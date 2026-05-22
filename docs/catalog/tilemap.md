# Catalog: `tilemap.*`

Phase 3 work-unit #10 — 6 daemon methods (`catalog_version` **0.12.0**).

| Method                 | Safe | Mutates | Headless |
| ---------------------- | ---- | ------- | -------- |
| `tilemap.describe`     | yes  | no      | yes      |
| `tilemap.set_cells`    | no   | yes     | yes      |
| `tilemap.fill`         | no   | yes     | yes      |
| `tilemap.query_cells`  | yes  | no      | yes      |
| `tilemap.tileset_info` | yes  | no      | yes      |
| `tilemap.terrain_paint`| no   | yes     | yes      |

Handlers: `packages/godot-mcp-addon/handlers/tilemap.gd`  
Helpers: `packages/godot-mcp-addon/handlers/tilemap_helpers.gd`

Uses `TileMapLayer` when available (Godot ≥ 4.3); falls back to legacy `TileMap` layer APIs otherwise. `tilemap_max_cells_per_call` = **4096**.

Error band: `-33960` … `-33964`.
