# Test fixtures

Per `docs/tasklist/10 §10.6.2`. Each subdirectory is a tiny Godot project the
integration harness can copy to a temp directory.

| Fixture           | Purpose                                                                 |
| ----------------- | ----------------------------------------------------------------------- |
| `empty/`          | Smallest valid project; powers headless `ping` + `script.validate_syntax`. |
| `minimal_3d/`     | _(planned)_ 3D scene + a node tree to exercise `scene.*` tools.         |
| `dialogue_demo/`  | _(planned)_ Macro showcase.                                             |
| `stress_tree_10000/` | _(planned)_ Stress tree for envelope/SLA tests.                       |

Add fixtures alongside this README; do **not** import the addon into the
fixture (the headless driver is loaded by `-script` instead).
