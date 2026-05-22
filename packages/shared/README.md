# Shared registries (canonical JSON)

Source-of-truth JSON consumed by **`packages/mcp-server`** (router boots from the method registry),
**`scripts/catalog-sync.mjs`** (generates
**`packages/godot-mcp-addon/_generated/catalog_meta.gd`**), and (incrementally) the Godot addon
(**`dispatcher.gd`** validates against matching schemas declared here).

| Path                          | Purpose                                                                          |
| ----------------------------- | -------------------------------------------------------------------------------- |
| `methods/registry.json`       | MCP / daemon opcode catalog (`catalog_version`, per-method schemas)              |
| `errors/registry.json`        | Subset mirrored for tooling; addon runtime errors remain in **`error_codes.gd`** |
| `diagnostics/autoheal.json`    | Optional hints merged into MCP error payloads when `--disable-auto-heal` is off  |

## Overrides

Router resolution order for `methods/registry.json`:

1. `TERRAVOLT_METHOD_REGISTRY_JSON` — absolute path to a registry file (advanced / packaging tests).
2. Walk **cwd** upward, then the compiled module directory, probing
   **`packages/shared/methods/registry.json`** (covers `npm run` from repo root and `dist/` runs).
