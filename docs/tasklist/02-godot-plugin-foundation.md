# 02 — Godot Plugin Foundation (Phase 1, part A)

> **Goal**: stand up the Godot EditorPlugin shell — `plugin.cfg`, the `EditorPlugin` entrypoint,
> addon lifecycle, dev mounting workflow, settings UI hooks, and the _scaffolding_ that file `03`
> (WebSocket server) and file `04` (JSON-RPC dispatcher + logging) will plug into. **No WebSocket
> code yet.** **No JSON-RPC code yet.** Only the addon shell, its lifecycle, and the integration
> seams.

---

## 2.1 Header

- **File:** `02-godot-plugin-foundation.md`
- **Purpose:** create the `packages/godot-mcp-addon/` plugin skeleton that the next two files
  extend.

## 2.2 Phase placement

- **Phase 1, part A.** Phase 1 is "Godot plugin foundation" in `docs/srs/execution_roadmap.md`. This
  file owns the addon shell. Files `03` and `04` own the WS daemon and the JSON-RPC + logging
  subsystems respectively.
- Gates Phase 2 _(only after `03` and `04` are also done)_.

## 2.3 Inputs / prerequisites

- `00` and `01` complete.
- Godot 4.x installed and on PATH.
- A throwaway Godot **dev project** outside this repo where the addon is mounted via symlink
  (preferred) or copy.
- Godot's **plugin docs** in `references/godot-docs/` available for offline lookup.

## 2.4 Outputs

When this file is done, the addon will:

1. Have a valid `plugin.cfg` recognized by Godot's plugin manager.
2. Have a primary `EditorPlugin` script that is enabled and disabled cleanly without errors.
3. Boot a _placeholder_ "MCP server lifecycle controller" that wires `_enter_tree`, `_exit_tree`,
   `_ready`, and an editor settings node — **but does not yet open a WebSocket port** (`03` does
   that).
4. Provide a _placeholder_ dispatch surface (`04` will give it the real JSON-RPC parser).
5. Provide a _placeholder_ logging surface (`04` will give it the real `user://mcp_log.txt` writer).
6. Expose a small **Editor dock or panel** (a single status row at minimum) so the developer can see
   addon state (idle / listening / connected / error) without poking the debugger.
7. Provide a **settings panel** entry (under `Project Settings → Plugins → TerraVolt MCP`) for any
   user-configurable knobs (heartbeat interval, port override later, log verbosity).
8. Provide **two npm scripts** at the repo root for development convenience: `addon:link` and
   `addon:unlink`.

The shell does **not** yet implement any actual MCP behavior. It is the chassis.

## 2.5 Operating constants used

- Port `6505` (used only as a default value rendered in the settings UI; the actual bind happens in
  `03`).
- Log path `user://mcp_log.txt` (used only as a default value rendered in the settings UI; actual
  writes happen in `04`).
- Heartbeat default `15s` (rendered in the settings UI as a configurable, used in `03`/`04`).

No new constants introduced.

---

## 2.6 Detailed task breakdown

### 2.6.1 Choose and lock the addon identity

1. **Plugin name:** `TerraVolt MCP` (display) / `terravolt_mcp` (machine).
2. **Plugin script path** (relative to the addon root): `main.gd` (entrypoint extending
   `EditorPlugin`).
3. **Plugin entry class:** `MainPlugin` (or similarly distinctive — recorded in the addon README).
4. **Plugin version:** start at `0.1.0`. Bumps are coordinated with the Node router release in `10`.
5. **Author:** TerraVolt / Marcel (project owner). Recorded once in `plugin.cfg`.

### 2.6.2 `plugin.cfg` plan

The file lives at `packages/godot-mcp-addon/plugin.cfg`. **Plan only — no actual file yet if
mounting requires a different on-disk path during dev; in that case create the file in the dev
project's `addons/` and confirm Godot's plugin manager recognizes it before committing.**

Fields, conceptually:

- Plugin display name.
- Description ("MCP bridge daemon for TerraVolt Godot MCP. Hosts a WebSocket on port 6505, logs to
  `user://mcp_log.txt`.").
- Author.
- Version.
- Script (relative path to `main.gd`).

### 2.6.3 EditorPlugin entrypoint (`main.gd`) — conceptual scope

> No code is written here. The file _describes_ what `main.gd` does once `02` finishes.

Responsibilities of `main.gd`:

1. Extend `EditorPlugin`.
2. On `_enter_tree`:
   - Instantiate the **logging facade** (placeholder for now; `04` swaps in the real one).
   - Instantiate the **dispatcher facade** (placeholder for now).
   - Instantiate the **MCP server controller** (placeholder; `03` swaps in the real WS server).
   - Register the addon's **dock or status panel** in the editor (lower-right dock or status bar —
     decision logged in §2.6.7).
   - Register the addon's **project settings** entries (see §2.6.6).
   - Emit a single line through the logging facade: "TerraVolt MCP addon entered tree."
3. On `_exit_tree`:
   - Tear down the MCP server controller cleanly (placeholder no-op for now; `03` adds the real
     `close()` path).
   - Unregister UI panels and project settings.
   - Emit a single log line: "TerraVolt MCP addon exited tree."
4. On `_ready` (or whichever Godot lifecycle hook fits best):
   - Honor the **"start on editor open" project setting** (default _enabled_). When enabled, kick
     off the MCP server controller's `start()` (placeholder for now).
5. Expose a single public method `restart()` that performs `stop() → start()` (placeholders for
   now). Useful when the user changes settings.

### 2.6.4 Placeholder facades

These are **types**, not features. They give later files clean seams.

| Facade       | Lives at                                 | Final owner |
| ------------ | ---------------------------------------- | ----------- |
| `MCPServer`  | `packages/godot-mcp-addon/mcp_server.gd` | File `03`   |
| `Dispatcher` | `packages/godot-mcp-addon/dispatcher.gd` | File `04`   |
| `Logger`     | `packages/godot-mcp-addon/logging.gd`    | File `04`   |

In this file the facades expose only the contracts they need (described below). Implementation
arrives in `03`/`04`.

**`MCPServer` contract (described, not coded):**

- `start()` — bind WS listen socket (`6505`) and begin accepting connections. In `02`, this is a
  no-op that logs "server.start() called (placeholder)."
- `stop()` — stop accepting, close existing peers, flush logs.
- `is_running() -> bool` — true if start() has been called and not yet stopped.
- `connection_state -> enum` — `idle`, `listening`, `client_connected`, `error`.
- Signals: `state_changed(new_state)`, `client_connected(peer_id)`,
  `client_disconnected(peer_id, reason)`.

**`Dispatcher` contract:**

- `dispatch(method: String, params: Dictionary) -> Dictionary` — returns a structured response
  (`{ok, result}` or `{ok, error}`). In `02`, returns a placeholder echoing the method name.
- `register(method: String, handler: Callable)` — registers a method handler. In `02`, the
  registration list contains only `ping`, `echo`, `server_info` (added in `04` for real;
  placeholders here).

**`Logger` contract:**

- `log_info(message: String, fields: Dictionary = {})` — append a structured line.
- `log_warn(...)`, `log_error(...)` — same shape.
- `set_verbosity(level)` — controls minimum level written.
- In `02`, the logger writes to `print()` in the editor output panel (so we can see addon lifecycle
  messages) but **not yet** to `user://mcp_log.txt`. `04` adds the file sink.

### 2.6.5 Addon enable/disable lifecycle

Verify that:

1. Enabling the addon in `Project Settings → Plugins` triggers `_enter_tree` with no errors.
2. Disabling the addon triggers `_exit_tree` cleanly with no leftover nodes, signals, or registered
   settings.
3. Toggling enable/disable repeatedly does not leak (use the editor's debugger panel to confirm).
4. Re-opening the dev project with the addon enabled loads it without prompting.

A short checklist captured in the addon README documents how to verify.

### 2.6.6 Project settings entries

Register the following under `Project Settings → General → Plugins → TerraVolt MCP` (or a dedicated
subgroup chosen here):

| Setting                                      | Type            | Default              | Purpose                                                                                 |
| -------------------------------------------- | --------------- | -------------------- | --------------------------------------------------------------------------------------- |
| `terravolt_mcp/server/port`                  | int             | `6505`               | WS listen port. Default _from `00 §0.3`_. Allow override but do not change the default. |
| `terravolt_mcp/server/bind_address`          | string          | `127.0.0.1`          | Listen address. Default loopback only.                                                  |
| `terravolt_mcp/server/auto_start_on_open`    | bool            | `true`               | If true, server starts when the editor opens.                                           |
| `terravolt_mcp/server/heartbeat_interval_ms` | int             | `15000`              | Heartbeat ping interval.                                                                |
| `terravolt_mcp/server/heartbeat_timeout_ms`  | int             | `45000`              | Heartbeat timeout.                                                                      |
| `terravolt_mcp/logging/path`                 | string          | `user://mcp_log.txt` | Log file path. Default per `00 §0.3`.                                                   |
| `terravolt_mcp/logging/level`                | enum            | `info`               | `debug` / `info` / `warn` / `error`.                                                    |
| `terravolt_mcp/logging/rotate_size_kb`       | int             | `5120`               | Rotate the log when it exceeds this size. Implementation in `04`.                       |
| `terravolt_mcp/security/require_token`       | bool            | `false`              | Reserve flag; token auth implemented in a later hardening pass.                         |
| `terravolt_mcp/security/token`               | string (secret) | `""`                 | Optional shared secret.                                                                 |
| `terravolt_mcp/context/max_tree_nodes`       | int             | `5000`               | Soft cap for raw scene tree responses; envelope kicks in beyond. Used by `09`.          |
| `terravolt_mcp/context/max_payload_kb`       | int             | `4096`               | Soft payload cap. Used by `09`.                                                         |

All settings should be wired so changing them via the editor UI either takes effect immediately
(preferred) or surfaces a "restart addon" hint (acceptable for port changes).

### 2.6.7 Editor UI surface (status panel)

Decide which surface is best:

- **Option A — Bottom-panel dock** (recommended): a single tab next to the Output / Debugger panels,
  labeled "TerraVolt MCP."
- **Option B — Editor toolbar button** that opens a popup with status.

Pick **A** for v1. The dock shows:

- **Status badge:** Idle / Listening / Client connected / Error.
- **Listen address:** e.g., `127.0.0.1:6505`.
- **Active connections:** count + last client identity hash.
- **Last log line.**
- **Buttons:** `Start`, `Stop`, `Restart`, `Open Log File`, `Copy Log Tail`.
- **Heartbeat indicator:** small "❤" pulse on each successful ping/pong.

Implementation in this file only stubs the dock with static text; live values arrive in `03`/`04`.

### 2.6.8 Dev workflow scripts

Implement two scripts at the repo root and reference them in §1.6.6:

1. **`addon:link`** — given the path to a Godot dev project (read from `~/.terravolt-mcp-dev.json`
   or an env var, e.g. `TERRAVOLT_GODOT_PROJECT`), create a symlink (or copy) from
   `packages/godot-mcp-addon/` to `<dev-project>/addons/terravolt_mcp/`.
2. **`addon:unlink`** — remove the symlink/copy.

Behavior:

- On Windows, prefer junction points if symlinks require admin; otherwise fall back to copy.
- Refuse to clobber an existing `addons/terravolt_mcp/` that contains modifications (compare
  timestamps; require `--force` to override).
- Print absolute paths involved.

### 2.6.9 Choose addon test framework

Pick **one** of: `GUT` or `gdUnit4`. Decision criteria:

- Active maintenance (commits within the last 12 months).
- Headless invocation support (we will run tests from CI in `10`).
- Easy assertion API.

Default recommendation: **GUT** unless `gdUnit4` shows clear advantages by impl time. Record the
choice in:

- The addon README.
- `00 §0.13` Decisions Log.

Install instructions for the chosen framework live in the addon README, not in this file. No actual
tests yet; the framework is set up so `10` can hit the ground running.

### 2.6.10 Addon README content (what to write now)

`packages/godot-mcp-addon/README.md` should now cover:

- Plugin name, version, Godot minimum version.
- Quick start: clone repo → run `npm run addon:link` → open Godot dev project → enable plugin.
- Settings reference (link to §2.6.6).
- Status dock screenshot placeholder (real screenshot added in `10`).
- Logging behavior summary (file sink lands in `04`).
- Pointer to `docs/tasklist/03` and `04` for further phases.

### 2.6.11 Manual smoke test (this phase)

Before declaring `02` complete, run:

1. Enable the addon in the dev project. Confirm no errors in the editor output panel.
2. Open the TerraVolt MCP dock. Confirm static labels render.
3. Change a project setting (e.g., flip `auto_start_on_open`). Confirm the setting persists across
   editor restarts.
4. Disable the addon. Confirm dock removes itself; no errors.
5. Re-enable. Confirm dock reappears.
6. Check the editor output panel for the lifecycle log lines from §2.6.3.

---

## 2.7 Schemes / data shapes (no code)

### 2.7.1 Addon directory shape (target after this file)

```text
packages/godot-mcp-addon/
  plugin.cfg                  (manifest — Godot recognizes plugin)
  main.gd                     (EditorPlugin entry — lifecycle, dock, settings)
  mcp_server.gd               (FACADE — real impl in 03)
  dispatcher.gd               (FACADE — real impl in 04)
  logging.gd                  (FACADE — real impl in 04)
  editor_ui/
    status_dock.tscn          (dock layout)
    status_dock.gd            (dock controller, static for now)
  README.md
```

`handlers/`, `schemas/`, etc., are added later by `04` and `08`.

### 2.7.2 State machine for `MCPServer` controller (preview, finalized in `03`)

```text
   ┌───────┐   start()   ┌───────────┐ client connects  ┌──────────────────┐
   │ idle  ├────────────▶│ listening ├─────────────────▶│ client_connected │
   └───┬───┘             └─────┬─────┘                  └─────────┬────────┘
       │                        │ stop()                          │ stop() / disconnect
       │                        ▼                                 ▼
       │                   ┌─────────┐                       ┌─────────┐
       └──────error()──────│  error  │◀──────error()─────────│  error  │
                           └─────────┘                       └─────────┘
```

States the dock surface in §2.6.7 must render verbatim.

### 2.7.3 Settings persistence contract

- Settings are stored in the dev project's `project.godot` via Godot's project settings API.
- The addon must not write its own config files; everything goes through project settings.
- On addon load, missing settings are initialized with the defaults from §2.6.6.

---

## 2.8 Tech stack delta vs `00 §0.10`

- Adds the addon test framework choice (GUT or gdUnit4) recorded in `00 §0.13`.
- Adds the dock UI as a `.tscn` + `.gd` pair (typed GDScript).
- No new runtime dependencies.

---

## 2.9 Acceptance criteria

- [ ] `plugin.cfg` validated by Godot's plugin manager (plugin appears in the list with correct
      metadata).
- [ ] `main.gd` enters and exits the tree cleanly on enable/disable cycles.
- [ ] Status dock renders with placeholder values; buttons exist (but only `Start`/`Stop`/`Restart`
      are visible; `Open Log File` may be hidden until `04` lands).
- [ ] All project settings from §2.6.6 are registered, persist, and surface in the editor.
- [ ] `addon:link` / `addon:unlink` work on the developer's machine.
- [ ] Addon README in `packages/godot-mcp-addon/` updated.
- [ ] Addon test framework chosen and recorded.
- [ ] Manual smoke test in §2.6.11 passes.
- [ ] No errors in editor output panel during enable/disable.
- [ ] Decisions Log (`00 §0.13`) updated with the chosen test framework and the file's completion
      timestamp.

---

## 2.10 Verification plan

1. Run `npm run addon:link` against a Godot dev project. Open the project.
2. Enable `TerraVolt MCP` plugin. Confirm dock appears, status badge shows `Idle` (or
   `Listening (placeholder)`).
3. Confirm log lines from `_enter_tree` show in the editor output.
4. Toggle `Project Settings → … → TerraVolt MCP → server/auto_start_on_open` off. Disable plugin.
   Re-enable. Confirm dock now shows `Idle`.
5. Change `server/port` to `6506` (non-default). Confirm the dock listen address updates (server
   doesn't actually bind yet, but the displayed value should reflect the setting).
6. Disable plugin. Confirm dock removed cleanly.
7. Run `npm run addon:unlink`. Confirm symlink/copy gone.

---

## 2.11 Risks & mitigations

| Risk                                                         | Mitigation                                                                                        |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| Editor crash on plugin enable due to malformed `plugin.cfg`. | Validate manifest fields against `references/godot-docs/`; test on a clean dev project.           |
| Symlink permissions on Windows.                              | Document junction fallback or copy fallback in the `addon:link` script.                           |
| Settings appear in the wrong place in the editor UI.         | Use a single namespace prefix (`terravolt_mcp/...`) so all settings group together.               |
| Dock causes editor UI clutter.                               | Keep dock minimal: status row + 3 buttons; advanced controls in a popup or in `Project Settings`. |
| Plugin name collision with other installed addons.           | Use `terravolt_mcp` machine name (unique).                                                        |
| GDScript version drift between Godot minors.                 | Pin minimum Godot version in `plugin.cfg` and the README.                                         |

---

## 2.12 Handoff checklist to file `03`

- [ ] `MCPServer` facade exists in `mcp_server.gd` with the public contract from §2.6.4.
- [ ] `start()` / `stop()` are no-ops that log placeholder messages.
- [ ] Status dock has the visual seams for live state updates.
- [ ] Project settings for port, bind address, heartbeat interval/timeout exist with defaults from
      `00 §0.3`.
- [ ] Dev workflow scripts work end-to-end.

When done, open **`03-godot-websocket-server.md`**.

---

## Appendix A — Official Godot Docs alignment (added revision 2)

> Sourced from `tutorials/plugins/editor/making_plugins.rst`, `tutorials/scripting/scene_tree.rst`,
> `tutorials/scripting/singletons_autoload.rst`, `tutorials/editor/command_line_tutorial.rst`, and
> `tutorials/io/data_paths.rst`. This appendix pins the addon shell to the engine's real plugin API.

### A.1 `plugin.cfg` canonical format (Godot 4 INI shape)

Per `making_plugins.rst`:

```text
[plugin]

name="TerraVolt MCP"
description="MCP bridge daemon for TerraVolt Godot MCP. Hosts a WebSocket on port 6505, logs to user://mcp_log.txt."
author="Marcel / TerraVolt"
version="0.1.0"
script="main.gd"
```

- Fields are `name`, `description`, `author`, `version`, `script`.
- `script` is **relative** to the plugin's directory (not `res://`-prefixed).
- For C# (.NET) entries the script path resolves to a `.cs` file _and_ the project must be built
  before the plugin can be enabled (`--build-solutions` from CLI).
- Recommended workflow: use the editor's **Project → Project Settings → Plugins → Create New
  Plugin** dialog to bootstrap the file with all defaults, then version it under
  `packages/godot-mcp-addon/`.

### A.2 `EditorPlugin` lifecycle (canonical)

Per `making_plugins.rst` and `class_EditorPlugin`:

- Entry script must be `@tool` and `extends EditorPlugin`.
- Lifecycle callbacks the addon must implement / honor:
  - `_enter_tree()` — initialization. Build the logger, dispatcher, MCP server controller; register
    the dock; register settings.
  - `_exit_tree()` — clean-up. Remove dock; tear down server; unregister settings; `queue_free()`
    any retained nodes.
  - `_enable_plugin()` — called once when the user toggles the plugin **on** in Project Settings.
    Use it to register autoloads.
  - `_disable_plugin()` — called once when the user toggles it **off**. Use it to remove autoloads.
- Sub-plugin pattern (per `making_plugins.rst` §"Using sub-plugins"): a parent plugin
  enables/disables children via
  `EditorInterface.set_plugin_enabled("<parent>/<child>", true|false)`. Reserve this pattern for
  future modularization.

### A.3 Dock / panel APIs

Per `making_plugins.rst` §"A custom dock":

- Status dock is a `.tscn` rooted at a `Control` (or descendant).
- Attach via `EditorPlugin.add_dock(EditorDock)` and detach via
  `EditorPlugin.remove_dock(EditorDock)`.
- Dock slot constants (use one): `DOCK_SLOT_LEFT_UL`, `DOCK_SLOT_LEFT_BL`, `DOCK_SLOT_LEFT_UR`,
  `DOCK_SLOT_LEFT_BR`, `DOCK_SLOT_RIGHT_UL`, `DOCK_SLOT_RIGHT_BL`, `DOCK_SLOT_RIGHT_UR`,
  `DOCK_SLOT_RIGHT_BR`. **Recommended:** `DOCK_SLOT_LEFT_BR` (lower-left dock) so the status row
  sits unobtrusively. (Decision recordable in `00 §0.13`.)
- Alternative attachment methods exposed by `EditorPlugin`:
  - `add_control_to_bottom_panel(Control, title)` — bottom panel tab (next to Output/Debugger).
    Strong candidate if dock conflicts with user layout.
  - `add_control_to_container(EditorPlugin.CONTAINER_*, Control)` — for inserting into a specific
    editor container (toolbar, inspector, etc.).
  - `add_tool_menu_item(label, callable)` — adds an entry under **Project → Tools → …**, an extra
    entry point.
- The user can drag/rearrange/float docks; persist nothing about position in TerraVolt code — Godot
  stores it.

### A.4 Project settings registration

Per `class_ProjectSettings` (engine reference) and `tutorials/editor/project_settings.rst`:

- Register a setting with `ProjectSettings.set_setting(name, default_value)` then
  `ProjectSettings.add_property_info({...})` to attach a type hint and tooltip.
- Use the editor-visible setting path `terravolt_mcp/<group>/<name>` for every entry in `02 §2.6.6`.
- Property hint dictionary fields: `name`, `type` (e.g., `TYPE_INT`, `TYPE_STRING`, `TYPE_BOOL`),
  `hint` (e.g., `PROPERTY_HINT_RANGE`, `PROPERTY_HINT_ENUM`), `hint_string` (e.g., `"1024,65535"`).
- Persist with `ProjectSettings.save()` if a setting is created at runtime (rare); usually the
  editor saves automatically.

### A.5 Autoload registration from the plugin

Per `tutorials/scripting/singletons_autoload.rst` §"Registering autoloads/singletons in plugins" and
`making_plugins.rst` §"Registering autoloads":

- API: `EditorPlugin.add_autoload_singleton(name, path)` /
  `EditorPlugin.remove_autoload_singleton(name)`.
- Call in `_enable_plugin()` / `_disable_plugin()` (not `_enter_tree`).
- Path may be a scene (`.tscn`) or a script (`.gd` / `.cs`).
- The autoload is added before any user scene loads, so the addon's autoload may be the first node
  in the runtime tree under `/root/`.
- **Warning** from the docs: never `free()` or `queue_free()` an autoload at runtime — the engine
  will crash. TerraVolt's `project.remove_autoload` tool must be marked `requiresEditor: true`.

### A.6 Editor data & path resolution

Per `data_paths.rst`:

- The dock's "Open Log File" button should call
  `ProjectSettings.globalize_path("user://mcp_log.txt")` and pass the result to
  `OS.shell_open(<absolute path>)`.
- For copying a log tail to clipboard: read via `FileAccess.open(path, FileAccess.READ)`; copy via
  `DisplayServer.clipboard_set(<text>)`.
- Self-contained mode (sentinel file `._sc_` next to the editor) reroutes `user://` to
  `editor_data/`. The settings dialog should display the resolved absolute path so the user can
  confirm.

### A.7 Recovery Mode awareness

Per `command_line_tutorial.rst` Run Options table:

- `godot --recovery-mode` disables tool scripts, editor plugins, GDExtensions — i.e., **disables
  TerraVolt MCP**. If a user reports the addon "missing" after a crash, the troubleshooting guide
  must point at recovery mode as a first check.

### A.8 Addon test framework — narrow the choice

Per the project's stated criteria (Decisions Log §0.13):

- **GUT (Godot Unit Test)** is the more popular of the two; mature for Godot 4; integrates with
  headless via `addons/gut/gut_cmdln.gd`. Recommended default.
- **gdUnit4** has a richer assertion API and a JUnit XML reporter (better for CI). Consider if
  `headless.run_tests` requires structured output for `10`'s release pipeline.
- Decision recordable here once the implementer commits.

### A.9 Settings hot-apply / restart-required matrix (refined per Godot APIs)

- Port and bind address are bound to a live socket — changing them requires `MCPServer.stop()` +
  `start()`. Surface a one-click "Restart" affordance on the dock.
- `auto_start_on_open` is read at addon load — change applies on next editor open (or via the dock's
  Start/Stop buttons immediately).
- Logging path / level changes apply on the next written record (already in `04`).

### A.10 Risk register additions

| Risk                                                                                             | Source                             | Mitigation                                                                                                |
| ------------------------------------------------------------------------------------------------ | ---------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Non-`@tool` GDScript loaded by addon is silently empty.                                          | `making_plugins.rst` warning.      | Lint enforces `@tool` at line 1 of every `.gd` under `packages/godot-mcp-addon/`.                         |
| `add_autoload_singleton` from `_enter_tree` instead of `_enable_plugin` fires every editor open. | `making_plugins.rst` §autoloads.   | Always use the `_enable_plugin`/`_disable_plugin` pair.                                                   |
| Dock layout collisions with other plugins.                                                       | Empirical.                         | Default slot reserved (`DOCK_SLOT_LEFT_BR`); document fallback to bottom-panel tab if conflicts reported. |
| Project Settings property hints absent ⇒ Inspector shows raw fields.                             | `class_ProjectSettings` reference. | Every TerraVolt setting must include `property_info` with `hint`/`hint_string`.                           |
