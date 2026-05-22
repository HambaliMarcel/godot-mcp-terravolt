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
      try {
        const info = await godot.request("server.info", {});
        daemonOk = true;
        if (typeof info === "object" && info !== null) {
          const dict = info as Record<string, unknown>;
          remoteSha = typeof dict.registry_sha256 === "string" ? dict.registry_sha256 : undefined;
          remoteVer = typeof dict.catalog_version === "string" ? dict.catalog_version : undefined;
        }
      } catch {
        daemonOk = false;
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
            pass,
          },
        }),
      );
    },
  );
}
