# 26 — Android deploy chain + scenario orchestration

> Phase 4 closeout: the only remaining feature surface from `godot-mcp-pro` that Terravolt did not
> have (Android deploy chain via `adb`) plus a scenario-style runner that orchestrates ordered
> input/wait/assert/screenshot steps. Hits the 222-tool stretch goal from
> [`docs/tasklist/25-catalog-completion-gate.md`](./25-catalog-completion-gate.md).

---

## 26.1 Header

- **File:** `26-android-and-scenario.md`
- **Purpose:** ship a `android.*` (3) + `testing.run_scenario` so the catalog matches the 222-tool
  target named by file 25 and surpasses every reference plugin on every dimension.
- **Catalog bump:** `0.16.0` → **`0.17.0`** when this file's gate is green.

## 26.2 Phase placement

End of Phase 4 (release / capability hardening). Prerequisites: tasks 11–25 closed; CI green.

## 26.3 Inputs / prerequisites

- `docs/tasklist/25-catalog-completion-gate.md` accepted (218 → 222 target documented there).
- Reference: `references/godot-mcp-pro/addons/godot_mcp/commands/android_commands.gd`
  (`list_android_devices`, `get_android_preset_info`, `deploy_to_android`).
- Reference: `references/godot-mcp-pro/addons/godot_mcp/commands/test_commands.gd`
  (`run_test_scenario` orchestrator).

## 26.4 Outputs

When this file is done:

1. **`android.*` category** (3 methods) registered in `packages/shared/methods/registry.json`.
2. **`testing.run_scenario`** registered in the `testing` category.
3. **`packages/godot-mcp-addon/handlers/android.gd`** + `android_helpers.gd` implement the commands;
   both are headless-safe (they shell out to `adb` and `Godot --headless --export-debug`, no editor
   dependency).
4. **Headless dispatch** in `headless_driver.gd` + `catalog_ops.gd` covers all 4 new methods.
5. **Error registry** gains 5 new app codes: `testing.scenario_failed`, `android.adb_not_found`,
   `android.preset_not_found`, `android.install_failed`, `android.export_failed`.
6. **Integration test** at
   `packages/mcp-server/tests/integration/android/android_and_scenario_headless.test.mjs` — 30th
   test in the suite, green against live Godot 4.6.3.

## 26.5 New tools

| Method                 | Category | Headless | Safe? | Notes                                                             |
| ---------------------- | -------- | -------- | ----- | ----------------------------------------------------------------- | ---- | ------ | ----------------------------- |
| `android.list_devices` | android  | yes      | read  | `adb devices -l`; returns serial + state + product/model/device   |
| `android.preset_info`  | android  | yes      | read  | Inspect `export_presets.cfg` for an Android preset                |
| `android.deploy`       | android  | yes      | write | Optional `--export-debug/release` + `adb install -r` + `am start` |
| `testing.run_scenario` | testing  | yes      | write | Sequence of `{type:input                                          | wait | assert | screenshot}`; per-step report |

## 26.6 Acceptance criteria

- [x] `npm run catalog:sync` reports 222 methods at `0.17.0`.
- [x] `npm run validate:catalog` is green (handlers wired, headless dispatch, error mirror).
- [x] `npm run coverage:report` writes 222 tools to `docs/coverage/catalog-coverage.md`.
- [x] `npm run release:check` mirrors 130 app error codes.
- [x] `npm run test:server` is **31/31** against live Godot 4.6.3 (includes the exhaustive
      `coverage/all_methods_dispatch` smoke that walks the registry and asserts no
      method-not-found).
- [x] `docs/coverage/parity-matrix.md` lists `android.*` as ✅ live and notes the +50 over Pro.

## 26.7 Verification (smoke)

```bash
# from H:\Godot MCP Marcel
npm run catalog:sync && npm run validate:catalog
$env:TERRAVOLT_GODOT_BINARY="<Godot 4.6.x executable>"
npm run test:server
```

Expected last line of `test:server`: `ℹ pass 30` / `ℹ fail 0`.

## 26.8 Why this lives outside the `08` umbrella

File 08 set the **target** at 200+; file 25 raised the **stretch** to 222; this file ships the final
4 tools that hit that stretch and closes the last remaining feature gap vs `godot-mcp-pro` (Android
deploy chain). It is intentionally narrow — no new framework, no new transport — so it can be tagged
`v0.17.0-rc.1` immediately after this PR lands.
