# `@terravolt/godot-mcp` — Node MCP router

The Terravolt MCP server. **Stdio** in (Cursor / any MCP client) and **WebSocket JSON-RPC 2.0** out
to the Godot daemon on `127.0.0.1:6505`, with a `--headless` TCP fallback for the registry rows that
mark `headlessFallback: true`.

Operator-level docs:

- **[`../../docs/guides/quick-start.md`](../../docs/guides/quick-start.md)** — first install +
  Cursor wiring.
- **[`../../docs/guides/mcp-usage.md`](../../docs/guides/mcp-usage.md)** — `tools/call` payload
  shapes.
- **[`../../docs/guides/tools-reference.md`](../../docs/guides/tools-reference.md)** — every tool,
  every field.
- **[`../../docs/guides/godot-integration.md`](../../docs/guides/godot-integration.md)** — editor vs
  headless flow.

Task references:
**[`docs/tasklist/05-node-mcp-router.md`](../../docs/tasklist/05-node-mcp-router.md)**,
**[`06-tool-translation-layer.md`](../../docs/tasklist/06-tool-translation-layer.md)**,
**[`07-headless-fallback.md`](../../docs/tasklist/07-headless-fallback.md)**,
**[`09-context-and-error-optimization.md`](../../docs/tasklist/09-context-and-error-optimization.md)**.

## CLI

After `npm run build:server` from the repo root:

```bash
node packages/mcp-server/dist/index.js --version
node packages/mcp-server/dist/index.js --print-config
```

Global install / `npx` use the **`terravolt-godot-mcp`** bin (see `package.json`).

## Flags / env vars

| Flag                         | Env var                              | Default           | Notes                                 |
| ---------------------------- | ------------------------------------ | ----------------- | ------------------------------------- | -------- | ---- | ------- |
| `--godot-host`               | `TERRAVOLT_GODOT_HOST`               | `127.0.0.1`       | Daemon WS bind.                       |
| `--godot-port`               | `TERRAVOLT_GODOT_PORT`               | `6505`            | Daemon WS port.                       |
| `--connect-timeout-ms`       | —                                    | `5000`            | Initial WS handshake.                 |
| `--request-timeout-ms`       | —                                    | `30000`           | Per JSON-RPC request.                 |
| `--heartbeat-interval-ms`    | `TERRAVOLT_HEARTBEAT_INTERVAL_MS`    | `15000`           | WS ping cadence.                      |
| `--heartbeat-timeout-ms`     | `TERRAVOLT_HEARTBEAT_TIMEOUT_MS`     | `45000`           | Pong watchdog.                        |
| `--reconnect-base-ms`        | —                                    | `500`             | Exp. backoff base.                    |
| `--reconnect-max-ms`         | —                                    | `30000`           | Exp. backoff cap.                     |
| `--max-payload-bytes`        | —                                    | `4 * 1024 * 1024` | WS frame size cap.                    |
| `--log-level`                | `TERRAVOLT_LOG_LEVEL`                | `info`            | `debug                                | info     | warn | error`. |
| `--token`                    | `TERRAVOLT_TOKEN`                    | unset             | Optional auth token.                  |
| `--notifications`            | —                                    | `all`             | `all                                  | events`. |
| `--godot-binary`             | `TERRAVOLT_GODOT_BINARY`             | resolver          | Absolute path for headless spawn.     |
| `--project`                  | `TERRAVOLT_PROJECT_PATH`             | unset             | Headless project root.                |
| `--headless-boot-timeout-ms` | `TERRAVOLT_HEADLESS_BOOT_TIMEOUT_MS` | `30000`           | Driver handshake timeout.             |
| `--headless-op-timeout-ms`   | `TERRAVOLT_HEADLESS_OP_TIMEOUT_MS`   | `60000`           | Per-RPC timeout.                      |
| `--metrics-window-sec`       | `TERRAVOLT_METRICS_WINDOW_SEC`       | `300`             | Rolling metrics window.               |
| `--disable-auto-heal`        | —                                    | off               | Drop `autoHeal` payloads from errors. |

## Registered MCP tools

Source of truth: `packages/shared/methods/registry.json` (daemon-bridged) plus
`src/mcp/local_router_tool_defs.ts` and `src/mcp/register_headless_router_tools.ts` (router-native).

### Daemon-bridged (via shared catalog)

| MCP tool      | Daemon JSON-RPC | Headless fallback     | Notes                                          |
| ------------- | --------------- | --------------------- | ---------------------------------------------- |
| `ping`        | `ping`          | yes (`ping@headless`) | Round-trip `{ daemonTs, roundTripMs }`.        |
| `server.info` | `server.info`   | yes                   | Includes `catalog_version`, `registry_sha256`. |
| `log.tail`    | `log.tail`      | no                    | Editor-only; tails `user://mcp_log.txt`.       |

### Router-only

| Tool                | Purpose                                                                  |
| ------------------- | ------------------------------------------------------------------------ |
| `tools.list`        | Enumerate tools (`category`, `safe` filters).                            |
| `tools.describe`    | Single-tool metadata + schemas.                                          |
| `tools.metrics`     | Per-tool counters + latency.                                             |
| `tools.bottlenecks` | Tools ranked by avg latency (`topN`).                                    |
| `tools.health`      | AJV smoke + daemon `server.info` + catalog SHA + headless resolvability. |
| `context.fetch_raw` | Run an arbitrary JSON-RPC method on the daemon (raw passthrough).        |

### Headless lifecycle

| Tool                       | Purpose                                                                 |
| -------------------------- | ----------------------------------------------------------------------- |
| `headless.start_project`   | Spawn `godot --headless --script headless_driver.gd` against a project. |
| `headless.status`          | Live session snapshot.                                                  |
| `headless.stop`            | SIGTERM / SIGKILL the session.                                          |
| `headless.validate_script` | GDScript compile check via `script.validate_syntax`.                    |

Daemon-backed tool inputs are AJV-validated against the registry `inputSchema` before dispatch.

## Cancellation (best-effort)

When MCP passes an aborted signal into a tool handler, the router rejects the in-flight JSON-RPC
request and sends `dispatch.cancel` `{ "target_id": <id> }` to the daemon (notification). The daemon
should treat this as cooperative cancellation where supported.

## Shared registry lookup

Resolution order for `packages/shared/methods/registry.json`:

1. `TERRAVOLT_METHOD_REGISTRY_JSON` — absolute path override (packaging / CI fixtures).
2. Walk `process.cwd()` ancestors, then ancestors of the compiled module — covers `npm run` from the
   monorepo root and running `dist/index.js` directly.

The helper accepts either a `file://` URL or an absolute path so a future caller can't accidentally
re-trigger the Windows `ERR_INVALID_URL_SCHEME` crash that the real-MCP smoke caught (commit
`22d5c5c`).

## Catalog sync (Godot side)

After editing `packages/shared/methods/registry.json`, run:

```bash
npm run catalog:sync
```

This regenerates `packages/godot-mcp-addon/_generated/catalog_meta.gd` so `server.info` and
`tools.health` stay aligned with the router's registry hash.

## Tests

```bash
npm run test:server
```

11 tests: CLI smoke (2), unit (6), real-Godot integration (3). The three integration tests auto-skip
when `TERRAVOLT_GODOT_BINARY` is unset.

## Layout

| Path                                        | Role                                                     |
| ------------------------------------------- | -------------------------------------------------------- |
| `src/index.ts`                              | `--version`, config, lifecycle.                          |
| `src/transport/mcp_stdio.ts`                | MCP SDK + tool registration + bridging.                  |
| `src/transport/godot_ws_client.ts`          | WS client, reconnect, heartbeat.                         |
| `src/headless/headlessCoordinator.ts`       | Session manager.                                         |
| `src/headless/headlessSession.ts`           | Spawn + port handshake.                                  |
| `src/headless/headlessTcpClient.ts`         | TCP JSON-RPC client.                                     |
| `src/headless/godotBinary.ts`               | Cross-platform resolver.                                 |
| `src/catalog/loadRegistry.ts`               | Loads shared `methods/registry.json`.                    |
| `src/catalog/repoRoot.ts`                   | URL-or-path tolerant root resolver.                      |
| `src/mcp/register_daemon_bridge.ts`         | Daemon-bridged tools + headless fallback.                |
| `src/mcp/register_router_only_tools.ts`     | `tools.*`, `context.fetch_raw`.                          |
| `src/mcp/register_headless_router_tools.ts` | `headless.*` lifecycle.                                  |
| `src/telemetry/metrics.ts`                  | Rolling counters + bottlenecks.                          |
| `src/diagnostics/autoheal_hints.ts`         | `autoHeal` resolver.                                     |
| `tests/integration/*.test.mjs`              | Real-Godot smoke (`mcp_e2e`, `addon_parse`, `headless`). |
| `tests/unit/*.test.mjs`                     | Pure-Node unit coverage.                                 |
| `tests/smoke.test.mjs`                      | CLI `--version` + `--print-config`.                      |

Operational constants (`:6505`, heartbeat defaults, payload caps) remain in
**[`docs/tasklist/00-foundation-and-contracts.md`](../../docs/tasklist/00-foundation-and-contracts.md)
§0.3** — do not fork them locally.

## Scripts (workspace)

From repo root: `npm run build:server`, `npm run typecheck`, `npm run test:server`, `npm run lint`.
