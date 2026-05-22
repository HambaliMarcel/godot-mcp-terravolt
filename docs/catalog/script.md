# `script.*` catalog (v0.5.0)

Phase 3 work-unit #3 — script read/write/validate surface.

| Method                 | Safe | Mutates | Editor | Headless | Notes                          |
| ---------------------- | ---- | ------- | ------ | -------- | ------------------------------ |
| `script.list`          | yes  | no      | yes    | yes      | Walk `.gd` / `.cs` / shaders.  |
| `script.read`          | yes  | no      | yes    | yes      | 96 KB inline cap.              |
| `script.write`         | no   | yes     | yes    | yes      | Supports `if_match` revision.  |
| `script.patch`         | no   | yes     | yes    | yes      | Line-range hunks.              |
| `script.validate`      | yes  | no      | yes    | yes      | `.gd` via `GDScript.reload()`. |
| `script.find_usages`   | yes  | no      | yes    | yes      | Word-boundary scan.            |
| `script.rename_symbol` | no   | yes     | yes    | no       | Editor-first v1.               |
| `script.format`        | no   | yes     | yes    | yes      | Minimal built-in formatter.    |

## Language parity

| Language               | read/write | validate                                     | format   |
| ---------------------- | ---------- | -------------------------------------------- | -------- |
| `.gd`                  | yes        | yes (syntax)                                 | minimal  |
| `.cs`                  | yes        | dotnet build (editor) / unavailable headless | deferred |
| `.shader` / `.vshader` | yes        | text-only                                    | no       |

## Errors

| Symbol                      | Code     |
| --------------------------- | -------- |
| `script.path_not_found`     | `-33600` |
| `script.path_exists`        | `-33601` |
| `script.patch_conflict`     | `-33602` |
| `script.dotnet_unavailable` | `-33603` |

See [`docs/catalog/signal.md`](signal.md).
