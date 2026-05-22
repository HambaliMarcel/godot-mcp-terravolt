# Catalog: `editor.*`

Phase 3 work-unit #6 — 9 daemon methods (`catalog_version` **0.8.0**).

| Method                  | Safe | Mutates | Headless |
| ----------------------- | ---- | ------- | -------- |
| `editor.screenshot`     | yes  | no      | no       |
| `editor.focus_node`     | yes  | no      | no       |
| `editor.open_script`    | yes  | no      | no       |
| `editor.run_undo`       | no   | yes     | no       |
| `editor.run_redo`       | no   | yes     | no       |
| `editor.execute_script` | no   | depends | no       |
| `editor.error_log_tail` | yes  | no      | partial  |
| `editor.reload_scripts` | no   | yes     | no       |
| `editor.layout`         | no   | yes     | no       |

Handler: `packages/godot-mcp-addon/handlers/editor.gd`  
Buffer: `packages/godot-mcp-addon/services/editor_error_buffer.gd`  
Deny-list: `packages/shared/security/expression_denylist.json`

Error band: `-33920` … `-33923`.
