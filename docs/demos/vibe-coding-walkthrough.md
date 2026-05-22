# Vibe-coding walkthrough — 2D platformer slice

Scripted demo for task 25: build a playable 2D platformer slice from an empty Godot project using
TerraVolt MCP prompts only (macros + a handful of mutators).

**Prerequisites:** Godot 4.6+, TerraVolt MCP wired in Cursor (`tools.health` → `pass: true`).

---

## Act 1 — Health and discovery (2 min)

| Step | Prompt                                              | Expected MCP call                                         | Outcome                                        |
| ---- | --------------------------------------------------- | --------------------------------------------------------- | ---------------------------------------------- |
| 1    | _"Run a health check on the Godot MCP."_            | `tools.health`                                            | `pass: true`, catalog `0.16.0`                 |
| 2    | _"List every daemon method in the macro category."_ | `context.fetch_raw` → `tools.list` filter or `tools.list` | 15 `macro.*` tools                             |
| 3    | _"Describe macro.basic_2d_level."_                  | `tools.describe` or registry lookup                       | Input schema with `project_path`, `level_name` |

---

## Act 2 — Scaffold the world (3 min)

| Step | Prompt                                                  | Expected call                                                  | Outcome                                    |
| ---- | ------------------------------------------------------- | -------------------------------------------------------------- | ------------------------------------------ |
| 4    | _"Create a new Godot project at ~/Games/CaveDive."_     | `project.info` / filesystem + `addon:link` guidance            | Empty 4.x project with addon               |
| 5    | _"Run macro.basic_2d_level dry_run first, then apply."_ | `macro.basic_2d_level` `{dry_run:true}` then `{dry_run:false}` | `levels/main_level.tscn` with TileMapLayer |
| 6    | _"Scaffold a 2D player controller."_                    | `macro.player_controller_2d`                                   | `actors/player.tscn` + movement script     |
| 7    | _"Add an enemy wave spawner macro."_                    | `macro.enemy_wave_spawner`                                     | Spawner scene under `actors/`              |

---

## Act 3 — UI and project wiring (2 min)

| Step | Prompt                                              | Expected call                                 | Outcome                              |
| ---- | --------------------------------------------------- | --------------------------------------------- | ------------------------------------ |
| 8    | _"Scaffold HUD with health and score."_             | `macro.hud_health_score`                      | `ui/hud.tscn`                        |
| 9    | _"Scaffold a main menu and wire it as main scene."_ | `macro.main_menu` + `project.set_main_scene`  | Menu scene + `project.godot` updated |
| 10   | _"Add input actions for jump and move_left/right."_ | `input.add_action`, `input.set_action_events` | InputMap entries                     |

---

## Act 4 — Validate headless (3 min)

| Step | Prompt                                                    | Expected call                                   | Outcome                        |
| ---- | --------------------------------------------------------- | ----------------------------------------------- | ------------------------------ |
| 11   | _"Compile-check every .gd file we created."_              | `headless.validate_script` loop                 | All `ok: true`                 |
| 12   | _"Start a headless game session and list runtime nodes."_ | `runtime.start_headless` + `runtime.list_nodes` | Bridge alive, nodes enumerated |
| 13   | _"Run testing.list_suites and report status."_            | `testing.list_suites`                           | Suite registry (fixture zoo)   |
| 14   | _"Stop the headless session."_                            | `headless.stop` / `runtime.stop`                | Process cleaned up             |

---

## Act 5 — Play in editor

| Step | Prompt                         | Expected outcome                            |
| ---- | ------------------------------ | ------------------------------------------- |
| 15   | _"Open Godot and press Play."_ | Character moves, HUD visible, enemies spawn |

---

## Reference alignment

This walkthrough exercises patterns from all four reference repos:

| Reference         | Pattern used                                             |
| ----------------- | -------------------------------------------------------- |
| **tomyud1**       | WS daemon + MCP stdio router; scene/project mutators     |
| **Coding-Solo**   | `runtime.start_headless` subprocess + bridge             |
| **godot-mcp-pro** | Rich catalog (218 tools), macro scaffolders, input/audio |
| **godot-docs**    | TileMapLayer, InputMap, autoload wiring                  |

---

## Known limitations in this demo

- Several macros (dialog, inventory, save/load, etc.) return **dry-run plans** until full apply
  templates land (see Linear TER-61).
- `runtime.play` editor path is not exercised in CI — use headless bridge for automation.
- Recorded video/GIF artifact is backlog (TER-42).

See also: [`docs/guides/use-cases.md`](../guides/use-cases.md),
[`docs/validation/tv-00-25-checkpoint.md`](../validation/tv-00-25-checkpoint.md).
