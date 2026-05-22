# MCP tools reference

**Source of truth:** `packages/shared/methods/registry.json` for daemon-bridged methods,
`packages/mcp-server/src/mcp/local_router_tool_defs.ts` +
`packages/mcp-server/src/mcp/register_headless_router_tools.ts` for the router-native tools. This
page is the operator-facing summary.

> Every tool returns the same MCP envelope: `{ ok: true, tool, method, latencyMs, result }` or
> `{ ok: false, message, app_code?, autoHeal?, … }`.

Catalog version: **`0.2.0`** (router `0.1.0`).  
Total tools: **12** — 3 daemon-bridged + 5 router-local + 4 headless.

## At a glance

| Tool                                                   | Category   | Where it runs                  | Requires editor    | Mutates        |
| ------------------------------------------------------ | ---------- | ------------------------------ | ------------------ | -------------- |
| [`ping`](#ping)                                        | `server`   | Daemon → fallback Headless TCP | No (with fallback) | No             |
| [`server.info`](#serverinfo)                           | `server`   | Daemon → fallback Headless TCP | No (with fallback) | No             |
| [`log.tail`](#logtail)                                 | `log`      | Daemon only                    | Yes                | No             |
| [`tools.list`](#toolslist)                             | `tools`    | Router-local                   | No                 | No             |
| [`tools.describe`](#toolsdescribe)                     | `tools`    | Router-local                   | No                 | No             |
| [`tools.metrics`](#toolsmetrics)                       | `tools`    | Router-local                   | No                 | No             |
| [`tools.bottlenecks`](#toolsbottlenecks)               | `tools`    | Router-local                   | No                 | No             |
| [`tools.health`](#toolshealth)                         | `tools`    | Router-local (probes daemon)   | No                 | No             |
| [`context.fetch_raw`](#contextfetch_raw)               | `tools`    | Router-local (proxies daemon)  | Yes (today)        | Caller-defined |
| [`headless.start_project`](#headlessstart_project)     | `headless` | Spawns Godot `--headless`      | No                 | No             |
| [`headless.status`](#headlessstatus)                   | `headless` | Router-local                   | No                 | No             |
| [`headless.stop`](#headlessstop)                       | `headless` | Router-local                   | No                 | Yes            |
| [`headless.validate_script`](#headlessvalidate_script) | `headless` | Spawns Godot `--headless`      | No                 | No             |

## Daemon-bridged tools

These tools target the WebSocket JSON-RPC daemon at `TERRAVOLT_GODOT_HOST:TERRAVOLT_GODOT_PORT`
(default `127.0.0.1:6505`). When `headlessFallback` is `true` and the WebSocket is unreachable, the
router spawns Godot `--headless` and replays the call (visible in the response as
`method: "<name>@headless"`).

### `ping`

JSON-RPC health check.

- **Input:** `{}`
- **Result:**
  ```jsonc
  {
    "ok": true,
    "daemonTs": 1748080500123,
    "roundTripMs": 4,
    "daemonResult": { "ok": true, "ts": 1748080500123 },
  }
  ```
- **Headless fallback:** yes (`ping@headless`).
- **Verified:** `tests/integration/mcp_e2e.test.mjs`.

```jsonc
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": { "name": "ping", "arguments": {} },
}
```

### `server.info`

Daemon identity + catalog metadata.

- **Input:** `{}`
- **Result (editor):**
  `{ name, addon_version, godot_version, catalog_version, registry_sha256, uptime_ms, listen_addr, supported_methods_count }`.
- **Result (headless fallback):** subset —
  `{ name: "terravolt-godot-headless", build_mode: "headless_tcp", catalog_version, registry_sha256, godot_version, supported_methods_count: 5 }`.
- **Headless fallback:** yes.

### `log.tail`

Tail the daemon log file (`user://mcp_log.txt`).

- **Input:**
  ```jsonc
  { "lines": 100, "level": "info" } // both fields optional
  ```

  - `lines`: integer `[1, 1000]`.
  - `level`: `"debug" | "info" | "warn" | "error"`.
- **Result:** array of structured log records.
- **Headless fallback:** no — requires editor session with the addon loaded.

## Router-local tools

These run inside the MCP router process. They never touch Godot directly except where noted
(`tools.health`, `context.fetch_raw`).

### `tools.list`

Enumerate every registered tool, with optional filters.

- **Input:**
  ```jsonc
  { "category": "headless", "safe": true } // both fields optional
  ```
- **Result:** array of `{ name, category, safe }`.

### `tools.describe`

Return full metadata + JSON Schemas for one tool.

- **Input:** `{ "name": "headless.validate_script" }`
- **Result:**
  ```jsonc
  {
    "kind": "local",
    "name": "headless.validate_script",
    "title": "Headless GDScript compile check",
    "description": "...",
    "category": "headless",
    "safe": true,
    "mutates": false,
    "requiresEditor": false,
    "requiresRuntime": false,
    "daemonMethod": null,
    "inputSchemaJson": { ... },
    "outputSchemaJson": { ... }
  }
  ```
- **Errors:** `tool.not_found` when the name is unknown.

### `tools.metrics`

Rolling per-tool telemetry (counts, latency, success rate). Window length is configurable via
`--metrics-window-sec` (default 300).

- **Input:** `{}`
- **Result:**
  ```jsonc
  {
    "windowSec": 300,
    "tools": {
      "ping": { "count": 12, "ok": 12, "avgMs": 5, "p95Ms": 8 },
      "headless.start_project": { "count": 1, "ok": 1, "avgMs": 1843, "p95Ms": 1843 },
    },
  }
  ```

### `tools.bottlenecks`

Tools ranked by rolling average latency. Pair with `tools.metrics` when an agent wants the slowest
ops first.

- **Input:** `{ "topN": 10 }` (default 10, clamped to `[1, 100]`).
- **Result:**
  ```jsonc
  {
    "topN": 10,
    "windowSec": 300,
    "items": [
      { "name": "headless.start_project", "avgMs": 1843, "count": 1 },
      { "name": "ping", "avgMs": 5, "count": 12 },
    ],
  }
  ```

### `tools.health`

End-to-end probe: AJV smoke + daemon `server.info` + catalog SHA parity + headless resolvability.

- **Input:** `{}`
- **Result (truncated):**
  ```jsonc
  {
    "checks": {
      "ajv_object_ok": true,
      "daemon_server_info_ok": true,
      "router_catalog_version": "0.2.0",
      "daemon_catalog_version": "0.2.0",
      "router_registry_sha256": "930063cfac74…",
      "daemon_registry_sha256": "930063cfac74…",
      "protocol_catalog_match": true,
      "protocol_catalog_mismatch_detected": false,
      "headless_godot_executable_resolvable": true,
      "headless_driver_gd_absolute": "H:\\...\\headless_driver.gd",
      "headless_tcp_session_alive": false,
      "pass": true,
    },
  }
  ```

A `pass: false` result with `protocol_catalog_mismatch_detected: true` means either router or addon
needs `npm run catalog:sync`.

### `context.fetch_raw`

Execute an arbitrary JSON-RPC method on the daemon and return the raw payload (no schema
validation). Useful for early access to daemon-only methods not yet wrapped as MCP tools.

- **Input:**
  ```jsonc
  { "method": "scene.get_open_path", "params": {} }
  ```
- **Result:** whatever the daemon returned (engine-shape).

## Headless tools

These tools manage a `--headless` Godot subprocess managed by `HeadlessCoordinator`. The driver is
`packages/godot-mcp-addon/headless/headless_driver.gd` — it does **not** require the addon to be
mounted in the target project.

Resolution order for the Godot binary: `--godot-binary` → `TERRAVOLT_GODOT_BINARY` → `PATH` →
platform install dirs (`%LOCALAPPDATA%\Programs\Godot\**` on Windows, `/Applications/Godot.app` on
macOS, `~/.local/share/godot/**` on Linux). On Windows the resolver prefers `*_console.exe` because
stderr (used for the port handshake) is reliable.

Resolution order for the project path: `headless.start_project.arguments.projectPath` → `--project`
→ `TERRAVOLT_PROJECT_PATH`.

### `headless.start_project`

Spawn a fresh headless TCP driver against the given project (or the configured project) and wait for
the port handshake.

- **Input:** `{ "projectPath": "C:\\path\\to\\my-godot-project" }` (optional — falls back to
  `TERRAVOLT_PROJECT_PATH` / `--project`).
- **Result:** `{ ready, alive, pid, host, port, projectPath, uptimeMs }`.
- **Errors:** `headless.binary_missing` (-33810), `headless.no_project` (-33811),
  `headless.spawn_failed` (-33812), `headless.driver_handshake_failed` (-33813).
- **Verified:** `tests/integration/mcp_e2e.test.mjs` (real Godot 4.6.3 stable mono).

### `headless.status`

Observability snapshot.

- **Input:** `{}`
- **Result:** `{ alive, pid, host, port, projectPath, uptimeMs }` or `{ alive: false }`.

### `headless.stop`

Terminate the headless subprocess.

- **Input:** `{ "force": false }` (when `true`, `SIGKILL`/`TerminateProcess`; otherwise `SIGTERM`).
- **Result:** `{ ok: true }`.

### `headless.validate_script`

GDScript compile check on a `.gd` file. Internally runs JSON-RPC `script.validate_syntax` against
the driver, which executes `GDScript.new().reload()` on the file contents.

- **Input:**
  ```jsonc
  {
    "path": "C:\\proj\\addons\\foo\\bar.gd", // absolute or res:// path
    "projectPath": "C:\\proj", // optional override
  }
  ```
- **Result on success:** `{ ok: true }`.
- **Result on failure:** `{ ok: false, errors: [{ line, col, message }, ...] }`.
- **Limitation:** GDScript only today; `.cs` parity will use Godot's `dotnet` pipeline (planned in
  §08).

## Error envelope

All daemon-bridged tools and the `headless.*` family share the same error shape:

```jsonc
{
  "ok": false,
  "message": "headless.binary_missing",
  "app_code": "headless.binary_missing",
  "hint": "...",
  "autoHeal": {
    "hint": "`headless.binary_missing` (-33810): Godot binary not located.",
    "steps": [
      "Run `npm run env:godot` and accept the candidate.",
      "Or set `TERRAVOLT_GODOT_BINARY` to an absolute path.",
    ],
  },
}
```

Disable `autoHeal` per process with `--disable-auto-heal`. Stable application error codes live in
`packages/shared/errors/registry.json` and are mirrored into
`packages/godot-mcp-addon/error_codes.gd`.

## See also

- `docs/guides/quick-start.md` — install & smoke test.
- `docs/guides/mcp-usage.md` — concrete Cursor / SDK invocation patterns.
- `docs/guides/godot-integration.md` — editor vs headless connection flow.
- `docs/guides/headless-only.md` — CI / no-editor mode.
- `docs/guides/troubleshooting.md` — failure modes → fixes.
- `docs/catalog/parity.md` — living editor/headless parity matrix.
