# Context map — TerraVolt Godot MCP

Suggested order when loading context:

1. **Structure** — `docs/architecture/overview.md`, **`docs/references/reference-repos-map.md`**, `artifacts/js-graphs/*.json`, GitNexus resources (`gitnexus://repo/{name}/context`).
2. **Product intent** — root `README.md`, `packages/*/README.md`, future `docs/specs/`.
3. **Upstream references** — `references/godot-mcp-*` MCP clones are indexed for discovery; **`references/godot-docs/`** is the official Sphinx manual (local clone + [docs online](https://docs.godotengine.org/)) — intentionally **omitted from GitNexus/Graphify** in this workspace to avoid doc-tree noise. Never treat reference trees as shipped TerraVolt product.

Prefer **paths** and short excerpts over pasting entire generated JSON.
