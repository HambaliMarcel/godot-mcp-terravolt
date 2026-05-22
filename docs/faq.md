# FAQ

Mirrors `docs/tasklist/10 §10.6.13`.

### Do I need Godot open?

For a small number of tools (`ping`, `server.info`, and the
`headless.start_project`/`stop`/`status`/`validate_script` family) **no** — the router can spawn a
`--headless` driver as needed. The full editor catalog (`08`) still requires the editor running and
the addon enabled. Track expansion in `docs/catalog/parity.md`.

### Can two agents use one daemon?

v1 is **single-client**. The daemon (`packages/godot-mcp-addon/`) rejects a second peer with
`transport.peer_busy` (`-33001`). Multi-client is on the v1.1 roadmap (§10.6.14).

### How do I add a new tool?

See `docs/tasklist/06-tool-translation-layer.md` for the shared catalog flow and
`docs/tasklist/08-toolset-implementation.md` for category-by-category acceptance criteria. The
minimum addition is:

1. A method row in `packages/shared/methods/registry.json`.
2. Bump `catalog_version` per `docs/tasklist/10 §10.6.7`.
3. `npm run catalog:sync` to regenerate the addon’s `_generated/catalog_meta.gd`.
4. Implement the handler in `packages/godot-mcp-addon/dispatcher.gd` (and the headless driver if
   `headlessFallback: true`).

### Why isn’t my project recognized?

Resolution order matches `docs/tasklist/07 §7.6.7`: `--project` flag, then `TERRAVOLT_PROJECT_PATH`,
then the project of a running editor (detected via `server.info`). The error is
`headless.no_project` (`-33811`) with a structured `autoHeal` pointer.

### What’s the difference between Godot MCP Pro / tomyud1 / Coding-Solo and Terravolt?

See `references/reference-repos-map.md`. Terravolt explicitly indexes those peers and only adopts
patterns that survive the lock contracts in `docs/tasklist/00`.

### Is this safe to use on big projects?

Yes once the §09 envelopes ship. Today, prefer scoped queries (e.g., `scene.get_subtree(path=...)`
over `scene.get_tree`) to avoid context blowups; the agent should respect `tools.bottlenecks`
reports.

### How do I report a bug?

GitHub issues. Include `npm run release:check` output and the snippet from `user://mcp_log.txt`. For
security-impacting bugs, see `SECURITY.md`.
