# `scene.*` catalog (v0.3.0)

Phase 3 work-unit #1 — scene read/write surface. Catalog version **`0.3.0`**.

| Method               | Safe | Mutates | Editor | Headless | Notes                                        |
| -------------------- | ---- | ------- | ------ | -------- | -------------------------------------------- |
| `scene.list`         | yes  | no      | yes    | yes      | Enumerate `.tscn` / `.scn` under `res://`.   |
| `scene.get`          | yes  | no      | yes    | yes      | Metadata without instantiating.              |
| `scene.open`         | yes  | no      | yes    | no       | `editor.not_available` headless.             |
| `scene.close`        | no   | yes     | yes    | no       | Best-effort tab close.                       |
| `scene.save`         | no   | yes     | yes    | no       | Saves active edited scene.                   |
| `scene.save_as`      | no   | yes     | yes    | no       | Save under new path.                         |
| `scene.create`       | no   | yes     | yes    | yes      | New scene with typed root.                   |
| `scene.delete`       | no   | yes     | yes    | yes      | Delete file; `force` skips dependency guard. |
| `scene.instantiate`  | no   | yes     | yes    | partial  | Needs active scene tree.                     |
| `scene.pack`         | no   | yes     | yes    | partial  | Pack subtree to new `.tscn`.                 |
| `scene.get_tree`     | yes  | no      | yes    | partial  | Envelope-aware tree walk.                    |
| `scene.get_subtree`  | yes  | no      | yes    | partial  | Subtree from `NodePath`.                     |
| `scene.find_in_tree` | yes  | no      | yes    | partial  | Selector search.                             |
| `scene.validate`     | yes  | no      | yes    | yes      | Returns `{ ok, issues[] }`.                  |
| `scene.replace`      | no   | yes     | yes    | partial  | Subtree replace with undo in editor.         |

## Common errors

| Symbol                      | Code     | When                                |
| --------------------------- | -------- | ----------------------------------- |
| `scene.path_not_found`      | `-33500` | Missing `.tscn` path.               |
| `scene.node_path_not_found` | `-33501` | NodePath missing in active tree.    |
| `scene.create_failed`       | `-33510` | `ResourceSaver.save` / pack failed. |
| `scene.save_failed`         | `-33511` | Editor save failed.                 |
| `node.type_unknown`         | `-33520` | Invalid `root_type` / class name.   |
| `resource.dependency_block` | `-33550` | Delete blocked by dependents.       |
| `editor.not_available`      | `-33400` | Editor-only op in headless.         |
| `editor.no_active_scene`    | `-33580` | No scene tab / edited root.         |

## Examples

**List scenes**

```json
{ "method": "scene.list", "params": { "include_imported": false } }
```

**Create then read**

```json
{ "method": "scene.create", "params": { "path": "res://levels/Cave.tscn", "root_type": "Node3D", "root_name": "CaveRoot" } }
{ "method": "scene.get", "params": { "path": "res://levels/Cave.tscn" } }
```

## See also

- [`docs/guides/use-cases.md`](../guides/use-cases.md)
- [`docs/catalog/parity.md`](parity.md)
- Registry: `packages/shared/methods/registry.json`
