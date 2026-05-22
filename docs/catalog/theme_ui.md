# Catalog: `theme_ui.*`

Phase 3 work-unit #10 — 6 daemon methods (`catalog_version` **0.12.0**).

| Method                    | Safe | Mutates | Headless |
| ------------------------- | ---- | ------- | -------- |
| `theme_ui.describe`       | yes  | no      | yes      |
| `theme_ui.set_color`      | no   | yes     | yes      |
| `theme_ui.set_font`       | no   | yes     | yes      |
| `theme_ui.set_stylebox`   | no   | yes     | yes      |
| `theme_ui.preview`        | yes  | no      | yes      |
| `theme_ui.scaffold_screen`| no   | yes     | yes      |

Handlers: `packages/godot-mcp-addon/handlers/theme_ui.gd`  
Helpers: `packages/godot-mcp-addon/handlers/theme_ui_helpers.gd`  
Scaffold presets: `packages/shared/presets/ui/` (mirrored under `packages/godot-mcp-addon/presets/ui/`).

`theme_preview_size` default: **256×256**. `Color` accepts `{ r, g, b, a }` or `#RRGGBBAA` strings.

Error band: `-33965` … `-33969`.
