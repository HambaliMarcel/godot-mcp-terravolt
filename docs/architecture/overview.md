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
| `references/godot-mcp-*` | Indexed by **GitNexus** + **Graphify** for study (see **`docs/references/reference-repos-map.md`**); **`references/godot-docs/`** is local manual only — excluded from indexes. |

After structural edits, refresh tooling: `.cursor/workflows/intel-refresh.md`.
