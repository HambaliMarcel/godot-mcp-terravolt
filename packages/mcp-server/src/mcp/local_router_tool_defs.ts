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

export const ROUTER_ONLY_TOOLS: RegisteredRouterTool[] = [
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

export type RouterOnlyToolName = "tools.list" | "tools.describe" | "tools.metrics" | "tools.health";

export function routerOnlyTool(name: RouterOnlyToolName): RegisteredRouterTool {
  const d = ROUTER_ONLY_TOOLS.find((t) => t.name === name);
  if (!d) throw new Error(`missing local router tool meta: ${name}`);
  return d;
}
