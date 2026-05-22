import { strict as assert } from "node:assert";
import test from "node:test";

import {
  MCP_TOOL_NAME_PATTERN,
  resolveMcpToolName,
  toMcpToolName,
} from "../../dist/mcp/mcp_tool_name.js";

test("toMcpToolName replaces dots with underscores", () => {
  assert.equal(toMcpToolName("scene.list"), "scene_list");
  assert.equal(toMcpToolName("tools.health"), "tools_health");
  assert.equal(toMcpToolName("ping"), "ping");
});

test("resolveMcpToolName accepts legacy dotted names", () => {
  assert.equal(resolveMcpToolName("server.info"), "server_info");
  assert.equal(resolveMcpToolName("server_info"), "server_info");
});

test("MCP tool names match host-safe pattern", () => {
  const samples = ["ping", "scene_list", "headless_start_project", "macro_basic_2d_level"];
  for (const s of samples) {
    assert.ok(MCP_TOOL_NAME_PATTERN.test(s), s);
  }
  assert.ok(!MCP_TOOL_NAME_PATTERN.test("scene.list"));
});
