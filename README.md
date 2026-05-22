# TerraVolt Godot MCP

> **Cursor ↔ Godot 4** over the Model Context Protocol. Stdio MCP router bridging a persistent
> WebSocket to the editor plus a headless `--script` driver for everything you can do without the
> GUI open.

- Router version `0.1.0` · **Catalog version `0.17.0`** (registry @
  [`packages/shared/methods/registry.json`](packages/shared/methods/registry.json))
- **222 daemon methods** across **28 categories** (`scene`, `node`, `script`, `signal`, `resource`,
  `shader`, `asset`, `batch_refactor`, `editor`, `analysis`, `animation`, `animation_tree`,
  `physics`, `particle`, `navigation`, `runtime`, `tilemap`, `theme_ui`, `audio`, `input`,
  `scene_3d`, `testing`, `profile`, `export`, `macro`, `android`, plus bootstrap/observability)
- **13** first-class MCP router tools today (3 daemon-bridged, 6 router-local, 4 headless
  lifecycle); the remaining 222 daemon methods are reachable via `context.fetch_raw`
- Verified against **Godot 4.6.3.stable.mono.official**: **30/30** integration tests including a
  real `@modelcontextprotocol/sdk` end-to-end smoke and a 21-suite headless matrix

## Why this exists

| Want to…                                                                      | Today                                                                                                                                                                                                                           |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Drive the Godot editor from Cursor / any MCP client                           | Yes, when the editor is open and the TerraVolt addon is enabled (`ping`, `server.info`, `log.tail`, plus `context.fetch_raw` for early access to anything else the daemon exposes).                                             |
| Run GDScript compile checks without the editor open                           | Yes — `headless.validate_script` spawns `godot --headless --script headless_driver.gd` on demand.                                                                                                                               |
| Keep ping/info alive when the editor isn't running                            | Yes — registry rows with `headlessFallback: true` (currently `ping`, `server.info`) automatically retry against the headless coordinator. The MCP envelope reports `method: "<name>@headless"` so the caller can see the route. |
| Telemetry: what's slow, what's failing                                        | Yes — `tools.metrics`, `tools.bottlenecks`, `tools.health`.                                                                                                                                                                     |
| Self-healing error messages                                                   | Yes — `autoHeal` hints from `packages/shared/diagnostics/autoheal.json` are merged into errors unless `--disable-auto-heal` is passed.                                                                                          |
| Full editor catalog (scene tree, node tree, inspector, exports, run tests, …) | Backlog — see `docs/tasklist/08`, tracked under Linear `TER-41`.                                                                                                                                                                |

## Quick start (under 10 minutes)

```powershell
# 1. clone + install + build
git clone https://github.com/HambaliMarcel/godot-mcp-terravolt.git
cd godot-mcp-terravolt
npm install
npm run build:server

# 2. point the router at a Godot 4 binary
npm run env:godot
# writes .terravolt/godot-env.json and prints the env line to copy.

# 3. (optional) link the addon into your dev project
$env:TERRAVOLT_GODOT_PROJECT = "C:\path\to\my-godot-project"
npm run addon:link
# Then in Godot: Project Settings → Plugins → enable "TerraVolt MCP".

# 4. wire it into Cursor
# Add this to your workspace `.cursor/mcp.json` (or user-level `~/.cursor/mcp.json`):
```

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

Restart Cursor — the tool picker now shows `ping`, `server.info`, `log.tail`, `tools.*`,
`context.fetch_raw`, and the `headless.*` family.

Full step-by-step (with troubleshooting) lives in
**[`docs/guides/quick-start.md`](docs/guides/quick-start.md)**.

## Detailed guides

| Guide                                                   | Read it when…                                      |
| ------------------------------------------------------- | -------------------------------------------------- |
| [Quick start](docs/guides/quick-start.md)               | first install / wiring Cursor                      |
| [Use cases (rookie-friendly)](docs/guides/use-cases.md) | you want game-dev scenarios for every feature      |
| [MCP usage](docs/guides/mcp-usage.md)                   | you want `tools/call` payload shapes per tool      |
| [Tools reference](docs/guides/tools-reference.md)       | you need the authoritative parameter/result list   |
| [Godot integration](docs/guides/godot-integration.md)   | you want to understand the editor vs headless flow |
| [Headless-only workflow](docs/guides/headless-only.md)  | CI, agents, no display                             |
| [Troubleshooting](docs/guides/troubleshooting.md)       | something fails — start here                       |
| [FAQ](docs/faq.md)                                      | strategic / scope questions                        |
| [Support matrix](docs/support-matrix.md)                | OS + Godot + Node combos we test                   |
| [v1 release readiness](docs/release/v1-readiness.md)    | tracking ship gates                                |
| [Roadmap](docs/roadmap.md)                              | post-1.0 items                                     |

## What ships in this repo

| Path                                                     | What's there                                                                                            |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| [`packages/mcp-server/`](packages/mcp-server/)           | Node + TypeScript MCP router (`@terravolt/godot-mcp`). MCP stdio in, WebSocket + headless TCP out.      |
| [`packages/godot-mcp-addon/`](packages/godot-mcp-addon/) | Godot 4 addon: WebSocket JSON-RPC daemon, rotating logger, headless TCP driver, generated catalog meta. |
| [`packages/shared/`](packages/shared/)                   | Canonical JSON registries (methods, errors, autoheal hints).                                            |
| [`docs/`](docs/)                                         | SRS, tasklists `00–10`, guides, validation checkpoint, support matrix.                                  |
| [`tests/_fixtures/`](tests/_fixtures/)                   | Minimal Godot projects used by the integration tests (`empty/`, `with-addon/`).                         |
| [`scripts/`](scripts/)                                   | `env:godot`, `catalog:sync`, `release:notes`, `release:check`, `addon:link`, intel regen.               |
| [`.github/workflows/`](.github/workflows/)               | `lint.yml`, `unit.yml` (cross-OS), `release.yml` (tag-driven).                                          |

## Verifying your install

```powershell
npm run lint                # ESLint @terravolt/godot-mcp
npm run typecheck           # tsc --noEmit
npm run build:server        # tsc emit dist/
npm run test:server         # 30 tests; real Godot integration auto-skips when binary missing
npm run catalog:sync        # regenerates _generated/catalog_meta.gd (catalog 0.17.0)
npm run coverage:report     # docs/coverage/catalog-coverage.md (222 tools, 28 categories)
npm run validate:catalog    # registry integrity + headless dispatch + error mirror gate
npm run release:check       # 5/5 gates (hash, version, error mirror, readiness, CHANGELOG)
```

To exercise real Godot interaction:

```powershell
$env:TERRAVOLT_GODOT_BINARY = (Get-Content .terravolt/godot-env.json | ConvertFrom-Json).godotBinary
npm run test:server         # now also runs the real-Godot integration + addon parse-check
```

## Status

Phases 1–4 (tasklists `00`–`26`) are in master with full real-Godot end-to-end coverage. Tracker:
**[`docs/validation/tv-00-25-checkpoint.md`](docs/validation/tv-00-25-checkpoint.md)**.

| Tasklist                          | State                                                                 |
| --------------------------------- | --------------------------------------------------------------------- |
| `00–01` Foundation + repo         | green                                                                 |
| `02–04` Addon + WS + JSON-RPC     | green                                                                 |
| `05–06` Router + shared catalog   | green                                                                 |
| `07` Headless fallback            | green — **201/222** methods headless-safe                             |
| `08` ~200 method catalog          | green — **222** methods @ catalog `0.17.0`                            |
| `09` Context / errors / telemetry | green — **130** error codes, `tools.bottlenecks`, `autoHeal`          |
| `10` QA / release / docs          | green — **30/30** tests, `release:check`, user guides                 |
| `11–24` Per-category catalog      | green — handlers + headless ops + integration tests + docs            |
| `25` Completion gate              | green — coverage report, parity matrix, validation checkpoint         |
| `26` Android + scenario           | green — `android.*` (3) + `testing.run_scenario` ship the 222 stretch |

## Contributing

- [`AGENTS.md`](AGENTS.md) — canonical agent-facing readme for this repo.
- [`CLAUDE.md`](CLAUDE.md) — Claude-specific routing notes.
- [`docs/contributing/agent-guidelines.md`](docs/contributing/agent-guidelines.md) — safety +
  branching.
- [`docs/contributing/git-hooks.md`](docs/contributing/git-hooks.md) — optional commit-msg hook.
- [`docs/contributing/windows-godot-portable.md`](docs/contributing/windows-godot-portable.md) —
  Windows-specific install notes.

## Governance

[`LICENSE`](LICENSE) · [`CONTRIBUTING.md`](CONTRIBUTING.md) ·
[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) · [`SECURITY.md`](SECURITY.md) ·
[`CHANGELOG.md`](CHANGELOG.md)

## Reference clones (local, not vendored)

```bash
git clone --depth 1 https://github.com/godotengine/godot-docs.git references/godot-docs
git clone --depth 1 https://github.com/youichi-uda/godot-mcp-pro.git references/godot-mcp-pro
git clone --depth 1 https://github.com/tomyud1/godot-mcp.git references/godot-mcp-tomyud1
git clone --depth 1 https://github.com/Coding-Solo/godot-mcp.git references/godot-mcp-coding-solo
```

Architectural comparison:
**[`docs/references/reference-repos-map.md`](docs/references/reference-repos-map.md)**.

## Code intelligence

This repo is indexed by GitNexus and Graphify:

```powershell
npm run omni:intel          # runs intel:gitnexus, intel:graphs, intel:graphify
```

See [`AGENTS.md`](AGENTS.md) for the embedded GitNexus block describing when to call
`gitnexus_query`, `gitnexus_impact`, and friends from inside Cursor.
