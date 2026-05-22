# Packages

Terravolt ships two first-party artefacts:

| Package                                | Role                                                                                         |
| -------------------------------------- | -------------------------------------------------------------------------------------------- |
| [`mcp-server/`](mcp-server/)           | MCP stdio router (Node + TypeScript strict) bridging Cursor ⇄ Godot daemon + headless driver |
| [`godot-mcp-addon/`](godot-mcp-addon/) | Godot 4 `EditorPlugin`, WebSocket JSON-RPC daemon, logging to `user://mcp_log.txt`           |

Operational contracts + vocabulary live in **`docs/srs/`** and the executable checklist under
**`docs/tasklist/`**.

## NPM script canon (mirror of `docs/tasklist/01` §1.6.6)

| Script                        | What it runs                                                | Implemented | Notes                                              |
| ----------------------------- | ----------------------------------------------------------- | ----------- | -------------------------------------------------- |
| `lint`                        | ESLint `@terravolt/godot-mcp`                               | ✅          | Extend globs when new TS dirs appear               |
| `lint:fix`                    | ESLint `--fix`                                              | ✅          | Workspace alias                                    |
| `format`                      | Prettier repo-wide (`*.json`, `*.md`, `*.ts`, workflows, …) | ✅          | Honours `.prettierignore`                          |
| `format:check`                | Prettier `--check`                                          | ✅          | Runs in CI                                         |
| `typecheck`                   | `tsc --noEmit` (router pkg)                                 | ✅          |                                                    |
| `build:server`                | `tsc` emit `dist/`                                          | ✅          | MCP runtime wiring in **`05`**                     |
| `dev:server`                  | _planned stub_                                              | Planned     | Activated in **`05`** once watch mode wraps router |
| `test:server`                 | `node --test` scaffold                                      | ✅          | Expand in tasks `05` / `10`                        |
| `test:e2e`                    | placeholder                                                 | Planned     | **`10`** headless choreography                     |
| `intel:graphs`                | `scripts/regen-graphs.mjs`                                  | ✅          | `artifacts/js-graphs/` snapshot                    |
| `intel:gitnexus`              | `scripts/run-gitnexus.mjs` (`GITNEXUS_NO_GITIGNORE=1`)      | ✅          | `.gitnexus/` local outputs                         |
| `intel:graphify`              | Python `python -m graphify update .`                        | ✅          | Requires Graphify CLI on PATH                      |
| `omni:intel`                  | all `intel:*`                                               | ✅          | Use after structural doc/code edits                |
| `addon:link` / `addon:unlink` | placeholder                                                 | Planned     | **`02`**                                           |
| `release`                     | placeholder                                                 | Planned     | **`10`**                                           |

If a helper is absent from `package.json`, treat it as **non-existent**.

## References

- [`docs/srs/README.md`](../docs/srs/README.md) — product blueprint bundle.
- [`docs/tasklist/00-foundation-and-contracts.md`](../docs/tasklist/00-foundation-and-contracts.md)
  — non-negotiable contracts.
- [`docs/tasklist/01-repository-and-tooling-setup.md`](../docs/tasklist/01-repository-and-tooling-setup.md)
  — Pre-Phase&nbsp;1 completion record.
