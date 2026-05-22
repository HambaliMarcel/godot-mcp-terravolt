# System architecture blueprint

## Objective

Construct a zero-friction, ultra-high-performance Model Context Protocol (MCP) bridge for Godot 4.x (`.NET` compatible targets). Aim to surpass the aggregate capabilities of `youichi-uda/godot-mcp-pro`, `tomyud1/godot-mcp`, and `Coding-Solo/godot-mcp`.

## Architecture topology

Dual-component system:

1. **Backend:** Node.js MCP server (**stdio** to Cursor/agents).
2. **Frontend:** Godot EditorPlugin (**WebSocket** daemon port **6505**).
3. **Fallback:** Headless CLI execution for Godot operations when the editor is closed.

## Core requisites

- **Protocol:** Strict **JSON-RPC 2.0**; standardized error codes for LLM-driven recovery.
- **Connection state:** Persistent WebSocket with exponential backoff and heartbeat ping/pong; avoid silent context drops.
- **State synchronization:** Bidirectional flow — Cursor-bound changes reflect in Godot and vice versa (`EditorInterface`/watchers/tree polling).
- **Performance:** Batch multi-node edits where possible; throttle polling for runtime performance monitors.

## Directives for implementers

- Study reference architectures: WebSocket patterns from **`tomyud1`**, headless execution from **Coding-Solo**, API/schema ideas from **`youichi-uda`** addon code where applicable.
- **TypeScript** for the Node MCP server.
- Prefer **typed** GDScript in the EditorPlugin.
- Avoid redundant tools — aggregate overlaps into polymorphic ops (e.g. one **`modify_node`** covering properties, groups, and meta).
