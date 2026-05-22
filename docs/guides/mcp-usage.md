# Using the TerraVolt MCP

This guide is the hands-on counterpart to `docs/guides/tools-reference.md`. It shows the **shapes**
Cursor (and any MCP-compatible client) sees over stdio JSON-RPC, plus a programmatic Node example
that mirrors how the end-to-end tests drive the router.

## 1. Wire the router into your client

Cursor `mcp.json` (workspace or `~/.cursor/mcp.json`):

```jsonc
{
  "mcpServers": {
    "terravolt-godot-mcp": {
      "command": "node",
      "args": ["packages/mcp-server/dist/index.js"],
      "env": {
        "TERRAVOLT_GODOT_BINARY": "C:\\Users\\<you>\\AppData\\Local\\Programs\\Godot\\Godot_v4.6.3-stable_mono_win64\\Godot_v4.6.3-stable_mono_win64_console.exe",
        "TERRAVOLT_PROJECT_PATH": "C:\\path\\to\\my-godot-project",
      },
    },
  },
}
```

CLI flags (alternative to env vars):

```text
node packages/mcp-server/dist/index.js \
  --godot-binary "C:\…\_console.exe" \
  --project       "C:\…\my-godot-project" \
  --godot-host    127.0.0.1   --godot-port 6505 \
  --connect-timeout-ms       5000 \
  --request-timeout-ms      30000 \
  --headless-boot-timeout-ms 30000 \
  --headless-op-timeout-ms  60000 \
  --metrics-window-sec        300 \
  --log-level                info
  # --disable-auto-heal
```

Run `node packages/mcp-server/dist/index.js --print-config` to see the fully-resolved configuration
on stderr (the same JSON the router boots with).

## 2. Per-tool examples (`tools/call` payloads)

> All examples below are the `params.arguments` body for an MCP `tools/call` request. Cursor
> surfaces the same fields in its tool picker UI.

### Health gate

```jsonc
// tools/call → tools.health → {}
{}
```

A healthy result has `result.checks.pass: true` and `result.checks.protocol_catalog_match: true`.

### Discover tools

```jsonc
// tools.list
{ "category": "headless", "safe": true }

// tools.describe
{ "name": "headless.validate_script" }
```

### Pure daemon ping (with auto fallback)

```jsonc
// ping  (no args)
{}
```

When the editor is open with the addon enabled, the response shows `method: "ping"` and
`result.roundTripMs` is the WS round trip. When the editor is closed and the headless coordinator
can spawn Godot, the response shows `method: "ping@headless"` instead.

### Headless lifecycle

```jsonc
// headless.start_project — boots Godot --headless against the project
{ "projectPath": "C:\\path\\to\\my-godot-project" }

// headless.status
{}

// headless.validate_script — compile a GDScript file
{
  "path": "C:\\path\\to\\my-godot-project\\addons\\foo\\bar.gd",
  "projectPath": "C:\\path\\to\\my-godot-project"   // optional override
}

// headless.stop
{ "force": true }
```

### Pass-through to a daemon method not yet wrapped

```jsonc
// context.fetch_raw — only when the daemon (editor mode) is running
{ "method": "log.tail", "params": { "lines": 50, "level": "warn" } }
```

### Performance triage

```jsonc
// tools.metrics
{}

// tools.bottlenecks
{ "topN": 5 }
```

## 3. Driving the router from Node (mirrors the E2E test)

The script below is a stripped version of `packages/mcp-server/tests/integration/mcp_e2e.test.mjs`.
It spawns the router as a real MCP server and exercises `tools/list` plus the headless lifecycle.

```js
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const transport = new StdioClientTransport({
  command: process.execPath,
  args: ["packages/mcp-server/dist/index.js"],
  env: {
    ...process.env,
    TERRAVOLT_GODOT_BINARY: "C:\\…\\Godot_v4.6.3-stable_mono_win64_console.exe",
    TERRAVOLT_PROJECT_PATH: "C:\\path\\to\\my-godot-project",
  },
});
const client = new Client({ name: "my-agent", version: "0.0.1" }, { capabilities: { tools: {} } });

await client.connect(transport);
const tools = await client.listTools();
console.log(
  "tools:",
  tools.tools.map((t) => t.name),
);

const start = await client.callTool({
  name: "headless.start_project",
  arguments: { projectPath: "C:\\path\\to\\my-godot-project" },
});
console.log("start:", start.structuredContent);

const ping = await client.callTool({ name: "ping", arguments: {} });
console.log("ping route:", ping.structuredContent.method);
// Prints "ping@headless" if no editor is running.

await client.callTool({ name: "headless.stop", arguments: { force: true } });
await client.close();
```

## 4. Result envelope

Every tool returns a structured payload (`tools/call`'s `structuredContent`):

```jsonc
{
  "ok": true,
  "tool": "headless.start_project",
  "method": "headless", // or daemon JSON-RPC, or "<m>@headless"
  "latencyMs": 1843,
  "result": {
    "ready": true,
    "alive": true,
    "pid": 17480,
    "host": "127.0.0.1",
    "port": 54321,
    "projectPath": "C:\\…",
    "uptimeMs": 18,
  },
}
```

Errors share the shape:

```jsonc
{
  "ok": false,
  "message": "headless.binary_missing",
  "app_code": "headless.binary_missing",
  "autoHeal": { "hint": "...", "steps": ["..."] },
}
```

The router also surfaces the same payload in `content[0].text` (JSON stringified) so non-structured
clients still see the data.

## 5. Operational tips

- **Editor vs headless:** the editor path is faster (`<10 ms` for `ping`), the headless path needs a
  `~1–3 s` cold start. Keep the editor open while iterating; use headless from CI or when running
  large compile checks.
- **Catalog drift:** if `tools.health` reports `protocol_catalog_mismatch_detected`, run
  `npm run catalog:sync` and restart both router and editor.
- **Profile latency:** poll `tools.metrics` periodically; treat the top three entries from
  `tools.bottlenecks` as the budget your agent should respect (§09).
- **Disable autoHeal in CI** if you want compact error logs: `--disable-auto-heal`.

## See also

- `docs/guides/quick-start.md`
- `docs/guides/tools-reference.md`
- `docs/guides/godot-integration.md`
- `docs/guides/headless-only.md`
