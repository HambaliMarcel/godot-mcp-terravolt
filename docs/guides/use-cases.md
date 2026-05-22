# Use cases — what each feature does for a Godot game

This is the **rookie-friendly** companion to `docs/guides/tools-reference.md`. Every feature gets:

- **What it does** — in one line.
- **When you reach for it** — a real game-dev moment.
- **How to ask Cursor** — a literal prompt you can copy.
- **What Cursor does under the hood** — which MCP tool runs.
- **Impact on Godot** — what happens in the engine.

Total surface: **222 daemon methods** across **28 categories** (catalog **0.17.0**), exposed to
Cursor via **13 MCP router tools** plus `context.fetch_raw` for any catalog method. **30/30
integration tests** pass against the live Godot 4.6.3 binary, so every category is provably
runnable. Pick whichever bucket matches your moment.

> Category reference: [`docs/catalog/`](../catalog/) · Coverage:
> [`docs/coverage/catalog-coverage.md`](../coverage/catalog-coverage.md)

---

## Bucket 1: "Is everything wired up correctly?" — health & discovery

You're starting Cursor, just installed the addon, and want to confirm the AI can actually drive
Godot. These tools answer "yes/no" quickly without touching your project.

### 1. `tools.health` — the master sanity check

- **What it does:** one combined probe — schema validator works, the editor daemon is reachable, the
  catalog hash matches on both sides, and a headless Godot can be spawned if needed.
- **Game-dev moment:** Monday morning, opened Cursor, opened Godot, about to start a feature. Want
  to confirm AI ↔ Godot is hot.
- **Ask Cursor:** _"Run a health check on the Godot MCP."_
- **Under the hood:** `tools.health` with `{}`.
- **Impact on Godot:** zero (it just sends `server.info` to your running editor). Returns
  `pass: true` when green.

### 2. `ping` — am I still connected?

- **What it does:** round-trip a tiny message to the daemon (or to a headless Godot if the editor is
  closed).
- **Game-dev moment:** Cursor "froze" while applying a refactor — worried the connection dropped.
- **Ask Cursor:** _"Ping the Godot daemon."_
- **Under the hood:** `ping` with `{}`. Result includes `roundTripMs`.
- **Impact on Godot:** the addon ticks a counter; the headless driver (if used) replies to one
  message. Negligible.

### 3. `server.info` — what's actually running?

- **What it does:** prints daemon identity — addon version, Godot version, catalog version, registry
  hash, uptime, listen address.
- **Game-dev moment:** you upgraded Godot from 4.5 to 4.6 and the addon is acting weird. First step:
  confirm the editor is actually running what you think it is.
- **Ask Cursor:** _"What's the Godot daemon currently running?"_
- **Under the hood:** `server.info`.
- **Impact on Godot:** zero (read-only metadata).

### 4. `tools.list` — what can the AI actually do?

- **What it does:** list every MCP tool registered (with category and whether it mutates state).
  Filterable by `category` or `safe`.
- **Game-dev moment:** new to the project. Want a menu of what to ask the AI for.
- **Ask Cursor:** _"List every headless tool the MCP exposes."_
- **Under the hood:** `tools.list` with `{ "category": "headless" }`.
- **Impact on Godot:** zero (pure router answer).

### 5. `tools.describe` — show me the exact arguments

- **What it does:** dump full metadata and JSON Schemas for one tool.
- **Game-dev moment:** you saw `headless.validate_script` in a list and want to know what arguments
  it accepts before invoking it.
- **Ask Cursor:** _"Describe the headless.validate_script tool."_
- **Under the hood:** `tools.describe` with `{ "name": "headless.validate_script" }`.
- **Impact on Godot:** zero.

---

## Bucket 2: "I'm building gameplay" — daily editor work

The editor is open. You're iterating on scripts, scenes, prefabs. These features keep the AI in the
loop while you work.

### 6. `log.tail` — read what Godot just printed

- **What it does:** tail the rotating log file `user://mcp_log.txt` (daemon-side logger). Optional
  `lines`, `level` filters.
- **Game-dev moment:** your `BossEnemy.gd` is supposed to play a sound on death but the sound never
  fires. You want to know whether the daemon's seen the call without flipping windows to the Godot
  Output panel.
- **Ask Cursor:** _"Tail the last 50 warn+ log lines from the Godot MCP."_
- **Under the hood:** `log.tail` with `{ "lines": 50, "level": "warn" }`.
- **Impact on Godot:** zero (read-only file tail).
- **Caveat:** editor mode only — no log file exists when the editor isn't running.

### 7. `context.fetch_raw` — try a daemon method that isn't a tool yet

- **What it does:** send any JSON-RPC method directly to the daemon and return the raw payload.
  Skips schema validation.
- **Game-dev moment:** the catalog (§08) is being expanded incrementally. You read the SRS and saw
  `scene.get_open_path` mentioned but it's not wrapped as a high-level MCP tool yet. You want to
  call it anyway.
- **Ask Cursor:** _"Use context.fetch_raw to call scene.get_open_path on the daemon."_
- **Under the hood:** `context.fetch_raw` with `{ "method": "scene.get_open_path", "params": {} }`.
- **Impact on Godot:** depends entirely on the method. Treat it as power-user: the AI is responsible
  for argument shapes.

---

## Bucket 3: "I want a compile guard before I waste time" — headless

The editor doesn't need to be open. The AI spawns a `godot --headless` process behind the scenes and
uses it for compile checks, info queries, etc.

### 8. `headless.start_project` — boot a background Godot

- **What it does:** spawn `godot --headless --path <project> --script headless_driver.gd`, wait for
  a TCP handshake, and report the live pid/port.
- **Game-dev moment:** CI agent on GitHub Actions — no display, no editor, but you still want the AI
  to compile-check your scripts.
- **Ask Cursor:** _"Start a headless Godot session for the project at C:\path\to\my-game."_
- **Under the hood:** `headless.start_project` with `{ "projectPath": "C:\\path\\to\\my-game" }`.
- **Impact on Godot:** **a new `godot.exe` (or `godot4`) process appears in Task Manager**, runs in
  `--headless` mode (no window), binds an ephemeral loopback TCP port, idles waiting for RPCs.
- **Cost:** ~1–3 seconds cold start. Once running, subsequent RPCs are fast.

### 9. `headless.status` — is the background Godot still alive?

- **What it does:** snapshot of the running session — alive flag, pid, port, project path, uptime.
- **Game-dev moment:** ran a long compile check, wonder if the subprocess is still healthy or if it
  crashed.
- **Ask Cursor:** _"Show the status of the headless Godot session."_
- **Under the hood:** `headless.status` with `{}`.
- **Impact on Godot:** zero (router-local accessor on the coordinator).

### 10. `headless.stop` — close the background Godot

- **What it does:** kill the subprocess (`SIGTERM`, or `SIGKILL` with `force: true`).
- **Game-dev moment:** you're done iterating, want to free RAM. Or a test run is hanging.
- **Ask Cursor:** _"Stop the headless Godot session."_
- **Under the hood:** `headless.stop` with `{ "force": false }` (set `true` to hard-kill).
- **Impact on Godot:** **the background `godot` process exits**. The next headless tool call will
  start a new one.

### 11. `headless.validate_script` — compile-check a `.gd` file

This is the **flagship** rookie tool. Use it before you context-switch back to Godot to discover
that braces are missing.

- **What it does:** load a GDScript file inside a headless Godot, parse it, and either say "ok" or
  return the list of parse errors (line, column, message).
- **Game-dev moment 1 — refactor:** the AI just split `Player.gd` into `Player.gd` +
  `PlayerInput.gd`. You want a confidence check that both still compile before you switch to Godot
  to play-test.
- **Game-dev moment 2 — typed signal mistake:** you added a typed signal
  `signal hit_taken(amount: int)` and forgot a colon. Cursor catches it without you reloading the
  editor.
- **Game-dev moment 3 — Mono migration:** you're porting a 4.5 project to 4.6. Validate every script
  in a tight loop before opening the editor.
- **Ask Cursor:** _"Compile-check player.gd at C:\path\to\my-game\scripts\player.gd."_
- **Under the hood:** `headless.validate_script` with
  ```jsonc
  { "path": "C:\\path\\to\\my-game\\scripts\\player.gd", "projectPath": "C:\\path\\to\\my-game" }
  ```
- **Impact on Godot:** the background `godot --headless` instance runs `GDScript.new().reload()`
  against the file contents. On failure, you get a clean error list — no editor restart, no UI
  scroll-through.
- **Limitation today:** GDScript only. C# (`.cs`) compile parity is scheduled for §08.

### 12. `tools.metrics` — what did I actually run today?

- **What it does:** rolling counters per tool — count, success count, average latency, p95 latency.
  Window is set by `--metrics-window-sec` (default 5 minutes).
- **Game-dev moment:** you ran 50 compile checks in a row and Cursor feels sluggish. Is it the model
  or my engine?
- **Ask Cursor:** _"Show me the current MCP tool metrics."_
- **Under the hood:** `tools.metrics` with `{}`.
- **Impact on Godot:** zero (router-local counters).

### 13. `tools.bottlenecks` — what's the slowest?

- **What it does:** rank tools by average latency. Returns the top N.
- **Game-dev moment:** your AI agent has 30 seconds budget per turn and you want to know which calls
  eat the most.
- **Ask Cursor:** _"What are the top 5 slowest MCP tools right now?"_
- **Under the hood:** `tools.bottlenecks` with `{ "topN": 5 }`.
- **Impact on Godot:** zero.

---

## Bonus capabilities (not separate tools, behaviors)

### Auto-heal hints in every error

When something fails, the error envelope embeds an `autoHeal` block with concrete next steps — for
example, "Run `npm run env:godot`" or "Set `TERRAVOLT_GODOT_BINARY` to an absolute path". This is on
by default; disable with `--disable-auto-heal` for compact logs.

- **Game-dev moment:** first day with the MCP — got `headless.binary_missing`. The error tells you
  the exact command to fix it.

### Headless fallback for `ping` and `server.info`

When the editor isn't running, `ping` and `server.info` automatically spawn a headless Godot to
answer instead of returning a connection error. The MCP envelope shows `method: "ping@headless"` so
the AI knows which path served the result.

- **Game-dev moment:** running an agent in CI without an editor. Asking "is the engine reachable?"
  still returns a useful answer instead of a hard fail.

### Cooperative cancellation

If Cursor aborts a long-running tool call (you hit Stop), the router sends
`dispatch.cancel { target_id: <id> }` to the daemon. Tools designed to honor cancellation will bail
out cleanly.

### Catalog version pinning

Both the router and the addon publish the same `catalog_version` (currently `0.2.0`) and registry
SHA. `tools.health` flags a mismatch so you know to run `npm run catalog:sync` after editing the
registry.

---

## "A day in the life" — your first AI-assisted Godot session

Here is a realistic sequence — every line is a prompt you can paste into Cursor.

1. **Boot.** _"Run a health check on the Godot MCP."_ → `tools.health` returns `pass: true`. Editor
   is on. Catalog matches.

2. **Browse.** _"List every tool with category headless."_ → `tools.list` returns the four headless
   tools.

3. **Refactor.** Ask the AI to split your `Player.gd` into smaller scripts. The AI makes edits.

4. **Compile guard.** _"Compile-check every .gd I just touched."_ → for each file,
   `headless.validate_script`. The AI loops over files and confirms `ok: true` before you switch
   back to the editor.

5. **Hit save in Godot, play-test.** Something prints an unexpected warning. _"Tail the last 100
   lines of mcp_log.txt at level warn or above."_ → `log.tail` shows the offending log.

6. **Triage performance.** _"Show me the top 3 slowest MCP tools so far this session."_ →
   `tools.bottlenecks` returns ranked latencies. You now know `headless.validate_script` is the
   cold-start cost.

7. **Shut down.** Done for the day. _"Stop the headless Godot session."_ → `headless.stop` cleans up
   the background process.

---

## What's NOT supported yet (so you don't waste time asking)

These remain **partial or backlog** at catalog **0.17.0**:

| Want to…                                    | Status                                    |
| ------------------------------------------- | ----------------------------------------- |
| Per-category MCP tools (222 as first-class) | Backlog — use `context.fetch_raw` today   |
| Browser project visualizer `:6510`          | Backlog — use Graphify/GitNexus           |
| Compile-check C# (`.cs`) files              | Backlog (§10)                             |
| Full macro apply (12/15 templates)          | Partial — dry-run works                   |
| Drive two Godot editors at once             | Roadmap (`docs/roadmap.md`)               |
| iOS deploy parity with `android.deploy`     | Roadmap — adb-equivalent tooling deferred |

Everything else from the original §08 backlog — scene/node mutators, resources, runtime bridge,
export, testing, audio, input, 3D scene sugar, macros, **Android deploy chain**, and **scenario
orchestration** — is **live**. See
[`docs/demos/vibe-coding-walkthrough.md`](../demos/vibe-coding-walkthrough.md) for an end-to-end
prompt script.

When new router tools land, this page will gain dedicated sections. For now, use the 13 router tools
plus `context.fetch_raw` for any of the 222 daemon methods — or read category docs under
`docs/catalog/`.

---

## See also

- `docs/guides/quick-start.md` — first install, Cursor wiring.
- `docs/guides/mcp-usage.md` — concrete `tools/call` payload shapes.
- `docs/guides/tools-reference.md` — schema-level reference.
- `docs/guides/godot-integration.md` — editor vs headless flow diagram.
- `docs/guides/troubleshooting.md` — what to do when an error fires.
