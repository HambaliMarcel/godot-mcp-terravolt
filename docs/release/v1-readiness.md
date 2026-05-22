# v1 release readiness checklist

Mirrors `docs/tasklist/10 §10.6.16`. Tick items only after the linked artefact is in `master` and CI
is green.

| Gate                                                | Status (2026-05-22 v4, catalog 0.5.0 verified) | Notes                                                                                                                                                                                           |
| --------------------------------------------------- | ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| All §09 acceptance criteria met.                    | Partial                                        | `tools.bottlenecks`, `context.fetch_raw`, `autoHeal` ship; envelopes / SLA budgets / batch fusion / `ifMatch` not yet.                                                                          |
| At least one tool per category from §08.            | Partial                                        | **5 categories live:** scene, project, node, script, signal (57 daemon methods, catalog `0.5.0`); remaining §08 categories in tasklists `14`–`25` (TER-41).                                     |
| Showcase scenario §10.6.4 passes locally and in CI. | Partial                                        | Real-MCP-over-stdio + headless lifecycle E2E + catalog headless suites (scene/project/node/script/signal); full §08 showcase still pending remaining categories.                                |
| All workflows green for 7 consecutive days.         | Pending                                        | `lint.yml` + `unit.yml` only today.                                                                                                                                                             |
| No unresolved CRITICAL/HIGH bugs.                   | Yes (current)                                  | Four bugs from the real-MCP sweep fixed and documented in `CHANGELOG.md`.                                                                                                                       |
| Documentation site builds clean.                    | Yes                                            | Root `README.md` rewritten; `docs/README.md` indexes the new guides (`quick-start.md`, `mcp-usage.md`, `tools-reference.md`, `godot-integration.md`, `headless-only.md`, `troubleshooting.md`). |
| Support matrix updated.                             | Yes                                            | `docs/support-matrix.md`.                                                                                                                                                                       |
| Security review fresh.                              | Yes                                            | `SECURITY.md` updated per §10.6.11 / §A.10.                                                                                                                                                     |
| Decisions log up to date.                           | Pending                                        | Add v1.0 entry when shipping (`docs/tasklist/00 §0.13`).                                                                                                                                        |
| Release notes drafted from registry diff.           | Tooling ready                                  | `npm run release:notes`.                                                                                                                                                                        |

## Pre-tag command sequence

```powershell
npm run lint
npm run typecheck
npm run build:server
npm run test:server
npm run catalog:sync
npm run release:check
npm run release:notes -- --from v0.0.0   # initial run; replace with previous tag
```

`release:check` is the **gate**: it asserts the addon `_generated/catalog_meta.gd` SHA matches the
registry, all `-33xxx` codes in `packages/shared/errors/registry.json` are mirrored in
`error_codes.gd`, `CHANGELOG.md` mentions the router version, and this checklist file exists.

## Post-release

- Open issues from the §10.6.14 roadmap.
- Schedule the §10.6.17 weekly maintenance pass.
- Update `docs/support-matrix.md` only if a Godot or Node baseline shifts.
