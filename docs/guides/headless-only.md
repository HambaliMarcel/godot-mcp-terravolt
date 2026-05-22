# Headless-only workflow

When you cannot (or do not want to) keep the Godot editor open — typically CI,
remote agents, or large refactors — TerraVolt’s **§07 headless fallback**
keeps a subset of MCP tools alive.

## Prerequisites

- Godot 4.x executable on disk (Mono recommended for `.cs` projects).
- The router knows where it is via:
  - `--godot-binary <abs>` flag, or
  - `TERRAVOLT_GODOT_BINARY` env var, or
  - one of the canonical install dirs (`%LOCALAPPDATA%\Programs\Godot\**` on
    Windows; see `docs/support-matrix.md`).
- A Godot project path via `--project <abs>` or `TERRAVOLT_PROJECT_PATH`.

Detect/record the binary path once per machine:

```powershell
npm run env:godot
```

## How fallback works

1. Each MCP request first targets the daemon at `127.0.0.1:6505`.
2. If the WebSocket transport is **down** **and** the method has
   `headlessFallback: true` in `packages/shared/methods/registry.json`, the
   router spawns Godot as `--headless --path <project> --script
   addons/.../headless/headless_driver.gd` and replays the JSON-RPC call over a
   loopback TCP socket negotiated through the driver’s stderr handshake.
3. Successful headless calls report `method: "<method>@headless"` in the MCP
   envelope so the agent can see which path served the result.

## Tools that work fully headless today

| MCP tool                  | Path                       |
| ------------------------- | -------------------------- |
| `ping`                    | Editor + headless          |
| `server.info`             | Editor + headless          |
| `headless.start_project`  | Headless only              |
| `headless.stop`           | Headless only              |
| `headless.status`         | Headless only              |
| `headless.validate_script` | Headless only             |
| `tools.*` (`list`, `describe`, `metrics`, `bottlenecks`, `health`) | Router-local (no engine)     |
| `context.fetch_raw`       | Editor (raw daemon passthrough) |

Anything else still needs an editor session until §08 expands the catalog.

## CI sketch (GitHub Actions, Windows / Linux)

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: "20"
- name: Install Godot 4 (Linux)
  run: |
    curl -L -o /tmp/godot.zip https://downloads.tuxfamily.org/godotengine/4.6.3/Godot_v4.6.3-stable_mono_linux_x86_64.zip
    mkdir -p $HOME/.local/share/godot && unzip /tmp/godot.zip -d $HOME/.local/share/godot
    echo "TERRAVOLT_GODOT_BINARY=$(ls $HOME/.local/share/godot/**/Godot_v4.6.3-stable_mono_linux_x86_64)" >> $GITHUB_ENV
  if: runner.os == 'Linux'
- run: npm ci
- run: npm run lint
- run: npm run typecheck
- run: npm run build:server
- run: npm run test:server
- run: npm run catalog:sync
- run: npm run release:check
```

## Troubleshooting

See `docs/guides/troubleshooting.md` — the `autoHeal` hints emitted on each
error point at the right env var or flag.
