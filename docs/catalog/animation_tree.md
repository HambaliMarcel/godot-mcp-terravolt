# Catalog: `animation_tree.*`

Phase 3 work-unit #8 — 8 daemon methods (`catalog_version` **0.10.0**).

| Method                             | Safe | Mutates | Headless |
| ---------------------------------- | ---- | ------- | -------- |
| `animation_tree.describe`          | yes  | no      | yes      |
| `animation_tree.set_active`        | no   | yes     | yes      |
| `animation_tree.set_parameter`     | no   | yes     | yes      |
| `animation_tree.add_state`         | no   | yes     | yes      |
| `animation_tree.remove_state`      | no   | yes     | yes      |
| `animation_tree.add_transition`    | no   | yes     | yes      |
| `animation_tree.remove_transition` | no   | yes     | yes      |
| `animation_tree.blend_audit`       | yes  | no      | yes      |

Handlers: `packages/godot-mcp-addon/handlers/animation_tree.gd`  
Helpers: `packages/godot-mcp-addon/handlers/animation_helpers.gd` (shared with `animation.*`)

**v1 notes:** State-machine CRUD requires an `AnimationTree` whose `tree_root` is an
`AnimationNodeStateMachine`. `set_parameter` with `mode: "travel"` expects a `…/playback` parameter
of type `AnimationNodeStateMachinePlayback`.

Error band: `-33945` … `-33949` (+ shared scene/node errors).
