# Tasklist TV-00–15 validation checkpoint

**Canonical docs:** `docs/tasklist/00*.md` … `15-catalog-asset-and-batch-refactor.md`

**Last sweep:** 2026-05-22 (Phase 3 work-unit #5, task 15 land)

## Automated checks

| Command                 | Expect                                        |
| ----------------------- | --------------------------------------------- |
| `npm run lint`          | Pass                                          |
| `npm run format:check`  | Pass                                          |
| `npm run typecheck`     | Pass                                          |
| `npm run build:server`  | Pass                                          |
| `npm run test:server`   | Pass — **17 tests** (+ asset/batch headless). |
| `npm run catalog:sync`  | Pass (`catalog_version=0.7.0`).               |
| `npm run release:check` | Pass (61 app error codes mirrored).           |

## Catalog snapshot

| Metric            | Value                                        |
| ----------------- | -------------------------------------------- |
| `catalog_version` | `0.7.0`                                      |
| Daemon methods    | **98**                                       |
| New in task 15    | **20** (`asset.*` 12 + `batch_refactor.*` 8) |

## Task 15 rollup

| ID     | Topic                          | Repo status                                                                                                                                    |
| ------ | ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| **15** | `asset.*` + `batch_refactor.*` | **Done.** Handlers, helpers, batch journal, registry `0.6.0`→`0.7.0`, headless dispatch, integration test + `asset_zoo` fixture, catalog docs. |

## Fixes during validation

- `ResourceUID.path_to_id()` → `ResourceLoader.get_resource_uid()` (Godot 4.6).
- Restored `resource_class_from_path()` in `_collect_resources` (regression from partial edit).
- `asset_helpers.gd` preloads `resource_helpers.gd` for reference rewrites.

## References

- Parity: `docs/catalog/parity.md`
- Prior: `docs/validation/tv-00-14-checkpoint.md`
- Spec: `docs/tasklist/15-catalog-asset-and-batch-refactor.md`
