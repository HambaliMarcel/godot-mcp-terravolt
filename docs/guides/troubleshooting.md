# Troubleshooting

The router emits structured **`autoHeal`** payloads on errors (unless
`--disable-auto-heal` is passed). Use them first — they cite the env var or
flag that resolves the issue. Below is the long-form companion.

| Symptom | Likely error symbol | Fix |
| ------- | ------------------- | --- |
| MCP tool returns `transport.not_connected` repeatedly. | `transport.not_connected` | Start the Godot editor and enable the TerraVolt addon, **or** ensure `headless.start_project` is reachable (set `TERRAVOLT_GODOT_BINARY` + `TERRAVOLT_PROJECT_PATH`). |
| `headless.*` MCP tool returns `headless.binary_missing`. | `-33810` | `npm run env:godot` to pick a binary, or set `TERRAVOLT_GODOT_BINARY` to an absolute path; on Windows prefer the `_console.exe` flavor. |
| Driver never returns a port. | `-33813` `headless.driver_handshake_failed` | Confirm `packages/godot-mcp-addon/headless/headless_driver.gd` is on disk and reachable; increase `--headless-boot-timeout-ms` for cold starts. |
| Headless RPC hangs and times out. | `-33816` `headless.timeout` | Raise `--request-timeout-ms` and `--headless-op-timeout-ms`; split workloads. |
| `tools.health` shows `catalogVersion` mismatch. | `protocol.catalog_mismatch` | Run `npm run catalog:sync` and restart both the router and the Godot editor. |
| “Recovery mode” loaded the editor and the addon is silent. | n/a | Godot **disables plugins** under `--recovery-mode`. Open the editor normally to re-enable the TerraVolt addon. |
| Linux CI cannot find the editor. | n/a | The official binary unzips to a long-named exe; symlink it to `/usr/local/bin/godot4` or set `TERRAVOLT_GODOT_BINARY` explicitly. |

## Capturing logs

- Daemon log: `user://mcp_log.txt` inside the active project. Use
  `log.tail` MCP tool for live tail.
- Router log: stderr of the `node packages/mcp-server/dist/index.js` process.
  Pipe to file for diagnostics.

## Reporting

Open a GitHub issue with:

1. Output of `npm run release:check`.
2. Relevant snippet of `user://mcp_log.txt`.
3. The Godot version (`& $env:TERRAVOLT_GODOT_BINARY --version`).
4. The MCP tool name and arguments that failed.
