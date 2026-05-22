# Packages (planned)

Terravolt code will ship as:

| Folder | Role |
|--------|------|
| [mcp-server/](mcp-server/) | MCP stdio/http server (Node or other runtime) bridging Godot ↔ agents |
| [godot-mcp-addon/](godot-mcp-addon/) | Godot 4 addon sources → install under a Godot project’s `addons/` |

Nothing is wired yet — this scaffold reserves names and docs.

**Build order:** read [`docs/srs/00-fundamentals-contract.md`](../docs/srs/00-fundamentals-contract.md) (pre–Phase 1), then follow [`docs/srs/execution_roadmap.md`](../docs/srs/execution_roadmap.md) before adding transport or tools.
