# TerraVolt Godot MCP — system overview

## Purpose

This repository hosts **/godot-mcp-terravolt/**: an MCP bridge for Godot, informed by upstream references under `references/`.

## Layers

| Layer | Role |
|--------|------|
| **Omni docs & rules** | `.cursor/rules`, workflows, agent policies |
| **Graphify (KG)** | `graphify-out/` — `npm run intel:graphify` ([safishamsi/graphify](https://github.com/safishamsi/graphify)); `.graphifyignore` excludes `references/` |
| **Graphify (JS graphs)** | `graphs/*.json` from `npm run intel:graphs` (dependency-cruiser + madge) |
| **GitNexus** | Code graph index in `.gitnexus/` (`npm run intel:gitnexus`) |
| **Cursor** | `.cursor/mcp.json` — **GitNexus** MCP; `.cursor/rules/graphify.mdc` — Graphify query-first behavior |

## Layout ( evolving )

- `references/` — read-only clones of other Godot MCP implementations (do not edit for product code).
- Future: Godot addon, Node MCP server, and specs will live beside this scaffold.

Refresh intel after structural changes: see `.cursor/workflows/intel-refresh.md`.
