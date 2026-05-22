import WebSocket from "ws";
import type { Config } from "../config.js";
import { DaemonJsonRpcError, TRANSPORT_NOT_CONNECTED, isRecord } from "../diagnostics/errors.js";
import { mapGodotJsonRpcError } from "../diagnostics/map_godot_error.js";
import { PendingRequests } from "../jsonrpc/pending.js";
import type { Logger } from "../logger.js";

export type GodotNotificationSubscriber = (method: string, params: unknown) => void;

/** Snapshot of the WebSocket transport for diagnostics (tools_health). */
export interface GodotWsTransportDiagnostics {
  readonly readyState: number | null;
  readonly helloReceived: boolean;
  readonly lastCloseCode: number | null;
  readonly lastCloseReason: string | null;
  readonly peerBusyCount: number;
  readonly backoffAttempt: number;
  readonly connectInFlight: boolean;
  readonly url: string;
}

/** Daemon hello frame signalling the peer has been promoted to `ready`. */
const HELLO_NOTE = "terravolt_mcp_server_hello_opaque";

/** WS close codes the daemon uses to signal we hit the single-peer limit. */
const CLOSE_POLICY_VIOLATION = 1008;

export class GodotWsClient {
  private ws: WebSocket | null = null;
  private reconnectTimer: ReturnType<typeof setTimeout> | undefined;
  private pingTimer: ReturnType<typeof setInterval> | undefined;
  private readonly pending: PendingRequests;
  private readonly idState = { n: 0 };
  private backoffAttempt = 0;
  private stableConnectedAt = 0;
  private lastPong = 0;
  private readonly subscribers = new Set<GodotNotificationSubscriber>();
  private started = false;
  private connectInFlight = false;
  private helloReceived = false;
  private lastCloseCode: number | null = null;
  private lastCloseReason: string | null = null;
  private peerBusyCount = 0;
  // When sustained peer_busy is observed the router enters "circuit-broken"
  // mode: reconnects are paused at the max backoff and tools surface a clearer
  // `transport.persistent_peer_busy` error so the user sees the storm root
  // cause (zombie MCP peer holding the slot) instead of an infinite retry.
  private circuitBroken = false;
  private static readonly PEER_BUSY_CIRCUIT_THRESHOLD = 10;

  constructor(
    private readonly cfg: Config,
    private readonly log: Logger,
  ) {
    this.pending = new PendingRequests(log);
  }

  start(): void {
    if (this.started) return;
    this.started = true;
    this.scheduleReconnect(0);
  }

  stop(): void {
    this.started = false;
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.reconnectTimer = undefined;
    this.stopPing();
    this.pending.rejectAll(new Error("router_stopped"));
    if (this.ws) {
      try {
        this.ws.close(1000, "router stop");
      } catch {
        /* ignore */
      }
      this.ws = null;
    }
  }

  subscribeNotifications(h: GodotNotificationSubscriber): () => void {
    this.subscribers.add(h);
    return () => {
      this.subscribers.delete(h);
    };
  }

  isConnected(): boolean {
    return this.ws !== null && this.ws.readyState === WebSocket.OPEN;
  }

  /** True once the WebSocket is OPEN _and_ the daemon hello frame arrived. */
  isReady(): boolean {
    return this.isConnected() && this.helloReceived;
  }

  /** Diagnostic snapshot for tools_health / disconnectedHint. */
  getTransportDiagnostics(): GodotWsTransportDiagnostics & {
    readonly circuitBroken: boolean;
  } {
    return {
      readyState: this.ws?.readyState ?? null,
      helloReceived: this.helloReceived,
      lastCloseCode: this.lastCloseCode,
      lastCloseReason: this.lastCloseReason,
      peerBusyCount: this.peerBusyCount,
      backoffAttempt: this.backoffAttempt,
      connectInFlight: this.connectInFlight,
      url: this.lastUrl(),
      circuitBroken: this.circuitBroken,
    };
  }

  /**
   * Reset the peer-busy circuit breaker so the router resumes reconnect
   * attempts immediately. Intended for use after the operator clears the stale
   * peer (e.g. via `server.force_disconnect`, the dock Restart button, or by
   * killing the zombie MCP process).
   */
  resetPeerBusyCircuit(): void {
    this.circuitBroken = false;
    this.peerBusyCount = 0;
    this.backoffAttempt = 0;
    if (this.started && !this.isConnected() && !this.connectInFlight) {
      this.scheduleReconnect(0);
    }
  }

  private lastUrl(): string {
    return `ws://${this.cfg.godotHost}:${this.cfg.godotPort}`;
  }

  /** Best-effort JSON-RPC notification toward the daemon (no response). */
  sendNotification(method: string, params: unknown): void {
    if (!this.isConnected()) return;
    const body = JSON.stringify({
      jsonrpc: "2.0",
      method,
      params: params ?? {},
    });
    this.safeSendText(body);
  }

  async request(
    method: string,
    params: unknown,
    opts?: { timeoutMs?: number; signal?: AbortSignal },
  ): Promise<unknown> {
    await this.waitForSocket(Math.min(5000, this.cfg.connectTimeoutMs));
    if (!this.isConnected()) {
      throw this.notConnectedErr();
    }
    const id = this.allocJsonRpcId();
    const body = JSON.stringify({
      jsonrpc: "2.0",
      id,
      method,
      params: params ?? {},
    });
    if (Buffer.byteLength(body, "utf8") > this.cfg.maxPayloadBytes) {
      throw new Error("max_payload_bytes_exceeded");
    }
    try {
      return await this.pending.create(
        id,
        method,
        opts?.timeoutMs ?? this.cfg.requestTimeoutMs,
        () => {
          this.safeSendText(body);
        },
        opts?.signal,
      );
    } catch (e) {
      if (opts?.signal?.aborted && typeof method === "string" && method.length > 0) {
        this.sendNotification("dispatch.cancel", { target_id: id });
      }
      throw e;
    }
  }

  dispose(): void {
    this.pending.dispose();
    this.stop();
  }

  private allocJsonRpcId(): number {
    this.idState.n += 1;
    return this.idState.n;
  }

  private notConnectedErr(): Error {
    const e = new Error(TRANSPORT_NOT_CONNECTED);
    (e as NodeJS.ErrnoException).code = TRANSPORT_NOT_CONNECTED;
    return e;
  }

  // Waits until the socket is OPEN and (best-effort) the daemon hello frame has
  // arrived. The hello frame is the daemon's "promoted to ready" signal — without
  // it we'd race the first RPC and lose it to a peer_busy disconnect. The hello
  // grace period is bounded so we still proceed on OPEN if the daemon is too old
  // to emit one.
  private async waitForSocket(maxMs: number): Promise<void> {
    if (this.isReady()) return;
    const deadline = Date.now() + maxMs;
    const helloGraceUntil = Date.now() + Math.min(750, Math.max(150, Math.floor(maxMs / 4)));
    await new Promise<void>((resolve, reject) => {
      const step = (): void => {
        if (this.isReady()) {
          resolve();
          return;
        }
        if (this.isConnected() && Date.now() >= helloGraceUntil) {
          // Daemon hello did not arrive in time — proceed anyway for back-compat.
          resolve();
          return;
        }
        if (Date.now() >= deadline) {
          reject(this.notConnectedErr());
          return;
        }
        setTimeout(step, 50);
      };
      step();
    });
  }

  private safeSendText(txt: string): void {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) return;
    this.ws.send(txt, { binary: false });
  }

  private scheduleReconnect(delayMs: number): void {
    if (!this.started) return;
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.reconnectTimer = setTimeout(() => void this.tryOpen(), delayMs);
  }

  private tryOpen(): void {
    if (!this.started || this.connectInFlight) return;
    if (this.ws) {
      // Wait for any previous socket to fully close before opening a new one;
      // overlapping handshakes are what cause the peer_busy reconnect storm.
      const rs = this.ws.readyState;
      if (rs === WebSocket.CONNECTING || rs === WebSocket.OPEN || rs === WebSocket.CLOSING) {
        const wait = rs === WebSocket.CLOSING ? 100 : 250;
        this.scheduleReconnect(wait);
        return;
      }
    }
    this.connectInFlight = true;
    this.helloReceived = false;
    const url = `ws://${this.cfg.godotHost}:${this.cfg.godotPort}`;
    const ws = new WebSocket(url, {
      handshakeTimeout: this.cfg.connectTimeoutMs,
    });
    this.ws = ws;
    ws.on("open", () => {
      this.connectInFlight = false;
      this.stableConnectedAt = Date.now();
      this.lastPong = Date.now();
      this.log("info", "transport", "connected", { url });
      this.startPing();
    });
    ws.on("pong", () => {
      this.lastPong = Date.now();
    });
    ws.on("message", (data) => {
      this.onRawMessage(data);
    });
    ws.on("close", (code, reason) => {
      this.connectInFlight = false;
      this.stopPing();
      const wasReady = this.helloReceived;
      this.helloReceived = false;
      const reasonStr = reason.toString();
      this.lastCloseCode = typeof code === "number" ? code : null;
      this.lastCloseReason = reasonStr;

      const peerBusy =
        code === CLOSE_POLICY_VIOLATION || /server\s+busy|peer_busy/i.test(reasonStr);
      if (peerBusy) this.peerBusyCount += 1;

      // Trip the circuit if we've seen sustained peer_busy without ever getting
      // ready. That's the unambiguous signature of a zombie peer holding the
      // single-peer slot.
      if (
        peerBusy &&
        !wasReady &&
        this.peerBusyCount >= GodotWsClient.PEER_BUSY_CIRCUIT_THRESHOLD &&
        !this.circuitBroken
      ) {
        this.circuitBroken = true;
        this.log("error", "transport", "peer_busy_circuit_open", {
          peer_busy_count: this.peerBusyCount,
          hint:
            "Another MCP client holds the Godot peer slot. Call " +
            "server.force_disconnect from that client, or restart the Godot " +
            "addon (Terravolt MCP dock -> Restart), or kill the zombie MCP " +
            "process.",
        });
      }

      this.log("warn", "transport", peerBusy ? "peer_busy" : "disconnected", {
        code,
        reason: reasonStr,
        was_ready: wasReady,
        peer_busy_count: this.peerBusyCount,
        circuit_broken: this.circuitBroken,
      });

      const lived = Date.now() - this.stableConnectedAt;
      // Only reset backoff after a clean, healthy session that actually reached
      // "ready" (hello received). peer_busy NEVER resets it.
      if (!peerBusy && wasReady && lived >= 30_000) {
        this.backoffAttempt = 0;
      }
      this.ws = null;

      // Honour the policy violation by backing off longer so we don't hammer the
      // single peer slot. Otherwise use normal exponential backoff. When the
      // circuit is open we cap at reconnectMaxMs to avoid pointless storm.
      const base = peerBusy
        ? Math.max(2_000, this.cfg.reconnectBaseMs * 4)
        : this.cfg.reconnectBaseMs;
      const delay = this.circuitBroken
        ? this.cfg.reconnectMaxMs
        : Math.min(this.cfg.reconnectMaxMs, base * 2 ** this.backoffAttempt);
      this.backoffAttempt += 1;

      const resetCode = this.circuitBroken
        ? "transport.persistent_peer_busy"
        : peerBusy
          ? "transport.peer_busy"
          : "transport_socket_closed";
      const reset = new Error(resetCode);
      (reset as NodeJS.ErrnoException).code = resetCode;
      this.pending.rejectAll(reset);
      this.scheduleReconnect(delay);
    });
    ws.on("error", (err) => {
      this.connectInFlight = false;
      this.log("warn", "transport", "ws_error", {
        message: String((err as Error).message ?? err),
      });
    });
  }

  private onRawMessage(data: WebSocket.RawData): void {
    let text: string;
    if (typeof data === "string") {
      text = data;
    } else if (Buffer.isBuffer(data)) {
      text = data.toString("utf8");
    } else if (Array.isArray(data)) {
      text = Buffer.concat(data).toString("utf8");
    } else {
      text = Buffer.from(data as ArrayBuffer).toString("utf8");
    }
    if (text.length > this.cfg.maxPayloadBytes + 1024) {
      this.log("warn", "transport", "frame_too_large", {
        bytes: text.length,
      });
      return;
    }
    let msg: unknown;
    try {
      msg = JSON.parse(text) as unknown;
    } catch {
      return;
    }
    if (Array.isArray(msg)) {
      for (const m of msg) this.dispatchOne(m);
      return;
    }
    this.dispatchOne(msg);
  }

  private dispatchOne(msg: unknown): void {
    if (!isRecord(msg)) return;
    // Daemon hello frame: opaque "session ready" marker emitted right after the
    // server promotes the peer to ready. Treat it as the readiness signal so
    // request() can stop racing peer_busy disconnects.
    if (
      !("id" in msg) &&
      !("method" in msg) &&
      typeof msg["note"] === "string" &&
      msg["note"] === HELLO_NOTE
    ) {
      if (!this.helloReceived) {
        this.helloReceived = true;
        this.peerBusyCount = 0;
        this.backoffAttempt = 0;
        this.circuitBroken = false;
        this.log("info", "transport", "session_ready", { url: this.lastUrl() });
      }
      return;
    }
    if ("id" in msg && msg["id"] !== null && msg["id"] !== undefined) {
      const rawId = msg["id"];
      const idNum = typeof rawId === "number" ? rawId : Number.parseInt(String(rawId), 10);
      if (!Number.isFinite(idNum)) return;
      if ("error" in msg) {
        this.pending.rejectRpc(
          idNum,
          new DaemonJsonRpcError(mapGodotJsonRpcError(msg["error"]) as Record<string, unknown>),
        );
      } else {
        this.pending.resolve(idNum, msg["result"]);
      }
      return;
    }
    const m = msg["method"];
    if (typeof m !== "string") return;
    if (this.cfg.notificationFilter === "events" && !m.startsWith("event.")) {
      return;
    }
    const p = "params" in msg ? msg["params"] : undefined;
    for (const sub of [...this.subscribers]) {
      try {
        sub(m, p);
      } catch {
        /* ignore */
      }
    }
  }

  private startPing(): void {
    this.stopPing();
    this.pingTimer = setInterval(() => {
      const w = this.ws;
      if (!w || w.readyState !== WebSocket.OPEN) return;
      if (Date.now() - this.lastPong > this.cfg.heartbeatTimeoutMs) {
        this.log("warn", "transport", "heartbeat_kill", {});
        try {
          w.close(4000, "heartbeat timeout");
        } catch {
          /* ignore */
        }
        return;
      }
      w.ping();
    }, this.cfg.heartbeatIntervalMs);
  }

  private stopPing(): void {
    if (this.pingTimer) clearInterval(this.pingTimer);
    this.pingTimer = undefined;
  }
}
