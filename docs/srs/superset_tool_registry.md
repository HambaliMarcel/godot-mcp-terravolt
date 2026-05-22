# Superset tool registry

## Objective

Define the API surface for **200+** distinct operations (target). Establish the baseline toolset for autonomous **vibe coding** of full game loops.

Descriptions should map cleanly to MCP tool schemas (`@modelcontextprotocol/sdk`) with explicit return payloads: successful calls return the **new state** of the affected objects.

## Categorical schemas

### 1. Scene & node DOM (CRUD+)

- `get_scene_tree(scene_path: String)` — Hierarchy with UID and node paths.
- `add_node(parent_path: String, type: String, name: String, properties: Dict)` — Instantiate and attach.
- `modify_node_properties(node_path: String, properties: Dict)` — Batch updates (Vectors, Colors, Transform3D, …).
- `reparent_node(node_path: String, new_parent_path: String, keep_global_transform: bool)`.

### 2. Scripting & context (C# & GDScript)

- `attach_script(node_path: String, script_path: String)`.
- `get_node_signals(node_path: String)` — Signals and active connections.
- `connect_signal(source_node: String, signal_name: String, target_node: String, method_name: String)`.
- `validate_script_syntax(script_path: String)` — Background compile; return error lines.

### 3. Runtime & telemetry (live connection)

- `get_runtime_tree()` — Live scene tree during play.
- `track_property(node_path: String, property: String, duration_sec: float)` — Time series during play.
- `simulate_input(action_name: String, state: bool)` — Drive `InputMap` actions.
- `get_performance_metrics()` — FPS, draw calls, VRAM, physics ticks, …

### 4. Vibe-code macros (advanced automation)

- `scaffold_ui(layout_json: Dict)` — JSON → nested `Control` trees (margins, boxes, anchors).
- `batch_import_assets(directory: String, import_type: String)` — Enforce import presets (e.g. nearest-neighbor for `/pixel_art`).
- `refactor_node_references(old_path: String, new_path: String)` — Update `get_node()` / `$` usage across scripts.

## Directives for implementers

- One tool ↔ one JSON schema; descriptions must be specific (Cursor routes on them).
- Standard return payloads; success returns updated object state.
