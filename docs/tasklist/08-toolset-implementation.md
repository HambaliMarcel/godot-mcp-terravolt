# 08 — Toolset Implementation (Phase 3 — the 200+ catalog)

> **Goal**: enumerate, organize, and implement the **complete Terravolt MCP tool catalog** — the
> surface that lets an agent build a full Godot 4 game by prompting. This file is the **catalog
> spec**: every tool, every category, every schema sketch, every error code, every parity note
> (editor vs headless). It is intentionally large. Implementation proceeds **category by category,
> iteratively**, gated on integration tests per category. No code is written here; this file is the
> _blueprint_ the implementer follows.

---

## 8.1 Header

- **File:** `08-toolset-implementation.md`
- **Purpose:** define ~235 tools organized by 22 categories, with detailed schema sketches and
  acceptance per category.

## 8.2 Phase placement

- **Phase 3.** Iterative.
- Gates Phase 4 only when **all categories** have at least one shipped tool with integration tests;
  the agent may declare a category "shipped" before all tools in it are implemented as long as the
  category's transport is verified and the must-have core tools are live.

## 8.3 Inputs / prerequisites

- Files `00`–`07` complete.
- Shared registries (`packages/shared/methods/registry.json` and
  `packages/shared/errors/registry.json`) in place from `06`.
- Headless fallback from `07` available.
- Code-gen pipeline produces typed router code + GDScript handler stubs.

## 8.4 Outputs

After this file:

1. The shared method registry contains all tools described below.
2. Each tool has: name, description, category, input schema, output schema, error codes, parity
   (editor/headless), safety/mutates flags, examples.
3. Daemon and headless driver implement category-by-category handlers.
4. Router exposes them to MCP clients.
5. `docs/catalog/` regenerated.
6. Per-category integration tests live (full QA matrix is in `10`).

## 8.5 Operating constants used

All from previous files.

---

## 8.6 Implementation order (recommended)

Implement in this order so that **dependencies are satisfied**:

1. **server / log / event / tools** — already partially shipped in `04`/`05`/`06`. Round these out.
2. **scene** — foundation for everything visual.
3. **node** — DOM ops, the polymorphic `node.modify`.
4. **script** — needed for everything dynamic.
5. **signal** — once nodes and scripts exist.
6. **resource** — generalizes scene/script.
7. **asset** — import pipeline.
8. **runtime** — playmode + telemetry.
9. **editor** — UX glue.
10. **project** — settings, autoloads.
11. **input** — actions.
12. **animation** — heavy editor.
13. **physics**.
14. **render**.
15. **audio**.
16. **network**.
17. **debug**.
18. **profile**.
19. **macro** — high-level vibe-coding workflows; built on top of all of the above.

Inside each category, write at least one **integration test** that proves the core tool round-trips
through both the editor daemon and (where applicable) the headless driver before moving to the next
category.

---

## 8.7 Universal rules for every tool

1. **Polymorphism over enumeration** (per `00 §0.6`). Where natural, fold variants into one tool
   with a discriminator field.
2. **Successful mutation returns the new state** of the affected object plus a `diff`.
3. **Errors use the registry** from `04 §4.6.5`; new codes added here are mirrored in the shared
   registry.
4. **Inputs validated** by schema on both router and daemon.
5. **Editor-only tools** declare `requiresEditor: true`; headless-capable tools fill in the parity
   table.
6. **Examples mandatory** — every tool's registry entry includes at least one request/response
   example.
7. **Side-effects logged** — every mutating tool produces a `dispatch.handler_called` debug log + a
   category-specific event notification if applicable.
8. **Dry-run support** — every mutating tool accepts `dryRun: true` to return the prospective new
   state without committing.
9. **Idempotency** — wherever feasible, tools are idempotent or expose an `ifMatch` revision token.

---

## 8.8 Common types referenced (see `06 §6.7.4`)

`NodePath`, `ScenePath`, `ResourcePath`, `NodeRef`, `PropertyDict`, `Variant`, `Diagnostic`,
`Vector2/3/4`, `Color`, `Transform2D/3D`, `Rect2`, `AABB`.

Two new common types introduced in this file:

- **`Selector`** — flexible scene/node selector: `oneOf`: NodePath, NodeRef (uid), `query` object
  with `{type?, group?, name_pattern?, in_subtree_of?}`.
- **`Patch`** — a property patch with optional `op` (`set`, `merge`, `delete`).

---

## 8.9 Category catalogs

> For each tool below, the registry entry will include: `description`, `inputSchema`,
> `outputSchema`, `category`, `safe`, `mutates`, `requiresEditor`, `requiresRuntime`, `cancellable`,
> `since`, `errorCodes`, `examples`. The summaries here are prose. **No code anywhere.**

### 8.9.1 `server` (8 tools)

| Tool                      | Summary                                                                           | Mutates      | Editor | Headless |
| ------------------------- | --------------------------------------------------------------------------------- | ------------ | ------ | -------- |
| `server.info`             | Identity, versions, listen address, uptime, catalog hash, mode (editor/headless). | no           | ✅     | ✅       |
| `server.list_methods`     | All registered methods + metadata. Optional `prefix`, `category`, `safe` filters. | no           | ✅     | ✅       |
| `server.list_error_codes` | The full error code registry.                                                     | no           | ✅     | ✅       |
| `server.shutdown`         | Gracefully stop the daemon (gated by `allow_remote_shutdown`).                    | yes          | ✅     | ✅       |
| `server.ping`             | Heartbeat.                                                                        | no           | ✅     | ✅       |
| `server.heartbeat`        | RPC heartbeat fallback.                                                           | no           | ✅     | ✅       |
| `server.set_log_level`    | Adjust logger level.                                                              | yes (config) | ✅     | ✅       |
| `server.set_settings`     | Patch any whitelisted setting; rejects port/bind without restart hint.            | yes (config) | ✅     | ✅       |

### 8.9.2 `log` (5 tools)

| Tool             | Summary                                                                                                |
| ---------------- | ------------------------------------------------------------------------------------------------------ |
| `log.tail`       | Return last N records (filterable).                                                                    |
| `log.set_level`  | Change minimum level.                                                                                  |
| `log.clear`      | Truncate active log (archives kept). Returns previous size.                                            |
| `log.rotate_now` | Force a rotation immediately.                                                                          |
| `log.search`     | Search records by predicate `{level?, subsystem?, event?, contains?, since?, until?}`; bounded result. |

### 8.9.3 `event` (5 tools)

| Tool                       | Summary                                                      |
| -------------------------- | ------------------------------------------------------------ |
| `event.subscribe`          | Add a subscription with method filter and optional throttle. |
| `event.unsubscribe`        | Remove a subscription by id.                                 |
| `event.list_subscriptions` | Active subs.                                                 |
| `event.throttle`           | Update rate limits per method.                               |
| `event.drain`              | Force-emit any buffered events for a subscription.           |

Server-initiated events (notifications) the agent can subscribe to (defined here, emitted by
relevant handlers below):

`event.scene.opened`, `event.scene.closed`, `event.scene.saved`, `event.scene.tree_changed`,
`event.node.added`, `event.node.removed`, `event.node.modified`, `event.script.attached`,
`event.script.compiled`, `event.resource.changed`, `event.asset.imported`, `event.runtime.started`,
`event.runtime.stopped`, `event.runtime.tree_changed`, `event.runtime.fps`, `event.logging.rotated`,
`event.editor.tab_focused`, `event.headless.session_state_changed`.

### 8.9.4 `tools` (4 tools)

| Tool             | Summary                                                                     |
| ---------------- | --------------------------------------------------------------------------- |
| `tools.list`     | All registered MCP tools.                                                   |
| `tools.describe` | Full descriptor by name.                                                    |
| `tools.metrics`  | Rolling counters.                                                           |
| `tools.health`   | Composite health check (registry hashes, transport, headless availability). |

### 8.9.5 `scene` (15 tools)

| Tool                 | Summary                                                                   | Mutates | Notes       |
| -------------------- | ------------------------------------------------------------------------- | ------- | ----------- |
| `scene.list`         | All scenes in the project. Optional path glob.                            | no      |             |
| `scene.get`          | Return scene metadata (root type, node count, has_script, last_modified). | no      |             |
| `scene.open`         | Open scene in editor.                                                     | yes     | editor-only |
| `scene.close`        | Close currently-open scene.                                               | yes     | editor-only |
| `scene.save`         | Save the current edited scene.                                            | yes     | editor-only |
| `scene.save_as`      | Save under a new path.                                                    | yes     | editor-only |
| `scene.create`       | Create a new scene file with a root node type.                            | yes     | both        |
| `scene.delete`       | Delete a scene file (with safety checks for autoload refs).               | yes     | both        |
| `scene.instantiate`  | Instantiate a scene into an open scene/subtree.                           | yes     | both        |
| `scene.pack`         | Pack a subtree into a PackedScene resource.                               | yes     | both        |
| `scene.get_tree`     | Return the full scene tree (subject to context envelope).                 | no      |             |
| `scene.get_subtree`  | Tree rooted at a given node.                                              | no      |             |
| `scene.find_in_tree` | Find nodes by `Selector`.                                                 | no      |             |
| `scene.validate`     | Run scene integrity checks (broken refs, missing scripts).                | no      | both        |
| `scene.replace`      | Replace a subtree with another scene/subtree.                             | yes     | both        |

### 8.9.6 `node` (20 tools)

| Tool                         | Summary                                                                                                                                                                                                 | Mutates          | Polymorphic notes                                           |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----------------------------------------------------------- |
| `node.get`                   | Full node snapshot: type, name, path, properties (filtered), groups, meta, signals, child names.                                                                                                        | no               |                                                             |
| `node.modify`                | **Polymorphic.** Patch properties, groups, owner, meta. Accepts `properties?: PropertyDict`, `groups?: { add?: [], remove?: [] }`, `owner?: NodePath`, `meta?: PropertyDict`. Returns new state + diff. | yes              | covers ≥ 4 narrow ops                                       |
| `node.add`                   | Create a child node of a type at a parent.                                                                                                                                                              | yes              |                                                             |
| `node.remove`                | Delete a node (and subtree).                                                                                                                                                                            | yes              |                                                             |
| `node.reparent`              | Move a node to a new parent with optional `keep_global_transform`.                                                                                                                                      | yes              |                                                             |
| `node.duplicate`             | Duplicate a node (subtree, with flags).                                                                                                                                                                 | yes              |                                                             |
| `node.rename`                | Rename a node.                                                                                                                                                                                          | yes              |                                                             |
| `node.find`                  | Find first/all by `Selector`.                                                                                                                                                                           | no               |                                                             |
| `node.get_path`              | Resolve a `Selector` to an unambiguous NodePath.                                                                                                                                                        | no               |                                                             |
| `node.set_owner`             | Re-owner subtree (useful for scene packing).                                                                                                                                                            | yes              | partly subsumed by `node.modify`; kept distinct for clarity |
| `node.get_children`          | Direct children list.                                                                                                                                                                                   | no               |                                                             |
| `node.get_parent`            | Parent node info.                                                                                                                                                                                       | no               |                                                             |
| `node.get_signals`           | Signals declared + connections.                                                                                                                                                                         | no               |                                                             |
| `node.get_methods`           | Available methods including inherited.                                                                                                                                                                  | no               |                                                             |
| `node.get_properties_schema` | List of properties with types and hints (Godot's property metadata).                                                                                                                                    | no               |                                                             |
| `node.walk`                  | Bounded traversal returning a stream-friendly subset.                                                                                                                                                   | no               |                                                             |
| `node.query`                 | Sophisticated query (XPath-like via the Selector type).                                                                                                                                                 | no               |                                                             |
| `node.set_visibility`        | Toggle visibility for 2D/3D nodes uniformly.                                                                                                                                                            | yes              | composed via `node.modify`, exposed for ergonomics          |
| `node.evaluate_in_node`      | Evaluate a typed expression in the context of a node (sandboxed; gated by `--allow-eval`).                                                                                                              | yes/no           | hidden by default                                           |
| `node.observe`               | Start a property observation: emit `event.node.modified` when listed properties change (until `unobserve`).                                                                                             | yes (subscribes) |                                                             |

### 8.9.7 `script` (15 tools)

| Tool                             | Summary                                                                                                                                                                              | Mutates |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------- |
| `script.attach`                  | Attach a script (path or new file template) to a node.                                                                                                                               | yes     |
| `script.detach`                  | Remove the script from a node.                                                                                                                                                       | yes     |
| `script.get`                     | Return script metadata + content (truncated if large).                                                                                                                               | no      |
| `script.set`                     | Replace script content (full or patch).                                                                                                                                              | yes     |
| `script.validate`                | Compile-check (GDScript or C#) via headless driver.                                                                                                                                  | no      |
| `script.refactor_rename`         | Rename a symbol across all scripts. Reports affected files.                                                                                                                          | yes     |
| `script.refactor_extract_method` | Extract a code range to a new method; updates callsites.                                                                                                                             | yes     |
| `script.search`                  | Symbol/text search across project scripts.                                                                                                                                           | no      |
| `script.replace`                 | Project-wide replace with safety guards (preview unless `commit:true`).                                                                                                              | yes     |
| `script.list_classes_in_project` | All `class_name` declarations.                                                                                                                                                       | no      |
| `script.generate_signature`      | Generate a function signature from a natural-language description (LLM-call disabled by default; agent does this off-MCP). Reserve method; v1 returns an "unimplemented" diagnostic. | no      |
| `script.document`                | Generate/refresh docstrings for a class.                                                                                                                                             | yes     |
| `script.format`                  | Apply formatter to a script.                                                                                                                                                         | yes     |
| `script.compile_all`             | Compile every script in the project; aggregate errors.                                                                                                                               | no      |
| `script.get_errors`              | Errors from last compile.                                                                                                                                                            | no      |

### 8.9.8 `signal` (10 tools)

| Tool                         | Summary                                         | Mutates |
| ---------------------------- | ----------------------------------------------- | ------- |
| `signal.list`                | Signals on a node (declared + inherited).       | no      |
| `signal.connect`             | Connect signal to a target node + method.       | yes     |
| `signal.disconnect`          | Disconnect.                                     | yes     |
| `signal.emit`                | Emit a signal (for tests/dev).                  | yes     |
| `signal.list_callbacks`      | Callbacks connected to a signal.                | no      |
| `signal.validate_connection` | Confirm a connection's target method exists.    | no      |
| `signal.list_emitters_of`    | All nodes that emit signal `X` of given type.   | no      |
| `signal.list_listeners_of`   | All listeners of signal `X`.                    | no      |
| `signal.suppress`            | Temporarily suppress emissions (for debugging). | yes     |
| `signal.replay`              | Replay a recorded emission sequence.            | yes     |

### 8.9.9 `resource` (15 tools)

| Tool                        | Summary                                                                                            |
| --------------------------- | -------------------------------------------------------------------------------------------------- |
| `resource.load`             | Load resource at path; returns serialized content + type.                                          |
| `resource.save`             | Save resource.                                                                                     |
| `resource.list`             | List resources matching a glob.                                                                    |
| `resource.find_by_path`     | Resolve a path to UID + metadata.                                                                  |
| `resource.find_by_uid`      | Resolve a UID to a path.                                                                           |
| `resource.create`           | Create a new resource (type + initial properties).                                                 |
| `resource.modify`           | Patch properties (polymorphic; covers shaders, materials, themes, fonts, curves, gradients, etc.). |
| `resource.duplicate`        | Duplicate to a new path.                                                                           |
| `resource.convert`          | Convert a resource (e.g., StreamPlayer settings, audio re-import options).                         |
| `resource.delete`           | Delete with dependency check.                                                                      |
| `resource.move`             | Move and update all references.                                                                    |
| `resource.get_dependencies` | What this resource references.                                                                     |
| `resource.get_dependents`   | What references this resource.                                                                     |
| `resource.validate`         | Type-check and integrity-check.                                                                    |
| `resource.snapshot`         | Create a versioned snapshot for rollback (in-memory; not git).                                     |

### 8.9.10 `asset` (12 tools)

| Tool                       | Summary                                                                   |
| -------------------------- | ------------------------------------------------------------------------- |
| `asset.import`             | Import a file with options.                                               |
| `asset.reimport`           | Force reimport.                                                           |
| `asset.list`               | List assets (filter by type, path, modified).                             |
| `asset.get_metadata`       | Importer settings for a file.                                             |
| `asset.set_preset`         | Set per-file import preset (e.g., nearest-neighbor for pixel art folder). |
| `asset.batch_apply_preset` | Apply a preset across a directory or glob.                                |
| `asset.validate`           | Check importer errors.                                                    |
| `asset.find_dups`          | Detect duplicate textures/sounds by hash.                                 |
| `asset.audit`              | Bulk report of asset health, sizes, types.                                |
| `asset.fix_broken_refs`    | Re-link references that moved.                                            |
| `asset.convert_format`     | Convert image/audio/model formats (headless preferred).                   |
| `asset.optimize`           | Compress textures, downsample audio with a recipe.                        |

### 8.9.11 `runtime` (15 tools)

| Tool                       | Summary                                                 | Requires runtime |
| -------------------------- | ------------------------------------------------------- | ---------------- |
| `runtime.play`             | Start the project (scene optional).                     | n/a — starts it  |
| `runtime.stop`             | Stop.                                                   | yes              |
| `runtime.pause`            | Pause.                                                  | yes              |
| `runtime.resume`           | Resume.                                                 | yes              |
| `runtime.step`             | Single-step (if editor debugger attached).              | yes              |
| `runtime.get_tree`         | Live scene tree during play.                            | yes              |
| `runtime.get_node`         | Read node properties live.                              | yes              |
| `runtime.set_node`         | Live patch a property.                                  | yes              |
| `runtime.simulate_input`   | Drive an InputMap action or raw key.                    | yes              |
| `runtime.get_performance`  | FPS, draw calls, VRAM, physics tics, GC.                | yes              |
| `runtime.set_breakpoint`   | Set a script breakpoint.                                | both             |
| `runtime.clear_breakpoint` | Clear.                                                  | both             |
| `runtime.list_breakpoints` | List.                                                   | both             |
| `runtime.profile_snapshot` | Capture a snapshot.                                     | yes              |
| `runtime.replay`           | Replay a recorded input sequence (if recording exists). | yes              |

### 8.9.12 `editor` (12 tools, editor-only)

| Tool                          | Summary                                                                   |
| ----------------------------- | ------------------------------------------------------------------------- |
| `editor.open_scene`           | Open a scene tab.                                                         |
| `editor.open_script`          | Open a script in the editor.                                              |
| `editor.focus_node`           | Focus a node in the SceneTree dock.                                       |
| `editor.select_nodes`         | Multi-select.                                                             |
| `editor.get_selection`        | Current selection.                                                        |
| `editor.run_undo`             | Undo the last user/editor action.                                         |
| `editor.run_redo`             | Redo.                                                                     |
| `editor.save_all`             | Save every dirty resource/scene.                                          |
| `editor.request_user_confirm` | Show a confirm dialog and return user's choice (for risky agent actions). |
| `editor.show_status_message`  | Render a status bar message.                                              |
| `editor.list_open_tabs`       | Scenes/scripts open.                                                      |
| `editor.close_tab`            | Close one.                                                                |

### 8.9.13 `project` (10 tools)

| Tool                         | Summary                                                                        |
| ---------------------------- | ------------------------------------------------------------------------------ |
| `project.get_settings`       | All project settings (filtered/grouped).                                       |
| `project.set_settings`       | Patch settings with type guards.                                               |
| `project.list_autoloads`     | Autoload list with paths and singletons.                                       |
| `project.add_autoload`       | Add an autoload entry.                                                         |
| `project.remove_autoload`    | Remove.                                                                        |
| `project.set_main_scene`     | Set the main scene.                                                            |
| `project.get_config_version` | `project.godot` config version + Godot min version.                            |
| `project.ensure_addons`      | Verify required addons are installed and enabled (Terravolt MCP itself first). |
| `project.list_features`      | Custom features.                                                               |
| `project.set_feature_flag`   | Toggle a custom feature flag.                                                  |

### 8.9.14 `input` (8 tools)

| Tool                       | Summary                               |
| -------------------------- | ------------------------------------- |
| `input.list_actions`       | Actions and bindings.                 |
| `input.add_action`         | Add a new action.                     |
| `input.remove_action`      | Remove.                               |
| `input.bind_key`           | Bind a key/mouse event.               |
| `input.bind_joystick`      | Bind a joystick event.                |
| `input.simulate_action`    | Drive an action (mostly runtime).     |
| `input.query_action_state` | Pressed/held/just-pressed.            |
| `input.validate_map`       | Check for conflicts/missing bindings. |

### 8.9.15 `animation` (12 tools)

| Tool                         | Summary                                                       |
| ---------------------------- | ------------------------------------------------------------- |
| `animation.create_player`    | Add an `AnimationPlayer` or `AnimationTree` to a node.        |
| `animation.list_animations`  | Animations on a player.                                       |
| `animation.create_animation` | New animation with length, loop.                              |
| `animation.edit_track`       | Add/modify a track (transform, value, method, audio, bezier). |
| `animation.get_track`        | Inspect a track.                                              |
| `animation.remove_track`     | Remove.                                                       |
| `animation.blend`            | Blend tree config.                                            |
| `animation.list_blend_trees` | Blend trees on a player.                                      |
| `animation.edit_blend_tree`  | Modify blend tree nodes.                                      |
| `animation.scrub`            | Move playhead to a time.                                      |
| `animation.snapshot_pose`    | Capture current pose as a keyframe set.                       |
| `animation.retarget`         | Retarget a skeleton animation to another rig.                 |

### 8.9.16 `physics` (10 tools)

| Tool                                | Summary                                     |
| ----------------------------------- | ------------------------------------------- |
| `physics.set_gravity`               | World gravity (2D / 3D variants via field). |
| `physics.set_layer_names`           | Name collision layers.                      |
| `physics.configure_collision_pairs` | Layer/mask matrix.                          |
| `physics.attach_collision_shape`    | Add a CollisionShape to a body.             |
| `physics.query_overlapping`         | Query bodies overlapping a shape.           |
| `physics.query_raycast`             | Ray from A to B; returns hits.              |
| `physics.query_shape_intersects`    | Shape intersection query.                   |
| `physics.simulate_step`             | Step the physics world (headless useful).   |
| `physics.configure_world`           | World boundaries, sleeping, etc.            |
| `physics.list_physics_servers`      | 2D vs 3D server states.                     |

### 8.9.17 `render` (10 tools)

| Tool                        | Summary                                                 |
| --------------------------- | ------------------------------------------------------- |
| `render.set_environment`    | Apply a WorldEnvironment / sky/fog/SSAO.                |
| `render.set_camera`         | Position, FOV, projection.                              |
| `render.configure_lights`   | Add/modify lights.                                      |
| `render.set_postprocess`    | DOF, glow, color correction.                            |
| `render.set_renderer_mode`  | Forward+/Mobile/Compat.                                 |
| `render.capture_screenshot` | Capture an image (editor preview or runtime).           |
| `render.get_renderer_info`  | Backend, GPU, capabilities.                             |
| `render.set_quality_preset` | Low/Medium/High preset map applied to project settings. |
| `render.list_shaders`       | Project shaders.                                        |
| `render.compile_shader`     | Compile-check.                                          |

### 8.9.18 `audio` (8 tools)

| Tool                       | Summary                                     |
| -------------------------- | ------------------------------------------- |
| `audio.list_buses`         | Buses + effects.                            |
| `audio.add_bus`            | Create a bus.                               |
| `audio.set_bus_volume`     | Volume + mute.                              |
| `audio.route`              | Reorder bus sends.                          |
| `audio.import_audio`       | Import file with bus suggestion.            |
| `audio.play_test_sound`    | Play during dev to verify routing (editor). |
| `audio.set_master_volume`  | Master volume.                              |
| `audio.configure_3d_audio` | Doppler, reverb, panning.                   |

### 8.9.19 `network` (8 tools)

| Tool                            | Summary                                |
| ------------------------------- | -------------------------------------- |
| `network.list_peers`            | Peers in a multiplayer session.        |
| `network.configure_multiplayer` | Mode (server/client), port, max peers. |
| `network.host`                  | Start hosting (runtime).               |
| `network.join`                  | Join.                                  |
| `network.list_rpcs`             | RPC methods on connected nodes.        |
| `network.register_rpc`          | Mark a method as RPC (script edit).    |
| `network.set_compression`       | Compression mode.                      |
| `network.test_connection`       | Echo packet round-trip.                |

### 8.9.20 `debug` (10 tools, editor-leaning)

| Tool                     | Summary                                 |
| ------------------------ | --------------------------------------- |
| `debug.break`            | Pause execution at the next safe point. |
| `debug.continue`         | Resume.                                 |
| `debug.step`             | Step over / into / out.                 |
| `debug.get_stack`        | Current stack frames.                   |
| `debug.get_locals`       | Locals at a frame.                      |
| `debug.set_local`        | Mutate a local (where supported).       |
| `debug.watch_expression` | Add a watch.                            |
| `debug.list_watches`     | List.                                   |
| `debug.attach`           | Attach debugger to a running game.      |
| `debug.detach`           | Detach.                                 |

### 8.9.21 `profile` (8 tools)

| Tool                          | Summary                       |
| ----------------------------- | ----------------------------- |
| `profile.start_capture`       | Start a profile capture.      |
| `profile.stop_capture`        | Stop; returns artifact.       |
| `profile.get_fps`             | Sample.                       |
| `profile.get_draw_calls`      | Sample.                       |
| `profile.get_memory`          | Heap / VRAM.                  |
| `profile.get_physics_metrics` | Steps, contacts, sleeping.    |
| `profile.list_hot_functions`  | Top consumers.                |
| `profile.export_report`       | Save a human-friendly report. |

### 8.9.22 `macro` (15 tools — the "vibe coding" multipliers)

Macros compose primitives. Each macro is a single MCP tool that produces multiple side-effects
atomically (with a single "new state" payload + diff). Macros must be **dry-runnable**.

| Macro                                 | Summary                                                                                                     |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `macro.scaffold_ui`                   | JSON `Control` tree → nested controls (margins, boxes, anchors). Returns the resulting subtree state.       |
| `macro.scaffold_scene`                | Common scene templates (FPS, top-down, side-scroller, menu). Inputs choose template + variant.              |
| `macro.scaffold_state_machine`        | Generate a hierarchical state machine (states, transitions, optional `AnimationTree` integration).          |
| `macro.scaffold_npc`                  | NPC archetype: body, collisions, anim states, dialogue hook, AI behavior tree skeleton.                     |
| `macro.scaffold_inventory`            | Inventory resource + UI grid + drag-and-drop signals.                                                       |
| `macro.scaffold_dialogue`             | Dialogue system: data files, runner node, UI, advance/skip controls.                                        |
| `macro.scaffold_save_system`          | Save/load with versioning, slot management, migration shim.                                                 |
| `macro.scaffold_menu`                 | Main menu (start/options/quit) with input mapping.                                                          |
| `macro.scaffold_pause_screen`         | Pause overlay with resume/options/quit and time-scale handling.                                             |
| `macro.scaffold_settings_panel`       | Audio/video/input options bound to project settings.                                                        |
| `macro.scaffold_pickup_item`          | Pickup template with hitbox, signal, polishing tween.                                                       |
| `macro.scaffold_player_controller_2d` | Top-down or platformer controller skeleton with input map + animation hooks.                                |
| `macro.scaffold_player_controller_3d` | FPS or third-person controller skeleton.                                                                    |
| `macro.batch_apply`                   | Apply a recipe (sequence of tool calls described in a single document) atomically with rollback on failure. |
| `macro.refactor_node_references`      | Project-wide path rename: update `get_node()` / `$` usage / `@onready` references in scripts.               |

Macros are **opinionated**. Each macro ships with one or two well-curated recipes; agents can adjust
later.

---

## 8.10 Catalog footprint count

Sum: 8 + 5 + 5 + 4 + 15 + 20 + 15 + 10 + 15 + 12 + 15 + 12 + 10 + 8 + 12 + 10 + 10 + 8 + 8 + 10 +
8 + 15 = **230 tools**. Above the 200 target with headroom.

---

## 8.11 Per-category integration tests (minimum)

For each category, **before** marking it shipped, the implementer must add:

- A round-trip test through the editor daemon for at least one mutating tool and one read tool.
- A headless variant if the category is supported in headless.
- A _negative_ test: malformed input → `protocol.invalid_params`.
- A _failure_ test: meaningful domain error (e.g., `scene.path_not_found`).
- A _notification_ test where the category emits events.

CI matrix details are in `10`.

---

## 8.12 New error codes added in this file

Reserve a block (`-33500` to `-33899` already in use; new codes added per category as needed):

| Code     | Symbol                        | Category  |
| -------- | ----------------------------- | --------- |
| `-33510` | `scene.create_failed`         | scene     |
| `-33511` | `scene.save_failed`           | scene     |
| `-33520` | `node.type_unknown`           | node      |
| `-33521` | `node.add_failed`             | node      |
| `-33522` | `node.reparent_invalid`       | node      |
| `-33530` | `script.refactor_conflict`    | script    |
| `-33531` | `script.compile_error`        | script    |
| `-33540` | `signal.unknown_signal`       | signal    |
| `-33541` | `signal.already_connected`    | signal    |
| `-33550` | `resource.dependency_block`   | resource  |
| `-33551` | `resource.write_failed`       | resource  |
| `-33560` | `asset.import_failed`         | asset     |
| `-33561` | `asset.preset_unknown`        | asset     |
| `-33570` | `runtime.invalid_state`       | runtime   |
| `-33580` | `editor.no_active_scene`      | editor    |
| `-33581` | `editor.dialog_cancelled`     | editor    |
| `-33590` | `project.setting_locked`      | project   |
| `-33600` | `input.binding_conflict`      | input     |
| `-33610` | `animation.track_invalid`     | animation |
| `-33620` | `physics.shape_required`      | physics   |
| `-33630` | `render.backend_unsupported`  | render    |
| `-33640` | `audio.bus_unknown`           | audio     |
| `-33650` | `network.not_connected`       | network   |
| `-33660` | `debug.attach_failed`         | debug     |
| `-33670` | `profile.capture_in_progress` | profile   |
| `-33680` | `macro.recipe_invalid`        | macro     |
| `-33681` | `macro.partial_failure`       | macro     |

All mirrored in `packages/shared/errors/registry.json`.

---

## 8.13 Tooling outputs / docs

- `docs/catalog/` regenerated on every catalog change (driven by `06`'s codegen).
- A printable cheat sheet (`docs/catalog/cheat-sheet.md`) listing all tools in one page (table
  only).
- Each category gets its own page with examples (`docs/catalog/<category>.md`).
- Parity matrix (`docs/catalog/parity.md`) auto-generated.

---

## 8.14 Acceptance criteria (this file = catalog spec)

- [ ] Shared registry contains all 230 tools with full metadata.
- [ ] Each category has at least one shipped read tool and one shipped write tool with integration
      tests.
- [ ] `node.modify` is polymorphic (one tool replaces ≥ 4 narrow ones).
- [ ] No duplicate-coverage tools snuck in (audit done; doctrine §0.6 honored).
- [ ] `docs/catalog/` regenerated.
- [ ] Parity matrix accurate.
- [ ] New error codes added to the shared error registry.
- [ ] Decisions Log updated.

---

## 8.15 Verification plan

1. Per-category integration tests pass (see `10` for the full matrix).
2. `tools.health` reports green: hashes match, schemas valid.
3. `tools.list` returns ≥ 200 tools.
4. Doc-gen run produces no diffs on second run (idempotent).
5. A "vibe coding" smoke test (in `10`): a single English prompt builds a tiny scene via
   `scene.create` + `node.add` + `script.attach` + `signal.connect`, then `runtime.play` runs it.

---

## 8.16 Risks & mitigations

| Risk                                                                           | Mitigation                                                                                              |
| ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| Catalog explosion ↔ maintenance debt.                                          | Polymorphism doctrine + codegen + per-category tests.                                                   |
| Tools that _look_ generic but are deeply specialized (e.g., animation tracks). | Use category-specific input schemas; don't force generic shapes.                                        |
| Macros become brittle.                                                         | Macros are versioned recipes; agents can request a specific recipe id.                                  |
| Schema duplication.                                                            | `packages/shared/schemas/common/`.                                                                      |
| Inconsistent return state across mutating tools.                               | Single response envelope (§6.6.6) enforced by codegen.                                                  |
| Editor/headless parity drifts.                                                 | Parity matrix is a CI artifact; regression tests on each release.                                       |
| Tools the engine can't safely automate (e.g., destructive ops).                | Mark `safe: false`, require explicit confirmation via `editor.request_user_confirm` or a dry-run first. |

---

## 8.17 Handoff checklist to file `09`

- [ ] All tools registered.
- [ ] `event.*` emitters in place for the key state changes (scene tree, node mods, runtime state).
- [ ] Telemetry hooks gathering data per tool.
- [ ] Failure paths exercise the error registry.
- [ ] Doc-gen produces clean `docs/catalog/`.

When done, open **`09-context-and-error-optimization.md`**.

---

## Appendix A — Official Godot Docs alignment (added revision 2)

> Sourced from `tutorials/scripting/*`, `tutorials/animation/*`, `tutorials/inputs/*`,
> `tutorials/networking/*`, and the `class_*` reference. For each catalog category, this appendix
> names the **canonical engine APIs** the daemon handler must use, plus per-category caveats.

### A.1 `scene.*` — implementation map

| Tool                 | Daemon-side APIs (Godot 4)                                                                                                             | Caveats                                                                                                                                                                                        |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `scene.list`         | `EditorFileSystem.get_filesystem()` walk + glob on `.tscn` / `.scn`.                                                                   | Honor `.gitignore`-like patterns via the addon's own ignore list.                                                                                                                              |
| `scene.get`          | `ResourceLoader.load(scene_path) → PackedScene` then inspect `_bundled` (avoid) or `instantiate()` and inspect tree once.              | Avoid heavy `instantiate()` for read-only metadata — use `PackedScene.get_state()` (returns `SceneState`) instead, then `SceneState.get_node_count()`, `get_node_name(i)`, `get_node_type(i)`. |
| `scene.open`         | `EditorInterface.open_scene_from_path(path)`.                                                                                          | Editor-only.                                                                                                                                                                                   |
| `scene.close`        | `EditorInterface.reload_scene_from_path(path)` won't close; use scene tab manipulation via `EditorInterface.get_editor_main_screen()`. | v1 acceptable to mark as best-effort; document.                                                                                                                                                |
| `scene.save`         | `EditorInterface.save_scene()`.                                                                                                        | Returns error code; map to `scene.save_failed`.                                                                                                                                                |
| `scene.save_as`      | `EditorInterface.save_scene_as(path)`.                                                                                                 | Same.                                                                                                                                                                                          |
| `scene.create`       | Build node tree in memory, `PackedScene.pack(root)`, `ResourceSaver.save(packed, path)`.                                               | All children must have `owner` set to the root for packing to capture them.                                                                                                                    |
| `scene.delete`       | `EditorFileSystem.move_to_trash` or `DirAccess.remove`.                                                                                | Run dependency check first (`scene.validate` semantics).                                                                                                                                       |
| `scene.instantiate`  | `PackedScene.instantiate(PackedScene.GEN_EDIT_STATE_*)` then `parent.add_child(node)` + set owner.                                     | Use `GEN_EDIT_STATE_INSTANCE` in the editor; `GEN_EDIT_STATE_DISABLED` for runtime.                                                                                                            |
| `scene.pack`         | `PackedScene.pack(node)` and save via `ResourceSaver.save`.                                                                            | Tree must have a unique owner.                                                                                                                                                                 |
| `scene.get_tree`     | `SceneState.get_node_count` + drill OR `EditorInterface.get_edited_scene_root()` if in editor.                                         | Respect envelope rules (`09`).                                                                                                                                                                 |
| `scene.get_subtree`  | Walk from a `NodePath`.                                                                                                                | Same.                                                                                                                                                                                          |
| `scene.find_in_tree` | Custom traversal using `node.get_class()`, `node.is_in_group()`, name regex.                                                           | Stable ordering: depth-first pre-order.                                                                                                                                                        |
| `scene.validate`     | Walk tree; for each node check `script.is_valid()`, missing exported resources (`null` checks on Object properties).                   | Returns a list of issues + autoHeal suggestions.                                                                                                                                               |
| `scene.replace`      | Use `Node.replace_by(new_node, keep_groups)`.                                                                                          | Editor undo via `EditorPlugin.get_undo_redo()` recommended.                                                                                                                                    |

### A.2 `node.*` — implementation map

| Tool                         | Daemon-side APIs                                                                                                                                                                                                                                                       |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- | ----------------- | --------------------------------------- |
| `node.get`                   | `Object.get_property_list()` + `Object.get(name)` for each non-default property; group via `Node.get_groups()`; meta via `Object.get_meta_list()` + `get_meta(key)`; signals via `Object.get_signal_list()`.                                                           |
| `node.modify` (polymorphic)  | For `properties`: `Object.set(prop, value)` per key. For `groups.add/remove`: `Node.add_to_group/remove_from_group`. For `owner`: `Node.set_owner`. For `meta`: `Object.set_meta(key, value)`. Wrap in `EditorPlugin.get_undo_redo().add_do_property` for editor undo. |
| `node.add`                   | `ClassDB.instantiate(type)` → `parent.add_child(node, force_readable_name = true)` → `node.owner = scene_root`.                                                                                                                                                        |
| `node.remove`                | `node.queue_free()` (deferred); use `call_deferred("free")` when called from inside another node's `_process`.                                                                                                                                                         |
| `node.reparent`              | `Node.reparent(new_parent, keep_global_transform)`.                                                                                                                                                                                                                    |
| `node.duplicate`             | `Node.duplicate(flags)` with `DUPLICATE_GROUPS                                                                                                                                                                                                                         | DUPLICATE_SIGNALS | DUPLICATE_SCRIPTS | DUPLICATE_USE_INSTANTIATION` as needed. |
| `node.rename`                | `node.name = new_name`. Godot deduplicates names automatically (`Sprite@2`); the agent receives the final name.                                                                                                                                                        |
| `node.find`                  | `Node.find_child(pattern, recursive=true, owned=true)` and `Node.find_children(pattern, type, recursive, owned)`.                                                                                                                                                      |
| `node.get_path`              | `node.get_path()` returns absolute; relative variants via `get_path_to(other)`. Unique-name nodes return paths with `%UniqueName`.                                                                                                                                     |
| `node.set_owner`             | `node.owner = ...` — **required** for `PackedScene.pack` to capture the node.                                                                                                                                                                                          |
| `node.get_children`          | `node.get_children()`.                                                                                                                                                                                                                                                 |
| `node.get_parent`            | `node.get_parent()`.                                                                                                                                                                                                                                                   |
| `node.get_signals`           | `Object.get_signal_list()` + `Object.get_signal_connection_list(signal_name)` for each.                                                                                                                                                                                |
| `node.get_methods`           | `Object.get_method_list()`.                                                                                                                                                                                                                                            |
| `node.get_properties_schema` | `Object.get_property_list()` + `PROPERTY_HINT_*` normalization (`06 §A.4`).                                                                                                                                                                                            |
| `node.walk`                  | DFS pre-order; respect envelope rules.                                                                                                                                                                                                                                 |
| `node.query`                 | XPath-flavored: parse predicates into `Node.find_children` calls or custom walker.                                                                                                                                                                                     |
| `node.set_visibility`        | `Node2D.visible` / `Node3D.visible` / `CanvasItem.visible`.                                                                                                                                                                                                            |
| `node.evaluate_in_node`      | `Expression` class (`Expression.parse(text, input_names)` + `Expression.execute(inputs, base_instance)`). Gated by `--allow-eval`.                                                                                                                                     |
| `node.observe`               | Connect to `Object.property_list_changed` and per-property hooks via `Object.notification(NOTIFICATION_*)`.                                                                                                                                                            |

### A.3 `script.*` — implementation map

| Tool                               | APIs                                                                                                                                                                              |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `script.attach`                    | `Node.set_script(load(path))`. To create on the fly: `GDScript.new()` + `source_code = "..."` + `reload()`.                                                                       |
| `script.detach`                    | `node.set_script(null)`.                                                                                                                                                          |
| `script.get`                       | `node.get_script()` → `Script` resource; read `source_code` for `.gd`. For `.cs` use `EditorInterface.get_script_editor()` to fetch text.                                         |
| `script.set`                       | Update `script.source_code` then `script.reload()`. Editor refresh via `EditorInterface.reload_scene_from_path` if needed.                                                        |
| `script.validate`                  | Headless `--check-only --script <path>`. Capture stderr → parse error lines (line/column).                                                                                        |
| `script.refactor_rename`           | Use `EditorInterface.get_script_editor()`'s find/replace plus `Script.has_method/get_method_list`; for safety perform across `EditorFileSystem`.                                  |
| `script.refactor_extract_method`   | Heavy lift; v1 may stub it.                                                                                                                                                       |
| `script.search` / `script.replace` | Walk `EditorFileSystem` for `.gd`/`.cs`; case-sensitive by default.                                                                                                               |
| `script.list_classes_in_project`   | Iterate `ProjectSettings.global_class_list` or use `ScriptServer.get_global_class_list()` (since Godot 4).                                                                        |
| `script.document`                  | Parse `##` doc comments per `gdscript_documentation_comments.rst`; regenerate via `class_GDScriptDocCommentTokenizer` (best-effort).                                              |
| `script.format`                    | Use Godot's built-in GDScript formatter (`gdscript-toolkit`/`gdformat` if installed locally) **or** invoke the editor's format-on-save via `EditorInterface.get_script_editor()`. |
| `script.compile_all`               | Headless: iterate `.gd` files, `--check-only --script <path>` each; for `.cs` use `--build-solutions --quit` once.                                                                |
| `script.get_errors`                | Cached result from last `script.compile_all`.                                                                                                                                     |

GDScript style enforced per `tutorials/scripting/gdscript/gdscript_styleguide.rst`.

### A.4 `signal.*` — implementation map

Per `class_Object`:

- `signal.list` → `Object.get_signal_list()`.
- `signal.connect` → `Object.connect(signal_name, callable, flags)`. Flags include
  `CONNECT_DEFERRED`, `CONNECT_PERSIST`, `CONNECT_ONE_SHOT`, `CONNECT_REFERENCE_COUNTED`.
- `signal.disconnect` → `Object.disconnect(signal_name, callable)`.
- `signal.emit` → `Object.emit_signal(signal_name, ...args)`.
- `signal.list_callbacks` → `Object.get_signal_connection_list(signal_name)`.
- `signal.validate_connection` → check method exists via `Object.has_method`.
- `signal.list_emitters_of` / `signal.list_listeners_of` → walk scene, cross-reference connection
  lists.
- `signal.suppress` and `signal.replay` — managed via Terravolt's own in-memory shim (record
  connections, route through proxy).

### A.5 `resource.*` — implementation map

Per `resources.rst`:

- `resource.load` → `ResourceLoader.load(path, type_hint, cache_mode)`.
- `resource.save` → `ResourceSaver.save(resource, path, flags)`. Flags: `FLAG_RELATIVE_PATHS`,
  `FLAG_BUNDLE_RESOURCES`, etc.
- `resource.list` → walk `EditorFileSystem`.
- `resource.find_by_uid` → `ResourceUID.id_to_text(id)` / `ResourceUID.get_id_path(id)`.
- `resource.create` → instantiate via `ClassDB.instantiate(type)` (only if
  `ClassDB.is_class_resource(type)`); set properties; save.
- `resource.modify` → `Object.set(prop, value)` then save.
- `resource.duplicate` → `Resource.duplicate(subresources: bool)`.
- `resource.convert` → type-specific; example: `AudioStreamMP3` ↔ `AudioStreamOggVorbis` via
  re-import.
- `resource.delete` → `EditorFileSystem.move_to_trash(path)` (recommended) or `DirAccess.remove`.
- `resource.move` → `EditorFileSystem.rename` so refs update.
- `resource.get_dependencies` → `EditorFileSystem.get_filesystem_path(path).get_file_deps(...)` or
  `ResourceLoader.get_dependencies(path)`.
- `resource.get_dependents` → walk reverse-index via `EditorFileSystem`.
- `resource.validate` → `ResourceLoader.exists` + load + type check.
- `resource.snapshot` → `Resource.duplicate(true)` held in an in-memory ring.

### A.6 `asset.*` — implementation map

Per `tutorials/assets_pipeline/*`:

- `asset.import` → `EditorFileSystem.update_file(path)` and editor's importer registry.
- `asset.reimport` → `EditorFileSystem.reimport_files([paths])`.
- `asset.set_preset` → edit the `.import` metadata file alongside the asset.
- `asset.batch_apply_preset` → walk directory + edit `.import` files in bulk.
- `asset.validate` → check importer error reports via the `EditorImportPlugin` registry.
- `asset.find_dups` → hash files; compare.
- `asset.audit` / `asset.optimize` → custom; rely on `Image` API for textures and `AudioStream` API
  for audio.

### A.7 `runtime.*` — implementation map

Per `scene_tree.rst`, `class_Engine`, `class_Performance`, `class_Input`:

- `runtime.play` → editor: `EditorInterface.play_main_scene()` or `play_current_scene()` or
  `play_custom_scene(path)`. Headless: spawn subprocess (per `07`).
- `runtime.stop` → `EditorInterface.stop_playing_scene()`.
- `runtime.pause` → set `SceneTree.paused = true`.
- `runtime.resume` → `SceneTree.paused = false`.
- `runtime.step` → not directly supported; emulate with breakpoint + single-step via
  `EngineDebugger` when attached.
- `runtime.get_tree` → over the remote debugger channel (editor) or via the daemon's in-process tree
  (headless).
- `runtime.get_node` / `runtime.set_node` → same; for editor, use the `EditorDebuggerPlugin` API.
- `runtime.simulate_input` → `Input.action_press(name)` / `Input.action_release(name)`; for raw
  input use `Input.parse_input_event(InputEvent)`.
- `runtime.get_performance` → `Performance.get_monitor(Performance.TIME_FPS)` and similar enums
  (`TIME_PROCESS`, `MEMORY_STATIC`, `RENDER_TOTAL_OBJECTS_IN_FRAME`, …).
- `runtime.set_breakpoint` / `clear_breakpoint` / `list_breakpoints` →
  `EngineDebugger.send_message("breakpoint:set/clear/list", [...])` or via the editor's debugger
  panel API.
- `runtime.profile_snapshot` → `EngineDebugger.profiling_start/stop` (categories: `script`,
  `physics_3d`, `physics_2d`, `gpu`).
- `runtime.replay` → Terravolt's own input recorder; uses `Input.parse_input_event` to replay.

### A.8 `editor.*` — implementation map

Per `class_EditorInterface`:

- `editor.open_scene` → `EditorInterface.open_scene_from_path(path)`.
- `editor.open_script` → `EditorInterface.edit_script(script, line, col, grab_focus)`.
- `editor.focus_node` → `EditorInterface.get_selection().clear()` then `add_node(node)`.
- `editor.select_nodes` → multi-add to `EditorSelection`.
- `editor.get_selection` → `EditorInterface.get_selection().get_selected_nodes()`.
- `editor.run_undo` / `run_redo` → `EditorInterface.get_editor_undo_redo()` → `undo()` / `redo()`
  (single global stack).
- `editor.save_all` → `EditorInterface.save_all_scenes()`.
- `editor.request_user_confirm` → `EditorInterface.popup_dialog_centered(...)` with a confirmation
  dialog scene; capture the user's choice via signal.
- `editor.show_status_message` → `EditorInterface.get_base_control().get_node("StatusBar")` is
  internal; use `print()` to Output panel (it's prefixed if `@tool`) plus dock's "Last log line".
- `editor.list_open_tabs` → `EditorInterface.get_open_scenes()` and script-editor open tabs via
  `get_script_editor().get_open_scripts()`.
- `editor.close_tab` → script editor: `get_script_editor()._close_tab` is private; use signals or
  fall back to "no API in v1, documented".

### A.9 `project.*` — implementation map

Per `class_ProjectSettings`:

- `project.get_settings` → `ProjectSettings.get_setting(name, default)` (per key) or iterate
  `ProjectSettings.get_property_list()`.
- `project.set_settings` → `ProjectSettings.set_setting(name, value)` + `ProjectSettings.save()` or
  `save_custom(path)`.
- `project.list_autoloads` → enumerate keys under `autoload/*`.
- `project.add_autoload` / `remove_autoload` → at runtime via `add_autoload_singleton` (editor-only)
  or by direct `ProjectSettings.set_setting("autoload/Name", "*res://...")`.
- `project.set_main_scene` → `ProjectSettings.set_setting("application/run/main_scene", path)` +
  save.
- `project.get_config_version` → `ProjectSettings.get_setting("application/config/features")` lists
  Godot version features (e.g., `["4.3", "Forward Plus"]`).
- `project.ensure_addons` → ensure `editor_plugins/enabled` includes Terravolt plugin.
- `project.list_features` → `OS.get_feature_list()` (custom features defined per export preset).
- `project.set_feature_flag` → custom features live in export presets, not ProjectSettings; the tool
  must edit `export_presets.cfg` and surface the limitation in `09`'s autoHeal.

### A.10 `input.*` — implementation map

Per `class_InputMap`, `class_InputEvent*`, and `tutorials/inputs/inputevent.rst`:

- `input.list_actions` → `InputMap.get_actions()` + per-action `InputMap.action_get_events(name)`.
- `input.add_action` / `remove_action` → `InputMap.add_action(name, deadzone)` /
  `erase_action(name)`. Also write to `ProjectSettings.set_setting("input/<name>", {...})` for
  persistence.
- `input.bind_key` → instantiate `InputEventKey` with `keycode`/`physical_keycode`;
  `InputMap.action_add_event(name, event)`.
- `input.bind_joystick` → `InputEventJoypadButton` or `InputEventJoypadMotion`.
- `input.simulate_action` → `Input.action_press` / `Input.action_release`.
- `input.query_action_state` → `Input.is_action_pressed` / `is_action_just_pressed` /
  `is_action_just_released` / `get_action_strength`.
- `input.validate_map` → look for duplicate bindings, missing actions referenced by scripts.

### A.11 `animation.*` — implementation map

Per `tutorials/animation/*` and `class_AnimationPlayer` / `class_AnimationTree`:

- `animation.create_player` → instantiate `AnimationPlayer` / `AnimationTree` (Godot 4: prefer
  `AnimationMixer` as the base when targeting features common to both).
- `animation.list_animations` → `AnimationPlayer.get_animation_list()` or
  `AnimationLibrary.get_animation_list()`.
- `animation.create_animation` → `Animation.new()`, set `length`, `loop_mode`, then
  `AnimationLibrary.add_animation(name, anim)`.
- `animation.edit_track` → `Animation.add_track(track_type)` returning index;
  `Animation.track_insert_key(idx, time, value)`. Track types per `animation_track_types.rst`
  (`TYPE_VALUE`, `TYPE_POSITION_3D`, `TYPE_ROTATION_3D`, `TYPE_SCALE_3D`, `TYPE_BLEND_SHAPE`,
  `TYPE_METHOD`, `TYPE_BEZIER`, `TYPE_AUDIO`, `TYPE_ANIMATION`).
- `animation.scrub` → `AnimationPlayer.seek(time, update=true)`.
- `animation.blend` / `animation.list_blend_trees` / `animation.edit_blend_tree` → use
  `AnimationTree.tree_root` set to `AnimationNodeBlendTree`/`AnimationNodeStateMachine`.
- `animation.snapshot_pose` → walk skeleton, capture `Skeleton3D.get_bone_pose(i)`.
- `animation.retarget` → use `SkeletonProfile` + `BoneMap` resources.

### A.12 `physics.*` — implementation map

Per `tutorials/physics/*`, `class_PhysicsServer2D` / `3D`, `class_World3D`:

- `physics.set_gravity` → `ProjectSettings.set_setting("physics/<2d|3d>/default_gravity", value)`.
- `physics.set_layer_names` →
  `ProjectSettings.set_setting("layer_names/<2d|3d>_physics/layer_<n>", name)`.
- `physics.configure_collision_pairs` → set masks/layers on body resources.
- `physics.attach_collision_shape` → `CollisionShape2D/3D.shape = <Shape resource>`.
- `physics.query_overlapping` → `PhysicsDirectSpaceState3D.intersect_shape(parameters)`.
- `physics.query_raycast` → `PhysicsDirectSpaceState3D.intersect_ray({from, to, ...})`.
- `physics.simulate_step` → `PhysicsServer3D.flush_queries()` after manual movement; full step
  generally driven by the engine main loop.
- `physics.configure_world` → set `World3D.environment`, `direct_space_state`, etc.
- `physics.list_physics_servers` → list 2D and 3D servers' status.

### A.13 `render.*` — implementation map

Per `tutorials/rendering/*` and `class_RenderingServer` / `class_WorldEnvironment`:

- `render.set_environment` → assign a `WorldEnvironment` node with an `Environment` resource.
- `render.set_camera` → `Camera3D` properties (`fov`, `near`, `far`, `position`).
- `render.configure_lights` → instantiate `DirectionalLight3D`, `OmniLight3D`, `SpotLight3D`.
- `render.set_postprocess` → `Environment.glow_enabled`, `ssr_enabled`, `tonemap_mode`.
- `render.set_renderer_mode` →
  `ProjectSettings.set_setting("rendering/renderer/rendering_method", "forward_plus|mobile|gl_compatibility")`.
- `render.capture_screenshot` → `Viewport.get_texture().get_image().save_png(path)`.
- `render.get_renderer_info` → `OS.get_video_adapter_driver_info()`,
  `RenderingServer.get_video_adapter_*`.
- `render.list_shaders` → walk `.gdshader` files.
- `render.compile_shader` → `Shader.code = "..."`; check for errors via
  `Shader.get_default_texture_parameter` etc.

### A.14 `audio.*` — implementation map

Per `tutorials/audio/*`, `class_AudioServer`:

- `audio.list_buses` → `AudioServer.bus_count`, `AudioServer.get_bus_name(idx)`, effects via
  `get_bus_effect_count`/`get_bus_effect(idx, i)`.
- `audio.add_bus` → `AudioServer.add_bus(at_position)`.
- `audio.set_bus_volume` → `AudioServer.set_bus_volume_db(idx, db)`.
- `audio.route` → `AudioServer.set_bus_send(idx, name)`.
- `audio.import_audio` → `EditorFileSystem` import pipeline; bus suggestion is heuristic.
- `audio.play_test_sound` → instantiate `AudioStreamPlayer` with a packaged test stream.
- `audio.set_master_volume` → bus 0.
- `audio.configure_3d_audio` → `AudioStreamPlayer3D` properties.

### A.15 `network.*` — implementation map

Per `tutorials/networking/high_level_multiplayer.rst` and `class_MultiplayerAPI`:

- `network.list_peers` → `MultiplayerAPI.get_peers()` and `get_unique_id()`.
- `network.configure_multiplayer` → assign a `MultiplayerPeer` (`ENetMultiplayerPeer`,
  `WebSocketMultiplayerPeer`, `WebRTCMultiplayerPeer`).
- `network.host` / `join` → `peer.create_server(port, max_clients)` /
  `create_client(address, port)`.
- `network.list_rpcs` → walk scripts for `@rpc` annotated methods (GDScript) / `[Rpc]` attributes
  (C#).
- `network.register_rpc` → emits script edit.
- `network.set_compression` → `ENetMultiplayerPeer.compression_mode`.
- `network.test_connection` → send/receive an RPC echo.

### A.16 `debug.*` — implementation map

Per `tutorials/scripting/debug/overview_of_debugging_tools.rst` and `class_EngineDebugger` /
`class_EditorDebuggerPlugin`:

- `debug.break` / `debug.continue` / `debug.step` → routed through the editor's debugger panel via
  `EngineDebugger.send_message`.
- `debug.get_stack` / `get_locals` / `set_local` → `EditorDebuggerPlugin._capture` / `_breaked`
  callbacks.
- `debug.watch_expression` → editor debugger supports watches via the panel; expose by intercepting
  the panel's add-watch.
- `debug.attach` / `detach` → editor handles this via the play workflow; expose as flags.

### A.17 `profile.*` — implementation map

Per `tutorials/scripting/debug/the_profiler.rst` and
`tutorials/scripting/debug/custom_performance_monitors.rst`:

- `profile.start_capture` / `stop_capture` → `EngineDebugger.profiling_start("script", [params])` /
  `profiling_stop`.
- `profile.get_fps` → `Performance.get_monitor(Performance.TIME_FPS)`.
- `profile.get_draw_calls` →
  `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)`.
- `profile.get_memory` → `Performance.get_monitor(Performance.MEMORY_STATIC)` and
  `MEMORY_STATIC_MAX`.
- `profile.get_physics_metrics` → `Performance.PHYSICS_2D_ACTIVE_OBJECTS` /
  `PHYSICS_3D_ACTIVE_OBJECTS` / `PHYSICS_*_COLLISION_PAIRS`.
- `profile.list_hot_functions` → reads `EngineDebugger.profiling_get_data` (script profiler output).
- `profile.export_report` → write JSON via `--benchmark-file` (headless) or manual write of
  collected samples.
- **Custom monitors**: Terravolt itself registers monitors for its own health (e.g.,
  `terravolt/wsd/inbound_qps`, `terravolt/dispatcher/p95_ms`) via
  `Performance.add_custom_monitor(name, callable)` — visible in **Debugger → Monitors**.

### A.18 `macro.*` — implementation guidance

Macros compose primitives. Per best-practices docs:

- **Scenes vs scripts** (`scenes_versus_scripts.rst`): macros prefer creating reusable `.tscn` files
  over giant scripts.
- **Scene organization** (`scene_organization.rst`): nested scenes are first-class; macros honor a
  maximum depth (default 4) and unique-name (`%`) marks for cross-cutting nodes.
- **Autoloads vs nodes** (`autoloads_versus_regular_nodes.rst`): macros default to non-autoload
  nodes; only `scaffold_save_system` and `scaffold_dialogue` register autoloads.
- **Logic preferences**: macros generate signal-driven code rather than polling.
- **State machine**: `scaffold_state_machine` generates either an `AnimationTree` +
  `AnimationNodeStateMachine` (preferred for character control) or a plain GDScript node-based FSM.

### A.19 New error codes pinned to engine specifics

| Code     | Symbol                                 | Trigger                                                                                                      |
| -------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `-33523` | `node.expression_failed`               | `node.evaluate_in_node`: `Expression.parse` or `Expression.execute` raised.                                  |
| `-33532` | `script.uses_inner_class_for_resource` | `resource.create` rejected because the script defines an inner-class resource (per `resources.rst` warning). |
| `-33611` | `animation.unsupported_track_type`     | Track type not valid for the targeted node (e.g., 3D track on a 2D node).                                    |
| `-33651` | `network.no_multiplayer_peer`          | Multiplayer ops with no peer assigned.                                                                       |
| `-33682` | `macro.recipe_missing_dependency`      | A macro requires an addon or class that isn't available.                                                     |

Mirrored in `packages/shared/errors/registry.json`.

### A.20 Risks added

| Risk                                                                  | Mitigation                                                                                        |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Heavy use of `instantiate()` for scene introspection thrashes memory. | Use `PackedScene.get_state()` for read-only metadata.                                             |
| `Node.queue_free()` from synchronous handler ⇒ engine instability.    | Always `call_deferred("free")` or `queue_free()` (which already defers).                          |
| `EditorInterface` methods that are private in some Godot minors.      | Document version-tested calls; mark such tools `since: <godot-minor>` in the registry.            |
| `Animation` track index drift on save/load.                           | Refer tracks by `(track_path, track_type)` instead of index where possible.                       |
| Resource UID collisions on duplicate.                                 | Use `ResourceSaver.save(..., FLAG_REPLACE_SUBRESOURCE_PATHS)` carefully; let Godot reassign UIDs. |
