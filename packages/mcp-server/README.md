# Node MCP router (`@terravolt/godot-mcp`)

Phase **2** MCP server: **stdio** (Cursor / MCP clients) ↔ **persistent WebSocket** to the Godot
TerraVolt daemon on **`127.0.0.1:6505`** (JSON-RPC **2.0**).

Task references: [`docs/tasklist/05-node-mcp-router.md`](../../docs/tasklist/05-node-mcp-router.md),
[`docs/tasklist/06-tool-translation-layer.md`](../../docs/tasklist/06-tool-translation-layer.md).

## CLI

After `npm run build:server` from the repo root:

```bash
node packages/mcp-server/dist/index.js --version
node packages/mcp-server/dist/index.js --print-config
```

Global install / `npx` use the **`terravolt-godot-mcp`** bin (see `package.json`).

## Cursor / MCP config (sketch)

Point your MCP client at the compiled entry (or `terravolt-godot-mcp`), **stdio** transport. Do
**not** wrap the process in shells that write to stdout. Logs are **stderr** JSON lines.

### Shared registry lookup

Resolution order for **`packages/shared/methods/registry.json`**:

1. **`TERRAVOLT_METHOD_REGISTRY_JSON`** — absolute path override (packaging / CI fixtures).
2. Walk **`process.cwd()`** ancestors, then ancestors of the compiled module — matches `npm run`
   from the monorepo root or running **`dist/index.js`** from `packages/mcp-server`.

See also [`packages/shared/README.md`](../shared/README.md).

## Daemon tools (from shared catalog)

Declared in **`packages/shared/methods/registry.json`** and merged at router boot:

| MCP tool      | Daemon JSON-RPC | Notes                                         |
| ------------- | --------------- | --------------------------------------------- |
| `ping`        | `ping`          | Round-trip `{ daemonTs, roundTripMs }`        |
| `server.info` | `server.info`   | Includes `catalog_version`, `registry_sha256` |
| `log.tail`    | `log.tail`      | Tail `user://mcp_log.txt` (catalog max lines) |

## Router-only tools

| Tool             | Purpose                                                |
| ---------------- | ------------------------------------------------------ |
| `tools.list`     | Enumerate tools (`category`, `safe` filters)           |
| `tools.describe` | Single-tool metadata + schemas                         |
| `tools.health`   | AJV smoke, daemon `server.info`, **catalog SHA** match |
| `tools.metrics`  | Counters for tool latency / success                    |

Input for daemon-backed tools is validated with **AJV** against each method's `inputSchema` in the
shared registry before dispatch.

## Cancellation (best-effort)

When MCP passes an aborted signal into a tool handler, the router rejects the in-flight JSON-RPC
request and sends **`dispatch.cancel`** `{ "target_id": <id> }` to the daemon (notification). The
daemon should treat this as cooperative cancellation where supported.

## Catalog sync (Godot)

After editing `packages/shared/methods/registry.json`, run:

```bash
npm run catalog:sync
```

This regenerates `packages/godot-mcp-addon/_generated/catalog_meta.gd` so **`server.info`** and
**`tools.health`** stay aligned with the router's registry hash.

## Layout

| Path                               | Role                                            |
| ---------------------------------- | ----------------------------------------------- |
| `src/index.ts`                     | `--version`, config, lifecycle, SIGINT/SIGTERM  |
| `src/transport/mcp_stdio.ts`       | MCP SDK + tools + bridging daemon notifications |
| `src/transport/godot_ws_client.ts` | WS client, reconnect, heartbeat                 |
| `src/catalog/loadRegistry.ts`      | Loads shared `methods/registry.json`            |
| `src/tools/registry.ts`            | Declarative tool catalog merge                  |

Operational constants (**`:6505`**, heartbeat defaults, payloads) remain in
**[`docs/tasklist/00-foundation-and-contracts.md`](../../docs/tasklist/00-foundation-and-contracts.md)**
§0.3 — do not fork them locally.

## Scripts (workspace)

From repo root: `npm run build:server`, `npm run typecheck`, `npm run test:server`, `npm run lint`.
