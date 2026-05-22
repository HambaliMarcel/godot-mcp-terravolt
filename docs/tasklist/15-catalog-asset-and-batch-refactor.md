# 15 — Catalog: `asset.*` + `batch_refactor.*` (Phase 3 work-unit #5)

> `asset.*` handles raw source files coming into the project: textures (PNG/JPG/EXR), audio
> (OGG/WAV/MP3), 3D models (GLTF/GLB/FBX/OBJ), and fonts (TTF/OTF). The Godot import pipeline turns
> these into `*.import` metadata + `.godot/imported/*` cached resources. `batch_refactor.*` provides
> cross-category, multi-file mutations: rename + reference rewrite, move folders, find-and-replace
> across scripts/scenes/resources.

---

## 15.1 Header

- **File:** `15-catalog-asset-and-batch-refactor.md`
- **Purpose:** ship `asset.*` (12 tools) + `batch_refactor.*` (8 tools) — 20 total.
- **Catalog bump:** `0.6.0` → **`0.7.0`** on land.

## 15.2 Phase placement

Phase 3, work-unit #5. Prerequisite: `14` shipped.

## 15.3 Inputs / prerequisites

- New handlers: `handlers/asset.gd`, `handlers/batch_refactor.gd`.
- Router modules: `src/tools/asset/`, `src/tools/batch_refactor/`.
- Headless reimport hook: `godot --headless --import` (per `07`).
- Allow-list of asset extensions per kind, maintained at `packages/shared/asset/extensions.json`.

## 15.4 Outputs

- 20 tools live, registered, validated, documented.
- New fixture: `tests/_fixtures/asset_zoo/` with one of every supported asset kind.
- `docs/catalog/asset.md` and `docs/catalog/batch_refactor.md` regenerated.

## 15.5 Operating constants used

- `asset_max_inline_bytes = 256` (KB) — anything above is referenced by pointer.
- `batch_refactor_max_files_per_call = 500` — sane default ceiling for mutation operations.
- `import_timeout_ms = 60000` per asset.

---

## 15.6 `asset.*` — 12 tools

### `asset.list`

- **Purpose:** list source asset files under `res://`.
- **Inputs:**
  `{ kind?: "texture"|"audio"|"model"|"font"|"any" (default "any"), pattern?: glob, include_imports?: bool (default true) }`.
- **Outputs:**
  `{ assets: [{ path, kind, size_bytes, modified_at, has_import_metadata: bool, import_target_class?: string }], total }`.
- **Godot APIs:** filesystem walk + extension allow-list; `.import` sidecar presence check.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"List all texture assets."_

### `asset.import_status`

- **Purpose:** report import status of an asset (or all).
- **Inputs:** `{ path?: ResourcePath, scope?: "all"|"folder", folder?: ResourcePath }`.
- **Outputs:**
  `{ items: [{ path, imported: bool, importer: string, type: string, last_modified, last_imported, dirty: bool }] }`.
- **Godot APIs:** read `<path>.import` files; compare mtimes;
  `EditorFileSystem.get_file_type(path)`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Which assets need reimport?"_

### `asset.reimport`

- **Purpose:** trigger reimport for an asset (or folder / project).
- **Inputs:**
  `{ path?: ResourcePath, scope?: "file"|"folder"|"project" (default "file"), folder?: ResourcePath }`.
- **Outputs:** `{ reimported: [ResourcePath], duration_ms, errors: [{ path, message }] }`.
- **Godot APIs:** `EditorFileSystem.reimport_files([path])`; headless path uses
  `godot --headless --import`.
- **safe:** false. **mutates:** true (regenerates `.godot/imported/*`).
- **Errors:** `asset.import_timeout` (`-33900`).
- **Cursor prompt:** _"Reimport every asset under res://art/textures/."_

### `asset.get_import_settings`

- **Purpose:** read import settings for an asset.
- **Inputs:** `{ path: ResourcePath }`.
- **Outputs:** `{ path, importer, type, settings: PropertyDict, default_settings: PropertyDict }`.
- **Godot APIs:** parse the `.import` INI file; for live runtime,
  `ResourceImporter.get_import_settings`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Show me import settings of hero_diffuse.png."_

### `asset.set_import_settings`

- **Purpose:** patch import settings (and trigger reimport).
- **Inputs:** `{ path: ResourcePath, patch: PropertyDict, reimport_after?: bool (default true) }`.
- **Outputs:** `{ updated: true, applied: { key: { before, after } }, reimported: bool, revision }`.
- **Godot APIs:** modify the `.import` file; call `EditorFileSystem.reimport_files`.
- **safe:** false. **mutates:** true.
- **Errors:** `asset.unknown_setting` (`-33901`).
- **Cursor prompt:** _"On hero_diffuse.png set compress/mode=2 and reimport."_

### `asset.add`

- **Purpose:** add a new asset file (from raw bytes or a base64 payload).
- **Inputs:**
  `{ path: ResourcePath, content_base64?: string, source_url?: string (file://), overwrite?: bool (default false) }`.
- **Outputs:** `{ added: true, path, size_bytes, kind, import_triggered: bool }`.
- **Godot APIs:** `FileAccess.open(path, WRITE)` writes the bytes; `EditorFileSystem.scan()`
  triggers import.
- **safe:** false. **mutates:** true.
- **Errors:** `asset.too_large` (`-33902`) if `> asset_max_inline_bytes` for base64;
  `asset.path_exists` (`-33903`).
- **Cursor prompt:** _"Add this PNG as res://art/icon.png."_

### `asset.delete`

- **Purpose:** delete an asset (and its import sidecar).
- **Inputs:** `{ path: ResourcePath, force?: bool (default false) }`.
- **Outputs:** `{ deleted: true, path, freed_bytes, sidecar_removed: bool }`.
- **Godot APIs:** `EditorFileSystem.move_to_trash(path)` then sidecar; ensure `.godot/imported/*`
  cache cleanup runs.
- **safe:** false. **mutates:** true.
- **Errors:** `resource.dependency_block`.
- **Cursor prompt:** _"Delete res://art/old_icon.png."_

### `asset.rename`

- **Purpose:** rename / move an asset and its sidecar with reference rewrites.
- **Inputs:**
  `{ from: ResourcePath, to: ResourcePath, update_references?: bool (default true), dry_run?: bool }`.
- **Outputs:**
  `{ renamed: true, from, to, sidecar_moved: bool, references_updated: [...], dry_run }`.
- **Godot APIs:** `DirAccess.rename` for both file + sidecar; rewrite `[ext_resource]` headers.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Rename res://art/icon.png to res://art/icons/main.png."_

### `asset.preview`

- **Purpose:** generate a preview thumbnail for an asset (texture, model, audio waveform, font
  sample).
- **Inputs:** `{ path: ResourcePath, size?: { w: int, h: int } (default 256x256) }`.
- **Outputs:** `{ kind, content_base64: string, mime: "image/png" }`.
- **Godot APIs:** `EditorResourcePreview.queue_resource_preview()` /
  `queue_edited_resource_preview()`; for audio, generate a waveform via `AudioStreamSample`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Show me a 128x128 preview of res://art/icon.png."_

### `asset.metadata`

- **Purpose:** read intrinsic metadata (image dims, audio duration/sample rate, model mesh count,
  font family).
- **Inputs:** `{ path: ResourcePath }`.
- **Outputs:** `{ kind, metadata: PropertyDict }`.
- **Godot APIs:** for images, `Image.load(path)`; audio: load `AudioStream` and read
  `get_length()`/`mix_rate`; model: traverse imported scene.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"What are the dimensions of hero_diffuse.png?"_

### `asset.batch_import_presets`

- **Purpose:** apply an import-settings preset (predefined or named) to many assets at once.
- **Inputs:**
  `{ preset: string ("compressed_albedo"|"unfiltered_pixel_art"|custom), paths?: [ResourcePath], pattern?: glob, dry_run?: bool }`.
- **Outputs:** `{ applied_to: [ResourcePath], reimported: bool, dry_run }`.
- **Godot APIs:** patch each `.import` file then bulk reimport.
- **safe:** false. **mutates:** true.
- **Errors:** `asset.preset_unknown` (`-33904`).
- **Cursor prompt:** _"Apply pixel-art preset to every texture under res://art/pixel/."_

### `asset.find_unused`

- **Purpose:** find asset files with no inbound references.
- **Inputs:** `{ kind?: "texture"|"audio"|"model"|"font"|"any", exclude?: [glob] }`.
- **Outputs:** `{ unused: [{ path, size_bytes }], total, total_freed_estimate_bytes }`.
- **Godot APIs:** uses `resource.get_dependents` index from file `14`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Find all unused texture assets."_

---

## 15.7 `batch_refactor.*` — 8 tools

### `batch_refactor.preview`

- **Purpose:** preview a batch refactor without applying — always step 1.
- **Inputs:** `{ plan: BatchPlan }` where
  `BatchPlan = { ops: [BatchOp], scope?: "project"|"folder", folder?: ResourcePath }` and
  `BatchOp = oneOf<{...kind: 'rename', from, to, kind_target: 'file'|'folder'|'class_name'|'function'|'signal' }, {...kind: 'move_folder', from, to }, {...kind: 'replace_string', pattern: string|regex, replacement: string, files?: [glob] }, {...kind: 'normalize_names', target: 'snake_case'|'PascalCase', selector: glob }, {...kind: 'set_property', selector: NodeOrResourceSelector, key, value }, {...kind: 'change_class', selector, from_class, to_class, preserve_props?: bool }>`.
- **Outputs:**
  `{ ops: [{ op, edits: [{ in_file, line?, before, after }], conflicts?: [{ message }] }], total_edits, total_files }`.
- **Godot APIs:** runs the equivalent of each op in a sandbox journal but applies nothing.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Preview renaming the Enemy class to Mob across the project."_

### `batch_refactor.apply`

- **Purpose:** apply a previewed plan (or supply the plan inline).
- **Inputs:** `{ plan: BatchPlan, confirm_token?: string, if_match?: revision }` — `confirm_token`
  is the hash returned by `preview` to avoid accidental re-apply.
- **Outputs:** `{ applied: true, files_changed, ops_succeeded, ops_failed, edits: [...] }`.
- **Godot APIs:** transactional execution; wraps in an editor-side `UndoRedo` if available.
- **safe:** false. **mutates:** true.
- **Errors:** `batch.confirm_mismatch` (`-33A00`), `batch.partial_failure` (`-33A01`).
- **Cursor prompt:** _"Apply the previewed plan."_

### `batch_refactor.rename_class`

- **Purpose:** rename a GDScript `class_name` or `.cs` class project-wide (sugar over
  `batch_refactor.apply`).
- **Inputs:**
  `{ from: string, to: string, also_rename_file?: bool (default false), dry_run?: bool }`.
- **Outputs:** `{ files_changed, edits: [...], dry_run }`.
- **Cursor prompt:** _"Rename class_name Enemy to Mob everywhere."_

### `batch_refactor.move_folder`

- **Purpose:** move a folder (with all contents) and rewrite references.
- **Inputs:** `{ from: ResourcePath, to: ResourcePath, dry_run?: bool }`.
- **Outputs:** `{ moved: true, files_moved: int, references_updated: int, dry_run }`.
- **Godot APIs:** `DirAccess` move + reference rewrite via `resource.replace_references`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Move res://art/textures/ to res://content/textures/."_

### `batch_refactor.replace_in_files`

- **Purpose:** safe project-wide find-and-replace (token-aware for `.gd` / `.cs`, plain-text for
  others).
- **Inputs:**
  `{ pattern: string | { regex: string, flags?: string }, replacement: string, files?: [glob], dry_run?: bool, max_edits?: int }`.
- **Outputs:** `{ edits: [{ in_file, line, before, after }], applied: bool, dry_run }`.
- **safe:** false. **mutates:** true.
- **Errors:** `batch.too_many_edits` (`-33A02`) when over `max_edits`.
- **Cursor prompt:** _"Replace `print(` with `Logger.debug(` across all .gd files."_

### `batch_refactor.normalize_names`

- **Purpose:** rename files/nodes/properties to fit a casing convention.
- **Inputs:**
  `{ target: "snake_case"|"PascalCase"|"camelCase", selector: { paths?: [glob], node_in_scene?: bool }, dry_run?: bool }`.
- **Outputs:** `{ renames: [{ from, to }], applied: bool, dry_run }`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Normalize all GDScript file names to snake_case."_

### `batch_refactor.change_class`

- **Purpose:** swap node types or resource classes across scenes/resources where compatible (e.g.,
  `Sprite2D` → `AnimatedSprite2D`).
- **Inputs:**
  `{ selector: { class: string, paths?: [glob] }, target_class: string, preserve_props?: bool (default true), dry_run?: bool }`.
- **Outputs:**
  `{ converted: [{ path, location, before_class, after_class }], applied: bool, dry_run }`.
- **Godot APIs:** safe property transfer using `ClassDB.class_has_property`; warn on lossy fields.
- **safe:** false. **mutates:** true.
- **Errors:** `batch.incompatible_classes` (`-33A03`).
- **Cursor prompt:** _"Change every Sprite2D under res://entities/ to AnimatedSprite2D, preserving
  props."_

### `batch_refactor.history`

- **Purpose:** list recent batch_refactor.apply calls (with revert tokens).
- **Inputs:** `{ limit?: int (default 20) }`.
- **Outputs:** `{ history: [{ id, applied_at, ops_count, files_changed, revert_token, summary }] }`.
- **Godot APIs:** persisted at `user://terravolt/batch_history.json`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"What batch refactors have I run today?"_

> **Revert.** Each `batch_refactor.apply` returns a `revert_token`;
> `batch_refactor.apply { plan: { ops: [{ kind: 'revert', token }] } }` undoes the batch
> (best-effort) by replaying the inverse plan stored alongside.

---

## 15.8 Schemes / data shapes added

- `BatchPlan` JSON Schema at `packages/shared/schemas/batch/BatchPlan.json`.
- `BatchOpResult` shape: `{ op, status: "ok"|"skipped"|"failed", edits: [...], errors: [...] }`.
- `AssetMetadata` shape per kind: `texture: { width, height, format, mipmaps }`,
  `audio: { duration_s, sample_rate, channels }`,
  `model: { mesh_count, animation_count, has_skeleton }`, `font: { family, weight, style }`.

## 15.9 Tech stack delta

- No new third-party deps.
- Daemon adds `services/batch_journal.gd` (persistent journal for revert support).

## 15.10 Acceptance criteria

- [ ] All 20 tools live; visible via `tools.list` per category.
- [ ] Every `batch_refactor` mutator supports `dry_run=true` and yields the same edit set the
      `apply` step would produce.
- [ ] `batch_refactor.apply` produces a revert token usable to undo the batch.
- [ ] Asset rename moves the `.import` sidecar atomically (no orphans).
- [ ] `asset.find_unused` is deterministic across runs with the same project state.

## 15.11 Verification plan

1. **Preview then apply:** rename `class_name Enemy → Mob`; preview output equals the apply edit
   set.
2. **Revert:** apply then revert restores file SHAs.
3. **Reimport:** mutate a `.import` setting → asset cache rebuild visible under `.godot/imported/*`
   with new mtime.
4. **Unused detector:** add a stray texture not referenced anywhere → `asset.find_unused` lists it;
   reference it from a scene → removed from the list.
5. **Class change:** convert `Sprite2D` → `AnimatedSprite2D`, ensure shared properties (`position`,
   `scale`) are transferred and unique ones (`animation`) seeded with defaults.

## 15.12 Risks & mitigations

| Risk                                                                        | Mitigation                                                                                                                           |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Batch operations partially fail mid-way leaving half-rewritten files.       | Two-phase commit: write to `.tmp` siblings, fsync, then atomic rename; on any failure, roll back.                                    |
| Reverting a batch after additional manual edits clobbers user work.         | Revert journal includes file content SHAs; refuse revert if any file's current SHA differs from post-apply SHA without `force=true`. |
| Reimport storms for large projects.                                         | Coalesce reimport requests; debounce by `import_timeout_ms / 6`.                                                                     |
| Regex find-and-replace produces destructive matches in binary `.res` files. | Hard skip binary files; rely on extension allow-list.                                                                                |
| Unused-asset false positives (dynamic loads via `load(...)` at runtime).    | Detect any `.gd`/`.cs` use of `load("res://...")` / `preload("res://...")` and add those to the dependency graph.                    |

## 15.13 Handoff checklist to file `16`

- [ ] Catalog version `0.7.0` pushed.
- [ ] 89 tools total live.
- [ ] Revert journal verified to round-trip a 50-op plan.
- [ ] Open `16-catalog-editor-and-analysis.md`.

## 15.14 Commit template

```text
feat(catalog): ship asset.* (12) and batch_refactor.* (8) — Phase 3 work-unit #5

- Atomic .import sidecar moves
- Two-phase commit with revert journal for batch ops
- Dynamic-load aware unused-asset detection
- Preset-based bulk import settings
- Bumps catalog_version 0.6.0 -> 0.7.0

Refs: docs/tasklist/15-catalog-asset-and-batch-refactor.md
```
