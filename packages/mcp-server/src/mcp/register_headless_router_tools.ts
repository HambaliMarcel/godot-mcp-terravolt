import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { HeadlessCoordinator } from "../headless/headlessCoordinator.js";
import { metricsRecordToolEnd, metricsRecordToolStart } from "../telemetry/metrics.js";
import type { RegisteredRouterTool } from "../tools/registry.js";
import { RouterToolCatalog } from "../tools/registry.js";
import { OpenParamsSchema } from "./local_router_tool_defs.js";
import { registerToolCompat } from "./register_tool_compat.js";
import { errStructured, okStructured, successEnvelope } from "./tool_result_envelopes.js";

/** §07 local MCP helpers (lifecycle + GDScript compile check). */
export function registerHeadlessRouterTools(args: {
  mcp: McpServer;
  routeCatalog: RouterToolCatalog;
  headless: HeadlessCoordinator;
}): void {
  const { mcp, routeCatalog, headless } = args;

  const local = (partial: Omit<RegisteredRouterTool, "kind">): void => {
    const row: RegisteredRouterTool = { ...partial, kind: "local" };
    routeCatalog.add(row);
  };

  local({
    name: "headless.start_project",
    title: "Headless session start",
    description: "Spawns lone Godot headless TCP driver for a project.",
    category: "headless",
    safe: false,
    mutates: false,
    requiresEditor: false,
    requiresRuntime: false,
    inputSchemaJson: {
      type: "object",
      properties: { projectPath: { type: "string", minLength: 1 } },
      additionalProperties: false,
    },
    outputSchemaJson: { type: "object" },
  });

  registerToolCompat(
    mcp,
    "headless.start_project",
    { title: "Headless session start", description: "Starts §07 headless subprocess.", inputSchema: OpenParamsSchema },
    async (raw) => {
      metricsRecordToolStart("headless.start_project");
      const t0 = Date.now();
      try {
        const p = OpenParamsSchema.parse(raw) as Record<string, unknown>;
        const projOpt = typeof p.projectPath === "string" ? p.projectPath : undefined;
        await headless.ensureDefaultSession(projOpt);
        const latency = Date.now() - t0;
        metricsRecordToolEnd("headless.start_project", true, latency);
        return okStructured(successEnvelope("headless.start_project", "headless", latency, { ready: true, ...headless.status() }));
      } catch (e) {
        metricsRecordToolEnd("headless.start_project", false, Date.now() - t0);
        const msg = e instanceof Error ? e.message : String(e);
        const code = msg.includes("binary_missing") ? "headless.binary_missing" : msg.includes("no_project") ? "headless.no_project" : "headless.spawn_failed";
        return errStructured(code, { app_code: code, hint: msg });
      }
    },
  );

  local({
    name: "headless.stop",
    title: "Headless stop",
    description: "Stops headless Godot subprocess.",
    category: "headless",
    safe: false,
    mutates: true,
    requiresEditor: false,
    requiresRuntime: false,
    inputSchemaJson: {
      type: "object",
      properties: { force: { type: "boolean" } },
      additionalProperties: false,
    },
    outputSchemaJson: { type: "object" },
  });

  registerToolCompat(
    mcp,
    "headless.stop",
    { title: "Headless stop", description: "Stops subprocess.", inputSchema: OpenParamsSchema },
    async (raw) => {
      metricsRecordToolStart("headless.stop");
      const t0 = Date.now();
      const p = OpenParamsSchema.parse(raw) as Record<string, unknown>;
      await headless.stop(Boolean(p.force));
      const latency = Date.now() - t0;
      metricsRecordToolEnd("headless.stop", true, latency);
      return okStructured(successEnvelope("headless.stop", "headless", latency, { ok: true }));
    },
  );

  local({
    name: "headless.status",
    title: "Headless status",
    description: "Observability for lone headless subprocess.",
    category: "headless",
    safe: true,
    mutates: false,
    requiresEditor: false,
    requiresRuntime: false,
    inputSchemaJson: { type: "object", additionalProperties: false },
    outputSchemaJson: { type: "object" },
  });

  registerToolCompat(
    mcp,
    "headless.status",
    { title: "Headless status", description: "Shows session info.", inputSchema: OpenParamsSchema },
    async () => {
      metricsRecordToolStart("headless.status");
      const t0 = Date.now();
      const latency = Date.now() - t0;
      metricsRecordToolEnd("headless.status", true, latency);
      return okStructured(successEnvelope("headless.status", "headless", latency, headless.status()));
    },
  );

  local({
    name: "headless.validate_script",
    title: "Headless GDScript compile check",
    description: "script.validate_syntax on TCP driver (.gd)",
    category: "headless",
    safe: true,
    mutates: false,
    requiresEditor: false,
    requiresRuntime: false,
    inputSchemaJson: {
      type: "object",
      properties: {
        path: { type: "string", minLength: 1 },
        projectPath: { type: "string" },
      },
      additionalProperties: false,
    },
    outputSchemaJson: { type: "object" },
  });

  registerToolCompat(
    mcp,
    "headless.validate_script",
    { title: "validate_script headless", description: "Parses/script reload .gd.", inputSchema: OpenParamsSchema },
    async (raw) => {
      metricsRecordToolStart("headless.validate_script");
      const t0 = Date.now();
      try {
        const p = OpenParamsSchema.parse(raw) as Record<string, unknown>;
        const scriptPath = String(p.path ?? "");
        if (!scriptPath) {
          metricsRecordToolEnd("headless.validate_script", false, Date.now() - t0);
          return errStructured("protocol.invalid_params", { app_code: "protocol.invalid_params" });
        }

        await headless.ensureDefaultSession(typeof p.projectPath === "string" ? p.projectPath : undefined);
        const res = await headless.rpc("script.validate_syntax", { path: scriptPath });
        const latency = Date.now() - t0;
        metricsRecordToolEnd("headless.validate_script", true, latency);

        return okStructured(successEnvelope("headless.validate_script", "script.validate_syntax", latency, res));
      } catch (e) {
        metricsRecordToolEnd("headless.validate_script", false, Date.now() - t0);
        return errStructured(e instanceof Error ? e.message : String(e));
      }
    },
  );
}

