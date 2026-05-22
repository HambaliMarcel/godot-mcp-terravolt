import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import type { Notification } from "@modelcontextprotocol/sdk/types.js";
import { Ajv, type ErrorObject, type ValidateFunction } from "ajv";
import addFormats from "ajv-formats";

import { loadMethodRegistry, registryContentSha256 } from "../catalog/loadRegistry.js";
import type { Config } from "../config.js";
import { HeadlessCoordinator } from "../headless/headlessCoordinator.js";
import type { Logger } from "../logger.js";
import { ROUTER_ONLY_TOOLS } from "../mcp/local_router_tool_defs.js";
import { registerDaemonBridgedTools } from "../mcp/register_daemon_bridge.js";
import type { ValidateDaemonFn } from "../mcp/register_daemon_bridge.js";
import { registerHeadlessRouterTools } from "../mcp/register_headless_router_tools.js";
import { registerRouterOnlyTools } from "../mcp/register_router_only_tools.js";
import { RouterToolCatalog } from "../tools/registry.js";
import { GodotWsClient } from "./godot_ws_client.js";

type ValidateFn = ValidateFunction;

export type RouterBundle = {
  mcp: McpServer;
  godot: GodotWsClient;
  catalog: RouterToolCatalog;
  connectStdio: () => Promise<void>;
  shutdown: () => Promise<void>;
};

/** MCP bootstrap: stdio transport binding + MCP tool wiring (delegated to `../mcp/*`). */
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
  (addFormats as unknown as (instance: typeof ajv) => void)(ajv);

  let ajvHealthSmoke: ValidateFn | null = null;
  try {
    ajvHealthSmoke = ajv.compile({
      type: "object",
      additionalProperties: false,
    }) as ValidateFn;
  } catch {
    ajvHealthSmoke = null;
  }

  const compilers = new Map<string, ValidateFn>();

  function getValidator(toolName: string, schemaObj: Record<string, unknown>): ValidateFn {
    let v = compilers.get(toolName);
    if (!v) {
      v = ajv.compile(schemaObj) as ValidateFn;
      compilers.set(toolName, v);
    }
    return v;
  }

  const validateDaemonInput: ValidateDaemonFn = (
    toolName: string,
    schemaObj: Record<string, unknown>,
    params: Record<string, unknown>,
  ): { ok: true } | { ok: false; errors: ErrorObject[] | undefined | null } => {
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
  };

  const mcp = new McpServer(
    { name: "terravolt-godot-mcp", version: config.packageVersion },
    {
      capabilities: { tools: { listChanged: false } },
      instructions:
        "Terravolt bridges Cursor MCP stdio to editor (:6505) and optional Godot headless TCP (task 07).",
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
  for (const lt of ROUTER_ONLY_TOOLS) routeCatalog.add(lt);

  const headless = new HeadlessCoordinator(config, log, String(import.meta.url));

  registerHeadlessRouterTools({ mcp, routeCatalog, headless });

  registerDaemonBridgedTools({
    mcp,
    godot,
    headless,
    routeCatalog,
    validateDaemonInput,
    includeAutoHealHints: config.includeAutoHealHints,
  });

  registerRouterOnlyTools({
    mcp,
    routeCatalog,
    jsonRegistry,
    routerRegistrySha,
    godot,
    ajvCompileSmoke: ajvHealthSmoke,
    headless,
  });

  godot.start();

  async function shutdown(): Promise<void> {
    try {
      await headless.stop(false);
    } catch {
      //
    }

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
