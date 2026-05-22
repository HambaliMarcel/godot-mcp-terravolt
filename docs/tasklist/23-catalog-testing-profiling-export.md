# 23 — Catalog: `testing.*` + `profile.*` + `export.*` (Phase 3 work-unit #13)

> The release-side categories. `testing.*` runs automated tests against the project (GUT / gdUnit4 /
> custom), asserts state, and compares screenshots. `profile.*` exposes Godot's performance monitors
> and adds TerraVolt's own per-tool counters. `export.*` drives release builds — presets, platform
> exports, template info.

---

## 23.1 Header

- **File:** `23-catalog-testing-profiling-export.md`
- **Purpose:** ship `testing.*` (6) + `profile.*` (2) + `export.*` (3) — 11 total.
- **Catalog bump:** `0.14.0` → **`0.15.0`** on land.

## 23.2 Phase placement

Phase 3, work-unit #13. Prerequisite: `22` shipped.

## 23.3 Inputs / prerequisites

- New handlers: `handlers/testing.gd`, `handlers/profile.gd`, `handlers/export.gd`.
- Router modules: `src/tools/testing/`, `src/tools/profile/`, `src/tools/export/`.
- Detect test runner: GUT (`addons/gut/`), gdUnit4 (`addons/gdUnit4/`), or custom — by directory
  scan.
- Detect export templates: `EditorExportPlatform.get_export_templates_dir()`; surface autoHeal for
  "templates not installed".

## 23.4 Outputs

- 11 tools live, registered, validated, documented.
- New fixtures: `tests/_fixtures/testing_zoo/` (two GUT tests, one passing, one failing) and
  `tests/_fixtures/export_zoo/` (a presets-configured fixture).
- `docs/catalog/testing.md`, `docs/catalog/profile.md`, `docs/catalog/export.md` regenerated.

## 23.5 Operating constants used

- `testing_default_timeout_ms = 120000`.
- `profile_sample_window_ms = 1000`.
- `export_default_timeout_ms = 600000`.

---

## 23.6 `testing.*` — 6 tools

### `testing.list_suites`

- **Purpose:** enumerate detected test suites.
- **Inputs:** `{ framework?: "gut"|"gdunit4"|"any" (default "any") }`.
- **Outputs:** `{ framework, suites: [{ name, path, test_count, tags: [string] }] }`.
- **Godot APIs:** filesystem walk under `tests/`, parse class headers (`extends GutTest`,
  `extends GdUnit4TestSuite`).
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"List my GUT test suites."_

### `testing.run`

- **Purpose:** run tests headless.
- **Inputs:**
  `{ framework?: "gut"|"gdunit4"|"auto" (default "auto"), suites?: [string], tags?: [string], parallel?: bool (default false), timeout_ms?: int, fail_fast?: bool (default false) }`.
- **Outputs:**
  `{ ok: bool, summary: { passed, failed, skipped, total }, duration_ms, suites: [{ name, passed, failed, skipped, failures: [{ test, message, stack }] }], report_path?: ResourcePath }`.
- **Godot APIs:** spawn `godot --headless --path <project> -s addons/gut/gut_cmdln.gd -gtest=<...>`
  (or gdUnit4 equivalent); parse the runner's machine-readable output (JSON when available).
- **safe:** false. **mutates:** true (writes a report file).
- **Errors:** `testing.framework_unknown` (`-33K00`), `testing.timeout` (`-33K01`).
- **Cursor prompt:** _"Run all my GUT tests headless."_

### `testing.assert_state`

- **Purpose:** assert a sequence of conditions against the current runtime/editor state, returning a
  structured PASS/FAIL report — for ad-hoc "is the game in expected state?" tests.
- **Inputs:**
  `{ assertions: [{ kind: "expression"|"property"|"signal_listener_exists"|"node_exists"|"text_contains", spec: PropertyDict, expect: any, message?: string }] }`.
- **Outputs:** `{ ok: bool, results: [{ kind, spec, expected, actual, ok }] }`.
- **Godot APIs:** delegates to `node.evaluate_expression` / `node.get` / `signal.list_connections` /
  `runtime.log_tail`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Assert that /Player.health == 100 and a HUD label contains 'Score: 0'."_

### `testing.screenshot_compare`

- **Purpose:** compare a screenshot against a golden image, with tolerance.
- **Inputs:**
  `{ source: { mode: "editor"|"runtime"|"file", path?: ResourcePath }, golden_path: ResourcePath, tolerance?: float (0..1, default 0.02), save_diff_to?: ResourcePath }`.
- **Outputs:**
  `{ ok: bool, mean_diff: float, max_diff: float, pixel_mismatch_count: int, diff_path?: ResourcePath }`.
- **Godot APIs:** load both as `Image`; per-channel diff; `Image.save_png` for diff.
- **safe:** false. **mutates:** true (writes diff file).
- **Errors:** `testing.golden_not_found` (`-33K02`).
- **Cursor prompt:** _"Take a screenshot of the editor viewport and compare to
  res://tests/golden/title.png."_

### `testing.list_reports`

- **Purpose:** list test reports stored under `user://terravolt/test_reports/`.
- **Inputs:** `{ limit?: int (default 20) }`.
- **Outputs:** `{ reports: [{ id, framework, started_at, finished_at, ok, summary }] }`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Show the last 5 test runs."_

### `testing.get_report`

- **Purpose:** read a stored test report.
- **Inputs:** `{ id: string }`.
- **Outputs:**
  `{ report: { ...same shape as testing.run.outputs..., raw_stdout?: string, raw_stderr?: string } }`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Show me the report for the last failing run."_

---

## 23.7 `profile.*` — 2 tools

### `profile.monitor`

- **Purpose:** sample Godot's built-in performance monitors (FPS, draw calls, mem, etc.) plus
  TerraVolt custom monitors.
- **Inputs:**
  `{ keys?: [string] (default common set), window_ms?: int, samples?: int (default 1) }`.
- **Outputs:**
  `{ samples: [{ ts, values: { key: float } }], averages: { key: float }, p95: { key: float } }`.
- **Godot APIs:** `Performance.get_monitor(<id>)`; engine builtins (`Performance.TIME_FPS`,
  `Performance.MEMORY_STATIC`, `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, etc.); custom
  monitors registered with `Performance.add_custom_monitor` from `09`.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"Sample FPS and draw calls for 2 seconds (20 samples)."_

### `profile.flamegraph`

- **Purpose:** capture a CPU flamegraph (script profiler) of the running game for N seconds.
- **Inputs:**
  `{ duration_s?: float (default 5), kind?: "script"|"network" (default "script"), include_native?: bool (default false) }`.
- **Outputs:**
  `{ ok: bool, flamegraph_path: ResourcePath, top_hot_functions: [{ function, file, self_pct, total_pct, calls }] }`.
- **Godot APIs:** `EngineDebugger.send_message("profiler:set", [...])` to start/stop the script
  profiler; collect `network:profile_data` for network. Saves flamegraph data as JSON (and an SVG
  when `flamegraph.pl` available).
- **safe:** true. **mutates:** true (writes file).
- **Errors:** `profile.flamegraph_unavailable` (`-33K10`).
- **Cursor prompt:** _"Capture a 5-second flamegraph of the running game."_

---

## 23.8 `export.*` — 3 tools

### `export.list_presets`

- **Purpose:** list export presets defined in `export_presets.cfg`.
- **Inputs:** none.
- **Outputs:**
  `{ presets: [{ name, platform, runnable, export_path, encryption_directory_filters, custom_features: [string], options_summary: PropertyDict }] }`.
- **Godot APIs:** parse `export_presets.cfg` (INI); cross-check with `EditorExportPlatform`
  enumeration.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"List my export presets."_

### `export.build`

- **Purpose:** build the project against a preset.
- **Inputs:**
  `{ preset: string, debug?: bool (default true), output_path?: ResourcePath, with_pck_only?: bool (default false), platform_args?: PropertyDict }`.
- **Outputs:**
  `{ ok: bool, exit_code, duration_ms, artifacts: [{ path, size_bytes, kind: "binary"|"pck"|"zip"|"data" }], log_tail: string }`.
- **Godot APIs:** spawn `godot --headless --export-debug "<preset>" "<output>"` or
  `--export-release` / `--export-pack`. Capture stderr/stdout.
- **safe:** false. **mutates:** true.
- **Errors:** `export.preset_unknown` (`-33K20`), `export.template_missing` (`-33K21`),
  `export.timeout` (`-33K22`).
- **Cursor prompt:** _"Export a Windows debug build to dist/win/."_

### `export.template_info`

- **Purpose:** describe installed export templates.
- **Inputs:** none.
- **Outputs:**
  `{ templates_dir, installed: [{ version, platforms: [string], path }], current_godot_version: string, mismatched: bool }`.
- **Godot APIs:** `EditorExportPlatform.get_export_templates_dir()`; scan that folder.
- **safe:** true. **mutates:** false.
- **Cursor prompt:** _"What export templates do I have installed?"_

---

## 23.9 Schemes / data shapes added

- `Assertion` discriminated union per `testing.assert_state.assertions[]`.
- `TestReport` shape (matches both `testing.run.outputs` and `testing.get_report.report`).
- `ExportArtifact` shape per `export.build.artifacts[]`.
- `MonitorSample` shape per `profile.monitor.samples[]`.

## 23.10 Tech stack delta

- Optional dev dependency: `flamegraph.pl` for SVG flamegraph rendering (otherwise JSON-only).
- New folder `user://terravolt/test_reports/` for persisted reports.

## 23.11 Acceptance criteria

- [ ] All 11 tools live; visible via `tools.list` per category.
- [ ] `testing.run` against the fixture returns the expected pass/fail split.
- [ ] `testing.screenshot_compare` flags a 5% deliberate change vs golden with
      `mean_diff > tolerance`.
- [ ] `profile.monitor` returns samples at `window_ms / samples` cadence within ±10%.
- [ ] `export.build` produces a non-zero artifact for the platform under test in CI
      (Linux/Windows/macOS).
- [ ] `export.template_info` reports `mismatched=true` when the installed templates' version differs
      from the running editor.

## 23.12 Verification plan

1. **Test framework detection:** `testing.list_suites` correctly identifies GUT in the fixture;
   reports `framework="gut"`.
2. **Run + persist:** `testing.run` produces a report; `testing.list_reports` includes it;
   `testing.get_report` returns the same data.
3. **Screenshot compare:** deliberately tinker a pixel; mismatch detected; diff file saved.
4. **Profiler:** capture flamegraph during a hot loop; `top_hot_functions[0]` is the loop method.
5. **Export:** invoke a Linux PCK-only export; verify the `.pck` is created and reproducible (same
   bytes on rerun).

## 23.13 Risks & mitigations

| Risk                                                                      | Mitigation                                                                                                          |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| GUT and gdUnit4 differ in cmdline grammar.                                | Per-framework adapter under `services/test_runner/gut.gd` / `gdunit4.gd`.                                           |
| Headless screenshot compare cannot capture editor windows.                | Document: `editor` mode only works when an editor is open; `runtime` mode requires `runtime.play`/`start_headless`. |
| Export templates auto-update across Godot versions and break determinism. | `export.build` records the templates' SHA in the artifact metadata.                                                 |
| Flamegraph capture in release builds requires `--debug` mode.             | Tool surfaces `profile.flamegraph_unavailable` autoHeal when the running build doesn't expose the profiler API.     |
| Long exports can wedge CI.                                                | Per-call `export_default_timeout_ms`; auto-kill the subprocess; surface `export.timeout`.                           |

## 23.14 Handoff checklist to file `24`

- [ ] Catalog version `0.15.0` pushed.
- [ ] 194 tools total live.
- [ ] CI gains an "export smoke test" matrix entry per platform.
- [ ] Open `24-catalog-macros.md`.

## 23.15 Commit template

```text
feat(catalog): ship testing.* (6), profile.* (2), export.* (3) — Phase 3 work-unit #13

- GUT + gdUnit4 adapters with persisted reports
- Screenshot compare with diff output
- Performance.monitor sampling + flamegraph capture
- Export presets / templates / build pipeline
- Bumps catalog_version 0.14.0 -> 0.15.0

Refs: docs/tasklist/23-catalog-testing-profiling-export.md
```
