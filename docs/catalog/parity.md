# Editor vs headless parity (living matrix)

Tracks which JSON-RPC daemon methods intentionally match between the `:6505` editor WebSocket and
the §07 headless TCP driver.

For full per-tool details (inputs, results, errors), see
**[`docs/guides/tools-reference.md`](../guides/tools-reference.md)**. For the connection flow, see
**[`docs/guides/godot-integration.md`](../guides/godot-integration.md)**.

## Legend

| Path         | Meaning                                                                                                                                 |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| Editor       | Daemon WebSocket reachable on `TERRAVOLT_GODOT_HOST` / `TERRAVOLT_GODOT_PORT`.                                                          |
| Headless TCP | Routed when `registry.json` sets `headlessFallback: true` and WS is disconnected. The MCP envelope reports `method: "<name>@headless"`. |

## Shipped parity (today)

| `method`      | Editor | Headless TCP | Notes                                                                                                                                                      |
| ------------- | ------ | ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ping`        | yes    | yes          | Timestamp source differs (`daemonResult` retains the raw payload). Verified by `tests/integration/mcp_e2e.test.mjs` (forces WS down via `--godot-port 1`). |
| `server.info` | yes    | yes          | Headless emits `build_mode: "headless_tcp"` and `supported_methods_count` for the driver allowlist.                                                        |

### Scene & project (catalog 0.3.0)

| `method`                                                                                                        | Editor | Headless TCP | Notes                                                                             |
| --------------------------------------------------------------------------------------------------------------- | ------ | ------------ | --------------------------------------------------------------------------------- |
| `scene.list`                                                                                                    | yes    | yes          | Walk `res://` for `.tscn` / `.scn`.                                               |
| `scene.get`                                                                                                     | yes    | yes          | Metadata without instantiate.                                                     |
| `scene.create`                                                                                                  | yes    | yes          | New scene file with typed root.                                                   |
| `scene.delete`                                                                                                  | yes    | yes          | File delete (dependency guard in editor).                                         |
| `scene.validate`                                                                                                | yes    | yes          | Returns issues in payload.                                                        |
| `project.info`                                                                                                  | yes    | yes          | Project metadata.                                                                 |
| `project.get_settings`                                                                                          | yes    | yes          | Group / key filter.                                                               |
| `project.set_settings`                                                                                          | yes    | yes          | Patch + optional `dry_run`.                                                       |
| `project.list_autoloads`                                                                                        | yes    | partial      | Headless returns empty list v1.                                                   |
| `project.set_main_scene`                                                                                        | yes    | yes          | Validates path when `validate=true`.                                              |
| `scene.open`, `scene.close`, `scene.save`, `scene.save_as`                                                      | yes    | no           | `editor.not_available` (`-33400`).                                                |
| `scene.get_tree`, `scene.get_subtree`, `scene.find_in_tree`, `scene.instantiate`, `scene.pack`, `scene.replace` | yes    | partial      | Need active scene; headless v1 returns `editor.no_active_scene` where applicable. |

### Node (catalog 0.4.0)

| `method`                                                                                 | Editor | Headless TCP | Notes                                            |
| ---------------------------------------------------------------------------------------- | ------ | ------------ | ------------------------------------------------ |
| `node.get`, `node.add`, `node.delete`, `node.modify`, `node.is_a`, `node.find_path`      | yes    | yes          | Active/main scene tree in headless driver.       |
| `node.list_groups`, `node.list_signals`, `node.evaluate_expression`                      | yes    | yes          | Expression denylist enforced.                    |
| `node.duplicate`, `node.move`, `node.rename`, `node.attach_script`, `node.detach_script` | yes    | partial      | Headless v1 deferred (`editor.no_active_scene`). |

### Script & signal (catalog 0.5.0)

| `method`                                                                                                               | Editor | Headless TCP | Notes                                   |
| ---------------------------------------------------------------------------------------------------------------------- | ------ | ------------ | --------------------------------------- |
| `script.list`, `script.read`, `script.write`, `script.patch`, `script.validate`, `script.find_usages`, `script.format` | yes    | yes          | `.gd` validate via `GDScript.reload()`. |
| `script.rename_symbol`                                                                                                 | yes    | no           | Editor-first v1.                        |
| `signal.list_declared`, `signal.list_connections`, `signal.find_listeners`, `signal.graph`                             | yes    | yes          | Graph exports JSON/Mermaid/DOT.         |
| `signal.connect`, `signal.disconnect`, `signal.bulk_connect`, `signal.bulk_disconnect`                                 | yes    | no           | Require active scene + UndoRedo.        |
| `signal.add_declaration`, `signal.remove_declaration`                                                                  | yes    | partial      | Headless stub for script file ops.      |

### Resource & shader (catalog 0.6.0)

| `method`                                                                                                                                                       | Editor | Headless TCP | Notes                                       |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------ | ------------------------------------------- |
| `resource.list`, `resource.get`, `resource.create`, `resource.update`, `resource.duplicate`, `resource.delete`, `resource.export_json`, `resource.import_json` | yes    | yes          | JSON export is deterministic (sorted keys). |
| `resource.get_dependencies`, `resource.get_dependents`, `resource.validate`, `resource.diff`                                                                   | yes    | yes          | Dependency walk via `ResourceLoader`.       |
| `resource.rename`, `resource.replace_references`, `resource.set_uid`                                                                                           | yes    | no           | Editor-first v1 (reference rewrites).       |
| `shader.list`, `shader.read`, `shader.write`, `shader.compile_check`, `shader.list_params`, `shader.set_material_params`                                       | yes    | yes          | Probe-uniform compile check heuristic.      |

### Asset & batch_refactor (catalog 0.7.0)

| `method`                                                                                                                                                                   | Editor | Headless TCP | Notes                                                |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------ | ---------------------------------------------------- |
| `asset.list`, `asset.import_status`, `asset.get_import_settings`, `asset.set_import_settings`, `asset.add`, `asset.delete`, `asset.rename`                                 | yes    | yes          | `.import` sidecar parse/write; reference rewrite.    |
| `asset.metadata`, `asset.find_unused`                                                                                                                                      | yes    | yes          | Text-reference scan includes `load`/`preload`.       |
| `asset.reimport`, `asset.batch_import_presets`                                                                                                                             | yes    | partial      | Headless notes editor/`godot --import` for reimport. |
| `asset.preview`                                                                                                                                                            | yes    | no           | `editor.not_available`.                              |
| `batch_refactor.preview`, `batch_refactor.apply`, `batch_refactor.rename_class`, `batch_refactor.move_folder`, `batch_refactor.replace_in_files`, `batch_refactor.history` | yes    | yes          | Confirm token from preview hash.                     |
| `batch_refactor.normalize_names`, `batch_refactor.change_class`                                                                                                            | yes    | partial      | Headless v1 stubs for complex scene rewrites.        |

### Editor & analysis (catalog 0.8.0)

| `method`                                                                                                                                                                | Editor | Headless TCP | Notes                                              |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------ | -------------------------------------------------- |
| `editor.screenshot`, `editor.focus_node`, `editor.open_script`, `editor.run_undo`, `editor.run_redo`, `editor.execute_script`, `editor.reload_scripts`, `editor.layout` | yes    | no           | `editor.not_available` in headless driver.         |
| `editor.error_log_tail`                                                                                                                                                 | yes    | partial      | Headless returns daemon buffer only.               |
| `analysis.scene_complexity`, `analysis.signal_flow`, `analysis.unused_resources`, `analysis.metrics`                                                                    | yes    | yes          | Shared `analysis_helpers.gd` in editor + headless. |

### Runtime (catalog 0.9.0)

| `method`                                                                                                                                    | Editor | Headless TCP | Notes                                                                                  |
| ------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------ | -------------------------------------------------------------------------------------- |
| `runtime.play`, `runtime.stop`, `runtime.status`                                                                                            | yes    | partial      | Headless uses `runtime.start_headless` subprocess + TCP bridge (port 6506).            |
| `runtime.start_headless`                                                                                                                    | no     | yes          | Spawns game process; resolves Godot exe (skips `.cmd`/`.bat` shims).                   |
| `runtime.list_nodes`, `runtime.inspect_node`, `runtime.evaluate`, `runtime.set_property`, `runtime.call_method`, `runtime.emit_signal`      | yes    | partial      | Proxied to game-process bridge when session alive.                                     |
| `runtime.send_input`, `runtime.simulate_sequence`, `runtime.click_ui`, `runtime.navigate`, `runtime.record_inputs`, `runtime.replay_inputs` | yes    | partial      | Bridge autoload in game project; CI covers core round-trip via `minimal_game` fixture. |
| `runtime.log_tail`, `runtime.screenshot`, `runtime.set_engine_param`                                                                        | yes    | partial      | Bridge helpers; screenshot needs render context in headless game.                      |

### Animation + animation_tree (catalog 0.10.0)

| `method`                                                                                                                                                                                                                           | Editor | Headless TCP | Notes                                   |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------ | --------------------------------------- |
| `animation.list`, `animation.create`, `animation.add_track`, `animation.set_key`, `animation.play`, `animation.stop`                                                                                                               | yes    | yes          | `AnimationPlayer` on loaded main scene. |
| `animation_tree.describe`, `animation_tree.set_parameter`, `animation_tree.get_parameter`, `animation_tree.blend_audit`, `animation_tree.play`, `animation_tree.stop`, `animation_tree.add_state`, `animation_tree.add_transition` | yes    | yes          | Headless uses fixture zoo scenes.       |

### Physics, particle, navigation (catalog 0.11.0)

| `method`                                                                                                                                   | Editor | Headless TCP | Notes                                                            |
| ------------------------------------------------------------------------------------------------------------------------------------------ | ------ | ------------ | ---------------------------------------------------------------- |
| `physics.add_body`, `physics.set_layers`, `physics.list_layers`, `physics.set_layer_name`, `physics.raycast`, `physics.set_gravity`        | yes    | yes          | Main-scene bootstrap + physics step advance in headless.         |
| `particle.add_system`, `particle.set_material`, `particle.preview`, `particle.set_emission`, `particle.list_presets`                       | yes    | yes          | GPU→CPU fallback when RD unavailable; no `Node.has()` (Godot 4). |
| `navigation.add_region`, `navigation.bake`, `navigation.add_agent`, `navigation.set_layers`, `navigation.path`, `navigation.debug_overlay` | yes    | yes          | Region bake + path query in headless fixtures.                   |

### Tilemap + theme_ui (catalog 0.12.0)

| `method`                                                                                                                                | Editor | Headless TCP | Notes                                                                                  |
| --------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------ | -------------------------------------------------------------------------------------- |
| `tilemap.describe`, `tilemap.set_cells`, `tilemap.fill`, `tilemap.query_cells`, `tilemap.tileset_info`, `tilemap.terrain_paint`         | yes    | yes          | `TileMapLayer`-first; legacy `TileMap` fallback where needed.                          |
| `theme_ui.describe`, `theme_ui.set_color`, `theme_ui.set_font`, `theme_ui.set_stylebox`, `theme_ui.preview`, `theme_ui.scaffold_screen` | yes    | yes          | Scaffold assigns `owner` before pack; control override describe reads theme overrides. |

### Audio + input (catalog 0.13.0)

| `method`                                                                                          | Editor | Headless TCP | Notes                                      |
| ------------------------------------------------------------------------------------------------- | ------ | ------------ | ------------------------------------------ |
| `audio.list_buses`, `audio.add_bus`, `audio.remove_bus`, `audio.set_bus`, `audio.add_effect`      | yes    | yes          | Bus layout via `default_bus_layout.tres`.  |
| `audio.preview_play`                                                                              | yes    | partial      | No audio output in headless CI.            |
| `input.list_actions`, `input.add_action`, `input.remove_action`, `input.set_action_events`        | yes    | yes          | InputMap CRUD.                             |
| `input.rename_action`, `input.simulate_action`, `input.describe_event`                            | yes    | yes          | Event serialization + simulate in driver.  |

### Scene 3D (catalog 0.14.0)

| `method`                                                                                          | Editor | Headless TCP | Notes                                      |
| ------------------------------------------------------------------------------------------------- | ------ | ------------ | ------------------------------------------ |
| `scene_3d.add_mesh_instance`, `scene_3d.add_camera`, `scene_3d.add_light`, `scene_3d.set_environment`, `scene_3d.add_gridmap`, `scene_3d.frame_subject` | yes | yes | 3D zoo fixture scenes. |

### Testing, profile, export (catalog 0.15.0)

| `method`                                                                                          | Editor | Headless TCP | Notes                                      |
| ------------------------------------------------------------------------------------------------- | ------ | ------------ | ------------------------------------------ |
| `testing.list_suites`, `testing.run`, `testing.assert_state`, `testing.list_reports`, `testing.get_report`, `testing.screenshot_compare` | yes | yes | Fixture zoo suites. |
| `profile.monitor`, `profile.flamegraph`                                                           | yes    | partial      | Flamegraph deferred in headless CI.        |
| `export.list_presets`, `export.build`, `export.template_info`                                     | yes    | yes          | Preset list + template info; build smoke.  |

### Macro scaffolders (catalog 0.16.0)

| `method`                                                                                          | Editor | Headless TCP | Notes                                      |
| ------------------------------------------------------------------------------------------------- | ------ | ------------ | ------------------------------------------ |
| All 15 `macro.*` scaffolders                                                                      | yes    | yes          | 3 full apply; 12 dry-run/stub templates.   |

## Headless-only methods (no editor counterpart)

| `method`                 | Surface                             | Notes                                                                     |
| ------------------------ | ----------------------------------- | ------------------------------------------------------------------------- |
| `script.validate_syntax` | `headless.validate_script` MCP tool | GDScript compile check via `GDScript.new().reload()` inside the driver.   |
| `server.list_methods`    | driver only                         | Returns the driver's allowlist (includes scene/project headless methods). |
| `dispatch.cancel`        | driver only                         | Cooperative cancellation hook (no-op today).                              |

## Editor-only methods (no headless counterpart)

| `method`                                                  | Notes                                         |
| --------------------------------------------------------- | --------------------------------------------- |
| `log.tail`                                                | Editor-mode daemon owns `user://mcp_log.txt`. |
| All other daemon methods without `headlessFallback: true` | Defaults to editor-only.                      |

## Backlog parity (planned)

Anything else in `packages/shared/methods/registry.json` **without** `headlessFallback: true` is
**editor-first** unless a dedicated MCP headless router tool exposes it locally. Expansion is
tracked under `docs/tasklist/07-headless-fallback.md` and Linear `TER-40` (TV-07).

Likely future parity (subject to §08 catalog landings): `scene.get_open_path`,
`script.validate_syntax` for `.cs`, `runtime.export_release`, `runtime.import_assets`,
`runtime.run_tests`.

## Validation checklist

Structured repo validation for tasks **TV-00 … TV-25**: **[`docs/validation/tv-00-25-checkpoint.md`](../validation/tv-00-25-checkpoint.md)** (supersedes TV-00–20 for catalog gate).
