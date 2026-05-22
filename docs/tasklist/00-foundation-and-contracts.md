# 00 — Foundation & Contracts (Pre-Phase 1)

> **You are the executor.** Read this whole file before touching anything. This is the "lock" file for everything that follows. Tasks `01` through `10` assume every contract in this file is internalized and respected.
>
> **No code is produced in this task.** Output is governance, contracts, conventions, glossary, acceptance criteria, and an unambiguous "definition of done" that the rest of the roadmap will be judged against.

---

## 0.1 Purpose of this file

This file converts the SRS bundle in `docs/srs/` into an **operational contract** the agent commits to for the entire build of **TerraVolt Godot MCP** (a.k.a. `godot-mcp-terravolt`). It is the single source of truth for:

- The **product topology** and which layer talks to which.
- The **wire protocol** and error discipline.
- The **operational constants** (ports, log paths, transports) every other phase must use.
- The **package layout** and naming.
- The **phase-gate rules** (do-not-skip).
- The **anti-redundancy doctrine** (polymorphic tools, no duplicated coverage).
- The **agent operating rules** (intel refresh, GitNexus impact, etc.).
- The **vocabulary** so every later file uses the exact same nouns.
- A **scoreboard** the agent uses to self-grade progress.

Output of this file is documentation only — *no* `plugin.cfg`, *no* `main.gd`, *no* TypeScript. The next coding phase (`02-godot-plugin-foundation.md`) starts the moment everything in this file is locked.

---

## 0.2 Product framing (memorize this)

**TerraVolt Godot MCP** is a *dual-stack* Model Context Protocol bridge for Godot 4.x (.NET-compatible), aiming to **dominate** the aggregate capabilities of three upstream reference implementations:

| Reference | Strength TerraVolt absorbs and exceeds |
|-----------|----------------------------------------|
| `youichi-uda/godot-mcp-pro` | **API/schema breadth**, editor-integrated coverage (paid Node bundle, ~172 tools). |
| `tomyud1/godot-mcp` | **WebSocket framing**, addon ↔ Node TS server parity, optional visualizer at `localhost:6510`. |
| `Coding-Solo/godot-mcp` | **Headless / subprocess** Godot execution when the editor is closed. |

TerraVolt is the **strict superset**: it ships both a *live editor* path **and** a *headless CLI* path, exposes a **single coherent ~200-op surface** (polymorphic, no duplicates), and is built for **vibe coding** — i.e., creating a complete Godot game by prompting a Cursor agent that drives this MCP.

> **North star**: "User types a single English sentence → working game produced, debugged, and packaged inside Godot, with the agent reading the runtime tree, tweaking properties, patching scripts, and re-running until acceptance criteria pass." The MCP surface must be rich enough to make this a realistic loop, not a demo.

### 0.2.1 Topology (locked)

```text
                        ┌────────────────────────┐
                        │  Cursor / MCP client   │
                        └───────────┬────────────┘
                                    │  stdio (JSON-RPC framed by MCP SDK)
                                    ▼
                     ┌────────────────────────────────┐
                     │   Node MCP router (TS)         │  packages/mcp-server
                     │   - MCP server (stdio)         │
                     │   - WS client to Godot daemon  │
                     │   - Headless fallback driver   │
                     └─────────────┬───────┬──────────┘
                                   │       │
                  WebSocket :6505  │       │  Headless CLI (godot --headless …)
                                   │       │
                                   ▼       ▼
                     ┌─────────────────┐  ┌─────────────────────────┐
                     │ Godot Editor    │  │ Godot engine subprocess │
                     │ EditorPlugin    │  │ (headless mode)         │
                     │ packages/       │  │  - run project          │
                     │  godot-mcp-     │  │  - exec script          │
                     │  addon/         │  │  - import assets        │
                     └─────────────────┘  └─────────────────────────┘
```

- The Node router is the **only** thing Cursor talks to.
- The Godot addon is the **only** thing the Node router talks to *over WebSocket*.
- The headless fallback is invoked **by the Node router** when the editor is unavailable.
- The agent never talks directly to Godot. There is no second public surface.

### 0.2.2 Non-negotiables

1. **TypeScript** for Node MCP server. Strict mode. No `any` without justification.
2. **Typed GDScript** in the addon. No untyped variables in shipped paths.
3. **JSON-RPC 2.0** end-to-end between Node router and Godot daemon.
4. **stdio** is the only MCP transport to Cursor for v1.
5. **Port 6505** is the only WebSocket listen port for the daemon.
6. **`user://mcp_log.txt`** is the only canonical log sink inside Godot.
7. **Polymorphic ops** beat duplicated narrow ops. One `modify_node` (covering properties, groups, meta) is preferred over three sibling tools.
8. **Successful tool returns the new state** of the affected object (or a structured diff). This is the universal response contract.

---

## 0.3 Operational constants (must be obeyed verbatim)

| Constant | Value | First binding |
|----------|-------|----------------|
| WebSocket listen port (editor) | `6505` | Phase 1, `mcp_server.gd` |
| Editor log sink | `user://mcp_log.txt` | Phase 1, logging subsystem |
| MCP transport (router ↔ Cursor) | `stdio` | Phase 2, Node router |
| Heartbeat interval (router ↔ daemon) | `15s` default, configurable | Phase 1 + Phase 2 |
| Heartbeat timeout | `45s` (3 missed heartbeats) | Phase 1 + Phase 2 |
| Reconnection backoff base | `500ms`, exponential, capped at `30s` | Phase 2 |
| JSON-RPC version | `"2.0"` (literal) | Phase 1 + Phase 2 |
| Application error code range | `-32099` to `-32000` (reserved by spec) and `-33000` to `-33999` (TerraVolt domain) | Phase 1 |
| Max request payload (router → daemon) | `4 MiB` soft, `16 MiB` hard | Phase 3 |
| Visualizer port (optional, parity with `tomyud1`) | `6510` (reserved, not auto-bound) | Future |

**Naming rule:** every later file that needs a constant must reference *this table*, never re-define it locally. If a constant ever needs to change, the change happens here first.

---

## 0.4 Package & path placement (locked)

| Deliverable | Path | Notes |
|-------------|------|-------|
| Godot 4 addon | `packages/godot-mcp-addon/` | Symlinked or copied into a Godot project's `addons/<name>/` for development. |
| Node MCP router (TS) | `packages/mcp-server/` | Strict TS; built artifact directory is implementation-defined but stays inside this package. |
| Shared docs | `docs/` | This task list lives at `docs/tasklist/`. |
| Upstream clones (study only) | `references/` | Gitignored. **Never** shipped. **Never** edited. |
| Generated intel | `artifacts/`, `graphify-out/`, `.gitnexus/` | Regenerated by `npm run omni:intel` / `intel:*` scripts. |

**Rule:** no shippable code lives outside `packages/`. The root and `docs/` are documentation and tooling only.

---

## 0.5 Phase gates (the rule we will not break)

Phases are taken from `docs/srs/execution_roadmap.md`. The agent must verify the previous phase's transport end-to-end before advancing.

| Phase | Gate file | "Done" means |
|-------|-----------|--------------|
| Pre-1 | **This file** + `01-repository-and-tooling-setup.md` | All contracts locked; repo skeleton ready; intel refresh runs clean. |
| 1 | `02-godot-plugin-foundation.md` + `03-godot-websocket-server.md` + `04-jsonrpc-dispatch-and-logging.md` | Godot daemon listens on `6505`, accepts a WS client, parses JSON-RPC, dispatches a no-op `ping`/`echo`/`server_info`, logs to `user://mcp_log.txt`. |
| 2 | `05-node-mcp-router.md` + `06-tool-translation-layer.md` | Node router exposes MCP over stdio to Cursor, connects to Godot daemon, round-trips `ping`/`echo`, reconnects after daemon restart. |
| 3 | `08-toolset-implementation.md` (iterated section by section) | All categorical tools wired, schema-validated, returning the new state of affected objects. |
| 4 | `09-context-and-error-optimization.md` | Context truncation, error mapping, agent retry contract verified under load and chaos tests. |
| Release | `10-quality-testing-release-and-docs.md` | QA matrix passes, docs published, packages versioned, release notes drafted. |

**Anti-skip rules:**

- Never begin Phase 2 until the daemon round-trip from Phase 1 is verified by a manual client (e.g., a `wscat`-style smoke test) and an automated test.
- Never wire a new tool in Phase 3 until its category's transport (e.g., scene tree, runtime, file ops) is health-checked.
- Phase 4 is **not** an optional polish phase; it is required for "vibe coding" to be reliable. Without context protection, large scenes choke the agent loop.
- Any deviation must be recorded in this file's *Decisions Log* (section 0.13) with rationale.

---

## 0.6 Anti-redundancy doctrine

The single biggest failure mode of the reference implementations is **tool bloat with overlapping coverage**. TerraVolt must avoid it.

**Rules:**

1. **Polymorphism over enumeration.** If two tools differ only by `target_field`, they are the same tool with a `target_field` parameter.
   - `modify_node` covers properties, groups, owner, metadata, and signals — *not* `set_node_property`, `add_node_to_group`, `set_node_meta`.
2. **Single-purpose tools only when polymorphism would hurt clarity** (e.g., `play_scene` vs. `stop_scene` stay separate because the parameter shape is genuinely different).
3. **Schema first, name second.** If you can't write a single coherent JSON Schema for a candidate tool, split it.
4. **Return the new state.** Successful mutations return the post-mutation object (or a structured diff with `before`/`after`). This eliminates a follow-up "read" round trip.
5. **No "convenience wrappers"** that the agent could trivially compose (`create_label_and_set_text` is two calls; do not add it).
6. **Reserve names early.** Every tool name claimed in `08-toolset-implementation.md` is reserved; if a follow-up phase wants the name, it must reuse or rename.

The goal of 200+ ops is **coverage**, not duplication. A coverage matrix lives in `08-toolset-implementation.md`.

---

## 0.7 The agent operating rules (Cursor-side discipline)

The Cursor agent executing these tasks must obey:

1. **Intel before edit.** If `gitnexus` is configured (see `AGENTS.md`), run `gitnexus_impact` on any symbol before editing it. Warn on HIGH/CRITICAL.
2. **Refresh intel after structural changes.** Run `npm run omni:intel` (or the individual `intel:*` scripts) after meaningful structural changes so the knowledge graph stays current.
3. **Respect `references/` as read-only.** Never write into `references/godot-*`. They are study fodder.
4. **Use `EditorInterface` (and friends) over hand-editing `.tscn`/`.tres`.** This is from the SRS and is non-negotiable. Hand-editing scene/resource text risks corruption.
5. **Never log secrets.** The log sink is local but assume agents may attach it.
6. **All file moves must update docs.** If a path changes, update `docs/repo-layout.md` and any task file that cites it.
7. **Use the project's npm scripts** (`scripts/`) instead of ad-hoc commands wherever they exist.
8. **Phase-gate self check.** Before starting any task file `N`, the agent re-reads files `0` through `N-1`. The tax is small; the reward is consistency.

---

## 0.8 Glossary (canonical vocabulary)

Use these terms exactly. They appear in every later file.

| Term | Meaning |
|------|---------|
| **Router** | The Node MCP server in `packages/mcp-server/`. The "Node side." |
| **Daemon** | The Godot EditorPlugin in `packages/godot-mcp-addon/`. The "Godot side." Listens on `6505`. |
| **Headless** | Godot launched in `--headless` mode by the Router for offline/scripted ops. |
| **Client** (in WS context) | The Router connecting to the Daemon. Never reversed; the Daemon is always the server. |
| **Tool** | An MCP tool exposed by the Router to Cursor. Has a JSON Schema and a translation function. |
| **Operation (op)** | A JSON-RPC method dispatched on the Daemon. Tools map 1↔1 or 1↔N to ops. |
| **Dispatcher** | The central function in the Daemon that routes a parsed JSON-RPC `method` to a handler. |
| **Handler** | A typed GDScript function that implements one op. |
| **Tool category** | One of: `scene`, `node`, `script`, `signal`, `resource`, `asset`, `runtime`, `editor`, `project`, `input`, `animation`, `physics`, `render`, `audio`, `network`, `debug`, `profile`, `macro`. |
| **Schema** | The JSON Schema attached to a tool. The Router validates inputs against it before sending the op. |
| **Diagnostic** | A structured, agent-readable error returned by the Router with `code`, `category`, `recoverable`, `hint`, and `data`. |
| **Heartbeat** | Periodic `ping`/`pong` JSON-RPC notifications keeping the WS link healthy. |
| **Context envelope** | The reduced/summarized payload returned when raw scene data would exceed the agent budget. |
| **Vibe coding** | The end-user experience of building a game by sustained natural-language prompting. |

---

## 0.9 Definitions of done — Foundation phase

The Foundation phase is **done** when every box below is true. The agent should self-check this list before opening file `01`.

- [ ] All five SRS documents read and summarized in working memory.
- [ ] Topology diagram (0.2.1) understood — agent can draw it without looking.
- [ ] Constants in 0.3 memorized (port, log path, transports, heartbeat numbers, error code ranges).
- [ ] Package layout in 0.4 confirmed against actual `packages/` tree.
- [ ] Phase gates in 0.5 acknowledged; "do not skip" rule accepted.
- [ ] Anti-redundancy doctrine (0.6) accepted as a hard design constraint.
- [ ] Operating rules (0.7) accepted; intel refresh path verified (`npm run` scripts exist).
- [ ] Glossary in 0.8 internalized; no later file will introduce new top-level vocabulary without amending this file.
- [ ] Decisions Log (0.13) has at least one entry: "Foundation locked at \[date\]".
- [ ] Risk register (0.14) acknowledged.

---

## 0.10 Tech stack (final, no debate)

| Layer | Choice | Justification |
|-------|--------|---------------|
| Node MCP router | **Node.js 20+** (LTS) | Stable, native fetch, native test runner, broad SDK support. |
| Router language | **TypeScript ≥ 5.x** with `strict: true` | SRS mandates TS; we want exhaustive type narrowing for tool schemas. |
| MCP SDK | **`@modelcontextprotocol/sdk`** (latest stable at impl time) | Spec-aligned, used by upstream `tomyud1`. |
| WebSocket client | **`ws`** | De facto Node WS library; matches `tomyud1` parity. |
| Schema validation | **JSON Schema (Draft 2020-12)** validated by a single library across both ends (Router validates input; Daemon optionally re-validates) | Required for MCP tool schemas. |
| Godot engine | **Godot 4.x** (.NET-compatible build) | SRS requirement; latest stable minor at impl time. |
| Addon language | **Typed GDScript** | Native EditorPlugin path. |
| Addon WS server | **Godot built-in `WebSocketMultiplayerPeer`/`WebSocketPeer`** APIs | First-party. |
| Logging (addon) | **Plain text** to `user://mcp_log.txt`, line-delimited JSON optional secondary | Tail-friendly for agents. |
| Logging (router) | **Structured JSON to stderr**, plain to stdout reserved for MCP transport | stdout is MCP-only; do not pollute. |
| Build (router) | TypeScript compiler (`tsc`) producing ESM | No bundler unless a future phase justifies it. |
| Test (router) | **Node test runner** + lightweight assertion lib; integration via spawning Godot in headless mode | Avoids extra deps. |
| Test (addon) | **GUT** (Godot Unit Test) or `gdUnit4`, decision recorded in `02-godot-plugin-foundation.md` | Pick once. |
| Lint | ESLint (TS) + GDScript style guide enforcement via Godot's built-in checks | Standard. |
| Format | Prettier (TS), Godot's GDScript formatter (addon) | Standard. |
| CI | GitHub Actions placeholders defined in `01`; full pipeline in `10` | Phased. |

**Forbidden in v1:**

- Browsers as MCP transport (only stdio).
- Frameworks that obscure the wire protocol (no Express, no Fastify, no Nest in the Router — direct WS + MCP SDK).
- Bundlers/transpilers beyond `tsc` unless `10` says otherwise.
- Heavy ORM/storage layers. Logs are flat files; state is held in memory or in `user://`.

---

## 0.11 Cross-file dependency map

```text
00 (this) ──► 01 ──► 02 ──► 03 ──► 04 ──┐
                                         ├──► 05 ──► 06 ──► 07 ──► 08 ──► 09 ──► 10
                              (Phase 1 gate)        (Phase 2 gate)    (Phase 3)  (Phase 4) (Release)
```

| File | Depends on (must be done first) | Provides to next |
|------|----------------------------------|------------------|
| 00 | — | Contracts, vocabulary, constants. |
| 01 | 00 | Repo skeleton, tooling, lint/format/test scaffolding (no product code yet). |
| 02 | 01 | Addon skeleton, `plugin.cfg` plan, lifecycle, dev workflow. |
| 03 | 02 | WS server design, lifecycle, framing rules, heartbeat. |
| 04 | 03 | JSON-RPC parser, dispatcher contract, error code registry, logging. |
| 05 | 04 | Node MCP router skeleton, stdio MCP transport, WS client. |
| 06 | 05 | Tool registration mechanism, schema validation, response normalization. |
| 07 | 06 | Headless fallback driver, parity matrix vs editor path. |
| 08 | 07 | The 200+ tool catalog with category-by-category breakdown. |
| 09 | 08 | Context envelopes, diagnostics, auto-healing contract. |
| 10 | 09 | QA, docs, release pipeline, versioning, support matrix. |

---

## 0.12 Scoreboard (used by the agent to grade itself)

Each later phase carries a small numeric scoreboard. The Foundation scoreboard:

| Metric | Target | Means of measurement |
|--------|--------|----------------------|
| SRS documents read | 5/5 | Self-attestation in Decisions Log. |
| Constants memorized | 100% | Agent can paste 0.3 from memory into a scratch buffer; verified spot-check. |
| Glossary terms learned | All in 0.8 | Spot-check during 02. |
| Decisions Log entries | ≥ 1 | "Foundation locked" with timestamp and author. |
| Risk register reviewed | Yes | Section 0.14 read; mitigations annotated where applicable. |

---

## 0.13 Decisions log (append-only)

Every irreversible decision goes here as a row. Format: `YYYY-MM-DD — author — decision — rationale — supersedes?`.

| Date | Author | Decision | Rationale | Supersedes |
|------|--------|----------|-----------|------------|
| _to-fill_ | _agent_ | Foundation locked, contracts above adopted. | SRS bundle internalized; aligns with `docs/srs/00-fundamentals-contract.md`. | — |

The agent **must** append a row when it finishes this file.

---

## 0.14 Risk register (foundation-relevant)

| Risk | Likelihood | Impact | Mitigation | Owner phase |
|------|-----------|--------|------------|-------------|
| Port `6505` already in use on the user's machine. | Medium | High | Detect on startup; surface a structured diagnostic; allow override via project config in a later phase but do **not** change the default. | 03 |
| Cursor MCP stdio framing changes between SDK versions. | Low | High | Pin SDK version; record in `package.json`; add an integration smoke test. | 05 |
| Godot 4 API drift between minors. | Medium | Medium | Pin minimum Godot version in `plugin.cfg`; record tested version in `02`. | 02 |
| Tool bloat creeping back in. | Medium | High | Maintain the polymorphism doctrine (0.6); reject PRs that add narrow duplicates. | 08 |
| Logging accidentally written to stdout in the Router (corrupting MCP frames). | Medium | Critical | Code review rule + lint configuration; integration test asserts stdout contains only MCP frames. | 05 |
| `.tscn` corruption from hand editing. | Medium | High | Hard rule: use `EditorInterface` exclusively. Lint or runtime guard if feasible. | 02 / 08 |
| Reference clones drift and confuse the agent. | Low | Medium | Index policy in `docs/references/reference-repos-map.md` already in place. | Standing |
| Phase skipping under time pressure. | High | Critical | Hard gate documented in 0.5; agent must self-check before each phase. | Standing |
| Heartbeat/timeout values too aggressive on slow machines. | Low | Medium | Make configurable in `04`; defaults conservative. | 04 |
| Headless fallback diverges in behavior from editor path. | Medium | High | Parity matrix maintained in `07`; integration tests cover both for the same op when applicable. | 07 |
| Context envelopes lose data agents need. | Medium | Medium | Always include "how to fetch unsummarized" pointer in envelopes. | 09 |

---

## 0.15 Communication conventions for later files

Every later task file (`01`–`10`) **must** include the following sections in this order:

1. **Header** (one line: file name + purpose).
2. **Phase placement** (which roadmap phase, what it gates).
3. **Inputs / prerequisites** (which earlier files must be done).
4. **Outputs / what this file produces**.
5. **Operating constants used** (cite section 0.3, never restate).
6. **Detailed task breakdown** (numbered, hierarchical, granular — *no code*).
7. **Schemes / data shapes** (described in prose + tables, *no code*).
8. **Tech stack delta** (anything beyond what 0.10 already locked in).
9. **Acceptance criteria / definition of done** (checklist).
10. **Verification plan** (how the agent proves it's done).
11. **Risks & mitigations** (file-local).
12. **Handoff checklist to next file**.

If a later file lacks any of these sections, it is considered **incomplete** and the agent must amend it before claiming the phase is done.

---

## 0.16 Final checklist (before opening file 01)

- [ ] I (the agent) can recite the topology diagram in 0.2.1.
- [ ] I can list all operational constants from 0.3 from memory.
- [ ] I accept the polymorphism doctrine and will not add narrow-duplicate tools.
- [ ] I have appended a row to the Decisions Log (0.13).
- [ ] I have skimmed the risk register (0.14) and acknowledged the high-impact rows.
- [ ] I will run `npm run omni:intel` after structural changes (per 0.7).
- [ ] I will never write into `references/` (per 0.7).
- [ ] I understand the section format in 0.15 applies to every later file.

When every box is checked, open **`01-repository-and-tooling-setup.md`**.

---

## Appendix A — Official Godot Docs alignment (added revision 2)

> Sourced from `references/godot-docs/` (Godot 4.x Sphinx manual). This appendix layers **engine truths** onto the contracts above. Earlier sections remain authoritative; this appendix narrows ambiguity and pins TerraVolt's choices to canonical Godot terminology and behavior.

### A.1 Doctrine clarifications

- **`@tool` requirement.** Per `tutorials/plugins/editor/making_plugins.rst`, the EditorPlugin entry script — and **every GDScript it loads in the editor** — must be `@tool`. A non-`@tool` script loaded by the addon "acts like an empty file" in the editor. Make this a hard rule for the entire daemon code path; record violations as bugs.
- **Plugin layout.** Godot expects `addons/<plugin_machine_name>/` inside the project's `res://addons/`. TerraVolt's machine name is `terravolt_mcp` and the addon root mounts to `res://addons/terravolt_mcp/` in the dev project.
- **Paths use `/` only.** Per `tutorials/scripting/filesystem.rst`, Godot mandates UNIX-style separators *even on Windows*. Anything that crosses into Godot land — scene paths, resource paths, log paths — uses `/`. Backslashes in agent inputs must be normalized at the router boundary.
- **`res://` is read-only at runtime.** Per `tutorials/io/data_paths.rst`, the `res://` filesystem is writable **only** when running inside the editor on the developer's machine; exported builds see it as read-only. All persistent writes (logs, settings overrides, snapshots) belong under `user://`. This is why `user://mcp_log.txt` is the contract.
- **`user://` is OS-resolved.** Real on-disk locations per `tutorials/io/data_paths.rst` §"User path":
  - Windows: `%APPDATA%\Godot\app_userdata\[project_name]\`
  - macOS: `~/Library/Application Support/Godot/app_userdata/[project_name]/`
  - Linux: `~/.local/share/godot/app_userdata/[project_name]/`
  - With `application/config/use_custom_user_dir` enabled, the folder moves outside Godot's own data directory.
  - Honors XDG (`XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`) on Linux/\*BSD.
  - Flatpak path: `~/.var/app/org.godotengine.Godot/...`.
  - Self-contained mode (`._sc_` or `_sc_` next to the editor binary) redirects everything to `editor_data/`.
  - The agent's `editor.show_log_path` tool (reserved) must resolve via `ProjectSettings.globalize_path("user://mcp_log.txt")`.

### A.2 Vocabulary delta — Godot canonical terms

These engine terms are now part of the project glossary alongside `00 §0.8`:

| Term | Canonical Godot meaning | TerraVolt usage |
|------|--------------------------|------------------|
| `SceneTree` | Singleton main loop owning the root `Viewport`. Returned by `Node.get_tree()`. | All scene/runtime tools read it. |
| `MainLoop` | Base class for any custom loop run via `--main-loop`. | Reserved for headless utility scripts. |
| `EditorInterface` | Editor-only singleton exposing scene/script/dock APIs. | Required for every `requiresEditor: true` tool. |
| `EditorPlugin` | Base class for the addon entry. Provides `_enter_tree`/`_exit_tree`/`_enable_plugin`/`_disable_plugin`. | `main.gd` extends this. |
| `PackedScene` | Serialized resource representing a scene. `.tscn` (text) or `.scn` (binary). | All `scene.*` and `node.pack` tools traffic in this. |
| `Resource` / `RefCounted` | Reference-counted serializable data containers. | All `resource.*` tools. |
| `NodePath` | Either absolute (`/root/Main/UI/Label`) or relative; supports `%UniqueName` syntax for scene-unique nodes. | Common schema in `06 §6.7.4`. |
| `Autoload` (singleton) | Project-wide globals, registered via Project Settings → Globals → Autoload, or programmatically with `EditorPlugin.add_autoload_singleton`. | `project.add_autoload` tool. |
| `Feature tag` | Build/runtime capability flag (`pc`, `mobile`, `web`, `editor`, `template`, `debug`, `release`, custom). | Used by export tooling and `09`'s context redaction. |

### A.3 Tree-order rule (used everywhere downstream)

Per `tutorials/scripting/scene_tree.rst`:

- `_enter_tree` and `_process` fire in **pre-order** (top → bottom).
- `_ready` fires in **post-order** (children before parents).
- `_exit_tree` fires in **reverse pre-order** (bottom → top).
- Override via `Node.process_priority`.

This is the canonical ordering the daemon must respect for scene mutation, event emission ordering, and lifecycle logging.

### A.4 Deferred call discipline

Per `tutorials/scripting/singletons_autoload.rst`:

> "Deleting the current scene at this point is a bad idea, because it may still be executing code. […] The solution is to defer the load to a later time."

Every TerraVolt op that mutates scene structure (free, reparent, replace, change_scene_to_*) must use `Object.call_deferred()` (or its semantic equivalent) when it might be triggered from inside another node's execution. This is mandatory for `scene.replace`, `node.remove`, `scene.delete`, and any `runtime.*` mutator.

### A.5 GDScript discipline

Source: `tutorials/scripting/gdscript/gdscript_styleguide.rst`.

- Use the official **GDScript Style Guide** verbatim across the addon.
- Static typing per `gdscript/static_typing.rst` is **required** in TerraVolt addon code, not optional. No untyped variables in shipped paths.
- Documentation comments per `gdscript_documentation_comments.rst` — handler functions should include the standard GDScript docstring so the agent can introspect them via the editor.

### A.6 Risk register additions

| Risk | Source | Mitigation |
|------|--------|------------|
| Non-`@tool` GDScript loaded by the addon ⇒ silently empty file. | `making_plugins.rst` warning. | Lint pass in `01` ensures every `.gd` shipped under `packages/godot-mcp-addon/` declares `@tool`. |
| Path case sensitivity drift (Windows/macOS vs Linux). | `tutorials/scripting/filesystem.rst`. | Enforce lowercase asset names in test fixtures; case-fold path comparisons in handlers. |
| `Autoload` freed at runtime crashes the engine. | `tutorials/scripting/singletons_autoload.rst` warning. | TerraVolt's `project.remove_autoload` must refuse runtime invocation (editor-only); `runtime.*` tools cannot free autoload nodes. |
| Self-contained mode confuses log discovery. | `data_paths.rst` §"Self-contained mode". | Logger resolves the actual `user://` path via `ProjectSettings.globalize_path` on first write and surfaces it in `server.info`. |
| Hand-editing `.tscn` corrupts dependencies. | `filesystem.rst` §"Drawbacks". | Already hard rule (`00 §0.7`); reinforced — all moves go through `EditorInterface` / `EditorFileSystem`. |

### A.7 Decisions Log addition

Append: "Doctrine pinned to Godot 4 official manual revision present in `references/godot-docs/`. `@tool`, deferred mutation, `/`-only paths, and `user://` resolution rules are non-negotiable engine truths."

