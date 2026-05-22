# Troubleshooting

The router emits structured **`autoHeal`** payloads on errors (unless `--disable-auto-heal` is
passed). Use them first — they cite the env var or flag that resolves the issue. Below is the
long-form companion.

| Symptom                                                            | Likely error symbol                         | Fix                                                                                                                                                                                                                                                                   |
| ------------------------------------------------------------------ | ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| MCP tool returns `transport.not_connected` repeatedly.             | `transport.not_connected`                   | Start the Godot editor and enable the Terravolt addon, **or** ensure `headless.start_project` is reachable (set `TERRAVOLT_GODOT_BINARY` + `TERRAVOLT_PROJECT_PATH`). For `ping` and `server.info`, fallback is automatic — if it still fails, the binary is missing. |
| `headless.*` MCP tool returns `headless.binary_missing`.           | `-33810`                                    | `npm run env:godot` to pick a binary, or set `TERRAVOLT_GODOT_BINARY` to an absolute path; on Windows prefer the `_console.exe` flavor.                                                                                                                               |
| `headless.*` returns `headless.no_project`.                        | `-33811`                                    | Pass `projectPath` to `headless.start_project`, or set `TERRAVOLT_PROJECT_PATH` / `--project`.                                                                                                                                                                        |
| Driver never returns a port.                                       | `-33813` `headless.driver_handshake_failed` | Confirm `packages/godot-mcp-addon/headless/headless_driver.gd` is on disk and reachable; on Windows confirm the `_console.exe` variant is selected. Increase `--headless-boot-timeout-ms` for cold starts.                                                            |
| Headless RPC hangs and times out.                                  | `-33816` `headless.timeout`                 | Raise `--request-timeout-ms` and `--headless-op-timeout-ms`; split workloads.                                                                                                                                                                                         |
| `tools.health` shows `protocol_catalog_mismatch_detected: true`.   | `protocol.catalog_mismatch`                 | Run `npm run catalog:sync` and restart both the router and the Godot editor.                                                                                                                                                                                          |
| Router crashes on launch on Windows with `ERR_INVALID_URL_SCHEME`. | n/a                                         | Symptom of stale build before the `loadRegistry` fix (commit `22d5c5c`). Run `npm run build:server` then retry. Tracked in `docs/validation/tv-00-10-checkpoint.md`.                                                                                                  |
| `headless.validate_script` says `missing: <path>`.                 | n/a                                         | Pass an **absolute** path or a `res://` path that resolves inside the active headless project. Driver expects `.gd` (GDScript today).                                                                                                                                 |
| “Recovery mode” loaded the editor and the addon is silent.         | n/a                                         | Godot **disables plugins** under `--recovery-mode`. Open the editor normally to re-enable the Terravolt addon.                                                                                                                                                        |
| Linux CI cannot find the editor.                                   | n/a                                         | The official binary unzips to a long-named exe; symlink it to `/usr/local/bin/godot4` or set `TERRAVOLT_GODOT_BINARY` explicitly.                                                                                                                                     |

## Capturing logs

- Daemon log: `user://mcp_log.txt` inside the active project. Use `log.tail` MCP tool for live tail.
- Router log: stderr of the `node packages/mcp-server/dist/index.js` process. Pipe to file for
  diagnostics.

## Reporting

Open a GitHub issue with:

1. Output of `npm run release:check`.
2. Relevant snippet of `user://mcp_log.txt`.
3. The Godot version (`& $env:TERRAVOLT_GODOT_BINARY --version`).
4. The MCP tool name and arguments that failed.

## See also

- `docs/guides/quick-start.md`
- `docs/guides/mcp-usage.md`
- `docs/guides/godot-integration.md`
- `docs/guides/headless-only.md`
- `docs/guides/tools-reference.md`
