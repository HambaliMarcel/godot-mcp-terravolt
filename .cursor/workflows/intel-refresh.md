# Intel refresh workflow

After large merges or when architecture shifts:

1. `npm run intel:gitnexus` — rebuild `.gitnexus/` (GitNexus index).
2. `npm run intel:graphs` — Omni **JS module** graphs → `graphs/`.
3. `npm run intel:graphify` — **safishamsi/graphify** code graph (AST-only) → `graphify-out/`. Optionally `npm run intel:graphify:cluster` after layout changes.
4. Update `architecture/SYSTEM_OVERVIEW.md` with a short bullet summary of what changed.

Restart Cursor after editing `.cursor/mcp.json`. If workspace and user MCP both define **GitNexus**, disable the duplicate in Cursor MCP settings.
