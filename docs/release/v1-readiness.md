# v1 release readiness checklist

Mirrors `docs/tasklist/10 §10.6.16`. Tick items only after the linked artefact is
in `master` and CI is green.

| Gate | Status (2026-05-22) | Notes |
| ---- | ------------------- | ----- |
| All §09 acceptance criteria met. | Partial | `tools.bottlenecks`, `context.fetch_raw`, `autoHeal` ship; envelopes / SLA budgets / batch fusion / `ifMatch` not yet. |
| At least one tool per category from §08. | Not started | Catalog still bootstrap-sized; tracked under TER-41. |
| Showcase scenario §10.6.4 passes locally and in CI. | Not started | Requires §08 catalog. |
| All workflows green for 7 consecutive days. | Pending | `lint.yml` + `unit.yml` only today. |
| No unresolved CRITICAL/HIGH bugs. | Pending | Pre-1.0 milestone. |
| Documentation site builds clean. | In progress | `docs/guides/`, `docs/support-matrix.md`, `docs/catalog/parity.md`, `docs/release/v1-readiness.md` added. |
| Support matrix updated. | Yes | `docs/support-matrix.md`. |
| Security review fresh. | Yes | `SECURITY.md` updated per §10.6.11 / §A.10. |
| Decisions log up to date. | Pending | Add v1.0 entry when shipping (`docs/tasklist/00 §0.13`). |
| Release notes drafted from registry diff. | Tooling ready | `npm run release:notes`. |

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

`release:check` is the **gate**: it asserts the addon `_generated/catalog_meta.gd`
SHA matches the registry, all `-33xxx` codes in
`packages/shared/errors/registry.json` are mirrored in `error_codes.gd`,
`CHANGELOG.md` mentions the router version, and this checklist file exists.

## Post-release

- Open issues from the §10.6.14 roadmap.
- Schedule the §10.6.17 weekly maintenance pass.
- Update `docs/support-matrix.md` only if a Godot or Node baseline shifts.
