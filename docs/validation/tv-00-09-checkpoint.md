# Tasklist TV-00–09 validation checkpoint

**Canonical docs:** `docs/tasklist/00*.md` … `09-context-and-error-optimization.md`

## Automated checks (2026-05-22)

Run from repo root (`npm install` once):

| Command | Expect |
|---------|--------|
| `npm run lint` | Pass |
| `npm run typecheck` | Pass |
| `npm run build:server` | Pass |
| `npm run test:server` | Pass (CLI smoke: `--version`, `--print-config`) |
| `npm run catalog:sync` | Pass (`packages/godot-mcp-addon/_generated/catalog_meta.gd`) |

## Per-task rollup (truthful)

| ID | Topic | Repo status |
|----|-------|--------------|
| 00–01 | Foundation, repo & tooling | Aligned with tasklists; Phase 1 entry criteria documented. |
| 02–04 | Godot plugin + WS + JSON-RPC daemon | Implemented under `packages/godot-mcp-addon/`. |
| 05–06 | Node MCP router + shared catalog | Implemented under `packages/mcp-server/`, `packages/shared/methods/registry.json`. |
| **07** | Headless fallback | **Partial:** `--headless` TCP driver (`headless_driver.gd`), router coordinator (`packages/mcp-server/src/headless/*`), MCP `headless.*` tools, and WS-down fallback when `headlessFallback: true`. Full parity (export, import, test runner, allowlists per spec) remains. |
| **08** | ~200-method catalog | **Not started** at catalog scale; spec is backlog until categories ship iteratively. |
| **09** | Context / errors / telemetry | **Partial:** rolling `tools.metrics`, `tools.bottlenecks`, `context.fetch_raw`, optional **`autoHeal`** hints on bridged daemon errors (`packages/shared/diagnostics/autoheal.json`), **`--disable-auto-heal`**. Daemon context envelopes (`envelope`), SLA budgets, and batch fusion are **not** implemented yet. |

## Manual / CI gap

Godot `--headless` spawn + TCP handshake is environment-dependent (binary path, project path); not exercised in default `npm run test:server`.

See also **`docs/catalog/parity.md`** for editor vs headless method parity.
