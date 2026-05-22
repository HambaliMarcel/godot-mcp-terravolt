# 04 — JSON-RPC Dispatch & Logging (Phase 1, part C)

> **Goal**: turn the raw WebSocket pipe from `03` into a strict **JSON-RPC 2.0**
> request/response/notification channel with a **central command dispatcher**, a **stable
> application error code registry**, and a **structured logger** that writes to
> `user://mcp_log.txt`. After this file, Phase 1 is complete: a Cursor agent can connect to the
> daemon, send `ping`, `echo`, `server_info`, and a handful of "introspection" methods, and get back
> well-formed JSON-RPC responses — all while every event is logged to a tail-friendly file.

---

## 4.1 Header

- **File:** `04-jsonrpc-dispatch-and-logging.md`
- **Purpose:** wire JSON-RPC 2.0 semantics, a central dispatcher, an application error registry, and
  a production-grade logger into the addon.

## 4.2 Phase placement

- **Phase 1, part C.** Completes Phase 1 alongside `02` and `03`.
- Gates Phase 2: the Node router (`05`) cannot be started until this file is done and a round-trip
  `ping` is proven.

## 4.3 Inputs / prerequisites

- `02` and `03` complete.
- A peer connection exists from a generic WS client during testing.
- Settings from `02 §2.6.6` available (`logging/path`, `logging/level`, `logging/rotate_size_kb`).

## 4.4 Outputs

After this file:

1. The **`Dispatcher`** is real. It parses JSON-RPC 2.0 messages from peer inbound queues, validates
   them, and routes to handlers.
2. A **stable error code registry** exists in addon code with documented codes (mirrored in this
   file).
3. **`Logger`** is real. It writes line-delimited JSON to `user://mcp_log.txt`, supports rotation,
   in-memory tail, and dock integration.
4. A minimum set of **"plumbing" methods** is implemented and reachable: `ping`, `echo`,
   `server_info`, `list_methods`, `log_tail`, `set_log_level`. None of these touch scene/node/editor
   state; they only prove the pipe.
5. **Heartbeat fallback** (JSON-RPC `ping`/`pong` notifications) is wired so that file `03`'s
   control-frame heartbeats have a parallel application-level option.
6. **Structured diagnostics** start here: every error returned to the router includes `code`,
   `message`, and a `data` envelope with category, severity, and a human-readable hint.
7. Dock surfaces the **log tail** and a **method ledger** of the last N RPC calls.

## 4.5 Operating constants used

| Constant                                 | Value                      | From        |
| ---------------------------------------- | -------------------------- | ----------- |
| JSON-RPC version literal                 | `"2.0"`                    | `00 §0.3`   |
| Application error code range (TerraVolt) | `-33000` to `-33999`       | `00 §0.3`   |
| Log file path                            | `user://mcp_log.txt`       | `00 §0.3`   |
| Log rotation default size                | `5 MiB` (i.e., `5120 KiB`) | `02 §2.6.6` |

No new constants introduced.

---

## 4.6 Detailed task breakdown

### 4.6.1 JSON-RPC 2.0 semantics — what the dispatcher must enforce

Strict adherence to the JSON-RPC 2.0 spec (https://www.jsonrpc.org/specification). The dispatcher
must:

1. Treat every inbound frame as **UTF-8 text** that should parse as a JSON value. If the frame is
   binary, reject with `transport.unsupported_frame`.
2. Accept **single requests** and **batch requests** (arrays). Batches are returned as arrays of
   responses, in the same order, with notifications omitted.
3. Enforce required fields:
   - `jsonrpc` must equal `"2.0"`. Otherwise return `-32600 Invalid Request`.
   - `method` must be a string. Otherwise `-32600`.
   - `id` may be string, number, or null. **Missing `id`** ⇒ **notification** (no response).
   - `params` is optional; when present must be array or object.
4. Reject unknown methods with `-32601 Method not found`.
5. Reject invalid params (schema mismatch) with `-32602 Invalid params`. Schema validation happens
   here (server-side) **and** in the router (client-side) so the error is doubly enforced. See
   §4.6.6.
6. Internal handler exceptions ⇒ `-32603 Internal error`, but **prefer mapping to a TerraVolt
   application code** in the `-33xxx` range with a precise category.
7. Parse failures (malformed JSON) ⇒ `-32700 Parse error`. Whenever the failed message has no
   recoverable `id`, the response uses `id: null` per spec.
8. Server **never** sends a request to the client by default. (Reserve the option for future
   server-initiated calls; v1 keeps a strict request-from-client model with optional notifications
   from the server.)
9. **Notifications from server to client** are allowed (events like `runtime.tree_changed`). They
   use a clearly namespaced method (e.g., `event.runtime.tree_changed`).

### 4.6.2 Central dispatcher contract

`Dispatcher` exposes:

| Method                                   | Inputs                               | Outputs                                            |
| ---------------------------------------- | ------------------------------------ | -------------------------------------------------- |
| `register(method_name, handler, schema)` | method string, callable, JSON Schema | bool (success)                                     |
| `unregister(method_name)`                | method string                        | bool                                               |
| `dispatch(peer, raw_frame)`              | peer + raw text                      | array of responses (or empty if all notifications) |
| `list_methods()`                         | —                                    | array of registered method names                   |
| `set_validator(validator)`               | reference                            | replaces JSON Schema validator (test seam)         |

Handlers receive a typed **request context** with at least:

- `method` (string).
- `params` (Variant — typed as Dictionary/Array; handler should validate further if needed).
- `peer_id` (int, from `03`).
- `request_id` (Variant — string/number/null/absent).
- `is_notification` (bool).

Handlers return either:

- A **result** value (any JSON-serializable Godot value).
- An **error** envelope (see §4.6.5).

The dispatcher takes care of building the wire response.

### 4.6.3 Method namespacing

Every method follows the dotted scheme `category.action[.qualifier]`. Examples:

- `ping`
- `echo`
- `server.info`
- `server.list_methods`
- `server.heartbeat`
- `server.shutdown` (gated by setting; defaults off)
- `log.tail`
- `log.set_level`
- `event.runtime.tree_changed` (server-initiated notification only)

Categories defined here (plumbing only): `server`, `log`, `event`. Files `05`–`08` add `scene`,
`node`, `script`, `resource`, etc.

### 4.6.4 Built-in methods to implement in this file

| Method                       | Direction | Params                                | Result                                                                                                           |
| ---------------------------- | --------- | ------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `ping`                       | C→S       | none                                  | `{ok: true, ts: <epoch_ms>}`                                                                                     |
| `echo`                       | C→S       | `{message: string}`                   | `{message: <same>, peer_id, ts}`                                                                                 |
| `server.info`                | C→S       | none                                  | `{name, version, godot_version, addon_version, build_mode, listen_address, uptime_sec, supported_methods_count}` |
| `server.list_methods`        | C→S       | optional `{prefix: string}`           | `[method_name, ...]`                                                                                             |
| `server.heartbeat`           | C→S       | none                                  | `{pong: true, ts}` (fallback to native control frames)                                                           |
| `server.shutdown`            | C→S       | optional `{reason: string}`           | `{ok}` (only when `server/allow_remote_shutdown` setting is true; default false)                                 |
| `log.tail`                   | C→S       | `{lines?: int = 100, level?: string}` | `[ {ts, level, subsystem, event, ...}, ... ]`                                                                    |
| `log.set_level`              | C→S       | `{level: string}`                     | `{ok, previous_level, new_level}`                                                                                |
| `event.runtime.tree_changed` | S→C       | —                                     | notification only (real payload defined later in `08`)                                                           |

These are the **only** methods implemented in this file. All other methods land in `08`.

### 4.6.5 Application error code registry

The TerraVolt application code range is `-33000` to `-33999`. Codes are stable: once assigned, they
never change meaning.

| Code     | Category    | Symbol                             | Recoverable?              | Meaning                                                                                               |
| -------- | ----------- | ---------------------------------- | ------------------------- | ----------------------------------------------------------------------------------------------------- |
| `-33000` | `transport` | `transport.bind_failed`            | No (until config changes) | WS listener could not bind.                                                                           |
| `-33001` | `transport` | `transport.peer_busy`              | Yes                       | Single-client policy rejected a second peer.                                                          |
| `-33002` | `transport` | `transport.handshake_failed`       | No                        | WS handshake invalid.                                                                                 |
| `-33003` | `transport` | `transport.heartbeat_timeout`      | Yes                       | Peer pruned for missed heartbeats.                                                                    |
| `-33004` | `transport` | `transport.abrupt_close`           | Yes                       | Peer closed without a clean close frame.                                                              |
| `-33005` | `transport` | `transport.queue_overflow`         | Yes                       | Per-peer inbound queue cap reached.                                                                   |
| `-33006` | `transport` | `transport.unsupported_frame`      | Yes                       | Binary frame received when text expected (or vice versa).                                             |
| `-33100` | `protocol`  | `protocol.invalid_jsonrpc_version` | Yes                       | `jsonrpc` field missing or not `"2.0"`.                                                               |
| `-33101` | `protocol`  | `protocol.method_not_found`        | Yes                       | Method not registered.                                                                                |
| `-33102` | `protocol`  | `protocol.invalid_params`          | Yes                       | Params failed schema validation.                                                                      |
| `-33103` | `protocol`  | `protocol.batch_too_large`         | Yes                       | Batch exceeds configured limit (default 50).                                                          |
| `-33200` | `auth`      | `auth.token_required`              | Yes                       | Token-required mode is on; peer didn't supply one.                                                    |
| `-33201` | `auth`      | `auth.token_invalid`               | Yes                       | Token mismatch.                                                                                       |
| `-33300` | `dispatch`  | `dispatch.handler_threw`           | Maybe                     | Handler raised an exception; wrapped in `-32603` for spec compliance and `-33300` in `data.app_code`. |
| `-33400` | `editor`    | `editor.not_available`             | Maybe                     | A handler that needs `EditorInterface` ran while editor is closed; suggest headless fallback.         |
| `-33401` | `editor`    | `editor.no_open_project`           | Maybe                     | No project loaded.                                                                                    |
| `-33500` | `scene`     | `scene.path_not_found`             | Maybe                     | Scene file not found.                                                                                 |
| `-33501` | `scene`     | `scene.node_path_not_found`        | Maybe                     | Node path within scene not found.                                                                     |
| `-33502` | `scene`     | `scene.invalid_path`               | Yes                       | Path syntax invalid.                                                                                  |
| `-33503` | `scene`     | `scene.read_only`                  | Maybe                     | Scene is read-only (e.g., imported asset).                                                            |
| `-33600` | `script`    | `script.compile_failed`            | Maybe                     | Script syntax check failed.                                                                           |
| `-33601` | `script`    | `script.attach_failed`             | Maybe                     | Could not attach script to node.                                                                      |
| `-33700` | `resource`  | `resource.not_found`               | Maybe                     | Resource file missing.                                                                                |
| `-33701` | `resource`  | `resource.unsupported_type`        | Yes                       | Operation not supported for resource type.                                                            |
| `-33800` | `runtime`   | `runtime.not_playing`              | Yes                       | Required play mode for the op.                                                                        |
| `-33801` | `runtime`   | `runtime.tree_unavailable`         | Maybe                     | Runtime tree poll failed.                                                                             |
| `-33900` | `context`   | `context.truncated`                | N/A (informational)       | Response was envelope-truncated; pointer to fetch raw included.                                       |
| `-33999` | `internal`  | `internal.unexpected`              | No                        | Catch-all — should be impossible if other codes are correctly assigned.                               |

**Rules**:

- The registry is exposed via `server.list_error_codes` (added in `08`; reserve the method name).
- Every error envelope includes `code`, `message`, `data.app_code` (the symbol), `data.category`,
  `data.recoverable`, `data.hint`, and optional `data.context` (object).

### 4.6.6 JSON Schema validation

- The dispatcher holds a per-method schema (provided at `register()` time).
- Validation library: a small, dependency-free GDScript JSON Schema validator (Draft 2020-12 subset
  is sufficient: `type`, `required`, `properties`, `items`, `enum`, `oneOf`, `anyOf`, `minimum`,
  `maximum`, `minLength`, `maxLength`, `pattern`, `additionalProperties`).
- If the addon community has a reasonable library by impl time, adopt it; otherwise build the
  minimal subset.
- Validation failures map to `-33102 protocol.invalid_params` with `data.errors: [...]`.

### 4.6.7 Heartbeat reconciliation

- Native WS control frames (file `03`) remain the **primary** heartbeat.
- **Fallback**: if a peer hasn't responded to a control-frame ping within `heartbeat_interval_ms`,
  send a JSON-RPC `server.heartbeat` notification expecting a `server.heartbeat` _request from the
  peer with a pong-result_ (mirroring `tomyud1`'s pattern).
- The fallback is configured by
  `terravolt_mcp/server/heartbeat_mode = "control_frame" | "rpc" | "both"`. Default `control_frame`.

### 4.6.8 `Logger` — structured, rotated, observable

`Logger` writes one **JSON line per record**:

- Schema: `{ts, level, subsystem, event, peer_id?, request_id?, method?, code?, message?, fields?}`.
- Reserved levels: `debug`, `info`, `warn`, `error`.
- Subsystems: `transport`, `protocol`, `dispatch`, `handler`, `lifecycle`, `runtime`, `context`.
- Path: read from `terravolt_mcp/logging/path`, default `user://mcp_log.txt`.
- Rotation: when file size exceeds `rotate_size_kb`, rename to `user://mcp_log.1.txt`, then
  `user://mcp_log.2.txt`, etc. Keep at most 5 archives by default (configurable:
  `terravolt_mcp/logging/max_archives`, default 5).
- In-memory **ring buffer** of the last 500 records for the dock's "Last log line" / "Copy Log Tail"
  feature and for `log.tail` requests.
- Thread/process safety: confine writes to the editor's main thread (Godot's editor scripting
  model). If a future phase introduces threading, gate writes through a Mutex.
- Hot reload: changing `logging/level` or `logging/path` takes effect on the next record (with a
  single info log line noting the change).

### 4.6.9 Diagnostic envelope

Every error returned over JSON-RPC follows this envelope shape (described in prose):

- `code` — JSON-RPC numeric code (spec or `-33xxx`).
- `message` — short human-readable string.
- `data`:
  - `app_code` — TerraVolt symbol (e.g., `scene.node_path_not_found`).
  - `category` — `transport`, `protocol`, `auth`, `editor`, `scene`, `script`, `resource`,
    `runtime`, `context`, `internal`, `dispatch`.
  - `recoverable` — bool.
  - `hint` — natural-language suggestion to the agent for self-healing (e.g., "Open the editor or
    call `headless.start_project` to populate the runtime tree.").
  - `context` — optional object with diagnostic fields (paths, indices, types).

This envelope is the contract `09` (context & error optimization) builds on.

### 4.6.10 Dock additions

- **Method ledger:** a list of the last N RPC calls (method, peer, latency ms, status code). Renders
  newest at top. Maximum N = 50.
- **Log tail tab:** shows the in-memory ring buffer with level filter.
- "Open Log File" button now functional (reveals `user://mcp_log.txt` in the OS file browser).

### 4.6.11 Boot order for the addon (recap after `02`/`03`/`04`)

1. `_enter_tree`: instantiate Logger (file sink ready), Dispatcher (no methods yet), MCPServer.
2. Logger emits `lifecycle.enter_tree`.
3. Dispatcher registers built-in methods (`ping`, `echo`, etc.).
4. MCPServer hands its inbound queues to Dispatcher's polling loop.
5. If `auto_start_on_open`, MCPServer.start().
6. Dock binds to MCPServer + Logger + Dispatcher signals.

Shutdown order:

1. Dispatcher refuses new requests; flushes responses for in-flight ones (best effort within the
   editor's exit window).
2. MCPServer closes peers cleanly with code 1001 ("going away").
3. Logger flushes the ring buffer to the file sink.
4. Dock detaches.

### 4.6.12 Manual smoke tests for this phase

1. Connect a WS client. Send `ping`. Expect `{ok:true, ts:...}` JSON-RPC response in < 50ms.
2. Send `echo` with an empty `message`. Expect `-33102 protocol.invalid_params` with `data.errors`
   listing the missing field.
3. Send a malformed JSON frame. Expect `-32700 Parse error`, `id: null`.
4. Send `server.info`. Confirm response includes Godot version, addon version, listen address,
   uptime.
5. Send `server.list_methods`. Confirm at least the methods in §4.6.4.
6. Send `log.set_level` to `debug`, then `log.tail`. Confirm both succeed and tail returns
   debug-level records.
7. Trigger an exception in a handler (use a temporary test method). Confirm `-32603 Internal error`
   with `data.app_code = dispatch.handler_threw`.
8. Watch `user://mcp_log.txt` grow with structured lines.
9. Force-rotate by setting `rotate_size_kb` low (e.g., 1) and pinging until rotation triggers.
   Confirm `mcp_log.1.txt` appears.
10. Restart editor and confirm log archives persist while the active file resumes appending.

---

## 4.7 Schemes / data shapes (no code)

### 4.7.1 Wire shapes (described)

- **Request** (object): `jsonrpc:"2.0"`, `method:string`, `params?:object|array`,
  `id?:string|number|null`.
- **Notification** (object): same as Request without `id`.
- **Response (success)**: `jsonrpc:"2.0"`, `result:any`, `id`.
- **Response (error)**: `jsonrpc:"2.0"`, `error:{code,message,data}`, `id`.
- **Batch**: array of any of the above.

### 4.7.2 Dispatcher pipeline

```text
peer.inbound_queue ──► parse JSON ──► validate JSON-RPC envelope ──► resolve method
                                                                       │
                                                                       ▼
                                                         look up handler + schema
                                                                       │
                                                                       ▼
                                                    validate params against schema
                                                                       │
                                                          ┌────────────┴────────────┐
                                                          ▼                         ▼
                                                       handler returns result    handler returns error
                                                          │                         │
                                                          ▼                         ▼
                                                 build success response      build error envelope
                                                                       │
                                                                       ▼
                                                          peer.outbound_queue
```

### 4.7.3 Method registry (described)

A map of
`method_name → {handler, schema, category, since_version, requires_editor?, requires_runtime?, deprecated?}`.
Fields populated at `register()` time. Used by `server.list_methods` and `server.info`.

### 4.7.4 Logger record shape (described)

Every record is a flat object whose top-level keys are: `ts` (ISO 8601 string with millisecond
precision), `level`, `subsystem`, `event`, plus optional contextual keys depending on the event
type. Records are written as **one JSON object per line**, no trailing comma, no enclosing array —
so any tool can tail-and-parse line by line.

### 4.7.5 Log rotation policy

- Active file: `user://mcp_log.txt`.
- Archives: `user://mcp_log.1.txt`, `mcp_log.2.txt`, …, `mcp_log.N.txt` (where N = `max_archives`,
  default 5).
- On rotation: shift indices upward (delete `N`, rename `N-1 → N`, …, rename active to `1`), open a
  fresh active file.
- Rotation does not interrupt logging beyond a tiny pause; in-memory ring buffer continues to
  receive records during the swap.

---

## 4.8 Tech stack delta vs `00 §0.10`

- Adds a minimal JSON Schema validator inside the addon. No new dependency if Godot does not ship
  one; if a community plugin exists by impl time, use it (and record the choice).
- No new dependencies in `packages/mcp-server/` from this file.

---

## 4.9 Acceptance criteria

- [ ] Strict JSON-RPC 2.0 parsing per §4.6.1 (including batches and notifications).
- [ ] Built-in methods §4.6.4 implemented and reachable.
- [ ] Error registry §4.6.5 documented in the addon README and in this file.
- [ ] Diagnostic envelope §4.6.9 used for every error response.
- [ ] Logger writes structured JSON to `user://mcp_log.txt` and rotates per §4.6.8.
- [ ] Dock surfaces method ledger and log tail.
- [ ] Heartbeat fallback per §4.6.7 documented (and switched on by setting if needed).
- [ ] Smoke tests in §4.6.12 all pass.
- [ ] Decisions Log updated.

---

## 4.10 Verification plan

1. Manual smoke tests §4.6.12.
2. Programmatic smoke (deferred full coverage to `10`): a tiny WS client that sends each built-in
   method and asserts the response shape.
3. Log inspection: `Get-Content -Wait user://mcp_log.txt` (or platform equivalent) shows live
   structured lines.
4. Rotation test: lower `rotate_size_kb` and spam pings to force rotation.
5. Heartbeat fallback test: disable native ping/pong in the WS client; confirm `server.heartbeat`
   fallback kicks in if `heartbeat_mode = "rpc"` or `"both"`.

---

## 4.11 Risks & mitigations

| Risk                                                                | Mitigation                                                                                                                          |
| ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| JSON parsing in GDScript is slower than expected on large payloads. | Cap inbound frame size at `terravolt_mcp/server/max_frame_bytes` (default 4 MiB); reject larger with `-33005`.                      |
| JSON Schema validator complexity.                                   | Implement only the subset listed in §4.6.6; future expansions are reserved.                                                         |
| Log file lock contention if editor closes mid-write.                | Wrap writes in try/except; on failure, drop the record and warn (don't crash).                                                      |
| Error code drift between Godot and Node sides.                      | Single source of truth: this file. Mirror in router (`05`/`06`) as a generated TS module reading from a shared JSON in `packages/`. |
| Notifications mis-handled as requests by sloppy clients.            | Strict spec adherence: missing `id` ⇒ notification, period. Document for router.                                                    |
| Dock method ledger eats memory if RPC volume is high.               | Cap to 50 entries; older entries discarded.                                                                                         |

---

## 4.12 Handoff checklist to file `05`

- [ ] Round-trip `ping` works between addon and a generic WS client.
- [ ] `server.info`, `server.list_methods`, `echo`, `log.tail`, `log.set_level`, `server.heartbeat`
      all answer correctly.
- [ ] Error envelope shape stable and documented.
- [ ] Logger writes to `user://mcp_log.txt` with rotation.
- [ ] **Phase 1 complete.** Phase 2 may begin.

When done, open **`05-node-mcp-router.md`**.

---

## Appendix A — Official Godot Docs alignment (added revision 2)

> Sourced from `tutorials/scripting/debug/*`, `tutorials/io/data_paths.rst`,
> `tutorials/editor/command_line_tutorial.rst`, and `tutorials/scripting/filesystem.rst`. Anchors
> the logger and dispatcher to Godot's first-party APIs.

### A.1 Log sink resolution (canonical)

Per `data_paths.rst`:

- The setting `terravolt_mcp/logging/path` defaults to `user://mcp_log.txt`. On first write, resolve
  to an absolute path with `ProjectSettings.globalize_path(<setting>)` and **cache the result**.
  Surface this absolute path via `server.info.log_path`.
- Honor self-contained mode (sentinel `._sc_` or `_sc_` next to the editor binary): the resolved
  absolute path will then live under `editor_data/app_userdata/<project>/mcp_log.txt`.
- Honor `application/config/use_custom_user_dir` and `application/config/custom_user_dir_name` (per
  `data_paths.rst` §"Accessing persistent user data") — the resolved path follows the project's
  choice automatically.

### A.2 File writing API

- Open the log file with `FileAccess.open(path, FileAccess.WRITE)` for the first record on startup
  (or `FileAccess.READ_WRITE` to append).
- Preferred append pattern: `FileAccess.open(path, FileAccess.READ_WRITE)` → `seek_end()` →
  `store_line(<json>)` → close on rotation or at addon `_exit_tree`.
- On Windows, **file locks** prevent two processes from reading/writing the same log simultaneously;
  the dock's "Open Log File" must not hold a handle.

### A.3 Logger ↔ Godot debug-category mapping

Per `tutorials/scripting/debug/overview_of_debugging_tools.rst` §"Debug project settings":

- Godot's own debug subcategories: `Settings`, `File Logging`, `GDScript`, `Shader Language`,
  `Canvas Items`, `Shapes`.
- TerraVolt's logger is **independent** of those (so as not to clobber a project's existing debug
  settings) but it should mirror Godot's `debug/file_logging/*` keys (where applicable) for
  consistency. Document mapping in the addon README.
- Godot's built-in `--log-file <path>` CLI flag (per `command_line_tutorial.rst`) overrides
  stderr/stdout logging for the engine. TerraVolt's logger is _additional_ (structured JSON to a
  known file); the user can still set `--log-file` for engine-level logging.

### A.4 The `breakpoint` keyword

Per `overview_of_debugging_tools.rst`:

- GDScript has a `breakpoint` keyword that triggers a debugger break when execution reaches it.
- Useful **inside TerraVolt addon dev**: drop `breakpoint` in a handler to inspect from the editor's
  debugger panel.
- **Never** ship `breakpoint` in committed handler code — add an ESLint-equivalent GDScript lint
  rule (or a CI grep) for `^[\\s]*breakpoint\\b` and fail PRs.

### A.5 Debug-category project setting alignment

When TerraVolt opens its logger, also honor (read-only):

- `application/run/print_header` (whether to print engine startup banner).
- `debug/file_logging/enable_file_logging` (engine's own file logging on/off).
- `debug/settings/stdout/verbose_stdout` (engine verbose flag).

The dock's debug panel may surface these for the developer's convenience; TerraVolt does not modify
them.

### A.6 JSON-RPC parsing in GDScript

- Use Godot's first-party `JSON.parse_string(<text>)` and `JSON.stringify(<dict>)` for parsing and
  serialization (no third-party deps).
- `JSON.parse_string` returns `null` on failure; the dispatcher must surface `-32700 Parse error`
  per `04 §4.6.1`.
- Numbers come back as `int` or `float` depending on input — schema validation must tolerate both
  for integer fields if needed (e.g., agent may send `1.0` instead of `1`).
- Strings are `String` (Godot 4 unifies `String`/`StringName` storage; method names returned via
  `server.list_methods` should be plain `String`).

### A.7 Notification semantics — agent-facing events

Per `tutorials/scripting/scene_tree.rst` and `tutorials/scripting/groups.rst`, scene/group changes
can be observed via:

- Signals on `SceneTree` such as `tree_changed`, `node_added`, `node_removed`, `node_renamed`.
- `Node.tree_entered`, `tree_exited`, `tree_exiting`, `child_entered_tree`, `child_exiting_tree`,
  `renamed`.

These power the `event.scene.*` and `event.node.*` notifications described in `08 §8.9.3`. The
dispatcher subscribes when the daemon enters the tree and unsubscribes on exit. Throttling rules
(added in `06`/`09`) apply.

### A.8 Logger record schema clarifications

Add the following keys to every record (in addition to those in `04 §4.7.4`):

- `addon_version` — pulled from `plugin.cfg` (`version` field). Useful for log analytics across
  releases.
- `godot_version` — `Engine.get_version_info()` shaped as
  `{major, minor, patch, status, build, hex, hash, year, string}`. Include just `version_string` to
  keep the record small.
- `pid` — `OS.get_process_id()`.
- `feature_tags` — `OS.get_feature_list()` (filtered to a short whitelist: `editor`, `template`,
  `release`, `debug`, `pc`, `mobile`, `web`).

Helps QA correlate logs to environments.

### A.9 Rotation API specifics

- File rename in GDScript: `DirAccess.rename(from, to)` (since Godot 4); or open a `DirAccess`
  instance for the `user://` directory.
- File size: `FileAccess.get_length()` on the open handle, or `FileAccess.get_file_size(path)`
  (static) when not open.
- On Windows, renaming an open file may fail — close the active handle before rotating, then reopen
  for append.

### A.10 Risks added

| Risk                                                                                 | Mitigation                                                                                                           |
| ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| `JSON.parse_string` differs subtly from JS `JSON.parse` for floats/`NaN`.            | Strict JSON validation on the router side; daemon's parser rejects `NaN`/`Infinity` (they aren't valid JSON anyway). |
| File handle held across editor reload corrupts log on Windows.                       | Close the file before any settings change that triggers a logger restart.                                            |
| `OS.get_feature_list()` includes user-defined custom features that may be sensitive. | Whitelist as in A.8; do not log unfiltered.                                                                          |
| `breakpoint` keyword left in shipped code halts the editor unexpectedly.             | Pre-commit + CI grep blocks it.                                                                                      |
| `user://` path differs across users; agent confused about where logs live.           | Always surface the resolved absolute path in `server.info` and `log.tail` responses.                                 |
