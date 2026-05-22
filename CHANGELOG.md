# Changelog

All notable changes to TerraVolt Godot MCP. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the project follows
[Semantic Versioning](https://semver.org/).

The shared method catalog tracks its own `catalog_version` inside
`packages/shared/methods/registry.json` and is bumped according to the rules in
`docs/tasklist/10 §10.6.7`.

## [Unreleased]

### Added

- **§07** Headless Godot fallback: TCP-backed `headless_driver.gd`,
  `HeadlessCoordinator`, MCP tools `headless.start_project`, `headless.stop`,
  `headless.status`, `headless.validate_script`. WebSocket-down fallback for
  registry rows with `headlessFallback: true` (currently `ping`, `server.info`).
- **§09** Router-only telemetry tools `tools.bottlenecks`, `context.fetch_raw`,
  and optional `autoHeal` hints on bridged daemon errors backed by
  `packages/shared/diagnostics/autoheal.json` (disabled with
  `--disable-auto-heal`).
- **§10** Release-engineering scripts: `npm run env:godot`,
  `npm run release:notes`, `npm run release:check`. CI workflows
  `unit.yml`, `release.yml` reserved/implemented; `lint.yml` retained.
  Documentation: `docs/guides/quick-start.md`, `docs/guides/headless-only.md`,
  `docs/guides/troubleshooting.md`, `docs/support-matrix.md`,
  `docs/release/v1-readiness.md`.
- **§07** Stable application error codes `-33810` … `-33817` mirrored in
  `packages/godot-mcp-addon/error_codes.gd` and
  `packages/shared/errors/registry.json`.

### Changed

- `packages/shared/methods/registry.json` `catalog_version` → `0.2.0`.
- `resolveGodotBinary` now scans `%LOCALAPPDATA%\Programs\Godot\**`,
  `%USERPROFILE%\Tools\Godot\**`, `C:\Program Files\Godot`, and `C:\Tools\Godot`
  on Windows; prefers the `_console.exe` variant for stable stderr capture.

### Fixed

- **Windows bootstrap crash:** `packages/mcp-server/src/catalog/loadRegistry.ts`
  double-decoded `import.meta.url` (calling `fileURLToPath` twice), raising
  `ERR_INVALID_URL_SCHEME` on every router spawn because Windows paths
  (`H:\…`) are parsed as URL scheme `h:`. Helpers now accept either a
  `file://` URL or an already-decoded absolute path.
- **`error_codes.gd` parse error in Godot 4.6:** multi-line `match` patterns
  (`A,\n B,\n C:`) are not valid GDScript. Replaced both `category_for`
  and `symbol_for` ladders with a single `_CODE_TO_SYMBOL` Dictionary.
- **`logging.gd` log rotation:** `FileAccess.get_file_size(path)` does not
  exist as a static method in Godot 4.6 (verified against
  `references/godot-docs/classes/class_fileaccess.rst`). Now opens the
  file in READ mode and uses `get_length()`.
- **`json_schema_mini.gd` strict typing:** `var it := schema["items"]`
  could not infer a type from a Variant dictionary access; now explicit
  `var it: Variant = …`.

### Verified end-to-end (real Godot 4.6.3 stable mono)

- `tests/integration/mcp_e2e.test.mjs` drives the compiled router via
  the official MCP TypeScript SDK over stdio and confirms `tools/list`,
  `headless.start_project`, `headless.validate_script`,
  `headless.status`, `headless.stop`, and WS-down → headless fallback for
  `ping` (route reported as `ping@headless`).
- `tests/integration/addon_parse.test.mjs` stages the addon into
  `tests/_fixtures/with-addon/` and runs `godot --headless --import` to
  confirm every `.gd` file parses cleanly with `class_name` resolution.

### Security

- `SECURITY.md` expanded with §10 threat-model notes for loopback default,
  optional token auth, arbitrary-script gating, and log redaction.

## 0.1.0 — initial scaffold

Initial monorepo skeleton, MCP router + Godot addon Phase 1, shared catalog
plumbing, Graphify/GitNexus intel, docs `00` – `09` mirrored from the SRS.
