# Tasklist TV-00–16 validation checkpoint

**Canonical docs:** `docs/tasklist/00*.md` … `16-catalog-editor-and-analysis.md`

**Last sweep:** 2026-05-22 (Phase 3 work-unit #6, task 16 land)

## Automated checks

| Command                 | Expect                                     |
| ----------------------- | ------------------------------------------ |
| `npm run lint`          | Pass                                       |
| `npm run format:check`  | Pass                                       |
| `npm run typecheck`     | Pass                                       |
| `npm run build:server`  | Pass                                       |
| `npm run test:server`   | Pass — **18 tests** (+ analysis headless). |
| `npm run catalog:sync`  | Pass (`catalog_version=0.8.0`).            |
| `npm run release:check` | Pass (65 app error codes mirrored).        |

## Catalog snapshot

| Metric            | Value                                  |
| ----------------- | -------------------------------------- |
| `catalog_version` | `0.8.0`                                |
| Daemon methods    | **111**                                |
| New in task 16    | **13** (`editor.*` 9 + `analysis.*` 4) |

## Task 16 rollup

| ID     | Topic                     | Repo status                                                                                                                             |
| ------ | ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| **16** | `editor.*` + `analysis.*` | **Done.** Handlers, analysis helpers, editor error buffer, registry `0.7.0`→`0.8.0`, headless dispatch, integration test, catalog docs. |

## References

- `docs/catalog/editor.md`, `docs/catalog/analysis.md`, `docs/catalog/parity.md`
- Linear: TER-52 (TV-16)
