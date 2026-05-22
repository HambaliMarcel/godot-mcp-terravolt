# Tasklist TV-00–16 validation checkpoint

**Canonical docs:** `docs/tasklist/00*.md` … `16-catalog-editor-and-analysis.md`

**Last sweep:** 2026-05-22 (maintainer re-validation after tasks **00–16** land)

## Automated checks

Run from repo root (`npm install` once):

| Command                 | Result (2026-05-22)                                                          |
| ----------------------- | ---------------------------------------------------------------------------- |
| `npm run lint`          | Pass                                                                         |
| `npm run format:check`  | Pass (after Prettier on agent docs)                                          |
| `npm run typecheck`     | Pass                                                                         |
| `npm run build:server`  | Pass                                                                         |
| `npm run test:server`   | Pass — **18 tests** (CLI 2, unit 6, integration 10 incl. analysis headless). |
| `npm run catalog:sync`  | Pass (`catalog_version=0.8.0`, `REGISTRY_SHA256=3982a6cb4a06…`).             |
| `npm run release:check` | Pass (65 app error codes mirrored).                                          |

## Catalog snapshot (registry)

| Metric             | Value                                                                         |
| ------------------ | ----------------------------------------------------------------------------- |
| `catalog_version`  | **`0.8.0`**                                                                   |
| Daemon methods     | **111**                                                                       |
| `headlessFallback` | **92**                                                                        |
| `requiresEditor`   | **21**                                                                        |
| MCP router tools   | **13** (unchanged — daemon methods bridge via registry / `context.fetch_raw`) |

### Methods by category (tasks 11–16)

| Category           | Count | Task                                |
| ------------------ | ----- | ----------------------------------- |
| `scene.*`          | 15    | 11                                  |
| `project.*`        | 7     | 11                                  |
| `node.*`           | 14    | 12                                  |
| `script.*`         | 8     | 13                                  |
| `signal.*`         | 10    | 13                                  |
| `resource.*`       | 15    | 14                                  |
| `shader.*`         | 6     | 14                                  |
| `asset.*`          | 12    | 15                                  |
| `batch_refactor.*` | 8     | 15                                  |
| `editor.*`         | 9     | 16                                  |
| `analysis.*`       | 4     | 16                                  |
| bootstrap          | 3     | 02–06 (`ping`, `server.*`, `log.*`) |

## Per-task rollup (00–16)

| ID     | Topic                               | Status                                                                                                                                                           |
| ------ | ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 00–01  | Foundation, repo & tooling          | **Done** — contracts, monorepo, CI scaffolding aligned with tasklists.                                                                                           |
| 02–04  | Godot plugin + WS + JSON-RPC daemon | **Done** — `packages/godot-mcp-addon/` (EditorPlugin, dispatcher, logging, MCP server).                                                                          |
| 05–06  | Node MCP router + shared catalog    | **Done** — `packages/mcp-server/`, `registry.json`, `catalog-sync.mjs`, daemon bridge.                                                                           |
| **07** | Headless fallback                   | **In progress** — **92/111** methods have headless parity; editor-only gaps in `docs/catalog/parity.md`. Backlog: export/import, run_tests, full scene mutators. |
| **08** | ~200-method catalog                 | **In progress** — work-units **11–16** landed (**111** methods); remaining categories in tasklists **17–25** (TER-41).                                           |
| **09** | Context / errors / telemetry        | **Partial** — `tools.bottlenecks`, `context.fetch_raw`, `autoHeal`; **65** mirrored error codes; envelopes / SLA / batch fusion backlog.                         |
| **10** | QA, release, docs                   | **Foundation complete** — CI, `release:check`, guides, **18** integration tests; editor UI E2E still deferred.                                                   |
| **11** | `scene.*` + `project.*`             | **Done** — handlers, headless ops, integration test, catalog docs.                                                                                               |
| **12** | `node.*`                            | **Done** — 14 tools, expression denylist, headless + integration test.                                                                                           |
| **13** | `script.*` + `signal.*`             | **Done** — 18 tools, `script_helpers.gd`, headless dispatch, integration test.                                                                                   |
| **14** | `resource.*` + `shader.*`           | **Done** — 21 tools, `resource_helpers.gd`, `resource_zoo` fixture, integration test.                                                                            |
| **15** | `asset.*` + `batch_refactor.*`      | **Done** — 20 tools, batch journal, `asset_zoo` fixture, integration test.                                                                                       |
| **16** | `editor.*` + `analysis.*`           | **Done** — 13 tools, error buffer, analysis helpers, integration test; editor live-stream event deferred.                                                        |

## Fixes during this sweep

- **`catalog_meta.gd` SHA drift:** Prettier reformatted `registry.json` after an earlier
  `catalog:sync`, leaving committed `REGISTRY_SHA256` stale until re-sync. **Always run
  `npm run catalog:sync` after editing or formatting `registry.json`.**
- **`format:check` on agent docs:** GitNexus wiki injection reformatted `AGENTS.md` / `CLAUDE.md`;
  Prettier pass restores gate green.

## Known gaps (not blockers for 00–16 closure)

- **MCP surface:** still 13 router tools; per-category MCP modules remain backlog (§06/§08).
- **Editor E2E:** no automated UI tests for `editor.screenshot`, undo/redo, or layout APIs.
- **`event.editor.error_logged`:** live stream + throttling not implemented (task 16 backlog).
- **Headless partial:** `batch_refactor.normalize_names`, `asset.reimport`, `editor.*` (except
  `error_log_tail`), resource UID/rename ops — see `docs/catalog/parity.md`.
- **§08 remaining:** runtime, animation, physics, etc. in tasklists **17–25**.

## References

- Parity: `docs/catalog/parity.md`
- Readiness: `docs/release/v1-readiness.md`
- Prior sweeps: `docs/validation/tv-00-10-checkpoint.md` … `tv-00-15-checkpoint.md`
- Linear: TER-41 (§08), TER-40 (§07), TER-42 (§10), TER-52 (TV-16)
