# Catalog: `testing.*`

Phase 3/4 — 7 daemon methods (`catalog_version` **0.17.0**, +1 from task 26).

| Method                       | Safe | Mutates | Headless |
| ---------------------------- | ---- | ------- | -------- |
| `testing.list_suites`        | yes  | no      | yes      |
| `testing.run`                | no   | yes     | yes      |
| `testing.assert_state`       | yes  | no      | yes      |
| `testing.screenshot_compare` | no   | yes     | yes      |
| `testing.list_reports`       | yes  | no      | yes      |
| `testing.get_report`         | yes  | no      | yes      |
| `testing.run_scenario`       | no   | yes     | yes      |

Handlers: `packages/godot-mcp-addon/handlers/testing.gd`  
Helpers: `packages/godot-mcp-addon/handlers/testing_helpers.gd`

`testing.run` detects GUT via `res://addons/gut/` and spawns
`godot --headless -s addons/gut/gut_cmdln.gd` when `gut_cmdln.gd` exists; otherwise returns a
structured stub report from scanned `func test_*` scripts. Reports persist under
`user://terravolt/test_reports/`.

`testing.run_scenario` executes an ordered array of `{type:"input"|"wait"|"assert"|"screenshot"}`
steps and returns a per-step report `{ok, steps_total, steps_run, steps:[…]}`. Use it to drive a
single playable slice through gameplay+assertion in one round-trip without writing a custom test
harness. Mirrors the orchestration pattern from `godot-mcp-pro/test_commands.gd:run_test_scenario`
but uses Terravolt headless primitives (no editor dependency).

Error band: `-33990` … `-33992`, `-33997` (`testing.scenario_failed`).
