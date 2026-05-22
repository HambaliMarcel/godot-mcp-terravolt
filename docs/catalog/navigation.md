# Catalog: `navigation.*`

Phase 3 work-unit #9 — 6 daemon methods (`catalog_version` **0.11.0**).

| Method                     | Safe | Mutates | Headless |
| -------------------------- | ---- | ------- | -------- |
| `navigation.add_region`    | no   | yes     | yes      |
| `navigation.bake`          | no   | yes     | yes      |
| `navigation.add_agent`     | no   | yes     | yes      |
| `navigation.set_layers`    | no   | yes     | yes      |
| `navigation.path`          | yes  | no      | yes      |
| `navigation.debug_overlay` | no   | yes     | yes      |

Handler: `packages/godot-mcp-addon/handlers/navigation.gd`  
Helpers: `packages/godot-mcp-addon/handlers/navigation_helpers.gd`

Operating constants: `nav_bake_timeout_ms = 120000`.

Navigation layer indices are **1-based** in inputs/outputs.

Error code: `-33954` (`navigation.bake_timeout`).
