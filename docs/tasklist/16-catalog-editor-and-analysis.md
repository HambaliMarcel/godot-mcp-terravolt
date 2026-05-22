# 16 — Catalog: `editor.*` + `analysis.*` (Phase 3 work-unit #6)

> The `editor.*` category exposes editor-state operations (screenshots, focus, docks, undo, error
> log, run a one-off script). The `analysis.*` category gives the agent structural insight into the
> project: complexity metrics, signal flow audits, unused-resource sweeps, and "needs love" lists.

---

## 16.1 Header

- **File:** `16-catalog-editor-and-analysis.md`
- **Purpose:** ship `editor.*` (9 tools) + `analysis.*` (4 tools) — 13 total.
- **Catalog bump:** `0.7.0` → **`0.8.0`** on land.

## 16.2 Phase placement

Phase 3, work-unit #6. Prerequisite: `15` shipped.

## 16.3 Inputs / prerequisites

- New handlers: `handlers/editor.gd`, `handlers/analysis.gd`.
- Router modules: `src/tools/editor/`, `src/tools/analysis/`.
- `editor.*` tools require an editor session — they refuse cleanly with `editor.not_available` in
  headless mode.
- Persistent error-log buffer (in-editor) attached via `EditorPlugin._notification` /
  `EditorInterface` script-editor hooks.

## 16.4 Outputs

- 13 tools live, registered, validated, documented.
- New event channel `event.editor.error_logged` to stream Godot editor errors / warnings live
  (subject to throttling).
- `docs/catalog/editor.md`, `docs/catalog/analysis.md` regenerated.

## 16.5 Operating constants used

- `editor_error_buffer_capacity = 2000` lines (rolling).
- `screenshot_max_kb = 2048`.
- `analysis_default_thresholds` registered at `packages/shared/analysis/thresholds.json`
  (cyclomatic, fan-out, file size).

---

## 16.6 `editor.*` — 9 tools

### `editor.screenshot`

- **Purpose:** capture a PNG of the editor (full window or named viewport).
- **Inputs:**
  `{ target?: "main"|"viewport_2d"|"viewport_3d"|"script_editor" (default "main"), size?: { w, h }, quality?: int (1-100, default 95) }`.
- **Outputs:** `{ image_base64, mime: "image/png", width, height, bytes }`.
- **Godot APIs:** `EditorInterface.get_base_control().get_viewport().get_texture().get_image()` for
  the editor; or grab a `SubViewport` for the requested target; `Image.save_png_to_buffer()` for PNG
  bytes.
- **Editor:** ✅. **Headless:** ❌.
- **safe:** true. **mutates:** false.
- **Errors:** `editor.screenshot_too_large` (`-33B00`).
- **Cursor prompt:** _"Screenshot the editor main window."_

### `editor.focus_node`

- **Purpose:** select and frame a node in the scene tree dock + viewport.
- **Inputs:** `{ path: NodePath, frame_in_viewport?: bool (default true) }`.
- **Outputs:** `{ focused: true, path }`.
- **Godot APIs:** `EditorInterface.get_selection().clear()`, `add_node(node)`;
  `EditorInterface.edit_node(node)`; for viewport framing,
  `EditorInterface.get_editor_viewport_3d().get_camera_3d()`–driven framing (best-effort across
  Godot minors).
- **Editor:** ✅. **Headless:** ❌.
- **safe:** true. **mutates:** false (UI state).
- **Cursor prompt:** _"Focus /root/Main/Player in the editor."_

### `editor.open_script`

- **Purpose:** open a script in the script editor at an optional line.
- **Inputs:** `{ path: ResourcePath, line?: int, column?: int }`.
- **Outputs:** `{ opened: true, path, line }`.
- **Godot APIs:** `EditorInterface.edit_resource(load(path))`; `ScriptEditor.goto_line(line)`.
- **Editor:** ✅. **Headless:** ❌.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Open Player.gd at line 42."_

### `editor.run_undo`

- **Purpose:** trigger Ctrl-Z in the editor.
- **Inputs:** `{ steps?: int (default 1) }`.
- **Outputs:** `{ undone: int, history_label?: string }`.
- **Godot APIs:** `EditorPlugin.get_undo_redo().undo()` (loop).
- **Editor:** ✅. **Headless:** ❌.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Undo my last 3 edits."_

### `editor.run_redo`

- **Purpose:** trigger Ctrl-Y in the editor.
- **Inputs:** `{ steps?: int (default 1) }`.
- **Outputs:** `{ redone: int, history_label?: string }`.
- **Godot APIs:** `EditorPlugin.get_undo_redo().redo()`.
- **Editor:** ✅. **Headless:** ❌.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Redo."_

### `editor.execute_script`

- **Purpose:** run a one-off `@tool` script inside the editor context — power-user, schema-gated.
- **Inputs:**
  `{ source: string, args?: PropertyDict, timeout_ms?: int (default 5000), allow_filesystem?: bool (default false), allow_net?: bool (default false) }`.
- **Outputs:** `{ ok: bool, return_value?, prints: [string], errors: [{ line, col, message }] }`.
- **Godot APIs:** create a transient `GDScript`, set `source_code`, `reload()`, instantiate, call a
  `main(args)` callback if present; capture `print` via redirected output buffer.
- **Editor:** ✅. **Headless:** ❌.
- **safe:** false. **mutates:** depends on script.
- **Errors:** `editor.script_timeout` (`-33B01`), `editor.script_forbidden_api` (`-33B02`) when
  source touches denied APIs (OS, File, etc.) and the corresponding `allow_*` flag is false.
- **Cursor prompt:** _"Run this @tool script inside the editor: <source>."_

### `editor.error_log_tail`

- **Purpose:** return recent editor errors / warnings.
- **Inputs:**
  `{ lines?: int (default 100), level?: "info"|"warn"|"error"|"all" (default "warn"), since_ts?: iso }`.
- **Outputs:**
  `{ entries: [{ ts, level, source: "engine"|"script", file?, line?, message }], next_cursor?: string }`.
- **Godot APIs:** capture via plugin-registered logger callback (`Engine.print_error_messages`
  hook); buffer in `services/editor_error_buffer.gd`.
- **Editor:** ✅. **Headless:** ⚠ (returns daemon log only).
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Tail the last 100 warn+ editor messages."_

### `editor.reload_scripts`

- **Purpose:** trigger a script editor "Reload Scripts" so live changes take effect.
- **Inputs:** `{ scope?: "all"|"changed" (default "changed") }`.
- **Outputs:** `{ reloaded: [ResourcePath], total }`.
- **Godot APIs:** `EditorInterface.reload_scene_from_path()` for the current scene; for scripts,
  `ScriptServer.reload_scripts()` (call deferred).
- **Editor:** ✅. **Headless:** ❌.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Reload my scripts."_

### `editor.layout`

- **Purpose:** save / restore editor docks layout (`Editor → Editor Layout`).
- **Inputs:** `{ action: "save"|"load"|"list"|"delete", name?: string }`.
- **Outputs:** depends on action: `{ layouts: [string] }` or `{ saved/loaded/deleted: true }`.
- **Godot APIs:** `EditorPlugin.get_editor_interface().save_layout` (where available); fall back to
  writing into `EditorSettings` keys for the layout file path.
- **Editor:** ✅. **Headless:** ❌.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Save the current dock layout as `terravolt-dev`."_

---

## 16.7 `analysis.*` — 4 tools

### `analysis.scene_complexity`

- **Purpose:** measure scene complexity (node count, depth, references, fan-out).
- **Inputs:**
  `{ scope?: "active"|ScenePath|"project" (default "active"), thresholds?: PropertyDict }`.
- **Outputs:**
  `{ overall: { node_count, max_depth, total_signal_connections, external_resource_refs }, per_scene?: [{ path, ... }], offenders: [{ path, metric, value, threshold }] }`.
- **Godot APIs:** scene traversal; cross-reference with `resource.get_dependencies`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Which scenes have a node count over 500?"_

### `analysis.signal_flow`

- **Purpose:** build a project-wide signal graph and flag suspicious patterns (orphan listeners,
  dead emitters, cycles).
- **Inputs:** `{ scope?: "active"|"project" (default "project") }`.
- **Outputs:**
  `{ graph_summary: { nodes, edges }, orphans: [{ path, signal, reason }], dead_listeners: [{ path, method, reason }], cycles: [[NodePath]] }`.
- **Godot APIs:** uses `signal.graph` + script symbol index from `13`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Find dead signal listeners across the project."_

### `analysis.unused_resources`

- **Purpose:** project-wide unused resources (scripts, scenes, assets, materials).
- **Inputs:** `{ kinds?: ["script"|"scene"|"asset"|"resource"] (default all), exclude?: [glob] }`.
- **Outputs:** `{ unused: [{ path, kind, size_bytes }], total_count, total_bytes_estimate }`.
- **Godot APIs:** combines `resource.get_dependents` and `asset.find_unused` plus dynamic-load
  detection.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Find unused everything in the project."_

### `analysis.metrics`

- **Purpose:** rolled-up code & content metrics for the project (LOC by language, scenes count,
  average scene size, script complexity histogram).
- **Inputs:** `{ kinds?: ["loc"|"scenes"|"scripts"|"complexity"|"resources"] (default all) }`.
- **Outputs:**
  `{ loc: { gd, cs, gdshader, total }, scenes: { count, avg_node_count, p95_node_count }, scripts: { count, avg_loc, p95_loc }, complexity: { histogram }, resources: { count, by_class } }`.
- **Godot APIs:** filesystem walk + AST cyclomatic counter (simple node walk).
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Give me the project metrics summary."_

---

## 16.8 Schemes / data shapes added

- `ErrorLogEntry` shape: `{ ts, level, source, file?, line?, message, stack?: [string] }`.
- `SignalGraphDiagnostic` (built on `13`'s `SignalGraph`): adds `orphans`, `dead_listeners`,
  `cycles`.
- `ComplexityReport` shape: per `analysis.scene_complexity` outputs.
- `MetricsSummary` shape: per `analysis.metrics` outputs.

## 16.9 Tech stack delta

- No new third-party deps.
- Daemon adds `services/editor_error_buffer.gd` and `services/metrics_collector.gd`.

## 16.10 Acceptance criteria

- [ ] All 13 tools live; visible via `tools.list`.
- [ ] `editor.execute_script` denies forbidden APIs by default and surfaces a precise list of denied
      identifiers when refused.
- [ ] `editor.error_log_tail` captures both engine-side errors and script errors from a malformed
      `.gd` save.
- [ ] `analysis.unused_resources` accounts for runtime `load()`/`preload()` references (no false
      positives on dynamically-loaded resources).
- [ ] `analysis.metrics` is deterministic across runs of an unchanged project.

## 16.11 Verification plan

1. **Screenshot:** capture the editor; assert non-zero PNG bytes and dimensions ≥ 256×256.
2. **Focus:** `editor.focus_node` on a sample subtree → `editor.screenshot` confirms the node is
   selected (visual diff against a golden).
3. **Undo/Redo:** run a `node.modify` op, then `editor.run_undo` reverts; `editor.run_redo`
   re-applies.
4. **Error log:** save a malformed `.gd` → `editor.error_log_tail` shows the parser diagnostic
   within 1s.
5. **Signal flow:** seed an orphan signal in a fixture; `analysis.signal_flow` reports it under
   `orphans`.
6. **Metrics determinism:** run `analysis.metrics` twice — outputs are byte-identical.

## 16.12 Risks & mitigations

| Risk                                                                         | Mitigation                                                                                                                                                                                |
| ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `editor.execute_script` is a sharp tool — code can mutate anything.          | Static deny-list of identifiers (`OS`, `DirAccess`, `FileAccess`, `HTTPClient`, `Engine.execute`) unless flags allow; hard timeout; result includes the actual source executed for audit. |
| Editor error log capture is version-fragile (no public hook in some minors). | Provide a polling fallback that tails `user://logs/godot.log` if direct hook fails.                                                                                                       |
| Layout save uses internal APIs that may change.                              | Wrap in feature detection; degrade gracefully with `editor.unsupported_in_version`.                                                                                                       |
| `analysis.*` over very large projects (>5k scripts) is slow.                 | Build an incremental index; rebuild on `EditorFileSystem.filesystem_changed`; cache results keyed by index version.                                                                       |
| Screenshot data inflates router context.                                     | Always return base64 + bytes; offer `pointer_ref` envelope path if > `screenshot_max_kb`.                                                                                                 |

## 16.13 Handoff checklist to file `17`

- [ ] Catalog version `0.8.0` pushed.
- [ ] 102 tools total live.
- [ ] Editor error live-stream event tested with > 100 messages/sec burst (throttled to ≤ 20/sec
      out).
- [ ] Open `17-catalog-runtime.md`.

## 16.14 Commit template

```text
feat(catalog): ship editor.* (9) and analysis.* (4) — Phase 3 work-unit #6

- Sandboxed editor.execute_script with deny-list
- Editor error log live stream + tail
- Scene complexity / signal flow / unused-resources reports
- Editor screenshots with size caps
- Bumps catalog_version 0.7.0 -> 0.8.0

Refs: docs/tasklist/16-catalog-editor-and-analysis.md
```
