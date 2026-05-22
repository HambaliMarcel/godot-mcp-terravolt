# 24 — Catalog: `macro.*` (Phase 3 work-unit #14 — vibe-coding multipliers)

> The `macro.*` category turns single agent prompts into **fully-scaffolded gameplay slices**: "make
> a 2D platformer player", "add an enemy waver spawner", "drop in a dialog system". Each macro is a
> deterministic high-level recipe that composes ~5–30 lower-level tool calls from earlier
> categories, with sensible defaults the user can override. These are the **biggest win** for
> vibe-coding.

---

## 24.1 Header

- **File:** `24-catalog-macros.md`
- **Purpose:** ship `macro.*` (15 scaffolders).
- **Catalog bump:** `0.15.0` → **`0.16.0`** on land.

## 24.2 Phase placement

Phase 3, work-unit #14 — the **last category** before the release gate file (`25`). All of `11`–`23`
must be live; `macro.*` calls into them via the daemon dispatcher, never via the network.

## 24.3 Inputs / prerequisites

- New handler `handlers/macro.gd` — orchestrator that calls into other handlers via the daemon's
  internal dispatch (not via JSON-RPC).
- Router module `src/tools/macro/`.
- Per-macro template folder `addons/godot_mcp/macros/<macro_name>/` containing optional `.tscn` /
  `.tres` seed files used as the starting point. Templates user-overridable by dropping a
  `res://terravolt/macros/<macro_name>/` folder.

## 24.4 Outputs

- 15 macros live, registered, validated, documented.
- New fixtures: `tests/_fixtures/macro_zoo/` (empty project the macros build into).
- `docs/catalog/macro.md` regenerated.
- Each macro has a "dry-run preview" mode returning the underlying op plan (a `BatchPlan` analog) so
  the user knows what's about to happen before applying.

## 24.5 Operating constants used

- `macro_default_dry_run = false` (but every macro accepts `dry_run: true`).
- `macro_max_ops = 200` per macro.
- `macro_history` persisted at `user://terravolt/macro_history.json`.

---

## 24.6 `macro.*` — 15 scaffolders

> Every macro returns
> `{ ok: bool, ops_applied: int, created: [{ kind, path }], modified: [{ kind, path }], dry_run: bool, revert_token?: string, summary: string }`.
> Each one supports `confirm_high_risk: true` for ops that override existing files. Each one writes
> a journal entry for one-step revert.

### `macro.player_controller_2d`

- **Purpose:** scaffold a complete 2D platformer player.
- **Inputs:**
  `{ scene_path?: ScenePath (default active), name?: string (default "Player"), with_sprite?: bool (default true), animation_set?: "idle_run_jump"|"idle_run_jump_attack" (default first), camera?: bool (default true), input_actions?: [string] (default ["move_left","move_right","jump"]) }`.
- **Builds:** `CharacterBody2D` + `CollisionShape2D` (`CapsuleShape2D`) + `AnimatedSprite2D` +
  `Camera2D` + a `Player.gd` script with `_physics_process` movement (gravity, jump, horizontal
  accel, coyote time, jump buffer). Registers the three input actions if missing.
- **Composed of:** `scene_3d`/`scene` mutators, `node.add`, `script.write` (Player.gd template),
  `input.add_action`.
- **Cursor prompt:** _"Scaffold a 2D platformer player named Hero with idle/run/jump."_

### `macro.player_controller_3d`

- **Purpose:** scaffold a complete 3D first-person or third-person player.
- **Inputs:**
  `{ scene_path?: ScenePath, name?: string (default "Player"), perspective?: "fp"|"tp" (default "tp"), with_mesh?: bool (default true), camera_offset?: Vector3, with_jump?: bool (default true), input_actions?: [string] (default ["move_forward","move_back","move_left","move_right","jump"]) }`.
- **Builds:** `CharacterBody3D` + capsule shape + optional mesh + Camera3D (parent-arm for TP) +
  Player3D.gd with mouselook + WASD + jump + gravity.
- **Cursor prompt:** _"Scaffold a 3D third-person player."_

### `macro.enemy_with_state_machine`

- **Purpose:** create a basic enemy with idle/patrol/chase/attack/dead `AnimationTree` state
  machine, nav agent, and aggro range.
- **Inputs:**
  `{ scene_path?: ScenePath, name?: string (default "Enemy"), dimension?: "2d"|"3d", patrol_radius?: float, aggro_radius?: float, attack_range?: float, health?: int (default 30) }`.
- **Builds:** body + shape + sprite or mesh + AnimationPlayer + AnimationTree (with the 5 states +
  transitions wired) + NavigationAgent + Enemy.gd with state methods + signals (`died`, `damaged`).
- **Cursor prompt:** _"Scaffold a 2D enemy with patrol/chase/attack."_

### `macro.enemy_wave_spawner`

- **Purpose:** drop in a wave-based spawner with progression and a UI counter.
- **Inputs:**
  `{ scene_path?: ScenePath, enemy_scene_path: ScenePath, spawn_points?: [NodePath], wave_count?: int (default 5), base_enemies?: int (default 3), scale_per_wave?: float (default 1.5), between_wave_pause_s?: float (default 4) }`.
- **Builds:** WaveSpawner.gd (Node) + UI label updates + signals (`wave_started`, `wave_finished`,
  `all_waves_finished`).
- **Cursor prompt:** _"Add a wave spawner using the Goblin scene with 5 waves."_

### `macro.dialog_system`

- **Purpose:** scaffold a typewriter dialog UI + dialog runner that loads `.tres` line files.
- **Inputs:**
  `{ scene_path?: ScenePath, theme_path?: ResourcePath, with_portrait?: bool (default true), with_choices?: bool (default true), typewriter_chars_per_s?: int (default 40) }`.
- **Builds:** `DialogUI.tscn` (CanvasLayer + Panel + RichTextLabel + Portrait TextureRect + Choices
  VBox) + `DialogRunner.gd` autoload + a starter `res://dialogs/intro.tres` example.
- **Cursor prompt:** _"Add a dialog system with portraits."_

### `macro.inventory_system`

- **Purpose:** scaffold an inventory data layer + UI grid.
- **Inputs:**
  `{ scene_path?: ScenePath, slot_count?: int (default 16), stackable?: bool (default true), with_drag_drop?: bool (default true), theme_path?: ResourcePath }`.
- **Builds:** `Item.tres` resource template, `Inventory.gd` autoload (data store),
  `InventoryUI.tscn` (GridContainer of slots, drag&drop hooks).
- **Cursor prompt:** _"Add an inventory with 20 slots and drag&drop."_

### `macro.save_load_system`

- **Purpose:** add a simple JSON save/load system with named slots.
- **Inputs:**
  `{ scope?: "user_dir"|"project", slot_count?: int (default 3), include_screenshot?: bool (default true) }`.
- **Builds:** `SaveManager.gd` autoload (writes `user://saves/slot_<n>.json`), a save indicator UI,
  and an example "save game" hook called from input action `save_quick`.
- **Cursor prompt:** _"Add a save/load system with 3 slots and screenshot thumbnails."_

### `macro.settings_menu`

- **Purpose:** scaffold a full settings menu (audio, video, controls).
- **Inputs:**
  `{ theme_path?: ResourcePath, output_path?: ScenePath (default "res://ui/Settings.tscn"), categories?: ["audio","video","controls"] (default all), bind_to_main_menu?: NodePath }`.
- **Builds:** SettingsMenu.tscn + Settings.gd that reads/writes `user://settings.cfg` + audio bus
  volume sliders bound to `AudioServer` + video options (vsync, msaa, fullscreen) + control rebind
  UI driven by `InputMap`.
- **Cursor prompt:** _"Create a settings menu wired to a 'Settings' button on /root/MainMenu."_

### `macro.main_menu`

- **Purpose:** scaffold a main menu screen with start / continue / settings / quit.
- **Inputs:**
  `{ theme_path?: ResourcePath, output_path?: ScenePath (default "res://ui/MainMenu.tscn"), with_continue?: bool (default true), with_credits?: bool (default false), start_scene_path?: ScenePath }`.
- **Builds:** MainMenu.tscn + MainMenu.gd with handlers (start, continue → load latest save,
  settings → push, quit). Updates `application/run/main_scene` (with `confirm_high_risk`).
- **Cursor prompt:** _"Scaffold a main menu and make it the project's main scene."_

### `macro.pause_overlay`

- **Purpose:** add a pause overlay (Esc to toggle).
- **Inputs:**
  `{ scene_path?: ScenePath, theme_path?: ResourcePath, options?: ["resume","settings","main_menu","quit"] }`.
- **Builds:** PauseOverlay.tscn + PauseOverlay.gd; toggles `get_tree().paused` while ignoring its
  own `process_mode`.
- **Cursor prompt:** _"Add an Esc pause overlay with resume/settings/main_menu/quit."_

### `macro.hud_health_score`

- **Purpose:** scaffold a HUD with health bar + score label.
- **Inputs:** `{ scene_path?: ScenePath, player_path?: NodePath, theme_path?: ResourcePath }`.
- **Builds:** HUD.tscn (CanvasLayer + ProgressBar + Label); HUD.gd subscribes to
  `player.health_changed` and `Score.changed` signals.
- **Cursor prompt:** _"Add a HUD bound to /Player.health_changed."_

### `macro.day_night_cycle`

- **Purpose:** scaffold a day/night cycle controller affecting `DirectionalLight3D` +
  `WorldEnvironment.sky`.
- **Inputs:**
  `{ scene_path?: ScenePath, duration_s?: float (default 600), start_hour?: float (default 8.0), with_fog?: bool (default true) }`.
- **Builds:** DayNightController.gd + WorldEnvironment + DirectionalLight3D (sun) + signals
  (`hour_changed`).
- **Cursor prompt:** _"Add a 10-minute day/night cycle starting at noon."_

### `macro.basic_2d_level`

- **Purpose:** scaffold a 2D level template (parallax bg + TileMap floor + player spawn point +
  level bounds).
- **Inputs:**
  `{ output_path: ScenePath, with_parallax?: bool (default true), tileset_path?: ResourcePath, level_width_tiles?: int (default 60), level_height_tiles?: int (default 20) }`.
- **Builds:** Level.tscn with `ParallaxBackground` + `TileMapLayer` (with a floor) +
  `Spawnpoint.tscn` instance.
- **Cursor prompt:** _"Create a basic 2D level at res://levels/Level1.tscn."_

### `macro.basic_3d_level`

- **Purpose:** scaffold a 3D level template (ground plane + GridMap walls + skybox env + spawn
  point).
- **Inputs:**
  `{ output_path: ScenePath, mesh_library_path?: ResourcePath, with_sky?: bool (default true), size_meters?: float (default 64) }`.
- **Builds:** Level3D.tscn with `StaticBody3D` ground + `WorldEnvironment` + GridMap +
  `Spawnpoint.tscn`.
- **Cursor prompt:** _"Create a basic 3D level at res://levels/Level1_3D.tscn."_

### `macro.localization_setup`

- **Purpose:** bootstrap localization (CSV-driven translations).
- **Inputs:**
  `{ locales?: [string] (default ["en","id","ja"]), table_path?: ResourcePath (default "res://localization/strings.csv"), wire_into_ui_root?: NodePath }`.
- **Builds:** `strings.csv` with placeholder rows, `LocaleManager.gd` autoload, `tr()` rewrite of
  static labels on the wired UI subtree (best-effort), `OptionButton` in Settings to switch locale.
- **Cursor prompt:** _"Set up localization for en/id/ja with a CSV table."_

---

## 24.7 Schemes / data shapes added

- `MacroResult` shape: per outputs description above.
- `MacroOpPlan` (returned from `dry_run`): `{ ops: [{ kind, args, why }] }`.
- `MacroHistoryEntry`: `{ id, macro, params, applied_at, ops_applied, revert_token }`.

## 24.8 Tech stack delta

- New addon folder `addons/godot_mcp/macros/` containing GDScript orchestrators + template
  scenes/resources.
- User-overridable mirror at `res://terravolt/macros/<name>/`.

## 24.9 Acceptance criteria

- [ ] All 15 macros live; visible via `tools.list({category: "macro"})`.
- [ ] Every macro has a `dry_run` mode that returns an op plan without applying.
- [ ] Every macro returns a `revert_token` that, when passed to
      `batch_refactor.apply { plan: { ops: [{ kind: "revert", token }] } }`, restores the project
      byte-identical (modulo whitespace).
- [ ] Macros respect existing files (no silent overwrite without `confirm_high_risk: true`).
- [ ] `macro.player_controller_2d` produces a scene where `runtime.play` →
      `runtime.send_input { right, 500ms }` moves the player visibly.

## 24.10 Verification plan

1. **Dry run:** `macro.dialog_system { dry_run: true }` returns ~12–18 ops with no file changes.
2. **Apply + revert:** `macro.inventory_system` then revert via journal returns project to identical
   SHA tree.
3. **Smoke:** each macro applied to an empty fixture; the resulting scene loads without errors
   (verified with `scene.validate`).
4. **End-to-end:** `macro.player_controller_2d` + `macro.basic_2d_level` +
   `macro.hud_health_score` + `runtime.play` → game runs, player moves, HUD updates from a forced
   signal emission.
5. **Localization:** switch locale via the generated OptionButton; UI labels swap text.

## 24.11 Risks & mitigations

| Risk                                              | Mitigation                                                                                                        |
| ------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Generated code drift from Godot version changes.  | Templates pinned per supported Godot minor; macro selects the right template via `Engine.get_version_info()`.     |
| User wants different naming/style.                | Every template is overridable via `res://terravolt/macros/<name>/`; macro searches user mirror first.             |
| Macros silently overwrite carefully tuned files.  | All file writes go through `script.write { mode: "create_only" }` (or `overwrite` only with `confirm_high_risk`). |
| Revert token corruption mid-macro.                | Two-phase commit per file (reuse `15`'s machinery).                                                               |
| Macros tempt the agent to skip lower-level tools. | Document explicitly: macros are _recipes_, not magic; their op plan is always inspectable via `dry_run`.          |

## 24.12 Handoff checklist to file `25`

- [ ] Catalog version `0.16.0` pushed.
- [ ] **209 tools** total live (well above the 200+ objective).
- [ ] All macros pass smoke-test scaffolding.
- [ ] Open `25-catalog-completion-gate.md`.

## 24.13 Commit template

```text
feat(catalog): ship macro.* (15 vibe-coding scaffolders) — Phase 3 work-unit #14

- 2D and 3D player controllers
- Enemy + state machine, wave spawner
- UI scaffolders (main menu, settings, pause, HUD, dialog, inventory)
- World scaffolders (basic 2D level, basic 3D level, day/night cycle)
- System scaffolders (save/load, localization)
- All macros support dry_run + revert tokens; templates user-overridable
- Crosses the 200+ tool threshold (209 tools live)
- Bumps catalog_version 0.15.0 -> 0.16.0

Refs: docs/tasklist/24-catalog-macros.md
```
