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

| `method`      | Editor | Headless TCP | Notes                                                                                                                                                      |
| ------------- | ------ | ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ping`        | yes    | yes          | Timestamp source differs (`daemonResult` retains the raw payload). Verified by `tests/integration/mcp_e2e.test.mjs` (forces WS down via `--godot-port 1`). |
| `server.info` | yes    | yes          | Headless emits `build_mode: "headless_tcp"` and `supported_methods_count` for the driver allowlist.                                                        |

### Scene & project (catalog 0.3.0)

| `method`                                                                                                        | Editor | Headless TCP | Notes                                                                             |
| --------------------------------------------------------------------------------------------------------------- | ------ | ------------ | --------------------------------------------------------------------------------- |
| `scene.list`                                                                                                    | yes    | yes          | Walk `res://` for `.tscn` / `.scn`.                                               |
| `scene.get`                                                                                                     | yes    | yes          | Metadata without instantiate.                                                     |
| `scene.create`                                                                                                  | yes    | yes          | New scene file with typed root.                                                   |
| `scene.delete`                                                                                                  | yes    | yes          | File delete (dependency guard in editor).                                         |
| `scene.validate`                                                                                                | yes    | yes          | Returns issues in payload.                                                        |
| `project.info`                                                                                                  | yes    | yes          | Project metadata.                                                                 |
| `project.get_settings`                                                                                          | yes    | yes          | Group / key filter.                                                               |
| `project.set_settings`                                                                                          | yes    | yes          | Patch + optional `dry_run`.                                                       |
| `project.list_autoloads`                                                                                        | yes    | partial      | Headless returns empty list v1.                                                   |
| `project.set_main_scene`                                                                                        | yes    | yes          | Validates path when `validate=true`.                                              |
| `scene.open`, `scene.close`, `scene.save`, `scene.save_as`                                                      | yes    | no           | `editor.not_available` (`-33400`).                                                |
| `scene.get_tree`, `scene.get_subtree`, `scene.find_in_tree`, `scene.instantiate`, `scene.pack`, `scene.replace` | yes    | partial      | Need active scene; headless v1 returns `editor.no_active_scene` where applicable. |

### Node (catalog 0.4.0)

| `method`                                                                                 | Editor | Headless TCP | Notes                                            |
| ---------------------------------------------------------------------------------------- | ------ | ------------ | ------------------------------------------------ |
| `node.get`, `node.add`, `node.delete`, `node.modify`, `node.is_a`, `node.find_path`      | yes    | yes          | Active/main scene tree in headless driver.       |
| `node.list_groups`, `node.list_signals`, `node.evaluate_expression`                      | yes    | yes          | Expression denylist enforced.                    |
| `node.duplicate`, `node.move`, `node.rename`, `node.attach_script`, `node.detach_script` | yes    | partial      | Headless v1 deferred (`editor.no_active_scene`). |

### Script & signal (catalog 0.5.0)

| `method`                                                                                                               | Editor | Headless TCP | Notes                                   |
| ---------------------------------------------------------------------------------------------------------------------- | ------ | ------------ | --------------------------------------- |
| `script.list`, `script.read`, `script.write`, `script.patch`, `script.validate`, `script.find_usages`, `script.format` | yes    | yes          | `.gd` validate via `GDScript.reload()`. |
| `script.rename_symbol`                                                                                                 | yes    | no           | Editor-first v1.                        |
| `signal.list_declared`, `signal.list_connections`, `signal.find_listeners`, `signal.graph`                             | yes    | yes          | Graph exports JSON/Mermaid/DOT.         |
| `signal.connect`, `signal.disconnect`, `signal.bulk_connect`, `signal.bulk_disconnect`                                 | yes    | no           | Require active scene + UndoRedo.        |
| `signal.add_declaration`, `signal.remove_declaration`                                                                  | yes    | partial      | Headless stub for script file ops.      |

## Headless-only methods (no editor counterpart)

| `method`                 | Surface                             | Notes                                                                     |
| ------------------------ | ----------------------------------- | ------------------------------------------------------------------------- |
| `script.validate_syntax` | `headless.validate_script` MCP tool | GDScript compile check via `GDScript.new().reload()` inside the driver.   |
| `server.list_methods`    | driver only                         | Returns the driver's allowlist (includes scene/project headless methods). |
| `dispatch.cancel`        | driver only                         | Cooperative cancellation hook (no-op today).                              |

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
