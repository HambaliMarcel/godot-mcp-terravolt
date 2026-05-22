# Reference repositories — Terravolt map

Local clones live under **`references/`** (gitignored). Use this page as the **mental model** before diving into Graphify/GitNexus on those trees.

Indexing policy (this repo tooling):

| Path | GitNexus & Graphify | Reason |
|------|---------------------|--------|
| `references/godot-mcp-pro/` | **Indexed** | Godot MCP patterns (addon-only public; study GDScript tooling). |
| `references/godot-mcp-tomyud1/` | **Indexed** | Free editor WebSocket MCP + TS server (`mcp-server/`) + visualizer. |
| `references/godot-mcp-coding-solo/` | **Indexed** | Headless Node MCP (`src/`), Godot subprocess / project tools. |
| `references/godot-docs/` | **Excluded** | Official [Sphinx/reST manual](https://github.com/godotengine/godot-docs) — tens of thousands of doc files; use [docs online](https://docs.godotengine.org/) + local clone for full-text/search, not codebase intelligence. |

Re-index respects **`.gitignore` for cloning** (`references/` stayed untracked) but tooling runs **`gitnexus analyze` with `GITNEXUS_NO_GITIGNORE=1`** ([`scripts/run-gitnexus.mjs`](../../scripts/run-gitnexus.mjs)) so MCP clones are visible to GitNexus while **`.gitnexusignore`** drops `references/godot-docs/`, `node_modules/`, and generated dirs.

---

## At-a-glance comparison

```text
                    ┌──────────────┐
                    │ Terravolt    │
                    │ godot-mcp-tv │
                    └──────┬───────┘
                           │ contrasts with ▼

   ┌─────────────────────────────────────────────────────────────────────┐
   │ youichi-uda/godot-mcp-pro     tom/Coding-Solo                      │
   │    WebSocket MCP + editor        vs    headless / CLI-style Godot  │
   │    (addon + paid Node server)    vs    npm package + GDScript/cli │
   └─────────────────────────────────────────────────────────────────────┘
```

| Repo | Upstream | License / cost | Transport | Typical tool count\* | Ship shape |
|------|----------|----------------|-----------|----------------------|------------|
| **Godot MCP Pro** | [youichi-uda/godot-mcp-pro](https://github.com/youichi-uda/godot-mcp-pro) | Addon free; Node server paid | MCP stdio → **Node server** ↔ **WS :6505** ↔ Godot plugin | **172** (modes: full / 3d / lite / minimal) | `addons/godot_mcp/` (+ `server/` only in paid zip) |
| **Godot MCP** | [tomyud1/godot-mcp](https://github.com/tomyud1/godot-mcp) | MIT | MCP stdio → **`mcp-server/`** (npm `godot-mcp-server`) ↔ **WS** ↔ `addons/godot_mcp/` | **42** (readme) / **32** (package README) | Plugin + `mcp-server/` + **browser visualizer** (`localhost:6510`) |
| **Godot MCP (Coding-Solo)** | [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp) | MIT | MCP stdio → **Node** (`src/`, published `@coding-solo/godot-mcp`) — **no live editor plugin** in the same way | Core “run / debug / scenes / UIDs…” | **`src/`** TypeScript MCP + **`scripts/`** GDScript subprocess helpers |
| **godot-docs** | [godotengine/godot-docs](https://github.com/godotengine/godot-docs) | CC / MIT slices | N/A — documentation source | N/A | reST/Sphinx (`tutorials/`, `classes/`, `getting_started/`, …) |

\*Counts come from upstream READMEs; versions may drift.

---

## Anatomy by folder (`references/`)

### `references/godot-mcp-pro/`

| Path | Role |
|------|------|
| `addons/godot_mcp/` | **Godot 4 plugin** — editor bridge, WS client, GDScript commands. |
| *(missing here)* `server/` | Paid bundle: Node MCP server (`build/index.js`), CLI (`cli.js`), modes `--lite`, `--minimal`, `--3d`. |
| `docs/`, `llms.txt` | Orientation for LLMs / users. |

**Takeaway for Terravolt:** richest **editor-integrated** surface; study **addon structure** + JSON-RPC framing; Node server closed-source in public tree.

---

### `references/godot-mcp-tomyud1/`

| Path | Role |
|------|------|
| `addons/godot_mcp/` | Editor plugin — WebSocket bridge to MCP server. |
| `mcp-server/` | **TypeScript** MCP implementation — publishes **`godot-mcp-server`** (see `package.json`). |
| `mcp-server/src/visualizer/` | **Browser explorer** (`map_project`) — graphs scripts/scenes (`localhost:6510`). |

**Architecture (from upstream):**

```text
AI client ◄── MCP (stdio) ──► mcp-server ◄── WebSocket ──► Godot editor (addon)
```

**Takeaway:** Best **open-source** reference for **WS + MCP + TS server + GD addon** parity; reuse patterns for transports and tool naming.

---

### `references/godot-mcp-coding-solo/`

| Path | Role |
|------|------|
| `src/` | **MCP server** (TS) — tools to launch editor, **run_project**, stdout/stderr capture, UID helpers, scene IO. |
| `scripts/` | **GDScript** pieces invoked / bundled for engine interactions. |
| `package.json` | Build → `build/index.js`, MCP SDK dependency. |

**Takeaway:** “**Outside the editor loop**” automation — subprocess Godot runs, debugging loop; contrasts with WS live plugin architectures.

---

### `references/godot-docs/`

| Path | Role |
|------|------|
| `getting_started/`, `tutorials/`, `engine_details/` | User-facing prose (reST). |
| `classes/` | Auto-derived class reference (MIT slice from engine). |
| `conf.py`, `Makefile`, `requirements.txt` | Sphinx build toolchain. |

**Takeaway:** Not an MCP codebase — **engine & API truths** alongside Terravolt work. Prefer **indexed web docs** + local grep in this clone; omit from GitNexus/Graphify in this mono-repo to avoid noise.

---

## Suggested learning order (agents & humans)

1. Read this map + **`docs/context/context-map.md`** (still prioritizes first-party Terravolt code).
2. **Compare architectures:** skim `addons/` in **Pro vs tom** side-by-side; then read **Coding-Solo `src/`** entrypoints.
3. **GitNexus:** `gitnexus_query`, `gitnexus_context` on symbols like `websocket`, `MCP`, `tool` within `references/godot-mcp-tomyud1/mcp-server/`.
4. **Graphify:** `py -3 -m graphify query "how does MCP connect to Godot"` (after `intel:graphify`).
5. **Godot-docs:** topical reading in Sphinx tree or [online manual](https://docs.godotengine.org/).

---

## Maintenance

```bash
# Refresh reference clones (example)
git -C references/godot-mcp-tomyud1 pull --ff-only

# Refresh indexes for Terravolt + MCP references (godot-docs still ignored)
npm run intel:gitnexus
npm run intel:graphs
npm run intel:graphify
```
