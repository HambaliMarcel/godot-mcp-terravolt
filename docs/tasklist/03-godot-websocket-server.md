# 03 — Godot WebSocket Server (Phase 1, part B)

> **Goal**: turn the `MCPServer` facade from `02` into a real WebSocket daemon listening on port `6505`. Accept connections from the Node router. Maintain a clean lifecycle, heartbeat, backoff for re-listen, and observability. **No JSON-RPC parsing yet — file `04` owns that.** The daemon, after this file, can hold an open WebSocket connection, exchange raw text/binary frames, and reflect lifecycle state in the editor dock.

---

## 3.1 Header

- **File:** `03-godot-websocket-server.md`
- **Purpose:** make the addon's WebSocket daemon real, robust, and observable, without yet parsing protocol payloads.

## 3.2 Phase placement

- **Phase 1, part B.** Pairs with `04` to complete Phase 1.
- Gates Phase 2 jointly with `04`.

## 3.3 Inputs / prerequisites

- `02` complete: addon shell, dock, settings, facades.
- A working dev project with the addon mounted.
- Godot's WebSocket APIs available (built-in `WebSocketPeer` / `WebSocketMultiplayerPeer` in Godot 4).
- Settings registered in `02` (`terravolt_mcp/server/port`, `bind_address`, `auto_start_on_open`, `heartbeat_interval_ms`, `heartbeat_timeout_ms`).

## 3.4 Outputs

When this file is done:

1. The daemon binds to `127.0.0.1:6505` (defaults from `00 §0.3`, overrideable via settings from `02 §2.6.6`).
2. Accepts WebSocket clients (single-client policy by default, see §3.6.6).
3. Performs the WebSocket handshake correctly (using Godot's first-party WS implementation).
4. Drives a clean per-peer lifecycle (connect, handshake-complete, ready, closing, closed).
5. Maintains a **heartbeat**: ping/pong frames at configured interval; closes peers that miss the timeout.
6. Surfaces lifecycle to the dock from `02 §2.6.7`.
7. Persists nothing across sessions; restart wipes state.
8. **Does not** parse application payloads. It receives a frame and forwards the raw text/bytes to the dispatcher facade. File `04` plugs the real dispatcher in.
9. Provides an observable error model: every failure (bind failure, malformed handshake, abrupt close) becomes a structured log line and a dock status update.

## 3.5 Operating constants used

| Constant | Value | From |
|----------|-------|------|
| Default listen port | `6505` | `00 §0.3` |
| Default bind address | `127.0.0.1` | `02 §2.6.6` |
| Default heartbeat interval | `15000ms` | `00 §0.3` / `02 §2.6.6` |
| Default heartbeat timeout | `45000ms` | `00 §0.3` / `02 §2.6.6` |

No new constants introduced.

---

## 3.6 Detailed task breakdown

### 3.6.1 Pick the Godot WS API and document why

Decision: use **Godot 4's built-in `WebSocketPeer` family** (and `WebSocketMultiplayerPeer` if multi-peer becomes desirable). Rationale:

- First-party; no native dependency.
- Stable since Godot 4.0.
- Matches the approach in `references/godot-mcp-tomyud1/addons/godot_mcp/`.

Record the decision in `00 §0.13`.

### 3.6.2 Server bootstrap flow

`MCPServer.start()` performs:

1. Read effective config from project settings (port, address, heartbeat ints).
2. Validate port range (`1024`–`65535`); reject reserved ports with a structured error.
3. Validate bind address (allow `127.0.0.1`, `0.0.0.0`, or any local IPv4/IPv6 the OS recognizes).
4. Create the WS listener (using the chosen API).
5. Begin polling for incoming connections in the editor's processing loop.
6. On success: state ← `listening`, log a structured line, update the dock badge.
7. On failure (port in use, permission denied, etc.): state ← `error`, log a structured error (mapped error code from `04`'s registry), update the dock badge with a clear message and a "Retry" affordance.

### 3.6.3 Per-peer lifecycle

For each accepted peer:

1. Run the WS handshake.
2. Once `WebSocketPeer` reaches the *open* state, mark the peer `ready`.
3. Issue a single `server.hello` notification (purely framed; payload content is `04`'s job — leave as an opaque placeholder string in this phase).
4. Begin reading frames in the polling loop.
5. For every received frame, push the raw frame (text or binary) onto a per-peer **inbound queue** that the dispatcher (file `04`) will consume.
6. On peer close (clean): log structured close reason; state ← `listening` (if no other peers) or stay `client_connected`.
7. On peer close (abrupt): log error; do not crash the polling loop.

### 3.6.4 Connection policy

**Single-client first.** Until file `08` proves otherwise, accept at most one concurrent client:

- If a second client connects, immediately close it with a "server busy" close code and a structured close reason. (Reserve the option to upgrade to multi-client later, but do not implement it here.)
- The Node router is expected to be the sole client.

Connection identity:

- Each peer is assigned an internal numeric ID for log correlation.
- Optionally surface a client-provided identity hash (e.g., from the first `client.hello` frame). Implementation lands in `04`/`05`; for now reserve a field on the peer object.

### 3.6.5 Heartbeat (ping / pong)

`MCPServer` owns the heartbeat loop:

1. While a peer is `ready`, schedule a ping every `heartbeat_interval_ms`.
2. Use WebSocket-native ping/pong control frames (preferred). If the chosen Godot WS API exposes only data frames, fall back to a JSON-RPC `ping` *notification* — but this fallback is implemented in `04`, not here. For now: prefer native control frames.
3. Track the timestamp of the last `pong` received. If `(now - last_pong) > heartbeat_timeout_ms`, close the peer with a "heartbeat timeout" reason.
4. Emit `heartbeat_pulse` on the dock so the UI can render the pulse icon.

### 3.6.6 Listen loop & polling cadence

- The editor runs at typical editor FPS. The daemon must `poll()` its WS listener and any open peers in a way that:
  - Doesn't drop frames.
  - Doesn't block the editor (use `process()` or a `Timer`).
- Recommended cadence: poll listeners on every editor `_process`, but rate-limit log spam.
- For potentially blocking work (large outbound payloads, future), defer to the next polling tick rather than building up call stacks.

### 3.6.7 Error model (transport-level only)

Structured errors raised here (final codes assigned in `04`):

- `transport.bind_failed` — listener could not bind (port in use, permission, etc.).
- `transport.handshake_failed` — WS handshake rejected.
- `transport.peer_busy` — second client rejected by single-client policy.
- `transport.heartbeat_timeout` — peer pruned.
- `transport.abrupt_close` — peer dropped without a clean close frame.
- `transport.poll_error` — exception during polling; log + continue.

Each error generates a structured log line and a dock state update. File `04` wires these into the application-level diagnostic registry.

### 3.6.8 Dock updates (live)

The dock (from `02 §2.6.7`) now binds to live state:

- Badge reflects current state (Idle / Listening / Client connected / Error).
- Listen address is the actual bound address:port.
- Active connections count is real.
- Heartbeat indicator pulses on every received pong.
- "Open Log File" still hidden if `04` hasn't landed; the file may not exist yet.
- "Copy Log Tail" reads the in-memory ring buffer the placeholder logger keeps until `04` writes the real file sink.

### 3.6.9 Configuration changes at runtime

When the user changes a relevant project setting (port, bind, heartbeat):

- If the daemon is `listening` or has a client connected, surface a "Restart server to apply" hint in the dock; do not auto-restart (to avoid surprise disconnects).
- Provide a `Restart` button on the dock for one-click reload.

### 3.6.10 Reserved hooks

Without implementing them, leave clean seams for:

- **Auth token check** during handshake (when `terravolt_mcp/security/require_token` is on). Reserved field on the handshake request handler.
- **TLS termination.** Out of scope for v1; documented as a future option in the addon README.
- **Per-peer rate limiting.** Reserve a hook that `04` can attach to.
- **Visualizer port `6510`.** Not bound here; just reserve a settings entry (already in `02 §2.6.6` future row).

### 3.6.11 Logging this file emits (placeholder shape)

Until `04` provides the real logger, log lines should be structured maps (rendered to the editor output panel for now) with at least:

- `ts` (timestamp).
- `level` (`info`/`warn`/`error`).
- `subsystem` (`transport`).
- `event` (`bind`, `peer_connected`, `peer_disconnected`, `heartbeat_pong`, `error`).
- `peer_id` if applicable.
- `details` (object).

File `04` will turn these into JSON lines in `user://mcp_log.txt`.

### 3.6.12 Manual smoke tests for this phase

1. Enable the addon. Confirm dock shows `Listening 127.0.0.1:6505`.
2. From a separate terminal, connect with a generic WS client (e.g., `wscat`, a browser console, or a small ad-hoc client). Confirm dock shows `Client connected` and the connection count increments.
3. Send any text frame. Confirm a structured log line appears with the received payload (truncated for the dock; full in the log).
4. Wait > `heartbeat_timeout_ms` with no pongs (use a client that doesn't respond to pings). Confirm the peer is pruned with `transport.heartbeat_timeout`.
5. Restart the editor with `auto_start_on_open` on. Confirm the daemon re-binds.
6. Change the port to an in-use value (e.g., another running server's port). Confirm `transport.bind_failed` is logged and dock shows `Error` with the cause.
7. Open two clients. Confirm second client is rejected with `transport.peer_busy` and the first remains.

---

## 3.7 Schemes / data shapes (no code)

### 3.7.1 Peer model (in-memory)

For each connected peer the daemon holds:

| Field | Type | Notes |
|-------|------|-------|
| `id` | int | Monotonically increasing. |
| `socket` | engine-native WS handle | Hidden behind facade. |
| `address` | string | `host:port`. |
| `connected_at` | float (seconds since epoch) | For uptime display. |
| `last_pong_at` | float | For heartbeat tracking. |
| `state` | enum | `handshaking` / `ready` / `closing` / `closed` / `errored`. |
| `inbound_queue` | array | Raw frames waiting for the dispatcher. |
| `outbound_queue` | array | Raw frames queued by the dispatcher to send. |
| `identity_hash` | string (optional) | Reserved; populated when `client.hello` lands in `04`/`05`. |
| `last_error` | object | Last transport-level error (if any). |

### 3.7.2 Frame flow

```text
Router  ──► WS frame ──► Godot listener ──► peer.inbound_queue
                                                  │
                                                  ▼
                                            Dispatcher (04)
                                                  │
                                                  ▼
                                        peer.outbound_queue ──► WS frame ──► Router
```

This file owns everything left of the dispatcher. File `04` owns the dispatcher and everything to its right semantically.

### 3.7.3 Dock surface fields (live)

The dock subscribes to these signals from `MCPServer`:

- `state_changed(new_state, details)`.
- `peer_connected(peer_id, address)`.
- `peer_disconnected(peer_id, reason)`.
- `heartbeat_pulse(peer_id, direction)` — direction = `in` (pong) or `out` (ping).
- `error_raised(code, message, fields)`.

### 3.7.4 Settings change behavior

| Setting | Hot-apply? | Restart hint? |
|---------|-----------|---------------|
| `server/port` | No | Yes |
| `server/bind_address` | No | Yes |
| `server/auto_start_on_open` | Yes | No |
| `server/heartbeat_interval_ms` | Yes | No |
| `server/heartbeat_timeout_ms` | Yes | No |
| `logging/*` | Yes (when `04` lands) | No |

---

## 3.8 Tech stack delta vs `00 §0.10`

- Confirms Godot built-in `WebSocketPeer` / `WebSocketMultiplayerPeer` as the only WS implementation. No third-party native modules.
- No new packages.

---

## 3.9 Acceptance criteria

- [ ] Daemon binds to `6505` by default; logs success.
- [ ] Single client can connect and is reported on the dock.
- [ ] A second client is rejected with `transport.peer_busy`.
- [ ] Heartbeat pings sent at the configured interval.
- [ ] Heartbeat timeout closes a non-responsive peer.
- [ ] Bind failure surfaces as `transport.bind_failed` with a clear cause; dock shows Error state with retry affordance.
- [ ] Disable/enable addon repeatedly without leaks (verified via Godot debugger).
- [ ] Restart button on dock cleanly stops and re-starts the daemon.
- [ ] Reserved hooks (auth, TLS, rate limit, visualizer) documented; no half-implementations.
- [ ] Smoke tests in §3.6.12 all pass.
- [ ] Decisions Log updated.

---

## 3.10 Verification plan

1. Manual smoke tests from §3.6.12.
2. Programmatic smoke test (deferred to file `10` for full integration): a tiny harness script that opens a WS connection to `127.0.0.1:6505`, sends a text frame, and reads any response. In this phase, run it manually.
3. Log inspection: confirm structured lines for every event type listed in §3.6.7.
4. Dock inspection: confirm every state transition lights up the correct badge.

---

## 3.11 Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Editor freezes due to overly chatty polling. | Rate-limit log lines per second; throttle dock updates. |
| Heartbeat using control frames is unavailable in the chosen API surface. | Fall back to a JSON-RPC `ping` notification once `04` provides the parser. Document the fallback. |
| Single-client policy is too strict for future debug tooling. | Keep policy behind a setting (`server/max_peers` future) so it can be relaxed without touching code. |
| Bind failures silently swallowed. | Always surface to the dock; never log-only. |
| Race condition between settings change and active peer. | Apply changes at next polling tick, not mid-frame. |
| Memory leaks from unbounded inbound queue if dispatcher stalls. | Cap the inbound queue per peer (e.g., 1024 frames). Drop oldest with a `transport.queue_overflow` warning. |

---

## 3.12 Handoff checklist to file `04`

- [ ] `MCPServer` exposes `inbound_queue` / `outbound_queue` per peer.
- [ ] All transport-level events emit structured records ready to be persisted by `04`'s logger.
- [ ] Heartbeat policy ready for either native control frames or JSON-RPC `ping` fallback.
- [ ] Dock signals (§3.7.3) defined and wired.
- [ ] No JSON-RPC parsing performed in this layer. Frames are opaque text/bytes here.

When done, open **`04-jsonrpc-dispatch-and-logging.md`**.

---

## Appendix A — Official Godot Docs alignment (added revision 2)

> Sourced from `tutorials/networking/websocket.rst`, `tutorials/networking/high_level_multiplayer.rst`, and `class_WebSocketPeer` / `class_TCPServer` references. This appendix pins the daemon to Godot 4's actual WebSocket API.

### A.1 Canonical Godot 4 WS server pattern

Per `websocket.rst` §"Minimal server example", a Godot 4 WS *server* is composed of:

- A `TCPServer` (`TCPServer.new()`) that:
  - Binds with `listen(port: int, bind_address := "*")` (returns `OK` or an error code).
  - Polls accepts with `is_connection_available()` in `_process()`.
  - Hands sockets off with `take_connection() → StreamPeerTCP`.
- A `WebSocketPeer` per accepted connection (`WebSocketPeer.new()`):
  - Adopts the raw TCP stream with `accept_stream(StreamPeerTCP)`.
  - Drives I/O each frame with `poll()`.
  - Reads `get_ready_state()` returning one of `STATE_CONNECTING`, `STATE_OPEN`, `STATE_CLOSING`, `STATE_CLOSED`.
  - Sends frames with `send_text(String)` (text frames) or `send(PackedByteArray)` (binary).
  - Reads with `get_available_packet_count()` → loop `get_packet() → PackedByteArray`, and `was_string_packet() → bool` to disambiguate the last read.
  - On close, captures `get_close_code() → int` (1000=normal; -1=abrupt) and `get_close_reason() → String`.

TerraVolt's `MCPServer` (file `03 §3.7`) maps 1:1 to this pattern.

### A.2 Frame disambiguation rule

- After every `get_packet()`, **immediately** call `was_string_packet()` and stash the result; the boolean is only valid until the next read.
- For TerraVolt: only **text** frames carry JSON-RPC. **Binary** frames are rejected with `transport.unsupported_frame` (`-33006`) unless a future phase adds a binary capability.

### A.3 Polling cadence

- `WebSocketPeer.poll()` is the engine's "advance the state machine + flush" call. **Skipping** it means the connection stalls; **over-calling** it is harmless beyond CPU.
- In the editor, drive `poll()` from `_process()` on the addon's main controller node (or a dedicated Timer at e.g. 60 Hz). Avoid running it from `_physics_process()` — that ties WS health to physics tick rate.
- Backpressure: if `get_available_packet_count()` is large in a single tick, drain in a bounded loop (e.g. cap at 32 per tick) to keep the editor responsive.

### A.4 Connection state ↔ TerraVolt FSM mapping

| Godot state | TerraVolt FSM (`3.7.1`) | Action |
|-------------|--------------------------|--------|
| `STATE_CONNECTING` | `handshaking` | Wait; poll. |
| `STATE_OPEN` | `ready` | Begin reading/writing. |
| `STATE_CLOSING` | `closing` | Keep polling until `STATE_CLOSED` to allow a graceful close. |
| `STATE_CLOSED` | `closed` | Read `get_close_code()` / `get_close_reason()`; remove peer; if `code == -1` log `transport.abrupt_close`. |

### A.5 Heartbeat — control frames vs RPC fallback

- Godot 4's `WebSocketPeer` honors WS-level **ping/pong control frames** but the documented API does **not** expose explicit `ping()` / `pong()` methods in user code — the peer responds to remote pings automatically and the server detects activity via `get_ready_state()` + `poll()`.
- **Therefore**, for TerraVolt's heartbeat:
  - **Primary mode (`heartbeat_mode = "rpc"`):** send a JSON-RPC `server.heartbeat` notification at interval; expect a peer reply within `heartbeat_timeout_ms`. This is reliable and observable.
  - **Optional probe (`heartbeat_mode = "control_frame"`):** rely on `get_ready_state()` transitions and recent packet timestamps; close peers whose `last_packet_at` exceeds the timeout. Lower granularity but cheap.
  - **`both`:** run both; whichever signals dead first wins.
- Update `02 §2.6.6` setting `terravolt_mcp/server/heartbeat_mode` accordingly — default to `"rpc"` for clarity.

### A.6 Close codes (RFC 6455 + Godot specifics)

Per WS specification (referenced by `websocket.rst`):

| Code | Meaning | TerraVolt use |
|------|---------|----------------|
| `1000` | Normal closure. | Graceful peer disconnect. |
| `1001` | Going away. | Daemon shutdown (`_exit_tree`). |
| `1002` | Protocol error. | Malformed handshake. |
| `1003` | Unsupported data. | Binary frame when text expected. |
| `1008` | Policy violation. | Single-client policy rejection (`transport.peer_busy`). |
| `1011` | Internal error. | Crash in dispatcher. |
| `-1` (Godot) | Abrupt close, no close frame received. | Maps to `transport.abrupt_close`. |

The daemon should call `close(code, reason)` on its WS peer object when it initiates the close.

### A.7 Bind address policy

- `TCPServer.listen(port, "*")` binds **all interfaces**; `"127.0.0.1"` binds loopback only.
- TerraVolt default: loopback (per `00 §0.7` security stance). The `bind_address` setting from `02 §2.6.6` flows directly into `listen()`'s second argument.
- For Windows: binding to `127.0.0.1` typically avoids the Windows Defender Firewall prompt; binding to `0.0.0.0` will trigger it on first run.

### A.8 Multi-peer reservation (future)

- Per `high_level_multiplayer.rst`, `WebSocketMultiplayerPeer` is the multi-client variant. TerraVolt v1 stays single-client per `03 §3.6.4`. If multi-client is added later:
  - Replace `TCPServer` + per-peer `WebSocketPeer` with `WebSocketMultiplayerPeer.create_server(port, ...)`.
  - Connection lifecycle moves to `peer_connected(id)` / `peer_disconnected(id)` signals.
  - Reserve this migration path; no code in v1.

### A.9 Risks added

| Risk | Source | Mitigation |
|------|--------|------------|
| Forgetting to call `poll()` deadlocks the daemon. | `websocket.rst`. | Wire `poll()` into the controller's `_process`; integration test asserts that frames flow within one editor tick. |
| Mixing text/binary semantics silently. | `websocket.rst` §"Minimal server example" uses `was_string_packet()`. | Read+stash in the same statement; never read after another read. |
| Slow polling backlogs large scene-tree responses. | Empirical. | Cap drain per tick; warn when queue depth crosses a watermark (`transport.queue_overflow` already reserved as `-33005`). |
| Firewall prompts on first run on Windows. | OS behavior. | Default loopback bind avoids it; document for users who need `0.0.0.0`. |
| WS message size limits. | `WebSocketPeer.max_queued_packets` / `inbound_buffer_size` / `outbound_buffer_size`. | Configure via project settings (add to `02 §2.6.6` follow-up: `server/inbound_buffer_size`, `server/outbound_buffer_size`, `server/max_queued_packets`). |

