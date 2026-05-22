# Shared registries (canonical JSON)

Source-of-truth JSON consumed by **`packages/mcp-server`** (router boots from the method registry),
**`scripts/catalog-sync.mjs`** (generates
**`packages/godot-mcp-addon/_generated/catalog_meta.gd`**), and the Godot addon (`dispatcher.gd`
validates against matching schemas declared here).

| Path                        | Purpose                                                                                                                                                 |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `methods/registry.json`     | MCP / daemon opcode catalog (`catalog_version`, per-method schemas, `headlessFallback` flag).                                                           |
| `errors/registry.json`      | Stable application error codes; addon runtime errors are mirrored in `packages/godot-mcp-addon/error_codes.gd` and asserted by `npm run release:check`. |
| `diagnostics/autoheal.json` | Optional hints merged into MCP error payloads when `--disable-auto-heal` is off.                                                                        |

Current shipped state (verified by `npm run release:check`):

- `catalog_version`: **`0.2.0`** (registry SHA `930063cfac74…`).
- 3 methods (`ping`, `server.info`, `log.tail`); `ping` and `server.info` have
  `headlessFallback: true`.
- 12 application error codes mirrored end-to-end.

## Overrides

Router resolution order for `methods/registry.json`:

1. `TERRAVOLT_METHOD_REGISTRY_JSON` — absolute path to a registry file (advanced / packaging tests).
2. Walk `process.cwd()` upward, then the compiled module directory, probing
   `packages/shared/methods/registry.json` (covers `npm run` from the monorepo root and `dist/`
   runs).

The path helper accepts either a `file://` URL or an absolute path so nothing can re-trigger the
Windows `ERR_INVALID_URL_SCHEME` crash that the real-MCP smoke surfaced (commit `22d5c5c`).

## Updating

```bash
# 1. edit packages/shared/methods/registry.json or errors/registry.json
# 2. bump catalog_version per docs/tasklist/10 §10.6.7
npm run catalog:sync           # regenerates packages/godot-mcp-addon/_generated/catalog_meta.gd
npm run release:check          # asserts addon mirror + CHANGELOG mention
```

For an audit of the editor vs headless parity, see
**[`docs/catalog/parity.md`](../../docs/catalog/parity.md)** and the authoritative
**[`docs/guides/tools-reference.md`](../../docs/guides/tools-reference.md)**.
