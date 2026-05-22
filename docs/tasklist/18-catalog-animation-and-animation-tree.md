# 18 — Catalog: `animation.*` + `animation_tree.*` (Phase 3 work-unit #8)

> Animation in Godot lives in two layers: classic `AnimationPlayer` + `Animation` resources
> (track-based keyframes) and the newer `AnimationTree` graph (state machines, blend trees,
> transitions). TerraVolt exposes both with dedicated tools so the agent can wire idle/run/jump
> state machines, key transform tracks, tweak easing, and audit blend weights.

---

## 18.1 Header

- **File:** `18-catalog-animation-and-animation-tree.md`
- **Purpose:** ship `animation.*` (6 tools) + `animation_tree.*` (8 tools) — 14 total.
- **Catalog bump:** `0.9.0` → **`0.10.0`** on land.

## 18.2 Phase placement

Phase 3, work-unit #8. Prerequisite: `17` shipped.

## 18.3 Inputs / prerequisites

- New handlers: `handlers/animation.gd`, `handlers/animation_tree.gd`.
- Router modules: `src/tools/animation/`, `src/tools/animation_tree/`.
- Catalog `Animation` and `AnimationTree` are GDClass families; tool inputs use `NodePath`s to
  `AnimationPlayer` / `AnimationTree` nodes plus optional `animation_name` strings.

## 18.4 Outputs

- 14 tools live, registered, validated, documented.
- New fixtures: `tests/_fixtures/animation_zoo/` (an `AnimationPlayer` with idle/walk/run/death) and
  `tests/_fixtures/animation_tree_zoo/` (an `AnimationTree` with a `StateMachine` root).
- `docs/catalog/animation.md` and `docs/catalog/animation_tree.md` regenerated.

## 18.5 Operating constants used

- `anim_track_max_keys_inline = 256` — over this, return a `pointer_ref`.
- `anim_default_blend_seconds = 0.15`.

---

## 18.6 `animation.*` — 6 tools

### `animation.list`

- **Purpose:** list all `AnimationPlayer`s and their animations in a scene (or project).
- **Inputs:** `{ scope?: "active"|ScenePath|"project" (default "active") }`.
- **Outputs:**
  `{ players: [{ path: NodePath, library_count: int, animations: [{ name, length, step, loop_mode }] }] }`.
- **Godot APIs:** find nodes of type `AnimationPlayer`; `AnimationPlayer.get_animation_list()`;
  `AnimationPlayer.get_animation(name).length / step / loop_mode`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"List every animation in the active scene."_

### `animation.create`

- **Purpose:** create a new `Animation` resource (in a library) on an `AnimationPlayer`.
- **Inputs:**
  `{ player_path: NodePath, library?: string (default ""), name: string, length?: float (default 1.0), step?: float (default 0.1), loop_mode?: "none"|"linear"|"pingpong" (default "none") }`.
- **Outputs:** `{ created: true, player_path, library, name, state, revision }`.
- **Godot APIs:** `AnimationPlayer.get_animation_library(library)` or create a new
  `AnimationLibrary` via `add_animation_library(name, lib)`;
  `lib.add_animation(name, Animation.new())`; configure properties.
- **safe:** false. **mutates:** true.
- **Errors:** `animation.name_exists` (`-33D00`).
- **Cursor prompt:** _"Create a 1.5s 'idle' animation on /root/Main/Player/AnimPlayer."_

### `animation.add_track`

- **Purpose:** add a track (transform, property, method, audio, bezier, blend-shape) to an
  animation.
- **Inputs:**
  `{ player_path: NodePath, animation: string, library?: string, track: { type: "value"|"position3d"|"rotation3d"|"scale3d"|"method"|"audio"|"bezier"|"blend_shape"|"animation", path: NodePath, key?: string }, index?: int }`.
- **Outputs:** `{ track_index: int, state, revision }`.
- **Godot APIs:** `Animation.add_track(Animation.TYPE_*)`;
  `Animation.track_set_path(index, NodePath)`.
- **safe:** false. **mutates:** true.
- **Errors:** `animation.unknown` (`-33D01`), `animation.track_kind_unknown` (`-33D02`).
- **Cursor prompt:** _"Add a position3d track for /Player/Body on the 'walk' animation."_

### `animation.set_keyframes`

- **Purpose:** insert / replace keyframes on a track.
- **Inputs:**
  `{ player_path: NodePath, animation: string, library?: string, track_index: int, keys: [{ time: float, value: any, easing?: float, transition?: "linear"|"in"|"out"|"in_out"|"cubic"|"bezier", handles?: { in: [x,y], out: [x,y] } }], mode?: "replace_all"|"upsert" (default "upsert") }`.
- **Outputs:** `{ inserted: int, updated: int, removed: int, state, revision }`.
- **Godot APIs:** `Animation.track_insert_key(index, time, value, transition_or_easing)`,
  `track_remove_key`, `track_find_key`.
- **safe:** false. **mutates:** true.
- **Errors:** `animation.unknown`.
- **Cursor prompt:** _"Set keyframes for /Player/Body position on the 'walk' track: 0s=(0,0,0),
  0.5s=(0,0,1), 1.0s=(0,0,0)."_

### `animation.play`

- **Purpose:** play (or queue / stop) an animation at runtime — convenience over
  `runtime.call_method`.
- **Inputs:**
  `{ player_path: NodePath, name?: string, library?: string, action?: "play"|"play_backwards"|"queue"|"stop"|"pause", custom_blend?: float, from_end?: bool }`.
- **Outputs:** `{ done: true, current_animation?: string }`.
- **Godot APIs:** `AnimationPlayer.play/play_backwards/queue/stop/pause`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Play 'walk' on /Player/AnimPlayer."_

### `animation.preview_export`

- **Purpose:** export an animation as a GIF or short MP4 (best-effort) using the editor renderer.
- **Inputs:**
  `{ player_path: NodePath, name: string, format?: "gif"|"mp4" (default "gif"), fps?: int (default 24), duration_s?: float }`.
- **Outputs:** `{ exported: true, path: ResourcePath, format, size_bytes }`.
- **Godot APIs:** render frames via `SubViewport` capture; assemble via FFmpeg if available; degrade
  to PNG sequence if FFmpeg missing.
- **safe:** false. **mutates:** true (writes file).
- **Errors:** `animation.exporter_missing` (`-33D03`).
- **Cursor prompt:** _"Export the 'walk' animation as a GIF."_

---

## 18.7 `animation_tree.*` — 8 tools

### `animation_tree.describe`

- **Purpose:** describe an `AnimationTree`: root kind, parameters, transitions.
- **Inputs:** `{ tree_path: NodePath }`.
- **Outputs:**
  `{ root_kind: "BlendTree"|"StateMachine"|"BlendSpace2D"|"BlendSpace1D"|"Animation", states?: [{ name, animation?: string, transitions: [{ to, condition?, advance_mode? }] }], parameters: [{ name, type, default, hint? }], active_state?: string }`.
- **Godot APIs:** `AnimationTree.get_tree_root()` returns an `AnimationNode`; walk its sub-nodes;
  `AnimationTree.parameters_base_path`; `AnimationNodeStateMachine` exposes states and transitions.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Describe /Player/AnimTree."_

### `animation_tree.set_active`

- **Purpose:** enable or disable processing on an `AnimationTree`.
- **Inputs:** `{ tree_path: NodePath, active: bool }`.
- **Outputs:** `{ active }`.
- **Godot APIs:** `AnimationTree.active = bool`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Turn the AnimationTree on."_

### `animation_tree.set_parameter`

- **Purpose:** set a parameter value (e.g., a blend factor, a `bool` condition, a state-machine
  `playback.travel(state)`).
- **Inputs:**
  `{ tree_path: NodePath, parameter: string, value: any, mode?: "set"|"travel"|"advance" (default "set") }`.
- **Outputs:** `{ set: true, parameter, before, after }`.
- **Godot APIs:** `AnimationTree.set("parameters/..." , value)`; for state-machine travel,
  `AnimationTree.get("parameters/<sm>/playback").travel(state)`.
- **safe:** false. **mutates:** true.
- **Errors:** `animation_tree.parameter_unknown` (`-33D10`).
- **Cursor prompt:** _"Travel to the 'jump' state on /Player/AnimTree."_

### `animation_tree.add_state`

- **Purpose:** add a state to a `StateMachine` root.
- **Inputs:**
  `{ tree_path: NodePath, state: { name: string, animation?: string, position?: [x,y] } }`.
- **Outputs:** `{ added: true, name, state, revision }`.
- **Godot APIs:** `AnimationNodeStateMachine.add_node(name, sub_node, position)`; sub-node is
  usually `AnimationNodeAnimation` referencing an animation name.
- **safe:** false. **mutates:** true.
- **Errors:** `animation_tree.state_exists` (`-33D11`).
- **Cursor prompt:** _"Add a 'death' state mapped to the 'death' animation."_

### `animation_tree.remove_state`

- **Purpose:** remove a state.
- **Inputs:** `{ tree_path: NodePath, name: string }`.
- **Outputs:** `{ removed: true, name, state, revision }`.
- **Godot APIs:** `AnimationNodeStateMachine.remove_node(name)`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Remove the 'death' state."_

### `animation_tree.add_transition`

- **Purpose:** add a transition between two states.
- **Inputs:**
  `{ tree_path: NodePath, from: string, to: string, transition: { xfade_time?: float, switch_mode?: "immediate"|"sync"|"at_end", advance_mode?: "disabled"|"enabled"|"auto", advance_condition?: string, priority?: int } }`.
- **Outputs:** `{ added: true, from, to, state, revision }`.
- **Godot APIs:**
  `AnimationNodeStateMachine.add_transition(from, to, AnimationNodeStateMachineTransition.new())`;
  configure transition props.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Add a transition idle → walk with xfade 0.2s, advance_condition='moving'."_

### `animation_tree.remove_transition`

- **Purpose:** remove a transition.
- **Inputs:** `{ tree_path: NodePath, from: string, to: string }`.
- **Outputs:** `{ removed: true, from, to, state, revision }`.
- **Godot APIs:** `AnimationNodeStateMachine.remove_transition_by_index(...)`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Remove the idle→walk transition."_

### `animation_tree.blend_audit`

- **Purpose:** snapshot blend weights / active states / current transition (read-only diagnostic for
  runtime).
- **Inputs:** `{ tree_path: NodePath }`.
- **Outputs:**
  `{ active_state?: string, blends: { parameter: { value, weight } }, current_transition?: { from, to, progress }, processing_time_us: int }`.
- **Godot APIs:** `AnimationTree.get(parameter_path)`;
  `AnimationNodeStateMachinePlayback.get_current_node()` / `get_fading_from_node()` /
  `get_current_play_position()`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"What's currently blending on /Player/AnimTree?"_

---

## 18.8 Schemes / data shapes added

- `AnimationTrack` shape:
  `{ index, type, path, key_count, length, interp: "nearest"|"linear"|"cubic", loop_wrap: bool }`.
- `StateMachineTransition` shape per inputs of `animation_tree.add_transition`.
- `BlendAudit` shape per `animation_tree.blend_audit` outputs.

## 18.9 Tech stack delta

- Optional dependency on `ffmpeg` for `animation.preview_export { format: "mp4" }`. Document
  install + autoHeal `animation.exporter_missing`.

## 18.10 Acceptance criteria

- [ ] All 14 tools live; visible via `tools.list`.
- [ ] Round-trip: `animation.create` → `animation.set_keyframes` → `animation.list` reflects the new
      track + key count.
- [ ] `animation.play` works against both editor and headless (with the runtime bridge).
- [ ] `animation_tree.add_state` followed by `add_transition` and `set_parameter { mode: "travel" }`
      actually transitions in the running game.
- [ ] `animation_tree.blend_audit` returns sane values when the tree is processing (active=true) and
      zeros when inactive.

## 18.11 Verification plan

1. **Create-then-play:** new animation `bow` on the `animation_zoo` fixture; `animation.play` makes
   the rig bow in the preview viewport.
2. **Keyframe accuracy:** set keys at `0,0.5,1.0` with `linear`; sample expressions at `0.25` return
   interpolated midpoint.
3. **State machine:** add state, add transition with `advance_condition="moving"`; runtime sets
   `moving=true` and bridge confirms state change.
4. **Blend audit:** mid-blend (xfade 0.5s, snapshot at 0.3s) → `current_transition.progress` ∈ (0.5,
   0.7) on stable hardware.

## 18.12 Risks & mitigations

| Risk                                                           | Mitigation                                                                                                     |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `Animation.track_insert_key` value shape varies by track type. | Validate per `track.type` (e.g., `position3d` requires Vector3); reject early with structured error.           |
| `AnimationTree` parameters_base_path differs between minors.   | Always normalize via `AnimationTree.get_parameter_default_value()` introspection rather than hardcoding paths. |
| GIF export quality is poor; MP4 export fails without FFmpeg.   | Surface `animation.exporter_missing` with autoHeal command; fall back to PNG sequence + `frames.txt` manifest. |
| Adding too many keys creates large outputs.                    | Envelope/pointer over `anim_track_max_keys_inline`.                                                            |
| State-machine cycles cause unreachable states.                 | `animation_tree.add_transition` runs a cycle check and warns (does not block) on a created cycle.              |

## 18.13 Handoff checklist to file `19`

- [ ] Catalog version `0.10.0` pushed.
- [ ] 135 tools total live.
- [ ] Animation fixtures committed.
- [ ] Open `19-catalog-physics-particle-navigation.md`.

## 18.14 Commit template

```text
feat(catalog): ship animation.* (6) and animation_tree.* (8) — Phase 3 work-unit #8

- Track-based keyframe writer with per-type validation
- StateMachine state/transition CRUD
- Live blend audit for running games
- Optional FFmpeg-backed preview export, autoHeal otherwise
- Bumps catalog_version 0.9.0 -> 0.10.0

Refs: docs/tasklist/18-catalog-animation-and-animation-tree.md
```
