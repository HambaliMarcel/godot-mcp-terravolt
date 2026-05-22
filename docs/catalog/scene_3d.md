# Catalog: `scene_3d.*`

Phase 3 work-unit #12 — 6 daemon methods (`catalog_version` **0.14.0**).

| Method                       | Safe | Mutates | Headless |
| ---------------------------- | ---- | ------- | -------- |
| `scene_3d.add_mesh_instance` | no   | yes     | yes      |
| `scene_3d.add_camera`        | no   | yes     | yes      |
| `scene_3d.add_light`         | no   | yes     | yes      |
| `scene_3d.set_environment`   | no   | yes     | yes      |
| `scene_3d.add_gridmap`       | no   | yes     | yes      |
| `scene_3d.frame_subject`     | no   | yes     | yes      |

Handlers: `packages/godot-mcp-addon/handlers/scene_3d.gd`  
Helpers: `packages/godot-mcp-addon/handlers/scene_3d_helpers.gd`

3D scene sugar on top of `node.add` / `node.modify`: mesh instances (primitive or resource),
cameras, lights, `WorldEnvironment`, `GridMap`, and smart camera framing.

Constants:

- `scene_3d_default_light_energy` = **1.0**
- `scene_3d_default_camera_fov` = **75.0** (degrees)
- GridMap cell cap reuses `tilemap_max_cells_per_call` = **4096**

Material assignment uses `set_surface_override_material(0, …)` (per-surface slot 0).

`scene_3d.set_environment` is idempotent: an existing `WorldEnvironment` under the scene root is
updated instead of creating a duplicate.

Error band: `-33980` … `-33982`.

| Code     | Symbol                           |
| -------- | -------------------------------- |
| `-33980` | `scene_3d.primitive_unknown`     |
| `-33981` | `scene_3d.mesh_library_unknown`  |
| `-33982` | `scene_3d.gridmap_cells_invalid` |
