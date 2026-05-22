# Context map — TerraVolt Godot MCP

Suggested order when loading context:

1. **Structure** — **`docs/repo-layout.md`**, **`docs/architecture/overview.md`**,
   **`docs/references/reference-repos-map.md`**, `artifacts/js-graphs/*.json`, GitNexus resources
   (`gitnexus://repo/{name}/context`).
2. **SRS & build order** — **`docs/srs/README.md`**, then **`docs/srs/00-fundamentals-contract.md`**
   (contracts before Phase 1), then phased specs in the same folder.
3. **`docs/tasklist/`** — `00–10` granular execution plan + gates (do **not** skip phases).
4. **Product intent** — root `README.md`, `packages/*/README.md`, future `docs/specs/`.
5. **Upstream references** — `references/godot-mcp-*` MCP clones are indexed for discovery;
   **`references/godot-docs/`** is the official Sphinx manual (local clone +
   [docs online](https://docs.godotengine.org/)) — intentionally **omitted from GitNexus/Graphify**
   in this workspace to avoid doc-tree noise. Never treat reference trees as shipped TerraVolt
   product.

Prefer **paths** and short excerpts over pasting entire generated JSON.
