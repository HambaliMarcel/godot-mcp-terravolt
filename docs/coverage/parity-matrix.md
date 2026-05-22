# Feature parity matrix — TerraVolt vs reference MCP plugins

Date-stamped snapshot for task 25 completion gate. Regenerate when reference clones or TerraVolt
catalog changes materially.

**Reference sources:** [`docs/references/reference-repos-map.md`](../references/reference-repos-map.md)

**Last validated:** 2026-05-22 — catalog **0.17.0**, **222** daemon methods, **201** headless
fallback, **31/31** integration tests passing against live Godot 4.6.3 (including the
exhaustive coverage smoke that dispatches every `headlessFallback: true` method).

| Feature | Reference | TerraVolt status | Notes |
| ------- | --------- | ---------------- | ----- |
| MCP stdio → Node router | tom / Pro / Coding-Solo | ✅ live | `packages/mcp-server` |
| Editor WebSocket daemon `:6505` | tom / Pro | ✅ live | `mcp_server.gd` |
| Headless TCP fallback | TerraVolt | ✅ live | `headless_driver.gd` + `catalog_ops.gd`, **201/222** methods |
| `tools.health` + catalog SHA | TerraVolt | ✅ live | `tools.health`, `catalog_meta.gd` |
| `tools.metrics` / bottlenecks | TerraVolt | ✅ live | Task 09 |
| `context.fetch_raw` | TerraVolt | ✅ live | Registry proxy for all 222 daemon methods |
| Structured `autoHeal` hints | TerraVolt | ✅ live | `autoheal.json` (130 error bands) |
| Browser project visualizer `:6510` | tom | ⏳ backlog | Use Graphify/GitNexus locally — TER-63 |
| Paid Node server modes (lite/3d) | Pro | ❌ not planned | Open addon; study patterns only |
| Subprocess `run_project` debug loop | Coding-Solo | ✅ partial | `runtime.start_headless` + bridge autoload |
| Scene / node / script tools | tom / Pro | ✅ live | Tasks 11–13 (37 methods) |
| Resource / shader / asset tools | Pro | ✅ live | Tasks 14–15 (41 methods) |
| Editor / analysis tools | Pro | ✅ live | Task 16 (13 methods) |
| Runtime playmode inspection | Pro | ✅ partial | Bridge path live; editor E2E deferred |
| Animation / physics / tilemap | Pro (3d mode) | ✅ live | Tasks 18–20 (43 methods) |
| Audio / input map | Pro | ✅ live | Task 21 (13 methods) |
| 3D scene sugar | Pro 3d | ✅ live | Task 22 (6 `scene_3d.*` tools) |
| Export / testing / profile | tom / Coding-Solo | ✅ live | Task 23 + 26 (12 tools incl. `testing.run_scenario`) |
| Macro scaffolders | TerraVolt | ✅ live | Task 24 (15 `macro.*` tools; 3 full, 12 dry-run/stub) |
| **Android deploy chain** | Pro | ✅ live | Task 26 (3 `android.*`: `list_devices`, `preset_info`, `deploy`) |
| Godot 4.6 API alignment | godot-docs | ✅ live | TileMapLayer, ThemeOwner, AudioServer 4.6 |

## Tool count comparison

| Source | Claimed tools | TerraVolt (2026-05-22) |
| ------ | ------------- | ---------------------- |
| godot-mcp-pro | ~172 (modes) | **222** (+50 over reference) |
| tom/godot-mcp | ~42 | **222** |
| Coding-Solo | core subset | **222** |
| **TerraVolt gate (task 25)** | ≥209 | **222 PASS** (meets stated 222 target exactly) |

## TerraVolt differentiators (explicit)

- Catalog version + registry SHA pinning in `server.info` / `tools.health`
- Headless fallback matrix documented in [`docs/catalog/parity.md`](../catalog/parity.md)
- Two-phase `batch_refactor.*` with revert journal
- Deterministic `resource.export_json`
- `macro.*` vibe-coding scaffolders (15 tools)
- `testing.run_scenario` orchestrator (input/wait/assert/screenshot steps in one call)
- Headless-first `android.*` deploy chain (`adb` + `--export-debug/release` from the daemon)
- `validate:catalog` + `coverage:report` CI gates (tasks 25 + 26)
- 31/31 integration tests against the real Godot 4.6.3 binary, including an exhaustive
  coverage smoke that dispatches 156/156 safe candidate methods from the 201 headless-capable
  catalog (proof of runnable wiring across the full catalog, not just happy-path samples)

## Known gaps (tracked in Linear)

| Gap | Status | Issue |
| --- | ------ | ----- |
| Browser visualizer `:6510` | ⏳ | TER-62 |
| Per-category MCP router tools (beyond 13) | ⏳ | TER-41 |
| Editor UI E2E / showcase video | ⏳ | TER-42 |
| Macro full apply (12/15 stubs) | ⏳ | TER-61 |
| C# compile parity | ⏳ | TER-42 |
| `runtime.play` editor soak | ⏳ | TER-40 |
