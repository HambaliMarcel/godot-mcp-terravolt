# 14 — Catalog: `resource.*` + `shader.*` (Phase 3 work-unit #4)

> Resources are Godot's persistence layer: textures, materials, fonts, themes, curves, animations,
> and every `.tres`/`.res` file. The `resource.*` category gives the agent full read/write power
> over these. `shader.*` is the specialized resource family for `.gdshader` / `.tres` shader
> materials — split out because shader workflows have unique compile/parameter semantics.

---

## 14.1 Header

- **File:** `14-catalog-resource-and-shader.md`
- **Purpose:** ship `resource.*` (15 tools) + `shader.*` (6 tools) — 21 total.
- **Catalog bump:** `0.5.0` → **`0.6.0`** on land.

## 14.2 Phase placement

Phase 3, work-unit #4. Prerequisite: `13` shipped.

## 14.3 Inputs / prerequisites

- New handlers: `handlers/resource.gd`, `handlers/shader.gd`.
- Router modules: `src/tools/resource/`, `src/tools/shader/`.
- Mime-type sniffing utility (built-in Godot `ResourceLoader.get_resource_type(path)`).
- Reuse `06`'s Variant-↔-JSON mapping for resource property payloads.

## 14.4 Outputs

- 21 tools live, registered, validated, documented.
- `docs/catalog/resource.md` and `docs/catalog/shader.md` regenerated.
- New built-in fixture: `tests/_fixtures/resource_zoo/` containing one of every common `.tres`
  class.

## 14.5 Operating constants used

- `resource_max_inline_kb = 64` — over this size, the response returns a `pointer_ref` envelope
  rather than raw bytes.
- `shader_compile_timeout_ms = 10000`.

---

## 14.6 `resource.*` — 15 tools

### `resource.list`

- **Purpose:** list resource files by class / glob.
- **Inputs:**
  `{ class?: string (e.g., "Texture2D"), pattern?: glob (default "**/*.{tres,res,gd,gdshader}"), include_imported?: bool (default false) }`.
- **Outputs:** `{ resources: [{ path, class, uid?, size_bytes, modified_at }], total }`.
- **Godot APIs:** `EditorFileSystem.get_filesystem()` walk; `ResourceLoader.get_resource_type(path)`
  for class.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"List all StyleBoxFlat resources in the project."_

### `resource.get`

- **Purpose:** read a resource's properties + nested sub-resources (envelope-aware for large blobs).
- **Inputs:**
  `{ path: ResourcePath, include_subresources?: bool (default false), max_depth?: int (default 3) }`.
- **Outputs:**
  `{ path, class, uid?, resource_name?, properties: PropertyDict, subresources?: { local_id: { class, properties } } }`.
- **Godot APIs:** `ResourceLoader.load(path)`, `Object.get_property_list()`,
  `Resource.resource_path`/`resource_name`.
- **safe:** true. **mutates:** false.
- **Errors:** `resource.path_not_found` (`-33800`).
- **Cursor prompt:** _"Show me res://art/hero_material.tres."_

### `resource.create`

- **Purpose:** create a new resource of a given class and save it.
- **Inputs:**
  `{ path: ResourcePath, class: string, properties?: PropertyDict, take_over_path?: bool (default false) }`.
- **Outputs:** `{ created: true, path, class, uid, revision }`.
- **Godot APIs:** `ClassDB.instantiate(class)`, populate via `Object.set`;
  `ResourceSaver.save(res, path)`; if `take_over_path` then `res.take_over_path(path)` first.
- **safe:** false. **mutates:** true.
- **Errors:** `resource.class_unknown` (`-33801`), `resource.path_exists` (`-33802`).
- **Cursor prompt:** _"Create a new StandardMaterial3D at res://art/grass.tres with albedo
  (0.4,0.7,0.3,1)."_

### `resource.update`

- **Purpose:** update properties on an existing resource (and re-save).
- **Inputs:** `{ path: ResourcePath, patch: PropertyDict, if_match?: revision, dry_run?: bool }`.
- **Outputs:** `{ updated: true, path, applied: { key: { before, after } }, dry_run, revision }`.
- **Godot APIs:** `ResourceLoader.load(path)`, `Object.set` per key, `ResourceSaver.save`.
- **safe:** false. **mutates:** true.
- **Errors:** `resource.property_unknown` (`-33803`), `resource.value_type_mismatch` (`-33804`),
  `protocol.idempotency_conflict`.
- **Cursor prompt:** _"Set albedo_color to (0.6, 0.3, 0.1, 1) on res://art/grass.tres."_

### `resource.duplicate`

- **Purpose:** duplicate a resource (deep or shallow) and save under a new path.
- **Inputs:**
  `{ source_path: ResourcePath, target_path: ResourcePath, deep?: bool (default true), overwrite?: bool (default false) }`.
- **Outputs:** `{ duplicated: true, source_path, target_path, revision }`.
- **Godot APIs:** `Resource.duplicate(subresources: bool)`, then `ResourceSaver.save`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Duplicate res://art/grass.tres as res://art/grass_dry.tres."_

### `resource.delete`

- **Purpose:** delete a resource file (with dependency safety).
- **Inputs:** `{ path: ResourcePath, force?: bool (default false) }`.
- **Outputs:** `{ deleted: true, path, freed_bytes, dependents_warned: [ResourcePath] }`.
- **Godot APIs:** `EditorFileSystem.move_to_trash(path)` or `DirAccess.remove(path)`; cross-check
  with `resource.get_dependents`.
- **safe:** false. **mutates:** true.
- **Errors:** `resource.dependency_block` (`-33550`).
- **Cursor prompt:** _"Delete res://art/old_grass.tres."_

### `resource.rename`

- **Purpose:** rename / move a resource file with reference rewrites.
- **Inputs:**
  `{ from: ResourcePath, to: ResourcePath, update_references?: bool (default true), dry_run?: bool }`.
- **Outputs:**
  `{ renamed: true, from, to, references_updated: [{ in_file, before, after }], dry_run }`.
- **Godot APIs:** `EditorFileSystem.move_resource(...)` if available; otherwise
  `EditorFileSystem.update_file()` + manual file move; rewrite `ext_resource` headers in dependent
  files when `update_references=true`.
- **safe:** false. **mutates:** true.
- **Errors:** `resource.path_exists`.
- **Cursor prompt:** _"Rename res://art/grass.tres to res://art/foliage/grass_default.tres."_

### `resource.get_dependencies`

- **Purpose:** list outbound dependencies of a resource (what it needs).
- **Inputs:** `{ path: ResourcePath, deep?: bool (default false) }`.
- **Outputs:** `{ dependencies: [{ path, class, weak: bool }], cycles?: [[ResourcePath]] }`.
- **Godot APIs:** `ResourceLoader.get_dependencies(path)`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"What does res://entities/Player.tscn depend on?"_

### `resource.get_dependents`

- **Purpose:** reverse-lookup — find who depends on this resource.
- **Inputs:** `{ path: ResourcePath, scope?: "project"|"folder", folder?: ResourcePath }`.
- **Outputs:** `{ dependents: [{ path, class, ref_count: int }], total }`.
- **Godot APIs:** walk filesystem + `ResourceLoader.get_dependencies` for each file (cached);
  incremental rebuild on file change.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Who depends on res://art/hero_material.tres?"_

### `resource.replace_references`

- **Purpose:** rewrite every reference to `from_path` to point at `to_path` (project-wide).
- **Inputs:**
  `{ from_path: ResourcePath, to_path: ResourcePath, dry_run?: bool, exclude?: [glob] }`.
- **Outputs:** `{ rewrites: [{ in_file, line?, before, after }], applied: bool, files_changed }`.
- **Godot APIs:** scan `.tscn`/`.tres`/`.gd`/`.cs` for the source path string; replace via text
  edit; trigger `EditorFileSystem.scan()` after.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Replace all references to res://art/grass.tres with
  res://art/foliage/grass_v2.tres."_

### `resource.export_json`

- **Purpose:** export a resource as deterministic JSON (for diffing / patching).
- **Inputs:** `{ path: ResourcePath, include_subresources?: bool (default true) }`.
- **Outputs:** `{ json_string: string, hash: sha-256, schema_version: string }`.
- **Godot APIs:** custom serializer using `Object.get_property_list()` + Variant-↔-JSON mapping from
  `06`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Export res://art/hero_material.tres as JSON for diffing."_

### `resource.import_json`

- **Purpose:** reconstitute a resource from a JSON blob produced by `resource.export_json`.
- **Inputs:**
  `{ target_path: ResourcePath, json_string: string, overwrite?: bool (default false) }`.
- **Outputs:** `{ imported: true, path, class, revision }`.
- **Godot APIs:** inverse of `export_json`; revalidate property types; `ResourceSaver.save`.
- **safe:** false. **mutates:** true.
- **Errors:** `resource.json_schema_mismatch` (`-33805`).
- **Cursor prompt:** _"Import this JSON as res://art/imported_material.tres."_

### `resource.set_uid`

- **Purpose:** assign or rotate a stable UID for a resource (for `.tscn` references to survive
  moves).
- **Inputs:** `{ path: ResourcePath, uid?: string (default auto), force?: bool (default false) }`.
- **Outputs:** `{ uid, previous_uid?: string }`.
- **Godot APIs:** `ResourceUID.create_id()`, `ResourceUID.add_id(id, path)`; cache update in
  `.godot/uid_cache.bin`.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Assign a UID to res://art/hero_material.tres."_

### `resource.validate`

- **Purpose:** sanity-check a resource file (loads, all subresources resolvable, no missing
  exports).
- **Inputs:** `{ path: ResourcePath }`.
- **Outputs:** `{ ok: bool, issues: [{ severity, code, message, path? }] }`.
- **Godot APIs:** load, then walk `Object.get_property_list()` and resolve sub-Resources.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Validate every .tres in res://art."_

### `resource.diff`

- **Purpose:** structured diff between two resource files (or against staged JSON).
- **Inputs:** `{ a: ResourcePath, b: ResourcePath | { json_string: string } }`.
- **Outputs:**
  `{ diff: [{ path: string, op: "add"|"remove"|"change", before?, after? }], summary: { added, removed, changed } }`.
- **Godot APIs:** load both → property-level diff via deterministic JSON projections.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Diff res://art/grass.tres vs res://art/grass_dry.tres."_

---

## 14.7 `shader.*` — 6 tools

### `shader.list`

- **Purpose:** list shader files (`.gdshader`) and shader materials (`.tres` whose class is
  `ShaderMaterial`).
- **Inputs:** `{ kind?: "code"|"material"|"any" (default "any") }`.
- **Outputs:** `{ shaders: [{ path, kind, uses_global_uniforms: bool }], total }`.
- **Godot APIs:** filesystem walk; `ResourceLoader.get_resource_type`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"List all shader materials."_

### `shader.read`

- **Purpose:** read shader source.
- **Inputs:** `{ path: ResourcePath, range?: { start_line, end_line } }`.
- **Outputs:**
  `{ path, language: "gdshader", content?, chunks?, truncated, includes: [ResourcePath] }`.
- **Godot APIs:** `FileAccess.open` on `.gdshader`; recursively resolve `#include` directives.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Read res://shaders/water.gdshader."_

### `shader.write`

- **Purpose:** create or overwrite a `.gdshader` file.
- **Inputs:**
  `{ path: ResourcePath, content: string, mode?: "overwrite"|"create_only", if_match?: revision }`.
- **Outputs:** `{ written: true, path, bytes_written, revision }`.
- **Godot APIs:** `FileAccess` write; trigger reimport.
- **safe:** false. **mutates:** true.
- **Cursor prompt:** _"Write a new shader res://shaders/glow.gdshader with this content..."_

### `shader.compile_check`

- **Purpose:** validate a shader compiles.
- **Inputs:** `{ path: ResourcePath }`.
- **Outputs:** `{ ok: bool, errors: [{ line, col, message }], warnings: [...] }`.
- **Godot APIs:** load as `Shader`, then `RenderingServer.shader_compile_async()` or rely on the
  editor's compile diagnostics; for headless, spawn a small compile harness script that loads +
  reads diagnostic logs.
- **safe:** true. **mutates:** false.
- **Errors:** `shader.compile_timeout` (`-33806`).
- **Cursor prompt:** _"Compile-check water.gdshader."_

### `shader.list_params`

- **Purpose:** enumerate uniform parameters of a shader (with hints).
- **Inputs:** `{ path: ResourcePath }`.
- **Outputs:** `{ params: [{ name, type, hint, hint_string?, default? }] }`.
- **Godot APIs:** load `Shader`, call `Shader.get_shader_uniform_list()`; for `ShaderMaterial.tres`,
  read `Material.get_shader_parameter_list()`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"What params does water.gdshader expose?"_

### `shader.set_material_params`

- **Purpose:** set parameter values on a `ShaderMaterial.tres`.
- **Inputs:** `{ material_path: ResourcePath, params: PropertyDict, if_match?: revision }`.
- **Outputs:** `{ updated: true, applied: { key: { before, after } }, revision }`.
- **Godot APIs:** load `ShaderMaterial`, `set_shader_parameter(name, value)` per key,
  `ResourceSaver.save`.
- **safe:** false. **mutates:** true.
- **Errors:** `shader.param_unknown` (`-33807`), `shader.param_type_mismatch` (`-33808`).
- **Cursor prompt:** _"Set wave_speed=0.6 on res://materials/water_mat.tres."_

---

## 14.8 Schemes / data shapes added

- `ResourceSummary` envelope:
  `{ path, class, uid, size_bytes, modified_at, properties_count, subresources_count, pointer_ref?: string }`.
- `DependencyEdge` shape: `{ from, to, kind: "ext_resource"|"sub_resource"|"script"|"include" }`.

## 14.9 Tech stack delta

- No new dependencies.
- New Godot autoload (optional): `ResourceDepIndex` (singleton) — caches dependency edges; rebuilt
  on `EditorFileSystem.resources_reimported`.

## 14.10 Acceptance criteria

- [ ] All 21 tools live; `tools.list({category: "resource"})` and `({category: "shader"})` enumerate
      them.
- [ ] `resource.export_json` is **deterministic** — same resource, same bytes, same hash across
      runs.
- [ ] `resource.import_json` of an export round-trips byte-identical (modulo whitespace).
- [ ] `resource.rename` with `update_references=true` rewrites every dependent
      `.tscn`/`.tres`/`.gd`.
- [ ] `shader.compile_check` returns the same diagnostics in editor and headless modes.

## 14.11 Verification plan

1. **Round-trip:** create → read → update → read → diff returns the expected change set.
2. **Dependency:** delete a resource with dependents and `force=false` → fail with
   `resource.dependency_block`; with `force=true` → succeed and `dependents_warned` is populated.
3. **JSON:** export, mutate JSON, import → produces a valid resource with the mutation applied.
4. **Shader compile:** seed a `.gdshader` with one error; expect `ok=false` with correct `line/col`.
5. **Diff:** introduce one property change → diff lists exactly one `change` entry.
6. **UID:** assign UID; rename the file; ensure all `[ext_resource uid="uid://..."]` references
   still resolve.

## 14.12 Risks & mitigations

| Risk                                                                                | Mitigation                                                                                                              |
| ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `resource.export_json` not deterministic across Godot versions due to map ordering. | Sort property lists by name; pin schema_version per registry minor.                                                     |
| `resource.replace_references` corrupts a binary `.res` file.                        | Restrict text rewrites to text-formatted `.tres`/`.tscn`/`.gd`; for `.res`, emit `resource.binary_rewrite_unsupported`. |
| Cyclic dependencies cause infinite walks.                                           | Cycle detector with visited-set in `resource.get_dependencies(deep=true)`.                                              |
| Shader compile diagnostics not surfaced from `RenderingServer`.                     | Fall back to in-editor stderr capture and parse known patterns (line:col:message).                                      |
| `resource.import_json` from a malformed payload writes garbage.                     | Strict JSON Schema validation per class (register schemas under `packages/shared/schemas/resources/`).                  |

## 14.13 Handoff checklist to file `15`

- [ ] Catalog version `0.6.0` pushed.
- [ ] 69 tools total live.
- [ ] `resource_zoo` fixture committed under `tests/_fixtures/`.
- [ ] Dependency index incremental rebuild benchmarked at < 250 ms for 1k resources.
- [ ] Open `15-catalog-asset-and-batch-refactor.md`.

## 14.14 Commit template

```text
feat(catalog): ship resource.* (15) and shader.* (6) — Phase 3 work-unit #4

- Deterministic JSON export/import with schema versioning
- Project-wide dependency index with reverse lookups
- Shader compile-check with parity (editor/headless)
- UID assignment + reference rewrites preserved across renames
- Bumps catalog_version 0.5.0 -> 0.6.0

Refs: docs/tasklist/14-catalog-resource-and-shader.md
```
