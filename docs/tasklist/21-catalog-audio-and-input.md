# 21 — Catalog: `audio.*` + `input.*` (Phase 3 work-unit #11)

> `audio.*` covers `AudioServer` bus layout, `AudioStreamPlayer*` nodes, bus effects, and previewing
> samples. `input.*` covers `InputMap` actions, key/event bindings, and the high-level "create /
> rename / delete action + simulate" workflow that a vibe-coder needs to wire up controls.

---

## 21.1 Header

- **File:** `21-catalog-audio-and-input.md`
- **Purpose:** ship `audio.*` (6) + `input.*` (7) — 13 total.
- **Catalog bump:** `0.12.0` → **`0.13.0`** on land.

## 21.2 Phase placement

Phase 3, work-unit #11. Prerequisite: `20` shipped.

## 21.3 Inputs / prerequisites

- New handlers: `handlers/audio.gd`, `handlers/input.gd`.
- Router modules: `src/tools/audio/`, `src/tools/input/`.
- `audio.*` reads/writes the AudioServer state (buses, volumes, sends, effects) AND `*.tres`
  `AudioBusLayout` files.
- `input.*` reads/writes `ProjectSettings` `input/*` keys (`InputMap` is the live view).

## 21.4 Outputs

- 13 tools live, registered, validated, documented.
- New fixtures: `tests/_fixtures/audio_zoo/` (a project with 3 buses + reverb + compressor) and
  `tests/_fixtures/input_zoo/` (default-mapped + custom actions).
- `docs/catalog/audio.md`, `docs/catalog/input.md` regenerated.

## 21.5 Operating constants used

- `audio_preview_max_seconds = 10`.
- `input_action_name_max_len = 64`.

---

## 21.6 `audio.*` — 6 tools

### `audio.list_buses`

- **Purpose:** describe the bus layout.
- **Inputs:** none.
- **Outputs:**
  `{ buses: [{ index, name, volume_db, mute, solo, bypass_effects, send_to: string|null, effects: [{ index, kind, enabled, params }] }] }`.
- **Godot APIs:** `AudioServer.bus_count`, `bus_get_name`, `bus_get_volume_db`, `bus_is_mute`,
  `bus_get_send`, `bus_get_effect_count`, `bus_get_effect(bus_idx, effect_idx)`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"What's the current audio bus layout?"_

### `audio.add_bus`

- **Purpose:** add a bus.
- **Inputs:** `{ name: string, send_to?: string (default "Master"), index?: int (default last) }`.
- **Outputs:** `{ added: true, index, name, state, revision }`.
- **Godot APIs:** `AudioServer.add_bus(index)`, `set_bus_name(index, name)`,
  `set_bus_send(index, send_to)`.
- **safe:** false. **mutates:** true.
- **Errors:** `audio.bus_name_exists` (`-33H00`).
- **Cursor prompt:** _"Add an SFX bus that sends to Master."_

### `audio.remove_bus`

- **Purpose:** remove a bus.
- **Inputs:** `{ name?: string, index?: int, reassign_sends_to?: string (default "Master") }`.
- **Outputs:** `{ removed: true, name, index, reassigned_count: int }`.
- **Godot APIs:** locate index by name; reassign every bus pointing here;
  `AudioServer.remove_bus(index)`.
- **safe:** false. **mutates:** true.
- **Errors:** `audio.bus_unknown` (`-33H01`), `audio.cannot_remove_master` (`-33H02`).
- **Cursor prompt:** _"Remove the SFX bus and reassign its dependents to Master."_

### `audio.set_bus`

- **Purpose:** patch bus properties (volume, mute, solo, send, bypass).
- **Inputs:** `{ bus: string|int, patch: { volume_db?, mute?, solo?, bypass_effects?, send_to? } }`.
- **Outputs:** `{ updated: true, applied: { key: { before, after } } }`.
- **Godot APIs:** `AudioServer.set_bus_*` per key.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Lower SFX volume to -6 dB and unmute Music."_

### `audio.add_effect`

- **Purpose:** add an effect to a bus.
- **Inputs:**
  `{ bus: string|int, kind: "Reverb"|"Delay"|"Compressor"|"Chorus"|"Limiter"|"EQ6"|"EQ10"|"EQ21"|"Distortion"|"PitchShift"|"Phaser"|"PanRecorder"|..., params?: PropertyDict, position?: int }`.
- **Outputs:** `{ added: true, bus, effect_index, kind, state, revision }`.
- **Godot APIs:** `AudioEffect{Reverb,Delay,...}.new()`; `set/get` params;
  `AudioServer.add_bus_effect(bus, effect, at_position)`.
- **safe:** false. **mutates:** true.
- **Errors:** `audio.effect_kind_unknown` (`-33H03`).
- **Cursor prompt:** _"Add a reverb to the Music bus with room_size=0.8."_

### `audio.preview_play`

- **Purpose:** play a sample on a bus for preview (in editor or runtime).
- **Inputs:**
  `{ stream_path: ResourcePath, bus?: string (default "Master"), volume_db?: float, pitch_scale?: float (default 1.0), duration_s?: float (max `audio_preview_max_seconds`) }`.
- **Outputs:** `{ played: true, finished_at: iso, duration_played_s }`.
- **Godot APIs:** instantiate a transient `AudioStreamPlayer`, set `stream/bus/volume_db`, `play()`,
  monitor `finished` signal; auto-free on completion. In headless mode, return
  `audio.no_output_device` autoHeal-friendly diagnostic.
- **safe:** false. **mutates:** false (transient node, autocleaned).
- **Errors:** `audio.preview_unavailable` (`-33H04`).
- **Cursor prompt:** _"Preview res://audio/jump.wav on the SFX bus."_

> **Bus layout persistence.** When the agent mutates buses in the editor, the daemon also writes the
> change to the project's `AudioBusLayout` resource at
> `ProjectSettings.get_setting("audio/buses/default_bus_layout")` so it survives restart.
> Runtime-only mutations don't persist.

---

## 21.7 `input.*` — 7 tools

### `input.list_actions`

- **Purpose:** enumerate `InputMap` actions and their events.
- **Inputs:** `{ include_builtin?: bool (default false) }`.
- **Outputs:**
  `{ actions: [{ name, deadzone, events: [{ kind: "key"|"mouse_button"|"joypad_button"|"joypad_motion", ...specific }] }] }`.
- **Godot APIs:** `InputMap.get_actions()`, `InputMap.action_get_events(name)`,
  `InputMap.action_get_deadzone(name)`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"List my custom input actions."_

### `input.add_action`

- **Purpose:** create an action with optional events.
- **Inputs:** `{ name: string, deadzone?: float (default 0.5), events?: InputEventLike[] }`.
- **Outputs:** `{ added: true, name, events: int }`.
- **Godot APIs:** `InputMap.add_action(name, deadzone)`; per event
  `InputMap.action_add_event(name, event)`. Persist via
  `ProjectSettings.set_setting("input/<name>", { deadzone, events: [...] })`.
- **safe:** false. **mutates:** true.
- **Errors:** `input.action_exists` (`-33I00`), `input.action_name_invalid` (`-33I01`).
- **Cursor prompt:** _"Add an action 'dash' bound to Shift."_

### `input.remove_action`

- **Purpose:** delete an action.
- **Inputs:** `{ name: string }`.
- **Outputs:** `{ removed: true, name }`.
- **Godot APIs:** `InputMap.erase_action(name)`; clear `ProjectSettings` key.
- **safe:** false. **mutates:** true.
- **Errors:** `input.action_unknown` (`-33I02`).
- **Cursor prompt:** _"Remove the dash action."_

### `input.set_action_events`

- **Purpose:** replace events for an action.
- **Inputs:** `{ name: string, events: InputEventLike[] }`.
- **Outputs:** `{ updated: true, name, before_count: int, after_count: int }`.
- **Godot APIs:** `InputMap.action_erase_events(name)`, then `action_add_event` per item.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Rebind 'jump' to [Space, A button on gamepad]."_

### `input.rename_action`

- **Purpose:** rename an action (and rewrite references in scripts / scenes).
- **Inputs:**
  `{ from: string, to: string, update_references?: bool (default true), dry_run?: bool }`.
- **Outputs:** `{ renamed: true, references_updated: [...], dry_run }`.
- **Godot APIs:** delete + recreate via `InputMap`; reference rewrite re-uses `script.find_usages`
  from `13`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Rename 'use_item' to 'interact' everywhere."_

### `input.simulate_action`

- **Purpose:** simulate an action press/release (shortcut over `runtime.send_input`).
- **Inputs:**
  `{ action: string, strength?: float (default 1.0), hold_ms?: int (default 50), then_release?: bool (default true) }`.
- **Outputs:** `{ simulated: true, action, duration_ms }`.
- **Godot APIs:** in runtime bridge: `Input.action_press(action, strength)` → wait `hold_ms` →
  `Input.action_release(action)`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Simulate pressing 'dash' for 100ms."_

### `input.describe_event`

- **Purpose:** describe a captured input event (useful when the agent wants to know what the user
  pressed).
- **Inputs:** `{ event: InputEventLike }`.
- **Outputs:** `{ display_string: string, normalized: InputEventLike, matched_actions: [string] }`.
- **Godot APIs:** `InputEventKey.as_text()`, etc.; cross-match with `InputMap.event_is_action`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"What is keycode 4194309?" (returns "Enter") and matched actions._

---

## 21.8 Schemes / data shapes added

- `BusInfo`, `EffectInfo` per `audio.list_buses` outputs.
- `InputEventLike` finalized at `packages/shared/schemas/common/InputEventLike.json` (extends `17`'s
  draft) with `keycode_or_physical_key`, `modifier_flags`, `pressed`, etc.
- `ActionInfo` shape per `input.list_actions.actions[]`.

## 21.9 Tech stack delta

- No new dependencies.
- Daemon adds `services/bus_layout_writer.gd` to persist bus changes to the `AudioBusLayout`
  resource.

## 21.10 Acceptance criteria

- [ ] All 13 tools live; visible via `tools.list`.
- [ ] `audio.add_bus` followed by `audio.list_buses` reflects the new bus (with `send_to`).
- [ ] `audio.preview_play` returns finished within `duration_s + 250ms` on a working device.
- [ ] `input.add_action` / `set_action_events` survives editor restart (persisted in
      `ProjectSettings`).
- [ ] `input.rename_action` with `update_references=true` rewrites all `is_action_pressed("from")`
      calls in `.gd`.

## 21.11 Verification plan

1. **Bus round-trip:** add SFX → add reverb → adjust volume → list → assert state.
2. **Layout persistence:** save & restart fixture; bus layout still present.
3. **Action round-trip:** add 'dash' → simulate → `runtime.evaluate`
   `Input.is_action_pressed("dash")` returns true mid-hold.
4. **Event describe:** synthesize a `Ctrl+Shift+K` event → display_string is "Ctrl+Shift+K".
5. **Rename references:** count usages before/after; old name absent, new name present.

## 21.12 Risks & mitigations

| Risk                                                            | Mitigation                                                                                                            |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Headless audio output unavailable.                              | `audio.preview_play` returns `audio.preview_unavailable` cleanly; document as expected in CI.                         |
| Bus layout writes race with editor's own writes.                | Wrap in `ProjectSettings.save()` and call `EditorFileSystem.scan()` after.                                            |
| Action rename rewrites strings inside comments/strings.         | Token-aware rename (consistent with `13`'s `script.rename_symbol`); allow `--scope=actions` quoted-literal-only mode. |
| Effect kind list grows across versions.                         | Maintain a per-version allow-list in `packages/shared/audio/effect_kinds.json`.                                       |
| Joypad event semantics (axis_value sign) differ across drivers. | `input.describe_event` returns a normalized field plus the raw values.                                                |

## 21.13 Handoff checklist to file `22`

- [ ] Catalog version `0.13.0` pushed.
- [ ] 177 tools total live.
- [ ] Bus layout persistence verified in a CI restart test.
- [ ] Open `22-catalog-3d-scene.md`.

## 21.14 Commit template

```text
feat(catalog): ship audio.* (6) and input.* (7) — Phase 3 work-unit #11

- Bus CRUD with effect chain editing
- Persistent AudioBusLayout updates
- InputMap CRUD with reference rewrite on rename
- Action simulation via runtime bridge
- Bumps catalog_version 0.12.0 -> 0.13.0

Refs: docs/tasklist/21-catalog-audio-and-input.md
```
