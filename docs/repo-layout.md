# Repository layout (canonical)

Single source for **where things live**. The root **[README](../README.md)** stays a short onboarding page; pointers lead here.

## Top-level

| Path | Role |
|------|------|
| **[`packages/`](../packages/)** | Shippable product: Node MCP server, Godot addon (see [packages/README.md](../packages/README.md)). |
| **[`scripts/`](../scripts/)** | Node scripts wired from **`package.json`** ([`scripts/README.md`](../scripts/README.md)). |
| **[`docs/`](./README.md)** | Architecture, SRS, reference map, contributing. |
| **[`config/`](../config/)** | Shared tooling config (`dependency-cruiser`, linters later). |
| **[`artifacts/js-graphs/`](../artifacts/js-graphs/)** | Regenerated **Omni** JSON (depcruise + madge); safe to commit for team snapshots. |
| **`graphify-out/`** | [Graphify](https://github.com/safishamsi/graphify) outputs (`graph.json`, `GRAPH_REPORT.md`, …); cache under `graphify-out/cache/` is **gitignored**. |
| **`/references/`** | **Gitignored** local clones of upstream MCP repos + optional `godot-docs` ([reference map](./references/reference-repos-map.md)). |
| **[`.cursor/`](../.cursor/)** | Workspace MCP (`mcp.json`), rules (`rules/*.mdc`), workflows (`workflows/`). |

## Local-only (never commit)

These may exist after running tools — keep them **out of Git**:

| Path / pattern | Why |
|----------------|-----|
| **`.gitnexus/`** | GitNexus index + parse cache ([`npm run intel:gitnexus`](../README.md)). |
| **`node_modules/`** | npm installs. |

## Layers (conceptual)

| Layer | Responsibility |
|--------|----------------|
| **Documentation** | `docs/` — architecture, SRS, agent context priorities. |
| **Omni tooling (Cursor)** | `.cursor/rules`, `.cursor/workflows`, Graphify/GitNexus refresh scripts. |
| **Graphify knowledge graph** | `graphify-out/` (`npm run intel:graphify`); exclusions in `.graphifyignore`. |
| **JS module graphs** | `artifacts/js-graphs/` (`npm run intel:graphs`). |
| **GitNexus** | `.gitnexus/` locally; suppressions in `.gitnexusignore`. |

Operational checklist: [`.cursor/workflows/intel-refresh.md`](../.cursor/workflows/intel-refresh.md).

## Related

- **[Architecture overview](./architecture/overview.md)** — purpose and evolution.  
- **[Context map](./context/context-map.md)** — suggested reading order for agents.  
- **[SRS index](./srs/README.md)** — product blueprint and phased implementation.
