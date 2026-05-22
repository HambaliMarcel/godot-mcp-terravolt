# godot-mcp-terravolt

TerraVolt **Godot ⇄ MCP** monorepo: product code lands in **`packages/`**; onboarding, SRS, and
agent context live in **`docs/`**.

**Canonical tree:** **[`docs/repo-layout.md`](docs/repo-layout.md)** — read this once before moving
files.

## Omni / intel stack

| Piece                | Command / output                                                                                                                                                                                      |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **JS module graphs** | `npm install` then **`npm run intel:graphs`** → `artifacts/js-graphs/`                                                                                                                                |
| **GitNexus**         | **`npm run intel:gitnexus`** → `.gitnexus/` (gitignored index). See `.gitnexusignore` — **`references/godot-mcp-*`** included; **`references/godot-docs`** excluded (Sphinx/manual). See `AGENTS.md`. |
| **Graphify (KG)**    | **`npm run intel:graphify`** → `graphify-out/`; **`npm run intel:graphify:cluster`** Optional. Patterns: `.graphifyignore`.                                                                           |
| **Combined**         | **`npm run omni:intel`**                                                                                                                                                                              |

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

`godot-docs` is large (official [Sphinx](https://docs.godotengine.org/) manual source — see upstream
[readme](https://github.com/godotengine/godot-docs)). **Architectural comparison** of MCP refs:
**[docs/references/reference-repos-map.md](docs/references/reference-repos-map.md)**.

## Documentation

[docs/README.md](docs/README.md) · [architecture](docs/architecture/overview.md) ·
[SRS](docs/srs/README.md) · [tasklist `00`–`10`](docs/tasklist/)

## Status

Early scaffold — structure reserved for MCP server + Godot addon implementation. **SRS:**
[`docs/srs/README.md`](docs/srs/README.md) (architecture, tool registry, roadmap; fundamentals
contract **before** Phase 1 coding).

## Contributing (Git hooks)

Optional Cursor co-author handling:
[docs/contributing/git-hooks.md](docs/contributing/git-hooks.md).
