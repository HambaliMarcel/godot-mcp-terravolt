# TerraVolt Godot MCP — system overview

## Purpose

**godot-mcp-terravolt** bridges agents (MCP **stdio**) and the Godot 4 editor (planned WebSocket
**`6505`**), guided by curated upstream clones under **`/references/`** (repo root, gitignored).
Shippable first-party code lives in **`packages/`**.

## Where to read next

| Topic                              | Doc                                                                              |
| ---------------------------------- | -------------------------------------------------------------------------------- |
| **Folders & tooling outputs**      | [`docs/repo-layout.md`](../repo-layout.md)                                       |
| **Agent loading order**            | [`docs/context/context-map.md`](../context/context-map.md)                       |
| **Product blueprint & phases**     | [`docs/srs/README.md`](../srs/README.md)                                         |
| **Roadmap exec order (`00`→`10`)** | [`docs/tasklist/`](../tasklist/)                                                 |
| **Upstream MCP anatomy**           | [`docs/references/reference-repos-map.md`](../references/reference-repos-map.md) |

Indexed for study: **`references/godot-mcp-*`**. **`references/godot-docs/`** stays local/manual
only — omitted from GitNexus/Graphify in this workspace (Sphinx volume).

## After structural changes

Refresh intel: **`npm run omni:intel`** (see
[`.cursor/workflows/intel-refresh.md`](../../.cursor/workflows/intel-refresh.md)).
