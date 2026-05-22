# 10 — Quality, Testing, Release & Docs

> **Goal**: ship. Build the full QA matrix, integration harness, vibe-coding end-to-end scenarios,
> performance benchmarks, documentation site, support matrix, versioning policy, release pipeline,
> security review, and post-release maintenance plan. After this file, **Terravolt Godot MCP `1.0`**
> is releasable.

---

## 10.1 Header

- **File:** `10-quality-testing-release-and-docs.md`
- **Purpose:** lock the QA, docs, and release workflow that takes Phase 4 code to a public release
  and keeps it healthy after.

## 10.2 Phase placement

- **Release phase.** Cross-cutting; consumes everything from `00`–`09`.

## 10.3 Inputs / prerequisites

- Files `00`–`09` complete.
- Catalog from `08` (~230 tools) implemented at least at "core tool per category" depth, with all
  error codes registered.
- Context optimizations from `09` live.
- Headless fallback from `07` working in CI.

## 10.4 Outputs

After this file:

1. **Test pyramid** is established — unit, integration, end-to-end (E2E), chaos, soak, performance —
   with documented coverage targets.
2. **CI pipelines** in `.github/workflows/` lint, test, build, run E2E, and (on tag) publish
   artifacts.
3. **Documentation site** under `docs/` is complete and consistent: README, quick start, catalog,
   parity matrix, error registry, FAQ, troubleshooting.
4. **Versioning policy** is explicit (semver) and tied to release-note generation.
5. **Release pipeline** for both packages:
   - `packages/mcp-server/` → npm registry as `@terravolt/godot-mcp` (or chosen name).
   - `packages/godot-mcp-addon/` → packaged as a zip suitable for the Godot Asset Library / a GitHub
     release.
6. **Support matrix** documents supported Godot versions, Node versions, and operating systems.
7. **Security review** addresses arbitrary script execution, port exposure, log content, and update
   policy.
8. **Vibe-coding showcase** — a scripted end-to-end story that an agent can replay to prove the
   system end to end.
9. **Roadmap** for v1.1+ recorded.

## 10.5 Operating constants used

All from previous files.

---

## 10.6 Detailed task breakdown

### 10.6.1 Test pyramid

| Layer                                       | Scope                                                                                                           | Owner                                    | Tools                                                 |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | ---------------------------------------- | ----------------------------------------------------- |
| Unit (router)                               | Pure TS modules (jsonrpc framing, schema validator wrapping, error mapping, retry helper, envelope summarizer). | `packages/mcp-server/tests/unit/`        | Node built-in test runner (or vitest if chosen).      |
| Unit (addon)                                | Pure GDScript helpers (logger formatter, validator, summarizer).                                                | `packages/godot-mcp-addon/tests/unit/`   | GUT or gdUnit4 (decision from `02`).                  |
| Integration (router ↔ daemon)               | Round-trip per category, including error paths and notifications.                                               | `packages/mcp-server/tests/integration/` | Custom harness; live editor or headless.              |
| E2E (MCP client → router → daemon → result) | Cursor-like client (or SDK example client) exercising tools.                                                    | `tests/e2e/` (top-level)                 | Node test runner; spawns router; uses MCP SDK client. |
| Catalog parity                              | Editor vs headless equivalence for every cross-mode tool.                                                       | `tests/parity/`                          | Iterates over the parity matrix.                      |
| Chaos                                       | Random WS disconnects, mid-batch failures, headless crashes.                                                    | `tests/chaos/`                           | Custom harness.                                       |
| Soak                                        | 24h workload of mixed tools.                                                                                    | `tests/soak/`                            | Nightly CI optional; locally executable.              |
| Performance                                 | Latency SLAs from `09`; payload caps; cold/warm starts.                                                         | `tests/perf/`                            | Microbench scripts.                                   |
| Doc tests                                   | Examples in `docs/catalog/` actually round-trip.                                                                | `tests/docs/`                            | Harvest examples; run them.                           |

Coverage **targets** (not enforced as a single number; per-layer goals):

- Router unit: ≥ 80% line coverage.
- Daemon unit: ≥ 70% (GDScript coverage tooling is younger).
- Integration: ≥ 1 test per _category_, ≥ 3 tests per _high-value tool_ (read, write, error).
- E2E: at least one full "vibe coding" scenario.
- Chaos / soak: green for 24h on the soak rig.

### 10.6.2 Integration harness

A standardized `tests/_harness/` provides:

- `startDaemon(opts)` — boots either a real Godot editor in a temp project (with addon mounted) or a
  headless session. Returns a handle.
- `startRouter(daemonHandle, opts)` — spawns the router as a child process; pipes MCP client over a
  memory-channel adapter.
- `mcpClient(routerHandle)` — connects via MCP SDK client.
- `assertResultEnvelope(result)` — checks the envelope shape from `09 §9.7.1`.
- `assertErrorEnvelope(error)` — checks shape from `09 §9.7.2`.
- `withSeededProject(name, fn)` — copies a seed project to a temp directory; cleans up after.

Test data ships under `tests/_fixtures/` with several small Godot projects (e.g., `empty/`,
`minimal_3d/`, `dialogue_demo/`, `stress_tree_10000/`).

### 10.6.3 Test selection per category

For every category (per `08`), at minimum:

- One "happy path read" test.
- One "happy path write + diff" test.
- One "schema rejection" test.
- One "domain error → autoHeal" test.
- One "notification" test (where the category emits events).
- One "parity test" (editor vs headless) where applicable.

Macro tests additionally exercise rollback on partial failure.

### 10.6.4 E2E "vibe coding" showcase

A scripted end-to-end story the agent (or a test harness) can replay:

1. Start with `tests/_fixtures/empty/`.
2. `project.ensure_addons` → confirm Terravolt MCP enabled.
3. `scene.create` → main scene with `Node3D` root.
4. `node.add` → camera, light, ground (StaticBody3D + CollisionShape3D).
5. `macro.scaffold_player_controller_3d` → player rig.
6. `script.attach` → behavior on `Player`.
7. `signal.connect` → input action wired to player.
8. `scene.save`.
9. `runtime.play` → headless run with timeout; capture stdout.
10. `runtime.get_performance` → assert FPS reasonable.
11. `runtime.stop`.
12. `headless.export` → produce a build for a test preset.
13. `headless.run_tests` → run the addon's tests (if any).
14. Capture metrics; verify under SLAs.

This scenario is the **release-blocking smoke** for v1.

### 10.6.5 Performance benchmarks

Measure and record baselines:

| Scenario                                   | Target                     |
| ------------------------------------------ | -------------------------- |
| Cold router boot (no daemon)               | < 200 ms                   |
| Cold daemon boot (editor enable)           | < 2 s                      |
| `ping` round-trip (warm)                   | < 5 ms p50, < 20 ms p95    |
| `scene.get_tree` 1k nodes (summary)        | < 50 ms p95                |
| `scene.get_tree` 1k nodes (raw, under cap) | < 250 ms p95               |
| `node.modify` single                       | < 100 ms p95               |
| `node.modify` 100-batch                    | < 400 ms p95               |
| Headless cold start                        | < 5 s                      |
| `headless.validate_script` small file      | < 1 s                      |
| `headless.export` small project            | < 30 s                     |
| Reconnect after daemon restart             | < 1 s typical, < 5 s worst |

If a target is missed, file an issue, _do not silently change the target_ — investigate first.

### 10.6.6 CI pipelines (`.github/workflows/`)

| Workflow          | Trigger                          | Steps                                                                                                 |
| ----------------- | -------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `lint.yml`        | PR + push                        | TS lint, GDScript style check (best-effort via headless Godot), Prettier check, docs links check.     |
| `unit.yml`        | PR + push                        | Router unit + addon unit.                                                                             |
| `integration.yml` | PR + push                        | Spawn headless Godot; run integration; upload artifacts.                                              |
| `e2e.yml`         | PR + push (label-gated for cost) | The "vibe coding showcase" using the headless harness.                                                |
| `parity.yml`      | PR + push                        | Editor vs headless parity tests; uses xvfb on Linux runners or a headless mode of the editor in test. |
| `perf.yml`        | nightly                          | Performance benchmarks; comments deltas.                                                              |
| `chaos.yml`       | nightly                          | Chaos suite.                                                                                          |
| `soak.yml`        | weekly (manual)                  | 24h soak.                                                                                             |
| `release.yml`     | tag `v*.*.*`                     | Build router; package addon; publish to npm and create GitHub release.                                |
| `docs.yml`        | push to `main`                   | Regenerate `docs/catalog/` and deploy if hosting docs.                                                |

Runners: Linux (default), macOS, Windows (essential because Godot's GDScript paths differ slightly
per OS). Each platform-relevant suite runs on all three OSs at least nightly.

### 10.6.7 Versioning policy

- Semver, applied to both packages independently but **synchronized for major releases**.
- `catalog_version` in `packages/shared/methods/registry.json` follows semver and is bumped:
  - PATCH for non-breaking bugfixes or hint updates.
  - MINOR for new tools, new error codes, new event types.
  - MAJOR for breaking schema changes, removed tools, renamed methods.
- Breaking changes require a deprecation entry in the registry with `replacedBy`. Tools marked
  deprecated emit a `warnings` entry on each call for one minor before removal.

### 10.6.8 Release pipeline

Steps the `release.yml` workflow performs on tag push:

1. Verify tag matches `packages/mcp-server/package.json` version.
2. Run full unit + integration + E2E suite.
3. Build router (`tsc`); produce `dist/`.
4. Pack `packages/godot-mcp-addon/` as `terravolt-mcp-addon-<version>.zip`.
5. Generate release notes from the changelog + the auto-derived "added/changed/removed tools" diff
   against the previous registry.
6. Publish router to npm (authenticated via secret).
7. Create a GitHub release with the addon zip attached.
8. (Optional) Submit the addon to Godot Asset Library if process supports automation.
9. Update `docs/` with the new version banner.

### 10.6.9 Documentation site

`docs/` final structure:

```text
docs/
  README.md                              (index — already exists; updated)
  repo-layout.md
  architecture/overview.md
  context/context-map.md
  references/reference-repos-map.md
  srs/...                                 (existing)
  tasklist/00..10.md                      (this set)
  catalog/
    index.md
    cheat-sheet.md
    parity.md
    server.md, log.md, event.md, tools.md, scene.md, node.md, script.md, signal.md,
    resource.md, asset.md, runtime.md, editor.md, project.md, input.md, animation.md,
    physics.md, render.md, audio.md, network.md, debug.md, profile.md, macro.md
  errors/
    index.md                              (mirror of registry.json with prose)
  diagnostics/
    autoheal.md
  guides/
    quick-start.md                        (zero → first prompt in 10 minutes)
    vibe-coding.md                        (how to prompt the agent for sustained sessions)
    headless-only.md                      (CI / no-editor workflow)
    custom-presets.md                     (asset presets, scaffolding recipes)
    troubleshooting.md
    upgrade.md
    contributing.md                       (or link to existing CONTRIBUTING.md)
  faq.md
  security.md                             (link to SECURITY.md)
  support-matrix.md
```

The "vibe coding" guide is the marquee document: it walks through prompts the agent can use to build
games end-to-end. It explicitly references tools by name and shows expected envelope shapes (no
code).

### 10.6.10 Support matrix

A table updated each release:

| OS                    | Godot 4.x version | Node        | Editor mode | Headless mode |
| --------------------- | ----------------- | ----------- | ----------- | ------------- |
| Windows 10/11 (x64)   | 4.x stable        | 20 LTS      | ✅          | ✅            |
| macOS 13+ (ARM/Intel) | 4.x stable        | 20 LTS      | ✅          | ✅            |
| Linux (Ubuntu 22.04+) | 4.x stable        | 20 LTS      | ✅          | ✅            |
| Earlier OSs           | best effort       | best effort | ⚠           | ⚠             |

Godot 3.x is **not** supported.

### 10.6.11 Security review

Address in `SECURITY.md`:

- **Local-only by default**: daemon binds `127.0.0.1`; refuse `0.0.0.0` unless an explicit opt-in
  flag.
- **Optional token auth**: `terravolt_mcp/security/require_token` + a token; router must supply it
  on the WS path or as the first frame.
- **TLS**: not required for `127.0.0.1`; reserve for future remote deployments.
- **Arbitrary script execution**: gated by `--allow-arbitrary-scripts` in the router; off by
  default.
- **Logs**: never log raw user data (prompts, secrets); redact paths under `secret/*` patterns;
  agents can disable verbose params with `terravolt_mcp/logging/redact = true`.
- **Updates**: release notes call out security-relevant changes; users on auto-update tools should
  subscribe to release feed.
- **Supply chain**: pin npm dependencies, audit on each release (`npm audit`), avoid post-install
  scripts, prefer first-party Godot APIs.

### 10.6.12 Telemetry & privacy

- Terravolt does **not** phone home. No telemetry is emitted off-machine.
- All metrics (`tools.metrics`, `tools.bottlenecks`) are local and accessible only via MCP tools.

### 10.6.13 FAQ outline

Topics:

- "Do I need Godot open?" (no, headless covers most things).
- "Can two agents use one daemon?" (single-client v1).
- "How do I add a new tool?" (link to `06` and `08`).
- "Why isn't my project recognized?" (resolution order in `07 §7.6.7`).
- "What's the difference between Godot MCP Pro / tomyud1 / Coding-Solo and Terravolt?" (the
  comparison from `references/reference-repos-map.md`).
- "Is this safe to use on big projects?" (yes, envelopes from `09`).
- "How do I report a bug?" (link to GitHub issues + telemetry capture instructions).

### 10.6.14 Roadmap (v1.1+ ideas)

Captured at the end of the docs and as GitHub issues:

- Multi-client daemon.
- Visualizer port `6510` parity with `tomyud1`.
- LLM-assisted refactors (server-side LLM call disabled by default).
- C# (.NET) deeper coverage parity with GDScript.
- Resource preview thumbnails in tool outputs.
- Headless multi-session.
- Cloud agent integration (Cursor cloud agents).

### 10.6.15 Open-source operations

- License confirmed (existing `LICENSE` file; recommend MIT to match upstream peers).
- `CONTRIBUTING.md` updated to reference `docs/tasklist/` and the catalog-gen flow.
- `CODE_OF_CONDUCT.md` kept as-is.
- Issue templates: bug report, feature request, security report (private route).
- PR template: requires checklist confirming impact analysis if available (GitNexus).

### 10.6.16 Release readiness review

A single pre-tag review reads:

- [ ] All Phase 4 acceptance criteria from `09` met.
- [ ] At least one tool shipped per category from `08`.
- [ ] Showcase scenario (§10.6.4) passes locally and in CI.
- [ ] All workflows green for 7 consecutive days.
- [ ] No unresolved CRITICAL/HIGH bugs.
- [ ] Documentation site builds clean.
- [ ] Support matrix updated.
- [ ] Security review fresh.
- [ ] Decisions Log up to date.
- [ ] Release notes drafted from registry diff.

### 10.6.17 Post-release maintenance

- **Weekly**: dependency audits (npm audit; Godot patch advisories).
- **Bi-weekly**: documentation refresh (catalog diffs).
- **Monthly**: perf regression review.
- **Quarterly**: re-evaluate roadmap; consider deprecations.

### 10.6.18 Manual smoke tests

1. Fresh OS install scenario: install Godot + Node; clone repo; run quick-start guide; build the
   showcase scene in < 10 minutes from prompts.
2. CI dry-run on a fork: confirm all workflows visible and green.
3. Tag-and-release dry-run (using a beta tag) to verify the `release.yml` flow without publishing
   publicly.
4. Doc tests pass: every example in `docs/catalog/<category>.md` round-trips against the headless
   harness.

---

## 10.7 Schemes / data shapes

### 10.7.1 Release-notes auto-gen schema

Auto-generated from registry diffs:

- `Added tools`: list of new methods/tools.
- `Changed tools`: list with old vs new schema diff summary.
- `Removed tools`: list with `since` + `replacedBy`.
- `Added error codes`.
- `Performance highlights`: deltas from perf benchmarks.
- `Bug fixes`: from CHANGELOG.

### 10.7.2 CI artifact layout

```text
.github/artifacts/
  router-<version>.tgz
  addon-<version>.zip
  catalog-<version>.json
  parity-matrix-<version>.md
  perf-report-<version>.md
```

### 10.7.3 Documentation linking rule

All cross-file links inside `docs/` must be relative and validated by `docs.yml`. No links to live
URLs in source-of-truth pages unless they're official Godot or MCP SDK docs.

---

## 10.8 Tech stack delta vs `00 §0.10`

- Adds (optional) `xvfb` on Linux CI runners to allow editor-mode E2E.
- Adds dependency on `gh` CLI for release workflows (CI runner provides it).
- No new runtime dependencies.

---

## 10.9 Acceptance criteria

- [ ] Test pyramid (§10.6.1) in place with documented coverage per layer.
- [ ] Integration harness (§10.6.2) and fixtures present.
- [ ] Per-category integration tests written.
- [ ] E2E showcase scenario passes in CI.
- [ ] Performance benchmarks (§10.6.5) recorded; CI compares against baseline.
- [ ] CI workflows (§10.6.6) implemented; green on `main`.
- [ ] Versioning policy documented; release pipeline (§10.6.8) functional.
- [ ] Documentation site (§10.6.9) complete.
- [ ] Support matrix and security review present.
- [ ] FAQ and troubleshooting cover at least the top 10 issues identified in soak/chaos.
- [ ] Release readiness review (§10.6.16) passes.
- [ ] Decisions Log updated.

---

## 10.10 Verification plan

1. Run `tests/e2e/` locally end-to-end.
2. Push a beta tag; observe `release.yml` produces the expected artifacts on a draft release.
3. Spot-check every `docs/catalog/<category>.md` page renders correctly and links resolve.
4. Run the soak suite at least once before v1.0.
5. Have a second pair of eyes (human or agent) review the release notes.

---

## 10.11 Risks & mitigations

| Risk                                   | Mitigation                                                                                       |
| -------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Editor-mode E2E flakiness on Linux CI. | Pin Godot version; use xvfb; quarantine flaky tests with a TODO comment; never silently disable. |
| npm publish blocked by name collision. | Pre-verify name; choose `terravolt-godot-mcp` fallback.                                          |
| Godot Asset Library policy changes.    | Provide GitHub release zip as primary; Asset Library is secondary.                               |
| Performance regressions sneak in.      | `perf.yml` nightly; PR commenter; tagged "perf-watch" runs on big PRs.                           |
| Documentation drifts behind code.      | Auto-generated catalog & parity pages; `docs.yml` lint enforces presence.                        |
| Security report channel under-served.  | `SECURITY.md` defines disclosure email/process; respond within X business days.                  |
| Catalog version bump forgotten.        | CI check that compares registry hash against `catalog_version`.                                  |

---

## 10.12 Final handoff

When this file is complete:

- The product is **shipped**.
- Append a final entry to the Decisions Log in `00 §0.13`: "v1.0 released at \[date\];
  catalog_version = …; minimum Godot = …; minimum Node = …; supported OSs = …."
- Open issues for the v1.1 roadmap (§10.6.14).
- Schedule the first weekly maintenance pass per §10.6.17.

There is no `11`. After `10`, all further work happens through normal product change-management
(issues, PRs, releases) governed by these eleven files.

---

## Appendix A — Official Godot Docs alignment (added revision 2)

> Sourced from `tutorials/editor/command_line_tutorial.rst`, `tutorials/export/*`,
> `tutorials/scripting/c_sharp/*`, and `tutorials/io/data_paths.rst`. Concretizes CI matrix, release
> pipeline, and docs site against engine-truth.

### A.1 CI runner setup checklist

Godot binary acquisition per `command_line_tutorial.rst` §"Path":

- **Linux runners (Ubuntu)**: install Godot 4.x via official tarball or a third-party action (e.g.,
  `chickensoft-games/setup-godot@v2`). Export `TERRAVOLT_GODOT_BINARY=/usr/local/bin/godot4`.
- **Windows runners**: install via Scoop (`scoop bucket add extras; scoop install godot`) or
  download the official .zip. Add to PATH.
- **macOS runners**: install via Homebrew (`brew install godot`) or unzip the `.app` bundle; invoke
  `Godot.app/Contents/MacOS/Godot`.
- **Headless display**: not needed because `--headless` disables display driver; pure headless CI
  requires no xvfb when only headless ops run. Editor-mode E2E on Linux requires `xvfb-run` or a
  Wayland session.

### A.2 Test runner commands (canonical)

| Purpose                                 | Command                                                                                                                                                                    |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Lint GDScript syntax across the project | `godot --headless --check-only --script scripts/run_syntax_check.gd`                                                                                                       |
| Build C# solutions                      | `godot --headless --build-solutions --quit`                                                                                                                                |
| Run GUT or gdUnit4 tests                | `godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit` (GUT) or `godot --headless --script addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/` (gdUnit4) |
| Import all assets before export         | `godot --headless --import --path <project>`                                                                                                                               |
| Export release build                    | `godot --headless --path <project> --export-release "<preset>" <abs-output-path>`                                                                                          |
| Validate GDExtension API compatibility  | `godot --doctool --gdextension-docs --path <project>`                                                                                                                      |
| Benchmark engine boot                   | `godot --headless --benchmark --benchmark-file artifacts/godot-boot.json --quit-after 1`                                                                                   |

Wrap each in an npm script for consistency: `test:godot:syntax`, `test:godot:gut`,
`test:godot:gdunit`, `build:godot:export`, `bench:godot`.

### A.3 Export preset hygiene

Per `tutorials/export/exporting_projects.rst` and `tutorials/export/feature_tags.rst`:

- `export_presets.cfg` is **committed** to the repo's test fixtures
  (`tests/_fixtures/*/export_presets.cfg`).
- Each fixture defines presets used by `release.yml` and `e2e.yml`. Keep presets minimal: one debug,
  one release, per target platform exercised in CI.
- Export templates must be downloadable in CI. Cache them under
  `~/.local/share/godot/export_templates/<version>.<flavor>/` (Linux) or equivalent.
- `--install-android-build-template` is required before Android exports.

### A.4 Feature tags in CI

- Inject feature tags via the project's `application/config/custom_features` setting or per-preset.
- Test matrix includes runs with custom tags `terravolt_ci=true` so the addon can suppress unsafe
  ops (e.g., `headless.run_script` always-off) in CI.

### A.5 Doc generation pipeline

- `--doctool <path>` + `--no-docbase` writes API XML for the project's GDExtensions only (skip the
  base engine).
- `--gdscript-docs <path>` walks GDScript files and produces API reference (great for the addon's
  own public API).
- The doc site builder (`scripts/build-docs.mjs` planned) consumes:
  - `packages/shared/methods/registry.json` → `docs/catalog/`.
  - `packages/shared/errors/registry.json` → `docs/errors/index.md`.
  - `packages/shared/diagnostics/autoheal.json` → `docs/diagnostics/autoheal.md`.
  - GDScript docs output → `docs/api/gdscript/`.

### A.6 Release artifact contents (concrete)

Per `tutorials/export/exporting_pcks.rst` and `command_line_tutorial.rst`:

- The **addon zip** packs `packages/godot-mcp-addon/` verbatim and a `README.md` with mounting
  instructions (`addon:link`).
- The **router npm package** packs `dist/`, `package.json`, the bin entry, and a slim README.
- A **catalog snapshot JSON** (`catalog-<version>.json`) is included as a release asset so external
  tooling can introspect Terravolt's tool surface without installing the package.

### A.7 Self-contained mode for CI

Per `data_paths.rst` §"Self-contained mode":

- For hermetic CI builds, copy the Godot binary into the workspace, drop a `._sc_` sentinel next to
  it, and rely on `editor_data/` for all state. Eliminates pollution of the runner's home directory
  and aids reproducibility.

### A.8 Performance baselines (engine-anchored)

- Cold engine boot per `--benchmark` typically lands in 0.5–2 s depending on platform. Use this as
  the floor for Terravolt's `headless.start_project` SLA from `10 §10.6.5` (target < 5 s).
- `Engine.get_frames_per_second()` and `Performance.get_monitor(Performance.TIME_FPS)` provide the
  FPS reading used by `runtime.get_performance`.
- `Performance.MEMORY_STATIC_MAX` and `MEMORY_MESSAGE_BUFFER_MAX` reveal memory pressure during long
  sessions; track in the soak suite.

### A.9 Recovery Mode safeguard

- Per `command_line_tutorial.rst` Run Options: `--recovery-mode` disables plugins. The release notes
  and FAQ must remind users that Terravolt MCP is **disabled** under recovery mode and link to the
  documented workaround (open the editor normally to re-enable the plugin).

### A.10 Security review additions

- Terravolt's WebSocket listens loopback by default per `00 §A.1`/`03 §A.7`. Document the threat
  model: if `bind_address` is changed to `0.0.0.0`, _any_ process on the local network can connect —
  recommend pairing with `terravolt_mcp/security/require_token`.
- Logs may contain user-supplied content (script source from `script.set`, asset paths). Redaction
  profile defaults match `09 §A.4`.
- `headless.run_script` (arbitrary script execution) remains off by default; document the exact CLI
  flag (`--allow-arbitrary-scripts`) in `SECURITY.md`.

### A.11 Supported Godot version matrix (concrete)

- v1.0 supports Godot **4.x stable**, .NET-compatible build optional.
- CI exercises the latest stable (`N`) and the previous stable (`N-1`).
- Document expected drift in `docs/support-matrix.md`; deprecate `N-2` only with a minor release.

### A.12 GDScript / C# parity for tests

- GDScript projects: tests through GUT or gdUnit4.
- C# projects: `--build-solutions` then `dotnet test` if the project ships unit tests in
  xUnit/NUnit; Terravolt's `headless.run_tests` shells to the right command based on project
  detection.

### A.13 Risks added

| Risk                                                       | Mitigation                                                                                                                   |
| ---------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Export templates missing in CI ⇒ export job fails late.    | Pre-step in CI runs `godot --headless --import` and verifies export templates exist before any export.                       |
| `--build-solutions` cache invalidation on Windows runners. | Clean `.godot/mono/` between runs or pin the cache key to `godot --version`.                                                 |
| `xvfb-run` flakiness for editor-mode E2E on Linux.         | Prefer headless except for genuinely editor-only tests; quarantine flakies into a separate workflow with a label gate.       |
| Docs site builds slow on every PR.                         | `docs.yml` regenerates only when `packages/shared/` or `docs/` changes (path filter).                                        |
| Release notes drift from actual catalog.                   | `release.yml` diff registries between previous tag and current — fail if `catalog_version` not bumped while methods changed. |
| Self-contained mode forgotten on cloud agents.             | Bootstrap script for CI runners drops the `._sc_` sentinel automatically when running against a downloaded binary.           |
