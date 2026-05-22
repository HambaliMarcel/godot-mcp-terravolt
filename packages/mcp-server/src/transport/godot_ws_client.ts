import WebSocket from "ws";
import type { Config } from "../config.js";
import { DaemonJsonRpcError, TRANSPORT_NOT_CONNECTED, isRecord } from "../diagnostics/errors.js";
import { mapGodotJsonRpcError } from "../diagnostics/map_godot_error.js";
import { PendingRequests } from "../jsonrpc/pending.js";
import type { Logger } from "../logger.js";

export type GodotNotificationSubscriber = (method: string, params: unknown) => void;

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

  private async waitForSocket(maxMs: number): Promise<void> {
    if (this.isConnected()) return;
    const deadline = Date.now() + maxMs;
    await new Promise<void>((resolve, reject) => {
      const step = (): void => {
        if (this.isConnected()) {
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
    if (
      this.ws &&
      (this.ws.readyState === WebSocket.CONNECTING || this.ws.readyState === WebSocket.OPEN)
    ) {
      return;
    }
    this.connectInFlight = true;
    const url = `ws://${this.cfg.godotHost}:${this.cfg.godotPort}`;
    const ws = new WebSocket(url, {
      handshakeTimeout: this.cfg.connectTimeoutMs,
    });
    this.ws = ws;
    ws.on("open", () => {
      this.connectInFlight = false;
      this.stableConnectedAt = Date.now();
      this.backoffAttempt = 0;
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
      this.log("warn", "transport", "disconnected", {
        code,
        reason: reason.toString(),
      });
      const lived = Date.now() - this.stableConnectedAt;
      if (lived >= 30_000) this.backoffAttempt = 0;
      this.ws = null;
      const delay = Math.min(
        this.cfg.reconnectMaxMs,
        this.cfg.reconnectBaseMs * 2 ** this.backoffAttempt,
      );
      this.backoffAttempt += 1;
      const reset = new Error("transport_socket_closed");
      (reset as NodeJS.ErrnoException).code = "transport_socket_closed";
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
