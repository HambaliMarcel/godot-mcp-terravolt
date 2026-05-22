import type { ErrorObject } from "ajv";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

import { DaemonJsonRpcError, TRANSPORT_NOT_CONNECTED } from "../diagnostics/errors.js";
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
  mcp: McpServer;
  godot: GodotWsClient;
  routeCatalog: RouterToolCatalog;
  validateDaemonInput: ValidateDaemonFn;
}): void {
  const { mcp, godot, validateDaemonInput, routeCatalog } = args;

  const emitted = new Set<string>();
  const rows = [...routeCatalog.filter({})];
  for (const row of rows) {
    if (row.kind !== "daemon" || row.daemonMethod === undefined) continue;
    if (emitted.has(row.name)) continue;
    emitted.add(row.name);

    registerDaemonRow(mcp, godot, row, row.daemonMethod, validateDaemonInput);
  }
}

function registerDaemonRow(
  mcp: McpServer,
  godot: GodotWsClient,
  meta: RegisteredRouterTool,
  daemonMethod: string,
  validateDaemonInput: ValidateDaemonFn,
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

      const v = validateDaemonInput(meta.name, meta.inputSchemaJson, paramsObj);
      if (!v.ok) {
        const latency = Date.now() - t0;
        metricsRecordToolEnd(meta.name, false, latency);
        return errStructured("protocol.invalid_params", {
          app_code: "protocol.invalid_params",
          errors: v.errors,
        });
      }

      try {
        const raw = await godot.request(daemonMethod, paramsObj, {
          signal: extra.signal,
        });
        const latencyMs = Date.now() - t0;
        metricsRecordToolEnd(meta.name, true, latencyMs);

        if (meta.name === "ping") {
          const rr =
            typeof raw === "object" && raw !== null ? (raw as Record<string, unknown>) : {};
          const tsRaw = rr["ts"];
          const daemonTs = typeof tsRaw === "number" ? tsRaw : Number.NaN;
          const body = successEnvelope(meta.name, daemonMethod, latencyMs, {
            ok: true,
            daemonTs: Number.isFinite(daemonTs) ? daemonTs : undefined,
            roundTripMs: latencyMs,
            daemonResult: raw,
          });
          return okStructured(body);
        }

        return okStructured(successEnvelope(meta.name, daemonMethod, latencyMs, raw));
      } catch (error: unknown) {
        const latencyMs = Date.now() - t0;
        metricsRecordToolEnd(meta.name, false, latencyMs);
        const code =
          typeof (error as NodeJS.ErrnoException).code === "string"
            ? (error as NodeJS.ErrnoException).code
            : "";

        if (code === TRANSPORT_NOT_CONNECTED || code === "transport_socket_closed") {
          return errStructured(TRANSPORT_NOT_CONNECTED, disconnectedHint());
        }

        if (error instanceof DaemonJsonRpcError) {
          return errStructured(String(error.message), error.daemon);
        }

        return errStructured(error instanceof Error ? error.message : String(error));
      }
    },
  );
}
