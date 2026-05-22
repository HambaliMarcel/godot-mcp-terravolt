# Linear tracking — Godot MCP TerraVolt roadmap

Tracked in Linear under **Terravolt** → project **Godot MCP TerraVolt — build roadmap**  
([open project page](https://linear.app/terravolt/project/godot-mcp-terravolt-build-roadmap-db4a5bd8fcbc)).

## What was imported via MCP (Cursor plugin)

| Episode | Markdown | Epic issue |
|--------|----------|-----------|
| 00 | `docs/tasklist/00-foundation-and-contracts.md` | [TER-33](https://linear.app/terravolt/issue/TER-33) |
| 01 | `docs/tasklist/01-repository-and-tooling-setup.md` | [TER-34](https://linear.app/terravolt/issue/TER-34) |
| 02 | `docs/tasklist/02-godot-plugin-foundation.md` | [TER-35](https://linear.app/terravolt/issue/TER-35) |
| 03 | `docs/tasklist/03-godot-websocket-server.md` | [TER-37](https://linear.app/terravolt/issue/TER-37) |
| 04 | `docs/tasklist/04-jsonrpc-dispatch-and-logging.md` | [TER-36](https://linear.app/terravolt/issue/TER-36) |
| 05 | `docs/tasklist/05-node-mcp-router.md` | [TER-38](https://linear.app/terravolt/issue/TER-38) |
| 06 | `docs/tasklist/06-tool-translation-layer.md` | [TER-39](https://linear.app/terravolt/issue/TER-39) |
| 07 | `docs/tasklist/07-headless-fallback.md` | [TER-40](https://linear.app/terravolt/issue/TER-40) |
| 08 | `docs/tasklist/08-toolset-implementation.md` | [TER-41](https://linear.app/terravolt/issue/TER-41) |
| 09 | `docs/tasklist/09-context-and-error-optimization.md` | [TER-43](https://linear.app/terravolt/issue/TER-43) |
| 10 | `docs/tasklist/10-quality-testing-release-and-docs.md` | [TER-42](https://linear.app/terravolt/issue/TER-42) |

Sequential **blockedBy** wiring (00 → … → 10) is configured on those epics: each episode waits on the prior epic.

Notes:

- **`03 → TER-37` then `04 → TER-36`** preserves the intended engineering order (`02 → 03 → 04`).
- Smoke item **TER-44** (“TEST”) without a parent is safe to archive or cancel on your board if you created it accidentally.

Child issues (`###` subsections plus exported checklist prose) correspond to **`tools/linear_task_export.json`** (`python tools/export_linear_issues.py`).

## Finish the child backlog (~295 subsections) in one sweep

Creating every child purely through MCP is slow in long chat sessions; use Linear’s GraphQL API once:

```powershell
# From repo root — Windows PowerShell
py -3 tools\export_linear_issues.py
setx LINEAR_API_KEY "lin_api_..."   # persistent for new shells — or `$env:` for session only

py -3 tools\push_linear_issue_children_api.py --dry-run
```

If **one subsection** already exists via MCP (e.g. Topology), prime the importer so it skips:

```powershell
py -3 tools\push_linear_issue_children_api.py --prime "TER-33`t[TV-00] 0.2.1 Topology (locked)"
py -3 tools\push_linear_issue_children_api.py
```

Progress is appended to `.linear_children_import_done.tsv` (ignored by Git) so re-runs are idempotent.

## Export limits (explicit)

Each exported child body caps at **~20 000 characters** in `tools/export_linear_issues.py` to match Linear payloads. Anything longer stays **canonical in Git** (`docs/tasklist/*.md`). Adjust the exporter if you need longer Linear descriptions.
