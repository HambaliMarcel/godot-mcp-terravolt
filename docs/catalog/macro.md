# Catalog: `macro.*`

Phase 3 work-unit #14 — 15 vibe-coding scaffolders (`catalog_version` **0.16.0**).

| Method                           | Status   | Headless |
| -------------------------------- | -------- | -------- |
| `macro.player_controller_2d`     | **live** | yes      |
| `macro.player_controller_3d`     | stub     | yes      |
| `macro.enemy_with_state_machine` | stub     | yes      |
| `macro.enemy_wave_spawner`       | stub     | yes      |
| `macro.dialog_system`            | **live** | yes      |
| `macro.inventory_system`         | stub     | yes      |
| `macro.save_load_system`         | stub     | yes      |
| `macro.settings_menu`            | stub     | yes      |
| `macro.main_menu`                | stub     | yes      |
| `macro.pause_overlay`            | stub     | yes      |
| `macro.hud_health_score`         | **live** | yes      |
| `macro.day_night_cycle`          | stub     | yes      |
| `macro.basic_2d_level`           | stub     | yes      |
| `macro.basic_3d_level`           | stub     | yes      |
| `macro.localization_setup`       | stub     | yes      |

Handlers: `packages/godot-mcp-addon/handlers/macro.gd`  
Helpers: `packages/godot-mcp-addon/handlers/macro_helpers.gd`  
Templates: `packages/godot-mcp-addon/macros/<name>/` (overridable at
`res://terravolt/macros/<name>/`)

Every macro accepts `dry_run: true` (returns `plan.ops`) and `confirm_high_risk: true` for
overwrites. Successful applies return
`{ ok, ops_applied, created, modified, dry_run, revert_token?, summary }`.

Journal: `user://terravolt/macro_history.json` · revert snapshots:
`user://terravolt/macro_reverts/`.

Error band: `-34000` … `-34006` (`macro.not_implemented`, `macro.ops_limit`, `macro.scene_required`,
`macro.file_exists`, `macro.template_missing`, `macro.high_risk`, `macro.apply_failed`).

Constants: `macro_max_ops = 200`, default `dry_run = false`.
