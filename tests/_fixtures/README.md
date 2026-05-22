# Test fixtures

Per `docs/tasklist/10 §10.6.2`. Each subdirectory is a tiny Godot project the
integration harness can copy to a temp directory.

| Fixture           | Purpose                                                                 |
| ----------------- | ----------------------------------------------------------------------- |
| `empty/`          | Smallest valid project; powers headless `ping` + `script.validate_syntax`. |
| `with-addon/`     | Project the addon-parse smoke stages into; verifies `class_name`s under real Godot. |
| `minimal_3d/`     | _(planned)_ 3D scene + a node tree to exercise `scene.*` tools.         |
| `dialogue_demo/`  | _(planned)_ Macro showcase.                                             |
| `stress_tree_10000/` | _(planned)_ Stress tree for envelope/SLA tests.                       |

Add fixtures alongside this README; for the headless driver you do **not**
need to import the addon (it loads via `--script`). The `with-addon/`
fixture is the exception: the parse-check test stages the addon as
`addons/terravolt_mcp/` at runtime (and `.gitignore`d) so that `class_name`
siblings resolve.
