# Catalog: `testing.*`

Phase 3 work-unit #13 — 6 daemon methods (`catalog_version` **0.15.0**).

| Method                       | Safe | Mutates | Headless |
| ---------------------------- | ---- | ------- | -------- |
| `testing.list_suites`        | yes  | no      | yes      |
| `testing.run`                | no   | yes     | yes      |
| `testing.assert_state`       | yes  | no      | yes      |
| `testing.screenshot_compare` | no   | yes     | yes      |
| `testing.list_reports`       | yes  | no      | yes      |
| `testing.get_report`         | yes  | no      | yes      |

Handlers: `packages/godot-mcp-addon/handlers/testing.gd`  
Helpers: `packages/godot-mcp-addon/handlers/testing_helpers.gd`

`testing.run` detects GUT via `res://addons/gut/` and spawns
`godot --headless -s addons/gut/gut_cmdln.gd` when `gut_cmdln.gd` exists; otherwise returns a
structured stub report from scanned `func test_*` scripts. Reports persist under
`user://terravolt/test_reports/`.

Error band: `-33990` … `-33992`.
