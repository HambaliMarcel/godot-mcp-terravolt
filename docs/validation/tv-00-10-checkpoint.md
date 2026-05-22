# Tasklist TV-00–10 validation checkpoint

**Canonical docs:** `docs/tasklist/00*.md` … `10-quality-testing-release-and-docs.md`

## Automated checks (2026-05-22, refreshed with **real Godot 4.6.3 stable mono**)

Run from repo root (`npm install` once):

| Command | Expect |
|---------|--------|
| `npm run lint` | Pass |
| `npm run typecheck` | Pass |
| `npm run build:server` | Pass |
| `npm run test:server` | Pass — **11 tests**: CLI smoke (2), router unit (6), **headless integration (1, real Godot)**, **MCP stdio E2E (1, real Godot)**, **addon parse-check (1, real Godot `--import`)**. |
| `npm run catalog:sync` | Pass (`packages/godot-mcp-addon/_generated/catalog_meta.gd`) |
| `npm run env:godot` | Pass (writes `.terravolt/godot-env.json`; auto-detects Mono build). |
| `npm run release:check` | Pass (5/5 gates: hash, version, error mirror, readiness doc, CHANGELOG). |
| `npm run release:notes` | Pass (diff vs previous tag, fallback to initial when no tag exists). |

### Real Godot interaction verified end-to-end

`packages/mcp-server/tests/integration/mcp_e2e.test.mjs` spawns the
compiled router via `@modelcontextprotocol/sdk` `StdioClientTransport`
and exercises:

1. MCP `tools/list` — confirms all 12 expected tools (`ping`,
   `server.info`, `log.tail`, `tools.{list,describe,metrics,bottlenecks,health}`,
   `context.fetch_raw`, `headless.{start_project,status,stop,validate_script}`).
2. `headless.start_project` → boots **real `Godot_v4.6.3-stable_mono_win64`**
   from `%LOCALAPPDATA%\Programs\Godot\…` against
   `tests/_fixtures/empty/project.godot`, parses the TCP port from stderr,
   returns live `pid`/`port`/`uptimeMs`.
3. `headless.validate_script` → JSON-RPC `script.validate_syntax` on a
   tiny `.gd` snippet generated in the fixture (round-trip with the
   driver's `GDScript.new()` → `reload()` path).
4. `ping` (daemon-bridged tool) → WS handshake fails (port `1`, no daemon),
   falls back to headless coordinator, returns
   `{ ok: true, method: "ping@headless" }` in `<200 ms`.
5. `headless.stop` → driver exits cleanly.

`packages/mcp-server/tests/integration/addon_parse.test.mjs` stages the
addon as `tests/_fixtures/with-addon/addons/terravolt_mcp/` and runs
`godot --headless --import --path <fixture>` which triggers the full
project compile pass — zero `SCRIPT ERROR: Parse Error:` lines required.

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

## Findings during the real-MCP smoke (2026-05-22 follow-up)

Driving the compiled router through `@modelcontextprotocol/sdk` (instead of
testing internal modules in-process) surfaced three real bugs that no other
test caught — they are now fixed:

- **Windows crash on bootstrap (`-router-only` regression).** `packages/mcp-server/src/catalog/loadRegistry.ts` called `resolveMethodRegistryJsonPath(fileURLToPath(import.meta.url))` and the helper then ran `fileURLToPath` again. On Windows the second call sees a path like `H:\…` and throws `ERR_INVALID_URL_SCHEME`. Fixed by passing `import.meta.url` directly; both helpers (`catalog/repoRoot.ts` and `headless/resolveTerravoltRoot.ts`) now also tolerate plain absolute paths defensively.
- **`error_codes.gd` parser failure under real Godot 4.6.** GDScript 4 does **not** accept multi-line patterns inside `match` arms; the existing `category_for(tv_code)` ladder failed with `Expected expression for match pattern`. Replaced both lookup helpers with a single `_CODE_TO_SYMBOL` Dictionary — fewer lines, no `match`, parses on every supported Godot 4.x.
- **`logging.gd` referenced a non-existent API.** `FileAccess.get_file_size(path)` does not exist as a static method in Godot 4.6 (cf. `references/godot-docs/classes/class_fileaccess.rst`). Replaced with `FileAccess.open(... READ).get_length()`.
- **`json_schema_mini.gd` type inference.** `var it := schema["items"]` failed strict typing (Dictionary indexing returns `Variant`). Now `var it: Variant = …`.

A new headless `--import` fixture (`tests/_fixtures/with-addon/`) plus
`tests/integration/addon_parse.test.mjs` guards against regressions of any
of the GDScript-side bugs above.

## Documentation tier (2026-05-22 v4 doc refresh)

The user-facing documentation was finalized against the verified state of
the codebase:

- Root `README.md` rewritten as the product entry — quick start, "why",
  guide index, status table.
- `docs/README.md` re-indexed into Guides / Status & release /
  Architecture / Execution / Contributing sections.
- New `docs/guides/tools-reference.md` — authoritative reference for all
  12 registered MCP tools (inputs, results, errors).
- New `docs/guides/mcp-usage.md` — concrete `tools/call` payloads per
  tool + a Node SDK example that mirrors `mcp_e2e.test.mjs`.
- New `docs/guides/godot-integration.md` — editor vs headless connection
  flow (ASCII diagram) + verification matrix.
- `docs/guides/quick-start.md`, `headless-only.md`, `troubleshooting.md`
  refreshed for test counts, new errors found, and cross-links.
- `packages/**/README.md` updated to today's flag/env-var/tool list.
- `docs/release/v1-readiness.md` "Documentation site builds clean" gate
  flipped from "In progress" to "Yes".

## Manual / CI gap

Editor-mode E2E (`xvfb-run` on Linux, real editor on Windows/macOS)
remains out of scope until §08 ships category implementations.

See also **`docs/catalog/parity.md`** and
**`docs/release/v1-readiness.md`**.
