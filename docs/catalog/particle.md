# Catalog: `particle.*`

Phase 3 work-unit #9 — 5 daemon methods (`catalog_version` **0.11.0**).

| Method                  | Safe | Mutates | Headless |
| ----------------------- | ---- | ------- | -------- |
| `particle.add_system`   | no   | yes     | yes      |
| `particle.set_material` | no   | yes     | yes      |
| `particle.preview`      | no   | yes     | yes      |
| `particle.set_emission` | no   | yes     | yes      |
| `particle.list_presets` | no\* | yes\*   | yes      |

\*Mutates only when `apply_to` + `preset_name` are supplied.

Handler: `packages/godot-mcp-addon/handlers/particle.gd`  
Helpers: `packages/godot-mcp-addon/handlers/particle_helpers.gd`  
Preset library: `packages/shared/presets/particle/*.json` (snow, fire, smoke, sparks, dust)

Operating constants: `particle_preview_frames = 30`.

Error code: `-33953` (`particle.gpu_unsupported` — CPU fallback note).
