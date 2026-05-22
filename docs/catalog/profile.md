# Catalog: `profile.*`

Phase 3 work-unit #13 — 2 daemon methods (`catalog_version` **0.15.0**).

| Method               | Safe | Mutates | Headless |
| -------------------- | ---- | ------- | -------- |
| `profile.monitor`    | yes  | no      | yes      |
| `profile.flamegraph` | yes  | yes     | yes      |

Handlers: `packages/godot-mcp-addon/handlers/profile.gd`  
Helpers: `packages/godot-mcp-addon/handlers/profile_helpers.gd`

`profile.monitor` samples `Performance.get_monitor` keys (FPS, memory, draw calls) at
`window_ms / samples` cadence. `profile.flamegraph` writes JSON under
`user://terravolt/flamegraphs/` (full profiler API when debug build allows).

Error band: `-33993`.
