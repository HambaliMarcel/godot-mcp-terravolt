# 12 — Catalog: `node.*` (Phase 3 work-unit #2)

> The `node.*` category is the **polymorphic core** of TerraVolt. Every other category eventually
> delegates here for tree manipulation. Get the contract right and the rest of Phase 3 becomes a
> parade of thin wrappers.

---

## 12.1 Header

- **File:** `12-catalog-node-polymorphic.md`
- **Purpose:** ship the **node.\*** category (14 tools): create / delete / duplicate / move,
  property read & write, signals, groups, type queries.
- **Tool count this file:** 14.

## 12.2 Phase placement

- **Phase 3, work-unit #2.**
- Prerequisite: file `11` shipped (`scene.*` + `project.*` live).
- Gates: files `13`–`24` will lean heavily on `node.*` semantics.

## 12.3 Inputs / prerequisites

- Add handler module `packages/godot-mcp-addon/handlers/node.gd` (statically-typed `@tool`
  GDScript).
- Add router module `packages/mcp-server/src/tools/node/` (mostly auto-generated; manual override
  only for `node.modify` because of polymorphic payloads).
- Catalog version bumps to **`0.4.0`** when this file lands.
- Shared schema additions:
  - `PropertyDict`: open-ended key/value object — value must round-trip through `06`'s
    Variant-↔-JSON mapping.
  - `SignalConnection`: `{ signal, target_path, method, flags?, binds?: any[] }`.

## 12.4 Outputs

When this file is done:

1. 14 tools live, each registered with `inputSchema`/`outputSchema`/error list/examples.
2. Polymorphic `node.modify` test matrix (set / add_to_group / remove_from_group / connect /
   disconnect) green.
3. UndoRedo verified in the editor for every mutator.
4. `docs/catalog/node.md` regenerated.

## 12.5 Operating constants used

- `tree_depth_default = 3` (envelope clamps).
- Per-call rate-limit: identical to `00 §0.3` (no new constants).

---

## 12.6 `node.*` — 14 tools

> **Naming.** Tool names use **dot-case** (`node.add`), not snake_case (`node_add`), per `00 §0.4`.
> **NodePath rules.** All inputs accept Godot NodePaths including `%UniqueName` shortcuts; the
> daemon resolves against the active edited scene unless `scene_path` is supplied (then it loads
> that scene transiently). **Owner discipline.** Every mutator that adds a node sets
> `node.owner = scene_root` so the change persists when the scene is saved. **Undo.** Editor-side
> mutators wrap actions in `EditorPlugin.get_undo_redo()` with `create_action(name)` /
> `add_do_method` / `add_undo_method` / `commit_action`.

### `node.add`

- **Purpose:** add a new node under a parent.
- **Inputs:**
  `{ parent_path: NodePath, type: string (Godot class name OR script ResourcePath), name?: string, properties?: PropertyDict, groups?: [string], index?: int, unique_name?: bool (default false) }`.
- **Outputs:** `{ added_path: NodePath, type, owner: NodePath, state: <node.get>, diff, revision }`.
- **Godot APIs:** `ClassDB.instantiate(type)` or `load(script_path).new()` for script-rooted types;
  `parent.add_child(child, true)` (force readable name); `parent.move_child(child, index)`;
  `child.unique_name_in_owner = true` if requested.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** false. **mutates:** true.
- **Errors:** `node.type_unknown` (`-33520`), `scene.node_path_not_found` (`-33501`).
- **Cursor prompt:** _"Add an AnimationPlayer named PlayerAnim under /root/Main/Player."_

### `node.delete`

- **Purpose:** remove a node (and its subtree) from the active scene.
- **Inputs:**
  `{ path: NodePath, defer?: bool (default true), free_resources?: bool (default false) }`.
- **Outputs:** `{ deleted_path, removed_node_count, state, diff, revision }`.
- **Godot APIs:** prefer `Node.queue_free()` (deferred) over `Node.free()` to avoid re-entrancy
  bugs; only `free()` immediately when `defer=false` AND the daemon can prove the call is outside
  the active signal chain (use `Object.is_class("SceneTree")` check on the active call stack).
- **Editor:** ✅. **Headless:** ✅.
- **safe:** false. **mutates:** true.
- **Errors:** `scene.node_path_not_found`.
- **Cursor prompt:** _"Delete /root/Main/OldPickup."_

### `node.duplicate`

- **Purpose:** clone a node (and optionally its subtree) under a target parent.
- **Inputs:**
  `{ source_path: NodePath, target_parent_path?: NodePath (default same parent), new_name?: string, flags?: { children?: bool, signals?: bool, scripts?: bool, groups?: bool } (defaults all true), shallow?: bool (default false) }`.
- **Outputs:** `{ duplicate_path: NodePath, name, state, diff, revision }`.
- **Godot APIs:** `Node.duplicate(flags)` where flags is the bitwise OR of `Node.DUPLICATE_*`
  constants; reparent if needed.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** false. **mutates:** true.
- **Errors:** `scene.node_path_not_found`.
- **Cursor prompt:** _"Duplicate /root/Main/Enemy as EnemyClone."_

### `node.move`

- **Purpose:** reparent a node and/or change sibling order.
- **Inputs:**
  `{ source_path: NodePath, target_parent_path: NodePath, index?: int (default last), keep_global_transform?: bool (default true), new_name?: string }`.
- **Outputs:** `{ new_path: NodePath, previous_path: NodePath, state, diff, revision }`.
- **Godot APIs:** `node.reparent(new_parent, keep_global_transform)`;
  `parent.move_child(node, index)`.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** false. **mutates:** true.
- **Errors:** `scene.node_path_not_found`, `node.cycle_detected` (`-33521`) when reparenting a node
  under itself.
- **Cursor prompt:** _"Move /root/Main/UI/HUD under /root/Main/CanvasLayer at index 0."_

### `node.rename`

- **Purpose:** rename a node, fixing inbound NodePath references where safely possible.
- **Inputs:**
  `{ path: NodePath, new_name: string, update_references?: bool (default true), dry_run?: bool }`.
- **Outputs:**
  `{ new_path: NodePath, references_updated: [{ from_path, property_or_script, before, after }], dry_run: bool, state, diff, revision }`.
- **Godot APIs:** `node.name = new_name` (must be unique among siblings); ref update walks the scene
  tree (and optionally `script.find_usages` from file `13`).
- **Editor:** ✅. **Headless:** ✅.
- **safe:** false. **mutates:** true.
- **Errors:** `node.name_collision` (`-33522`).
- **Cursor prompt:** _"Rename /root/Main/Player to Hero."_

### `node.get`

- **Purpose:** read a node's identity + serializable properties.
- **Inputs:**
  `{ path: NodePath, properties?: "all"|[string] (default "all"), include_hint?: bool (default true), include_export?: bool (default true), envelope?: "summary"|"raw" (default "summary") }`.
- **Outputs:**
  `{ path, name, type, script?: ResourcePath, owner_path, groups: [string], unique_name_in_owner: bool, properties: { key: { value, type, hint?, hint_string?, default?, is_overridden? } } }`.
- **Godot APIs:** `Node.get_class()`, `Object.get_property_list()`, `Object.get(key)`,
  `Node.get_groups()`, `Node.get_script()`.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** true. **mutates:** false.
- **Errors:** `scene.node_path_not_found`.
- **Cursor prompt:** _"What's on /root/Main/Player? Properties + groups."_

### `node.modify`

- **Purpose:** polymorphic mutator combining property writes, group changes, and signal connections
  in **one atomic call**.
- **Inputs:** `{ path: NodePath, ops: [Op], dry_run?: bool, if_match?: opaque-revision }` where
  `Op = { kind: "set", key, value } | { kind: "set_path", key, value } | { kind: "unset", key } | { kind: "add_to_group", group, persistent?: bool } | { kind: "remove_from_group", group } | { kind: "set_meta", key, value } | { kind: "remove_meta", key } | { kind: "connect", signal, target_path, method, flags?, binds? } | { kind: "disconnect", signal, target_path, method }`.
- **Outputs:**
  `{ applied: [Op + before-state-per-op], skipped: [Op + reason], dry_run, state, diff, revision }`.
- **Godot APIs:** `Object.set(key, value)`, `Node.add_to_group(group, persistent)`,
  `Node.remove_from_group(group)`, `Object.set_meta`/`remove_meta`,
  `Object.connect(signal, Callable)`, `Object.disconnect(signal, Callable)`. Ops execute as a
  transaction inside one UndoRedo `create_action`/`commit_action` so Ctrl-Z reverts the whole batch.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** false. **mutates:** true.
- **Errors:** `node.property_unknown` (`-33523`), `node.value_type_mismatch` (`-33524`),
  `signal.unknown` (see `13`), `protocol.idempotency_conflict` (`-33002`).
- **Cursor prompt:** _"On /root/Main/Player set speed=550, add to group 'players', and connect
  health_changed to /root/Main/UI/HUD::\_on_health_changed."_

### `node.list_groups`

- **Purpose:** enumerate groups for a node (and optionally for the whole tree).
- **Inputs:**
  `{ path?: NodePath, recursive?: bool (default false), scope?: "scene"|"active" (default "active") }`.
- **Outputs:** `{ groups: [string] }` or `{ by_path: { NodePath: [string] }, distinct: [string] }`
  when recursive.
- **Godot APIs:** `Node.get_groups()`; `SceneTree.get_nodes_in_group(name)` for reverse lookup.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Which groups is /root/Main/Player in? And which groups exist project-wide?"_

### `node.list_signals`

- **Purpose:** enumerate declared signals and active connections on a node.
- **Inputs:**
  `{ path: NodePath, include_inherited?: bool (default true), include_connections?: bool (default true) }`.
- **Outputs:**
  `{ signals: [{ name, args: [{ name, type }], inherited_from?: string, connections: [{ target_path, method, flags, binds }] }] }`.
- **Godot APIs:** `Object.get_signal_list()`, `Object.get_signal_connection_list(signal)`.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"What signals does /root/Main/Player have, and who's listening?"_

### `node.find_path`

- **Purpose:** resolve a `Selector` to a concrete NodePath (or list of paths) in the active scene.
- **Inputs:** `{ selector: Selector, expect?: "single"|"many" (default "many") }`.
- **Outputs:** `{ paths: [NodePath], scene_path: ScenePath }`.
- **Godot APIs:** `Node.find_children(pattern, type, true, true)`, `SceneTree.get_nodes_in_group`.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** true. **mutates:** false.
- **Errors:** `selector.no_match` (`-33525`) when `expect="single"` and 0 or >1 results.
- **Cursor prompt:** _"Find the node tagged with the 'boss' group."_

### `node.is_a`

- **Purpose:** type query — is a node an instance of (or descendant from) a class / script?
- **Inputs:** `{ path: NodePath, type: string }`.
- **Outputs:** `{ match: bool, actual_type, class_hierarchy: [string] }`.
- **Godot APIs:** `Object.is_class(type)` and `Script` walk via `Script.get_base_script()`.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Is /root/Main/Player a CharacterBody2D?"_

### `node.attach_script`

- **Purpose:** attach a script to a node (creating one if necessary — defers to `13 script.create`).
- **Inputs:**
  `{ path: NodePath, script_path: ResourcePath, replace_existing?: bool (default false) }`.
- **Outputs:**
  `{ attached: true, script_path, previous_script_path?: ResourcePath, state, diff, revision }`.
- **Godot APIs:** `node.set_script(load(script_path))`; if `replace_existing=false` and one exists,
  fail with `node.script_already_attached`.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** false. **mutates:** true.
- **Errors:** `node.script_already_attached` (`-33526`), `script.path_not_found` (see `13`).
- **Cursor prompt:** _"Attach res://scripts/Player.gd to /root/Main/Player."_

### `node.detach_script`

- **Purpose:** remove the script from a node.
- **Inputs:** `{ path: NodePath }`.
- **Outputs:**
  `{ detached: true, previous_script_path: ResourcePath | null, state, diff, revision }`.
- **Godot APIs:** `node.set_script(null)`.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Detach the script from /root/Main/Tester."_

### `node.evaluate_expression`

- **Purpose:** evaluate a sandboxed Godot `Expression` against a node's context (for read-only
  inspection).
- **Inputs:** `{ path: NodePath, expression: string, inputs?: PropertyDict }`.
- **Outputs:** `{ value, type, error?: { line, col, message } }`.
- **Godot APIs:** `Expression.new()`, `Expression.parse(expression, [param_names])`,
  `Expression.execute(values, base_instance)`; reject expressions that touch `File`, `OS`, `os`,
  `Engine.execute`, etc., via static AST prefilter.
- **Editor:** ✅. **Headless:** ✅.
- **safe:** true (sandboxed). **mutates:** false.
- **Errors:** `expression.parse_error` (`-33527`), `expression.execute_error` (`-33528`),
  `expression.forbidden_identifier` (`-33529`).
- **Cursor prompt:** _"Evaluate `position.x + 32` on /root/Main/Player."_

---

## 12.7 Schemes / data shapes added

- `PropertyDict` finalized at `packages/shared/schemas/common/PropertyDict.json` — patternProperties
  with Variant values; reject `Object`-typed values that aren't `Resource` / `NodePath`.
- `NodeDiff` shape:
  `{ added_nodes: [NodePath], removed_nodes: [NodePath], renamed: [{ from, to }], property_changes: [{ path, key, before, after }], group_changes: [{ path, added: [string], removed: [string] }], signal_changes: [{ path, added: [...], removed: [...] }] }`.

## 12.8 Tech stack delta

- No new dependencies.
- Daemon adds `handlers/node.gd`.
- Router auto-generates 13 tool modules; `node.modify` has a hand-rolled wrapper because its input
  is polymorphic (oneOf with discriminator on `kind`).

## 12.9 Acceptance criteria

- [ ] All 14 tools live; visible via `tools.list({category: "node"})`.
- [ ] `node.modify` round-trips every `Op.kind` listed.
- [ ] Editor-side Ctrl-Z reverts every multi-op `node.modify` as a single undo step.
- [ ] Headless variant of every tool that claims headless support has at least one passing test.
- [ ] `node.evaluate_expression` rejects forbidden identifiers (OS, File, DirAccess, FileAccess,
      etc.) — covered by a deny-list integration test.
- [ ] `node.rename` with `update_references=true` rewrites NodePath properties on sibling nodes
      inside the active scene (cross-scene rewrites are deferred to `15 batch_refactor`).

## 12.10 Verification plan

1. **Create-then-read:** `node.add` → `node.get` matches submitted properties.
2. **Mutate-then-diff:** `node.modify` with 4 ops → output `state.diff` lists all 4 changes; Ctrl-Z
   restores baseline.
3. **Polymorphism:** `node.is_a` returns `true` for both class names ("Node2D") and ancestor classes
   ("CanvasItem").
4. **Reparenting:** `node.move` preserves `global_transform` when `keep_global_transform=true`;
   verify with `node.get { properties: ["global_position"] }` before/after.
5. **Headless:** drive an off-screen fixture scene through start/duplicate/delete/save cycle.
6. **Notifications:** `event.node.added`, `event.node.removed`, `event.node.renamed`,
   `event.node.moved` emit with throttled payloads.

## 12.11 Risks & mitigations

| Risk                                                                             | Mitigation                                                                                                                                |
| -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Polymorphic `node.modify` opens an enormous schema surface.                      | Discriminator-based JSON Schema; reject unknown `kind` with `protocol.invalid_params`.                                                    |
| `Object.set(key, value)` silently no-ops on unknown keys in some Godot versions. | Pre-check with `property in node.get_property_list()` before set; raise `node.property_unknown` otherwise.                                |
| `Node.free()` vs `queue_free()` mistakes crash the editor.                       | Default to `defer=true`; only allow `defer=false` when called from a known-safe path.                                                     |
| Expression sandbox bypass via clever string.                                     | AST-level static rejection of OS/File/DirAccess identifiers; deny list maintained in `packages/shared/security/expression_denylist.json`. |
| Cross-scene references go stale after `node.rename`.                             | Out-of-scope here; raise an info-level diagnostic and defer to `15 batch_refactor.rename`.                                                |

## 12.12 Handoff checklist to file `13`

- [ ] Catalog version `0.4.0` pushed.
- [ ] 30 tools total live (`scene.*` 9 + `project.*` 7 + `node.*` 14).
- [ ] `node.evaluate_expression` denylist test in CI.
- [ ] Open `13-catalog-script-and-signal.md`.

## 12.13 Commit template

```text
feat(catalog): ship node.* (14 tools) — Phase 3 work-unit #2

- Polymorphic node.modify with transactional Op array
- UndoRedo integration for every mutator
- Sandboxed node.evaluate_expression (deny OS/File/DirAccess)
- Bumps catalog_version 0.3.0 -> 0.4.0

Refs: docs/tasklist/12-catalog-node-polymorphic.md
```
