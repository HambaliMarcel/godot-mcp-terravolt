# Runtime bridge (game process)

TerraVolt **`runtime.*`** tools inspect and drive the **running game**, not the editor daemon on `:6505`. A second TCP JSON-RPC listener runs inside the game process via the **`TerraVoltRuntimeBridge`** autoload.

## Topology

```mermaid
flowchart LR
  MCP[MCP router] --> Editor[Editor daemon :6505]
  Editor --> Proxy[runtime_proxy.gd]
  Proxy --> Bridge[runtime_bridge.gd :6506]
  Bridge --> Tree[Live SceneTree]
```

- **Editor play:** `runtime.play` → `EditorInterface.play_*` → child game loads autoload → bridge prints `TERRAVOLT_RUNTIME_PORT=<n>` on stderr and listens on loopback.
- **Headless CI:** `runtime.start_headless` spawns `godot --headless --path <project>` (fixture must register the autoload). The headless **driver** (`headless_driver.gd`) proxies `runtime.*` over the same TCP bridge.

## Wire protocol

- Transport: **TCP**, newline-delimited **JSON-RPC 2.0** (same framing as `headless_driver.gd`).
- Default port: **6506** (`terravolt_mcp/runtime/port`, env `TERRAVOLT_RUNTIME_PORT`).
- Bridge methods: `ping`, `list_nodes`, `inspect_node`, `evaluate`, `set_property`, `call_method`, `emit_signal`, `send_input`, `simulate_sequence`, `click_ui`, `navigate`, `record_inputs`, `replay_inputs`, `log_tail`, `screenshot`, `set_engine_param`.

## Session state

`runtime_session.gd` tracks `{ alive, pid, bridge_port, mode, uptime_ms }` in the editor or headless driver process. Bridge tools return **`runtime.no_session`** (`-33930`) with an **autoHeal** hint when no session is active.

## Installation

When the TerraVolt addon enables, `main.gd` calls `add_autoload_singleton("TerraVoltRuntimeBridge", …/autoloads/runtime_bridge.gd)` so play mode always exposes the bridge. Headless fixtures declare the autoload in `project.godot` directly.

## Safety

- Expression evaluation uses the same deny-list as `node.evaluate_expression`.
- Input synthesis warns when `SceneTree.paused` unless `force: true`.
- Input recording ring buffer caps at 10_000 events (`runtime_recording_buffer_capacity`).

## Related docs

- [`docs/catalog/runtime.md`](../catalog/runtime.md)
- [`docs/tasklist/17-catalog-runtime.md`](../tasklist/17-catalog-runtime.md)
