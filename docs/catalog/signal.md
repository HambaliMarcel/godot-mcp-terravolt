# `signal.*` catalog (v0.5.0)

Phase 3 work-unit #3 — signal declarations and connection graph ops.

| Method                      | Safe | Mutates | Editor | Headless | Notes                           |
| --------------------------- | ---- | ------- | ------ | -------- | ------------------------------- |
| `signal.list_declared`      | yes  | no      | yes    | yes      | Parse `signal` lines in script. |
| `signal.add_declaration`    | no   | yes     | yes    | partial  | Inserts signal into `.gd`.      |
| `signal.remove_declaration` | no   | yes     | yes    | partial  | Removes signal line.            |
| `signal.connect`            | no   | yes     | yes    | no       | Needs active scene.             |
| `signal.disconnect`         | no   | yes     | yes    | no       | Single connection drop.         |
| `signal.list_connections`   | yes  | no      | yes    | yes      | Outgoing connections.           |
| `signal.find_listeners`     | yes  | no      | yes    | yes      | Reverse lookup (scene).         |
| `signal.bulk_connect`       | no   | yes     | yes    | no       | Atomic batch + UndoRedo.        |
| `signal.bulk_disconnect`    | no   | yes     | yes    | no       | Batch disconnect.               |
| `signal.graph`              | yes  | no      | yes    | yes      | JSON / Mermaid / DOT export.    |

## Errors

| Symbol                  | Code     |
| ----------------------- | -------- |
| `signal.name_exists`    | `-33700` |
| `signal.unknown`        | `-33701` |
| `signal.target_unknown` | `-33702` |
| `signal.method_unknown` | `-33703` |

See [`docs/catalog/script.md`](script.md).
