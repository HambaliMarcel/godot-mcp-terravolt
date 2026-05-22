import { z } from "zod";

import type { RegisteredRouterTool } from "../tools/registry.js";

export const ToolsListSchema = z
  .object({
    category: z.string().optional(),
    safe: z.boolean().optional(),
  })
  .strict();

export const ToolsDescribeSchema = z
  .object({
    name: z.string().min(1),
  })
  .strict();

/** Open object for MCP args before AJV validates against daemon `inputSchema` from the registry. */
export const OpenParamsSchema = z.record(z.string(), z.unknown());

export const ToolsBottlenecksSchema = z
  .object({
    topN: z.number().int().min(1).max(100).optional(),
  })
  .strict();

export const ContextFetchRawSchema = z
  .object({
    method: z.string().min(1),
    params: z.record(z.string(), z.unknown()).optional(),
  })
  .strict();

/** Router-native MCP tools (underscore ids — universal MCP host compatibility). */
export const ROUTER_ONLY_TOOLS: RegisteredRouterTool[] = [
  {
    kind: "local",
    name: "tools_list",
    title: "List MCP tools",
    description: "List MCP tools with optional filters: category(string), safe(boolean).",
    category: "tools",
    safe: true,
    mutates: false,
    requiresEditor: false,
    requiresRuntime: false,
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
    name: "tools_describe",
    title: "Describe MCP tool",
    description: "Return metadata + schemas for one tool from the compiled router snapshot.",
    category: "tools",
    safe: true,
    mutates: false,
    requiresEditor: false,
    requiresRuntime: false,
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
    name: "tools_metrics",
    title: "Router metrics",
    description: "Rolling tool-call telemetry required by Phase 2 tasklist 06.",
    category: "tools",
    safe: true,
    mutates: false,
    requiresEditor: false,
    requiresRuntime: false,
    inputSchemaJson: { type: "object", additionalProperties: false },
    outputSchemaJson: { type: "object" },
  },
  {
    kind: "local",
    name: "tools_bottlenecks",
    title: "tools_bottlenecks",
    description: "§09 — tools ranked by rolling average latency.",
    category: "tools",
    safe: true,
    mutates: false,
    requiresEditor: false,
    requiresRuntime: false,
    inputSchemaJson: {
      type: "object",
      properties: { topN: { type: "integer", minimum: 1, maximum: 100 } },
      additionalProperties: false,
    },
    outputSchemaJson: { type: "object" },
  },
  {
    kind: "local",
    name: "context_fetch_raw",
    title: "context_fetch_raw",
    description: "§09 — execute a JSON-RPC method on the daemon (pointer sugar; no envelope yet).",
    category: "tools",
    safe: true,
    mutates: false,
    requiresEditor: false,
    requiresRuntime: false,
    inputSchemaJson: {
      type: "object",
      required: ["method"],
      properties: {
        method: { type: "string", minLength: 1 },
        params: { type: "object" },
      },
      additionalProperties: false,
    },
    outputSchemaJson: { type: "object" },
  },
  {
    kind: "local",
    name: "tools_health",
    title: "tools_health",
    description: "AJV sanity + daemon server.info probe + SHA256 parity for catalog JSON.",
    category: "tools",
    safe: true,
    mutates: false,
    requiresEditor: false,
    requiresRuntime: false,
    inputSchemaJson: { type: "object", additionalProperties: false },
    outputSchemaJson: { type: "object" },
  },
];

export type RouterOnlyToolName =
  | "tools_list"
  | "tools_describe"
  | "tools_metrics"
  | "tools_health"
  | "tools_bottlenecks"
  | "context_fetch_raw";

export function routerOnlyTool(name: RouterOnlyToolName): RegisteredRouterTool {
  const d = ROUTER_ONLY_TOOLS.find((t) => t.name === name);
  if (!d) throw new Error(`missing local router tool meta: ${name}`);
  return d;
}
