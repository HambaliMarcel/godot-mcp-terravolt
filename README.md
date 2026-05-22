# Terravolt Godot MCP

> **Cursor ↔ Godot 4** over the Model Context Protocol. Stdio MCP router bridging a persistent
> WebSocket to the editor plus a headless `--script` driver for everything you can do without the
> GUI open.

- Router version **`0.1.0`** · catalog version **`0.17.0`**
  ([`packages/shared/methods/registry.json`](packages/shared/methods/registry.json))
- **222 daemon methods** across **28 categories** (`scene`, `node`, `script`, `signal`, `resource`,
  `shader`, `asset`, `batch_refactor`, `editor`, `analysis`, `animation`, `animation_tree`,
  `physics`, `particle`, `navigation`, `runtime`, `tilemap`, `theme_ui`, `audio`, `input`,
  `scene_3d`, `testing`, `profile`, `export`, `macro`, `android`, plus bootstrap/observability)
- **13** first-class MCP router tools (3 daemon-bridged, 6 router-local, 4 headless lifecycle); the
  remaining daemon methods are reachable via `context.fetch_raw`
- **201/222** methods support **headless fallback** (no editor open)
- Verified against **Godot 4.6.3.stable.mono.official**: **31/31** integration tests, including a
  real `@modelcontextprotocol/sdk` end-to-end smoke, a 21-suite headless matrix, and an exhaustive
  coverage smoke that dispatches **156/156** safe candidate methods from the headless-capable
  catalog (no method-not-found responses on the live daemon)

Phases 1–4 (tasklists **`00`–`26`**) are complete on `master`. Validation tracker:
[`docs/validation/tv-00-25-checkpoint.md`](docs/validation/tv-00-25-checkpoint.md).

---

## Why this exists

| Want to…                                                               | Today                                                                                                                                                                                                       |
| ---------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Drive the Godot editor from Cursor / any MCP client                    | Yes, when the editor is open and the Terravolt addon is enabled (`ping`, `server.info`, `log.tail`, plus `context.fetch_raw` for the full catalog).                                                         |
| Run GDScript compile checks without the editor open                    | Yes — `headless.validate_script` spawns `godot --headless --script headless_driver.gd` on demand.                                                                                                           |
| Keep ping/info alive when the editor isn't running                     | Yes — registry rows with `headlessFallback: true` (**201/222**) automatically retry against the headless coordinator. The MCP envelope reports `method: "<name>@headless"` so the caller can see the route. |
| Telemetry: what's slow, what's failing                                 | Yes — `tools.metrics`, `tools.bottlenecks`, `tools.health`.                                                                                                                                                 |
| Self-healing error messages                                            | Yes — `autoHeal` hints from `packages/shared/diagnostics/autoheal.json` are merged into errors unless `--disable-auto-heal` is passed.                                                                      |
| Full catalog (scene tree, nodes, scripts, exports, runtime, macros, …) | Yes — **222 methods** via the editor daemon or headless TCP; Cursor reaches them through **`context.fetch_raw`** (per-category MCP router tools beyond the current 13 are backlog TER-41).                  |

---

## Ready to use?

| Layer                      | Status                                                             |
| -------------------------- | ------------------------------------------------------------------ |
| Code + tests on `master`   | Ready — **31/31** tests, `release:check` green                     |
| Godot 4.x binary           | Run `npm run env:godot` → writes `.terravolt/godot-env.json`       |
| Cursor MCP wiring          | One-time — add Terravolt to `.cursor/mcp.json`, restart Cursor     |
| Addon in your game project | Recommended for editor mode — `npm run addon:link` + enable plugin |
| Headless-only mode         | Works without the addon (**201** methods)                          |

**Bottom line:** the stack is code-ready. Expect ~10 minutes of one-time Cursor + addon setup before
your first vibe-coding session.

| Question                           | Answer                                                                                                                   |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Can I use MCP on my Godot project? | **Yes** — headless works now; editor mode needs addon + plugin enable.                                                   |
| Better than reference MCP plugins? | **Yes on tool count (222)** and headless/CI/scenario/android; references win on browser UI and some Pro server niceties. |
| Where are detailed prompts?        | [`docs/guides/use-cases.md`](docs/guides/use-cases.md) — rookie-friendly scenario for every category.                    |

---

## vs reference MCP plugins

Validated in [`docs/coverage/parity-matrix.md`](docs/coverage/parity-matrix.md) (last sweep
2026-05-22, catalog **0.17.0**).

| Source        | Claimed tools |     Terravolt |
| ------------- | ------------: | ------------: |
| godot-mcp-pro |          ~172 | **222** (+50) |
| tom/godot-mcp |           ~42 |       **222** |
| Coding-Solo   |   core subset |       **222** |

**Terravolt differentiators:**

- **201/222** methods work headless (no editor open)
- `tools.health`, catalog SHA pinning, `tools.metrics` / bottlenecks
- `context.fetch_raw` → all 222 daemon methods from Cursor
- `testing.run_scenario`, `android.*` deploy chain
- 15 `macro.*` scaffolders, `batch_refactor.*` with revert journal
- 31 integration tests + 156/156 exhaustive dispatch smoke
- `validate:catalog` + `coverage:report` CI gates

**Known gaps (tracked in Linear):**

- Browser visualizer on `:6510` (tom) — backlog TER-63
- Pro paid “lite/3d” server modes — not planned
- **12/15 macros** are dry-run/stub only (3 fully apply)
- `runtime.play` editor soak — partial
- Per-category MCP router tools beyond the current **13** — use `context.fetch_raw` instead

Architectural comparison:
[`docs/references/reference-repos-map.md`](docs/references/reference-repos-map.md).

---

## Catalog — all 222 methods (0.17.0)

Grouped by category. Full schemas: [`docs/catalog/`](docs/catalog/) · Auto-generated report:
[`docs/coverage/catalog-coverage.md`](docs/coverage/catalog-coverage.md) · Rookie prompts:
[`docs/guides/use-cases.md`](docs/guides/use-cases.md).

| Category           |   # | Methods                                                                                                     | Typical use case                                                  |
| ------------------ | --: | ----------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| **server**         |   2 | `ping`, `server.info`                                                                                       | “Is MCP connected? What Godot version?”                           |
| **log**            |   1 | `log.tail`                                                                                                  | “Show last 50 daemon log lines” (editor only)                     |
| **scene**          |  15 | list, get, open, close, save, create, delete, instantiate, pack, get_tree, find_in_tree, validate, replace… | “List all .tscn files”, “Create level scene”, “Inspect node tree” |
| **scene_3d**       |   6 | add_camera, add_light, add_mesh_instance, set_environment, add_gridmap, frame_subject                       | “Add a camera + directional light to my 3D scene”                 |
| **node**           |  14 | add, delete, duplicate, move, rename, get, modify, attach_script, find_path, evaluate_expression…           | “Add CharacterBody2D under Player”, “Set speed property”          |
| **script**         |   8 | list, read, write, patch, validate, format, find_usages, rename_symbol                                      | “Compile-check Player.gd”, “Patch this function”                  |
| **signal**         |  10 | list_declared, connect, disconnect, bulk_connect, graph…                                                    | “Wire player.died → hud.update_health”                            |
| **project**        |   7 | info, get/set_settings, autoloads, set_main_scene                                                           | “Set main scene”, “Add autoload singleton”                        |
| **resource**       |  15 | list, get, create, update, duplicate, export_json, diff, validate…                                          | “Create Texture2D resource”, “Export scene as JSON”               |
| **shader**         |   6 | list, read, write, compile_check, list_params, set_material_params                                          | “Compile-check my shader”, “List uniform params”                  |
| **asset**          |  12 | list, reimport, import_settings, batch_import, find_unused, preview…                                        | “Reimport PNGs”, “Find unused assets”                             |
| **batch_refactor** |   8 | preview, apply, rename_class, move_folder, replace_in_files, history…                                       | “Rename class across project with revert journal”                 |
| **editor**         |   9 | screenshot, focus_node, open_script, undo/redo, execute_script, error_log_tail…                             | “Screenshot editor”, “Focus node in tree” (**editor only**)       |
| **analysis**       |   4 | scene_complexity, signal_flow, unused_resources, metrics                                                    | “How complex is this scene?”, “Unused resource audit”             |
| **runtime**        |  19 | play, stop, start_headless, list_nodes, inspect_node, send_input, screenshot, click_ui…                     | “Start headless game”, “Inspect Player node at runtime”           |
| **animation**      |   6 | list, create, add_track, set_keyframes, play, preview_export                                                | “Create AnimationPlayer track”                                    |
| **animation_tree** |   8 | describe, add_state, add_transition, blend_audit…                                                           | “Build state machine transitions”                                 |
| **physics**        |   6 | add_body, raycast, set_gravity, list_layers…                                                                | “Raycast from player”, “Set gravity scale”                        |
| **particle**       |   5 | add_system, set_material, preview, set_emission, list_presets                                               | “Add GPUParticles2D preset”                                       |
| **navigation**     |   6 | add_region, bake, add_agent, path, debug_overlay…                                                           | “Bake navmesh”, “Find path A→B”                                   |
| **tilemap**        |   6 | describe, set_cells, fill, query_cells, tileset_info, terrain_paint                                         | “Paint terrain on TileMapLayer”                                   |
| **theme_ui**       |   6 | describe, set_color, set_font, scaffold_screen, preview…                                                    | “Scaffold settings screen UI”                                     |
| **audio**          |   6 | list_buses, add_bus, add_effect, preview_play…                                                              | “Add reverb bus”, “Preview SFX”                                   |
| **input**          |   7 | list_actions, add_action, set_action_events, simulate_action…                                               | “Add jump action bound to Space”                                  |
| **testing**        |   7 | list_suites, run, assert_state, run_scenario, screenshot_compare, get_report…                               | “Run 4-step scenario: input → wait → assert → screenshot”         |
| **profile**        |   2 | monitor, flamegraph                                                                                         | “Capture performance monitor snapshot”                            |
| **export**         |   3 | list_presets, build, template_info                                                                          | “List export presets”, “Build Windows exe”                        |
| **macro**          |  15 | player_controller_2d/3d, basic_2d/3d_level, hud, main_menu, dialog, inventory, save_load…                   | “Scaffold 2D platformer level in one call”                        |
| **android**        |   3 | list_devices, preset_info, deploy                                                                           | “Deploy APK to connected device” (needs `adb`)                    |

**Headless-capable:** 201/222 · **Editor-required:** 23 · **MCP router tools exposed directly:** 13
· **Rest:** via `context.fetch_raw`

---

## Quick start (under 10 minutes)

Full walkthrough: [`docs/guides/quick-start.md`](docs/guides/quick-start.md).

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
# Then in Godot: Project Settings → Plugins → enable "Terravolt MCP".

# 4. wire it into Cursor — add to workspace .cursor/mcp.json (or ~/.cursor/mcp.json):
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

Restart Cursor — the tool picker shows `ping`, `server.info`, `log.tail`, `tools.*`,
`context.fetch_raw`, and the `headless.*` family.

> **Windows tip:** use the `_console.exe` Godot binary. Terravolt parses
> `TERRAVOLT_HEADLESS_PORT=<port>` from stderr; the non-console exe drops stderr by default.

---

## Manual setup vs automated checks

### You do once (manual)

1. **Install/build** — `npm install`, `npm run build:server`, `npm run env:godot`
2. **Wire Cursor MCP** — edit `.cursor/mcp.json`, set `TERRAVOLT_GODOT_BINARY` and
   `TERRAVOLT_PROJECT_PATH`, restart Cursor
3. **Link addon** (recommended for editor mode) — `npm run addon:link`, enable **Terravolt MCP**
   plugin in Godot
4. **Open Godot** with your project when you want editor-speed tools (`log.tail`, `scene.open`, live
   daemon on `:6505`)

### Automated (CI / local anytime)

```powershell
npm run test:example      # 7-check smoke on examples/playable-demo
npm run test:server       # 31/31 full suite vs live Godot (skips when binary missing)
npm run validate:catalog  # 222-method registry + headless dispatch gate
npm run release:check     # hash, error codes, readiness
```

---

## How to test end-to-end

### Phase A — prove the engine stack (no Cursor)

```powershell
cd godot-mcp-terravolt
$env:TERRAVOLT_GODOT_BINARY = (Get-Content .terravolt/godot-env.json | ConvertFrom-Json).godotBinary
npm run test:example   # 7/7 checks on examples/playable-demo
npm run test:server    # 31/31 integration suite
```

### Phase B — press Play in Godot

Open [`examples/playable-demo/project.godot`](examples/playable-demo/) → **F5** → move with
arrows/WASD, **Enter** to recolor. Self-contained (no addon required).

Or headless:

```powershell
& $env:TERRAVOLT_GODOT_BINARY --path examples/playable-demo
```

> `tests/_fixtures/` projects are headless test rigs. They ship a placeholder `main.tscn` so F5
> shows a pointer to `examples/playable-demo/` instead of “no main scene defined”.

### Phase C — wire Cursor and health-check

1. Add Terravolt to `mcp.json` (above)
2. Restart Cursor
3. Ask: _“Run a health check on the Godot MCP.”_

Expect `tools.health` → `pass: true` (headless at minimum; `daemon_server_info_ok: true` when Godot
editor + addon are running).

### Phase D — vibe-coding session

Prompts and expected MCP calls:
[`docs/demos/vibe-coding-walkthrough.md`](docs/demos/vibe-coding-walkthrough.md).

| Step | Ask Cursor                                          | MCP call                                                              |
| ---- | --------------------------------------------------- | --------------------------------------------------------------------- |
| 1    | “Run health check”                                  | `tools.health`                                                        |
| 2    | “List scenes in my project”                         | `context.fetch_raw` → `scene.list`                                    |
| 3    | “Validate Player.gd”                                | `headless.validate_script` or `context.fetch_raw` → `script.validate` |
| 4    | “Dry-run macro.basic_2d_level”                      | `context.fetch_raw` → `macro.basic_2d_level` `{dry_run:true}`         |
| 5    | “Run a test scenario: wait 0.1s then assert 1+1==2” | `context.fetch_raw` → `testing.run_scenario`                          |

On **your** project: set `TERRAVOLT_PROJECT_PATH`, run `addon:link`, enable the plugin, open Godot,
then ask Cursor to drive it.

---

## Verifying your install

```powershell
npm run lint                # ESLint @terravolt/godot-mcp
npm run typecheck           # tsc --noEmit
npm run build:server        # tsc emit dist/
npm run test:server         # 31 tests; real Godot integration auto-skips when binary missing
npm run catalog:sync        # regenerates _generated/catalog_meta.gd (catalog 0.17.0)
npm run coverage:report     # docs/coverage/catalog-coverage.md (222 tools, 28 categories)
npm run validate:catalog    # registry integrity + headless dispatch + error mirror gate
npm run release:check       # 5/5 gates (hash, version, error mirror, readiness, CHANGELOG)
node packages/mcp-server/dist/index.js --print-config   # sanity-check env + port 6505
```

**Latest verification snapshot (2026-05-22, Godot 4.6.3):**

| Check                                  | Result                                                                          |
| -------------------------------------- | ------------------------------------------------------------------------------- |
| `npm run test:example`                 | **7/7 PASS**                                                                    |
| `npm run test:server`                  | **31/31 PASS**                                                                  |
| Vibe flow on `examples/playable-demo/` | **9/10 OK** (ping, scene, script, project, input, macro dry_run, scenario)      |
| `android.list_devices`                 | Expected `adb_not_found` when Android SDK not installed — not a desktop blocker |
| Router `--print-config`                | Resolves Godot binary from `.terravolt/godot-env.json`                          |

---

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
| [Examples](examples/README.md)                          | playable demo vs test fixtures                     |

---

## What ships in this repo

| Path                                                     | What's there                                                                                            |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| [`packages/mcp-server/`](packages/mcp-server/)           | Node + TypeScript MCP router (`@terravolt/godot-mcp`). MCP stdio in, WebSocket + headless TCP out.      |
| [`packages/godot-mcp-addon/`](packages/godot-mcp-addon/) | Godot 4 addon: WebSocket JSON-RPC daemon, rotating logger, headless TCP driver, generated catalog meta. |
| [`packages/shared/`](packages/shared/)                   | Canonical JSON registries (methods, errors, autoheal hints).                                            |
| [`examples/playable-demo/`](examples/playable-demo/)     | Self-contained “press Play” demo (no addon required).                                                   |
| [`docs/`](docs/)                                         | SRS, tasklists `00–26`, guides, validation checkpoint, support matrix.                                  |
| [`tests/_fixtures/`](tests/_fixtures/)                   | Minimal Godot projects for integration tests (`empty/`, `with-addon/`, category zoos).                  |
| [`scripts/`](scripts/)                                   | `env:godot`, `catalog:sync`, `release:notes`, `release:check`, `addon:link`, intel regen.               |
| [`.github/workflows/`](.github/workflows/)               | `lint.yml`, `unit.yml` (cross-OS), `release.yml` (tag-driven).                                          |

---

## Status

| Tasklist                          | State                                                         |
| --------------------------------- | ------------------------------------------------------------- |
| `00–01` Foundation + repo         | green                                                         |
| `02–04` Addon + WS + JSON-RPC     | green                                                         |
| `05–06` Router + shared catalog   | green                                                         |
| `07` Headless fallback            | green — **201/222** methods headless-safe                     |
| `08` ~200 method catalog          | green — **222** methods @ catalog `0.17.0`                    |
| `09` Context / errors / telemetry | green — **130** error codes, `tools.bottlenecks`, `autoHeal`  |
| `10` QA / release / docs          | green — **31/31** tests, `release:check`, user guides         |
| `11–24` Per-category catalog      | green — handlers + headless ops + integration tests + docs    |
| `25` Completion gate              | green — coverage report, parity matrix, validation checkpoint |
| `26` Android + scenario           | green — `android.*` (3) + `testing.run_scenario`              |

---

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

## Code intelligence

This repo is indexed by GitNexus and Graphify:

```powershell
npm run omni:intel          # runs intel:gitnexus, intel:graphs, intel:graphify
```

See [`AGENTS.md`](AGENTS.md) for the embedded GitNexus block describing when to call
`gitnexus_query`, `gitnexus_impact`, and friends from inside Cursor.
