# Graph artifacts (Graphify layer)

Run `npm run intel:graphs`.

- **dependency-graph.json** — dependency-cruiser (module graph for JS/TS toolchains)
- **madge-graph.json** — madge (optional circular-dep / graph summary)

Third-party reference clones under `references/` are excluded from scans.

When the MCP server or Godot addon layout stabilizes, update the globs in this script and refresh `architecture/SYSTEM_OVERVIEW.md`.
