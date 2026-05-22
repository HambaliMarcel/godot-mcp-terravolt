# Quick start

Goal: from zero to a working TerraVolt MCP session in **under 10 minutes**.

> Prereqs: Node 20+ on `PATH`, Godot 4.x stable (mono build recommended), git.

## 1. Clone and install

```powershell
git clone https://github.com/HambaliMarcel/godot-mcp-terravolt.git
cd "godot-mcp-terravolt"
npm install
npm run build:server
```

## 2. Point the router at your Godot 4 executable

Recommended Windows location (canonical, no admin needed):
`%LOCALAPPDATA%\Programs\Godot\Godot_v4.x.x-stable_mono_win64\`.

Auto-detect and write a profile to `.terravolt/godot-env.json`:

```powershell
npm run env:godot
```

The script prints the exact `TERRAVOLT_GODOT_BINARY` line for your shell. To
override manually:

```powershell
$env:TERRAVOLT_GODOT_BINARY = "C:\Users\<you>\AppData\Local\Programs\Godot\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe"
```

> Use the `_console.exe` flavor on Windows: TerraVolt parses
> `TERRAVOLT_HEADLESS_PORT=<port>` from stderr, and the non-console exe drops
> stderr by default.

## 3. (Optional) Link the addon to a Godot project

```powershell
npm run addon:link -- --project "C:\path\to\my-godot-project"
```

This symlinks `packages/godot-mcp-addon/` into the project as
`addons/terravolt_mcp/`. Enable it from **Project Settings → Plugins**. The
addon listens on `127.0.0.1:6505` by default.

## 4. Smoke test

With **no Godot editor running**, headless still works for parity methods:

```powershell
npm run dev:server -- --print-config
```

You should see JSON on stderr with `godotPort: 6505` and (after
`npm run env:godot`) a populated `godotBinaryEnv`.

For a full Godot smoke (`--version`):

```powershell
& $env:TERRAVOLT_GODOT_BINARY --version
```

Expected: `4.x.x.stable.mono.official.<sha>`.

## 5. Plug into Cursor

Add to your Cursor `mcp.json` (workspace or user):

```jsonc
{
  "mcpServers": {
    "terravolt-godot-mcp": {
      "command": "node",
      "args": ["packages/mcp-server/dist/index.js"],
      "env": {
        "TERRAVOLT_GODOT_BINARY": "C:\\Users\\<you>\\AppData\\Local\\Programs\\Godot\\Godot_v4.6.3-stable_mono_win64\\Godot_v4.6.3-stable_mono_win64_console.exe"
      }
    }
  }
}
```

Restart Cursor. The MCP tools panel should list `ping`, `server.info`,
`tools.list`, `tools.describe`, `tools.metrics`, `tools.bottlenecks`,
`context.fetch_raw`, `tools.health`, and the `headless.*` family.

## 6. Next steps

- `docs/guides/headless-only.md` — CI / no-editor workflow.
- `docs/guides/troubleshooting.md` — common failures and `autoHeal` hints.
- `docs/catalog/parity.md` — editor vs headless tool surface.
