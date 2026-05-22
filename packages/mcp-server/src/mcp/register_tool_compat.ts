import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

import { toMcpToolName } from "./mcp_tool_name.js";

/** MCP SDK `registerTool` + Zod can overflow TS instantiation depth; handlers stay typed locally. */
export function registerToolCompat(
  server: McpServer,
  name: string,
  config: {
    title: string;
    description: string;
    inputSchema?: unknown;
  },
  handler: (rawArgs: unknown, extra: { signal: AbortSignal }) => Promise<unknown>,
): void {
  const mcpName = toMcpToolName(name);
  (server.registerTool as unknown as (toolName: string, cfg: unknown, fn: typeof handler) => void)(
    mcpName,
    config,
    handler,
  );
}
