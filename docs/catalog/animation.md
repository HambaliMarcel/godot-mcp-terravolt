# Catalog: `animation.*`

Phase 3 work-unit #8 — 6 daemon methods (`catalog_version` **0.10.0**).

| Method                   | Safe | Mutates | Headless |
| ------------------------ | ---- | ------- | -------- |
| `animation.list`         | yes  | no      | yes      |
| `animation.create`       | no   | yes     | yes      |
| `animation.add_track`    | no   | yes     | yes      |
| `animation.set_keyframes`| no   | yes     | yes      |
| `animation.play`         | no   | yes     | yes      |
| `animation.preview_export` | no | yes     | no (editor) |

Handlers: `packages/godot-mcp-addon/handlers/animation.gd`  
Helpers: `packages/godot-mcp-addon/handlers/animation_helpers.gd`

**v1 notes:** `animation.list` uses the edited scene in the editor; headless loads `application/run/main_scene` or instantiates scenes for `scope: "project"`. `animation.play` and `animation.preview_export` target runtime/editor respectively; preview export degrades to a PNG sequence when FFmpeg is unavailable.

Error band: `-33940` … `-33944` (+ shared scene/node errors).
