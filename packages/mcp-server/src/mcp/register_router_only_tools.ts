import net from "node:net";
import type { ValidateFunction } from "ajv";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

import type { MethodRegistryFile } from "../catalog/methodRegistry.types.js";
import type { HeadlessCoordinator } from "../headless/headlessCoordinator.js";
import { GodotWsClient } from "../transport/godot_ws_client.js";
import {
  metricsBottleneckReport,
  metricsRecordToolEnd,
  metricsRecordToolStart,
  metricsSnapshot,
} from "../telemetry/metrics.js";
import { RouterToolCatalog } from "../tools/registry.js";
import {
  ContextFetchRawSchema,
  ToolsBottlenecksSchema,
  ToolsDescribeSchema,
  ToolsListSchema,
  routerOnlyTool,
} from "./local_router_tool_defs.js";

import { registerToolCompat } from "./register_tool_compat.js";
import {
  errStructured,
  okStructured,
  successEnvelope,
  describeToolMeta,
} from "./tool_result_envelopes.js";

type ValidateFn = ValidateFunction;

/** Router-native helpers (`tools.*`) wired after catalog merge — Phase 2 task `06`. */
export function registerRouterOnlyTools(args: {
  mcp: McpServer;
  routeCatalog: RouterToolCatalog;
  jsonRegistry: MethodRegistryFile;
  routerRegistrySha: string;
  godot: GodotWsClient;
  ajvCompileSmoke: ValidateFn | null;
  headless?: HeadlessCoordinator;
}): void {
  const { mcp, routeCatalog, jsonRegistry, routerRegistrySha, godot, ajvCompileSmoke, headless } =
    args;

  registerToolCompat(
    mcp,
    "tools_list",
    {
      title: routerOnlyTool("tools_list").title,
      description: routerOnlyTool("tools_list").description,
      inputSchema: ToolsListSchema,
    },
    async (argsInput: unknown, _extra: { signal: AbortSignal }) => {
      metricsRecordToolStart("tools_list");
      const t0 = Date.now();
      const p = ToolsListSchema.parse(argsInput);
      const items = routeCatalog.filter({
        category: p.category,
        safe: p.safe,
      });
      const latency = Date.now() - t0;
      metricsRecordToolEnd("tools_list", true, latency);
      return okStructured(
        successEnvelope(
          "tools_list",
          "local",
          latency,
          items.map((row) => ({
            name: row.name,
            category: row.category,
            safe: row.safe,
          })),
        ),
      );
    },
  );

  registerToolCompat(
    mcp,
    "tools_describe",
    {
      title: routerOnlyTool("tools_describe").title,
      description: routerOnlyTool("tools_describe").description,
      inputSchema: ToolsDescribeSchema,
    },
    async (argsInput: unknown, _extra: { signal: AbortSignal }) => {
      metricsRecordToolStart("tools_describe");
      const t0 = Date.now();
      const { name } = ToolsDescribeSchema.parse(argsInput);
      const td = routeCatalog.describe(name);
      const latency = Date.now() - t0;
      if (!td) {
        metricsRecordToolEnd("tools_describe", false, latency);
        return errStructured("tool.not_found", { name });
      }
      metricsRecordToolEnd("tools_describe", true, latency);
      return okStructured(
        successEnvelope("tools_describe", "local", latency, describeToolMeta(td)),
      );
    },
  );

  registerToolCompat(
    mcp,
    "tools_metrics",
    {
      title: routerOnlyTool("tools_metrics").title,
      description: routerOnlyTool("tools_metrics").description,
    },
    async (_raw: unknown, _extra: { signal: AbortSignal }) => {
      metricsRecordToolStart("tools_metrics");
      const t0 = Date.now();
      const latency = Date.now() - t0;
      metricsRecordToolEnd("tools_metrics", true, latency);
      return okStructured(successEnvelope("tools_metrics", "local", latency, metricsSnapshot()));
    },
  );

  registerToolCompat(
    mcp,
    "tools_bottlenecks",
    {
      title: routerOnlyTool("tools_bottlenecks").title,
      description: routerOnlyTool("tools_bottlenecks").description,
      inputSchema: ToolsBottlenecksSchema,
    },
    async (raw: unknown, _extra: { signal: AbortSignal }) => {
      metricsRecordToolStart("tools_bottlenecks");
      const t0 = Date.now();
      const p = ToolsBottlenecksSchema.parse(raw);
      const topN = p.topN ?? 10;
      const report = metricsBottleneckReport(topN);
      const latency = Date.now() - t0;
      metricsRecordToolEnd("tools_bottlenecks", true, latency);
      return okStructured(successEnvelope("tools_bottlenecks", "local", latency, report));
    },
  );

  registerToolCompat(
    mcp,
    "context_fetch_raw",
    {
      title: routerOnlyTool("context_fetch_raw").title,
      description: routerOnlyTool("context_fetch_raw").description,
      inputSchema: ContextFetchRawSchema,
    },
    async (raw: unknown, extra: { signal: AbortSignal }) => {
      metricsRecordToolStart("context_fetch_raw");
      const t0 = Date.now();
      const p = ContextFetchRawSchema.parse(raw);
      try {
        const res = await godot.request(p.method, p.params ?? {}, { signal: extra.signal });
        const latency = Date.now() - t0;
        metricsRecordToolEnd("context_fetch_raw", true, latency);
        return okStructured(successEnvelope("context_fetch_raw", p.method, latency, res));
      } catch (err: unknown) {
        const latency = Date.now() - t0;
        metricsRecordToolEnd("context_fetch_raw", false, latency);
        return errStructured(err instanceof Error ? err.message : String(err));
      }
    },
  );

  registerToolCompat(
    mcp,
    "tools_health",
    {
      title: routerOnlyTool("tools_health").title,
      description: routerOnlyTool("tools_health").description,
    },
    async (_raw: unknown, _extra: { signal: AbortSignal }) => {
      metricsRecordToolStart("tools_health");
      const t0 = Date.now();

      let ajvOk = false;
      try {
        if (ajvCompileSmoke !== null) ajvOk = ajvCompileSmoke({}) === true;
      } catch {
        ajvOk = false;
      }

      let daemonOk = false;
      let remoteSha: string | undefined;
      let remoteVer: string | undefined;
      let daemonErrorCode: string | null = null;
      try {
        const info = await godot.request("server.info", {});
        daemonOk = true;
        if (typeof info === "object" && info !== null) {
          const dict = info as Record<string, unknown>;
          remoteSha = typeof dict.registry_sha256 === "string" ? dict.registry_sha256 : undefined;
          remoteVer = typeof dict.catalog_version === "string" ? dict.catalog_version : undefined;
        }
      } catch (err) {
        daemonOk = false;
        const code = (err as NodeJS.ErrnoException | undefined)?.code;
        daemonErrorCode =
          typeof code === "string" && code.length > 0 ? code : ((err as Error)?.message ?? null);
      }

      // When the daemon RPC fails, surface concrete transport diagnostics so the
      // operator can tell apart "port not listening" / "stuck on peer_busy" /
      // "router was never reachable". This is what made the Laminer incident
      // hard to triage previously.
      let transportDiagnostics: Record<string, unknown> | null = null;
      if (!daemonOk) {
        const diag = godot.getTransportDiagnostics();
        const portReachable = await probeTcpPort(
          diag.url.replace(/^ws:\/\//, "").split(":")[0] ?? "127.0.0.1",
          Number.parseInt(diag.url.split(":").pop() ?? "0", 10),
          500,
        );
        const peerBusyLikely = diag.lastCloseCode === 1008 || diag.peerBusyCount > 0;
        const hint = diag.circuitBroken
          ? "Peer-busy circuit is OPEN — sustained peer_busy detected (zombie MCP peer holding the slot). Run `server_force_disconnect` from this client (if it ever connected), or click the Restart button on Godot's Terravolt MCP dock, or kill any stale `node packages/mcp-server/dist/index.js` processes. Then call `transport_reset` to resume reconnects."
          : peerBusyLikely
            ? "Only one MCP client is allowed per Godot editor. Close other Cursor windows / scripts, then restart this MCP server. If the slot stays blocked, the Godot editor will now auto-evict stale peers on the next handshake."
            : portReachable
              ? "Port 6505 listens but no MCP session. Make sure Godot is open in EDITOR mode (not F5 game) with the Terravolt MCP plugin enabled."
              : "Port 6505 is not reachable. Open Godot.exe --path <project> --editor and enable the Terravolt MCP plugin.";
        transportDiagnostics = {
          url: diag.url,
          port_reachable: portReachable,
          ws_ready_state: diag.readyState,
          hello_received: diag.helloReceived,
          last_close_code: diag.lastCloseCode,
          last_close_reason: diag.lastCloseReason,
          peer_busy_count: diag.peerBusyCount,
          backoff_attempt: diag.backoffAttempt,
          connect_in_flight: diag.connectInFlight,
          circuit_broken: diag.circuitBroken,
          daemon_error_code: daemonErrorCode,
          likely_cause: diag.circuitBroken
            ? "transport.persistent_peer_busy"
            : peerBusyLikely
              ? "transport.peer_busy"
              : portReachable
                ? "transport.no_session"
                : "transport.port_closed",
          hint,
        };
      }

      let headlessGodotResolvable = false;
      try {
        headless?.godotExeOrThrow();
        headlessGodotResolvable = true;
      } catch {
        headlessGodotResolvable = false;
      }
      let headlessDriverGd: string | null = null;
      try {
        headlessDriverGd = headless?.resolveDriverPath() ?? null;
      } catch {
        headlessDriverGd = null;
      }
      const headlessTcpAlive = Boolean(
        (headless?.status() as Record<string, unknown> | undefined)?.alive,
      );

      const hashMatch =
        daemonOk &&
        remoteSha !== undefined &&
        remoteSha === routerRegistrySha &&
        remoteVer === jsonRegistry.catalog_version;

      const mismatchFlag =
        daemonOk && remoteSha !== undefined && remoteSha.length > 0 && !hashMatch;

      const pass = ajvOk && daemonOk && hashMatch;
      const latencyMs = Date.now() - t0;
      metricsRecordToolEnd("tools_health", Boolean(pass), latencyMs);

      return okStructured(
        successEnvelope("tools_health", "local.health", latencyMs, {
          checks: {
            ajv_object_ok: ajvOk,
            daemon_server_info_ok: daemonOk,
            router_catalog_version: jsonRegistry.catalog_version,
            daemon_catalog_version: remoteVer ?? null,
            router_registry_sha256: routerRegistrySha,
            daemon_registry_sha256: remoteSha ?? null,
            protocol_catalog_match: hashMatch,
            protocol_catalog_mismatch_detected: mismatchFlag,
            headless_godot_executable_resolvable: headlessGodotResolvable,
            headless_driver_gd_absolute: headlessDriverGd,
            headless_tcp_session_alive: headlessTcpAlive,
            transport_diagnostics: transportDiagnostics,
            pass,
          },
        }),
      );
    },
  );

  registerToolCompat(
    mcp,
    "mode_status",
    {
      title: routerOnlyTool("mode_status").title,
      description: routerOnlyTool("mode_status").description,
    },
    async (_raw: unknown, _extra: { signal: AbortSignal }) => {
      metricsRecordToolStart("mode_status");
      const t0 = Date.now();

      // 1) Editor (head/window) mode probe — quick TCP test + WS transport diag.
      const diag = godot.getTransportDiagnostics();
      const editorHost = diag.url.replace(/^ws:\/\//, "").split(":")[0] ?? "127.0.0.1";
      const editorPort = Number.parseInt(diag.url.split(":").pop() ?? "0", 10);
      const editorPortReachable = await probeTcpPort(editorHost, editorPort, 400);
      let editorRpcOk = false;
      let editorCatalogVersion: string | null = null;
      try {
        const info = await godot.request("server.info", {});
        editorRpcOk = true;
        if (typeof info === "object" && info !== null) {
          const v = (info as Record<string, unknown>)["catalog_version"];
          editorCatalogVersion = typeof v === "string" ? v : null;
        }
      } catch {
        editorRpcOk = false;
      }

      // 2) Headless coordinator state (no spawn — just status).
      const headlessStatus = (headless?.status() as Record<string, unknown> | undefined) ?? {
        alive: false,
      };
      let headlessExeResolvable = false;
      try {
        headless?.godotExeOrThrow();
        headlessExeResolvable = true;
      } catch {
        headlessExeResolvable = false;
      }

      // 3) Recommendation: editor wins when alive (full 222 methods); headless
      // is the fallback when editor isn't reachable but binary + project are set.
      const editorAlive = editorRpcOk;
      const headlessAlive = Boolean((headlessStatus as Record<string, unknown>).alive);
      const headlessAvailable = headlessExeResolvable;
      const recommendedMode: "editor" | "headless" | "none" = editorAlive
        ? "editor"
        : headlessAvailable
          ? "headless"
          : "none";
      const hybridReady = editorAlive || headlessAvailable;

      const advice: string[] = [];
      if (!editorAlive) {
        if (editorPortReachable) {
          advice.push(
            "Port 6505 listens but the daemon RPC is not responding. Restart the Terravolt MCP server from the editor bottom panel.",
          );
        } else {
          advice.push(
            'Open the Godot editor: Godot.exe --path "<your-project>" --editor, then enable the Terravolt MCP plugin to expose the head/window path.',
          );
        }
      }
      if (!headlessAvailable) {
        advice.push(
          "Set TERRAVOLT_GODOT_BINARY (and optionally TERRAVOLT_PROJECT_PATH) to enable the headless fallback.",
        );
      }
      if (editorAlive && headlessAvailable) {
        advice.push(
          'Hybrid ready: editor will serve calls by default; pass `_mode: "headless"` per tool call to force the headless path.',
        );
      }

      const latencyMs = Date.now() - t0;
      metricsRecordToolEnd("mode_status", true, latencyMs);
      return okStructured(
        successEnvelope(
          "mode_status",
          "local.mode_status",
          latencyMs,
          {
            editor: {
              alive: editorAlive,
              ws_ready_state: diag.readyState,
              hello_received: diag.helloReceived,
              port_reachable: editorPortReachable,
              port: editorPort,
              host: editorHost,
              catalog_version: editorCatalogVersion,
              last_close_code: diag.lastCloseCode,
              last_close_reason: diag.lastCloseReason,
              peer_busy_count: diag.peerBusyCount,
            },
            headless: {
              alive: headlessAlive,
              available: headlessAvailable,
              ...headlessStatus,
            },
            recommended_mode: recommendedMode,
            hybrid_ready: hybridReady,
            override_hint:
              'Daemon-bridged tools accept `_mode`: "editor" (no fallback), "headless" (skip editor), "auto" (default).',
            advice,
          },
          "router",
        ),
      );
    },
  );

  registerToolCompat(
    mcp,
    "transport_reset",
    {
      title: routerOnlyTool("transport_reset").title,
      description: routerOnlyTool("transport_reset").description,
    },
    async (_raw: unknown, _extra: { signal: AbortSignal }) => {
      metricsRecordToolStart("transport_reset");
      const t0 = Date.now();
      const before = godot.getTransportDiagnostics();
      godot.resetPeerBusyCircuit();
      // Give the reconnect one tick to fire, then re-snapshot.
      await new Promise<void>((r) => setTimeout(r, 50));
      const after = godot.getTransportDiagnostics();
      const latencyMs = Date.now() - t0;
      metricsRecordToolEnd("transport_reset", true, latencyMs);
      return okStructured(
        successEnvelope(
          "transport_reset",
          "local.transport_reset",
          latencyMs,
          {
            before: {
              circuit_broken: before.circuitBroken,
              peer_busy_count: before.peerBusyCount,
              backoff_attempt: before.backoffAttempt,
              ws_ready_state: before.readyState,
            },
            after: {
              circuit_broken: after.circuitBroken,
              peer_busy_count: after.peerBusyCount,
              backoff_attempt: after.backoffAttempt,
              ws_ready_state: after.readyState,
            },
            hint:
              after.circuitBroken === false && before.circuitBroken === true
                ? "Circuit cleared. Reconnect attempt scheduled."
                : after.circuitBroken === false
                  ? "Circuit was not tripped. Reconnect attempt scheduled."
                  : "Circuit could not be cleared; reset called but state not yet updated.",
          },
          "router",
        ),
      );
    },
  );
}

/** Best-effort TCP reachability probe for the Godot MCP port (no traffic). */
async function probeTcpPort(host: string, port: number, timeoutMs: number): Promise<boolean> {
  if (!Number.isFinite(port) || port <= 0) return false;
  return await new Promise<boolean>((resolve) => {
    const sock = new net.Socket();
    let done = false;
    const finish = (ok: boolean): void => {
      if (done) return;
      done = true;
      try {
        sock.destroy();
      } catch {
        /* ignore */
      }
      resolve(ok);
    };
    sock.setTimeout(timeoutMs);
    sock.once("connect", () => finish(true));
    sock.once("timeout", () => finish(false));
    sock.once("error", () => finish(false));
    try {
      sock.connect(port, host);
    } catch {
      finish(false);
    }
  });
}
