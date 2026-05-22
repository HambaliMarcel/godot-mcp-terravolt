# 17 — Catalog: `runtime.*` (Phase 3 work-unit #7)

> `runtime.*` is the **playmode** category — the agent can start the game, inspect a live scene
> tree, evaluate expressions against running objects, drive UI clicks, record/replay inputs, drive
> navigation. This is what enables true "vibe testing": the agent presses Play, observes, adjusts,
> and presses Stop.

---

## 17.1 Header

- **File:** `17-catalog-runtime.md`
- **Purpose:** ship `runtime.*` (19 tools).
- **Catalog bump:** `0.8.0` → **`0.9.0`** on land.

## 17.2 Phase placement

Phase 3, work-unit #7. Prerequisite: `16` shipped.

## 17.3 Inputs / prerequisites

- New handler `handlers/runtime.gd`.
- Daemon-side **runtime bridge** autoload (`packages/godot-mcp-addon/autoloads/runtime_bridge.gd`) —
  installed via `EditorPlugin.add_autoload_singleton` when the addon is enabled. The bridge runs
  **in the game process** (not the editor), listens on a sibling WebSocket port `6506`
  (configurable: `terravolt_mcp/runtime/port`), and forwards inspection/mutation requests there.
- Daemon-side `editor → runtime` router proxies `runtime.*` calls onto the game process when one is
  alive.
- Headless support uses `runtime.start_headless { scene }` to launch the same project under
  `godot --headless` with the bridge autoload still active.

## 17.4 Outputs

- 19 tools live, registered, validated, documented.
- New fixture: `tests/_fixtures/minimal_game/` with a small Godot project that includes the runtime
  bridge so end-to-end runtime tests pass.
- `docs/catalog/runtime.md` regenerated.

## 17.5 Operating constants used

- `runtime_inspection_throttle_hz = 30` — protects the game frame budget.
- `runtime_recording_buffer_capacity = 10_000` input events.
- `runtime_navigate_default_speed = 200` (px/s in 2D, m/s in 3D — separate constants by dimension).

---

## 17.6 `runtime.*` — 19 tools

> **Lifecycle.** Most runtime tools require an active game session — either via `runtime.play`
> (editor playmode) or `runtime.start_headless` (subprocess). They return `runtime.no_session`
> (`-33C00`) otherwise with an autoHeal to start one.

### `runtime.play`

- **Purpose:** start the game in the editor (Play scene, Play current, or Play project).
- **Inputs:** `{ mode?: "project"|"current_scene"|"specific", scene?: ScenePath, args?: [string] }`.
- **Outputs:** `{ playing: true, pid: int, started_at: iso, bridge_port: int, mode }`.
- **Godot APIs:** `EditorInterface.play_main_scene()` / `play_current_scene()` /
  `play_custom_scene(path)`.
- **Editor:** ✅. **Headless:** ❌ (use `start_headless`).
- **safe:** false. **mutates:** true (process start).
- **Cursor prompt:** _"Play the current scene."_

### `runtime.stop`

- **Purpose:** stop the running game.
- **Inputs:** `{ force?: bool (default false) }`.
- **Outputs:** `{ stopped: true, was_pid: int }`.
- **Godot APIs:** `EditorInterface.stop_playing_scene()` first; `OS.kill(pid)` only if `force`.
- **Editor:** ✅. **Headless:** ✅ (kills subprocess).
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Stop the game."_

### `runtime.start_headless`

- **Purpose:** spawn the project headless with the runtime bridge.
- **Inputs:** `{ scene?: ScenePath, args?: [string], wait_handshake_ms?: int (default 5000) }`.
- **Outputs:** `{ started: true, pid, bridge_port, handshake_duration_ms }`.
- **Godot APIs:** spawn `godot --headless --path <project> --main-scene <scene>`; rely on the
  runtime bridge autoload to dial back.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Boot the project headless on Title.tscn."_

### `runtime.status`

- **Purpose:** check whether a runtime session is alive.
- **Inputs:** none.
- **Outputs:**
  `{ session: { alive: bool, pid?, bridge_port?, mode?: "editor"|"headless", uptime_ms? } }`.
- **Editor / Headless:** ✅.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Is the game running?"_

### `runtime.list_nodes`

- **Purpose:** scene tree envelope for the **running** game (mirror of `scene.get_tree` but live).
- **Inputs:** `{ envelope?: "summary"|"raw", max_depth?: int, root?: NodePath }`.
- **Outputs:** scene tree envelope.
- **Godot APIs:** runtime bridge walks `get_tree().root` and emits the envelope.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Show the live scene tree."_

### `runtime.inspect_node`

- **Purpose:** read a live node's properties.
- **Inputs:**
  `{ path: NodePath, properties?: "all"|[string], include_signals?: bool (default false) }`.
- **Outputs:** `{ path, type, properties: PropertyDict, groups: [string], signals?: [{ ... }] }`.
- **Godot APIs:** `Node.get_node(path).get_property_list()` etc.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"What's /root/Main/Player's velocity right now?"_

### `runtime.evaluate`

- **Purpose:** sandboxed expression evaluation against the live tree (mirror of
  `node.evaluate_expression`, but in the game process).
- **Inputs:** `{ path: NodePath, expression: string, inputs?: PropertyDict }`.
- **Outputs:** `{ value, type, error? }`.
- **Godot APIs:** runtime bridge owns the `Expression` evaluator; same deny-list as `12`.
- **safe:** true (sandboxed). **mutates:** false.
- **Cursor prompt:** _"Evaluate `velocity.length()` on /root/Main/Player."_

### `runtime.set_property`

- **Purpose:** set a property on a live node (for what-if testing).
- **Inputs:** `{ path: NodePath, key: string, value: any }`.
- **Outputs:** `{ set: true, path, key, before, after }`.
- **Godot APIs:** `Object.set(key, value)` in the game process.
- **safe:** false. **mutates:** true (game state).
- **Errors:** `node.property_unknown`, `node.value_type_mismatch`.
- **Cursor prompt:** _"Set /root/Main/Player.speed to 1000 right now."_

### `runtime.call_method`

- **Purpose:** call a method on a live node with arguments.
- **Inputs:** `{ path: NodePath, method: string, args?: any[] }`.
- **Outputs:** `{ called: true, return_value, took_ms }`.
- **Godot APIs:** `Object.callv(method, args)`.
- **safe:** false. **mutates:** depends on method.
- **Errors:** `node.method_unknown` (`-33C10`).
- **Cursor prompt:** _"Call /root/Main/Player.take_damage(20)."_

### `runtime.emit_signal`

- **Purpose:** emit a signal in the game.
- **Inputs:** `{ path: NodePath, signal: string, args?: any[] }`.
- **Outputs:** `{ emitted: true }`.
- **Godot APIs:** `Object.emit_signal(name, ...args)`.
- **safe:** false. **mutates:** true.
- **Errors:** `signal.unknown`.
- **Cursor prompt:** _"Emit Player.died with arg 'enemy:goblin'."_

### `runtime.send_input`

- **Purpose:** synthesize input events into the game (keyboard / mouse / action / gamepad).
- **Inputs:**
  `{ events: [{ type: "key"|"mouse_button"|"mouse_motion"|"action"|"joy_button"|"joy_axis", ...specific-fields }], delay_between_ms?: int (default 0) }`.
- **Outputs:** `{ sent: int }`.
- **Godot APIs:** build `InputEvent*` instances; `Input.parse_input_event(event)`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Press the W key for 200ms."_

### `runtime.simulate_sequence`

- **Purpose:** higher-level input macro (named sequence of actions with delays).
- **Inputs:**
  `{ sequence: [{ action: string, hold_ms?: int, then_release?: bool }], pace_ms?: int (default 16) }`.
- **Outputs:** `{ done: true, total_duration_ms }`.
- **Godot APIs:** delegate to `runtime.send_input`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Walk forward 1 second, jump, walk left for 500ms."_

### `runtime.click_ui`

- **Purpose:** click a UI button or interactable by NodePath or by text label.
- **Inputs:**
  `{ selector: { path?: NodePath, text?: string, role?: "Button"|"CheckBox"|"OptionButton"|... }, scroll_into_view?: bool (default true), wait_animation_ms?: int (default 250) }`.
- **Outputs:** `{ clicked: true, path }`.
- **Godot APIs:** find Control via text traversal; synthesize a click `InputEventMouseButton` at the
  control's global rect center.
- **safe:** false. **mutates:** true.
- **Errors:** `runtime.ui_not_found` (`-33C11`).
- **Cursor prompt:** _"Click the 'Start Game' button."_

### `runtime.navigate`

- **Purpose:** drive a navigation agent (or CharacterBody) toward a position.
- **Inputs:**
  `{ agent_path: NodePath, target: { vec2?: [x,y], vec3?: [x,y,z], node_path?: NodePath }, speed?: float, timeout_ms?: int (default 10000), arrival_radius?: float }`.
- **Outputs:** `{ arrived: bool, end_position, duration_ms, path_length }`.
- **Godot APIs:** `NavigationAgent2D/3D.set_target_position(target)`; tick `_physics_process` via
  short waits; or apply velocity directly for simple bodies.
- **safe:** false. **mutates:** true (game state).
- **Errors:** `runtime.navigate_timeout` (`-33C12`).
- **Cursor prompt:** _"Drive Player to /root/Main/PointB."_

### `runtime.record_inputs`

- **Purpose:** start/stop recording live inputs.
- **Inputs:** `{ action: "start"|"stop", buffer_id?: string }`.
- **Outputs:** `{ recording: bool, buffer_id, event_count: int }`.
- **Godot APIs:** runtime bridge subscribes to `Input` events via `_input` in an autoload node;
  stores events with timestamps.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Start recording inputs."_

### `runtime.replay_inputs`

- **Purpose:** replay a recorded input buffer.
- **Inputs:** `{ buffer_id: string, speed?: float (default 1.0), loop?: bool (default false) }`.
- **Outputs:** `{ replayed: true, duration_ms, event_count }`.
- **Godot APIs:** iterate buffer; for each, `Input.parse_input_event(event)` at the recorded `dt`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Replay buffer 'walkthrough-3'."_

### `runtime.log_tail`

- **Purpose:** tail the running game's print/log buffer.
- **Inputs:** `{ lines?: int, level?: "info"|"warn"|"error"|"all", since_ts?: iso }`.
- **Outputs:** `{ entries: [{ ts, level, source, message }], next_cursor }`.
- **Godot APIs:** runtime bridge captures via `Engine.print_handler` hook; ring buffer.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Tail the running game's last 100 lines."_

### `runtime.screenshot`

- **Purpose:** capture the live game viewport.
- **Inputs:** `{ size?: { w, h }, quality?: int }`.
- **Outputs:** `{ image_base64, mime: "image/png", width, height, bytes }`.
- **Godot APIs:** `get_viewport().get_texture().get_image().save_png_to_buffer()` inside the game
  process; bridge ships base64 back.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Screenshot the running game."_

### `runtime.set_engine_param`

- **Purpose:** mutate engine-wide runtime params (time scale, physics tick, vsync).
- **Inputs:**
  `{ params: { time_scale?: float, physics_ticks_per_second?: int, vsync?: "disabled"|"enabled"|"adaptive"|"mailbox", debug_collisions?: bool, debug_navigation?: bool } }`.
- **Outputs:** `{ applied: { key: { before, after } } }`.
- **Godot APIs:** `Engine.time_scale`, `Engine.physics_ticks_per_second`,
  `DisplayServer.window_set_vsync_mode`, `get_tree().debug_collisions_hint`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Slow the game to 0.25× and turn on collision debug."_

---

## 17.7 Schemes / data shapes added

- `InputEventLike` shape (used by `runtime.send_input`):
  `{ type, key?, action?, button_index?, position?, velocity?, pressed?, strength?, axis?, axis_value?, modifiers?: { ctrl, shift, alt, meta } }`.
- `RuntimeSession` shape: `{ alive, pid?, bridge_port?, mode, uptime_ms?, scene? }`.
- `RuntimeBuffer` shape for recordings:
  `{ buffer_id, started_at, ended_at?, events: [InputEventLike] }`.

## 17.8 Tech stack delta

- New addon autoload `runtime_bridge.gd` (game-process only) — installed via plugin enable.
- Daemon proxy adds `services/runtime_proxy.gd` to forward editor-side calls to the bridge port.

## 17.9 Acceptance criteria

- [ ] All 19 tools live; visible via `tools.list({category: "runtime"})`.
- [ ] `runtime.play` → `runtime.list_nodes` returns a non-empty tree within 1s.
- [ ] `runtime.send_input` parses every event kind without crashing in the headless fixture.
- [ ] `runtime.record_inputs` → `runtime.replay_inputs` reproduces a 5-second walkthrough fixture
      deterministically (same end position ± 1px).
- [ ] `runtime.no_session` autoHeal includes the exact next prompt to start a session.
- [ ] `runtime.navigate` arrives within `timeout_ms` on the `minimal_game` nav fixture.

## 17.10 Verification plan

1. **End-to-end:** `runtime.play` → `runtime.list_nodes` → `runtime.send_input { W,300ms }` →
   `runtime.inspect_node { /Player }` shows position delta.
2. **Headless E2E:** same but starting with `runtime.start_headless` (no display).
3. **UI click:** Title screen fixture, click "Start" by text → scene transition happens;
   `runtime.list_nodes` shows new root.
4. **Record/replay:** record manual session, replay, compare delta.
5. **Engine param:** set `time_scale=0.5`; observe `physics_process` callbacks via expression
   evaluation that the simulated time is half.

## 17.11 Risks & mitigations

| Risk                                                  | Mitigation                                                                                                                                                                               |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Game-process bridge crashes the game on send.         | Bridge autoload wraps every dispatch in `Engine.error_logged` handler; if it fails to bind the port, the game continues without it and the editor surfaces `runtime.bridge_unavailable`. |
| Inputs synthesize during a game-paused state.         | Pre-flight check `get_tree().paused`; surface a warning entry; allow forced send via `force: true`.                                                                                      |
| Live property writes corrupt game state and crash.    | Same allow-list as `node.modify` writes; user opt-in via `confirm_high_risk: true` for engine-internal types.                                                                            |
| Recording buffer overflows for long sessions.         | Capacity capped at `runtime_recording_buffer_capacity`; switch to disk-backed storage at `user://terravolt/runtime_buffers/<id>.bin`.                                                    |
| Navigation tools deadlock if the agent never arrives. | Hard timeout returns `runtime.navigate_timeout`; output includes the closest reached position for debugging.                                                                             |

## 17.12 Handoff checklist to file `18`

- [ ] Catalog version `0.9.0` pushed.
- [ ] 121 tools total live.
- [ ] Game-process runtime bridge documented at `docs/architecture/runtime-bridge.md`.
- [ ] Open `18-catalog-animation-and-animation-tree.md`.

## 17.13 Commit template

```text
feat(catalog): ship runtime.* (19 tools) — Phase 3 work-unit #7

- Adds game-process runtime bridge autoload (port 6506)
- play/stop, inspect, mutate, evaluate, send_input, click_ui, navigate
- Input record/replay with disk overflow buffer
- Engine param control (time_scale, physics ticks, debug flags)
- Bumps catalog_version 0.8.0 -> 0.9.0

Refs: docs/tasklist/17-catalog-runtime.md
```
