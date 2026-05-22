# `node.*` catalog (v0.4.0)

Phase 3 work-unit #2 — polymorphic node tree manipulation. Catalog version **`0.4.0`**.

| Method                     | Safe | Mutates | Editor | Headless | Notes                                      |
| -------------------------- | ---- | ------- | ------ | -------- | ------------------------------------------ |
| `node.add`                 | no   | yes     | yes    | yes      | Typed child under parent; sets `owner`.    |
| `node.delete`              | no   | yes     | yes    | yes      | Default `defer=true` (`queue_free`).       |
| `node.duplicate`           | no   | yes     | yes    | partial  | Headless v1 deferred.                      |
| `node.move`                | no   | yes     | yes    | partial  | Reparent + sibling index.                  |
| `node.rename`              | no   | yes     | yes    | partial  | Optional in-scene NodePath rewrite.        |
| `node.get`                 | yes  | no      | yes    | yes      | Properties + groups snapshot.              |
| `node.modify`              | no   | yes     | yes    | yes      | Transactional `ops[]` batch.               |
| `node.list_groups`         | yes  | no      | yes    | yes      | Per-node or recursive.                     |
| `node.list_signals`        | yes  | no      | yes    | yes      | Declarations + connections.                |
| `node.find_path`           | yes  | no      | yes    | yes      | `Selector` → paths.                        |
| `node.is_a`                | yes  | no      | yes    | yes      | Class / script check.                      |
| `node.attach_script`       | no   | yes     | yes    | partial  | Requires script path.                      |
| `node.detach_script`       | no   | yes     | yes    | partial  | Clears script.                             |
| `node.evaluate_expression` | yes  | no      | yes    | yes      | Sandboxed `Expression`; denylist enforced. |

## `node.modify` op kinds

`set`, `set_path`, `unset`, `add_to_group`, `remove_from_group`, `set_meta`, `remove_meta`,
`connect`, `disconnect`

## Common errors

| Symbol                            | Code     |
| --------------------------------- | -------- |
| `scene.node_path_not_found`       | `-33501` |
| `node.type_unknown`               | `-33520` |
| `node.cycle_detected`             | `-33521` |
| `node.name_collision`             | `-33522` |
| `node.property_unknown`           | `-33523` |
| `selector.no_match`               | `-33525` |
| `expression.forbidden_identifier` | `-33529` |

Denylist source: `packages/shared/security/expression_denylist.json`

## See also

- [`docs/catalog/scene.md`](scene.md)
- [`docs/catalog/parity.md`](parity.md)
