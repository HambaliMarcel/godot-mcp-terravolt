# Catalog: `resource.*`

Phase 3 work-unit #4 — 15 daemon methods (`catalog_version` **0.6.0**).

| Method                        | Safe | Mutates | Headless         |
| ----------------------------- | ---- | ------- | ---------------- |
| `resource.list`               | yes  | no      | yes              |
| `resource.get`                | yes  | no      | yes              |
| `resource.create`             | no   | yes     | yes              |
| `resource.update`             | no   | yes     | yes              |
| `resource.duplicate`          | no   | yes     | yes              |
| `resource.delete`             | no   | yes     | yes              |
| `resource.rename`             | no   | yes     | partial (editor) |
| `resource.get_dependencies`   | yes  | no      | yes              |
| `resource.get_dependents`     | yes  | no      | yes              |
| `resource.replace_references` | no   | yes     | partial (editor) |
| `resource.export_json`        | yes  | no      | yes              |
| `resource.import_json`        | no   | yes     | yes              |
| `resource.set_uid`            | no   | yes     | partial (editor) |
| `resource.validate`           | yes  | no      | yes              |
| `resource.diff`               | yes  | no      | yes              |

Handler: `packages/godot-mcp-addon/handlers/resource.gd`  
Helpers: `packages/godot-mcp-addon/handlers/resource_helpers.gd`

Error band: `-33800` … `-33805` (+ shared `resource.dependency_block` `-33550`).
