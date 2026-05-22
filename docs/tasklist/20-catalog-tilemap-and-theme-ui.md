# 20 — Catalog: `tilemap.*` + `theme_ui.*` (Phase 3 work-unit #10)

> `tilemap.*` covers 2D `TileMap` + `TileMapLayer` workflows (Godot 4.3 introduced `TileMapLayer` as
> the recommended primitive). `theme_ui.*` covers Control nodes, themes, styles, fonts, colors — the
> agent can build complete UI screens by prompt.

---

## 20.1 Header

- **File:** `20-catalog-tilemap-and-theme-ui.md`
- **Purpose:** ship `tilemap.*` (6) + `theme_ui.*` (6) — 12 total.
- **Catalog bump:** `0.11.0` → **`0.12.0`** on land.

## 20.2 Phase placement

Phase 3, work-unit #10. Prerequisite: `19` shipped.

## 20.3 Inputs / prerequisites

- New handlers: `handlers/tilemap.gd`, `handlers/theme_ui.gd`.
- Router modules: `src/tools/tilemap/`, `src/tools/theme_ui/`.
- TileMap tooling targets `TileMapLayer` for Godot ≥ 4.3 and degrades to legacy `TileMap` for older
  minors (feature detection via `ClassDB.class_exists("TileMapLayer")`).
- Pull theme overrides from both `Theme` resources and per-Control `theme_override_*` properties.

## 20.4 Outputs

- 12 tools live, registered, validated, documented.
- New fixtures: `tests/_fixtures/tilemap_zoo/` (a tileset + simple map) and
  `tests/_fixtures/theme_zoo/` (a complete theme with three style boxes).
- `docs/catalog/tilemap.md` and `docs/catalog/theme_ui.md` regenerated.

## 20.5 Operating constants used

- `tilemap_max_cells_per_call = 4096` — chunked writes above this.
- `theme_preview_size = { w: 256, h: 256 }`.

---

## 20.6 `tilemap.*` — 6 tools

### `tilemap.describe`

- **Purpose:** describe a `TileMapLayer` (or `TileMap` if legacy): tileset, layers, used rect, atlas
  sources.
- **Inputs:** `{ path: NodePath }`.
- **Outputs:**
  `{ kind: "tilemap"|"tilemaplayer", tileset_path?: ResourcePath, layers?: [{ name, z_index, modulate }], used_rect: { x, y, w, h }, atlas_sources: [{ source_id, atlas_path: ResourcePath, size, texture_region }] }`.
- **Godot APIs:** `TileMapLayer.tile_set`, `TileSet.get_source_count()`, `TileSet.get_source(id)`;
  for legacy, `TileMap.get_layer_count()` + `get_layer_*`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Describe /root/Main/World/Ground (TileMap)."_

### `tilemap.set_cells`

- **Purpose:** set / clear cells in bulk.
- **Inputs:**
  `{ path: NodePath, layer_name?: string (only for legacy TileMap), cells: [{ position: [x,y], source_id?: int, atlas_coords?: [x,y], alternative_id?: int (default 0), clear?: bool }], if_match?: revision }`.
- **Outputs:** `{ written: int, cleared: int, state, revision }`.
- **Godot APIs:** `TileMapLayer.set_cell(position, source_id, atlas_coords, alternative)`; legacy
  `TileMap.set_cell(layer, position, ...)`.
- **safe:** false. **mutates:** true.
- **Errors:** `tilemap.cell_batch_too_large` (`-33G00`), `tilemap.atlas_unknown` (`-33G01`).
- **Cursor prompt:** _"Paint a 10×3 patch of grass tiles starting at (0,0) on /World/Ground."_

### `tilemap.fill`

- **Purpose:** fill a rectangle (or polygon) with one tile.
- **Inputs:**
  `{ path: NodePath, rect?: { x, y, w, h }, polygon?: [Vector2], source_id: int, atlas_coords: [x,y], alternative_id?: int (default 0) }`.
- **Outputs:** `{ written: int, rect_or_poly_used, state, revision }`.
- **Godot APIs:** loop calling `set_cell` (or `set_cells_terrain_connect` for terrain-aware fill).
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Fill rect (0,0,40,8) with the dirt tile."_

### `tilemap.query_cells`

- **Purpose:** read tiles in a region.
- **Inputs:** `{ path: NodePath, rect?: { x, y, w, h }, used_rect_only?: bool (default false) }`.
- **Outputs:** `{ cells: [{ position, source_id, atlas_coords, alternative_id }], rect_used }`.
- **Godot APIs:** `TileMapLayer.get_used_cells()`; `get_cell_source_id`, `get_cell_atlas_coords`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"What tiles are in the rect (0,0,10,10) on /World/Ground?"_

### `tilemap.tileset_info`

- **Purpose:** describe a `TileSet` resource (sources, regions, custom data layers, terrains).
- **Inputs:** `{ tileset_path: ResourcePath }`.
- **Outputs:**
  `{ tile_size, sources: [...], custom_data_layers: [{ name, type }], terrain_sets: [{ name, mode, terrains: [{ name, color }] }] }`.
- **Godot APIs:** `TileSet.get_source_count`, `TileSet.get_terrain_sets_count`, etc.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Describe res://art/tileset_main.tres."_

### `tilemap.terrain_paint`

- **Purpose:** paint cells using the terrain auto-tiler (peering bit aware).
- **Inputs:**
  `{ path: NodePath, cells: [Vector2], terrain_set: int, terrain: int, ignore_empty_terrains?: bool (default true) }`.
- **Outputs:** `{ written: int, neighbors_recomputed: int, state, revision }`.
- **Godot APIs:**
  `TileMapLayer.set_cells_terrain_connect(cells, terrain_set, terrain, ignore_empty_terrains)`.
- **safe:** false. **mutates:** true.
- **Errors:** `tilemap.terrain_unknown` (`-33G02`).
- **Cursor prompt:** _"Terrain-paint a snake of cells from (0,5) to (20,5) with terrain set 0,
  terrain 'dirt'."_

---

## 20.7 `theme_ui.*` — 6 tools

### `theme_ui.describe`

- **Purpose:** describe a `Theme` resource (or per-Control overrides).
- **Inputs:** `{ theme_path?: ResourcePath, control_path?: NodePath }`.
- **Outputs:**
  `{ kind: "theme"|"control_overrides", colors: { type/name: Color }, constants: {...}, fonts: {...}, font_sizes: {...}, icons: {...}, styles: { type/name: { class, properties_summary } }, default_font?: ResourcePath, default_font_size?: int }`.
- **Godot APIs:** `Theme.get_color_list/type_list/...`; for control overrides,
  `Control.get_theme_color_list("type")` and `theme_override_*` properties.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Describe res://ui/main_theme.tres."_

### `theme_ui.set_color`

- **Purpose:** set a color on a theme (or per-Control override).
- **Inputs:**
  `{ target: { theme_path?, control_path? }, type: string, name: string, value: Color }`.
- **Outputs:** `{ updated: true, before, after }`.
- **Godot APIs:** `Theme.set_color(name, type, value)` or
  `Control.add_theme_color_override(name, value)`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Set Button.font_color to (0.95, 0.95, 0.95) on res://ui/main_theme.tres."_

### `theme_ui.set_font`

- **Purpose:** set the default font / size / per-type font.
- **Inputs:**
  `{ target: { theme_path?, control_path? }, type?: string, name?: string ("font"|"normal_font"|"..."), font_path: ResourcePath, size?: int }`.
- **Outputs:** `{ updated: true, before, after }`.
- **Godot APIs:** `Theme.set_font(name, type, font)` + `Theme.set_default_font` + per-Control
  `add_theme_font_override`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Set the default font to res://art/fonts/Inter.ttf at size 18."_

### `theme_ui.set_stylebox`

- **Purpose:** define / replace a `StyleBox` (flat / texture / empty / line).
- **Inputs:**
  `{ target: { theme_path?, control_path? }, type: string, name: string (e.g., "normal"), stylebox: { kind: "flat"|"texture"|"empty"|"line", properties: PropertyDict } }`.
- **Outputs:** `{ updated: true, stylebox_path?: ResourcePath, before, after }`.
- **Godot APIs:** instantiate `StyleBoxFlat/Texture/Empty/Line`; populate properties;
  `Theme.set_stylebox(name, type, sb)`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Give Button.normal a rounded StyleBoxFlat with bg=(0.2,0.2,0.25) and
  corner_radius_all=8."_

### `theme_ui.preview`

- **Purpose:** generate a preview image of how a theme renders a sample widget grid.
- **Inputs:**
  `{ theme_path: ResourcePath, widgets?: ["Button"|"Label"|"Panel"|"LineEdit"|"OptionButton"|"CheckBox"|"ScrollContainer"] (default common set), size?: { w, h } }`.
- **Outputs:** `{ image_base64, mime: "image/png", widgets_rendered: [string] }`.
- **Godot APIs:** off-screen `SubViewport` populated with one of each widget; `Image` capture.
- **safe:** true. **mutates:** false.
- **Errors:** `theme.preview_failed` (`-33G10`).
- **Cursor prompt:** _"Show me a preview of res://ui/main_theme.tres."_

### `theme_ui.scaffold_screen`

- **Purpose:** scaffold a complete UI screen (`Title`, `Settings`, `HUD`, `Pause`) from a high-level
  spec.
- **Inputs:**
  `{ output_path: ScenePath, kind: "title"|"settings"|"hud"|"pause"|"inventory"|"dialog"|"loading", theme_path?: ResourcePath, options?: { title?: string, buttons?: [string], orientation?: "vertical"|"horizontal", canvas_layer?: bool } }`.
- **Outputs:** `{ created: true, path, state, revision }`.
- **Godot APIs:** instantiate Control nodes (`CanvasLayer` if requested → `Control` →
  `VBoxContainer` → `Button` etc.); save via `PackedScene`. Picks safe defaults per `kind`. Connects
  placeholder signals (e.g., Title `start_pressed` to a stub on the root).
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Scaffold a settings screen at res://ui/Settings.tscn using the main theme."_

---

## 20.8 Schemes / data shapes added

- `Color` shape: `{ r, g, b, a }` (0..1 floats) — accept `"#RRGGBBAA"` strings too (per `06`).
- `StyleBoxSpec` discriminated union per `theme_ui.set_stylebox`.
- `TilemapCell` shape per `tilemap.set_cells.cells[]`.
- `TilesetInfo` shape per `tilemap.tileset_info`.

## 20.9 Tech stack delta

- No new dependencies.
- New addon resource folder `addons/godot_mcp/presets/ui/` containing scaffold templates for each
  `kind`.

## 20.10 Acceptance criteria

- [ ] All 12 tools live; visible via `tools.list`.
- [ ] `tilemap.set_cells` round-trip — write, then `query_cells` returns identical data.
- [ ] `tilemap.terrain_paint` writes a contiguous path that survives reload.
- [ ] `theme_ui.set_color` mutates either a `Theme` resource OR a `Control`'s `theme_override_*`
      based on which target is provided.
- [ ] `theme_ui.preview` returns a PNG ≥ 256×256 with the expected widgets visible.
- [ ] `theme_ui.scaffold_screen` produces a scene that compiles (loadable via `scene.get`).

## 20.11 Verification plan

1. **Paint + read:** paint a 16×16 grass field; `query_cells` returns all 256 cells with the correct
   atlas coords.
2. **Terrain paint:** snake of 30 cells; visual diff against a golden PNG.
3. **Tileset describe:** golden snapshot of `tileset_main.tres` info; check stability across runs.
4. **Theme color override on Control:** override on a `Button`; `theme_ui.describe { control_path }`
   reports the override.
5. **Theme preview:** snapshot vs golden.
6. **Scaffolder:** create a Pause screen; `scene.get` reports the expected node count.

## 20.12 Risks & mitigations

| Risk                                                              | Mitigation                                                                                                                                                   |
| ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------- |
| Mixed Godot versions where `TileMapLayer` does not exist (≤ 4.2). | Feature-detect at runtime; expose `tilemap.api_version: "legacy"` in `describe`; degrade `terrain_paint` to legacy `set_cells_terrain_connect` on `TileMap`. |
| Large `set_cells` calls stall the editor thread.                  | Cap by `tilemap_max_cells_per_call`; chunk above; emit `event.tilemap.progress`.                                                                             |
| Per-Control theme overrides + `Theme` resources can conflict.     | `describe` always emits both sources with a `wins: "override"                                                                                                | "theme"` annotation. |
| `theme_ui.scaffold_screen` could lock the agent into one style.   | Templates are user-extensible (folder under `addons/godot_mcp/presets/ui/`); each template can be edited by the user.                                        |
| StyleBox property shape drift between versions.                   | Validate against a per-class allow-list before set.                                                                                                          |

## 20.13 Handoff checklist to file `21`

- [ ] Catalog version `0.12.0` pushed.
- [ ] 164 tools total live.
- [ ] UI preset library committed.
- [ ] Open `21-catalog-audio-and-input.md`.

## 20.14 Commit template

```text
feat(catalog): ship tilemap.* (6) and theme_ui.* (6) — Phase 3 work-unit #10

- TileMapLayer-first with legacy TileMap fallback
- Terrain auto-tile paint
- Theme + per-Control override editing with deterministic preview
- UI scaffolder for Title/Settings/HUD/Pause/Inventory/Dialog/Loading
- Bumps catalog_version 0.11.0 -> 0.12.0

Refs: docs/tasklist/20-catalog-tilemap-and-theme-ui.md
```
