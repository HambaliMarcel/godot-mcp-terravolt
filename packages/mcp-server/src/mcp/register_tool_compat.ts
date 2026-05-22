import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

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
  (server.registerTool as unknown as (toolName: string, cfg: unknown, fn: typeof handler) => void)(
    name,
    config,
    handler,
  );
}
