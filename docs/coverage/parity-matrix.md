# Feature parity matrix — TerraVolt vs reference MCP plugins

Date-stamped snapshot for task 25 completion gate. Regenerate when reference clones or TerraVolt
catalog changes materially.

**Reference sources:** `docs/references/reference-repos-map.md`

| Feature | Reference | TerraVolt status | Notes |
| ------- | --------- | ---------------- | ----- |
| MCP stdio → Node router | tom / Pro / Coding-Solo | ✅ live | `packages/mcp-server` |
| Editor WebSocket daemon `:6505` | tom / Pro | ✅ live | `mcp_server.gd` |
| Headless TCP fallback | TerraVolt | ✅ live | `headless_driver.gd`, 152+ methods |
| `tools.health` + catalog SHA | TerraVolt | ✅ live | `tools.health`, `catalog_meta.gd` |
| `tools.metrics` / bottlenecks | TerraVolt | ✅ live | Task 09 |
| `context.fetch_raw` | TerraVolt | ✅ live | Registry proxy |
| Structured `autoHeal` hints | TerraVolt | ✅ live | `autoheal.json` |
| Browser project visualizer `:6510` | tom | ⏳ backlog | Use Graphify/GitNexus locally |
| Paid Node server modes (lite/3d) | Pro | ❌ not planned | Open addon; study patterns only |
| Subprocess `run_project` debug loop | Coding-Solo | ✅ partial | `runtime.start_headless` + bridge |
| Scene / node / script tools | tom / Pro | ✅ live | Tasks 11–13 |
| Animation / physics / tilemap | Pro (3d mode) | ✅ live | Tasks 18–20 |
| Runtime playmode inspection | Pro | ✅ partial | Bridge; editor E2E deferred |
| Macro scaffolders | TerraVolt | ⏳ task 24 | 15 `macro.*` tools |
| Export / testing / profile | tom / Coding-Solo | ⏳ task 23 | 11 tools |
| Audio / input map | Pro | ⏳ task 21 | 13 tools |
| 3D scene sugar | Pro 3d | ⏳ task 22 | 6 `scene_3d.*` tools |

## Tool count comparison

| Source | Claimed tools | TerraVolt (target) |
| ------ | ------------- | ------------------ |
| godot-mcp-pro | ~172 (modes) | — |
| tom/godot-mcp | ~42 | — |
| Coding-Solo | core subset | — |
| **TerraVolt** | — | **≥209** at gate (task 25) |

## TerraVolt differentiators (explicit)

- Catalog version + registry SHA pinning in `server.info` / `tools.health`
- Headless fallback matrix documented in `docs/catalog/parity.md`
- Two-phase `batch_refactor.*` with revert journal
- Deterministic `resource.export_json`
- `macro.*` vibe-coding scaffolders (task 24)
