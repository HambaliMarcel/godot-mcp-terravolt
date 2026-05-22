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
  const { mcp, routeCatalog, jsonRegistry, routerRegistrySha, godot, ajvCompileSmoke, headless } = args;

  registerToolCompat(
    mcp,
    "tools.list",
    {
      title: routerOnlyTool("tools.list").title,
      description: routerOnlyTool("tools.list").description,
      inputSchema: ToolsListSchema,
    },
    async (argsInput: unknown, _extra: { signal: AbortSignal }) => {
      metricsRecordToolStart("tools.list");
      const t0 = Date.now();
      const p = ToolsListSchema.parse(argsInput);
      const items = routeCatalog.filter({
        category: p.category,
        safe: p.safe,
      });
      const latency = Date.now() - t0;
      metricsRecordToolEnd("tools.list", true, latency);
      return okStructured(
        successEnvelope(
          "tools.list",
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
    "tools.describe",
    {
      title: routerOnlyTool("tools.describe").title,
      description: routerOnlyTool("tools.describe").description,
      inputSchema: ToolsDescribeSchema,
    },
    async (argsInput: unknown, _extra: { signal: AbortSignal }) => {
      metricsRecordToolStart("tools.describe");
      const t0 = Date.now();
      const { name } = ToolsDescribeSchema.parse(argsInput);
      const td = routeCatalog.describe(name);
      const latency = Date.now() - t0;
      if (!td) {
        metricsRecordToolEnd("tools.describe", false, latency);
        return errStructured("tool.not_found", { name });
      }
      metricsRecordToolEnd("tools.describe", true, latency);
      return okStructured(
        successEnvelope("tools.describe", "local", latency, describeToolMeta(td)),
      );
    },
  );

  registerToolCompat(
    mcp,
    "tools.metrics",
    {
      title: routerOnlyTool("tools.metrics").title,
      description: routerOnlyTool("tools.metrics").description,
    },
    async (_raw: unknown, _extra: { signal: AbortSignal }) => {
      metricsRecordToolStart("tools.metrics");
      const t0 = Date.now();
      const latency = Date.now() - t0;
      metricsRecordToolEnd("tools.metrics", true, latency);
      return okStructured(successEnvelope("tools.metrics", "local", latency, metricsSnapshot()));
    },
  );

  registerToolCompat(
    mcp,
    "tools.bottlenecks",
    {
      title: routerOnlyTool("tools.bottlenecks").title,
      description: routerOnlyTool("tools.bottlenecks").description,
      inputSchema: ToolsBottlenecksSchema,
    },
    async (raw: unknown, _extra: { signal: AbortSignal }) => {
      metricsRecordToolStart("tools.bottlenecks");
      const t0 = Date.now();
      const p = ToolsBottlenecksSchema.parse(raw);
      const topN = p.topN ?? 10;
      const report = metricsBottleneckReport(topN);
      const latency = Date.now() - t0;
      metricsRecordToolEnd("tools.bottlenecks", true, latency);
      return okStructured(successEnvelope("tools.bottlenecks", "local", latency, report));
    },
  );

  registerToolCompat(
    mcp,
    "context.fetch_raw",
    {
      title: routerOnlyTool("context.fetch_raw").title,
      description: routerOnlyTool("context.fetch_raw").description,
      inputSchema: ContextFetchRawSchema,
    },
    async (raw: unknown, extra: { signal: AbortSignal }) => {
      metricsRecordToolStart("context.fetch_raw");
      const t0 = Date.now();
      const p = ContextFetchRawSchema.parse(raw);
      try {
        const res = await godot.request(p.method, p.params ?? {}, { signal: extra.signal });
        const latency = Date.now() - t0;
        metricsRecordToolEnd("context.fetch_raw", true, latency);
        return okStructured(successEnvelope("context.fetch_raw", p.method, latency, res));
      } catch (err: unknown) {
        const latency = Date.now() - t0;
        metricsRecordToolEnd("context.fetch_raw", false, latency);
        return errStructured(err instanceof Error ? err.message : String(err));
      }
    },
  );

  registerToolCompat(
    mcp,
    "tools.health",
    {
      title: routerOnlyTool("tools.health").title,
      description: routerOnlyTool("tools.health").description,
    },
    async (_raw: unknown, _extra: { signal: AbortSignal }) => {
      metricsRecordToolStart("tools.health");
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
      const headlessTcpAlive = Boolean((headless?.status() as Record<string, unknown> | undefined)?.alive);

      const hashMatch =
        daemonOk &&
        remoteSha !== undefined &&
        remoteSha === routerRegistrySha &&
        remoteVer === jsonRegistry.catalog_version;

      const mismatchFlag =
        daemonOk && remoteSha !== undefined && remoteSha.length > 0 && !hashMatch;

      const pass = ajvOk && daemonOk && hashMatch;
      const latencyMs = Date.now() - t0;
      metricsRecordToolEnd("tools.health", Boolean(pass), latencyMs);

      return okStructured(
        successEnvelope("tools.health", "local.health", latencyMs, {
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
