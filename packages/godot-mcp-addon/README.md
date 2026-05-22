# Godot MCP addon (placeholder)

Place GDScript **EditorPlugin** sources here per [`docs/srs/execution_roadmap.md`](../../docs/srs/execution_roadmap.md) **Phase 1** (not started in this repo root until you open a Godot 4 project or add an embedded project).

**Pre–Phase 1:** lock contracts in [`docs/srs/00-fundamentals-contract.md`](../../docs/srs/00-fundamentals-contract.md) (port **6505**, JSON-RPC 2.0, log **`user://mcp_log.txt`**).

**Phase 1 checklist (when coding):**

1. `plugin.cfg` + entry `main.gd` (EditorPlugin)
2. `mcp_server.gd` — WebSocket server on **6505**
3. JSON-RPC parser + central command dispatcher
4. Logging — **`user://mcp_log.txt`** only

**Convention:** symlink or copy this folder into a Godot 4 project under `addons/<addon_folder>/` (folder name matches `plugin.cfg`).
