# Catalog: `runtime.*`

Phase 3 work-unit #7 — 19 playmode methods (`catalog_version` **0.9.0**+, registry band **0.12.0** when shipped with later categories).

| Method | Safe | Mutates | Editor | Headless |
| --- | --- | --- | --- | --- |
| `runtime.play` | no | yes | yes | no |
| `runtime.stop` | no | yes | yes | partial |
| `runtime.start_headless` | no | yes | yes | yes |
| `runtime.status` | yes | no | yes | yes |
| `runtime.list_nodes` | yes | no | bridge | bridge |
| `runtime.inspect_node` | yes | no | bridge | bridge |
| `runtime.evaluate` | yes | no | bridge | bridge |
| `runtime.set_property` | no | yes | bridge | bridge |
| `runtime.call_method` | no | depends | bridge | bridge |
| `runtime.emit_signal` | no | yes | bridge | bridge |
| `runtime.send_input` | no | yes | bridge | bridge |
| `runtime.simulate_sequence` | no | yes | bridge | bridge |
| `runtime.click_ui` | no | yes | bridge | bridge |
| `runtime.navigate` | no | yes | bridge | bridge |
| `runtime.record_inputs` | no | yes | bridge | bridge |
| `runtime.replay_inputs` | no | yes | bridge | bridge |
| `runtime.log_tail` | yes | no | bridge | bridge |
| `runtime.screenshot` | yes | no | bridge | bridge |
| `runtime.set_engine_param` | no | yes | bridge | bridge |

**Bridge** = requires an active session (`runtime.play` or `runtime.start_headless`).

Handlers: `packages/godot-mcp-addon/handlers/runtime.gd`, `runtime_helpers.gd`  
Session / proxy: `packages/godot-mcp-addon/services/runtime_session.gd`, `runtime_proxy.gd`  
Game process: `packages/godot-mcp-addon/autoloads/runtime_bridge.gd` (TCP **6506**, `terravolt_mcp/runtime/port` or `TERRAVOLT_RUNTIME_PORT`)

Error band: `-33930` … `-33939`.

Fixture: `tests/_fixtures/minimal_game/`
