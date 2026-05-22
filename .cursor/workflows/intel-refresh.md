# Intel refresh workflow

After large merges or when architecture shifts:

1. `npm run intel:gitnexus` — rebuild `.gitnexus/` (GitNexus index).
2. `npm run intel:graphs` — Omni **JS module** graphs → `artifacts/js-graphs/`.
3. `npm run intel:graphify` — **safishamsi/graphify** code graph (AST) → `graphify-out/` (optional: `intel:graphify:cluster`).
4. Update `docs/architecture/overview.md` with a short bullet summary of what moved.

Restart Cursor after editing `.cursor/mcp.json`. If workspace + user MCP both define **GitNexus**, disable the duplicate in MCP settings.
