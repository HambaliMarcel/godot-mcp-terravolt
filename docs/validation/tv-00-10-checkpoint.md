# Tasklist TV-00–10 validation checkpoint

**Canonical docs:** `docs/tasklist/00*.md` … `10-quality-testing-release-and-docs.md`

## Automated checks (2026-05-22, refreshed)

Run from repo root (`npm install` once):

| Command | Expect |
|---------|--------|
| `npm run lint` | Pass |
| `npm run typecheck` | Pass |
| `npm run build:server` | Pass |
| `npm run test:server` | Pass — 9 tests: CLI smoke (2), router unit (6), **headless integration (1, real Godot)**. |
| `npm run catalog:sync` | Pass (`packages/godot-mcp-addon/_generated/catalog_meta.gd`) |
| `npm run env:godot` | Pass (writes `.terravolt/godot-env.json`; auto-detects Mono build). |
| `npm run release:check` | Pass (5/5 gates: hash, version, error mirror, readiness doc, CHANGELOG). |
| `npm run release:notes` | Pass (diff vs previous tag, fallback to initial when no tag exists). |

## Per-task rollup (truthful)

| ID | Topic | Repo status |
|----|-------|--------------|
| 00–01 | Foundation, repo & tooling | Aligned with tasklists. |
| 02–04 | Godot plugin + WS + JSON-RPC daemon | Implemented under `packages/godot-mcp-addon/`. |
| 05–06 | Node MCP router + shared catalog | Implemented under `packages/mcp-server/`, `packages/shared/methods/registry.json`. |
| **07** | Headless fallback | **Foundation complete, surface partial.** TCP driver (`headless_driver.gd`) is now **self-contained** (env-driven catalog meta, peer re-accept across RPC calls — discovered + fixed in this sweep). Router coordinator spawns Godot from `%LOCALAPPDATA%\Programs\Godot\**`. Integration test exercises `ping` + `server.info` over real Godot. Backlog: `export`, `import_assets`, `run_tests`, full allowlists. |
| **08** | ~200-method catalog | **Not started.** Catalog is intentionally bootstrap-sized; expand category-by-category per §08. |
| **09** | Context / errors / telemetry | **Partial.** `tools.bottlenecks`, `context.fetch_raw`, optional `autoHeal` shipped. Envelopes / SLA budgets / batch fusion / `ifMatch` still backlog. |
| **10** | QA, release, docs | **Foundation complete.** `unit.yml` + `release.yml` workflows, `release:check` gate, `release:notes` generator, support matrix, FAQ, troubleshooting, security threat model, v1 readiness checklist, CHANGELOG. Integration / E2E showcase pending §08 surface. |

## Findings during the §10 sweep

- **Bug fix (§07):** the headless driver previously `preload("../error_codes.gd")` which fails when launched against a project that does not mount the addon (Godot resource loader can’t resolve outside `res://`). Driver is now self-contained; catalog meta arrives through `TERRAVOLT_CATALOG_VERSION` and `TERRAVOLT_REGISTRY_SHA256` env vars injected by `launchHeadlessDriver`.
- **Bug fix (§07):** the driver previously `_stop=true` on first peer disconnect, killing subsequent RPCs. Replaced with `_peer=null` + re-accept loop. Validated by `tests/integration/headless.test.mjs`.
- **Path migration:** Godot 4.6.3 Mono moved from `C:\Users\marce\Downloads\…` to `%LOCALAPPDATA%\Programs\Godot\Godot_v4.6.3-stable_mono_win64\`. Router resolver and `setup-godot-env.mjs` scan that location and prefer the `_console.exe` variant.

## Manual / CI gap

Editor-mode E2E (`xvfb-run` on Linux, real editor on Windows/macOS) remains out of scope until §08 ships category implementations.

See also **`docs/catalog/parity.md`** and **`docs/release/v1-readiness.md`**.
