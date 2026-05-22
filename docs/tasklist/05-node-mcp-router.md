# 05 — Node MCP Router (Phase 2, part A)

> **Goal**: build the **Node.js TypeScript MCP server** that Cursor talks to over stdio, and that
> opens a persistent WebSocket client to the Godot daemon on `127.0.0.1:6505`. This file implements
> the _transport layer_ of the router — MCP server boot, stdio framing (via SDK), WS client +
> reconnect, JSON-RPC framing helpers, request correlation, and a built-in **ping** tool that proves
> end-to-end round-trip. Tool registration mechanics, schema validation, and the broad tool catalog
> land in `06` and `08`.

---

## 5.1 Header

- **File:** `05-node-mcp-router.md`
- **Purpose:** wire the Node MCP router up to Cursor and the Godot daemon with minimal tools; prove
  end-to-end transport.

## 5.2 Phase placement

- **Phase 2, part A.** Pairs with `06` to complete Phase 2.
- Gates Phase 3 jointly with `06`.

## 5.3 Inputs / prerequisites

- Phase 1 fully complete (files `02`/`03`/`04`).
- Godot daemon listens on `127.0.0.1:6505` and answers `ping`.
- `packages/mcp-server/` skeleton from `01` exists with README.

## 5.4 Outputs

After this file:

1. `packages/mcp-server/` is a real TypeScript Node project that builds cleanly with `tsc`.
2. The router exposes itself as an **MCP server over stdio** using `@modelcontextprotocol/sdk`.
3. The router opens a persistent **WebSocket client** to the Godot daemon, with reconnect loop,
   exponential backoff, and heartbeat.
4. A **`ping`** MCP tool is exposed to Cursor. When called, the router sends JSON-RPC `ping` to the
   daemon and returns the round-trip result.
5. A second tool **`server.info`** is exposed (passthrough).
6. A third tool **`log.tail`** is exposed (passthrough; useful for the agent to inspect daemon
   logs).
7. The router validates daemon responses, normalizes errors, and **never writes to stdout** except
   as MCP frames (so MCP framing is never corrupted).
8. The router logs to **stderr** in structured JSON.
9. Cursor (or any MCP client) can `npx`/`node`-launch the router and complete a `ping` round-trip.

## 5.5 Operating constants used

| Constant               | Value                       | From      |
| ---------------------- | --------------------------- | --------- |
| Daemon address         | `127.0.0.1:6505` by default | `00 §0.3` |
| Heartbeat interval     | `15000ms` default           | `00 §0.3` |
| Heartbeat timeout      | `45000ms` default           | `00 §0.3` |
| Reconnect backoff base | `500ms`, capped `30000ms`   | `00 §0.3` |
| Max request payload    | soft `4 MiB`, hard `16 MiB` | `00 §0.3` |

No new constants introduced.

---

## 5.6 Detailed task breakdown

### 5.6.1 Project manifest finalization

Update `packages/mcp-server/`:

- **Manifest fields (planned in `01 §1.6.3`):**
  - `name`: tentative `@terravolt/godot-mcp` — finalize once npm name availability is checked. If
    unavailable, fall back to `terravolt-godot-mcp` and record decision in `00 §0.13`.
  - `version`: `0.1.0`.
  - `type`: `module` (ESM).
  - `engines.node`: `>=20.10`.
  - `bin`: a single executable name (suggestion: `terravolt-godot-mcp`).
  - `main`: the compiled entry (e.g., `dist/index.js`).
  - `exports`: ESM map.
- **Runtime dependencies:**
  - `@modelcontextprotocol/sdk` (latest stable at impl time; pin minor).
  - `ws` (latest stable; pin minor).
  - JSON Schema validator (recommendation: `ajv` + `ajv-formats`).
  - A lightweight CLI arg parser (built-in `node:util.parseArgs` is sufficient — no extra dep).
  - No logger dependency; emit JSON to stderr by hand.
- **Dev dependencies:**
  - `typescript`, `@types/node`, `@types/ws`.
  - ESLint with TS plugin; Prettier (root).
  - Test runner: prefer **Node built-in test runner** (`node --test`) for v1 to avoid extra deps;
    revisit in `10`.

### 5.6.2 TypeScript configuration

- `strict: true`, `noUncheckedIndexedAccess: true`, `noImplicitOverride: true`,
  `exactOptionalPropertyTypes: true`.
- `module: "nodenext"`, `moduleResolution: "nodenext"`, `target: "es2022"`.
- `outDir: "dist"`, `rootDir: "src"`, `sourceMap: true`, `declaration: true`.
- No `any` without `// eslint-disable-next-line` and a justification comment.

### 5.6.3 Source layout (finalize from `01 §1.6.3`)

```text
packages/mcp-server/src/
  index.ts                  (entry: argv parse, boot, lifecycle)
  config.ts                 (env + argv parsing, defaults)
  logger.ts                 (stderr JSON logger)
  diagnostics/
    errors.ts               (TerraVolt error code mirror; consumed by 06/09)
    map_godot_error.ts      (translates daemon errors → MCP-friendly shape — final in 09)
  transport/
    mcp_stdio.ts            (binds @modelcontextprotocol/sdk to stdio)
    godot_ws_client.ts      (persistent WS to daemon, reconnect, heartbeat)
  jsonrpc/
    framing.ts              (request id alloc, serialization, parsing)
    pending.ts              (correlation map, timeouts)
  tools/
    registry.ts             (tool registration mechanism — final in 06)
    builtin/
      ping.ts               (the proving tool)
      server_info.ts        (passthrough)
      log_tail.ts           (passthrough)
  headless/
    driver.ts               (stub here; real impl in 07)
```

This file ships everything **outside** `tools/` plus the three built-ins listed.

### 5.6.4 Entry, lifecycle, and argv

The router accepts:

| Flag / env                              | Default             | Purpose                                |
| --------------------------------------- | ------------------- | -------------------------------------- |
| `--godot-host` / `TERRAVOLT_GODOT_HOST` | `127.0.0.1`         | Daemon host.                           |
| `--godot-port` / `TERRAVOLT_GODOT_PORT` | `6505`              | Daemon port.                           |
| `--connect-timeout-ms`                  | `5000`              | First-attempt connect timeout.         |
| `--heartbeat-interval-ms`               | `15000`             | Override heartbeat.                    |
| `--heartbeat-timeout-ms`                | `45000`             | Override timeout.                      |
| `--reconnect-base-ms`                   | `500`               | Backoff base.                          |
| `--reconnect-max-ms`                    | `30000`             | Backoff cap.                           |
| `--log-level` / `TERRAVOLT_LOG_LEVEL`   | `info`              | `debug`/`info`/`warn`/`error`.         |
| `--request-timeout-ms`                  | `30000`             | Per-RPC default.                       |
| `--max-payload-bytes`                   | `4_194_304` (4 MiB) | Soft cap.                              |
| `--enable-headless-fallback`            | `false`             | Toggle for `07`.                       |
| `--token` / `TERRAVOLT_TOKEN`           | unset               | Auth token for daemon.                 |
| `--version`                             | —                   | Print version & exit.                  |
| `--print-config`                        | —                   | Echo resolved config to stderr & exit. |

Lifecycle:

1. Parse argv + env. Validate. On failure, print structured JSON error to stderr and exit non-zero.
2. Initialize logger.
3. Initialize MCP server (stdio).
4. Initialize Godot WS client (start connect attempt; do not block tool registration).
5. Register built-in tools (§5.6.7).
6. Begin MCP loop (stdio).
7. On signals (`SIGINT`, `SIGTERM`): drain in-flight RPCs (best effort, bounded by
   `--request-timeout-ms`), close WS, exit `0`.

### 5.6.5 MCP stdio transport

- Use `@modelcontextprotocol/sdk` to bind a server to stdio.
- Server identity: `name`, `version`, server-side capabilities advertised (resources/prompts may be
  added later; this file ships **tools** only).
- **Stdout discipline:** nothing other than MCP-framed messages goes to stdout. All logging goes to
  stderr. Add a lint rule (ESLint custom or `no-console` with allowed `console.error`-only) to
  enforce this.
- The MCP "tools" capability lists at least the three built-ins. Schemas are inline in this file
  (described, not coded).

### 5.6.6 Godot WS client (persistent)

Behavior:

1. On startup, attempt to connect to `ws://<host>:<port>` (no path required).
2. On success: log `transport.connected`, mark router state `connected`.
3. On failure: schedule reconnect with exponential backoff (`base * 2^attempts` capped at `max`).
   Backoff resets to `base` after any successful connection that lasts ≥ 30 seconds.
4. Open one connection at a time. If a connection is already open, additional connect attempts are
   no-ops.
5. **Heartbeat**: send native WS ping every `heartbeat_interval_ms`. If
   `(now - last_pong) > heartbeat_timeout_ms`, force-close and reconnect.
6. **Outbound frames**: serialize a JSON-RPC request, append to a small in-memory outbound queue,
   and write directly when the socket is open. If the socket is not open, queue with a per-tool TTL
   (default 5s) and reject queued items on TTL with `transport.not_connected`.
7. **Inbound frames**: parse JSON, route to the correlation map (`pending.ts`) by `id`.
   Notifications go to a notification subscriber list.
8. **Errors**: any framing or parsing error logs a structured warning and (when severe) closes +
   reconnects.

### 5.6.7 Built-in tools (this file's three)

#### `ping`

- **Description (for MCP):** "Health check; returns daemon round-trip latency and timestamp."
- **Input schema:** no parameters.
- **Behavior:** sends JSON-RPC `ping` to the daemon; returns `{ ok, daemonTs, roundTripMs }`.
- **Errors:** if daemon disconnected → return a `transport.not_connected` error envelope.

#### `server.info`

- **Description:** "Daemon identity, addon/engine versions, uptime, listen address, supported method
  count."
- **Input schema:** no parameters.
- **Behavior:** passthrough to daemon `server.info`; result returned verbatim.

#### `log.tail`

- **Description:** "Tail the daemon's structured log."
- **Input schema:**
  `{ lines?: integer (1..1000, default 100), level?: "debug"|"info"|"warn"|"error" }`.
- **Behavior:** passthrough to daemon `log.tail`; result returned verbatim.

These three tools are enough to prove Phase 2.

### 5.6.8 Request correlation & timeouts

- Each outbound JSON-RPC request gets a unique `id` (e.g., monotonic integer, scoped per process).
- The correlation map (`pending.ts`) stores `{id → {resolve, reject, deadline, method}}`.
- Default per-request timeout: `--request-timeout-ms` (30s). Individual tools may override (later).
- On timeout: reject with `dispatch.timeout` (use code `-33999` until a dedicated code is added) and
  log a warning; the response, if it ever arrives, is dropped with an info log.

### 5.6.9 Error normalization (light pass; full in `09`)

For now:

- If the daemon returns a JSON-RPC error envelope, translate to an MCP tool error with the `data`
  envelope preserved so the agent sees the `app_code`, `category`, `hint`.
- If the router itself fails (no daemon, parse error), return an MCP tool error with
  `app_code = transport.*` and a clear hint.

Full diagnostic mapping (including auto-healing suggestions) is in `09`.

### 5.6.10 Logging (router-side)

- One log line per record, JSON, to **stderr**.
- Schema (mirror of daemon's):
  `{ts, level, subsystem, event, peer? (n/a here), request_id?, method?, code?, message?, fields?}`.
- Subsystems: `router`, `transport`, `mcp`, `tool`, `dispatch`.
- Level controllable via `--log-level`.
- Optional file sink in a future phase; **not** in v1.

### 5.6.11 Configuration precedence

CLI flags > environment variables > defaults. The resolved config is rendered when `--print-config`
is passed.

### 5.6.12 Manual smoke tests for this phase

1. Start the Godot daemon (addon enabled).
2. Run the router from a terminal with `--log-level=debug`. Confirm `transport.connected` log on
   stderr.
3. Use an MCP-aware client (e.g., Cursor) or a mock MCP client to call the `ping` tool. Expect
   `{ ok, daemonTs, roundTripMs }`.
4. Call `server.info`. Confirm Godot/addon versions are surfaced.
5. Call `log.tail`. Confirm at least one record returns.
6. Stop the Godot daemon (disable the plugin). Confirm router logs `transport.disconnected` and
   starts reconnecting with backoff.
7. Call `ping` while disconnected. Expect a `transport.not_connected` error.
8. Re-enable plugin. Confirm router reconnects and `ping` succeeds again.
9. Send `SIGTERM` to the router. Confirm graceful shutdown (no zombie connections).
10. Try launching with a wrong port (e.g., `--godot-port=6506`). Confirm clean errors and retries.

---

## 5.7 Schemes / data shapes (no code)

### 5.7.1 Router state machine

```text
  ┌──────────┐ connect()  ┌──────────────┐  open  ┌────────────┐  pong stale  ┌────────────┐
  │ starting │───────────►│ connecting   │───────►│ connected  │─────────────►│ unhealthy  │
  └──────────┘            └──────┬───────┘        └─────┬──────┘              └──────┬─────┘
                                  │                     │ stop / SIGTERM             │
                                  │ error               ▼                            │
                                  └────────────► ┌────────────┐ backoff ◄────────────┘
                                                 │ retrying   │
                                                 └────────────┘
```

### 5.7.2 Outbound queue policy

- Bounded queue per connection (e.g., 1024 entries).
- Drop oldest with `transport.queue_overflow` if full.
- Queue drained on `open`; cleared on `close`.

### 5.7.3 MCP tool registration shape

For each tool the router exposes to Cursor:

| Field             | Purpose                                                                     |
| ----------------- | --------------------------------------------------------------------------- |
| `name`            | e.g., `ping`.                                                               |
| `title`           | Human-friendly.                                                             |
| `description`     | Specific; Cursor routes on description.                                     |
| `inputSchema`     | JSON Schema. Validated **before** dispatching to daemon.                    |
| `outputSchema`    | Optional but recommended.                                                   |
| `handler`         | Function from input → MCP tool result.                                      |
| `category`        | One of the categories from `00 §0.8`.                                       |
| `requiresEditor`  | bool.                                                                       |
| `requiresRuntime` | bool.                                                                       |
| `safe`            | bool — informational; "safe" tools can be executed automatically by agents. |

(Final tool catalog populated in `06`/`08`; this file only ships three.)

### 5.7.4 Correlation map shape

`pending: Map<id, { resolve, reject, deadline, method, startedAt }>` — eviction on response or
timeout.

### 5.7.5 Configuration shape

Single immutable `Config` object built once at startup, passed to subsystems. Hot-reload of config
is **not** supported in v1; the router restarts to apply changes.

---

## 5.8 Tech stack delta vs `00 §0.10`

- Adds `ajv` (and `ajv-formats`) as the JSON Schema validator on the router side.
- Confirms ESM-only build, Node built-in test runner for v1.

---

## 5.9 Acceptance criteria

- [x] `packages/mcp-server/` builds with `npm run build:server`.
- [x] `packages/mcp-server/` typechecks (`npm run typecheck`).
- [x] `ping`, `server.info`, `log.tail` tools registered with valid JSON schemas.
- [x] Router connects to the daemon and survives daemon restarts via reconnect + backoff.
- [x] Heartbeat works; unhealthy connections are detected and recycled.
- [x] No stdout pollution; all logs go to stderr.
- [x] CLI flags and env vars from §5.6.4 honored.
- [ ] Smoke tests in §5.6.12 pass (manual operator checklist; CI covers `--version` /
      `--print-config`).
- [x] Decisions Log updated.

---

## 5.10 Verification plan

1. Smoke tests §5.6.12.
2. Mini integration: launch the router under a generic MCP client (e.g., the SDK's example client or
   Cursor itself), enumerate tools, and call each of the three.
3. Stress mini-test: call `ping` 1000 times in a loop; verify no leaks (process RSS stable, no
   growing pending map).
4. Reconnect test: kill the editor and confirm backoff sequence; restart editor and confirm
   reconnection within `reconnect-max-ms`.
5. Log audit: confirm no `console.log` calls in the source (lint rule enforces).

---

## 5.11 Risks & mitigations

| Risk                                            | Mitigation                                                                          |
| ----------------------------------------------- | ----------------------------------------------------------------------------------- |
| stdout pollution from accidental `console.log`. | Lint rule + integration test that asserts stdout produces only MCP-framed messages. |
| Reconnect storms hammer the daemon.             | Exponential backoff (already specified); never below `base`.                        |
| MCP SDK version drift breaks framing.           | Pin minor version; integration smoke test in CI.                                    |
| Long-running requests block heartbeats.         | Heartbeat runs on its own timer, independent of request queues.                     |
| Pending map leak on misbehaving daemon.         | Per-request timeout; sweep for expired entries every second.                        |
| Misconfigured port silently fails.              | Always log effective config at startup; `--print-config` available.                 |

---

## 5.12 Handoff checklist to file `06`

- [ ] Three built-in tools live end-to-end (requires running Godot daemon + plugin).
- [x] WS client robust to disconnect/reconnect.
- [x] Router source layout established under `packages/mcp-server/src/`.
- [x] Tool registration mechanism exists in `tools/registry.ts` (even if minimal).
- [x] Diagnostic envelope from daemon is preserved in MCP tool errors.

When done, open **`06-tool-translation-layer.md`**.

---

## Appendix A — Official Godot Docs alignment (added revision 2)

> Sourced from `tutorials/networking/websocket.rst`, `tutorials/editor/command_line_tutorial.rst`,
> and `tutorials/scripting/c_sharp/*`. Anchors the router to engine specifics around the WS daemon
> and project lifecycle.

### A.1 Router-side WS client expectations (matching Godot 4 server semantics)

Per `websocket.rst` minimal client example, the Godot daemon expects standard WebSocket framing:

- Opening handshake: vanilla HTTP `Upgrade: websocket`. No custom subprotocol required; `ws` library
  defaults are fine.
- **Text frames** for JSON-RPC. Use `WebSocket.send(text, { binary: false })` (or library
  equivalent) — the daemon disambiguates with `was_string_packet()`.
- **Binary frames** are reserved (e.g., future file transfer). v1 router never sends binary.
- Close codes per Appendix `03 §A.6` — router should log close code/reason if non-1000.

### A.2 Router-side heartbeat strategy

Aligns with `03 §A.5`:

- Default `heartbeat_mode = "rpc"`: router sends JSON-RPC `server.heartbeat` request at
  `heartbeat_interval_ms`; expects a `pong:true` result within `heartbeat_timeout_ms`.
- Optional control-frame ping: `ws` library supports automatic pings via
  `WebSocket({ pingInterval, pingTimeout })` — wire as a fallback when `heartbeat_mode = "both"`.
- Pong arrival resets the dead-line timer; missed pongs ⇒ socket close + reconnect.

### A.3 Daemon-discovery helpers

When the router can't immediately reach the daemon, helpful CLI flags exposed for users:

- `--print-config` already specified; add `--probe-daemon` (planned) which tries one connect attempt
  with a short timeout and exits with a code reflecting success — useful for shell scripts and CI
  gating.
- Reserve future flags: `--daemon-spawn-editor <path>` to auto-launch the editor with a project, and
  `--daemon-spawn-headless` to fall back to headless (`07`).

### A.4 .NET / C# considerations

Per `tutorials/scripting/c_sharp/index.rst` and the `command_line_tutorial.rst` `--build-solutions`
flag:

- If the user project uses C#, the addon (still GDScript-only on TerraVolt's side) must coexist with
  a project that requires `--build-solutions` for the editor to enable C# scripts.
- `headless.validate_script` for `.cs` files must invoke Godot with `--build-solutions` once, then
  `--check-only` against the file path. Reserve this complication for `07`.
- The router does not directly interact with C# tooling; it only routes ops to the daemon, which
  uses `EditorInterface` regardless of language.

### A.5 Router-side configuration knobs (additions)

Reflect engine-level knobs the user may want to surface from the router as well:

- `--engine-args "<args>"` — passthrough arguments for any spawned Godot subprocess (used by `07`'s
  headless driver). Quoted JSON-friendly.
- `--debug-server <uri>` — when provided, the router exposes it via `server.info` so agents know
  where the engine debug server (DAP/LSP) is reachable. TerraVolt does **not** drive DAP/LSP itself
  in v1; these belong to the agent's IDE.
- `--dap-port <int>`, `--lsp-port <int>` — observation-only fields surfaced in `server.info` if the
  daemon reports them via a future `server.list_endpoints` op.

### A.6 Reserved future MCP-side endpoints

Map of editor endpoints the router might _report_ (not drive) for completeness:

| Endpoint                          | Source           | Field on `server.info`   |
| --------------------------------- | ---------------- | ------------------------ |
| GDScript Debug Adapter Protocol   | `--dap-port`     | `endpoints.dap_port`     |
| GDScript Language Server Protocol | `--lsp-port`     | `endpoints.lsp_port`     |
| Remote debug server               | `--debug-server` | `endpoints.debug_server` |
| TerraVolt MCP WebSocket           | this file        | `endpoints.terravolt_ws` |

The agent can read these to coordinate with the IDE if it wishes.

### A.7 stdout discipline reaffirmed

- The Node MCP SDK uses stdin/stdout as its transport — **nothing else** may write to stdout.
- ESLint custom rule: forbid `console.log` and bare `process.stdout.write` in
  `packages/mcp-server/src/`. The only `process.stdout.write` allowed lives inside the SDK transport
  adapter.
- Integration test: pipe stdout into a JSON-RPC parser; the parser must succeed on every line.

### A.8 Risks added

| Risk                                                                                             | Mitigation                                                                                                                                          |
| ------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| User connects router to a daemon running a different Godot minor — schema mismatch.              | `server.info.godot_version` + `catalog_version` checked on connect; warn if Godot minor differs from the tested minor noted in `02 §A.8`.           |
| Router runs against a project with `.cs` autoload that hasn't been built — daemon never enables. | Router emits `editor.solutions_unbuilt` diagnostic (new code `-33402`, reserve) when `server.info` reports `c_sharp: true, solutions_built: false`. |
| Daemon emits notifications faster than agent can consume.                                        | Per-method rate limits from `06`; router additionally enforces a global notifications-per-second cap.                                               |
