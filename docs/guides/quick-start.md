# Quick start

Goal: from zero to a working Terravolt MCP session in **under 10 minutes**.

> Prereqs: **Node ≥ 20.10** on `PATH`, **Godot 4.x stable** (mono build recommended for `.cs`
> projects), git, and any MCP-capable client (Cursor Desktop is the primary target).

## 1. Clone, install, build

```powershell
git clone https://github.com/HambaliMarcel/godot-mcp-terravolt.git
cd godot-mcp-terravolt
npm install
npm run build:server
```

This compiles `packages/mcp-server/dist/index.js` — that's the binary Cursor will spawn over stdio.

## 2. Point the router at your Godot 4 executable

Recommended Windows location (canonical, no admin needed):

```
%LOCALAPPDATA%\Programs\Godot\Godot_v4.x.x-stable_mono_win64\
```

Auto-detect + write a profile to `.terravolt/godot-env.json`:

```powershell
npm run env:godot
```

The script prints the exact `TERRAVOLT_GODOT_BINARY=…` line for your shell. To override manually:

```powershell
$env:TERRAVOLT_GODOT_BINARY = "C:\Users\<you>\AppData\Local\Programs\Godot\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe"
```

> Use the `_console.exe` flavor on Windows: Terravolt parses `TERRAVOLT_HEADLESS_PORT=<port>` from
> stderr, and the non-console exe drops stderr by default.

Validate the binary actually works:

```powershell
& $env:TERRAVOLT_GODOT_BINARY --version
# expected: 4.x.x.stable.mono.official.<sha>
```

## 3. (Optional) Link the addon into a Godot project

If you want **editor mode** (faster `ping`, full daemon catalog), stage the addon into your dev
project:

```powershell
$env:TERRAVOLT_GODOT_PROJECT = "C:\path\to\my-godot-project"
npm run addon:link
```

This symlinks (or copies, if junction creation fails) `packages/godot-mcp-addon/` into the project
as `addons/terravolt_mcp/`. Then in Godot:

1. **Project → Project Settings → Plugins → enable “Terravolt MCP”.**
2. The bottom panel **Terravolt MCP** appears with Start/Stop/Restart and a live status indicator.
3. The daemon listens on `127.0.0.1:6505` (override in **Project Settings →
   terravolt_mcp/server/port**).

Skip this step if you only need the **headless mode** tools — those work without the addon being
mounted.

## 4. Smoke test

Print the resolved config (JSON on stderr) — sanity-checks env vars + flags:

```powershell
node packages/mcp-server/dist/index.js --print-config
```

Expect a `godotBinaryEnv` value pointing at the binary you set, plus `godotPort: 6505`.

If `TERRAVOLT_GODOT_BINARY` is set you can also run the full real-Godot integration tests:

```powershell
npm run test:server
# 43/43 tests pass: smoke, unit (incl. transport resilience + hybrid_mode), real-Godot
# integration (21 headless suites incl. android.*, an exhaustive 156/156 coverage smoke
# that dispatches every safe catalog method, plus mode_status + _mode override e2e).
npm run validate:catalog
# Registry integrity + headless dispatch gate (tasks 25 + 26).
npm run release:check
# Catalog hash + 130 app error codes + readiness gate.
```

## 5. Plug into Cursor

Add to your Cursor `mcp.json` (workspace `.cursor/mcp.json` or `~/.cursor/mcp.json`):

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

Restart Cursor. The MCP tools panel lists **14 router tools**; the full **222-method** catalog
(`catalog_version` 0.17.0) is available via `context_fetch_raw`:

- `ping`, `server_info`, `log_tail`
- `tools_list`, `tools_describe`, `tools_metrics`, `tools_bottlenecks`, `tools_health`,
  `mode_status`, `context_fetch_raw`
- `headless_start_project`, `headless_status`, `headless_stop`, `headless_validate_script`

### Hybrid mode (head ↔ headless)

Terravolt is **hybrid by default**:

- When the **Godot editor is open** (with the addon enabled), every daemon-bridged tool talks to the
  live window — you see edits land in real time.
- When the editor is **not** available, the router auto-spawns a **headless Godot** session and
  serves the same call from disk state. The 201 `headlessFallback: true` methods continue to work.

Every response carries a `route_mode` so you always know who served the call:

```jsonc
{ "ok": true, "tool": "scene_list", "method": "scene.list@editor",   "route_mode": "editor",   "result": {...} }
{ "ok": true, "tool": "scene_list", "method": "scene.list@headless", "route_mode": "headless", "result": {...} }
```

Call `mode_status` for a one-shot hybrid snapshot:

```jsonc
{
  "result": {
    "editor": { "alive": true, "port": 6505, "catalog_version": "0.17.0", "hello_received": true },
    "headless": { "alive": false, "available": true },
    "recommended_mode": "editor",
    "hybrid_ready": true,
    "advice": [
      "Hybrid ready: editor will serve calls by default; pass `_mode: \"headless\"` per tool call to force the headless path.",
    ],
  },
}
```

You can also **force a path per call** by adding `_mode` to any daemon-bridged tool's arguments:

- `_mode: "auto"` (default) — editor first, headless on transport error.
- `_mode: "editor"` — never fall back; surface the editor error if it's not reachable.
- `_mode: "headless"` — skip the WebSocket entirely; useful for parity testing or while another
  client owns the editor's single peer slot.

The `_mode` field is stripped before the daemon receives the payload.

Example category calls via `context.fetch_raw`:

```jsonc
{ "method": "scene.list", "params": {} }
{ "method": "macro.basic_2d_level", "params": { "project_path": "C:\\path\\to\\game", "dry_run": true } }
{ "method": "input.list_actions", "params": {} }
{ "method": "export.list_presets", "params": {} }
{ "method": "android.list_devices", "params": {} }
{ "method": "testing.run_scenario", "params": { "steps": [{ "type": "wait", "seconds": 0.05 }] } }
```

Per-tool payloads live in **[`mcp-usage.md`](mcp-usage.md)** and full parameter/result schemas in
**[`tools-reference.md`](tools-reference.md)**.

## 6. Verify the connection

In Cursor (or any MCP client) call `tools.health` with `{}`. A healthy response has:

```jsonc
{
  "ok": true,
  "result": {
    "checks": {
      "ajv_object_ok": true,
      "daemon_server_info_ok": true, // true if editor + addon running
      "protocol_catalog_match": true, // catalog SHA matches between sides
      "headless_godot_executable_resolvable": true,
      "pass": true,
    },
  },
}
```

If `daemon_server_info_ok: false` but `headless_godot_executable_resolvable: true`, the router will
still serve `ping`, `server.info`, `headless.start_project`, `headless.validate_script`, etc. —
fallback works.

When `daemon_server_info_ok` is `false` the response now includes a `transport_diagnostics` block
with the actual cause:

```jsonc
{
  "transport_diagnostics": {
    "url": "ws://127.0.0.1:6505",
    "port_reachable": true,
    "hello_received": false,
    "last_close_code": 1008,
    "last_close_reason": "policy violation: server busy",
    "peer_busy_count": 3,
    "likely_cause": "transport.peer_busy",
    "hint": "Only one MCP client allowed per Godot editor. Close other Cursor windows / scripts, then restart this MCP server.",
  },
}
```

`likely_cause` is one of:

- `transport.port_closed` — Godot isn't open in **editor** mode. Run
  `Godot.exe --path <project> --editor` and enable the Terravolt MCP plugin (don't press **F5**; the
  game window does not host the MCP server).
- `transport.peer_busy` — another MCP client owns the peer slot. The addon now defaults to
  `max_peers = 2` and auto-evicts stale peers on the next handshake. If a real zombie client is
  connected, call `server_force_disconnect` from this client (once it briefly connects), click
  **Restart** on the Terravolt MCP dock, or kill the stale `node packages/mcp-server/dist/index.js`
  process(es).
- `transport.persistent_peer_busy` — sustained `peer_busy` (10+ rejects in a row) tripped the
  router's circuit breaker. Reconnects are paused at the max backoff to stop the storm. After you
  clear the stale peer, call **`transport_reset`** to clear the circuit and resume reconnects
  immediately.
- `transport.no_session` — port listens, but the daemon never promoted us to `ready`. Restart the
  Terravolt MCP server from the editor bottom panel.

### Recovering from a `peer_busy` storm

If `tools_health` shows `circuit_broken: true` or you see thousands of `peer_busy` lines in the
Godot log, the most common cause is multiple Node.js MCP processes leaking from previous Cursor
sessions. Cleanup:

```powershell
# Windows / PowerShell
Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" |
  Where-Object { $_.CommandLine -like "*Godot MCP Marcel*dist*" } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
```

```bash
# macOS / Linux
pkill -f 'packages/mcp-server/dist/index.js'
```

Then restart the Terravolt MCP server from Cursor's MCP settings and click **Restart** on the Godot
Terravolt MCP dock. Calling `transport_reset` will also force one immediate reconnect.

## 7. Next steps

- **[`mcp-usage.md`](mcp-usage.md)** — concrete `tools/call` payloads.
- **[`tools-reference.md`](tools-reference.md)** — parameter + result reference.
- **[`godot-integration.md`](godot-integration.md)** — editor ↔ headless flow.
- **[`headless-only.md`](headless-only.md)** — CI / agents.
- **[`troubleshooting.md`](troubleshooting.md)** — known failure modes.
- **[`../catalog/parity.md`](../catalog/parity.md)** — editor vs headless parity.
