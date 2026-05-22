# 07 — Headless Fallback (Phase 2, part C / coverage extension)

> **Goal**: give the router a **headless** path that lets it perform Godot operations *without a running editor*, by spawning Godot in `--headless` mode and driving it via JSON-RPC over stdio (or a short-lived local WS on a different port). The headless path is **modeled after the Coding-Solo upstream** and is the difference between "TerraVolt requires a developer to keep Godot open" and "TerraVolt can autonomously create, build, and verify projects from a CI runner or while the dev's editor is closed." It also unlocks ops that don't need the editor (running tests, importing assets, exporting builds, validating syntax).

---

## 7.1 Header

- **File:** `07-headless-fallback.md`
- **Purpose:** implement a headless Godot execution mode that is functionally equivalent — for as many ops as possible — to the live editor daemon path.

## 7.2 Phase placement

- Strictly part of **Phase 2** as the third leg (editor daemon path + tool factory + headless fallback). Some teams place it later; in TerraVolt it ships now because the **vibe coding** target requires Godot ops even when no editor is open.
- Gates Phase 3 jointly with `05`/`06` (Phase 3 tools will assume the fallback exists so they can declare which path they use).

## 7.3 Inputs / prerequisites

- `05` and `06` complete.
- Godot 4.x binary discoverable on the developer's machine.
- A "headless project" template (a minimal Godot project the router can use when no explicit project is open).

## 7.4 Outputs

After this file:

1. The router has a **headless driver** (`packages/mcp-server/src/headless/`) that can:
   - Locate the Godot binary (via env, config, or PATH).
   - Launch Godot with `--headless` against a target project.
   - Drive Godot through one of two transports — see §7.6.3.
   - Stream Godot's stdout/stderr through the structured logger.
   - Tear the subprocess down cleanly.
2. The router decides per-tool whether to use **editor daemon** or **headless** based on tool metadata (`requiresEditor`, fallback policy, runtime state).
3. The headless driver supports the same JSON-RPC ops the editor daemon exposes, **at least for the ops that don't require `EditorInterface`**. A **parity matrix** documents which ops are supported in each mode.
4. New tools `headless.start_project`, `headless.stop`, `headless.status` are exposed to MCP clients.
5. Headless-only utility tools land here: `headless.run_project`, `headless.export`, `headless.import_assets`, `headless.validate_script`, `headless.run_tests`. These are "always headless" even if the editor is open (faster, deterministic, sandboxed).
6. The dock in the addon (when editor is running) can show "Headless session active" if the router has launched one.
7. CI uses the headless path exclusively (file `10`'s test harness).

## 7.5 Operating constants used

| Constant | Value | Notes |
|----------|-------|-------|
| Default headless port (if WS strategy chosen) | `6506` | Reserved, never overlaps with editor `6505`. |
| Default headless subprocess timeout (boot) | `30s` | Configurable. |
| Default per-op timeout (headless) | `60s` | Often longer than editor (asset imports, exports). |
| Max concurrent headless sessions | `1` v1 | Multi-session deferred. |

---

## 7.6 Detailed task breakdown

### 7.6.1 Two scenarios for "headless"

Distinguish carefully:

1. **Editor is open** → Router prefers the daemon. Headless is used only for ops marked `headlessOnly` or for explicit `headless.*` tools.
2. **Editor is closed** → Router uses headless for everything that can run headless. Ops marked `requiresEditor: true` return a clear `editor.not_available` error suggesting the agent open the editor (via a `editor.open` tool if it exists, or by instructing the user).

The agent therefore has three modes:

- **Live editor + headless ops**: the most powerful; both paths usable.
- **Headless only**: most ops still possible, including game runs, asset imports, exports, syntax validation.
- **Disabled**: neither — error.

### 7.6.2 Godot binary discovery

Resolution order (first hit wins):

1. `--godot-binary` CLI flag.
2. `TERRAVOLT_GODOT_BINARY` env var.
3. `~/.terravolt-mcp.json` config file (per-user).
4. `PATH` lookup (`godot`, `godot4`, `Godot_v4.*` patterns).
5. Common install locations per OS (e.g., `/Applications/Godot.app/...`, `C:\Program Files\Godot\...`).

Document the resolution in the router README and in `--print-config`. On failure to locate, the router still starts; only headless tools fail with `headless.binary_missing` (new error code `-33810`).

### 7.6.3 Headless transport — choose one strategy

Two valid strategies:

- **Strategy A (preferred): subprocess stdio**. Godot is launched with `--headless` and a small driver script (bundled in the addon under `packages/godot-mcp-addon/headless/driver.gd`) that reads JSON-RPC from stdin and writes responses to stdout. The router pipes over the subprocess streams. **No port consumed; no WS server.** Modeled on Coding-Solo.
- **Strategy B: subprocess + WS on port `6506`**. Godot launches with the same plugin enabled but in headless mode, binding the daemon on a different port. Router connects as a second WS client. More uniform with the editor path but uses a port and re-launches a heavy startup path.

**Decision:** ship **Strategy A** in v1. Reserve Strategy B as an opt-in via `--headless-strategy=ws` for testing parity. Record the decision in `00 §0.13`.

### 7.6.4 Driver script (conceptual; lives inside the addon)

`packages/godot-mcp-addon/headless/driver.gd`:

- Runs at engine startup when invoked with `--script driver.gd`.
- Initializes a minimal version of `Dispatcher` and `Logger`.
- Reads JSON-RPC from stdin (line-delimited or `Content-Length` framed — pick line-delimited for simplicity, document choice).
- Writes responses to stdout, **with strict discipline**: only JSON-RPC frames on stdout; Godot's other prints go to stderr (Godot's default).
- Implements a subset of handlers that don't require `EditorInterface`: file ops, script syntax validation, project imports, run-and-report, etc.
- Exits cleanly when stdin closes.

This driver lives **in the addon package** (not the router) because the GDScript code matches the editor-side dispatcher. Both share `handlers/` modules where possible — the `requiresEditor` metadata flag controls which handlers are loaded.

### 7.6.5 Router-side headless driver

`packages/mcp-server/src/headless/driver.ts` exposes a programmatic API to other parts of the router:

- `start(projectPath, opts) → SessionHandle` — launches Godot with `--headless --script <addon-shipped driver>`, returns a handle.
- `call(handle, method, params, opts) → Promise<result>` — sends a JSON-RPC request over stdin; awaits a response with timeout.
- `notify(handle, method, params)` — fire-and-forget.
- `subscribe(handle, methodFilter, listener)` — observe `event.*` notifications.
- `status(handle) → {pid, uptime, queueDepth, lastStderrLines}`.
- `stop(handle, opts)` — graceful shutdown with grace period; SIGKILL fallback.

### 7.6.6 Routing policy: editor vs headless

Per tool, the router decides which transport to use:

1. If tool is **`headlessOnly`**: always headless.
2. If tool **`requiresEditor`**: always editor; error if editor unavailable.
3. Otherwise:
   - If editor daemon is `connected`: prefer editor.
   - Else if a headless session is running for the relevant project: use headless.
   - Else: spin up a headless session on demand (limited to one concurrent).

Per-tool policy can be overridden via `--prefer=headless` (testing).

### 7.6.7 Project resolution (which project to drive headless?)

A headless session is bound to one Godot project. The router resolves it by:

1. `--project` CLI flag.
2. `TERRAVOLT_PROJECT_PATH` env var.
3. If a Godot editor is currently running (detected by trying to connect to `:6505`), use *its* project path (via `server.info` extension).
4. Persistent last-used project (stored in `~/.terravolt-mcp.json`).
5. Otherwise, fail with `headless.no_project` (`-33811`).

### 7.6.8 New MCP tools shipped here

| Tool | Behavior |
|------|----------|
| `headless.start_project` | Spin up a headless session for a project. Inputs: `{ projectPath }`. Result: `{ sessionId, pid, godotVersion, ready: true }`. |
| `headless.stop` | Stop the active session. Inputs: `{ force?: bool }`. |
| `headless.status` | Returns session status: `{ alive, pid, uptimeMs, lastStderrTail, currentOp }`. |
| `headless.run_project` | Run the current project to completion or until a timeout. Inputs: `{ scene?: string, args?: string[], timeoutMs?: int, captureOutput?: bool }`. Result: `{ exitCode, stdout (truncated), stderr (truncated), durationMs }`. |
| `headless.export` | Export a build. Inputs: `{ preset: string, outputPath: string, debug?: bool }`. Returns artifact path & size. |
| `headless.import_assets` | Force re-import of assets, optionally with import presets. Inputs: `{ patterns?: string[], preset?: string }`. |
| `headless.validate_script` | Compile-check a GDScript or C# file. Inputs: `{ path: string }`. Result: `{ ok, errors?: [{line, col, message}] }`. |
| `headless.run_tests` | Run the addon's chosen test framework (GUT/gdUnit4). Inputs: `{ filter?: string }`. Result: `{ passed, failed, durationMs, report }`. |
| `headless.run_script` | Execute an arbitrary script file in a sandboxed run. Inputs: `{ path, args?: string[] }`. Used for orchestration; gated by a safety flag. |

All headless tools route through the headless driver and bypass the editor daemon entirely.

### 7.6.9 Sandbox & safety

- The headless driver runs as a normal user process; no privilege escalation.
- The router refuses to launch headless against project paths outside an allowlist if `--restrict-paths` is set (CI usage).
- Output capture has a max size; larger output is truncated with a pointer to a temp file path that the agent can fetch via `headless.fetch_artifact` (future tool, reserve name).
- `headless.run_script` is hidden behind `--allow-arbitrary-scripts` because it can execute anything. Default off.

### 7.6.10 Parity matrix vs editor mode

Document a table in `docs/catalog/parity.md` (generated from the shared registry). Categories of ops:

| Category | Editor support | Headless support | Notes |
|----------|----------------|------------------|-------|
| `scene` read | ✅ | ✅ | |
| `scene` write | ✅ | ✅ | use `PackedScene` save APIs |
| `node` DOM (read) | ✅ | ✅ | |
| `node` DOM (write) | ✅ | ✅ | via instantiated tree |
| `script` syntax check | ✅ | ✅ | preferred headless for speed |
| `script` editor undo/redo | ✅ | ❌ | editor-only |
| `signal` connect/list | ✅ | ✅ | |
| `resource` read/write | ✅ | ✅ | |
| `asset` import | ✅ | ✅ | headless preferred for batch |
| `runtime` start | ✅ | ✅ via `--headless` run | |
| `runtime` step / breakpoints | ✅ | ❌ | editor debugger required |
| `editor` UI ops | ✅ | ❌ | requires editor |
| `project` settings | ✅ | ✅ | |
| `input` map | ✅ | ✅ | |
| `animation` edit | ✅ | partial | some animation editors are editor-only |
| `physics` config | ✅ | ✅ | |
| `render` setup | ✅ | ✅ | |
| `audio` import | ✅ | ✅ | |
| `network` autoload check | ✅ | ✅ | |
| `debug` profiler | ✅ | partial | |
| `profile` snapshots | ✅ | partial | |
| `macro` orchestrations | ✅ | ✅ | depend on underlying ops |

Final exact columns come from `08`. Maintain this matrix per release.

### 7.6.11 Lifecycle

Boot of router with headless enabled:

1. Resolve Godot binary; warn if missing.
2. Resolve project path; warn if missing.
3. Do **not** spawn a session until a tool requests one (lazy).
4. On first tool that needs headless: spawn session; warm up; ready when driver echoes `headless.ready`.

Shutdown:

1. On router SIGTERM: send `dispatch.cancel` to in-flight ops; close stdin; wait `--headless-shutdown-grace-ms` (default 5s); SIGKILL.
2. On crash: child should terminate (we manage it).

### 7.6.12 Observability

- Headless stdout JSON-RPC frames are tee'd to the router's stderr logger (debug level).
- Headless stderr (Godot prints) is forwarded to the router's stderr logger at info level (per line) with subsystem `headless.engine`.
- Status tool shows last N lines and current op.
- Optional artifact directory (`--artifacts-dir`, default OS temp) collects build outputs, test reports, and crash dumps.

### 7.6.13 Manual smoke tests

1. With editor **closed**, run `tools.health`. Expect editor disconnected, headless ready (when invoked).
2. Call `headless.start_project` with a known project. Expect `ready:true`.
3. Call `headless.validate_script` on a well-formed script. Expect `ok:true`.
4. Call `headless.validate_script` on a script with a typo. Expect `ok:false` and errors with line/col.
5. Call `headless.run_project` on a project with a small autoexit scene. Expect `exitCode:0`.
6. Call `headless.export` for a configured preset. Expect artifact path and non-zero size.
7. Call `headless.stop`. Confirm `status` shows `alive:false`.
8. With editor **open**, call `headless.run_tests`. Expect headless spins up a second Godot process and runs tests; both editor and headless coexist.
9. Force-kill the editor mid-call. Confirm router falls back to headless if the tool allows.

---

## 7.7 Schemes / data shapes (no code)

### 7.7.1 Session model

| Field | Type | Notes |
|-------|------|-------|
| `id` | string (uuid) | |
| `pid` | int | |
| `projectPath` | string | |
| `godotVersion` | string | parsed from stderr banner |
| `startedAt` | ISO ts | |
| `state` | enum | `starting` / `ready` / `busy` / `closing` / `closed` / `errored` |
| `currentOp` | object? | method, started_at, request_id |
| `queueDepth` | int | |
| `lastStderrTail` | array | last 200 lines, ring buffer |

### 7.7.2 Subprocess framing

- Line-delimited JSON on stdin/stdout.
- Each line is one JSON-RPC message.
- Lines > 1 MiB rejected with `transport.unsupported_frame`.

### 7.7.3 Error codes added

| Code | Symbol | Meaning |
|------|--------|---------|
| `-33810` | `headless.binary_missing` | Godot binary not located. |
| `-33811` | `headless.no_project` | Project path could not be resolved. |
| `-33812` | `headless.spawn_failed` | OS-level spawn error. |
| `-33813` | `headless.driver_handshake_failed` | Driver did not say `headless.ready` within timeout. |
| `-33814` | `headless.session_busy` | A session is already running and `max=1`. |
| `-33815` | `headless.crashed` | Subprocess died unexpectedly. |
| `-33816` | `headless.timeout` | Op exceeded per-op timeout. |
| `-33817` | `headless.disallowed` | Path or operation not allowed (e.g., outside allowlist, arbitrary script not permitted). |

Mirror in `packages/shared/errors/registry.json`.

### 7.7.4 Routing policy table

| Tool flag | Editor open? | Action |
|-----------|--------------|--------|
| `requiresEditor` | yes | route editor |
| `requiresEditor` | no | error `editor.not_available` |
| `headlessOnly` | yes/no | route headless |
| neither | yes | route editor |
| neither | no | route headless (lazy spin) |

---

## 7.8 Tech stack delta vs `00 §0.10`

- No new runtime dependencies; uses Node's `child_process` and `readline`.
- Adds a small driver script in the addon (GDScript), bundled with the addon package.

---

## 7.9 Acceptance criteria

- [ ] Router resolves Godot binary by §7.6.2 order and logs the resolution.
- [ ] Strategy A (subprocess stdio) is the default headless transport.
- [ ] Headless session spawns within `30s` for a known project.
- [ ] `headless.*` tools listed in §7.6.8 all work.
- [ ] Routing policy from §7.6.6 honored.
- [ ] Parity matrix (§7.6.10) generated and accurate.
- [ ] New error codes (§7.7.3) added to the shared error registry.
- [ ] Session lifecycle robust to editor open/close and router restarts.
- [ ] Smoke tests in §7.6.13 pass.
- [ ] Decisions Log updated.

---

## 7.10 Verification plan

1. Smoke tests §7.6.13.
2. CI dry-run (placeholder for `10`): in a fresh container with only Godot binary and Node, the router can run `headless.run_tests` end-to-end.
3. Crash test: kill the headless process; confirm router surfaces `headless.crashed`, marks session closed, and a subsequent tool call lazily spawns a fresh session.
4. Routing test: enable editor, call a `requiresEditor` tool — expect editor route; disable editor, call same tool — expect `editor.not_available`.
5. Performance: measure cold-start time for `headless.start_project` on a small test project (target < 5s).

---

## 7.11 Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Godot binary not on PATH on CI runners. | Document `TERRAVOLT_GODOT_BINARY` strategy; CI sets it explicitly. |
| Headless driver and editor dispatcher drift in behavior. | Share handler modules where possible; the parity matrix is a CI artifact verified on each release. |
| Subprocess stdout pollution (Godot prints arbitrary text). | Strict line-delimited JSON-RPC; anything else goes to stderr by convention. |
| Long-running export blocks the session. | Per-op timeout; status tool reports current op so the agent doesn't double-dispatch. |
| Headless run of `run_project` may hang if the scene has no autoexit. | Hard timeout default; agent must opt-in to longer runs. |
| Arbitrary script execution risk. | Gated by `--allow-arbitrary-scripts`; off by default. |
| Multiple concurrent headless sessions desired. | v2 work; keep `max=1` for now; document upgrade path. |

---

## 7.12 Handoff checklist to file `08`

- [ ] Headless driver + router-side driver work for the ops you'd expect (file/script/runtime).
- [ ] Routing policy is in place; tools can declare `requiresEditor` / `headlessOnly`.
- [ ] Parity matrix is part of `docs/catalog/`.
- [ ] Headless error codes added to shared registry.
- [ ] CI can run `headless.run_tests` end-to-end (target verified, formal CI wiring in `10`).

When done, open **`08-toolset-implementation.md`**.

---

## Appendix A — Official Godot Docs alignment (added revision 2)

> Sourced from `tutorials/editor/command_line_tutorial.rst` and `tutorials/export/*`. This appendix enumerates the **exact** CLI flags the headless driver uses, plus tested invocation patterns.

### A.1 Headless invocation grammar (canonical)

```
godot --headless [--path <project_dir>] [--upwards] [--script <res-or-fs-path>]
       [--main-loop <ClassName>] [--scene <path>] [--check-only]
       [--main-pack <file.pck>] [--remote-fs <host[:port]>] [--remote-fs-password <pw>]
       [--rendering-method <forward_plus|mobile|gl_compatibility>]
       [--rendering-driver <driver>] [--gpu-index <n>]
       [--audio-driver <driver>] [--display-driver headless]
       [--log-file <abs-path>]
       [--quit] [--quit-after <iters>]
       [--build-solutions]
       [--import]
       [--export-release <preset> <out>] [--export-debug <preset> <out>]
       [--export-pack <preset> <out>] [--export-patch <preset> <out>] [--patches <p1,p2,...>]
       [--write-movie <out>] [--fixed-fps <fps>] [--disable-vsync]
       [--doctool <path>] [--gdscript-docs <path>] [--no-docbase]
       [--gdextension-docs] [--dump-extension-api] [--dump-extension-api-with-docs]
       [--validate-extension-api <prev.json>]
       [--dump-gdextension-interface] [--dump-gdextension-interface-json]
       [--benchmark] [--benchmark-file <abs.json>]
       [--test [--help]]
       [--verbose|-v] [--quiet|-q] [--no-header]
       [-- user_arg1 user_arg2 ...]
```

Engine-relevant constants:

- `--headless` ≡ `--display-driver headless --audio-driver Dummy`.
- User args following `--` are read inside scripts via `OS.get_cmdline_user_args()`; engine args via `OS.get_cmdline_args()`.
- Returned path semantics for `--export-*` are **relative to the project directory**, *not* the current working directory. Always pass absolute paths in TerraVolt's headless calls to avoid ambiguity.

### A.2 Driver script contract

Per `command_line_tutorial.rst` §"Running a script":

- The script passed to `--script` **must** `extends SceneTree` or `extends MainLoop`.
- Lifecycle: when the script extends `SceneTree`, `_init()` is the entrypoint, and `quit()` is required to terminate.
- When extending `MainLoop`, implement `_initialize()`, `_process(delta)`, `_finalize()`.
- TerraVolt's bundled driver (`packages/godot-mcp-addon/headless/driver.gd`) extends `SceneTree`; its `_init()` registers the JSON-RPC over stdin/stdout pipe and pumps the loop until stdin closes.
- For interactive headless sessions, keep the SceneTree alive (don't call `quit()`); rely on stdin EOF to exit.

### A.3 `--check-only` and script syntax validation

- Per `command_line_tutorial.rst`, `--check-only` only parses for errors and quits — perfect for `headless.validate_script` on `.gd` files.
- Combine with `--script <path>` to target a specific file.
- For `.cs` files, syntax checking goes through the C# compiler — invoke `godot --build-solutions --headless --quit` first (compile the whole project) and capture compile diagnostics from stderr; finer-grained per-file validation requires the C# toolchain directly.

### A.4 Asset import via headless

Per `command_line_tutorial.rst` and `tutorials/export/exporting_projects.rst`:

- `godot --headless --import --path <project>` imports all pending assets and exits. This implies `--editor --quit`.
- TerraVolt's `headless.import_assets` and `asset.batch_apply_preset` rely on this flag.
- Imports honor `.import/` metadata files and the editor's importer registry.

### A.5 Export pipeline — required setup

- `export_presets.cfg` must exist with named presets (e.g., `"Windows Desktop"`, `"Linux/X11"`, `"Android"`).
- Export templates must be installed on the runner (the editor downloads them; in CI, use the headless `--install-android-build-template` for Android specifically and `--import` to ensure resources are ready before export).
- `--export-release` paths: target directory **must exist** beforehand; TerraVolt creates it if missing.
- `--export-pack` accepts either `.pck` or `.zip` based on output extension.

### A.6 Multiple-instance runs

Per `command_line_tutorial.rst` and `tutorials/scripting/debug/overview_of_debugging_tools.rst` §"Customize Run Instances":

- Reserved for future multi-session headless: the editor supports running multiple project instances concurrently. TerraVolt v1 keeps `max=1`; v1.1+ may expose `headless.start_multi`.

### A.7 Remote filesystem and remote debug

- `--remote-fs <host[:port]>` allows the engine to serve project files over the network (useful for low-storage devices). Reserve a `--remote-fs-host` router flag that auto-passes this to the headless engine; out of scope for v1 but documented so an agent can request the integration in v1.1+.
- `--remote-debug <uri>` connects the engine's script debugger to a remote IDE. TerraVolt observes this only — it does not drive the script debugger over MCP.

### A.8 Render driver selection

- `--rendering-method forward_plus|mobile|gl_compatibility`: pick `gl_compatibility` for CI runners without strong GPU support. Default in headless: typically `forward_plus`, but if the runner lacks Vulkan/Metal, force `gl_compatibility`.
- `--gpu-index <n>`: useful on multi-GPU CI nodes; default `0`.

### A.9 Benchmarking & docs generation

- `--benchmark` + `--benchmark-file <abs.json>`: write JSON benchmark report. TerraVolt's perf suite (`10`) uses this for boot-time measurements.
- `--doctool <path>` / `--gdscript-docs <path>` / `--gdextension-docs`: generate API reference XML. Reserved for `headless.generate_docs` (future).
- `--dump-extension-api` / `--validate-extension-api`: useful when a project uses GDExtension. Reserved for `headless.validate_gdextension`.
- `--test`: requires an engine compiled with `tests=yes`; not applicable to user CI typically.

### A.10 Engine vs user args

- Arguments **before** `--` go to the engine.
- Arguments **after** `--` (or `++`) go to the running script/game via `OS.get_cmdline_user_args()`.
- `headless.run_script` exposes `args` as user-side arguments; TerraVolt's driver passes them after `--`.

### A.11 Self-contained mode and CI

- Sentinel file `._sc_` next to the editor binary enables portable mode. CI runners often benefit from this for hermetic builds.
- Document in `10` how to set up self-contained mode for the CI image.

### A.12 Process exit code semantics

- Exit code `0`: normal completion.
- Non-zero exit codes propagate from the engine (e.g., `--check-only` returns non-zero on parse failure, `--validate-extension-api` returns non-zero on incompatibility).
- TerraVolt's headless driver wraps the subprocess and translates non-zero codes into `headless.crashed` (`-33815`) **unless** the op's contract expects non-zero (validation ops surface the code in the result, not as an error).

### A.13 Risks added

| Risk | Mitigation |
|------|------------|
| Mixing `--editor` and `--headless` flags. | Driver only ever uses one of them per session; documented in `07 §A.1`. |
| Missing `--build-solutions` on C# projects breaks first run. | `headless.start_project` detects `.csproj`, runs build first, then proceeds. |
| Renderer selection fails on bare CI hosts. | Auto-detect: try `forward_plus`, fall back to `gl_compatibility` on Vulkan probe failure (logs the choice). |
| `--remote-fs` exposed by accident. | Off by default; gated behind a router flag with security warning in docs. |
| Engine version drift changes CLI flag set. | Pin a tested Godot minor in `02 §A.8`; CI matrix exercises N and N-1. |

