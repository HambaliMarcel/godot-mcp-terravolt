# Tasklist TV-00–14 validation checkpoint

**Canonical docs:** `docs/tasklist/00*.md` … `14-catalog-resource-and-shader.md`

**Last sweep:** 2026-05-22 (Phase 3 work-unit #4, task 14 land)

## Automated checks

Run from repo root (`npm install` once):

| Command                 | Expect                                                                                |
| ----------------------- | ------------------------------------------------------------------------------------- |
| `npm run lint`          | Pass                                                                                  |
| `npm run format:check`  | Pass                                                                                  |
| `npm run typecheck`     | Pass                                                                                  |
| `npm run build:server`  | Pass                                                                                  |
| `npm run test:server`   | Pass — **16 tests**: prior 15 + **resource/shader headless** (1).                     |
| `npm run catalog:sync`  | Pass (`catalog_version=0.6.0`, `packages/godot-mcp-addon/_generated/catalog_meta.gd`) |
| `npm run release:check` | Pass (hash, version, 52 app error codes mirrored, readiness doc, CHANGELOG).          |

## Catalog snapshot (registry)

| Metric             | Value                                                                                      |
| ------------------ | ------------------------------------------------------------------------------------------ |
| `catalog_version`  | `0.6.0`                                                                                    |
| Daemon methods     | **78**                                                                                     |
| `headlessFallback` | **68** (editor-only: `resource.rename`, `resource.replace_references`, `resource.set_uid`) |
| MCP router tools   | **13** (unchanged — daemon methods bridge via registry)                                    |

Phase 3 categories shipped through task 14: **`scene.*`** (15), **`project.*`** (7), **`node.*`**
(14), **`script.*`** (8), **`signal.*`** (10), **`resource.*`** (15), **`shader.*`** (6), plus 3
legacy server methods.

## Task 14 rollup

| ID     | Topic                     | Repo status                                                                                                                                                                                                              |
| ------ | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **14** | `resource.*` + `shader.*` | **Done.** Handlers (`resource.gd`, `resource_helpers.gd`, `shader.gd`), registry `0.5.0`→`0.6.0`, headless ops in `catalog_ops.gd`, integration test + `resource_zoo` fixture, `docs/catalog/resource.md` / `shader.md`. |

## Fixes applied during validation

- Replaced invalid `ResourceLoader.get_resource_type()` (not in Godot 4.6) with
  `resource_class_from_path()` (load + `.tres` header sniff).
- Headless `shader.compile_check` uses probe-uniform compile heuristic (Godot does not expose
  structured compile errors at runtime).
- Integration test cleans fixture artifacts before run to avoid `resource.path_exists` flakes.

## Known gaps (not blockers for 14 closure)

- Editor-only resource methods (`rename`, `replace_references`, `set_uid`) return
  `editor.not_available` in headless — documented in `docs/catalog/parity.md`.
- `shader.compile_check` probe-uniform heuristic may miss edge cases where drivers optimize out
  unused uniforms.
- Dependency index / `resource.get_dependents` is stubbed (empty) in headless v1.

## References

- Parity matrix: `docs/catalog/parity.md`
- Prior sweep (00–13): `docs/validation/tv-00-13-checkpoint.md`
- Task spec: `docs/tasklist/14-catalog-resource-and-shader.md`
