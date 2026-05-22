/** MCP tool ids must be `[A-Za-z0-9_]+` (Cursor, Claude Desktop, VS Code MCP, etc.). */
export const MCP_TOOL_NAME_PATTERN = /^[A-Za-z0-9_]+$/;

/** Map catalog/daemon dotted ids to MCP-safe tool names. */
export function toMcpToolName(catalogName: string): string {
  return catalogName.replace(/\./g, "_");
}

/** Accept legacy dotted names from prompts/docs; return registered MCP tool id. */
export function resolveMcpToolName(name: string): string {
  if (MCP_TOOL_NAME_PATTERN.test(name)) return name;
  return toMcpToolName(name);
}

export function assertMcpToolName(name: string): void {
  if (!MCP_TOOL_NAME_PATTERN.test(name)) {
    throw new Error(`invalid MCP tool name (use underscores, not dots): ${name}`);
  }
}
