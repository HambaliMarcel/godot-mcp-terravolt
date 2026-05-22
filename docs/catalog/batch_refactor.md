# Catalog: `batch_refactor.*`

Phase 3 work-unit #5 — 8 daemon methods (`catalog_version` **0.7.0**).

| Method                            | Safe | Mutates | Headless |
| --------------------------------- | ---- | ------- | -------- |
| `batch_refactor.preview`          | yes  | no      | yes      |
| `batch_refactor.apply`            | no   | yes     | yes      |
| `batch_refactor.rename_class`     | no   | yes     | yes      |
| `batch_refactor.move_folder`      | no   | yes     | yes      |
| `batch_refactor.replace_in_files` | no   | yes     | yes      |
| `batch_refactor.normalize_names`  | no   | yes     | partial  |
| `batch_refactor.change_class`     | no   | yes     | partial  |
| `batch_refactor.history`          | yes  | no      | yes      |

Handler: `packages/godot-mcp-addon/handlers/batch_refactor.gd`  
Journal: `packages/godot-mcp-addon/services/batch_journal.gd`  
Schema: `packages/shared/schemas/batch/BatchPlan.json`

Error band: `-33910` … `-33913`.
