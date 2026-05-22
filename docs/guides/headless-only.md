# Headless-only workflow

When you cannot (or do not want to) keep the Godot editor open — typically CI, remote agents, or
large refactors — Terravolt’s **§07 headless fallback** keeps a subset of MCP tools alive.

## Prerequisites

- Godot 4.x executable on disk (Mono recommended for `.cs` projects).
- The router knows where it is via:
  - `--godot-binary <abs>` flag, or
  - `TERRAVOLT_GODOT_BINARY` env var, or
  - one of the canonical install dirs (`%LOCALAPPDATA%\Programs\Godot\**` on Windows; see
    `docs/support-matrix.md`).
- A Godot project path via `--project <abs>` or `TERRAVOLT_PROJECT_PATH`.

Detect/record the binary path once per machine:

```powershell
npm run env:godot
```

## How fallback works

1. Each daemon-bridged MCP request first targets `TERRAVOLT_GODOT_HOST:TERRAVOLT_GODOT_PORT`
   (default `127.0.0.1:6505`).
2. If the WebSocket transport is **down** **and** the method has `headlessFallback: true` in
   `packages/shared/methods/registry.json` (today that means `ping` and `server.info`), the router
   asks the headless coordinator to spawn:
   ```text
   godot --headless --path <project> --script <abs path>/headless_driver.gd
   ```
   and replays the JSON-RPC call over a loopback TCP socket whose port the driver writes to stderr
   (`TERRAVOLT_HEADLESS_PORT=<n>`).
3. Successful headless calls report `method: "<method>@headless"` in the MCP envelope, so the agent
   can see which path served the result.

`packages/mcp-server/tests/integration/mcp_e2e.test.mjs` exercises this fallback against a real
Godot binary by forcing the daemon WS to fail (`--godot-port 1`) and asserting the `ping` result
reports `method: "ping@headless"` in under 200 ms.

## Tools that work fully headless today

| MCP tool                                                         | Path                              |
| ---------------------------------------------------------------- | --------------------------------- |
| `ping`                                                           | Editor + headless (auto fallback) |
| `server.info`                                                    | Editor + headless (auto fallback) |
| `headless.start_project`                                         | Headless only                     |
| `headless.stop`                                                  | Headless only                     |
| `headless.status`                                                | Headless only                     |
| `headless.validate_script`                                       | Headless only (GDScript today)    |
| `tools.list` / `describe` / `metrics` / `bottlenecks` / `health` | Router-local (no engine)          |
| `context.fetch_raw`                                              | Editor (raw daemon passthrough)   |
| `log.tail`                                                       | Editor only                       |

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
- run: npm run test:server # 11/11 incl. real-Godot integration when binary present
- run: npm run catalog:sync
- run: npm run release:check
```

## See also

- `docs/guides/quick-start.md` — first install + smoke.
- `docs/guides/mcp-usage.md` — concrete `tools/call` payloads.
- `docs/guides/tools-reference.md` — full parameter/result schema.
- `docs/guides/godot-integration.md` — flow diagrams.
- `docs/catalog/parity.md` — editor vs headless parity matrix.

## Troubleshooting

See `docs/guides/troubleshooting.md` — the `autoHeal` hints emitted on each error point at the right
env var or flag.
