# Quick start

Goal: from zero to a working TerraVolt MCP session in **under 10 minutes**.

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

> Use the `_console.exe` flavor on Windows: TerraVolt parses `TERRAVOLT_HEADLESS_PORT=<port>` from
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

1. **Project → Project Settings → Plugins → enable “TerraVolt MCP”.**
2. The bottom panel **TerraVolt MCP** appears with Start/Stop/Restart and a live status indicator.
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
# 30/30 tests pass: smoke, unit, real-Godot integration (21 headless suites incl. android.*).
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

Restart Cursor. The MCP tools panel lists **13 router tools**; the full **222-method** catalog
(`catalog_version` 0.17.0) is available via `context.fetch_raw`:

- `ping`, `server.info`, `log.tail`
- `tools.list`, `tools.describe`, `tools.metrics`, `tools.bottlenecks`, `tools.health`,
  `context.fetch_raw`
- `headless.start_project`, `headless.status`, `headless.stop`, `headless.validate_script`

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

## 7. Next steps

- **[`mcp-usage.md`](mcp-usage.md)** — concrete `tools/call` payloads.
- **[`tools-reference.md`](tools-reference.md)** — parameter + result reference.
- **[`godot-integration.md`](godot-integration.md)** — editor ↔ headless flow.
- **[`headless-only.md`](headless-only.md)** — CI / agents.
- **[`troubleshooting.md`](troubleshooting.md)** — known failure modes.
- **[`../catalog/parity.md`](../catalog/parity.md)** — editor vs headless parity.
