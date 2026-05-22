# godot-mcp-terravolt

Godot MCP integration for TerraVolt.

## Omni protocol stack (this repo)

Aligned with [HambaliMarcel/omni-protocol](https://github.com/HambaliMarcel/omni-protocol) conventions:

| Piece | What to run |
|--------|-------------|
| **JS module graphs (Omni)** | `npm install` then `npm run intel:graphs` → `graphs/` (dependency-cruiser + madge) |
| **GitNexus** | `npm run intel:gitnexus` → local `.gitnexus/` (gitignored). Reference clones under `references/` are omitted via `.gitnexusignore`. See `AGENTS.md`. |
| **Cursor** | Workspace MCP: `.cursor/mcp.json` (GitNexus). Rules: `.cursor/rules/terravolt-omni.mdc` |
| **[Graphify](https://github.com/safishamsi/graphify) (knowledge graph)** | **`npm run intel:graphify`** → `graphify-out/` (AST). Rule: `.cursor/rules/graphify.mdc`. Patterns: `.graphifyignore`. Use `py -3 -m graphify query "..."` once `graphify-out/graph.json` exists. Optional: **`npm run intel:graphify:cluster`**. Global Cursor rule in `%USERPROFILE%\.cursor\rules\graphify.mdc` may overlap this repo rule. |

Intel refresh checklist: `.cursor/workflows/intel-refresh.md`

## Reference repos (local)

`references/` is gitignored. Clone into it for side‑by‑side study:

```bash
git clone --depth 1 https://github.com/youichi-uda/godot-mcp-pro.git references/godot-mcp-pro
git clone --depth 1 https://github.com/tomyud1/godot-mcp.git references/godot-mcp-tomyud1
git clone --depth 1 https://github.com/Coding-Solo/godot-mcp.git references/godot-mcp-coding-solo
```

## Status

Early scaffold — omni tooling; reference repos are local only (see above).
