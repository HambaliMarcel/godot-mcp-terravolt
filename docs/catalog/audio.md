# Catalog: `audio.*`

Phase 3 work-unit #11 — 6 daemon methods (`catalog_version` **0.13.0**).

| Method               | Safe | Mutates | Headless |
| -------------------- | ---- | ------- | -------- |
| `audio.list_buses`   | yes  | no      | yes      |
| `audio.add_bus`      | no   | yes     | yes      |
| `audio.remove_bus`   | no   | yes     | yes      |
| `audio.set_bus`      | no   | yes     | yes      |
| `audio.add_effect`   | no   | yes     | yes      |
| `audio.preview_play` | no   | no\*    | yes†     |

\* Transient `AudioStreamPlayer` only.  
† Returns `audio.preview_unavailable` in headless CI (no output device).

Handlers: `packages/godot-mcp-addon/handlers/audio.gd`  
Helpers: `packages/godot-mcp-addon/handlers/audio_helpers.gd`

Effect allow-list: `packages/shared/audio/effect_kinds.json`.  
Bus layout persistence writes `audio/buses/default_bus_layout` via `AudioServer.get_bus_layout()`.

Error band: `-33970` … `-33974`.
