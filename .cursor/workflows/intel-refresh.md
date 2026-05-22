# Intel refresh workflow

After large merges or when architecture shifts:

1. `npm run intel:gitnexus` — rebuild `.gitnexus/` (**includes `references/godot-mcp-*`; excludes
   `references/godot-docs/`** per `.gitnexusignore`). Implemented by
   [`scripts/run-gitnexus.mjs`](../../scripts/run-gitnexus.mjs).
2. `npm run intel:graphs` — Omni **JS module** graphs → `artifacts/js-graphs/` (depcruise/madge obey
   `references/godot-docs` exclusions).
3. `npm run intel:graphify` — **safishamsi/graphify** code KG → `graphify-out/`
   (`references/godot-docs` excluded via `.graphifyignore`). The npm script sets
   `GRAPHIFY_VIZ_NODE_LIMIT=8000` so `graphify-out/graph.html` can be regenerated when node counts
   exceed the default 5000-cap.
4. Update **`docs/repo-layout.md`**, **`docs/architecture/overview.md`**, and/or
   **`docs/references/reference-repos-map.md`** when reference clones, `packages/`, or `scripts/`
   change materially.

Restart Cursor after editing `.cursor/mcp.json`. If workspace + user MCP both define **GitNexus**,
disable the duplicate in MCP settings.
