# Catalog: `input.*`

Phase 3 work-unit #11 — 7 daemon methods (`catalog_version` **0.13.0**).

| Method                    | Safe | Mutates | Headless |
| ------------------------- | ---- | ------- | -------- |
| `input.list_actions`      | yes  | no      | yes      |
| `input.add_action`        | no   | yes     | yes      |
| `input.remove_action`     | no   | yes     | yes      |
| `input.set_action_events` | no   | yes     | yes      |
| `input.rename_action`     | no   | yes     | yes      |
| `input.simulate_action`   | no   | yes     | yes      |
| `input.describe_event`    | yes  | no      | yes      |

Handlers: `packages/godot-mcp-addon/handlers/input.gd`  
Helpers: `packages/godot-mcp-addon/handlers/input_helpers.gd`

Event shape: `packages/shared/schemas/common/InputEventLike.json`.  
Actions persist under `ProjectSettings` `input/<name>` keys.

Error band: `-33975` … `-33977`.
