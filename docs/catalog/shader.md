# Catalog: `shader.*`

Phase 3 work-unit #4 — 6 daemon methods (`catalog_version` **0.6.0**).

| Method                       | Safe | Mutates | Headless |
| ---------------------------- | ---- | ------- | -------- |
| `shader.list`                | yes  | no      | yes      |
| `shader.read`                | yes  | no      | yes      |
| `shader.write`               | no   | yes     | yes      |
| `shader.compile_check`       | yes  | no      | yes      |
| `shader.list_params`         | yes  | no      | yes      |
| `shader.set_material_params` | no   | yes     | yes      |

Handler: `packages/godot-mcp-addon/handlers/shader.gd`

Error band: `-33806` … `-33808`.
