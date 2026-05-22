# Packages

Terravolt ships two first-party artefacts:

| Package                                | Role                                                                                         |
| -------------------------------------- | -------------------------------------------------------------------------------------------- |
| [`mcp-server/`](mcp-server/)           | MCP stdio router (Node + TypeScript strict) bridging Cursor ⇄ Godot daemon + headless driver |
| [`godot-mcp-addon/`](godot-mcp-addon/) | Godot 4 `EditorPlugin`, WebSocket JSON-RPC daemon, logging to `user://mcp_log.txt`           |

Operational contracts + vocabulary live in **`docs/srs/`** and the executable checklist under
**`docs/tasklist/`**.

## NPM script canon (mirror of `docs/tasklist/01` §1.6.6)

| Script                        | What it runs                                                | Implemented | Notes                                                                            |
| ----------------------------- | ----------------------------------------------------------- | ----------- | -------------------------------------------------------------------------------- |
| `lint`                        | ESLint `@terravolt/godot-mcp`                               | yes         | Extend globs when new TS dirs appear                                             |
| `lint:fix`                    | ESLint `--fix`                                              | yes         | Workspace alias                                                                  |
| `format`                      | Prettier repo-wide (`*.json`, `*.md`, `*.ts`, workflows, …) | yes         | Honours `.prettierignore`                                                        |
| `format:check`                | Prettier `--check`                                          | yes         | Runs in CI                                                                       |
| `typecheck`                   | `tsc --noEmit` (router pkg)                                 | yes         |                                                                                  |
| `build:server`                | `tsc` emit `dist/`                                          | yes         | Phase **`05`** router entry `dist/index.js`                                      |
| `catalog:sync`                | `scripts/catalog-sync.mjs` (registry → Godot `_generated/`) | yes         | Run after editing `packages/shared/methods/registry.json`                        |
| `env:godot`                   | `scripts/setup-godot-env.mjs`                               | yes         | Detect Godot 4 binary, write `.terravolt/godot-env.json`                         |
| `release:notes`               | `scripts/release-notes.mjs`                                 | yes         | Diff registries against previous tag                                             |
| `release:check`               | `scripts/release-check.mjs`                                 | yes         | 5/5 gate: hash, version, error mirror, readiness doc, CHANGELOG                  |
| `dev:server`                  | `node scripts/planned.mjs dev:server` (stub)                | Planned     | File watcher optional; `build:server` + node `dist/` suffices for MCP            |
| `test:server`                 | `node --test` in `@terravolt/godot-mcp`                     | yes         | 11 tests: smoke (2), unit (6), real-Godot integration (3)                        |
| `test:e2e`                    | placeholder                                                 | Planned     | **`10`** headless choreography (once §08 catalog ships)                          |
| `intel:graphs`                | `scripts/regen-graphs.mjs`                                  | yes         | `artifacts/js-graphs/` snapshot                                                  |
| `intel:gitnexus`              | `scripts/run-gitnexus.mjs` (`GITNEXUS_NO_GITIGNORE=1`)      | yes         | `.gitnexus/` local outputs                                                       |
| `intel:graphify`              | Python `python -m graphify update .`                        | yes         | Requires Graphify CLI on PATH                                                    |
| `omni:intel`                  | all `intel:*`                                               | yes         | Use after structural doc/code edits                                              |
| `addon:link` / `addon:unlink` | `scripts/addon-link.mjs` (symlink/copy into dev project)    | yes         | `TERRAVOLT_GODOT_PROJECT` or `~/.terravolt-mcp-dev.json`; see `docs/tasklist/02` |
| `release`                     | placeholder                                                 | Planned     | **`10`**                                                                         |

If a helper is absent from `package.json`, treat it as **non-existent**.

## References

- [`docs/srs/README.md`](../docs/srs/README.md) — product blueprint bundle.
- [`docs/tasklist/00-foundation-and-contracts.md`](../docs/tasklist/00-foundation-and-contracts.md)
  — non-negotiable contracts.
- [`docs/tasklist/01-repository-and-tooling-setup.md`](../docs/tasklist/01-repository-and-tooling-setup.md)
  — Pre-Phase&nbsp;1 completion record.
