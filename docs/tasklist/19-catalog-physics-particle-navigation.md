# 19 — Catalog: `physics.*` + `particle.*` + `navigation.*` (Phase 3 work-unit #9)

> Three simulation-system categories shipped together. `physics.*` covers rigid/static/character
> bodies, collision shapes, layers, raycasts. `particle.*` covers GPU/CPU particle systems,
> materials, gradients. `navigation.*` covers navigation regions, agents, baking, layer management.

---

## 19.1 Header

- **File:** `19-catalog-physics-particle-navigation.md`
- **Purpose:** ship `physics.*` (6) + `particle.*` (5) + `navigation.*` (6) — 17 total.
- **Catalog bump:** `0.10.0` → **`0.11.0`** on land.

## 19.2 Phase placement

Phase 3, work-unit #9. Prerequisite: `18` shipped.

## 19.3 Inputs / prerequisites

- New handlers: `handlers/physics.gd`, `handlers/particle.gd`, `handlers/navigation.gd`.
- Router modules under `src/tools/physics/`, `src/tools/particle/`, `src/tools/navigation/`.
- Layer/mask presentation always exposes both `bits: int` and `layer_names: [string]` (looked up
  from `ProjectSettings`).

## 19.4 Outputs

- 17 tools live, registered, validated, documented.
- New fixtures: `tests/_fixtures/physics_zoo/`, `tests/_fixtures/particle_zoo/`,
  `tests/_fixtures/nav_zoo/`.
- `docs/catalog/physics.md`, `docs/catalog/particle.md`, `docs/catalog/navigation.md` regenerated.

## 19.5 Operating constants used

- `physics_raycast_max_per_call = 64`.
- `particle_preview_frames = 30`.
- `nav_bake_timeout_ms = 120000`.

---

## 19.6 `physics.*` — 6 tools

### `physics.add_body`

- **Purpose:** add a physics body node (with optional collision shape) under a parent.
- **Inputs:**
  `{ parent_path: NodePath, kind: "static"|"rigid"|"character"|"area"|"animatable", dimension: "2d"|"3d", name?: string, transform?: { position?, rotation?, scale? }, shape?: { kind: "box"|"sphere"|"capsule"|"cylinder"|"convex"|"concave"|"world_boundary"|"rectangle"|"circle"|"segment", params: PropertyDict }, mass?: float, gravity_scale?: float, layer?: BitMask, mask?: BitMask }`.
- **Outputs:** `{ added_path: NodePath, body_kind, shape_path?: NodePath, state, revision }`.
- **Godot APIs:** instantiate `StaticBody2D/3D` / `RigidBody2D/3D` / `CharacterBody2D/3D` /
  `AnimatableBody2D/3D` / `Area2D/3D`; add a `CollisionShape*` child with the requested `Shape*`
  resource (e.g., `BoxShape3D`); configure properties.
- **safe:** false. **mutates:** true.
- **Errors:** `physics.shape_kind_unknown` (`-33E00`), `physics.dimension_mismatch` (`-33E01`).
- **Cursor prompt:** _"Add a rigid 3D body under /root/Main/Pile with a box shape (1×2×1) and mass
  5."_

### `physics.set_layers`

- **Purpose:** set collision layer / mask on a body.
- **Inputs:**
  `{ path: NodePath, layer?: BitMask|{ named: [string] }, mask?: BitMask|{ named: [string] } }`.
- **Outputs:** `{ updated: true, layer: { bits, names }, mask: { bits, names } }`.
- **Godot APIs:** `CollisionObject2D/3D.collision_layer` / `collision_mask`; lookup names via
  `ProjectSettings.get_setting("layer_names/<2d/3d>/physics/layer_<n>")`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Set /Player layer to ['player'] and mask to ['enemies', 'world']."_

### `physics.list_layers`

- **Purpose:** list named physics layers (2D and 3D) defined in `ProjectSettings`.
- **Inputs:** `{ dimension?: "2d"|"3d"|"both" (default "both") }`.
- **Outputs:** `{ layers_2d: [{ index, name }], layers_3d: [{ index, name }] }`.
- **Godot APIs:** read `ProjectSettings` keys `layer_names/2d_physics/layer_*`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"What are my physics layers?"_

### `physics.set_layer_name`

- **Purpose:** name (or rename) a physics layer.
- **Inputs:** `{ dimension: "2d"|"3d", index: int (1..32), name: string }`.
- **Outputs:** `{ updated: true, index, name }`.
- **Godot APIs:** `ProjectSettings.set_setting("layer_names/<2d/3d>_physics/layer_<n>", name)`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Name 3D physics layer 2 'enemies'."_

### `physics.raycast`

- **Purpose:** issue a raycast against the live or editor scene physics space.
- **Inputs:**
  `{ dimension: "2d"|"3d", from: Vector, to: Vector, mask?: BitMask|{ named: [string] }, exclude?: [NodePath], hit_areas?: bool (default false), batch?: [{ from, to, mask?, exclude? }] (overrides scalar fields) }`.
- **Outputs:**
  `{ results: [{ hit: bool, position?, normal?, collider_path?: NodePath, distance? }] }`.
- **Godot APIs:**
  `PhysicsDirectSpaceState2D/3D.intersect_ray(PhysicsRayQueryParameters*.create(...))`; must run
  inside `_physics_process` or via the runtime bridge.
- **safe:** true. **mutates:** false.
- **Errors:** `physics.batch_too_large` (`-33E02`).
- **Cursor prompt:** _"Cast a ray from /Player.global_position downward 10m and tell me what's
  there."_

### `physics.set_gravity`

- **Purpose:** mutate global gravity (vector + magnitude) per dimension.
- **Inputs:** `{ dimension: "2d"|"3d", direction?: Vector (unit), magnitude?: float }`.
- **Outputs:** `{ before: { direction, magnitude }, after: { direction, magnitude } }`.
- **Godot APIs:**
  `ProjectSettings.set_setting("physics/<2d/3d>/default_gravity_vector"|"default_gravity", value)`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Set 3D gravity to 5 m/s² pointing -y."_

---

## 19.7 `particle.*` — 5 tools

### `particle.add_system`

- **Purpose:** add a `GPUParticles2D/3D` (or CPU fallback) under a parent with a process material.
- **Inputs:**
  `{ parent_path: NodePath, dimension: "2d"|"3d", use_gpu?: bool (default true), name?: string, transform?: TransformLike, amount?: int, lifetime?: float, emitting?: bool (default true), material?: PropertyDict (for ParticleProcessMaterial) }`.
- **Outputs:**
  `{ added_path, system_path: NodePath, material_path?: ResourcePath, state, revision }`.
- **Godot APIs:** instantiate `GPUParticles2D/3D` (or `CPUParticles2D/3D`); assign a
  `ParticleProcessMaterial`; configure `amount`/`lifetime`/`emitting`.
- **safe:** false. **mutates:** true.
- **Errors:** `particle.gpu_unsupported` (`-33F00`) (fallback note when GPU mode unavailable).
- **Cursor prompt:** _"Add a 3D GPU particle system under /Boss for a death burst (300 particles,
  1.5s life)."_

### `particle.set_material`

- **Purpose:** update properties on a particle process material (gradient, scale curve, emission
  shape, etc.).
- **Inputs:** `{ material_path: ResourcePath, patch: PropertyDict, if_match?: revision }`.
- **Outputs:** `{ updated: true, applied: { key: { before, after } } }`.
- **Godot APIs:** `ResourceLoader.load(material_path) → ParticleProcessMaterial`; per-property
  `Object.set`; `ResourceSaver.save`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"On the boss death material set scale_max=3.0 and color_ramp to a fire
  gradient."_

### `particle.preview`

- **Purpose:** render a short preview of a particle system.
- **Inputs:**
  `{ system_path: NodePath, duration_s?: float (default 1.0), fps?: int (default 24), format?: "png_sequence"|"gif"|"mp4" (default "gif") }`.
- **Outputs:** `{ exported: true, paths: [ResourcePath], format }`.
- **Godot APIs:** render via off-screen `SubViewport`; same exporter chain as
  `animation.preview_export`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Show me a 1s preview of /Boss/DeathBurst."_

### `particle.set_emission`

- **Purpose:** start / stop / one-shot emission.
- **Inputs:**
  `{ system_path: NodePath, action: "play"|"stop"|"emit_once"|"restart", amount?: int }`.
- **Outputs:** `{ done: true, emitting: bool }`.
- **Godot APIs:** `GPUParticles2D/3D.emitting`, `restart()`, `emit_particle(...)`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Restart the death burst once."_

### `particle.list_presets`

- **Purpose:** enumerate named presets and (optionally) apply one.
- **Inputs:** `{ apply_to?: NodePath, preset_name?: string }`.
- **Outputs:** `{ presets: [{ name, description }], applied?: { preset_name, applied_to } }`.
- **Godot APIs:** preset library shipped at `addons/godot_mcp/presets/particle/*.tres`; if
  `apply_to` provided, copy properties onto the target system's process material.
- **safe:** false (when applying). **mutates:** true (when applying).
- **Cursor prompt:** _"Apply the 'snow' particle preset to /WeatherSystem."_

---

## 19.8 `navigation.*` — 6 tools

### `navigation.add_region`

- **Purpose:** add a `NavigationRegion2D/3D` with a `NavigationMesh` / `NavigationPolygon`.
- **Inputs:**
  `{ parent_path: NodePath, dimension: "2d"|"3d", name?: string, transform?: TransformLike, navmesh?: { kind: "from_geometry"|"empty", geometry_paths?: [NodePath] } }`.
- **Outputs:**
  `{ added_path: NodePath, region_path: NodePath, navmesh_path?: ResourcePath, state, revision }`.
- **Godot APIs:** instantiate `NavigationRegion3D` / `NavigationRegion2D`; assign a `NavigationMesh`
  / `NavigationPolygon` resource.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Add a 3D nav region under /World/Ground covering the geometry under
  /World/Static."_

### `navigation.bake`

- **Purpose:** bake the navmesh / navpoly for a region (or all regions).
- **Inputs:**
  `{ region_path?: NodePath, scope?: "region"|"all_in_scene" (default "region"), cell_size?: float, agent_radius?: float, agent_height?: float, max_slope_deg?: float, edge_max_length?: float }`.
- **Outputs:** `{ baked: int, durations_ms: [int], errors: [{ region_path, message }] }`.
- **Godot APIs:** `NavigationServer3D.region_bake_navigation_mesh(...)` /
  `NavigationRegion3D.bake_navigation_mesh()`; configurable bake parameters on the navmesh resource.
- **safe:** false. **mutates:** true.
- **Errors:** `navigation.bake_timeout` (`-33F10`).
- **Cursor prompt:** _"Bake every nav region in the current scene with cell_size 0.25."_

### `navigation.add_agent`

- **Purpose:** add a `NavigationAgent2D/3D` child to a body.
- **Inputs:**
  `{ parent_path: NodePath, dimension: "2d"|"3d", path_max_distance?: float, target_desired_distance?: float, radius?: float, navigation_layers?: BitMask }`.
- **Outputs:** `{ added_path: NodePath, agent_path: NodePath, state, revision }`.
- **Godot APIs:** instantiate `NavigationAgent2D/3D`; configure properties.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Add a 3D nav agent to /Enemies/Goblin."_

### `navigation.set_layers`

- **Purpose:** set navigation layer / mask names and bits.
- **Inputs:**
  `{ dimension: "2d"|"3d", layer_index?: int, layer_name?: string, target_path?: NodePath, navigation_layers?: BitMask }`.
- **Outputs:** `{ updated: true }`.
- **Godot APIs:** rename via
  `ProjectSettings.set_setting("layer_names/<2d/3d>_navigation/layer_<n>", name)`; assign on
  `NavigationAgent` via `navigation_layers`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Name 3D nav layer 1 'walkable' and put /Goblin on it."_

### `navigation.path`

- **Purpose:** compute a navigation path between two points using the active map.
- **Inputs:**
  `{ dimension: "2d"|"3d", from: Vector, to: Vector, layers?: BitMask, optimize?: bool (default true) }`.
- **Outputs:** `{ path: [Vector], length, ok: bool }`.
- **Godot APIs:** `NavigationServer3D.map_get_path(map, from, to, optimize, layers)`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Find a 3D path from /Player.global_position to /PointB.global_position."_

### `navigation.debug_overlay`

- **Purpose:** toggle navigation debug overlay (in editor or runtime).
- **Inputs:** `{ enabled: bool, scope?: "editor"|"runtime" (default "runtime") }`.
- **Outputs:** `{ enabled }`.
- **Godot APIs:** `get_tree().debug_navigation_hint = bool` for runtime; `EditorInterface` toggle
  for editor.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Show the nav debug overlay in the running game."_

---

## 19.9 Schemes / data shapes added

- `BitMask` shape: `{ bits: int, names?: [string] }` — accept either form on input; always return
  both on output.
- `TransformLike` shape:
  `{ position?: Vector, rotation?: Vector|Quat, scale?: Vector, transform2d?: [[a,b],[c,d],[tx,ty]], transform3d?: [[...x3...],[...y3...],[...z3...],[...origin...]] }`
  — accepts either decomposed or matrix form.
- `Shape2DOr3D` discriminated union per `physics.add_body { shape }`.
- `NavmeshSpec` per `navigation.add_region`.

## 19.10 Tech stack delta

- No new third-party deps.
- New addon resource folder `addons/godot_mcp/presets/particle/`.

## 19.11 Acceptance criteria

- [ ] All 17 tools live; visible via `tools.list`.
- [ ] Shape kind allow-list matches what `ClassDB.instantiate` accepts in the current Godot minor.
- [ ] Layer/mask round-trip: set by name; read returns same names + bits.
- [ ] Bake completes within `nav_bake_timeout_ms` on the `nav_zoo` fixture.
- [ ] Path query returns a non-empty path for two points on the same baked region.

## 19.12 Verification plan

1. **Body + raycast:** add a static body; raycast above it; result reports the body.
2. **Layer naming:** rename a layer; `physics.set_layers { named: [...] }` resolves to the renamed
   bits.
3. **Particle preset:** apply a preset; `particle.preview` produces a 1s GIF.
4. **Nav round-trip:** add region + agent + bake + path; agent navigates in the headless fixture.
5. **Debug overlay:** runtime overlay visible in `runtime.screenshot` (visual diff against golden).

## 19.13 Risks & mitigations

| Risk                                                           | Mitigation                                                                                                                       |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Bake is CPU-heavy; can stall the editor.                       | Run bakes on a background thread where possible; otherwise stream progress via `event.navigation.bake_progress`.                 |
| Layer index 0 vs 1 confusion.                                  | Terravolt always uses **1-indexed** layer numbers in inputs/outputs; document explicitly.                                        |
| GPU particles unavailable on some platforms.                   | Detect via `RenderingServer.has_feature("particles_gpu")`; auto-fallback to `CPUParticles*`; surface `particle.gpu_unsupported`. |
| Raycasts outside `_physics_process` return stale results.      | Always run inside the physics step (use runtime bridge `process_priority`); document caveat.                                     |
| Adding shape with wrong dimension (`BoxShape3D` on a 2D body). | Pre-check dimension; raise `physics.dimension_mismatch`.                                                                         |

## 19.14 Handoff checklist to file `20`

- [ ] Catalog version `0.11.0` pushed.
- [ ] 152 tools total live.
- [ ] Particle preset library committed.
- [ ] Open `20-catalog-tilemap-and-theme-ui.md`.

## 19.15 Commit template

```text
feat(catalog): ship physics.* (6), particle.* (5), navigation.* (6) — Phase 3 work-unit #9

- Dimension-aware body and shape construction
- Named layer/mask interop (project settings)
- Bake + path queries against the live nav server
- Particle preset library (snow, fire, smoke, sparks, dust)
- Bumps catalog_version 0.10.0 -> 0.11.0

Refs: docs/tasklist/19-catalog-physics-particle-navigation.md
```
