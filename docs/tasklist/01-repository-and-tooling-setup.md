# 01 — Repository & Tooling Setup (Pre-Phase 1 finalization)

> **Goal**: bring the monorepo from "docs only" to "fully ready to host Phase 1 code." No product
> code yet. Only repo structure, tooling, scripts, linting, formatting, intel pipelines, and CI
> placeholders.

---

## 1.1 Header

- **File:** `01-repository-and-tooling-setup.md`
- **Purpose:** lock down the monorepo skeleton, dev tooling, and automation so that Phase 1
  (`02`–`04`) starts on solid ground.

## 1.2 Phase placement

- Foundation phase (pre-Phase 1).
- Gates: must be complete **before** anything in `02-godot-plugin-foundation.md` is started.
- Does **not** ship product code; ships only structure and tooling.

## 1.3 Inputs / prerequisites

- `00-foundation-and-contracts.md` fully internalized.
- Decisions Log (0.13) updated to "Foundation locked."
- Local Godot 4.x installed (any recent stable; exact version pinned in `02`).
- Node.js 20 LTS installed.
- Git configured per the existing repo `.githooks/`.

## 1.4 Outputs / what this file produces

When complete the repo will have:

1. A confirmed, documented top-level layout (no surprises).
2. Two **empty-but-claimed** package directories: `packages/godot-mcp-addon/` and
   `packages/mcp-server/`, each with a stub `README.md` and a placeholder for required manifests.
3. A working **TypeScript project** scaffold under `packages/mcp-server/` (manifest, tsconfig, lint,
   format, test runner) **without** any source files yet.
4. A working **Godot addon scaffold target** under `packages/godot-mcp-addon/` (with the manifest
   _plan_, not the manifest itself — that's in `02`).
5. Root-level dev tooling: lint, format, Husky/`.githooks` integration, `dependency-cruiser` config
   (already present, audited), `Graphify`/`GitNexus` refresh wiring (already present, audited), and
   Prettier baseline.
6. CI placeholders: workflow files in `.github/workflows/` that lint and (later) test, but do not
   yet build product code.
7. A single canonical `npm run` task table documented in `packages/README.md` and
   `scripts/README.md`.

---

## 1.5 Operating constants used

This file does **not** introduce new constants. It references those locked in
`00-foundation-and-contracts.md` §0.3 (Node ≥ 20, TS strict, port `6505`, log sink
`user://mcp_log.txt`, etc.).

---

## 1.6 Detailed task breakdown

### 1.6.1 Audit current repo state

Before changing anything:

1. List every top-level entry and confirm it matches `docs/repo-layout.md`.
2. Confirm `references/` contains the four expected clones (`godot-mcp-pro`, `godot-mcp-tomyud1`,
   `godot-mcp-coding-solo`, `godot-docs`) and is gitignored.
3. Confirm `.gitnexus/`, `node_modules/`, `graphify-out/cache/` are gitignored.
4. Confirm `packages/godot-mcp-addon/` and `packages/mcp-server/` exist (even if empty beyond
   `README.md`).
5. Read `package.json`, `package-lock.json`, and every script under `scripts/`. Build a mental table
   of what each script does. Record any duplicates or dead scripts to be pruned in a follow-up.
6. Read `.cursor/rules/*.mdc`, `.cursor/workflows/*.md`, and `AGENTS.md` / `CLAUDE.md`. These are
   the agent guardrails. Note any rule that constrains how Phase 1 should be coded (e.g., must use
   GitNexus impact analysis before edits).

**Deliverable:** a short, in-memory audit summary the agent uses to drive the rest of this file.
Nothing is written to disk in this step.

### 1.6.2 Lock the canonical top-level layout

The layout is already correct on disk; this step is verification + documentation only:

| Path                                                                                                          | Status target                                                    |
| ------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `packages/godot-mcp-addon/`                                                                                   | exists, has `README.md`, no source yet.                          |
| `packages/mcp-server/`                                                                                        | exists, has `README.md`, no source yet.                          |
| `packages/README.md`                                                                                          | summarizes both packages, references SRS and task list.          |
| `docs/`                                                                                                       | unchanged structure; this task list lives in `docs/tasklist/`.   |
| `scripts/`                                                                                                    | kept; only audit and document, do not delete unfamiliar scripts. |
| `config/`                                                                                                     | kept; e.g. `dependency-cruiser` config lives here.               |
| `artifacts/js-graphs/`                                                                                        | kept as the commit-safe intel snapshot.                          |
| `graphify-out/`                                                                                               | kept; cache subdir gitignored.                                   |
| `references/`                                                                                                 | gitignored; never edited.                                        |
| `.cursor/`, `.claude/`, `.githooks/`, `.gitnexus/`, `.github/`                                                | kept; audited but not restructured here.                         |
| `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `LICENSE`, root `README.md` | kept; spot-check that they still match this task list.           |

If anything is missing, **create the empty directory with a `README.md`** describing its purpose; do
not create source files yet.

### 1.6.3 Bootstrap the Node MCP router package skeleton

Under `packages/mcp-server/`:

1. **Manifest plan.** Define what the `package.json` will contain _conceptually_. No file is
   committed in this step; just record the plan:
   - **Name:** to be finalized in `05`. Reserve a placeholder like `@terravolt/godot-mcp` (final
     name decision logged in `00`'s Decisions Log if it changes).
   - **Type:** ESM.
   - **Engines:** Node `>=20`.
   - **Bin:** future MCP server entrypoint; declared in `05`.
   - **Dependencies (to be added in `05`):** `@modelcontextprotocol/sdk`, `ws`, a small JSON Schema
     validator (e.g., `ajv`), maybe a logger (decision in `05`).
   - **DevDependencies (added now, not later):** `typescript`, `@types/node`, `eslint` + TS plugin,
     `prettier`, `vitest`-or-`node --test` (pick one; record in `05`).
   - **Scripts table:** `build`, `lint`, `lint:fix`, `format`, `format:check`, `test`, `dev`,
     `typecheck`. Names final; behavior implemented later.
2. **Folder skeleton plan** (do not create source files yet):
   - `src/` — to host Router source in `05`.
   - `src/tools/` — to host tool modules in `06`/`08`.
   - `src/transport/` — to host WS client and stdio MCP setup in `05`.
   - `src/jsonrpc/` — to host JSON-RPC framing & dispatch helpers in `05`.
   - `src/headless/` — to host headless fallback driver in `07`.
   - `src/diagnostics/` — to host error mapping in `09`.
   - `tests/` — integration & smoke tests, scaffolded in `10`.
3. **TS config plan:** strict, ESM, `moduleResolution: "nodenext"`, isolated modules, no implicit
   any, `noUncheckedIndexedAccess`. Final file written in `05`.
4. **Lint plan:** ESLint with TS plugin, `import/order` rule, no `console.log` to stdout in source
   (custom rule placeholder; final policing in `05`).
5. **Format plan:** Prettier with project-wide config (root-level, see 1.6.5).

**Deliverable:** an updated `packages/mcp-server/README.md` describing the package's _intent_ (and
pointing at `05` for actual coding).

### 1.6.4 Bootstrap the Godot addon package skeleton (plan only)

Under `packages/godot-mcp-addon/`:

1. **Manifest plan** (`plugin.cfg`, to be written in `02`):
   - Plugin name, description, author, version, script entry pointing at the `EditorPlugin` script.
2. **Folder skeleton plan** (created lazily as `02`–`04` need them):
   - `main.gd` (EditorPlugin entrypoint).
   - `mcp_server.gd` (WebSocket daemon).
   - `dispatcher.gd` (JSON-RPC dispatcher).
   - `handlers/` (one file per category, populated in `08`).
   - `logging.gd` (single log subsystem, writing to `user://mcp_log.txt`).
   - `schemas/` (optional — embedded JSON Schemas for daemon-side validation).
   - `editor_ui/` (optional dock; addressed late in `02` or in a polish phase).
3. **Dev project plan.** A _separate_ throwaway Godot project (not committed) will host the addon
   during development via a symlink or copy. Document the workflow:
   - Where the dev project lives on the developer's machine (under their `~/Documents/`-equivalent).
   - How the addon is mounted: prefer **symlink** so edits propagate; if symlinks are unsupported,
     document copy + watch script.
   - How to verify the addon is enabled (`Project Settings → Plugins`).
4. **GDScript style guide.** Adopt **Godot's official GDScript style guide** verbatim. Document a
   one-page summary in `packages/godot-mcp-addon/README.md` once `02` starts; in this file just note
   the choice.

**Deliverable:** an updated `packages/godot-mcp-addon/README.md` describing the addon's _intent_
(and pointing at `02`–`04` for actual coding).

### 1.6.5 Root-level tooling

These pieces are repo-wide. Most already exist; audit and align.

1. **Prettier** — root config. Define line width, trailing commas, semi, quote style. Applies to TS,
   JSON, MD. (GDScript not formatted by Prettier — it has its own formatter inside Godot.)
2. **EditorConfig** — root `.editorconfig` already typical; if missing, add. Enforces UTF-8, LF,
   final newline, tab/space policy per language.
3. **ESLint** — root config or per-package; recommend per-package under `packages/mcp-server/` and a
   root config that defers to package configs.
4. **`dependency-cruiser`** — confirm `config/` contains a working config; document expected
   invocation via npm scripts.
5. **`Graphify`** — confirm `.graphifyignore` excludes `references/godot-docs/`, `node_modules/`,
   generated dirs, and the `references/` clones that don't need indexing.
6. **`GitNexus`** — confirm `.gitnexusignore` mirrors the same exclusion intent; confirm
   `scripts/run-gitnexus.mjs` (or equivalent) sets `GITNEXUS_NO_GITIGNORE=1` so MCP reference clones
   are indexed.
7. **Husky / `.githooks`** — audit existing hooks. Pre-commit should run **lint** and **format
   check** on staged files (TS at minimum). Pre-push placeholder for tests; finalize in `10`.
8. **`.gitignore`** — confirm it covers: `node_modules/`, `references/`, `.gitnexus/`,
   `graphify-out/cache/`, `dist/`, `build/`, `*.log`, `.DS_Store`, OS junk, IDE caches.
9. **`AGENTS.md` / `CLAUDE.md` / `.cursor/rules/`** — read again with the new task list in mind. If
   any rule contradicts a contract in `00`, add an issue note in the Decisions Log (0.13) flagging
   the contradiction; do not silently change rules.

### 1.6.6 NPM script table (canonical)

Document this table in `packages/README.md` and `scripts/README.md`. Scripts not yet implemented are
marked **\[planned\]**.

| Script           | What it does                                                                         | Where implemented             | Status          |
| ---------------- | ------------------------------------------------------------------------------------ | ----------------------------- | --------------- |
| `lint`           | Run ESLint over `packages/mcp-server` (and any future TS code).                      | root or `packages/mcp-server` | live or planned |
| `lint:fix`       | Auto-fix ESLint issues.                                                              | same                          | planned         |
| `format`         | Run Prettier across the repo.                                                        | root                          | live/planned    |
| `format:check`   | Verify Prettier compliance.                                                          | root                          | planned         |
| `typecheck`      | `tsc --noEmit` in router.                                                            | `packages/mcp-server`         | planned (05)    |
| `build:server`   | Compile router TS.                                                                   | `packages/mcp-server`         | planned (05)    |
| `dev:server`     | Run router in watch mode against a running daemon.                                   | `packages/mcp-server`         | planned (05)    |
| `test:server`    | Run router test suite.                                                               | `packages/mcp-server`         | planned (10)    |
| `test:e2e`       | Spin up Godot headless + router + canned MCP client.                                 | root                          | planned (10)    |
| `intel:gitnexus` | Re-index GitNexus.                                                                   | `scripts/run-gitnexus.mjs`    | live            |
| `intel:graphs`   | Re-emit `artifacts/js-graphs/*.json`.                                                | `scripts/run-graphs.mjs`      | live            |
| `intel:graphify` | Re-emit `graphify-out/*`.                                                            | `scripts/run-graphify.mjs`    | live            |
| `omni:intel`     | Run all `intel:*` scripts.                                                           | root                          | live            |
| `addon:link`     | Symlink/copy `packages/godot-mcp-addon` into a configured Godot project's `addons/`. | `scripts/link-addon.*`        | planned (02)    |
| `addon:unlink`   | Remove the symlink/copy.                                                             | same                          | planned (02)    |
| `release`        | Versioning + tagging + changelog.                                                    | TBD                           | planned (10)    |

**Rule:** every npm script must have an entry here; if not listed, it doesn't exist. This avoids the
"secret script" problem.

### 1.6.7 CI placeholders

Under `.github/workflows/`:

1. **`lint.yml`** — runs ESLint and Prettier check on PRs. Should _pass even when no source is
   present yet_ (lint on the eventual TS files, no-op gracefully if zero matches).
2. **`docs-check.yml`** — verifies all internal links in `docs/` resolve. Helpful given how many
   cross-links this task list will have.
3. **`intel-check.yml`** _(optional)_ — runs `omni:intel` in dry-run mode to confirm tooling is
   healthy. May be deferred to `10`.
4. **`test.yml`** _(placeholder)_ — wired in `10`; in this phase, create an empty workflow file with
   a "TODO: enable when tests land" comment to reserve the path.
5. **`build.yml`** _(placeholder)_ — wired in `10`.

**Rule for placeholders:** they must exist as files with valid YAML so they appear in the GitHub UI,
but they may no-op.

### 1.6.8 Documentation alignment

Update or confirm:

1. `docs/README.md` — points at SRS, architecture overview, and **this task list**
   (`docs/tasklist/`).
2. `docs/repo-layout.md` — mentions `docs/tasklist/` as a top-level docs section.
3. `docs/architecture/overview.md` — already references the SRS and reference map; add a one-line
   pointer to `docs/tasklist/` as the "execution plan."
4. `docs/context/context-map.md` — append `docs/tasklist/` to the "Suggested order when loading
   context" list, between "SRS" and "Product intent."
5. `AGENTS.md` (and the analogous `CLAUDE.md`) — append a one-paragraph note: "When implementing
   TerraVolt MCP, follow `docs/tasklist/00`–`10` in order. Do not skip phase gates."
6. `packages/README.md` — point at `docs/tasklist/` and the SRS.

### 1.6.9 Reference indexing freshness

1. Run `npm run intel:gitnexus` (or `omni:intel`) to ensure references are indexed.
2. Confirm via the GitNexus context resource that the four reference clones appear with non-zero
   symbol counts.
3. Confirm `references/godot-docs/` is **not** indexed (per `.gitnexusignore`).
4. Spot-check by querying GitNexus for `websocket` against `references/godot-mcp-tomyud1/`; expect
   hits.

### 1.6.10 Dev environment doctor (manual checklist)

Document a short "doctor" checklist in `scripts/README.md` (or under a new
`scripts/doctor/README.md`) that the agent runs before each new phase:

- Node version ≥ 20.
- Godot 4.x present on PATH (`godot --version` returns a 4.x string).
- `npm install` completes without errors at repo root.
- `npm run lint` exits 0.
- `npm run format:check` exits 0.
- `npm run omni:intel` exits 0.
- The Godot dev project (for the addon) is configured and the symlink/copy of
  `packages/godot-mcp-addon/` is current.

This step does **not** create code yet. It just produces or updates the doctor checklist doc.

---

## 1.7 Schemes / data shapes (no code)

### 1.7.1 Repository skeleton (target after this file)

```text
packages/
  mcp-server/
    README.md          (intent, points to 05)
    package.json       (ESM scaffold; MCP deps deferred to task 05)
    tsconfig.json      (strict nodenext; build tsconfig emits dist/)
    eslint.config.mjs
    src/               (routing folders + scaffold health stub)
  godot-mcp-addon/
    README.md          (intent, points to 02)
    [planned] plugin.cfg
    [planned] main.gd
    [planned] mcp_server.gd
    [planned] dispatcher.gd
    [planned] logging.gd
    [planned] handlers/
docs/
  tasklist/            (this set of files)
scripts/               (existing)
config/                (existing)
.github/workflows/
  lint.yml             (active)
  docs-check.yml       (active)
  test.yml             (placeholder)
  build.yml            (placeholder)
```

### 1.7.2 Dependency hierarchy (intent)

- Router depends on: `@modelcontextprotocol/sdk`, `ws`, JSON Schema validator.
- Addon depends on: Godot 4 first-party APIs only.
- No build artifacts depend on `references/`.

### 1.7.3 Tooling matrix

| Concern           | Tool                                   | Lives where                               |
| ----------------- | -------------------------------------- | ----------------------------------------- |
| Lint TS           | ESLint                                 | per-package                               |
| Format TS/JSON/MD | Prettier                               | root                                      |
| Format GDScript   | Godot built-in formatter               | inside Godot editor                       |
| Type check        | `tsc`                                  | per-package                               |
| Test (router)     | TBD in `05`/`10` (Node test or Vitest) | per-package                               |
| Test (addon)      | TBD in `02` (GUT or gdUnit4)           | per-package                               |
| Dep graph (TS)    | `dependency-cruiser`, `madge`          | `config/`, `artifacts/js-graphs/`         |
| Code intel        | GitNexus + Graphify                    | `.gitnexus/`, `graphify-out/`, `scripts/` |

---

## 1.8 Tech stack delta vs `00`

None. This file uses only what `00 §0.10` already locked. It picks two things deferred from `00`:

- **Test framework (router):** decided in `05` (prefer Node's built-in test runner unless there's a
  strong reason to add `vitest`).
- **Test framework (addon):** decided in `02` (prefer GUT for popularity; `gdUnit4` if better
  tooling emerges by impl time).

---

## 1.9 Acceptance criteria

- [x] Top-level layout matches §1.7.1.
- [x] `packages/mcp-server/README.md` describes intent and points at `05`.
- [x] `packages/godot-mcp-addon/README.md` describes intent and points at `02`.
- [x] `packages/README.md` lists both packages and the canonical npm script table from §1.6.6.
- [x] Root tooling (Prettier, ESLint config, EditorConfig, hooks) audited and aligned.
- [x] `.github/workflows/` has at least `lint.yml`, `docs-check.yml`, plus placeholder
      `test.yml`/`build.yml`.
- [x] `docs/context/context-map.md` mentions `docs/tasklist/`.
- [x] `AGENTS.md` mentions `docs/tasklist/`.
- [x] Doctor checklist exists and passes locally.
- [x] `npm run omni:intel` completes without error.
- [x] Decisions Log (0.13) updated with the file's completion timestamp.

---

## 1.10 Verification plan

1. From a clean checkout (or after a `git status` confirming no dirty product code), run the doctor
   checklist.
2. Confirm CI workflows show up on the next push as expected (or are visible in the GitHub Actions
   tab even if no source matches).
3. Open `docs/tasklist/00-foundation-and-contracts.md` and `01-repository-and-tooling-setup.md` in
   the editor, follow every cross-link, confirm none are broken.
4. Spot-check GitNexus: query for `WebSocket` in `references/godot-mcp-tomyud1/`; expect ≥ 1 hit.
5. Spot-check Graphify: confirm `graphify-out/GRAPH_REPORT.md` (or equivalent) is up to date.

---

## 1.11 Risks & mitigations (file-local)

| Risk                                                                            | Mitigation                                                                                                                  |
| ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Existing scripts in `scripts/` were authored before this task list and overlap. | Audit-only in this phase; defer pruning to a single "tooling cleanup" follow-up to avoid breaking unrelated workflows.      |
| Husky/Git hooks fail on Windows due to symlink permissions.                     | Document fallback (manual hook setup via `core.hooksPath = .githooks`).                                                     |
| `npm install` adds unwanted transitive deps.                                    | Pin lockfile; commit `package-lock.json`.                                                                                   |
| CI placeholders create noise.                                                   | Mark them with TODO comments; document expected activation in `10`.                                                         |
| Reference clones drift mid-build.                                               | Snapshot commit hashes in `docs/references/reference-repos-map.md` (deferred follow-up; not mandatory for `01` completion). |

---

## 1.12 Handoff checklist to file `02`

- [x] All §1.9 boxes checked.
- [x] Godot 4.x reachable on `PATH` (**`godot --version`**) — portable ZIP +
      `%USERPROFILE%\bin\godot.cmd` shim (see
      [`windows-godot-portable.md`](../contributing/windows-godot-portable.md)).
- [x] Throwaway Godot dev project exists outside the monorepo (this machine:
      `%USERPROFILE%\Documents\TerravoltMcpDev`; configure addons in task `02`).
- [x] `addon:link`/`addon:unlink` scripts noted (`package.json` → `planned.mjs`; implement task
      `02`).
- [x] GDScript style guide chosen (Godot official) and noted in the addon README.
- [ ] Addon test framework (**GUT vs gdUnit4**) — pick when opening **`02`** (not a `01` blocker).

When all done, open **`02-godot-plugin-foundation.md`**.

---

## Appendix A — Official Godot Docs alignment (added revision 2)

> Sourced from `references/godot-docs/`. Adds dev-environment specifics, CLI invocations, and editor
> expectations that the rest of the build relies on.

### A.1 Godot binary discovery & invocation

Per `tutorials/editor/command_line_tutorial.rst`:

- **PATH placement.** Recommended: place the editor binary under `/usr/local/bin/godot` on Linux. On
  Windows, `scoop install godot` (or `godot-mono` for .NET builds) adds it automatically, or use the
  **portable ZIP + `godot.cmd` shim** documented in
  [`contributing/windows-godot-portable.md`](../contributing/windows-godot-portable.md). On macOS,
  the binary lives inside the `.app` bundle at `Godot.app/Contents/MacOS/Godot`.
- **Sentinel command for the doctor checklist:** `godot --version` (returns the engine version
  banner).
- **Project detection.** Any directory containing a `project.godot` file is a Godot project. Use
  `--path <dir>` or `--upwards` (auto-walk parents) to point Godot at it; otherwise the Project
  Manager opens.
- **Headless smoke test:** `godot --headless --version` confirms the editor build can run without a
  display server (this is what CI relies on).

### A.2 Plugin scaffolding via the editor dialog (preferred dev workflow)

Per `making_plugins.rst`:

- The editor has a built-in dialog: **Project → Project Settings → Plugins tab → Create New
  Plugin**. It generates `addons/<subfolder>/plugin.cfg` and the entry script in one click.
- TerraVolt's dev workflow:
  1. Open the throwaway Godot dev project.
  2. Use the dialog _once_ to bootstrap the initial `plugin.cfg` and `main.gd` shape.
  3. Move the generated files into `packages/godot-mcp-addon/` (or rely on `addon:link` symlink so
     the dev project's `addons/terravolt_mcp/` always reflects the repo).
- Record the convention in `packages/godot-mcp-addon/README.md`.

### A.3 GDScript style guide adoption

- The canonical guide is `tutorials/scripting/gdscript/gdscript_styleguide.rst`.
- The repo's lint pipeline should reject GDScript files that violate the official guide (snake*case
  for identifiers, two-space indents \_in the docs* but Godot's actual style is **tab indentation**,
  `class_name` PascalCase, `_private_method` underscore prefix).
- Reference `tutorials/scripting/gdscript/static_typing.rst` for the "static typing required in
  shipped paths" rule from `00 §A.5`.

### A.4 Shebang pattern for headless utility scripts

Per `command_line_tutorial.rst` §"Running a script":

- A `.gd` script can be made directly executable on Linux/macOS with the shebang
  `#!/usr/bin/env -S godot -s` or `#!/usr/bin/godot -s`.
- The script must `extends SceneTree` or `extends MainLoop`.
- This is the pattern the headless driver in `07` adopts. Mention in the doctor checklist (`1.6.10`)
  that on Linux/macOS the driver script can be invoked via the shebang for local manual debugging.

### A.5 NPM script table additions (planned, finalize in `02`/`07`)

| Script                       | Purpose                                                                     | Tied to                   |
| ---------------------------- | --------------------------------------------------------------------------- | ------------------------- |
| `godot:doctor`               | Run `godot --version`, `godot --headless --version`; print PATH resolution. | Doctor checklist §1.6.10. |
| `addon:scaffold-from-editor` | One-time helper noting the manual editor-dialog step.                       | `02 §A.2`.                |
| `dev:project:open`           | Open the configured dev project (`godot --editor --path <dev project>`).    | `02`.                     |
| `catalog:gen`                | (Defined in `06`.)                                                          | Reaffirmed here.          |

### A.6 Risk register additions

| Risk                                                  | Mitigation                                                                                                                                                      |
| ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Godot binary missing in CI runners.                   | Pin install in `.github/workflows/*.yml` (e.g., `chickensoft-games/setup-godot` action or manual download); doctor checklist short-circuits with a clear error. |
| Plugin generated outside `addons/` directory.         | The editor's Create New Plugin dialog enforces `addons/<subfolder>/`; document the path explicitly in the addon README so contributors don't drift.             |
| Symlink permission errors on Windows.                 | Fall back to copy in `addon:link`; document admin requirement for symlink in the README.                                                                        |
| GDScript formatter divergence between Godot versions. | Pin the supported Godot minor in `02 §A.1` and re-validate on each Godot point release.                                                                         |
