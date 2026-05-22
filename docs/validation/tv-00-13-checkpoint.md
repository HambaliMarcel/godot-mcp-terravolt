# Tasklist TV-00–13 validation checkpoint

**Canonical docs:** `docs/tasklist/00*.md` … `13-catalog-script-and-signal.md`

**Last sweep:** 2026-05-22 (post Phase 3 work-units #1–#3, commit `b41326d` on `master`)

## Automated checks

Run from repo root (`npm install` once):

| Command                 | Expect                                                                                                                                                                                        |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `npm run lint`          | Pass                                                                                                                                                                                          |
| `npm run format:check`  | Pass                                                                                                                                                                                          |
| `npm run typecheck`     | Pass                                                                                                                                                                                          |
| `npm run build:server`  | Pass                                                                                                                                                                                          |
| `npm run test:server`   | Pass — **15 tests**: CLI smoke (2), router unit (3), headless integration (1), MCP stdio E2E (1), addon parse-check (1), **scene** (1), **project** (1), **node** (1), **script+signal** (1). |
| `npm run catalog:sync`  | Pass (`catalog_version=0.5.0`, `packages/godot-mcp-addon/_generated/catalog_meta.gd`)                                                                                                         |
| `npm run release:check` | Pass (hash, version, 43 app error codes mirrored, readiness doc, CHANGELOG).                                                                                                                  |

## Catalog snapshot (registry)

| Metric             | Value                                                                         |
| ------------------ | ----------------------------------------------------------------------------- |
| `catalog_version`  | `0.5.0`                                                                       |
| Daemon methods     | **57**                                                                        |
| `headlessFallback` | **47**                                                                        |
| MCP router tools   | **13** (unchanged — daemon methods bridge via `context.fetch_raw` / registry) |

Phase 3 categories shipped: **`scene.*`** (15), **`project.*`** (7), **`node.*`** (14),
**`script.*`** (8), **`signal.*`** (10), plus 3 legacy server methods.

## Per-task rollup (truthful)

| ID     | Topic                               | Repo status                                                                                                                                                                                                                         |
| ------ | ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 00–01  | Foundation, repo & tooling          | Aligned with tasklists.                                                                                                                                                                                                             |
| 02–04  | Godot plugin + WS + JSON-RPC daemon | Implemented under `packages/godot-mcp-addon/`.                                                                                                                                                                                      |
| 05–06  | Node MCP router + shared catalog    | Implemented under `packages/mcp-server/`, `packages/shared/methods/registry.json`.                                                                                                                                                  |
| **07** | Headless fallback                   | **Substantially expanded.** `headless/catalog_ops.gd` dispatches scene/project/node/script/signal over TCP. Editor-only gaps documented in `docs/catalog/parity.md`. Backlog: full active-scene mutators, export/import, run_tests. |
| **08** | ~200-method catalog                 | **In progress (Phase 3).** Work-units **11–13** landed 54 new daemon methods; remaining categories in tasklists **14–25**.                                                                                                          |
| **09** | Context / errors / telemetry        | **Partial.** `tools.bottlenecks`, `context.fetch_raw`, `autoHeal` shipped; new catalog error bands `-335xx` / `-336xx` / `-337xx` mirrored. Envelopes / SLA budgets / batch fusion / `ifMatch` still backlog.                       |
| **10** | QA, release, docs                   | **Foundation complete + catalog tests.** CI workflows, `release:check`, support matrix, user guides. Integration coverage extended for tasks 11–13. Editor-mode E2E still deferred.                                                 |
| **11** | `scene.*` + `project.*`             | **Done.** Handlers, registry `0.3.0`→merged at `0.5.0`, headless ops, integration tests, `docs/catalog/scene.md` / `project.md`.                                                                                                    |
| **12** | `node.*`                            | **Done.** 14 tools, polymorphic `node.modify`, expression denylist, headless + integration test, `docs/catalog/node.md`.                                                                                                            |
| **13** | `script.*` + `signal.*`             | **Done.** 18 tools, `script_helpers.gd`, schemas, headless script/signal dispatch, integration test, `docs/catalog/script.md` / `signal.md`. Registry at **`0.5.0`**.                                                               |

## Known gaps (not blockers for 11–13 closure)

- **MCP surface:** still 13 router tools; new daemon methods are reachable via editor WS or headless
  TCP + `context.fetch_raw` until per-category MCP tool modules land (future §08/§06 work).
- **Headless partial paths:** `scene.open`/`save`, `node.duplicate`/`move`, `signal.connect`, etc. —
  see `docs/catalog/parity.md`.
- **`use-cases.md`:** documents the 13 MCP tools (correct for router layer); does not yet walk
  through catalog daemon methods by name.
- **Editor E2E:** no automated test drives the Godot editor UI for scene/node mutators with
  UndoRedo.

## References

- Parity matrix: `docs/catalog/parity.md`
- v1 readiness: `docs/release/v1-readiness.md`
- Prior sweep (00–10 only): `docs/validation/tv-00-10-checkpoint.md`
