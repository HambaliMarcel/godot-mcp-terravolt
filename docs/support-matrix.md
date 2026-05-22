# Support matrix

Validated combinations for the TerraVolt Godot MCP stack. Update every release per
`docs/tasklist/10 §10.6.10`.

## Engine + runtime

| OS                                | Godot 4.x          | Node      | Editor mode | Headless mode |
| --------------------------------- | ------------------ | --------- | ----------- | ------------- |
| Windows 10/11 x64                 | 4.6.x stable mono  | 20 LTS+   | Supported   | Supported     |
| macOS 13+ (Apple Silicon / Intel) | 4.6.x stable       | 20 LTS+   | Supported   | Supported     |
| Linux (Ubuntu 22.04+, Fedora 39+) | 4.6.x stable       | 20 LTS+   | Supported   | Supported     |
| Older OSes                        | Best effort        | Best effort | Best effort | Best effort   |

Godot 3.x is **not** supported.

## Canonical Godot install paths

| OS      | Recommended location |
| ------- | -------------------- |
| Windows | `%LOCALAPPDATA%\Programs\Godot\Godot_v4.x.x-stable_mono_win64\` (auto-detected) |
| macOS   | `/Applications/Godot.app/` or `/Applications/Godot 4.app/` |
| Linux   | `/usr/local/bin/godot4` or `~/.local/share/godot/godot` |

The router’s **`resolveGodotBinary`** scans these locations recursively (one
level deep) and prefers a `*_console.exe` variant on Windows so stderr (used by
the headless port handshake) is reliable.

Override with **`--godot-binary <abs>`** or
**`TERRAVOLT_GODOT_BINARY=<abs>`**.

## Node engine

`packages/mcp-server/package.json` declares `engines.node >= 20.10`.

## Cursor / MCP client

The router speaks MCP over stdio (SDK ≥ 1.29). Any compliant MCP client should
work; Cursor Desktop is the primary target.

## Mono / .NET

C# projects require Godot’s Mono build (chosen here). `--build-solutions` and
`headless.run_tests` flows assume the .NET SDK is installed and on `PATH`.

## Cross-references

- `docs/guides/quick-start.md` — first-run install + smoke test.
- `docs/guides/headless-only.md` — CI-style usage without the editor.
- `docs/catalog/parity.md` — which MCP tools work in editor vs headless.
- `docs/release/v1-readiness.md` — release gate checklist.
