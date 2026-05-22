# 25 — Catalog completion gate & 1.0 release readiness

> Phase 3 closes here. This file is **not** a new category — it's the **final gate** the agent must
> pass before the catalog is declared "feature-complete vs the 200+ feature objective" and the
> project is ready for the 1.0 release pipeline defined in file `10`.

---

## 25.1 Header

- **File:** `25-catalog-completion-gate.md`
- **Purpose:** validate everything `11`–`24` produced; close the 200+ feature objective; hand off to
  file `10`'s release flow.
- **Catalog bump:** `0.16.0` → **`0.17.0-rc.1`** when this file's gate is green.

## 25.2 Phase placement

End of Phase 3 / entry to Phase 4 (release). Prerequisites: every category from `11`–`24` shipped,
**209 tools live**.

## 25.3 Inputs / prerequisites

- Files `11`–`24` complete; their commit templates merged to `master`.
- CI green across all matrix entries from file `10`.
- All registered tools have a 5-test row in CI per `08 §8.11`.

## 25.4 Outputs

When this file is done:

1. **Catalog Coverage Report** published at `docs/coverage/catalog-coverage.md` (auto-generated).
2. **Feature Parity Matrix** vs the reference plugin (the `godot-mcp-pro` screenshot the user
   shared) published at `docs/coverage/parity-matrix.md`.
3. **End-to-end vibe-coding demo** (`docs/demos/vibe-coding-walkthrough.md` + a short video / GIF
   artifact) showing an empty Godot project turned into a playable 2D platformer slice via prompts
   only.
4. **1.0 release candidate** tagged `v0.17.0-rc.1`.
5. **Linear issues opened** for known gaps and tracked under a milestone "TerraVolt 1.0 — Catalog
   Complete".

## 25.5 Operating constants used

No new constants. References existing ones across files.

---

## 25.6 Completion checklist — the 200+ feature gate

> The agent must check off every box. Any unchecked item blocks the 1.0 RC tag.

### 25.6.1 Tool count and registry integrity

- [ ] `tools.list` returns **≥ 209 tools** (live count).
- [ ] `tools.health` returns `ok` (router and addon hashes match; catalog_version aligned).
- [ ] `release:check` passes the `catalog_hash` + `error_mirror` + `versions` + `readiness` +
      `changelog` gates.
- [ ] Every entry in `packages/shared/methods/registry.json` has a paired handler in
      `packages/godot-mcp-addon/handlers/<category>.gd`.
- [ ] Every error code in `packages/shared/errors/registry.json` is mirrored in `error_codes.gd`.

### 25.6.2 Category-by-category presence

| File                    | Category(s)                                               |                 Tool count | Status |
| ----------------------- | --------------------------------------------------------- | -------------------------: | ------ |
| `11`                    | `scene.*` + `project.*`                                   |                         16 | [ ]    |
| `12`                    | `node.*`                                                  |                         14 | [ ]    |
| `13`                    | `script.*` + `signal.*`                                   |                         18 | [ ]    |
| `14`                    | `resource.*` + `shader.*`                                 |                         21 | [ ]    |
| `15`                    | `asset.*` + `batch_refactor.*`                            |                         20 | [ ]    |
| `16`                    | `editor.*` + `analysis.*`                                 |                         13 | [ ]    |
| `17`                    | `runtime.*`                                               |                         19 | [ ]    |
| `18`                    | `animation.*` + `animation_tree.*`                        |                         14 | [ ]    |
| `19`                    | `physics.*` + `particle.*` + `navigation.*`               |                         17 | [ ]    |
| `20`                    | `tilemap.*` + `theme_ui.*`                                |                         12 | [ ]    |
| `21`                    | `audio.*` + `input.*`                                     |                         13 | [ ]    |
| `22`                    | `scene_3d.*`                                              |                          6 | [ ]    |
| `23`                    | `testing.*` + `profile.*` + `export.*`                    |                         11 | [ ]    |
| `24`                    | `macro.*`                                                 |                         15 | [ ]    |
| **Pre-3 (files 04–07)** | health (5) + daemon (3) + headless (4) + escape hatch (1) |                         13 | [ ]    |
| **Total**               |                                                           | **222** (≥ 200+ objective) | [ ]    |

### 25.6.3 Quality gates

- [ ] Every tool has an `inputSchema`, `outputSchema`, `errors[]`, and ≥ 1 example in the registry.
- [ ] Every tool has at least the 5-test baseline (happy read, happy write, schema rejection, domain
      error, notification or N/A) from `08 §8.11`.
- [ ] Every mutator returns `state` + `diff` envelope.
- [ ] Every editor-only tool returns `editor.not_available` with autoHeal in headless mode.
- [ ] Every long-running tool emits a progress event or returns within 30s on the reference fixture.

### 25.6.4 Documentation gates

- [ ] `docs/catalog/<category>.md` files regenerated and committed for every category in 25.6.2.
- [ ] `docs/coverage/catalog-coverage.md` generated from the registry — lists tool count per
      category, parity flags, total.
- [ ] `docs/coverage/parity-matrix.md` lists every feature from the comparison screenshot and
      TerraVolt's status (✅ live, ⏳ planned, ❌ not planned, with reasoning).
- [ ] `docs/guides/use-cases.md` updated to reflect the full ~222 tool surface (refresh from the
      13-tool draft).
- [ ] `docs/guides/quick-start.md` updated with at least one example call per category.
- [ ] `docs/demos/vibe-coding-walkthrough.md` — 10-minute scripted demo (prompts + expected
      outcomes) that builds a playable 2D slice from scratch using only macros + a handful of
      mutators.

### 25.6.5 Performance gates

- [ ] Editor round-trip p95 ≤ `editor_p95_ms_budget` (`09 §9.10`) under the integration suite.
- [ ] Headless validate p95 ≤ `headless_p95_ms_budget`.
- [ ] Tool registry load time ≤ `registry_load_ms_budget` on a cold start.
- [ ] No tool above `slow_tool_alert_ms_budget` in `tools.bottlenecks` after a full E2E run
      (exempting export.build, profile.flamegraph, navigation.bake).

### 25.6.6 Reliability gates

- [ ] `tools.metrics` shows ≥ 99% success rate across the integration suite (excluding
      intentionally-failing assertion fixtures).
- [ ] WebSocket disconnect / reconnect tested against editor close + reopen → router auto-recovers
      within `reconnect_max_ms`.
- [ ] Two concurrent agents driving the same daemon: both see consistent `revision` tokens;
      conflicting writes fail with `protocol.idempotency_conflict`.
- [ ] Crash recovery: kill -9 the daemon → router surfaces `daemon.unreachable` with autoHeal; on
      daemon restart, `tools.health` returns green within 10s.

### 25.6.7 Security gates

- [ ] `editor.execute_script` deny-list test passes (forbidden identifiers refused).
- [ ] `node.evaluate_expression` and `runtime.evaluate` deny-lists tested.
- [ ] `batch_refactor.*` two-phase commit cannot leave files in half-rewritten state (kill -9
      mid-apply test).
- [ ] No tool reads/writes outside `res://` and `user://` without explicit
      `confirm_high_risk: true`.
- [ ] WebSocket bind address default is loopback; remote bind requires
      `terravolt_mcp/server/allow_remote: true` and emits a banner warning.

### 25.6.8 Headless / CI gates

- [ ] All `headless.*` flows pass in CI matrix on Linux + Windows + macOS for the supported Godot
      minors.
- [ ] `export.build` smoke test produces a working PCK for at least one platform per OS in CI.
- [ ] `testing.run` returns the same pass/fail count locally and in CI.

### 25.6.9 Parity vs reference plugin (the screenshot)

Use `docs/coverage/parity-matrix.md`. The agent must list each row from the screenshot's feature
list and mark TerraVolt's status. At gate time:

- [ ] Tool surface count is **≥** the reference's claim (~163 → TerraVolt ≥ 209).
- [ ] Every reference feature listed under "Key Features" is either ✅ live or ⏳ on the 1.0
      milestone with an open Linear issue.
- [ ] TerraVolt's **differentiators** explicitly listed: `tools.health` + catalog SHA pinning,
      `tools.metrics` + `tools.bottlenecks`, `headless` fallback, `context.fetch_raw`, AJV schema
      validation, structured `autoHeal`, two-phase batch refactor with revert, deterministic
      `resource.export_json`, `macro.*` scaffolders.

---

## 25.7 Schemes / data shapes added

- `CoverageReport` shape (generated):
  `{ generated_at, catalog_version, tool_count, by_category: { name: { count, files: [string] } }, gaps: [string] }`.
- `ParityMatrix` shape:
  `{ rows: [{ feature, reference_source, terravolt_status, notes, linear_issue? }] }`.

## 25.8 Tech stack delta

- Doc generator extended to read the live registry and emit `catalog-coverage.md` and
  `parity-matrix.md`.
- New CI step `coverage:report` runs the generator and asserts the total tool count ≥ 200.

## 25.9 Acceptance criteria

- [ ] Every checkbox in 25.6.\* is checked off in the PR that lands this file's deliverables.
- [ ] CI `coverage:report` step passes with `total_tools ≥ 200`.
- [ ] `v0.17.0-rc.1` tag is created on `master` after the PR merges.
- [ ] Linear milestone "TerraVolt 1.0 — Catalog Complete" contains zero open blockers.

## 25.10 Verification plan

1. **Tool count assertion:** `npm run coverage:report` exits 0 and prints
   `total_tools=222 (+ buffer)`.
2. **End-to-end demo:** record the vibe-coding walkthrough; verify each prompt produces the expected
   scene/script/UI artifacts.
3. **Disaster drills:**
   - kill -9 daemon; router recovers.
   - corrupt `registry.json`; `tools.health` flags `catalog_mismatch` with autoHeal.
   - run two MCP clients simultaneously; both observe consistent revision tokens.
4. **Parity matrix review:** every row has a status; statuses backed by either a registry entry, a
   Linear issue, or a doc note explaining "intentionally not planned".
5. **RC tag dry-run:** `release:check` green; `gh release create v0.17.0-rc.1 --draft` succeeds.

## 25.11 Risks & mitigations

| Risk                                                                                 | Mitigation                                                                                                   |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| One sub-category lags (e.g., `runtime.*` blocked on platform-specific input quirks). | File a Linear issue and gate the 1.0 RC behind it; ship the RC under `0.17.0-rc.X` until the issue resolves. |
| Reference plugin keeps growing during our development.                               | Parity matrix snapshots the reference at gate time (date-stamped); future parity work is its own milestone.  |
| Doc generator drift from registry shape.                                             | Regenerator is part of CI; PRs that change the registry but not docs fail.                                   |
| 200+ count via low-quality "stub" tools.                                             | Every counted tool must have the 5-test baseline (no stubs).                                                 |
| Performance gates marginal in CI runners.                                            | Use the dedicated CI runner spec from `10`; document baseline numbers per runner.                            |

## 25.12 Handoff to file `10`

- [ ] Tag `v0.17.0-rc.1` (RC track defined in `10 §10.7`).
- [ ] Trigger release pipeline per `10`.
- [ ] Open a Linear "TerraVolt 1.0 — Public" milestone targeting `v1.0.0` once any soak issues are
      resolved.

## 25.13 Commit template

```text
chore(release): catalog gate green — 222 tools live, 1.0 RC

- Coverage report shows 222 registered tools across 22 categories
- Parity matrix tracks every reference-plugin feature
- All quality / docs / performance / reliability / security gates passing
- Tags v0.17.0-rc.1 to enter the release pipeline

Refs: docs/tasklist/25-catalog-completion-gate.md, docs/tasklist/10-quality-testing-release-and-docs.md
```

---

## 25.14 What "done" looks like

- A new user opens Cursor, runs `npx terravolt-mcp` (or installs the addon + npm package), and
  points Cursor at it via `.cursor/mcp.json`.
- They prompt: _"Boot a new Godot project at ~/Games/CaveDive, scaffold a 2D platformer player, a
  wave spawner, a HUD, and a main menu. Save as the main scene. Test it headless."_
- TerraVolt:
  1. `tools.health` confirms wiring.
  2. `macro.basic_2d_level` → level file.
  3. `macro.player_controller_2d` → player.
  4. `macro.enemy_wave_spawner` → spawner.
  5. `macro.hud_health_score` → HUD.
  6. `macro.main_menu` → menu + `project.set_main_scene`.
  7. `headless.run_project` → smoke test.
  8. Returns: _"Playable build verified. Press Play in Godot to try it."_
- That's the **vibe-coding loop**. Files `11`–`24` make every step of that loop possible; file `25`
  proves it's actually shippable.
