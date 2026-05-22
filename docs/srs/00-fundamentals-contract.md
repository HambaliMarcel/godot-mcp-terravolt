# TerraVolt Godot MCP — fundamentals contract (pre–Phase 1)

This document **executes** the non-code baseline from the SRS: agreed contracts and repo gates **before** [execution_roadmap.md](execution_roadmap.md) Phase 1 (`plugin.cfg` / `main.gd` / `mcp_server.gd`).

## 1. Product topology (locked)

| Piece | Role | Notes |
|--------|------|--------|
| **Node MCP backend** | `stdio` to Cursor/agents | Strict **TypeScript** when implemented ([system_architecture_blueprint.md](system_architecture_blueprint.md)) |
| **Godot EditorPlugin frontend** | **WebSocket daemon** binding **TCP port `6505`** | Persistent connection, backoff + heartbeat (blueprint) |
| **Headless fallback** | Godot/CLI operations when editor closed | Pattern from **Coding-Solo** reference; detailed in later phases |

## 2. Wire protocol (locked)

- **Framing:** **JSON-RPC 2.0** end-to-end between MCP tool layer and Godot command dispatch.  
- **Errors:** Standard JSON-RPC errors + **stable application error codes** so agents can auto-heal (align with Phase 4 roadmap; reserve codes early in server).  
- **Godot → agent context:** File watchers + scene-tree polling (blueprint); implementation begins after transport is proven.

## 3. Operational constants (locked)

| Constant | Value | Where used first |
|----------|--------|------------------|
| WebSocket listen port | **`6505`** | Phase 1 `mcp_server.gd` |
| Editor log file | **`user://mcp_log.txt`** | Phase 1 logging subsystem (Cursor can tail) |
| MCP transport to Cursor | **`stdio`** | Phase 2 Node router |

## 4. Implementation placement (locked)

| Deliverable | Repository path |
|-------------|-----------------|
| Godot addon | **`packages/godot-mcp-addon/`** → copy/symlink into a Godot 4 project’s `addons/<name>/` |
| Node MCP server | **`packages/mcp-server/`** |

No redundant tools: prefer **polymorphic** operations (e.g. one `modify_node` covering properties/groups/meta) per blueprint.

## 5. Phase gate (do not skip)

From [execution_roadmap.md](execution_roadmap.md):

- **Do not start Phase 2** until Godot-side **WebSocket + JSON-RPC dispatch + logging** are verified (Phase 1).  
- **Do not advance phases** until the **underlying transport** for the current phase is verified.

**Current status:** fundamentals documented and repo aligned; **Phase 1** is the next coding step (plugin skeleton + WS + JSON-RPC + log).

## 6. Reference study map

See [docs/references/reference-repos-map.md](../references/reference-repos-map.md) for which upstream repo supplies WebSocket patterns, headless execution, and API schema ideas.
