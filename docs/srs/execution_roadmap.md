# Execution roadmap

## Objective

Strict, linear execution plan from **zero** to **production-ready** MCP behavior for this product.

## Fundamentals (pre–Phase 1)

Complete [**`00-fundamentals-contract.md`**](00-fundamentals-contract.md) in-repo: topology, JSON-RPC discipline, constants (**`6505`**, **`user://mcp_log.txt`**), package paths, and phase gates. Closing fundamentals does **not** require transport code — only locked contracts that Phase 1 will implement.

## Phase 1: Godot plugin foundation

1. Godot EditorPlugin scaffold (`plugin.cfg`, `main.gd`).
2. WebSocket server (`mcp_server.gd`) on port **6505**.
3. JSON-RPC parser and central command dispatcher.
4. Logging to **`user://mcp_log.txt`** only (tail-friendly for agents).

## Phase 2: Node.js MCP router

1. npm project; `@modelcontextprotocol/sdk` and `ws`.
2. WebSocket **client** to the Godot daemon; reconnection loop.
3. **stdio** MCP transport for Cursor.
4. Tool translation: MCP tool calls → Godot JSON-RPC payloads; await responses.

## Phase 3: Toolset implementation (iterative)

1. **File ops** (read/write/project settings); verify from Cursor.
2. **Scene DOM** (add/reparent/properties); generate a simple scene from chat.
3. **Runtime** (play/stop/live tree); debug session smoke test.
4. **Macros** (UI scaffolding, asset mapping).

## Phase 4: Context & error optimization

1. Context protection: truncate huge trees; default to scripts / non-default params unless expanded.
2. Auto-healing: map Godot editor errors → structured MCP diagnostics for agent retry.

## Directives for implementers

- Do not enter the next phase until the **current** transport layer is verified end-to-end.
- Prefer **EditorInterface** (and related editor APIs) over hand-editing `.tscn` text to avoid corruption.
