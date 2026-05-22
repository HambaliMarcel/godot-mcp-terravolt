# TerraVolt Godot MCP — system overview

## Purpose

**godot-mcp-terravolt** is the TerraVolt workspace for an MCP ⇄ Godot bridge, guided by curated upstream comparisons under **`references/`** (local, gitignored).

## Layers

| Layer | Role |
|--------|------|
| **Documentation** | `docs/` — architecture, agent context priorities, contributing notes |
| **Omni tooling (Cursor)** | `.cursor/rules`, `.cursor/workflows`, agent policies |
| **Graphify knowledge graph** | `graphify-out/` (`npm run intel:graphify`); ignores in `.graphifyignore` |
| **JS module graphs (Omni)** | `artifacts/js-graphs/` from `npm run intel:graphs` |
| **GitNexus** | `.gitnexus/` index (`npm run intel:gitnexus`) |
| **Config** | `config/` — e.g. dependency-cruiser |
| **Build / intel scripts** | `tools/intel/` |
| **Shippable code (future)** | `packages/mcp-server/`, `packages/godot-mcp-addon/` |

## Layout

| Area | Responsibility |
|------|------------------|
| `references/` | Read-only clones of other Godot MCP projects — patterns only |
| `packages/` | MCP server + Godot addon product code once implemented |
| `artifacts/` | Regenerated analyzer output (committed for teammates when useful) |

After structural edits, refresh tooling: `.cursor/workflows/intel-refresh.md`.
