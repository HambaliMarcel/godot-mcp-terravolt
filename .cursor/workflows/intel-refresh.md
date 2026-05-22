# Intel refresh workflow

After large merges or when architecture shifts:

1. `npm run intel:gitnexus` — rebuild `.gitnexus/` (**includes `references/godot-mcp-*`; excludes `references/godot-docs/`** per `.gitnexusignore`).
2. `npm run intel:graphs` — Omni **JS module** graphs → `artifacts/js-graphs/` (depcruise/madge obey `references/godot-docs` exclusions).
3. `npm run intel:graphify` — **safishamsi/graphify** code KG → `graphify-out/` (`references/godot-docs` excluded via `.graphifyignore`).
4. Update **`docs/architecture/overview.md`** and/or **`docs/references/reference-repos-map.md`** if reference clones or layering changed.

Restart Cursor after editing `.cursor/mcp.json`. If workspace + user MCP both define **GitNexus**, disable the duplicate in MCP settings.
