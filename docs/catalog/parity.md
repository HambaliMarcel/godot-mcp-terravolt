# Editor vs headless parity (living matrix)

Tracks which JSON-RPC daemon methods intentionally match between the `:6505` editor WebSocket and
the §07 headless TCP driver.

For full per-tool details (inputs, results, errors), see
**[`docs/guides/tools-reference.md`](../guides/tools-reference.md)**. For the connection flow, see
**[`docs/guides/godot-integration.md`](../guides/godot-integration.md)**.

## Legend

| Path         | Meaning                                                                                                                                 |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| Editor       | Daemon WebSocket reachable on `TERRAVOLT_GODOT_HOST` / `TERRAVOLT_GODOT_PORT`.                                                          |
| Headless TCP | Routed when `registry.json` sets `headlessFallback: true` and WS is disconnected. The MCP envelope reports `method: "<name>@headless"`. |

## Shipped parity (today)

| `method`      | Editor | Headless TCP | Notes                                                                                                                                                                                                                      |
| ------------- | ------ | ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ping`        | yes    | yes          | Timestamp source differs (`daemonResult` retains the raw payload). Verified by `tests/integration/mcp_e2e.test.mjs` (forces WS down via `--godot-port 1`).                                                                 |
| `server.info` | yes    | yes          | Headless emits a minimal subset (`name: "terravolt-godot-headless"`, `build_mode: "headless_tcp"`, `catalog_version`, `registry_sha256`, `godot_version`, `supported_methods_count: 5`); parity fields converge over time. |

## Headless-only methods (no editor counterpart)

| `method`                 | Surface                             | Notes                                                                                                                           |
| ------------------------ | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `script.validate_syntax` | `headless.validate_script` MCP tool | GDScript compile check via `GDScript.new().reload()` inside the driver.                                                         |
| `server.list_methods`    | driver only                         | Returns the driver's allowlist (`["dispatch.cancel", "ping", "script.validate_syntax", "server.info", "server.list_methods"]`). |
| `dispatch.cancel`        | driver only                         | Cooperative cancellation hook (no-op today).                                                                                    |

## Editor-only methods (no headless counterpart)

| `method`                                                  | Notes                                         |
| --------------------------------------------------------- | --------------------------------------------- |
| `log.tail`                                                | Editor-mode daemon owns `user://mcp_log.txt`. |
| All other daemon methods without `headlessFallback: true` | Defaults to editor-only.                      |

## Backlog parity (planned)

Anything else in `packages/shared/methods/registry.json` **without** `headlessFallback: true` is
**editor-first** unless a dedicated MCP headless router tool exposes it locally. Expansion is
tracked under `docs/tasklist/07-headless-fallback.md` and Linear `TER-40` (TV-07).

Likely future parity (subject to §08 catalog landings): `scene.get_open_path`,
`script.validate_syntax` for `.cs`, `runtime.export_release`, `runtime.import_assets`,
`runtime.run_tests`.

## Validation checklist

Structured repo validation for tasks **TV-00 … TV-10** (including honest partial scope for §07 §08
§09 §10): **[`docs/validation/tv-00-10-checkpoint.md`](../validation/tv-00-10-checkpoint.md)**.
