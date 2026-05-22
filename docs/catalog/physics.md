# Catalog: `physics.*`

Phase 3 work-unit #9 — 6 daemon methods (`catalog_version` **0.11.0**).

| Method                   | Safe | Mutates | Headless |
| ------------------------ | ---- | ------- | -------- |
| `physics.add_body`       | no   | yes     | yes      |
| `physics.set_layers`     | no   | yes     | yes      |
| `physics.list_layers`    | yes  | no      | yes      |
| `physics.set_layer_name` | no   | yes     | yes      |
| `physics.raycast`        | yes  | no      | yes      |
| `physics.set_gravity`    | no   | yes     | yes      |

Handler: `packages/godot-mcp-addon/handlers/physics.gd`  
Helpers: `packages/godot-mcp-addon/handlers/physics_helpers.gd`

Operating constants: `physics_raycast_max_per_call = 64`.

Layer indices are **1-based** in inputs/outputs; responses always include `{ bits, names }`.

Error band: `-33950` … `-33952`.
