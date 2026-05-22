# 06 — Tool Translation Layer (Phase 2, part B)

> **Goal**: industrialize the "MCP tool ↔ Godot JSON-RPC op" mapping. After this file, adding a new
> tool is a _boilerplate-light, schema-first_ exercise: declare schema, declare daemon op, declare
> normalizer for the response, and it lights up across both ends. This file is the **factory** for
> the 200+ tools in `08`. It also wires the **shared error registry**, **shared method registry**,
> and **versioned tool catalog** so that the agent, the router, and the daemon agree on every name,
> every schema, and every error code.

---

## 6.1 Header

- **File:** `06-tool-translation-layer.md`
- **Purpose:** establish the registration mechanics, schema validation, response normalization,
  request lifecycle, and shared registries that the tool catalog (`08`) plugs into.

## 6.2 Phase placement

- **Phase 2, part B.** Completes Phase 2 with `05`.
- Gates Phase 3 — `08`'s catalog cannot ship without this file.

## 6.3 Inputs / prerequisites

- `05` complete: router transport works, three built-in tools live.
- Daemon's error registry from `04 §4.6.5` accessible.
- JSON Schema validator (`ajv`) installed.

## 6.4 Outputs

After this file:

1. **Tool registry** in the router is mature: declarative, type-safe, with full lifecycle (`onCall`,
   `onError`, `onCancel`).
2. **Shared method registry** exists as a single JSON artifact in `packages/` so that both router
   and daemon agree on names, schemas, error codes.
3. **Shared error registry** — a JSON mirror of `04 §4.6.5` consumed by router code generation.
4. **Schema validation** is bidirectional: router validates input before dispatch; daemon
   re-validates on receipt (for defense in depth).
5. **Response normalization** is uniform: every tool result conforms to a documented response
   envelope (success / partial / error).
6. **Tool categories** are taxonomized; the router exposes them so Cursor can filter.
7. **Cancellation & timeouts** are first-class: long-running tools cooperate with MCP cancellation.
8. **Notifications** flow back to MCP clients: the router subscribes to daemon notifications
   (`event.*`) and emits MCP notifications.
9. **Telemetry hooks** exist for `09` to attach to (per-tool latency, success rate, payload size).
10. A small set of **utility tools** is shipped now to exercise the factory: `tools.list`,
    `tools.describe`, `tools.health`. These three live in the **router** (no daemon round-trip).

This file does **not** implement scene, node, script, runtime, or asset tools — that's `08`.

## 6.5 Operating constants used

- Max payload sizes from `00 §0.3` (`4 MiB` soft, `16 MiB` hard).
- Error code range `-33000`/`-33999` from `00 §0.3`.
- Default per-request timeout `30s` from `05`.

No new constants introduced.

---

## 6.6 Detailed task breakdown

### 6.6.1 Shared method registry — the source of truth

Create a single registry file (e.g., `packages/shared/methods/registry.json`) that both router and
daemon read:

| Field             | Type        | Purpose                                                                                           |
| ----------------- | ----------- | ------------------------------------------------------------------------------------------------- |
| `method`          | string      | Dotted name (e.g., `scene.get_tree`).                                                             |
| `category`        | string      | One of the categories from `00 §0.8`.                                                             |
| `since`           | string      | Version when introduced (semver).                                                                 |
| `deprecated`      | bool?       | True if scheduled for removal.                                                                    |
| `replacedBy`      | string?     | If deprecated.                                                                                    |
| `description`     | string      | Short, specific (Cursor routes on this).                                                          |
| `inputSchema`     | JSON Schema | Daemon op input.                                                                                  |
| `outputSchema`    | JSON Schema | Daemon op output.                                                                                 |
| `mcpTool`         | object?     | Optional override for the corresponding MCP tool surface (different name, different description). |
| `requiresEditor`  | bool        | True for ops that need `EditorInterface`.                                                         |
| `requiresRuntime` | bool        | True for ops that need the game to be playing.                                                    |
| `safe`            | bool        | "Safe" = agent may call without confirmation. Default false for mutators.                         |
| `mutates`         | bool        | True if the op changes project/editor state.                                                      |
| `errorCodes`      | array       | TerraVolt app codes this op may raise.                                                            |
| `examples`        | array       | One or two example payloads (for docs and agent learning).                                        |

This file lives in `packages/shared/` (a new shared package created by this file). Both router (TS)
and daemon (GDScript) read it at boot.

### 6.6.2 Shared error registry

Create `packages/shared/errors/registry.json` that mirrors `04 §4.6.5` verbatim. Fields:

| Field         | Type   | Purpose                          |
| ------------- | ------ | -------------------------------- |
| `code`        | int    | E.g., `-33500`.                  |
| `symbol`      | string | E.g., `scene.path_not_found`.    |
| `category`    | string | E.g., `scene`.                   |
| `severity`    | enum   | `info` / `warn` / `error`.       |
| `recoverable` | bool   | Whether the agent can self-heal. |
| `hint`        | string | Natural-language suggestion.     |
| `since`       | string | semver.                          |

Generate a TS module from this registry at build time so the router consumes typed enums.

### 6.6.3 Tool registry (router)

Each MCP tool is described by:

| Field             | Purpose                                                                                        |
| ----------------- | ---------------------------------------------------------------------------------------------- |
| `name`            | MCP tool name (often matches the daemon method, but may differ for ergonomics).                |
| `title`           | Human-friendly.                                                                                |
| `description`     | Specific; Cursor routes on it.                                                                 |
| `inputSchema`     | JSON Schema (may reuse the daemon's schema or be a narrower wrapper).                          |
| `outputSchema`    | Optional, recommended.                                                                         |
| `category`        | Same taxonomy as the method registry.                                                          |
| `safe`            | bool.                                                                                          |
| `mutates`         | bool.                                                                                          |
| `requiresEditor`  | bool.                                                                                          |
| `requiresRuntime` | bool.                                                                                          |
| `cancellable`     | bool.                                                                                          |
| `dispatch`        | reference: either a daemon method name or a function (for local-only tools like `tools.list`). |
| `pre`             | optional pre-flight hook (e.g., warmup, payload size check).                                   |
| `normalize`       | response normalizer (see §6.6.7).                                                              |
| `errorMap`        | optional override of error mapping for this tool.                                              |

The registry exposes `register(tool)`, `unregister(name)`, `get(name)`, `list({category?})`.
Registration may happen at startup from the shared method registry (auto-generation) and via
hand-coded tools for local-only operations.

### 6.6.4 Auto-generation vs hand-coding

- **Auto-generated tools**: 90% of the catalog. The router reads the shared method registry and
  produces MCP tools mechanically. Each generated tool dispatches to the daemon method with the same
  name.
- **Hand-coded tools**: for cases where the MCP surface differs from the daemon method (e.g.,
  combining two daemon ops into one tool, or local-only tools like `tools.list`).
- **Override mechanism**: a hand-coded tool replaces an auto-generated one if names collide.

### 6.6.5 Schema validation lifecycle

Per tool call:

1. **MCP SDK** parses the tool call frame.
2. **Router** looks up the tool by name.
3. **Router** runs `inputSchema` validation via `ajv`. Failure ⇒ MCP error with
   `app_code = protocol.invalid_params` and `data.errors`.
4. **Router** runs `pre` hook (if any). Failure ⇒ MCP error with `app_code` from the hook.
5. **Router** dispatches to daemon (`godot_ws_client`). Daemon **re-validates** input against its
   copy of the same schema.
6. **Daemon** runs the handler, returns either a result or a TerraVolt error envelope.
7. **Router** validates the daemon's result against `outputSchema` (in dev mode at least; in prod
   mode this is sampled).
8. **Router** runs `normalize` and emits the MCP tool result.

### 6.6.6 Successful response envelope

Every successful tool result follows:

```text
{
  "ok": true,
  "tool": "<name>",
  "method": "<daemon method>",
  "latencyMs": <int>,
  "result": { ... tool-specific shape ... },
  "warnings": [<diagnostic envelope>, ...],   // optional
  "context": {                                  // optional, see file 09
    "truncated": false,
    "envelopeKind": "raw" | "summary" | "diff",
    "hintToFetchRaw": "<method to call> with <params> to fetch full"
  }
}
```

**Mutating tools** add a `state` field on top of (or inside) `result` that contains the **new state
of the affected object**:

```text
{
  "ok": true,
  "tool": "node.modify",
  "result": {
    "state": { ... full updated node object ... },
    "diff":  { "before": {...}, "after": {...} }   // recommended for mutators
  }
}
```

This is the "successful calls return the new state" contract from `00 §0.2.2`.

### 6.6.7 Response normalization

`normalize` functions:

- **Strip noise**: drop daemon-only debug fields not useful to the agent.
- **Convert Godot types** to JSON-friendly equivalents (Vectors → `{x,y,z}`, Colors → `{r,g,b,a}`
  0–1, Transforms → matrix arrays + decomposed origin/rotation/scale, NodePaths → strings).
- **Stable ordering** of arrays for deterministic agent reasoning (e.g., children sorted by
  node-path order).
- **Attach `context` envelope** if the response was truncated.

The factory provides default normalizers per data type so individual tools rarely need custom code.

### 6.6.8 Error normalization

Errors from the daemon already arrive in the envelope from `04 §4.6.9`. The router:

- Maps daemon `app_code` to the same symbol on the router side.
- Adds `hint` (already present) and (in `09`) an `autoHealSuggestion` field with the next tool call
  the agent might try.
- Optionally enriches `context` with the failing input (after redaction).

Final error mapping logic lives in `09`. This file lands the _envelope shape_ and the pass-through
wiring.

### 6.6.9 Cancellation

- MCP's tool call supports cancellation via the SDK.
- The router routes cancel to the pending request entry; if the request is still in flight, it sends
  a JSON-RPC `dispatch.cancel` notification to the daemon with the request id. The daemon attempts
  to abort the handler if it's cancellable; otherwise it completes and the result is discarded.
- Reserve the daemon op `dispatch.cancel` (added to the daemon dispatcher; minimal: for handlers
  that support cooperative cancellation).
- Default `cancellable: false` on a tool unless the underlying op supports cooperative cancellation.
  Tools that do not support cancellation still propagate the cancel by best-effort dropping the
  response.

### 6.6.10 Notifications (server → MCP client)

The daemon emits notifications (`event.*`). The router:

1. Subscribes to all `event.*` methods.
2. Re-emits them as MCP notifications (the SDK supports this) to the client, preserving `method` and
   `params`.
3. Allows the router to _filter_ or _throttle_ notifications via `--notifications=<filter>` (default
   `all`, with per-method rate limits).

Useful event examples (defined in `08`):

- `event.runtime.tree_changed`.
- `event.editor.scene_saved`.
- `event.logging.rotated`.

### 6.6.11 Telemetry hooks

Per tool call, the router records:

- Tool name, daemon method.
- Started at, ended at.
- Latency (ms).
- Input payload size, output payload size.
- Result status (`ok` / `error`).
- Error code if any.
- Whether response was truncated (set by `09`).

Stored in a small **rolling counter** structure exposed via a local-only MCP tool `tools.metrics`
(no daemon round-trip). Used by `09`'s context optimization and `10`'s QA.

### 6.6.12 Local-only tools shipped now

Three tools that exercise the registry without daemon round-trip:

| Tool             | Behavior                                                           |
| ---------------- | ------------------------------------------------------------------ |
| `tools.list`     | Lists every registered tool. Optional `category`, `safe` filters.  |
| `tools.describe` | Returns the full descriptor (schemas + metadata) for a named tool. |
| `tools.metrics`  | Returns the rolling counters from §6.6.11.                         |

Plus a daemon-touching tool for safety:

| Tool           | Behavior                                                                                                                                           |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tools.health` | Composite check: daemon connectivity (`ping`), shared registry hashes (router vs daemon), schema validator self-test. Returns a pass/fail summary. |

### 6.6.13 Versioning the catalog

- The shared registry has a top-level `catalog_version` (semver).
- The router reports it via `server_info` (extension) so the agent knows which catalog is live.
- Daemon validates that its compiled registry hash matches the router-supplied hash on first call.
  Mismatch ⇒ a `protocol.catalog_mismatch` (new code `-33104`; add to the registry).

### 6.6.14 Categories and surface organization

Define and lock the **18 categories** that will host the 200+ tools (consistent with `00 §0.8`):

`server`, `log`, `event`, `tools`, `scene`, `node`, `script`, `signal`, `resource`, `asset`,
`runtime`, `editor`, `project`, `input`, `animation`, `physics`, `render`, `audio`, `network`,
`debug`, `profile`, `macro`.

(That's 22; intentional — some categories from `00 §0.8` are split for clarity. Lock this set here
and reflect it in the shared method registry.)

For each category, document: short purpose, who owns the daemon-side handlers, sample tool name,
expected response envelope notes.

### 6.6.15 Documentation generation

- The router can `--dump-catalog` to print the entire MCP tool catalog (JSON) and a markdown
  rendering for docs.
- A small script in `scripts/` regenerates `docs/catalog/` (a new directory) from the shared
  registry. This is the source of `10`'s catalog docs.

### 6.6.16 Test seams

For `10`'s QA:

- `register(tool)` exposes a "test mode" where dispatch can be redirected to a mock daemon.
- The validator can be swapped via a config flag for golden-file tests.

### 6.6.17 Manual smoke tests for this phase

1. Boot the router. Confirm `tools.list` returns at least: `ping`, `server.info`, `log.tail`,
   `tools.list`, `tools.describe`, `tools.health`, `tools.metrics`.
2. Call `tools.describe` for each; confirm schemas are non-empty.
3. Call `tools.health`. Expect a pass summary with matching catalog hash.
4. Mutate the daemon's shared registry copy (e.g., flip a description). Re-boot router. Confirm
   `tools.health` reports `protocol.catalog_mismatch`.
5. Call `tools.metrics`. Confirm latency entries exist after a few `ping`s.
6. Force a schema validation failure on `log.tail` (e.g., pass `lines: -1`). Expect
   `protocol.invalid_params` with `data.errors`.
7. Subscribe to notifications via MCP; toggle the daemon's logging level. Expect a notification
   (when wired in `08`, but the subscription path should already be functional).

---

## 6.7 Schemes / data shapes (no code)

### 6.7.1 Tool descriptor shape

See §6.6.3. Stable; downstream files only add to this shape, never remove.

### 6.7.2 Response envelope (success / mutating / error)

- **Success**: §6.6.6.
- **Mutating**: same with `result.state` and optional `result.diff`.
- **Error**: standard MCP tool error with `data` envelope from `04 §4.6.9`.

### 6.7.3 Catalog file layout (target)

```text
packages/shared/
  methods/
    registry.json          (machine-readable catalog)
    registry.md            (human-readable catalog, generated)
  errors/
    registry.json          (error code mirror)
    registry.md            (generated)
  schemas/
    common/                (reusable schemas: NodePath, Vector2, etc.)
    methods/
      <method>.json        (per-method input/output schemas, referenced from registry.json)
```

### 6.7.4 Reusable common schemas

Define once, referenced everywhere:

- `NodePath` (string with pattern).
- `ScenePath` (string ending in `.tscn` or `.scn`).
- `ResourcePath` (string starting with `res://` or `user://`).
- `Vector2`, `Vector3`, `Vector4` (objects).
- `Color` (`{r,g,b,a}` 0..1).
- `Transform2D`, `Transform3D` (`{origin, basis}`).
- `Rect2`, `AABB`.
- `NodeRef` (oneOf: NodePath string OR `{ uid: string }`).
- `PropertyDict` (object with string keys, JSON-friendly values).
- `Variant` (anyOf: number/string/bool/array/object/null/known typed shapes).
- `Diagnostic` (the error envelope from `04 §4.6.9`).

### 6.7.5 Generation flow

```text
packages/shared/methods/registry.json
            │
            ├──► packages/mcp-server/src/_generated/tools.ts   (router-side TS types) — optional / later
            ├──► packages/godot-mcp-addon/_generated/catalog_meta.gd (SHA + version; today)
            └──► docs/catalog/                                  (markdown — planned in `10`)
```

**Today:** `npm run catalog:sync` (alias `catalog:gen`) runs `scripts/catalog-sync.mjs` and
refreshes `_generated/catalog_meta.gd` only. Full codegen + `docs/catalog/` remains for later tasks.

---

## 6.8 Tech stack delta vs `00 §0.10`

- Adds a `packages/shared/` package containing JSON registries and schemas only (no executable code
  there; consumed by both sides).
- Adds a build-time codegen step in the router. No new runtime dependencies.

---

## 6.9 Acceptance criteria

- [x] `packages/shared/` exists with method and error registries.
- [x] Router auto-generates MCP tools from the shared registry at boot.
- [x] Daemon loads the same shared registry on enable (via `catalog:sync` → `catalog_meta.gd` +
      dispatcher fields).
- [x] `tools.list`, `tools.describe`, `tools.health`, `tools.metrics` work.
- [x] Schema validation is enforced on both sides.
- [ ] Response normalization in place for the common Godot types (`§6.7.4`) — deferred toward `08` /
      shared `schemas/common/`.
- [x] Cancellation pathway documented and wired (best-effort).
- [ ] Notifications subscription wired with dummy `event.test.tick` (daemon path not yet emitted;
      router bridge is live).
- [x] `tools.health` detects catalog mismatch (`protocol_catalog_mismatch_detected` + SHA/version
      parity).
- [ ] Smoke tests in §6.6.17 pass (manual; partial automation via `test:server`).
- [x] Decisions Log updated.

---

## 6.10 Verification plan

1. Smoke tests §6.6.17.
2. Mock-daemon test: route through an in-process mock instead of WS; ensure registry & normalization
   behave identically.
3. Schema fuzz: run a small fuzz pass that randomizes parameters for `log.tail` and confirms only
   well-typed inputs succeed.
4. Doc-gen: run `npm run catalog:gen`; confirm `docs/catalog/` regenerates without diff drift on
   repeated runs.
5. Catalog version: bump `catalog_version`; verify clients see the bump via `server.info`.

---

## 6.11 Risks & mitigations

| Risk                                         | Mitigation                                                                              |
| -------------------------------------------- | --------------------------------------------------------------------------------------- |
| Codegen drift between router and daemon.     | Single source: `packages/shared/`. Mismatch detected at boot.                           |
| Schemas duplicate across tools.              | Common schemas in `packages/shared/schemas/common/`; methods reference via `$ref`.      |
| Auto-generation introduces fragile coupling. | Keep auto-generation simple; explicit overrides allowed per tool.                       |
| Cancellation half-implemented in handlers.   | Mark tools `cancellable: false` by default; flip per-tool when the handler supports it. |
| Notification flood from chatty events.       | Per-method rate limits + filter flag.                                                   |
| `tools.metrics` reveals too much.            | Keep counters anonymous (no user input echoed).                                         |

---

## 6.12 Handoff checklist to file `07`

- [x] Shared registry is the source of truth for names, schemas, error codes.
- [x] Tool registration mechanics ready to absorb the 200+ tool catalog.
- [ ] Notification path exercised with `event.*` from daemon (bridge ready; no tick yet).
- [x] Telemetry hooks ready for `09`.
- [ ] Router doc-gen produces `docs/catalog/` (planned with `10`).

When done, open **`07-headless-fallback.md`**.

---

## Appendix A — Official Godot Docs alignment (added revision 2)

> Sourced from `tutorials/scripting/resources.rst`, `tutorials/scripting/scene_tree.rst`,
> `tutorials/scripting/groups.rst`, `tutorials/best_practices/*`, and the `class_*` reference.
> Sharpens the shared registries and common schemas against Godot's actual data shapes.

### A.1 Common types — Godot ↔ JSON mapping (locked)

Per `class_Variant` and the Variant subtypes in the reference:

| Godot type                      | JSON shape (TerraVolt)                                                                                        | Notes                                                                                                                                  |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | --------- | ----------------------------------- | ---------------------- |
| `bool`                          | `true` / `false`                                                                                              | direct                                                                                                                                 |
| `int`                           | integer                                                                                                       | `int64` range; document if any tool returns values outside JS safe-integer range and use a `string` with `bigint:` prefix in that case |
| `float`                         | number                                                                                                        | reject `NaN`/`Infinity`                                                                                                                |
| `String` / `StringName`         | string                                                                                                        | always emitted as `string`; `StringName` collapses to `string`                                                                         |
| `NodePath`                      | string                                                                                                        | "/root/..." absolute, "../" relative, "%UniqueName" supported                                                                          |
| `Vector2`                       | `{x,y}`                                                                                                       |                                                                                                                                        |
| `Vector2i`                      | `{x,y}` with integer components                                                                               | flag `int:true` optional metadata                                                                                                      |
| `Vector3` / `Vector3i`          | `{x,y,z}`                                                                                                     |                                                                                                                                        |
| `Vector4` / `Vector4i`          | `{x,y,z,w}`                                                                                                   |                                                                                                                                        |
| `Color`                         | `{r,g,b,a}` in 0..1                                                                                           | hex form `{hex:"#RRGGBBAA"}` accepted as input                                                                                         |
| `Transform2D`                   | `{origin:{x,y}, x:{x,y}, y:{x,y}}` plus decomposed `{position, rotation, scale}`                              | redundant for agent ergonomics                                                                                                         |
| `Transform3D`                   | `{origin:{x,y,z}, basis:[[..],[..],[..]]}` plus decomposed `{position, rotation_euler, rotation_quat, scale}` |                                                                                                                                        |
| `Basis`                         | `[[..],[..],[..]]`                                                                                            | rows are basis vectors                                                                                                                 |
| `Quaternion`                    | `{x,y,z,w}`                                                                                                   |                                                                                                                                        |
| `Rect2` / `Rect2i`              | `{position:{x,y}, size:{x,y}}`                                                                                |                                                                                                                                        |
| `AABB`                          | `{position:{x,y,z}, size:{x,y,z}}`                                                                            |                                                                                                                                        |
| `Plane`                         | `{normal:{x,y,z}, d:number}`                                                                                  |                                                                                                                                        |
| `Array` / typed array           | JSON array                                                                                                    | typed arrays carry `_element_type` metadata when round-tripped                                                                         |
| `Dictionary` / typed dictionary | JSON object                                                                                                   | object keys are strings even if Godot key was non-string; non-string keys serialize as `{"_keys":[...], "_values":[...]}` envelope     |
| `PackedByteArray` etc.          | base64 string with `{ "\_packed": "byte"                                                                      | "int32"                                                                                                                                | "float32" | ..., "data": "<base64>" }` envelope | avoids JSON ballooning |
| `Object` (Resource, Node)       | `{ "_object_class": "ResourceClass", "_uid": "<uid>", "_path": "res://...", ... }` envelope                   | full vs ref form gated by envelope mode (`09`)                                                                                         |
| `Callable`                      | `{ "_callable": true, "object_path": "<NodePath>", "method": "<name>" }`                                      | informational only; cannot be invoked from JSON                                                                                        |
| `Signal`                        | `{ "_signal": true, "object_path": "<NodePath>", "signal": "<name>" }`                                        | informational                                                                                                                          |
| `RID`                           | string (opaque)                                                                                               | rarely exposed; reserved                                                                                                               |

This table lives in `packages/shared/schemas/common/` as one document per type.

### A.2 Resource semantics

Per `tutorials/scripting/resources.rst`:

- **Anything serializable is a `Resource`.** Scenes (`PackedScene`), textures, materials, themes,
  fonts, animations, audio streams, scripts.
- **External vs built-in.** A resource with a non-empty `resource_path` is external; an empty
  `resource_path` means built-in to the parent scene/resource.
- **Dedup.** Godot loads the same resource path once and shares. Tools that return resources should
  return a reference envelope (`A.1` `Object` row) unless `envelope: raw` is requested.
- **Sub-resources** are recursive — emit a single object with refs; the agent can drill via
  `resource.load`.
- **Inline classes** can't be saved (per the `resources.rst` warning). The `resource.create` tool
  refuses requests whose `script` field points at an inner class; raise `resource.unsupported_type`
  (`-33701`).
- Use `ResourceLoader.load(path, type_hint, cache_mode)` and
  `ResourceSaver.save(resource, path, flags)` (or `Resource.take_over_path()` for advanced cases).
- `class_name` declarations are how custom resources show up in the editor's "New Resource" dialog.
  The `resource.create` tool's `type` field accepts those `class_name` strings.

### A.3 Group semantics

Per `tutorials/scripting/groups.rst`:

- A node may belong to many groups. Groups are strings.
- `SceneTree.get_nodes_in_group(name)` and `SceneTree.call_group(name, method, ...)` are the
  bulk-ops handles.
- Group membership is part of `node.modify`'s polymorphic surface (`groups.add` / `groups.remove`).
- The `event.scene.tree_changed` notification fires when any node changes group membership.

### A.4 Property hints — what `node.get_properties_schema` returns

Per `class_Object.get_property_list()` and the `PROPERTY_HINT_*` enum:

- Each property entry contains `name`, `type` (Variant type index), `hint` (`PROPERTY_HINT_*`),
  `hint_string`, `usage` (`PROPERTY_USAGE_*`).
- TerraVolt's tool returns this list **plus** a normalized JSON-schema-flavored summary:
  - `enum` properties (`PROPERTY_HINT_ENUM`) → `{ enum: [...] }`.
  - `range` (`PROPERTY_HINT_RANGE`) with `"min,max[,step]"` → `{ minimum, maximum, multipleOf }`.
  - `file`/`dir` paths → `{ format: "res-path" | "fs-path" }`.
  - `node_type` → `{ nodeType: "ClassName" }`.
- This lets the agent generate valid `node.modify` payloads from the schema.

### A.5 Best-practices source rules adopted in the catalog

Per `tutorials/best_practices/*`:

- **Scenes vs scripts** (`scenes_versus_scripts.rst`): TerraVolt's `macro.*` recipes default to
  **scene-based** assets (PackedScene) for reusability; scripts attach behavior. Tools must not
  force users to create scripts where scenes would do.
- **Scene organization** (`scene_organization.rst`): macros generate hierarchies that follow "small,
  composable scenes" — no monolithic god-scenes.
- **Autoloads vs nodes** (`autoloads_versus_regular_nodes.rst`): TerraVolt's autoload tools warn the
  agent when autoload count exceeds a project's earlier baseline (heuristic: > 8 autoloads),
  referencing the doc.
- **Logic preferences** (`logic_preferences.rst`): when generating boilerplate via macros, prefer
  signals over polling and `await` over deeply nested callbacks.
- **Project organization** (`project_organization.rst`): macros respect a default layout (`scenes/`,
  `scripts/`, `assets/`) but never mutate a project's existing layout without `dryRun`.

### A.6 `class_*` reference embedding

For each tool, the registry entry should embed a stable `engineRef` field pointing at the relevant
class/method anchor (e.g., `class_packedscene_method_instantiate`). The doc generator
(`scripts/catalog-gen`) renders these as links into the online Godot manual so the agent can
deep-link engine truth from any tool description.

### A.7 Schema reuse — `$ref` graph

- All common shapes live under `packages/shared/schemas/common/` (per `06 §6.7.4`).
- Per-method schemas use `$ref` to reference them; never inline a Vector or Color shape.
- Validator (`ajv`) on the router side: enable `strict: true`, `allErrors: true`, and
  `useDefaults: true` (so optional fields with defaults populate automatically).
- Daemon-side validator (light subset) honors at least `$ref`, `type`, `required`, `properties`,
  `enum`, `oneOf`, `anyOf`, `minimum`/`maximum`, `pattern`, `minLength`/`maxLength`,
  `additionalProperties`.

### A.8 New common schemas to ship

- `Variant` — discriminated by `_variant_type` (matches Godot's `Variant.Type` enum). Used in
  `node.modify` for property values where the type is dynamic.
- `Color.hex` and `Color.rgba` accepted interchangeably; normalize to `Color.rgba` on input.
- `EulerYXZ` vs `EulerXYZ` rotation orders — accept both, normalize to `YXZ` (Godot 4 default for
  `Node3D.rotation`).
- `NodePathExpression` — supports `%UniqueName`, `..`, `@/anonymous-name`. Documented per
  `class_NodePath`.

### A.9 Risks added

| Risk                                                                  | Mitigation                                                                                                         |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Mismatch between Godot's `Variant` types and JSON ⇒ subtle data loss. | A.1 mapping locked; round-trip tests for every type.                                                               |
| Resource inner-class limitation forgotten.                            | `resource.create` schema rejects inner-class scripts at validation time.                                           |
| Property hint string formats vary (`"min,max,step"` vs `"min,max"`).  | Normalize in the daemon's schema generator; document.                                                              |
| Typed arrays/dictionaries lose element-type info across JSON.         | Carry `_element_type` envelope.                                                                                    |
| Reserved namespace clashes with engine future methods.                | TerraVolt always uses two-segment dotted names (`category.action`); engine uses single-camelCase or single tokens. |
