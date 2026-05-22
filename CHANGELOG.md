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

### Security

- `SECURITY.md` expanded with §10 threat-model notes for loopback default,
  optional token auth, arbitrary-script gating, and log redaction.

## 0.1.0 — initial scaffold

Initial monorepo skeleton, MCP router + Godot addon Phase 1, shared catalog
plumbing, Graphify/GitNexus intel, docs `00` – `09` mirrored from the SRS.
