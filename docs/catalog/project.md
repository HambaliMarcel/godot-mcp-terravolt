# `project.*` catalog (v0.3.0)

Phase 3 work-unit #1 — project settings and autoload surface. Catalog version **`0.3.0`**.

| Method                    | Safe | Mutates | Editor | Headless | Notes                               |
| ------------------------- | ---- | ------- | ------ | -------- | ----------------------------------- |
| `project.info`            | yes  | no      | yes    | yes      | Name, main scene, paths, counts.    |
| `project.get_settings`    | yes  | no      | yes    | yes      | Read by `keys` or `group` prefix.   |
| `project.set_settings`    | no   | yes     | yes    | yes      | Patch settings; `dry_run` previews. |
| `project.list_autoloads`  | yes  | no      | yes    | yes      | Ordered autoload rows.              |
| `project.add_autoload`    | no   | yes     | yes    | yes      | Register singleton/script autoload. |
| `project.remove_autoload` | no   | yes     | yes    | yes      | Remove by name.                     |
| `project.set_main_scene`  | no   | yes     | yes    | yes      | Sets `application/run/main_scene`.  |

## Common errors

| Symbol                   | Code     | When                                                    |
| ------------------------ | -------- | ------------------------------------------------------- |
| `scene.path_not_found`   | `-33500` | `set_main_scene` with `validate=true` and missing file. |
| `project.setting_locked` | `-33590` | High-risk key without `confirm_high_risk`.              |
| `editor.not_available`   | `-33400` | Editor-only paths when daemon unavailable.              |

## Examples

**Project metadata**

```json
{ "method": "project.info", "params": {} }
```

**Patch rendering settings (dry run)**

```json
{
  "method": "project.set_settings",
  "params": {
    "patch": { "rendering/anti_aliasing/quality/msaa_2d": 1 },
    "dry_run": true
  }
}
```

**Set main scene**

```json
{ "method": "project.set_main_scene", "params": { "path": "res://main.tscn", "validate": true } }
```

## See also

- [`docs/guides/use-cases.md`](../guides/use-cases.md)
- [`docs/catalog/parity.md`](parity.md)
- Registry: `packages/shared/methods/registry.json`
