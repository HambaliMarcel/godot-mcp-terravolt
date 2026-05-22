/** Shared with registry builders — keep in sync with packages/mcp-server/src/mcp/mcp_tool_name.ts */
export const MCP_TOOL_NAME_PATTERN = /^[A-Za-z0-9_]+$/;

export function toMcpToolName(catalogName) {
  return catalogName.replace(/\./g, "_");
}

export function assertMcpToolName(name) {
  if (!MCP_TOOL_NAME_PATTERN.test(name)) {
    throw new Error(`invalid MCP tool name (use underscores, not dots): ${name}`);
  }
}
