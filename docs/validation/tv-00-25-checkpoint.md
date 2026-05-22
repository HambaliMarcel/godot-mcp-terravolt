# Tasklist TV-00–26 validation checkpoint

**Canonical docs:** `docs/tasklist/00*.md` … `26-android-and-scenario.md`

**Last sweep:** 2026-05-22 (maintainer audit — tasks **00–26** complete at catalog **0.17.0**,
**222** daemon methods, **31/31** integration tests passing against live Godot 4.6.3.mono.official,
including the new exhaustive coverage smoke that dispatches **156/156** safe candidate methods out
of 201 headless-capable methods)

## Deliverables matrix (00–25)

| Task  | Topic                       | Key artifacts                                                         | Status   |
| ----- | --------------------------- | --------------------------------------------------------------------- | -------- |
| 00–01 | Foundation, repo            | Contracts, monorepo, CI, `.githooks/`                                 | Done     |
| 02–04 | Godot daemon                | `packages/godot-mcp-addon/` plugin, WS `:6505`, dispatcher, logging   | Done     |
| 05–06 | MCP router                  | `packages/mcp-server/`, `registry.json`, `catalog-sync.mjs`           | Done     |
| 07    | Headless                    | `headless_driver.gd`, `catalog_ops.gd`, **201/222** headless parity   | Done     |
| 08    | ~200-tool catalog           | **222** methods through task 26 gate (≥ 200 objective + 222 stretch)  | Done     |
| 09    | Context/errors              | `tools.bottlenecks`, `context.fetch_raw`, **130** error codes         | Done     |
| 10    | QA/release                  | CI workflows, **30** tests, `release:check`, user guides              | Progress |
| 11–16 | Scene → analysis catalog    | Handlers, headless ops, integration tests, catalog docs               | Done     |
| 17    | `runtime.*` (19)            | Bridge autoload, `runtime_proxy.gd`, `minimal_game` fixture           | Done     |
| 18    | `animation.*` + tree (14)   | Handlers, zoo fixtures, headless tests                                | Done     |
| 19    | physics/particle/nav (17)   | Handlers, presets, zoo fixtures                                       | Done     |
| 20    | tilemap + theme_ui (12)     | Handlers, UI presets, scaffolder                                      | Done     |
| 21    | audio + input (13)          | `audio.gd`, `input.gd`, bus layout writer, zoo fixtures               | Done     |
| 22    | scene_3d (6)                | `scene_3d.gd`, 3D zoo fixture                                         | Done     |
| 23    | testing/profile/export (11) | `testing.gd`, `profile.gd`, `export.gd`                               | Done     |
| 24    | macro (15)                  | `macro.gd`, `macro_runner.gd`, journal, template macros               | Done     |
| 25    | Completion gate             | `coverage:report`, `validate:catalog`, parity matrix, this checkpoint | Done     |
| 26    | android + scenario (4)      | `android.gd`/`android_helpers.gd`, `testing.run_scenario`, 30th test  | Done     |

**Registry builders:** `scripts/build-registry-{11..24,26}.mjs`  
**Integration tests:** 21 headless category suites + exhaustive coverage smoke under
`packages/mcp-server/tests/integration/` (`coverage/all_methods_dispatch.test.mjs` walks every
`headlessFallback: true` registry entry against the live daemon)  
**Catalog docs:** `docs/catalog/*.md` (28 category pages incl. `android.md`)

## Automated checks

Run from repo root (`npm install` once):

| Command                    | Result (2026-05-22)                                              |
| -------------------------- | ---------------------------------------------------------------- |
| `npm run lint`             | Pass                                                             |
| `npm run format:check`     | Pass (LF enforced via `.gitattributes`)                          |
| `npm run typecheck`        | Pass                                                             |
| `npm run build:server`     | Pass                                                             |
| `npm run test:server`      | Pass — **31/31** tests against live Godot 4.6.3.mono.official    |
| `npm run catalog:sync`     | Pass (`catalog_version=0.17.0`)                                  |
| `npm run coverage:report`  | Pass — **222** tools ≥ 200 gate (matches task 25 stretch target) |
| `npm run validate:catalog` | Pass — handlers wired, headless dispatch, error mirror           |
| `npm run release:check`    | Pass (**130** app error codes mirrored)                          |
| GitHub CI (5 checks)       | Pass — lint, docs links, unit matrix (ubuntu/macos/windows)      |

## Catalog snapshot (registry)

| Metric             | Value                                                  |
| ------------------ | ------------------------------------------------------ |
| `catalog_version`  | **`0.17.0`** (RC tag `v0.17.0-rc.1` ready)             |
| Daemon methods     | **222**                                                |
| `headlessFallback` | **201**                                                |
| `requiresEditor`   | **23**                                                 |
| MCP router tools   | **13** (daemon methods bridge via `context.fetch_raw`) |

### Methods by category (tasks 11–24)

| Category               | Count | Task  | Catalog bump |
| ---------------------- | ----- | ----- | ------------ |
| `scene.*`              | 15    | 11    | 0.3.0        |
| `project.*`            | 7     | 11    | 0.3.0        |
| `node.*`               | 14    | 12    | 0.4.0        |
| `script.*`             | 8     | 13    | 0.5.0        |
| `signal.*`             | 10    | 13    | 0.5.0        |
| `resource.*`           | 15    | 14    | 0.6.0        |
| `shader.*`             | 6     | 14    | 0.6.0        |
| `asset.*`              | 12    | 15    | 0.7.0        |
| `batch_refactor.*`     | 8     | 15    | 0.7.0        |
| `editor.*`             | 9     | 16    | 0.8.0        |
| `analysis.*`           | 4     | 16    | 0.8.0        |
| `runtime.*`            | 19    | 17    | 0.9.0        |
| `animation.*`          | 6     | 18    | 0.10.0       |
| `animation_tree.*`     | 8     | 18    | 0.10.0       |
| `physics.*`            | 6     | 19    | 0.11.0       |
| `particle.*`           | 5     | 19    | 0.11.0       |
| `navigation.*`         | 6     | 19    | 0.11.0       |
| `tilemap.*`            | 6     | 20    | 0.12.0       |
| `theme_ui.*`           | 6     | 20    | 0.12.0       |
| `audio.*`              | 6     | 21    | 0.13.0       |
| `input.*`              | 7     | 21    | 0.13.0       |
| `scene_3d.*`           | 6     | 22    | 0.14.0       |
| `testing.*`            | 6     | 23    | 0.15.0       |
| `profile.*`            | 2     | 23    | 0.15.0       |
| `export.*`             | 3     | 23    | 0.15.0       |
| `macro.*`              | 15    | 24    | 0.16.0       |
| `android.*`            | 3     | 26    | 0.17.0       |
| `testing.run_scenario` | +1    | 26    | 0.17.0       |
| bootstrap              | 5     | 02–06 | —            |

## Reference-repo alignment (4 main references)

| Reference                 | Terravolt adoption                                                                                                                       | Gap / backlog                                                                             |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| **tomyud1/godot-mcp**     | WS `:6505` daemon + Node MCP stdio router; shared JSON-RPC envelope; headless TCP fallback when WS down                                  | Browser visualizer (`localhost:6510`) not ported — use Graphify/GitNexus locally (TER-62) |
| **Coding-Solo/godot-mcp** | `runtime.start_headless`, subprocess Godot with stdout/stderr path; headless coordinator in `mcp-server`                                 | Full `run_project` debug loop UI not duplicated — covered by `runtime.*` bridge           |
| **godot-mcp-pro**         | Rich editor-integrated handler layout; mode-aware catalog concept; expression denylist; **222 > 172** tools; android deploy chain ported | Paid Node server closed-source — study addon patterns only                                |
| **godot-docs**            | Godot 4.6 APIs: `TileMapLayer`, `CPUParticles3D` fallback, `ThemeOwner` overrides, `AudioServer` 4.6                                     | Manual topical lookup — excluded from Graphify/GitNexus index                             |

## Task 21–25 acceptance (honest status)

| Criterion                    | Status      | Notes                                                              |
| ---------------------------- | ----------- | ------------------------------------------------------------------ |
| All tools live in registry   | **Pass**    | 222 methods; `validate:catalog` green                              |
| Headless round-trips         | **Pass**    | 7 new integration suites; **30/30** total against real Godot 4.6.3 |
| Audio bus layout in headless | **Pass**    | `ensure_bus_layout_loaded()`; Godot 4.6 `is_bus_solo()`            |
| Input action map CRUD        | **Pass**    | Full headless round-trip in `input_zoo` fixture                    |
| Macro apply                  | **Partial** | 3 full macros; 12 dry-run/stub templates (TER-61)                  |
| Export.build smoke           | **Pass**    | Headless preset list + template_info; build deferred in CI         |
| 200+ gate                    | **Pass**    | **222 ≥ 209 ≥ 200** (matches task 25's stated 222 target exactly)  |
| Vibe-coding walkthrough doc  | **Pass**    | `docs/demos/vibe-coding-walkthrough.md`                            |
| Android deploy chain         | **Pass**    | `android.list_devices` / `preset_info` / `deploy` headless-safe    |
| `testing.run_scenario`       | **Pass**    | Integration test covers input/wait/assert/screenshot orchestration |
| RC tag `v0.17.0-rc.1`        | **Ready**   | All gates green; safe to tag after this validation sweep           |

## Known gaps (not blockers for 00–25 closure)

- **MCP surface:** still 13 router tools; per-category MCP modules remain backlog (§06/§08, TER-41).
- **Headless partial:** `runtime.play`, editor screenshot/layout, `asset.preview`, signal connect in
  headless.
- **Performance benchmarks** (`09 §9.10`) and dependency index not shipped.
- **Editor E2E** and recorded demo video backlog (TER-42).

## References

- Parity: `docs/coverage/parity-matrix.md`, `docs/catalog/parity.md`
- Coverage: `docs/coverage/catalog-coverage.md`
- Demo: `docs/demos/vibe-coding-walkthrough.md`
- Architecture: `docs/architecture/runtime-bridge.md`
- Reference map: `docs/references/reference-repos-map.md`
- Linear: TER-40 (§07), TER-41 (§08), TER-42 (§10), TER-43 (§09), TER-47–TER-61 (TV-11–25)
