import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import type { Notification } from "@modelcontextprotocol/sdk/types.js";
import { Ajv, type ErrorObject, type ValidateFunction } from "ajv";
import addFormats from "ajv-formats";
import { z } from "zod";
import { loadMethodRegistry, registryContentSha256 } from "../catalog/loadRegistry.js";
import type { Config } from "../config.js";
import { DaemonJsonRpcError, TRANSPORT_NOT_CONNECTED } from "../diagnostics/errors.js";
import type { Logger } from "../logger.js";
import {
  metricsRecordToolEnd,
  metricsRecordToolStart,
  metricsSnapshot,
} from "../telemetry/metrics.js";
import type { RegisteredRouterTool } from "../tools/registry.js";
import { RouterToolCatalog } from "../tools/registry.js";
import { GodotWsClient } from "./godot_ws_client.js";

const ToolsListSchema = z
  .object({
    category: z.string().optional(),
    safe: z.boolean().optional(),
  })
  .strict();

const ToolsDescribeSchema = z
  .object({
    name: z.string().min(1),
  })
  .strict();

const OpenParamsSchema = z.record(z.string(), z.unknown());

type ValidateFn = ValidateFunction;

/** MCP SDK `registerTool` + Zod can overflow TS instantiation depth; handlers stay typed locally. */
function registerToolCompat(
  server: McpServer,
  name: string,
  config: {
    title: string;
    description: string;
    inputSchema?: unknown;
  },
  handler: (rawArgs: unknown, extra: { signal: AbortSignal }) => Promise<unknown>,
): void {
  (server.registerTool as unknown as (toolName: string, cfg: unknown, fn: typeof handler) => void)(
    name,
    config,
    handler,
  );
}

export type RouterBundle = {
  mcp: McpServer;
  godot: GodotWsClient;
  catalog: RouterToolCatalog;
  connectStdio: () => Promise<void>;
  shutdown: () => Promise<void>;
};

function okStructured(envelope: Record<string, unknown>) {
  return {
    structuredContent: envelope,
    content: [{ type: "text" as const, text: JSON.stringify(envelope) }],
  };
}

function errStructured(message: string, data?: Record<string, unknown>) {
  const payload = { ok: false as const, message, ...data };
  return {
    structuredContent: payload,
    content: [{ type: "text" as const, text: JSON.stringify(payload) }],
    isError: true as const,
  };
}

function successEnvelope(
  tool: string,
  method: string,
  latencyMs: number,
  result: unknown,
): Record<string, unknown> {
  return { ok: true, tool, method, latencyMs, result };
}

function disconnectedHint(): Record<string, unknown> {
  return {
    app_code: TRANSPORT_NOT_CONNECTED,
    hint: "Ensure TerraVolt MCP addon is listening on :6505 (Phase 1); see docs/tasklist/05 §5.6.12 smoke.",
  };
}

function describeTool(t: RegisteredRouterTool): Record<string, unknown> {
  return {
    kind: t.kind,
    name: t.name,
    title: t.title,
    description: t.description,
    category: t.category,
    safe: t.safe,
    mutates: t.mutates,
    requiresEditor: t.requiresEditor,
    requiresRuntime: t.requiresRuntime,
    daemonMethod: t.daemonMethod ?? null,
    inputSchemaJson: t.inputSchemaJson,
    outputSchemaJson: t.outputSchemaJson ?? null,
  };
}

const LOCAL_TOOLS: RegisteredRouterTool[] = [
  {
    kind: "local",
    name: "tools.list",
    title: "List MCP tools",
    description: "List MCP tools with optional filters: category(string), safe(boolean).",
    category: "tools",
    safe: true,
    mutates: false,
    requiresEditor: false,
    requiresRuntime: false,
    daemonMethod: undefined,
    inputSchemaJson: {
      type: "object",
      properties: {
        category: { type: "string" },
        safe: { type: "boolean" },
      },
      additionalProperties: false,
    },
    outputSchemaJson: { type: "array" },
  },
  {
    kind: "local",
    name: "tools.describe",
    title: "Describe MCP tool",
    description: "Return metadata + schemas for one tool from the compiled router snapshot.",
    category: "tools",
    safe: true,
    mutates: false,
    requiresEditor: false,
    requiresRuntime: false,
    daemonMethod: undefined,
    inputSchemaJson: {
      type: "object",
      required: ["name"],
      properties: { name: { type: "string", minLength: 1 } },
      additionalProperties: false,
    },
    outputSchemaJson: { type: "object" },
  },
  {
    kind: "local",
    name: "tools.metrics",
    title: "Router metrics",
    description: "Rolling tool-call telemetry required by Phase 2 tasklist 06.",
    category: "tools",
    safe: true,
    mutates: false,
    requiresEditor: false,
    requiresRuntime: false,
    daemonMethod: undefined,
    inputSchemaJson: { type: "object", additionalProperties: false },
    outputSchemaJson: { type: "object" },
  },
  {
    kind: "local",
    name: "tools.health",
    title: "tools.health",
    description: "AJV sanity + daemon server.info probe + SHA256 parity for catalog JSON.",
    category: "tools",
    safe: true,
    mutates: false,
    requiresEditor: false,
    requiresRuntime: false,
    daemonMethod: undefined,
    inputSchemaJson: { type: "object", additionalProperties: false },
    outputSchemaJson: { type: "object" },
  },
];

export function bootstrapRouter(opts: { config: Config; log: Logger }): RouterBundle {
  const { config, log } = opts;

  const jsonRegistry = loadMethodRegistry();
  const routerRegistrySha = registryContentSha256();

  const ajv = new Ajv({
    strict: false,
    allErrors: true,
    allowUnionTypes: true,
    strictTuples: false,
  });
  (addFormats as unknown as (inst: Ajv) => void)(ajv);

  const compilers = new Map<string, ValidateFn>();

  function getValidator(toolName: string, schemaObj: Record<string, unknown>): ValidateFn {
    let v = compilers.get(toolName);
    if (!v) {
      v = ajv.compile(schemaObj) as ValidateFn;
      compilers.set(toolName, v);
    }
    return v;
  }

  function validateDaemonInput(
    toolName: string,
    schemaObj: Record<string, unknown>,
    params: Record<string, unknown>,
  ): { ok: true } | { ok: false; errors: ErrorObject[] | undefined | null } {
    try {
      const validate = getValidator(toolName, schemaObj);
      if (!validate(params)) return { ok: false, errors: validate.errors };
      return { ok: true };
    } catch {
      log("warn", "router", "ajv_compile_skipped", {
        toolName,
      });
      return { ok: true };
    }
  }

  const mcp = new McpServer(
    { name: "terravolt-godot-mcp", version: config.packageVersion },
    {
      capabilities: { tools: { listChanged: false } },
      instructions:
        "TerraVolt Godot MCP bridges Cursor (stdio MCP) to the Godot editor daemon (:6505).",
    },
  );

  const godot = new GodotWsClient(config, log);

  godot.subscribeNotifications((method, params) => {
    const notification: Notification = {
      method: "notifications/message",
      params: {
        level: "info",
        logger: `terravolt.daemon.${method}`,
        data: params,
      },
    };
    void mcp.server.notification(notification).catch(() => {});
  });

  const routeCatalog = new RouterToolCatalog();
  routeCatalog.mergeFromDaemonRegistry(jsonRegistry.methods);
  for (const lt of LOCAL_TOOLS) routeCatalog.add(lt);

  function registerDaemonTool(meta: RegisteredRouterTool, daemonMethod: string): void {
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

  registerToolCompat(
    mcp,
    "tools.list",
    {
      title: LOCAL_TOOLS[0]!.title,
      description: LOCAL_TOOLS[0]!.description,
      inputSchema: ToolsListSchema,
    },
    async (args: unknown, _extra: { signal: AbortSignal }) => {
      metricsRecordToolStart("tools.list");
      const t0 = Date.now();
      const p = ToolsListSchema.parse(args);
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
      title: LOCAL_TOOLS[1]!.title,
      description: LOCAL_TOOLS[1]!.description,
      inputSchema: ToolsDescribeSchema,
    },
    async (args: unknown, _extra: { signal: AbortSignal }) => {
      metricsRecordToolStart("tools.describe");
      const t0 = Date.now();
      const { name } = ToolsDescribeSchema.parse(args);
      const td = routeCatalog.describe(name);
      const latency = Date.now() - t0;
      if (!td) {
        metricsRecordToolEnd("tools.describe", false, latency);
        return errStructured("tool.not_found", { name });
      }
      metricsRecordToolEnd("tools.describe", true, latency);
      return okStructured(successEnvelope("tools.describe", "local", latency, describeTool(td)));
    },
  );

  registerToolCompat(
    mcp,
    "tools.metrics",
    {
      title: LOCAL_TOOLS[2]!.title,
      description: LOCAL_TOOLS[2]!.description,
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
    "tools.health",
    {
      title: LOCAL_TOOLS[3]!.title,
      description: LOCAL_TOOLS[3]!.description,
    },
    async (_raw: unknown, _extra: { signal: AbortSignal }) => {
      metricsRecordToolStart("tools.health");
      const t0 = Date.now();

      let ajvOk = false;
      try {
        const smoke = ajv.compile({
          type: "object",
          additionalProperties: false,
        }) as ValidateFn;
        ajvOk = smoke({}) === true;
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
            pass,
          },
        }),
      );
    },
  );

  const emitted = new Set<string>();
  for (const row of [...routeCatalog.filter({})]) {
    if (row.kind !== "daemon" || row.daemonMethod === undefined) continue;
    if (emitted.has(row.name)) continue;
    emitted.add(row.name);
    registerDaemonTool(row, row.daemonMethod);
  }

  godot.start();

  async function shutdown(): Promise<void> {
    try {
      await mcp.close();
    } finally {
      godot.dispose();
    }
  }

  return {
    mcp,
    godot,
    catalog: routeCatalog,
    connectStdio: async () => {
      await mcp.connect(new StdioServerTransport());
    },
    shutdown,
  };
}
