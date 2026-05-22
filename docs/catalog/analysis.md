# Catalog: `analysis.*`

Phase 3 work-unit #6 — 4 daemon methods (`catalog_version` **0.8.0**).

| Method                      | Safe | Mutates | Headless |
| --------------------------- | ---- | ------- | -------- |
| `analysis.scene_complexity` | yes  | no      | yes      |
| `analysis.signal_flow`      | yes  | no      | yes      |
| `analysis.unused_resources` | yes  | no      | yes      |
| `analysis.metrics`          | yes  | no      | yes      |

Handler: `packages/godot-mcp-addon/handlers/analysis.gd`  
Helpers: `packages/godot-mcp-addon/handlers/analysis_helpers.gd`  
Thresholds: `packages/shared/analysis/thresholds.json`
