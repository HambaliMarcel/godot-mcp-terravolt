# GitNexus — this workspace

**Roadmap discipline:** Agents must execute **[`docs/tasklist/`](docs/tasklist/)** **`00`** →
**`10`** in order (`00`/`01` are pre-product-code gates). Honour phase constraints from
[**`docs/srs/execution_roadmap.md`**](docs/srs/execution_roadmap.md) before writing
transport/tooling.

TerraVolt **godot-mcp-terravolt** uses **GitNexus** for codebase intelligence when JS/TS (and
analyzed) sources land here.

## Activate / refresh

1. Install deps: `npm install`
2. Index: `npm run intel:gitnexus` (or `npx gitnexus analyze` from repo root)

If MCP tools warn the graph is stale, rerun the analyze step.

## Graphify

Regenerate dependency graphs:

```bash
npm run intel:graphs
```

Artifacts: `artifacts/js-graphs/dependency-graph.json`, `artifacts/js-graphs/madge-graph.json`
(JS/TS module layer only).

## Cursor

Workspace MCP servers: `.cursor/mcp.json` (includes **GitNexus**).

After editing MCP config, restart Cursor.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **godot-mcp-terravolt** (3215 symbols, 5558 relationships, 157 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/godot-mcp-terravolt/context` | Codebase overview, check index freshness |
| `gitnexus://repo/godot-mcp-terravolt/clusters` | All functional areas |
| `gitnexus://repo/godot-mcp-terravolt/processes` | All execution flows |
| `gitnexus://repo/godot-mcp-terravolt/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
