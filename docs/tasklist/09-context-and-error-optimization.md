# 09 — Context & Error Optimization (Phase 4)

> **Goal**: make the MCP **agent-grade**. Big scene trees stop choking the agent's context window;
> errors return structured "what to try next" hints; mutations report diffs the agent can reason
> about; telemetry exposes bottlenecks. After this file, the system is suitable for _sustained vibe
> coding_: a Cursor agent can run dozens to hundreds of tool calls per session without running out
> of context, getting stuck on opaque failures, or producing inconsistent state.

---

## 9.1 Header

- **File:** `09-context-and-error-optimization.md`
- **Purpose:** ship context envelopes, structured diagnostics, auto-healing hints, retry contracts,
  telemetry, and performance guardrails.

## 9.2 Phase placement

- **Phase 4.** Cross-cutting; touches both daemon and router.
- Gates the release in `10`.

## 9.3 Inputs / prerequisites

- Files `00`–`08` complete.
- `tools.metrics` populated from real usage.
- Error envelope from `04 §4.6.9` is the universal error shape.
- Some categories (`scene`, `node`, `runtime`) already emit large payloads.

## 9.4 Outputs

After this file:

1. **Context envelopes** are first-class. Every tool whose natural response can be unboundedly large
   (scene tree, runtime tree, large file content, profile dumps) returns a _summarized_ envelope by
   default with an explicit, agent-readable pointer to fetch the raw payload.
2. **Default-truncation rules** on a per-category basis with sensible heuristics.
3. **Auto-healing diagnostics**: every error envelope includes `autoHeal` — a structured suggestion
   the agent can act on (e.g., "open the editor first" → call `editor.open_scene`).
4. **Retry contracts**: tools annotate their idempotency and the router exposes a safe "retry
   policy" the agent can consult.
5. **Telemetry surface**: `tools.metrics` is upgraded; `tools.bottlenecks` lists the
   slowest/highest-payload methods.
6. **Performance budget**: a per-call SLA matrix; the router warns when a tool exceeds budget.
7. **Throttle & batch helpers**: agents can opt into automatic batching (e.g., 50 `node.modify`
   calls fused into one).
8. **Deterministic ordering**: outputs are stable across runs to make agent reasoning reliable.
9. **Documentation site sources updated** so the agent learns from `docs/catalog/`.

## 9.5 Operating constants used

| Constant                                     | Default     | Source      |
| -------------------------------------------- | ----------- | ----------- |
| Max tree nodes returned raw                  | `5000`      | `02 §2.6.6` |
| Max payload KiB returned raw                 | `4096`      | `02 §2.6.6` |
| Default context envelope mode                | `summary`   | this file   |
| Auto-healing pointer max hint length         | `400` chars | this file   |
| Per-call latency SLA — read tools            | `200 ms`    | this file   |
| Per-call latency SLA — write tools           | `500 ms`    | this file   |
| Per-call latency SLA — runtime/profile tools | `1 s`       | this file   |
| Per-call latency SLA — macros                | `5 s`       | this file   |
| Rolling metrics window                       | `5 minutes` | this file   |

---

## 9.6 Detailed task breakdown

### 9.6.1 The context envelope

Every tool that can return a "big" payload supports three modes, controlled by an optional input
`envelope`:

- `summary` (default for large defaults): a digest with counts, top-level structure, and "fetch raw"
  pointers.
- `raw`: full payload, subject to **hard caps**. If a raw response would exceed `max_payload_kb`,
  the daemon returns a `context.truncated` envelope instead.
- `diff`: only for mutating tools; returns `before`/`after` per touched object.

Envelope output shape (preview only — no code):

- `envelopeKind`: one of `summary`, `raw`, `diff`, `truncated`.
- `summary` (if summary or truncated):
  - `counts`: `{ nodes, descendants, properties, children_average, …}` depending on tool.
  - `roots`: top-level structure (e.g., root nodes of a tree).
  - `sample`: a small, deterministic sample (e.g., first 50 children).
  - `pointers`: array of `{ method, params, description }` the agent can call to retrieve
    unsummarized slices (e.g., `node.get` on a specific path).
  - `bytes_estimated_raw`: hint to the agent.
  - `cache_id`: optional opaque token to reference this envelope in subsequent calls.
- `raw` (if raw): the full data.
- `diff` (if diff): `{ before, after, patch }`.
- `truncated` (if hard-capped): `{ reason, recovery: pointers[] }`.

### 9.6.2 Default envelope rules per category

| Category             | Default envelope for read                                                                  | Notes                                                                  |
| -------------------- | ------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| `scene.get_tree`     | `summary`                                                                                  | Provide structure + first-level node names; pointers to subtree fetch. |
| `scene.get_subtree`  | `raw` (subject to caps)                                                                    |                                                                        |
| `scene.find_in_tree` | `summary` if > 50 results                                                                  |                                                                        |
| `node.get`           | `raw`                                                                                      |                                                                        |
| `node.walk`          | `summary` with pagination tokens                                                           |                                                                        |
| `script.get`         | `raw` if < 100KB, else `summary` (top of file + symbol list + pointers to `script.search`) |                                                                        |
| `script.search`      | `summary` if > 50 hits                                                                     |                                                                        |
| `resource.load`      | `summary` for binary/heavy resources; `raw` for small text/JSON                            |                                                                        |
| `asset.list`         | `summary` if > 500 entries                                                                 |                                                                        |
| `runtime.get_tree`   | `summary`                                                                                  |                                                                        |
| `profile.get_*`      | `summary` for histograms; `raw` for single metric                                          |                                                                        |
| Others               | `raw` unless natural payload is large                                                      |                                                                        |

### 9.6.3 Summarization heuristics

Documented per category. Universal rules:

1. **Preserve identity**: always include node paths, UIDs, types.
2. **Preserve top-level shape**: agent should be able to see the "outline."
3. **Bound depth**: default depth `3`; configurable per call.
4. **Bound breadth**: cap children per node at `25` in summary; include `truncated_children_count`.
5. **Stable selection**: sample is deterministic (e.g., first N by path order), never random.
6. **Always include pointers**: every summary tells the agent how to fetch the missing parts.

### 9.6.4 Pointer language (agent-actionable)

A pointer is a small object the agent can use directly:

| Field               | Type   | Purpose                       |
| ------------------- | ------ | ----------------------------- |
| `method`            | string | Tool name to call.            |
| `params`            | object | Pre-filled parameters.        |
| `description`       | string | Human-readable explanation.   |
| `cost_estimate`     | enum   | `low` / `medium` / `high`.    |
| `expected_envelope` | string | What the agent will get back. |

Example (no code):
`{ method: "node.walk", params: { from: "/root/Main/UI", depth: 2 }, description: "Drill into the UI subtree.", cost_estimate: "low", expected_envelope: "raw" }`.

### 9.6.5 Auto-healing diagnostics

Every error envelope is extended with:

| Field                               | Type              | Purpose                                                                        |
| ----------------------------------- | ----------------- | ------------------------------------------------------------------------------ |
| `autoHeal`                          | object?           | Suggestion the agent can act on.                                               |
| `autoHeal.cause`                    | string            | Short cause classification (e.g., `editor_closed`, `path_typo`, `wrong_type`). |
| `autoHeal.suggestedActions`         | array of pointers | Ordered actions to try.                                                        |
| `autoHeal.likelihood`               | enum              | `high` / `medium` / `low` confidence in the suggestion.                        |
| `autoHeal.requiresUserConfirmation` | bool              | If `true`, agent should ask first.                                             |

**Examples (described, no code):**

- `scene.path_not_found`:
  - Cause: `path_typo` or `file_missing`.
  - Suggested: `scene.list` (find similar names), then `scene.open` with corrected path.
- `editor.not_available`:
  - Cause: `editor_closed`.
  - Suggested: `headless.start_project` if op is headless-capable, else "ask user to open editor."
- `node.type_unknown`:
  - Cause: `wrong_type`.
  - Suggested: `node.get_properties_schema` (none applicable; use `tools.describe` to inspect
    input), then retry with valid `type`.
- `script.compile_error`:
  - Cause: `syntax_error`.
  - Suggested: re-attempt `script.set` with a corrected patch; include error coordinates from
    `data.errors`.
- `transport.not_connected`:
  - Cause: `daemon_down`.
  - Suggested: wait for reconnect (the router will retry); fall back to headless if applicable.

A small dictionary of autoHeal templates lives in `packages/shared/diagnostics/autoheal.json`. The
router fills templates with context.

### 9.6.6 Retry contract per tool

Every tool's registry entry now carries:

| Field         | Type   | Purpose                                                |
| ------------- | ------ | ------------------------------------------------------ |
| `idempotent`  | bool   | Repeating the call with same inputs is safe.           |
| `retryable`   | enum   | `always` / `on_transient` / `never`.                   |
| `retryPolicy` | object | `{ maxAttempts, backoffMs, factor }`.                  |
| `ifMatch`     | bool   | Whether the tool supports an `ifMatch` revision token. |

The router exposes a **safe-retry helper** internally; the agent can also rely on the policy by
reading `tools.describe`. Transient errors (`transport.*`, `headless.crashed`,
`internal.unexpected`) are retried automatically by the router up to the policy when called via the
`runWithRetry` capability (opt-in by the agent).

### 9.6.7 Idempotency tokens (`ifMatch`)

For mutating tools where rerunning could clobber concurrent changes, the daemon attaches a
`revision` to the returned state. The next mutating call may set `ifMatch: <revision>`; daemon
refuses with `dispatch.conflict` (`-33105`, new code) if the revision is stale.

Reserve this on:

- `node.modify`
- `scene.save`, `scene.save_as`
- `resource.modify`, `resource.save`
- `script.set`
- `project.set_settings`
- `input.add_action` / `bind_*`
- `animation.edit_track`

### 9.6.8 Telemetry & bottlenecks

Upgrade `tools.metrics`:

- Per-tool: count, average latency, p50/p95/p99, error rate, average input bytes, average output
  bytes.
- Per-category: same aggregates.
- Per-error code: count.
- Last 5-minute rolling window.

Add new tool:

| Tool                | Summary                                                               |
| ------------------- | --------------------------------------------------------------------- |
| `tools.bottlenecks` | Top-N slowest tools, top-N largest payloads, top-N error-prone tools. |

Optional: emit `event.metrics.snapshot` every minute (subscription-based) so the agent can monitor
over time.

### 9.6.9 Performance budget enforcement

When a tool exceeds its SLA latency:

- Warn in the structured log.
- Append a `warnings` entry on the result envelope (`{ kind: "slow", actualMs, budgetMs }`).
- After repeated breaches (configurable), demote the tool to `safe: false` to discourage automatic
  use.

When a tool exceeds payload caps:

- Always rewrite to a `summary` envelope.
- Add `context.truncated` warning.

### 9.6.10 Throttling & batching

Some operations are obviously batch-friendly (`node.modify` over many nodes, `asset.import` for many
files). For these, ship:

- An **explicit batch tool** when natural (`macro.batch_apply` already exists from `08`).
- A **client-side hint**: `tools.describe` reveals `batchable: true` for tools that the daemon
  implements with internal batching even when called individually. The router then auto-batches
  calls within a small time window (configurable, e.g., `batch_window_ms`, default `8`) into a
  single daemon op.
- Cancellation must cancel the _whole batch_ together.

### 9.6.11 Deterministic ordering

For every list/array in any response:

- Sort by a stable key (node path, asset path, uid, name).
- Document the chosen key in the tool's outputSchema.
- Never include time-dependent fields in the sorted region (timestamps go in side fields).

### 9.6.12 Context "Cache" hints

The router maintains an LRU keyed by `cache_id` (returned in summary envelopes). Any pointer call
can include `from_cache_id: <id>` so the daemon returns _only the parts not yet seen by the agent_.
This is opt-in and may be skipped in v1 if implementation cost is high; the field is **reserved** in
the envelope spec.

### 9.6.13 Logging level for diagnostics

When a diagnostic with `autoHeal.likelihood = high` fires, log at `warn` (visible to dev). Lower
likelihoods log at `info`. Repeats of the same diagnostic within a 30s window are deduplicated.

### 9.6.14 Configuration knobs added

| Setting                                               | Default   | Purpose                  |
| ----------------------------------------------------- | --------- | ------------------------ |
| `terravolt_mcp/context/default_envelope`              | `summary` | Global default.          |
| `terravolt_mcp/context/max_tree_depth_summary`        | `3`       |                          |
| `terravolt_mcp/context/max_children_per_node_summary` | `25`      |                          |
| `terravolt_mcp/context/page_size_default`             | `50`      | For paginated lists.     |
| `terravolt_mcp/diagnostics/include_autoheal`          | `true`    | Toggle for benchmarking. |
| `terravolt_mcp/diagnostics/dedupe_window_sec`         | `30`      |                          |
| Router CLI: `--metrics-window-sec`                    | `300`     |                          |
| Router CLI: `--batch-window-ms`                       | `8`       |                          |
| Router CLI: `--auto-retry`                            | `false`   | Opt-in agent retries.    |

### 9.6.15 Updated tool surface (delta)

| Tool                     | Status                                                                           |
| ------------------------ | -------------------------------------------------------------------------------- |
| `tools.metrics`          | upgraded (per §9.6.8)                                                            |
| `tools.bottlenecks`      | new                                                                              |
| `context.fetch_raw`      | new helper that takes any pointer object and dispatches it (sugar for the agent) |
| `context.peek_cache`     | new — list pointer cache entries (when caching is implemented)                   |
| `event.metrics.snapshot` | new notification                                                                 |

### 9.6.16 Chaos & soak tests

To prove the optimizations:

- **Chaos**: randomly drop daemon WS connection during a session; confirm router/agent recover via
  `transport.*` autoHeal hints.
- **Soak**: 24-hour sustained workload of mixed tools; confirm memory stable, no metric loss, log
  rotation clean.
- **Big project**: open a Godot project with > 10,000 nodes; confirm `scene.get_tree` returns within
  200ms via summary envelope.

These tests are scaffolded here, fully wired in `10`.

### 9.6.17 Manual smoke tests

1. Open a large scene. Call `scene.get_tree`. Confirm `envelopeKind: summary` with stable structure
   and pointers to deeper fetches.
2. Call `scene.get_tree` with `envelope: raw`. If under cap, confirm raw; if over, confirm
   `truncated` with recovery pointers.
3. Force a `scene.path_not_found`. Confirm `autoHeal.suggestedActions` includes a `scene.list`
   pointer with a name pattern.
4. Call `node.modify` twice; second time with stale `ifMatch`. Confirm `dispatch.conflict`.
5. Watch `tools.metrics` over a minute of ping/echo; confirm p50/p95 fill in.
6. Subscribe to `event.metrics.snapshot`. Confirm minutely notifications.

---

## 9.7 Schemes / data shapes

### 9.7.1 Result envelope (final)

```text
{
  ok: true,
  tool: "<name>",
  method: "<daemon method>",
  latencyMs: <int>,
  result: { ... },
  warnings: [ {kind, ...} ],
  context: {
    envelopeKind: "raw" | "summary" | "diff" | "truncated",
    cache_id?: "<opaque>",
    pointers?: [ {method, params, description, cost_estimate, expected_envelope}, ... ],
    bytes_estimated_raw?: <int>
  },
  revision?: "<opaque>"
}
```

### 9.7.2 Error envelope (final)

Extending the envelope from `04 §4.6.9`:

```text
{
  code: <jsonrpc-or-app-code>,
  message: "...",
  data: {
    app_code: "...",
    category: "...",
    recoverable: <bool>,
    hint: "...",
    context: { ... },
    autoHeal?: {
      cause: "...",
      suggestedActions: [ <pointer>, ... ],
      likelihood: "high" | "medium" | "low",
      requiresUserConfirmation: <bool>
    }
  }
}
```

### 9.7.3 Telemetry record

```text
{
  ts, tool, method, latencyMs, ok, errorCode?, inBytes, outBytes, truncated, envelopeKind
}
```

Aggregated by `tools.metrics`; deduplicated and rolled-up per minute.

---

## 9.8 Tech stack delta vs `00 §0.10`

- No new runtime dependencies.
- New shared file: `packages/shared/diagnostics/autoheal.json`.
- New daemon module: `handlers/_envelope.gd` (summarization helpers).

---

## 9.9 Acceptance criteria

- [ ] Context envelope shape (§9.7.1) used by every tool that returns potentially large payloads.
- [ ] Default envelope rules (§9.6.2) implemented.
- [ ] AutoHeal hints attached to every error returned from listed categories.
- [ ] `ifMatch` revision tokens supported by the mutating tools listed in §9.6.7.
- [ ] `tools.metrics` upgraded; `tools.bottlenecks` shipped; `context.fetch_raw` shipped.
- [ ] Performance budget warnings work.
- [ ] Chaos and soak tests scaffolded in `tests/`.
- [ ] New configuration knobs documented in addon README and router README.
- [ ] Smoke tests in §9.6.17 pass.
- [ ] Decisions Log updated.

---

## 9.10 Verification plan

1. Smoke tests §9.6.17.
2. Big-project test (see §9.6.16): a Godot project with > 10,000 nodes; benchmark `scene.get_tree`
   summary vs raw.
3. Stress test: hammer `ping` and `node.modify` for 10 minutes; confirm metrics stable, no memory
   creep.
4. AutoHeal QA: deliberately mis-call a half-dozen tools; confirm hints lead to valid recovery in
   each case.
5. Editor-closed run: with editor closed, drive the autoHeal chain end-to-end (fall back to
   headless).

---

## 9.11 Risks & mitigations

| Risk                                                      | Mitigation                                                                                                                     |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| AutoHeal hints become inaccurate over time.               | Templates in `packages/shared/diagnostics/autoheal.json`; update with the catalog; tests assert presence for every error code. |
| Summaries lose crucial info.                              | Pointer language ensures the agent can always retrieve the missing parts.                                                      |
| Metrics overhead.                                         | Cheap counters; sampling reads at p99 level; no per-call disk writes.                                                          |
| Idempotency tokens cause user friction (write conflicts). | Reasonable defaults: only set `ifMatch` for mutating tools where concurrent edits realistic.                                   |
| Auto-batching introduces ordering bugs.                   | Disabled by default; only enabled when both router and daemon support the batch op semantics.                                  |
| Soak test reveals a leak.                                 | Address in `10` before release; fail gates.                                                                                    |

---

## 9.12 Handoff checklist to file `10`

- [ ] Envelope rules implemented and verified.
- [ ] AutoHeal templates complete for all error codes.
- [ ] Telemetry surface available to QA.
- [ ] `tools.bottlenecks` and `tools.metrics` produce trustworthy data.
- [ ] Chaos + soak harness wired (full CI run is `10`).

When done, open **`10-quality-testing-release-and-docs.md`**.

---

## Appendix A — Official Godot Docs alignment (added revision 2)

> Sourced from `tutorials/best_practices/*`,
> `tutorials/scripting/debug/custom_performance_monitors.rst`, `tutorials/scripting/scene_tree.rst`,
> and `tutorials/export/feature_tags.rst`. Sharpens the envelope, autoHeal, and telemetry strategy
> against engine-truth.

### A.1 Engine truth that shapes summarization

- Tree iteration is **always** pre-order from the root (`scene_tree.rst`). The summary envelope's
  `sample` array uses this order for determinism.
- `_ready` is post-order (children before parents). Notifications about subtree-completed states
  should fire on parent `_ready`, not on `node_added`.
- `Node.is_node_ready()` distinguishes "added but not ready" from "ready" — useful in `node.observe`
  to defer reads.

### A.2 Custom performance monitors as telemetry

Per `custom_performance_monitors.rst`:

- TerraVolt's daemon publishes `terravolt/<subsystem>/<metric>` monitors via
  `Performance.add_custom_monitor(name, callable)`:
  - `terravolt/dispatcher/inbound_qps` — frames/sec accepted.
  - `terravolt/dispatcher/p50_ms`, `p95_ms`, `p99_ms` — request latency.
  - `terravolt/transport/peers` — active peer count.
  - `terravolt/transport/queue_depth` — peer inbound queue depth.
  - `terravolt/logger/records_per_sec` — logger rate.
  - `terravolt/envelope/truncate_rate` — fraction of responses that triggered summarization.
  - `terravolt/autoheal/hits_per_min` — autoHeal suggestions fired.
- These appear in **Debugger → Monitors** and are queryable from inside the project at runtime via
  `Performance.get_custom_monitor("terravolt/dispatcher/p95_ms")`.
- `tools.bottlenecks` reads from the same store so the agent and human observability share data.

### A.3 Envelope sizing heuristics tied to engine defaults

Project Setting `terravolt_mcp/context/max_tree_nodes` default `5000` is consistent with typical
large Godot scenes; reference projects in `references/godot-mcp-*` rarely exceed a few thousand.
Document this as the rationale.

### A.4 Feature tags drive context redaction

Per `tutorials/export/feature_tags.rst` and `OS.get_feature_list()`:

- Standard tags include `editor`, `template`, `release`, `debug`, `pc`, `mobile`, `web`, plus
  user-defined.
- `09 §9.6.13` redaction rules use these:
  - In `editor` mode, log payload params with longer context.
  - In `template` / `release` mode (exported product), redact more aggressively.
  - Custom tags (e.g., `internal_build`) may be considered sensitive — never echoed to log unless
    whitelisted.
- The router exposes `--redaction-profile <editor|template|strict>` to override.

### A.5 AutoHeal templates anchored to engine messages

A starter set of templates that map Godot error strings to autoHeal actions:

| Godot error pattern                              | TerraVolt autoHeal                                                                         |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------ |
| `Resource file not found: <path>`                | Suggest `scene.list` or `resource.find_by_path` with normalized pattern.                   |
| `Parser Error: Identifier '<name>' not declared` | Suggest `script.search` for the identifier.                                                |
| `Node not found: <path>`                         | Suggest `scene.find_in_tree` with the basename.                                            |
| `Class '<name>' not found`                       | Suggest `script.list_classes_in_project`.                                                  |
| `Method '<name>' not found in '<class>'`         | Suggest `node.get_methods`.                                                                |
| `Signal '<name>' not declared`                   | Suggest `node.get_signals`.                                                                |
| `Failed to load script` (with line/col)          | Suggest `script.set` with the corrected snippet and `headless.validate_script` to confirm. |
| `RID is invalid`                                 | Suggest `tools.health`.                                                                    |
| `Couldn't open file` (write)                     | Check `res://` read-only at runtime; suggest `user://` (per `data_paths.rst`).             |

These templates live in `packages/shared/diagnostics/autoheal.json`.

### A.6 Idempotency revisions — engine-friendly tokens

Use a hash of `(resource_path, resource.get_modified_time())` or
`EditorFileSystem.get_file_modified_time(path)` as the `revision` token for resource-backed
mutators. For scene roots, hash
`(scene_path, EditorInterface.get_edited_scene_root().get_instance_id())`.

### A.7 Cancellation cooperation

- Long-running ops must respect cancellation: use `Engine.is_editor_hint()` checks combined with the
  dispatcher's "cancellation token" pattern (a `bool` flag set by `dispatch.cancel`).
- For loops over many files (e.g., `script.compile_all`), check the flag every N iterations.
- The cancel hint should be surfaced as a `warnings` entry on the partial result if the cancel
  happened mid-stream.

### A.8 Throttling against engine ticks

- Don't emit notifications faster than one per editor frame; coalesce within a frame.
- For `event.runtime.fps`, sample at 1Hz (not 60Hz) — agent can request a higher rate explicitly.
- Use `Engine.get_process_frames()` to detect same-frame coalescing.

### A.9 Risks added

| Risk                                                        | Mitigation                                                                                  |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Custom monitors register multiple times after addon reload. | On `_exit_tree`, call `Performance.remove_custom_monitor(name)` for each registered metric. |
| Envelope sample order non-deterministic.                    | Sort by NodePath / asset path / UID before truncation.                                      |
| AutoHeal suggestions stale relative to current Godot patch. | Templates carry `engineRef`; refreshed when registry version bumps.                         |
| Feature-tag-driven redaction surprises users.               | `tools.health` reports active redaction profile; documented in FAQ.                         |
