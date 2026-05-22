# 11 — Catalog: `scene.*` + `project.*` (Phase 3 work-unit #1)

> **Implementer note.** Files `00`–`10` describe contracts, plumbing, and the _full_ aspirational
> catalog. Files `11`–`25` are **executable work-units**: each one tells the agent "go ship this
> category now." Implement them **in order** unless explicitly overridden. After each file: write
> tests, update the shared registry, regenerate docs, commit, push, move to the next file.

---

## 11.1 Header

- **File:** `11-catalog-scene-and-project.md`
- **Purpose:** ship the **scene.\*** (9 tools) and **project.\*** (7 tools) categories — the
  foundational read/write surface for everything else.
- **Tool count this file:** 16.

## 11.2 Phase placement

- **Phase 3, work-unit #1.** Begins the iterative catalog shipping.
- Prerequisite: files `02`–`07` complete; the daemon round-trips JSON-RPC; the router registers
  tools from the shared registry; `tools.health` is green.
- Gates: subsequent files (`12`–`25`) will assume `scene.*` and `project.*` are live and stable.

## 11.3 Inputs / prerequisites

- Catalog version is currently the one shipped by `06` (e.g., `0.2.0`). Bump to **`0.3.0`** when
  this file lands (minor — new tools, no breaking changes).
- Shared registry path: `packages/shared/methods/registry.json`.
- Shared schemas path: `packages/shared/schemas/common/`.
- Daemon handlers path: `packages/godot-mcp-addon/handlers/scene.gd` (new) and `handlers/project.gd`
  (new). These must be `@tool` GDScript files, statically typed, that register their methods with
  the central `Dispatcher`.
- Router tool modules: auto-generated from registry; hand-overrides only where necessary in
  `packages/mcp-server/src/tools/scene/` and `tools/project/`.

## 11.4 Outputs

When this file is done:

1. 16 new tools live, each with an `inputSchema`, `outputSchema`, error code list, and at least one
   example in the registry.
2. Per-tool integration test in `packages/mcp-server/tests/integration/scene/` and
   `tests/integration/project/`.
3. `docs/catalog/scene.md` and `docs/catalog/project.md` regenerated.
4. `CHANGELOG.md` updated under `## [Unreleased] — Phase 3 catalog`.
5. Catalog version bumped; `tools.health` reports `protocol.catalog_mismatch` until both daemon and
   router are restarted (expected).
6. `tools.list({category: "scene"})` and `tools.list({category: "project"})` return the new tools.

## 11.5 Operating constants used

All from `00 §0.3`. New project settings under `terravolt_mcp/catalog/scene/*` may be introduced if
needed (e.g., `tree_depth_default`); document each.

---

## 11.6 `scene.*` — 9 tools

> All `scene.*` mutators wrap their actions in the editor's `UndoRedo`
> (`EditorPlugin.get_undo_redo()`) so the user can Ctrl-Z. Headless variants skip the undo step.

### `scene.list`

- **Purpose:** enumerate every `.tscn` / `.scn` file under `res://`.
- **Inputs:**
  `{ pattern?: string (glob, default "**/*.tscn,**/*.scn"), include_imported?: bool (default false) }`.
- **Outputs:**
  `{ scenes: [ { path: ScenePath, uid?: string, size_bytes: int, modified_at: iso-ts } ], total: int }`.
  Sorted alphabetically by path. Subject to summary envelope when > `page_size_default`.
- **Godot APIs:** `EditorFileSystem.get_filesystem()` walk; `ResourceUID.text_to_id(...)` to surface
  UIDs.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** true. **mutates:** false.
- **Errors:** none beyond transport.
- **Cursor prompt:** _"List all scenes in the project."_

### `scene.get`

- **Purpose:** scene metadata without instantiating.
- **Inputs:** `{ path: ScenePath }`.
- **Outputs:**
  `{ path, uid?, root_type, node_count, has_script, last_modified, dependencies: [ResourcePath] }`.
- **Godot APIs:** `ResourceLoader.load(path) → PackedScene`, then
  `PackedScene.get_state() → SceneState` and read counters; `ResourceLoader.get_dependencies(path)`
  for refs.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** true. **mutates:** false.
- **Errors:** `scene.path_not_found` (`-33500`).
- **Cursor prompt:** _"Tell me about res://levels/Forest.tscn — node count and what scripts it
  uses."_

### `scene.open`

- **Purpose:** open a scene tab in the editor.
- **Inputs:** `{ path: ScenePath, focus?: bool (default true) }`.
- **Outputs:** `{ opened: bool, active_path: ScenePath, tab_index: int }`.
- **Godot APIs:** `EditorInterface.open_scene_from_path(path)`.
- **Editor:** ✅. **Headless:** ❌ → `editor.not_available` (`-33400`) with autoHeal: "open the
  editor or use `headless.run_project`".
- **safe:** true. **mutates:** false (just changes editor focus).
- **Cursor prompt:** _"Open the Forest level in the editor."_

### `scene.close`

- **Purpose:** close the currently-edited scene tab (or a named one).
- **Inputs:** `{ path?: ScenePath, save_first?: bool (default false) }`.
- **Outputs:** `{ closed: bool, remaining_tabs: [ScenePath] }`.
- **Godot APIs:** `EditorInterface.get_open_scenes()`; tab close via the scene-tabs container
  (`EditorInterface.get_editor_main_screen()` traversal); v1 best-effort, document if a particular
  minor lacks a stable public API.
- **Editor:** ✅. **Headless:** ❌.
- **safe:** false (loses unsaved changes if `save_first=false`). **mutates:** true.
- **Errors:** `editor.no_active_scene` (`-33580`).
- **Cursor prompt:** _"Close the current scene without saving."_

### `scene.save`

- **Purpose:** save the currently-edited scene.
- **Inputs:** `{ path?: ScenePath (must match active if provided) }`.
- **Outputs:**
  `{ saved: bool, path: ScenePath, bytes_written: int, state: { ...scene.get shape... }, revision: opaque }`.
- **Godot APIs:** `EditorInterface.save_scene()`; error code via `Error` enum (`OK`/`FAILED`/...).
- **Editor:** ✅. **Headless:** ❌ (use `scene.create`/`scene.replace` to mutate; then save via
  `ResourceSaver.save` directly).
- **safe:** false. **mutates:** true.
- **Errors:** `scene.save_failed` (`-33511`), `editor.no_active_scene`.
- **Cursor prompt:** _"Save the current scene."_

### `scene.save_as`

- **Purpose:** save the currently-edited scene under a new path.
- **Inputs:** `{ new_path: ScenePath, overwrite?: bool (default false) }`.
- **Outputs:** `{ saved, path, bytes_written, state, revision }`.
- **Godot APIs:** `EditorInterface.save_scene_as(path)`.
- **Editor:** ✅. **Headless:** ❌.
- **safe:** false. **mutates:** true.
- **Errors:** `scene.save_failed`.
- **Cursor prompt:** _"Save this scene as res://levels/Forest_v2.tscn."_

### `scene.create`

- **Purpose:** create a new scene file with a root node of a given type.
- **Inputs:**
  `{ path: ScenePath, root_type: string (default "Node"), root_name?: string (default basename), children?: [{ type, name, properties?: PropertyDict }] }`.
- **Outputs:** `{ created: true, path, state: { ...scene.get... }, revision }`.
- **Godot APIs:** `ClassDB.instantiate(root_type) → Node`; build tree; set `owner` for every child
  to the root; `PackedScene.new(); pack(root_node); ResourceSaver.save(packed, path)`.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** false. **mutates:** true.
- **Errors:** `scene.create_failed` (`-33510`), `node.type_unknown` (`-33520`).
- **Cursor prompt:** _"Create a new scene res://levels/Cave.tscn with a Node3D root named
  CaveRoot."_

### `scene.delete`

- **Purpose:** delete a scene file (with dependency safety).
- **Inputs:** `{ path: ScenePath, force?: bool (default false) }`.
- **Outputs:** `{ deleted: true, path, freed_bytes: int, dependents_warned: [ResourcePath] }`.
- **Godot APIs:** dependents via `resource.get_dependents` (see `14`); use
  `EditorFileSystem.move_to_trash(path)`.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** false. **mutates:** true.
- **Errors:** `resource.dependency_block` (`-33550`) when `force=false` and dependents exist.
- **Cursor prompt:** _"Delete res://levels/old_test.tscn."_

### `scene.instantiate`

- **Purpose:** instantiate a `PackedScene` as a child of a node in the open scene (editor) or in the
  headless tree.
- **Inputs:**
  `{ source_path: ScenePath, parent_path: NodePath, name?: string, properties?: PropertyDict, edit_state?: "instance"|"disabled"|"main" (default "instance") }`.
- **Outputs:** `{ instantiated: NodePath, root_type, child_count, state, revision }`.
- **Godot APIs:** `ResourceLoader.load(source_path) → PackedScene`;
  `PackedScene.instantiate(PackedScene.GEN_EDIT_STATE_*)`; `parent.add_child(node, true)`;
  `node.owner = scene_root` so the node is saved when the parent scene is saved.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** false. **mutates:** true.
- **Errors:** `scene.path_not_found`, `scene.node_path_not_found` (`-33501`).
- **Cursor prompt:** _"Drop res://entities/Enemy.tscn into the active scene under
  /root/Main/EnemiesGroup."_

### `scene.pack`

- **Purpose:** pack a subtree of the open scene into a new `.tscn`.
- **Inputs:**
  `{ root_path: NodePath, output_path: ScenePath, recursive_owner?: bool (default true) }`.
- **Outputs:** `{ packed: true, path, node_count, state, revision }`.
- **Godot APIs:** `PackedScene.new()`; if `recursive_owner`, walk subtree and set
  `owner = root_path` for nested children; `PackedScene.pack(root)`;
  `ResourceSaver.save(packed, output_path)`.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** false. **mutates:** true.
- **Errors:** `scene.create_failed`.
- **Cursor prompt:** _"Pack the /root/Main/UI/HUD subtree as res://ui/HUD.tscn."_

### `scene.get_tree`

- **Purpose:** return the active edited scene's full tree (envelope-aware).
- **Inputs:**
  `{ envelope?: "summary"|"raw" (default "summary"), max_depth?: int, max_children_per_node?: int }`.
- **Outputs:** scene tree envelope per `09 §9.7.1`.
- **Godot APIs:** `EditorInterface.get_edited_scene_root() → Node`; recursive walk; for each node
  emit `{ name, type, path, has_script, children_count, sample_children }`.
- **Editor:** ✅. **Headless:** ✅ (returns the root scene loaded headless).
- **safe:** true. **mutates:** false.
- **Errors:** `editor.no_active_scene`.
- **Cursor prompt:** _"Show me the active scene's tree, depth 3."_

### `scene.get_subtree`

- **Purpose:** return a subtree from a specific NodePath.
- **Inputs:** `{ root_path: NodePath, envelope?, max_depth?, max_children_per_node? }`.
- **Outputs:** subtree envelope.
- **Godot APIs:** same as `scene.get_tree` but starting at `scene_root.get_node(root_path)`.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** true. **mutates:** false.
- **Errors:** `scene.node_path_not_found`.
- **Cursor prompt:** _"Show me the tree below /root/Main/Player."_

### `scene.find_in_tree`

- **Purpose:** search the active scene for nodes matching a `Selector`.
- **Inputs:**
  `{ selector: Selector, limit?: int (default 50), include_props?: bool (default false) }`.
- **Outputs:** `{ matches: [{ path: NodePath, type, properties_subset? }], truncated: bool }`.
- **Godot APIs:** `Node.find_children(pattern, type, recursive=true, owned=true)`; group filter via
  `Node.is_in_group`.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** true. **mutates:** false.
- **Errors:** none.
- **Cursor prompt:** _"Find all StaticBody3D nodes in the active scene."_

### `scene.validate`

- **Purpose:** static integrity check (missing scripts, broken external refs, missing exported
  resources, orphaned unique-name marks).
- **Inputs:** `{ scope?: "active"|ScenePath (default "active"), depth?: int (default unlimited) }`.
- **Outputs:**
  `{ ok: bool, issues: [{ severity: "info"|"warn"|"error", path?, code, message, autoHeal? }] }`.
- **Godot APIs:** walk tree; `Object.get_property_list()` to find exported Resource fields;
  `ResourceLoader.exists()` for paths.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** true. **mutates:** false.
- **Errors:** none (returns issues in payload, not as errors).
- **Cursor prompt:** _"Validate res://levels/Forest.tscn and tell me what's broken."_

### `scene.replace`

- **Purpose:** replace a subtree with another scene (or with a synthesized subtree).
- **Inputs:**
  `{ at_path: NodePath, with: { source_path?: ScenePath, subtree?: { type, name, properties?, children? } } } | { keep_groups?: bool (default true), keep_owner?: bool (default true) }`.
- **Outputs:** `{ replaced: NodePath, state, diff, revision }`.
- **Godot APIs:** `Node.replace_by(new_node, keep_groups)`; wrap in `EditorPlugin.get_undo_redo()`
  for undo.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** false. **mutates:** true.
- **Errors:** `scene.node_path_not_found`, `scene.path_not_found`.
- **Cursor prompt:** _"Replace /root/Main/PlaceholderEnemy with an instance of
  res://entities/Goblin.tscn."_

---

## 11.7 `project.*` — 7 tools

### `project.info`

- **Purpose:** consolidated project metadata.
- **Inputs:** none.
- **Outputs:**
  `{ name, version, godot_version_required, main_scene, renderer, dotnet: bool, autoload_count, addon_count, feature_tags: [string], path_user_dir: string, path_res_dir: string }`.
- **Godot APIs:** `ProjectSettings.get_setting()` per key; `OS.get_feature_list()`;
  `ProjectSettings.globalize_path("user://")` and `"res://"`.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"What's this project's metadata?"_

### `project.get_settings`

- **Purpose:** read one or many project settings.
- **Inputs:**
  `{ keys?: [string], group?: string (e.g., "rendering/"), include_defaults?: bool (default false) }`.
- **Outputs:** `{ settings: { key: { value, type, hint, hint_string, default, is_overridden } } }`.
- **Godot APIs:** `ProjectSettings.get_setting`, `ProjectSettings.get_property_list()` for shape.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Read all rendering/\* project settings."_

### `project.set_settings`

- **Purpose:** patch project settings.
- **Inputs:** `{ patch: { key: value, ... }, save?: bool (default true), dry_run?: bool }`.
- **Outputs:**
  `{ applied: { key: { before, after } }, dry_run: bool, state: <project.info shape> }`.
- **Godot APIs:** `ProjectSettings.set_setting(key, value)`; `ProjectSettings.save()` (or
  `save_custom`).
- **Editor:** ✅. **Headless:** ✅.
- **safe:** false. **mutates:** true.
- **Errors:** `project.setting_locked` (`-33590`) for read-only keys (e.g.,
  `application/config/features`).
- **Cursor prompt:** _"Set rendering/renderer/rendering_method to mobile."_

### `project.list_autoloads`

- **Purpose:** list every autoload entry.
- **Inputs:** none.
- **Outputs:**
  `{ autoloads: [{ name: string, path: ResourcePath, singleton: bool, source: "project"|"addon" }] }`.
- **Godot APIs:** enumerate keys under `autoload/*` via `ProjectSettings.get_property_list()`.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"List all autoloads."_

### `project.add_autoload`

- **Purpose:** register an autoload.
- **Inputs:** `{ name: string (PascalCase), path: ResourcePath, singleton?: bool (default true) }`.
- **Outputs:**
  `{ added: true, autoload: { name, path, singleton }, state: <list_autoloads result> }`.
- **Godot APIs:** `EditorPlugin.add_autoload_singleton(name, path)` if running inside the plugin;
  alternative: `ProjectSettings.set_setting("autoload/<name>", "*<path>")` (the `*` prefix means
  singleton).
- **Editor:** ✅. **Headless:** ⚠ (write `project.godot` directly; document caveat that the engine
  won't reload autoloads mid-headless-session).
- **safe:** false. **mutates:** true.
- **Errors:** `node.type_unknown` if path doesn't resolve to a Node-extending class.
- **Cursor prompt:** _"Register res://scripts/GameState.gd as autoload GameState."_

### `project.remove_autoload`

- **Purpose:** unregister an autoload.
- **Inputs:** `{ name: string }`.
- **Outputs:** `{ removed: true, name, state }`.
- **Godot APIs:** `EditorPlugin.remove_autoload_singleton(name)`; or clear the setting.
- **Editor:** ✅. **Headless:** ⚠ (same caveat as `add_autoload`).
- **safe:** false. **mutates:** true.
- **Errors:** none if name absent (idempotent).
- **Cursor prompt:** _"Remove the GameState autoload."_

### `project.set_main_scene`

- **Purpose:** set `application/run/main_scene`.
- **Inputs:** `{ path: ScenePath, validate?: bool (default true) }`.
- **Outputs:** `{ set: true, path, previous: ScenePath | null, state }`.
- **Godot APIs:** `ProjectSettings.set_setting("application/run/main_scene", path)`;
  `ProjectSettings.save()`.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** false. **mutates:** true.
- **Errors:** `scene.path_not_found` if `validate=true` and the file is missing.
- **Cursor prompt:** _"Set the main scene to res://levels/Title.tscn."_

---

## 11.8 Schemes / data shapes added

- `Selector` type finalized: `oneOf`:
  `{ node_path: NodePath } | { uid: string } | { query: { type?, group?, name_pattern?, in_subtree_of? } }`.
  Lives at `packages/shared/schemas/common/Selector.json`.
- `SceneSummary` envelope:
  `{ root: { name, type }, depth_returned, total_node_count_estimate, sample: [ { name, type, path, children_count, sample_children: [] } ], pointers: [...] }`.
- `ProjectSetting` shape: `{ value, type, hint, hint_string, default, is_overridden }`.

## 11.9 Tech stack delta

- No new dependencies.
- Daemon adds `handlers/scene.gd` and `handlers/project.gd`.
- Router auto-generates 16 tool modules; no hand-overrides expected.

## 11.10 Acceptance criteria

- [ ] All 16 tools appear in `tools.list({category: "scene"})` and
      `tools.list({category: "project"})`.
- [ ] Each tool passes the 5-test bar from `08 §8.11` (happy read, happy write, schema rejection,
      domain error, notification where applicable).
- [ ] Editor-only tools properly return `editor.not_available` when run headless.
- [ ] Headless variants verified against `tests/_fixtures/empty/` and `tests/_fixtures/minimal_3d/`.
- [ ] `docs/catalog/scene.md` and `docs/catalog/project.md` regenerated and committed.
- [ ] Catalog version bumped to `0.3.0`.
- [ ] CHANGELOG entry added.
- [ ] `release:check` green.

## 11.11 Verification plan

1. **Sanity:** `tools.health` after restart must show matching catalog hashes.
2. **Round-trip:** call `scene.list` on a fresh fixture; expect ≥ 1 result.
3. **Create-then-read:** `scene.create` a new scene → `scene.get_tree` returns the expected root.
4. **Mutate-then-verify:** `project.set_settings { "rendering/anti_aliasing/quality/msaa_2d": 1 }` →
   `project.get_settings` reflects the change.
5. **Undo:** in editor, run `scene.replace`, then trigger Ctrl-Z from the editor — subtree restored.
6. **Headless parity:** every tool that claims headless support is exercised via
   `headless.start_project` first.
7. **Notification:** modify a setting via `project.set_settings`; subscribe to
   `event.project.setting_changed` (new event introduced here) — verify the event fires.

## 11.12 Risks & mitigations

| Risk                                                                                               | Mitigation                                                                               |
| -------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `scene.close` lacks a public API in some Godot minors.                                             | Mark as best-effort; surface `editor.not_available` with autoHeal if it can't act.       |
| `scene.delete` orphans references.                                                                 | `force=false` by default; uses `resource.get_dependents` to refuse if breakage detected. |
| `project.set_settings` on a critical key (e.g., `application/config/name`) breaks the dev project. | Whitelist of "high-risk" keys gated behind `confirm_high_risk: true`.                    |
| Autoload reorder semantics differ between minor versions.                                          | Document the limitation; tool returns the current order as observed.                     |
| `PackedScene.pack` fails if children have null `owner`.                                            | Always set `owner` recursively in `scene.create` / `scene.pack`.                         |

## 11.13 Handoff checklist to file `12`

- [x] Catalog version pushed (task 11 land merged at **0.5.0**; cumulative **0.8.0** on `master`).
- [x] Scene + project methods registered (**22** tools).
- [x] `docs/catalog/scene.md` and `docs/catalog/project.md` committed.
- [x] Integration tests green in CI.
- [x] Open `12-catalog-node-polymorphic.md`.

---

## 11.14 Commit template

```text
feat(catalog): ship scene.* (9 tools) and project.* (7 tools) — Phase 3 work-unit #1

- Adds 16 tools to packages/shared/methods/registry.json
- Adds handlers/scene.gd and handlers/project.gd in the addon
- Router auto-generation produces 16 new MCP tools
- Bumps catalog_version 0.2.0 -> 0.3.0
- Updates docs/catalog/{scene,project}.md
- Adds integration tests under tests/integration/{scene,project}/

Refs: docs/tasklist/11-catalog-scene-and-project.md
```
