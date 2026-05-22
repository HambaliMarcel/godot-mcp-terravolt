# Tasklist TV-00–20 validation checkpoint

**Canonical docs:** `docs/tasklist/00*.md` … `20-catalog-tilemap-and-theme-ui.md`

**Last sweep:** 2026-05-22 (maintainer audit — tasks **00–20** complete; task **21+** next)

## Deliverables matrix (00–20)

| Task  | Topic                     | Key artifacts                                                              | Status   |
| ----- | ------------------------- | -------------------------------------------------------------------------- | -------- |
| 00–01 | Foundation, repo          | Contracts, monorepo, CI, `.githooks/`                                      | Done     |
| 02–04 | Godot daemon              | `packages/godot-mcp-addon/` plugin, WS, dispatcher, logging                | Done     |
| 05–06 | MCP router                | `packages/mcp-server/`, `registry.json`, `catalog-sync.mjs`                | Done     |
| 07    | Headless                  | `headless_driver.gd`, `catalog_ops.gd`, **152/173** headless parity        | Partial  |
| 08    | ~200-tool catalog         | **173** methods through task 20; tasks **21–25** remain                    | Progress |
| 09    | Context/errors            | `tools.bottlenecks`, `context.fetch_raw`, **100** error codes              | Partial  |
| 10    | QA/release                | CI workflows, **24** tests, `release:check`, user guides                   | Progress |
| 11–16 | Scene → analysis catalog  | Handlers, headless ops, integration tests, catalog docs                    | Done     |
| 17    | `runtime.*` (19)          | Bridge autoload, `runtime_proxy.gd`, `minimal_game` fixture, headless test | Done     |
| 18    | `animation.*` + tree (14) | Handlers, zoo fixtures, headless tests                                     | Done     |
| 19    | physics/particle/nav (17) | Handlers, presets, zoo fixtures, headless test                             | Done     |
| 20    | tilemap + theme_ui (12)   | Handlers, UI presets, scaffolder, headless test                            | Done     |

**Registry builders:** `scripts/build-registry-{11..20}.mjs`  
**Integration tests:** 14 headless suites under `packages/mcp-server/tests/integration/`  
**Catalog docs:** `docs/catalog/*.md` through runtime, animation, physics, tilemap, theme_ui

## Automated checks

Run from repo root (`npm install` once):

| Command                  | Result (2026-05-22)                                          |
| ------------------------ | ------------------------------------------------------------ |
| `npm run lint`           | Pass                                                         |
| `npm run format:check`   | Pass (after Prettier sweep)                                  |
| `npm run typecheck`      | Pass                                                         |
| `npm run build:server`   | Pass                                                         |
| `npm run test:server`    | Pass — **24 tests** (use `--test-concurrency=1` on Windows). |
| `npm run catalog:sync`   | Pass (`catalog_version=0.12.0`).                             |
| `npm run release:check`  | Pass (**100** app error codes mirrored).                     |
| `npm run intel:graphify` | Pass — 7841 nodes, 7484 edges.                               |
| `npm run intel:gitnexus` | Pass — 4612 symbols, 7216 relationships, 169 flows.          |

## Catalog snapshot (registry)

| Metric             | Value                                                             |
| ------------------ | ----------------------------------------------------------------- |
| `catalog_version`  | **`0.12.0`**                                                      |
| Daemon methods     | **173**                                                           |
| `headlessFallback` | **152**                                                           |
| `requiresEditor`   | **21**                                                            |
| MCP router tools   | **13** (daemon methods bridge via registry / `context.fetch_raw`) |

### Methods by category (tasks 11–20)

| Category           | Count | Task  | Catalog bump |
| ------------------ | ----- | ----- | ------------ |
| `scene.*`          | 15    | 11    | 0.3.0        |
| `project.*`        | 7     | 11    | 0.3.0        |
| `node.*`           | 14    | 12    | 0.4.0        |
| `script.*`         | 8     | 13    | 0.5.0        |
| `signal.*`         | 10    | 13    | 0.5.0        |
| `resource.*`       | 15    | 14    | 0.6.0        |
| `shader.*`         | 6     | 14    | 0.6.0        |
| `asset.*`          | 12    | 15    | 0.7.0        |
| `batch_refactor.*` | 8     | 15    | 0.7.0        |
| `editor.*`         | 9     | 16    | 0.8.0        |
| `analysis.*`       | 4     | 16    | 0.8.0        |
| `runtime.*`        | 19    | 17    | 0.9.0        |
| `animation.*`      | 6     | 18    | 0.10.0       |
| `animation_tree.*` | 8     | 18    | 0.10.0       |
| `physics.*`        | 6     | 19    | 0.11.0       |
| `particle.*`       | 5     | 19    | 0.11.0       |
| `navigation.*`     | 6     | 19    | 0.11.0       |
| `tilemap.*`        | 6     | 20    | 0.12.0       |
| `theme_ui.*`       | 6     | 20    | 0.12.0       |
| bootstrap          | 3     | 02–06 | —            |

## Reference-repo alignment (4 main references)

| Reference                 | Terravolt adoption                                                                                       | Gap / backlog                                                                            |
| ------------------------- | -------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| **tomyud1/godot-mcp**     | WS `:6505` daemon + Node MCP stdio router; shared JSON-RPC envelope; headless TCP fallback when WS down  | Browser visualizer (`localhost:6510`) not ported — use Graphify/GitNexus locally instead |
| **Coding-Solo/godot-mcp** | `runtime.start_headless`, subprocess Godot with stdout/stderr path; headless coordinator in `mcp-server` | Full `run_project` debug loop UI not duplicated — covered by `runtime.*` bridge          |
| **godot-mcp-pro**         | Rich editor-integrated handler layout; mode-aware catalog concept; expression denylist                   | Paid Node server closed-source — study addon patterns only                               |
| **godot-docs**            | Godot 4.6 APIs: `TileMapLayer`, `CPUParticles3D` fallback, `ThemeOwner` overrides, strict typing         | Manual topical lookup — excluded from Graphify/GitNexus index                            |

## Task 17–20 acceptance (honest status)

| Criterion                             | Status       | Notes                                                           |
| ------------------------------------- | ------------ | --------------------------------------------------------------- |
| All tools live in registry            | **Pass**     | 62 new methods; `tools.list` category filter works via router   |
| Headless round-trips                  | **Pass**     | 4 new integration suites green (24/24 total)                    |
| `runtime.start_headless` + bridge     | **Pass**     | Fixed `.cmd` shim spawn; CI polls bridge                        |
| `runtime.play` editor E2E             | **Deferred** | Editor session not in CI — bridge path validated                |
| Record/replay determinism             | **Deferred** | Helpers shipped; 5s walkthrough golden test backlog             |
| `runtime.navigate` timeout            | **Deferred** | `minimal_game` has no nav mesh — method exists, fixture backlog |
| Particle GPU fallback                 | **Pass**     | Headless uses CPU particles; no `Node.has()`                    |
| Theme scaffold `scene.get` node count | **Pass**     | Owner assignment before `PackedScene.pack`                      |
| Control theme override describe       | **Pass**     | Reads `PROPERTY_USAGE_THEME_OVERRIDE` + color overrides         |

## Known gaps (not blockers for 00–20 closure)

- **MCP surface:** still 13 router tools; per-category MCP modules remain backlog (§06/§08).
- **Headless partial:** `runtime.play`, editor screenshot/layout, `asset.preview`, signal connect in
  headless.
- **§08 remaining:** audio, input, 3D scene, testing, macros, completion gate — tasklists **21–25**.
- **Performance benchmarks** (`09 §9.10`) and dependency index not shipped.

## References

- Parity: `docs/catalog/parity.md`
- Architecture: `docs/architecture/runtime-bridge.md`
- Reference map: `docs/references/reference-repos-map.md`
- Linear: TER-41 (§08), TER-40 (§07), TER-42 (§10), TER-52–TER-56 (TV-16–20)
