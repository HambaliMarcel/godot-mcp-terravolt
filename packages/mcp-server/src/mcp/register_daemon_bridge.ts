import type { ErrorObject } from "ajv";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

import { DaemonJsonRpcError, TRANSPORT_NOT_CONNECTED } from "../diagnostics/errors.js";
import { loadAutoHealHintsBundle, resolveAutoHeal } from "../diagnostics/autoheal_hints.js";
import type { HeadlessCoordinator } from "../headless/headlessCoordinator.js";
import { GodotWsClient } from "../transport/godot_ws_client.js";
import { metricsRecordToolEnd, metricsRecordToolStart } from "../telemetry/metrics.js";
import type { RegisteredRouterTool } from "../tools/registry.js";
import { RouterToolCatalog } from "../tools/registry.js";
import { OpenParamsSchema } from "./local_router_tool_defs.js";
import { registerToolCompat } from "./register_tool_compat.js";
import {
  disconnectedHint,
  errStructured,
  okStructured,
  successEnvelope,
} from "./tool_result_envelopes.js";

export type ValidateDaemonFn = (
  toolName: string,
  schemaObj: Record<string, unknown>,
  params: Record<string, unknown>,
) => { ok: true } | { ok: false; errors: ErrorObject[] | undefined | null };

export function registerDaemonBridgedTools(args: {
  headless?: HeadlessCoordinator;
  mcp: McpServer;
  godot: GodotWsClient;
  routeCatalog: RouterToolCatalog;
  validateDaemonInput: ValidateDaemonFn;
  includeAutoHealHints: boolean;
}): void {
  const { headless, mcp, godot, validateDaemonInput, routeCatalog, includeAutoHealHints } = args;

  const emitted = new Set<string>();
  const rows = [...routeCatalog.filter({})];
  for (const row of rows) {
    if (row.kind !== "daemon" || row.daemonMethod === undefined) continue;
    if (emitted.has(row.name)) continue;
    emitted.add(row.name);

    registerDaemonRow(
      mcp,
      godot,
      row,
      row.daemonMethod,
      validateDaemonInput,
      headless,
      includeAutoHealHints,
    );
  }
}

function transportDisconnectedPayload(includeAutoHealHints: boolean): Record<string, unknown> {
  const base = disconnectedHint();
  if (!includeAutoHealHints) return base;
  const ah = loadAutoHealHintsBundle().bySymbol[TRANSPORT_NOT_CONNECTED];
  return ah !== undefined ? { ...base, autoHeal: ah } : base;
}

function registerDaemonRow(
  mcp: McpServer,
  godot: GodotWsClient,
  meta: RegisteredRouterTool,
  daemonMethod: string,
  validateDaemonInput: ValidateDaemonFn,
  headless: HeadlessCoordinator | undefined,
  includeAutoHealHints: boolean,
): void {
  registerToolCompat(
    mcp,
    meta.name,
    {
      title: meta.title,
      description: `${meta.description}\n\nDaemon JSON-RPC: \`${daemonMethod}\`\n(Source: packages/shared/methods/registry.json)`,
      inputSchema: OpenParamsSchema,
    },
    async (rawArgs: unknown, extra: { signal: AbortSignal }) => {
      metricsRecordToolStart(meta.name);
      const t0 = Date.now();
      let paramsObj: Record<string, unknown>;
      try {
        paramsObj = OpenParamsSchema.parse(rawArgs);
      } catch {
        metricsRecordToolEnd(meta.name, false, Date.now() - t0);
        return errStructured("protocol.invalid_params", {
          app_code: "protocol.invalid_params",
        });
      }

      // Optional per-call hybrid override: `_mode: "editor" | "headless" | "auto"`.
      // Strip before validation so it never leaks into the daemon-side schema.
      const modeOverride = extractModeOverride(paramsObj);

      const v = validateDaemonInput(meta.name, meta.inputSchemaJson, paramsObj);
      if (!v.ok) {
        const latency = Date.now() - t0;
        metricsRecordToolEnd(meta.name, false, latency);
        return errStructured("protocol.invalid_params", {
          app_code: "protocol.invalid_params",
          errors: v.errors,
        });
      }

      const finishOk = (
        raw: unknown,
        route: string,
        routeMode: "editor" | "headless",
      ): ReturnType<typeof okStructured> => {
        const latencyMs = Date.now() - t0;
        metricsRecordToolEnd(meta.name, true, latencyMs);
        if (meta.name === "ping") {
          const rr =
            typeof raw === "object" && raw !== null ? (raw as Record<string, unknown>) : {};
          const tsRaw = rr["ts"];
          const daemonTs = typeof tsRaw === "number" ? tsRaw : Number.NaN;
          const body = successEnvelope(
            meta.name,
            route,
            latencyMs,
            {
              ok: true,
              daemonTs: Number.isFinite(daemonTs) ? daemonTs : undefined,
              roundTripMs: latencyMs,
              daemonResult: raw,
            },
            routeMode,
          );
          return okStructured(body);
        }
        return okStructured(successEnvelope(meta.name, route, latencyMs, raw, routeMode));
      };

      // Force headless when caller asks for it. Skips the WS attempt entirely so
      // we never compete with the editor's single peer slot.
      if (modeOverride === "headless") {
        if (!meta.headlessFallback || headless === undefined) {
          metricsRecordToolEnd(meta.name, false, Date.now() - t0);
          return errStructured("mode.headless_not_available", {
            app_code: "mode.headless_not_available",
            hint: meta.headlessFallback
              ? "Headless coordinator missing from runtime (configure TERRAVOLT_GODOT_BINARY and TERRAVOLT_PROJECT_PATH)."
              : `Tool '${meta.name}' requires the live editor and cannot run headless.`,
          });
        }
        try {
          await headless.ensureDefaultSession();
          const raw = await headless.rpc(daemonMethod, paramsObj);
          return finishOk(raw, `${daemonMethod}@headless`, "headless");
        } catch (err) {
          metricsRecordToolEnd(meta.name, false, Date.now() - t0);
          return errStructured("mode.headless_failed", {
            app_code: "mode.headless_failed",
            hint: err instanceof Error ? err.message : String(err),
          });
        }
      }

      try {
        const raw = await godot.request(daemonMethod, paramsObj, {
          signal: extra.signal,
        });
        return finishOk(raw, `${daemonMethod}@editor`, "editor");
      } catch (error: unknown) {
        const code =
          typeof (error as NodeJS.ErrnoException).code === "string"
            ? (error as NodeJS.ErrnoException).code
            : "";

        const transportDown =
          code === TRANSPORT_NOT_CONNECTED ||
          code === "transport_socket_closed" ||
          code === "transport.peer_busy";

        // editor-forced mode never falls back to headless.
        if (modeOverride === "editor") {
          metricsRecordToolEnd(meta.name, false, Date.now() - t0);
          if (transportDown) {
            return errStructured(
              TRANSPORT_NOT_CONNECTED,
              transportDisconnectedPayload(includeAutoHealHints),
            );
          }
          if (error instanceof DaemonJsonRpcError) {
            return errStructured(
              typeof error.daemon["message"] === "string"
                ? error.daemon["message"]
                : String(error.message),
              error.daemon,
            );
          }
          return errStructured(error instanceof Error ? error.message : String(error));
        }

        if (transportDown && meta.headlessFallback && headless !== undefined) {
          try {
            await headless.ensureDefaultSession();
            const raw = await headless.rpc(daemonMethod, paramsObj);
            return finishOk(raw, `${daemonMethod}@headless`, "headless");
          } catch {
            metricsRecordToolEnd(meta.name, false, Date.now() - t0);
            return errStructured(
              TRANSPORT_NOT_CONNECTED,
              transportDisconnectedPayload(includeAutoHealHints),
            );
          }
        }

        const latencyMs = Date.now() - t0;
        metricsRecordToolEnd(meta.name, false, latencyMs);

        if (transportDown) {
          return errStructured(
            TRANSPORT_NOT_CONNECTED,
            transportDisconnectedPayload(includeAutoHealHints),
          );
        }

        if (error instanceof DaemonJsonRpcError) {
          const ah = includeAutoHealHints ? resolveAutoHeal(error.daemon) : undefined;
          const msg =
            typeof error.daemon["message"] === "string"
              ? error.daemon["message"]
              : String(error.message);
          return errStructured(msg, {
            ...error.daemon,
            ...(ah !== undefined ? { autoHeal: ah } : {}),
          });
        }

        return errStructured(error instanceof Error ? error.message : String(error));
      }
    },
  );
}

/**
 * Pops an optional `_mode` field from the params dict and returns it. The mode
 * lets the caller force one half of the hybrid path:
 *
 *   - `editor`   — never fall back to headless
 *   - `headless` — skip the WebSocket attempt entirely
 *   - `auto`     — default: editor first, headless on transport error
 *
 * `_mode` is stripped before the AJV daemon-input check so it never reaches the
 * Godot side.
 */
function extractModeOverride(
  params: Record<string, unknown>,
): "editor" | "headless" | "auto" | undefined {
  const raw = params["_mode"];
  if (raw === undefined) return undefined;
  delete params["_mode"];
  if (raw === "editor" || raw === "headless" || raw === "auto") return raw;
  return undefined;
}
