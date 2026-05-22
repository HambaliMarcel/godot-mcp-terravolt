# godot-mcp-terravolt

TerraVolt **Godot ⇄ MCP** workspace: Node/intel toolchain at the repo root, product code slated for **`packages/`**, narrative docs in **`docs/`**.

## Repository layout

| Path | Responsibility |
|------|----------------|
| **`docs/`** | Architecture overview, agent context map, contributing (see [docs/README.md](docs/README.md)) |
| **`packages/`** | MCP server + Godot addon placeholders ([packages/README.md](packages/README.md)) |
| **`config/`** | Shared analyzers (`dependency-cruiser`, future linters) |
| **`tools/intel/`** | Scripts invoked by npm for graphs / codegen helpers |
| **`artifacts/`** | Regenerated analyzer output (safe to commit; refresh with npm scripts below) |
| **`graphify-out/`** | [Graphify](https://github.com/safishamsi/graphify) KG (default path; Cursor rule `.cursor/rules/graphify.mdc`) |
| **`references/`** | Local clones (**gitignored**): MCP repos indexed by GitNexus/Graphify; **`godot-docs/`** Sphinx tree excluded ([map](docs/references/reference-repos-map.md)). |

## Omni / intel stack

| Piece | Command / output |
|--------|-------------------|
| **JS module graphs** | `npm install` then **`npm run intel:graphs`** → `artifacts/js-graphs/` |
| **GitNexus** | **`npm run intel:gitnexus`** → `.gitnexus/` (gitignored index). See `.gitnexusignore` — **`references/godot-mcp-*`** included; **`references/godot-docs`** excluded (Sphinx/manual). See `AGENTS.md`. |
| **Graphify (KG)** | **`npm run intel:graphify`** → `graphify-out/`; **`npm run intel:graphify:cluster`** Optional. Patterns: `.graphifyignore`. |
| **Combined** | **`npm run omni:intel`** |

Operational checklist: [.cursor/workflows/intel-refresh.md](.cursor/workflows/intel-refresh.md)  
Architecture: [docs/architecture/overview.md](docs/architecture/overview.md)

## Workspace agents (Cursor)

- MCP: [.cursor/mcp.json](.cursor/mcp.json) (**GitNexus**)
- Rules: [.cursor/rules/terravolt-omni.mdc](.cursor/rules/terravolt-omni.mdc), `graphify.mdc`

## Reference repos (local)

```bash
git clone --depth 1 https://github.com/godotengine/godot-docs.git references/godot-docs
git clone --depth 1 https://github.com/youichi-uda/godot-mcp-pro.git references/godot-mcp-pro
git clone --depth 1 https://github.com/tomyud1/godot-mcp.git references/godot-mcp-tomyud1
git clone --depth 1 https://github.com/Coding-Solo/godot-mcp.git references/godot-mcp-coding-solo
```

`godot-docs` is large (official [Sphinx](https://docs.godotengine.org/) manual source — see upstream [readme](https://github.com/godotengine/godot-docs)). **Architectural comparison** of MCP refs: **[docs/references/reference-repos-map.md](docs/references/reference-repos-map.md)**.
## Status

Early scaffold — structure reserved for MCP server + Godot addon implementation.

## Contributing (Git hooks)

Optional Cursor co-author handling: [docs/contributing/git-hooks.md](docs/contributing/git-hooks.md).
