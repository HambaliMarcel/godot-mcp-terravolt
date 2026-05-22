# Catalog: `export.*`

Phase 3 work-unit #13 — 3 daemon methods (`catalog_version` **0.15.0**).

| Method                 | Safe | Mutates | Headless |
| ---------------------- | ---- | ------- | -------- |
| `export.list_presets`  | yes  | no      | yes      |
| `export.build`         | no   | yes     | yes      |
| `export.template_info` | yes  | no      | yes      |

Handlers: `packages/godot-mcp-addon/handlers/export.gd`  
Helpers: `packages/godot-mcp-addon/handlers/export_helpers.gd`

`export.list_presets` parses `export_presets.cfg`. `export.build` spawns
`godot --headless --export-pack` or `--export-debug` / `--export-release` (same subprocess pattern
as `runtime.start_headless`). `export.template_info` scans the templates directory and sets
`mismatched` when folder versions differ from the running editor.

Error band: `-33994` … `-33996`.
