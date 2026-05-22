# 22 — Catalog: `scene_3d.*` (Phase 3 work-unit #12)

> A small, focused category for the 3D-specific parts of scene authoring that don't fit cleanly into
> `scene.*` or `node.*`: mesh instances, cameras, lights, environment, GridMap, and Decals. Strictly
> additive — these tools are sugar on top of `node.add` + `node.modify`, but with 3D-aware defaults
> and safety.

---

## 22.1 Header

- **File:** `22-catalog-3d-scene.md`
- **Purpose:** ship `scene_3d.*` (6 tools).
- **Catalog bump:** `0.13.0` → **`0.14.0`** on land.

## 22.2 Phase placement

Phase 3, work-unit #12. Prerequisite: `21` shipped.

## 22.3 Inputs / prerequisites

- New handler `handlers/scene_3d.gd`.
- Router module `src/tools/scene_3d/`.
- Reuses `node.add` for tree mutation and `resource.create` for materials/environments.

## 22.4 Outputs

- 6 tools live, registered, validated, documented.
- New fixture: `tests/_fixtures/scene_3d_zoo/` (a Node3D root with a MeshInstance3D, OmniLight3D,
  Camera3D, WorldEnvironment, and a GridMap).
- `docs/catalog/scene_3d.md` regenerated.

## 22.5 Operating constants used

- `scene_3d_default_light_energy = 1.0`.
- `scene_3d_default_camera_fov = 75.0` (degrees).

---

## 22.6 `scene_3d.*` — 6 tools

### `scene_3d.add_mesh_instance`

- **Purpose:** add a `MeshInstance3D` with an optional mesh/material assignment.
- **Inputs:**
  `{ parent_path: NodePath, name?: string, transform?: TransformLike, mesh?: { source: "primitive"|"resource", primitive_kind?: "box"|"sphere"|"capsule"|"cylinder"|"plane"|"quad"|"prism"|"torus", primitive_params?: PropertyDict, resource_path?: ResourcePath }, material?: { source: "resource"|"inline"|"none", resource_path?: ResourcePath, inline?: PropertyDict (for StandardMaterial3D) }, cast_shadow?: "off"|"on"|"double_sided"|"shadows_only" (default "on"), gi_mode?: "disabled"|"static"|"dynamic" (default "static") }`.
- **Outputs:**
  `{ added_path: NodePath, mesh_resource_path?: ResourcePath, material_resource_path?: ResourcePath, state, revision }`.
- **Godot APIs:** instantiate `MeshInstance3D`; for primitives, `BoxMesh.new()`, `SphereMesh.new()`,
  etc.; for resources, `ResourceLoader.load`. Material via `StandardMaterial3D.new()` or load.
  Configure shadow / GI properties.
- **safe:** false. **mutates:** true.
- **Errors:** `scene_3d.primitive_unknown` (`-33J00`).
- **Cursor prompt:** _"Add a 2m box mesh under /World named Crate, with the wood material."_

### `scene_3d.add_camera`

- **Purpose:** add a `Camera3D` with optional "current" toggle.
- **Inputs:**
  `{ parent_path: NodePath, name?: string, transform?: TransformLike, fov?: float (default 75), near?: float (default 0.05), far?: float (default 4000), projection?: "perspective"|"orthogonal"|"frustum" (default "perspective"), current?: bool (default false), cull_mask?: BitMask }`.
- **Outputs:** `{ added_path: NodePath, current: bool, state, revision }`.
- **Godot APIs:** instantiate `Camera3D`; configure properties; if `current=true`, call
  `Camera3D.make_current()` (only one active per viewport).
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Add a perspective Camera3D under /Player named EyeCam, fov=70,
  current=true."_

### `scene_3d.add_light`

- **Purpose:** add a directional / omni / spot light.
- **Inputs:**
  `{ parent_path: NodePath, name?: string, transform?: TransformLike, kind: "directional"|"omni"|"spot", color?: Color, energy?: float (default 1.0), shadow_enabled?: bool (default true), bake_mode?: "disabled"|"static"|"dynamic" (default "dynamic"), range?: float (omni/spot), angle_deg?: float (spot), inner_angle_deg?: float (spot) }`.
- **Outputs:** `{ added_path, kind, state, revision }`.
- **Godot APIs:** instantiate `DirectionalLight3D` / `OmniLight3D` / `SpotLight3D`; configure shared
  `light_color/light_energy/shadow_enabled/light_bake_mode` and kind-specific properties.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Add an omni light under /World/Crate at (0,2,0) with warm color and energy
  1.5."_

### `scene_3d.set_environment`

- **Purpose:** add or update a `WorldEnvironment` (sky + fog + ambient + tonemap).
- **Inputs:**
  `{ scene_root_path?: NodePath (default active root), spec: { background?: "clear_color"|"sky"|"color"|"canvas"|"custom_color", sky?: { kind: "procedural"|"physical"|"panorama", params?: PropertyDict }, ambient_light?: { source: "background"|"disabled"|"color"|"sky", color?: Color, energy?: float }, tonemap?: { mode: "linear"|"reinhard"|"filmic"|"aces", exposure?: float, white?: float }, fog?: { enabled: bool, color?: Color, density?: float, height?: float, sun_scatter?: float }, glow?: { enabled: bool, intensity?: float, strength?: float, bloom?: float }, ssao?: { enabled: bool, radius?: float, intensity?: float }, ssr?: { enabled: bool, max_steps?: int } } }`.
- **Outputs:**
  `{ environment_path: NodePath, environment_resource_path?: ResourcePath, state, revision }`.
- **Godot APIs:** ensure a `WorldEnvironment` exists (create one if not); attach
  `Environment.new()`; populate properties. For sky, instantiate `Sky.new()` +
  `ProceduralSkyMaterial.new()` etc.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Set up a sunny sky with mild fog and filmic tonemap on the active scene."_

### `scene_3d.add_gridmap`

- **Purpose:** add a `GridMap` with a chosen `MeshLibrary` and (optionally) seeded cells.
- **Inputs:**
  `{ parent_path: NodePath, name?: string, transform?: TransformLike, mesh_library_path: ResourcePath, cell_size?: Vector3 (default 1,1,1), cells?: [{ position: [x,y,z], item: int, orientation?: int }] }`.
- **Outputs:** `{ added_path: NodePath, mesh_library_path, cells_written: int, state, revision }`.
- **Godot APIs:** instantiate `GridMap`; `gridmap.mesh_library = load(path)`;
  `gridmap.cell_size = cell_size`; `gridmap.set_cell_item(pos, item, orientation)` per cell.
- **safe:** false. **mutates:** true.
- **Errors:** `scene_3d.mesh_library_unknown` (`-33J10`), `scene_3d.gridmap_cells_invalid`
  (`-33J11`).
- **Cursor prompt:** _"Add a GridMap using res://world/blocks.tres seeded with a 5×1×5 floor."_

### `scene_3d.frame_subject`

- **Purpose:** position a camera to frame a subject (or set of subjects) using its global AABB.
- **Inputs:**
  `{ camera_path: NodePath, subjects: [NodePath], margin?: float (default 1.2), pitch_deg?: float (default -15), yaw_deg?: float (default 30) }`.
- **Outputs:** `{ updated: true, applied_transform: TransformLike, framed_aabb: { center, size } }`.
- **Godot APIs:** compute combined `AABB` from subject `VisualInstance3D.get_aabb()` (with
  `global_transform`); fit camera distance from FOV + AABB diagonal; set
  `Camera3D.global_transform`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Frame the camera so /Boss and /Player are both visible."_

---

## 22.7 Schemes / data shapes added

- `EnvironmentSpec` per `scene_3d.set_environment.spec`.
- `GridmapCell` shape: `{ position: [x, y, z], item: int, orientation?: int }`.
- `PrimitiveMeshSpec` per `scene_3d.add_mesh_instance.mesh.primitive_*`.

## 22.8 Tech stack delta

- No new dependencies.
- Builds on `node.add` + `resource.create` machinery from `12` and `14`.

## 22.9 Acceptance criteria

- [ ] All 6 tools live; visible via `tools.list({category: "scene_3d"})`.
- [ ] `scene_3d.add_mesh_instance` with `mesh.source=primitive` creates a fully working node
      (visible in `editor.screenshot`).
- [ ] `scene_3d.add_camera { current: true }` makes that camera the active one for viewport
      rendering.
- [ ] `scene_3d.set_environment` is idempotent (running twice doesn't create two `WorldEnvironment`
      nodes).
- [ ] `scene_3d.frame_subject` produces a camera position from which `get_aabb()` of each subject
      lies inside the viewport rect.
- [ ] `scene_3d.add_gridmap` with seeded cells survives reload and round-trips via `node.get`.

## 22.10 Verification plan

1. **Visual:** add box + omni light + camera; screenshot; assert non-black, non-magenta center pixel
   (something is rendered).
2. **Environment idempotency:** run `set_environment` twice; only one `WorldEnvironment` exists.
3. **Frame:** add two distant subjects; `frame_subject` brings both inside the viewport (verify via
   screenshot bounding box detection).
4. **GridMap:** seed a 3×3 floor; `get_cell_item` returns same items.
5. **Headless:** all create operations succeed via `headless.run_project` on a minimal fixture.

## 22.11 Risks & mitigations

| Risk                                                                                        | Mitigation                                                                                                                |
| ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | --------------- |
| Material assignment varies between `surface_material_override_0` and `material_override`.   | Document the rule (per-surface preferred); allow both via `material_target: "global"                                      | "per_surface"`. |
| Environment is global to the active scene tree, but multiple WorldEnvironments can coexist. | `set_environment` detects duplicates and warns; idempotency means: replace the topmost.                                   |
| `Camera3D.make_current()` invalidates the editor's camera.                                  | Only call when `current=true` is explicit; restore editor camera on `runtime.stop`.                                       |
| GridMap memory cost with very large cell counts.                                            | Cap `cells.length` at `tilemap_max_cells_per_call` (re-use constant); chunk above with `event.scene_3d.gridmap_progress`. |
| `frame_subject` with subjects spanning very large AABBs may push camera through walls.      | Document caveat; tool returns AABB so the agent can adjust manually.                                                      |

## 22.12 Handoff checklist to file `23`

- [ ] Catalog version `0.14.0` pushed.
- [ ] 183 tools total live.
- [ ] 3D scene zoo fixture committed.
- [ ] Open `23-catalog-testing-profiling-export.md`.

## 22.13 Commit template

```text
feat(catalog): ship scene_3d.* (6 tools) — Phase 3 work-unit #12

- Mesh instances with primitive or resource meshes and material assignment
- Cameras (perspective/ortho/frustum) with current toggle
- Directional / omni / spot lights with shadow + bake config
- WorldEnvironment with sky / fog / tonemap / glow / SSAO / SSR
- GridMap creation with seeded cells
- Smart frame_subject camera framing
- Bumps catalog_version 0.13.0 -> 0.14.0

Refs: docs/tasklist/22-catalog-3d-scene.md
```
