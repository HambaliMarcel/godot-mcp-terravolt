# Node MCP router (`packages/mcp-server`)

This package becomes the **MCP stdio server** Cursor talks to
(`docs/tasklist/05-node-mcp-router.md`, Phase&nbsp;2).

## Current status (through task `01`)

- TypeScript scaffold only — **Phase&nbsp;2 code begins in task `05`.**
- Folders reserve where transport, tooling, diagnostics, JSON-RPC framing, and the headless driver
  will live (`src/transport`, `src/tools`, …).
- Lint + typecheck + build + smoke `node:test` wired so CI can stay green **before** the router
  exists.

### Manifest outlook (finalize in task `05`)

| Concern      | Plan                                                                                        |
| ------------ | ------------------------------------------------------------------------------------------- |
| **Runtime**  | Node **20 LTS+**, `"type":"module"`                                                         |
| **MCP deps** | `@modelcontextprotocol/sdk`, `ws`, JSON Schema validator (e.g. `ajv`) — install in **`05`** |
| **Exports**  | `build/` emits runnable ESM for the MCP CLI entry                                           |
| **Dev deps** | `typescript`, ESLint suite (already pinned)                                                 |

### Folder map

| Path               | Planned contents                                        |
| ------------------ | ------------------------------------------------------- |
| `src/`             | Router bootstrap (`05`)                                 |
| `src/transport/`   | stdio MCP + WebSocket client to Godot `:6505` (`05`)    |
| `src/jsonrpc/`     | Framing/helpers shared with daemon contract (`05`–`06`) |
| `src/tools/`       | MCP tool registrations (`06`/`08`)                      |
| `src/headless/`    | Headless subprocess driver parity (`07`)                |
| `src/diagnostics/` | Agent-facing error normalization (`09`)                 |
| `tests/`           | Router tests evolve through `05`/`10`                   |

Operational constants (stdio-only MCP, `:6505`, JSON-RPC **`2.0`**, heartbeat defaults) remain
defined in **`docs/tasklist/00-foundation-and-contracts.md`** §0.3 — never fork them locally.

## Package scripts (`npm run` when invoked via workspace)

See root **[`packages/README.md`](../README.md)** /
**[`scripts/README.md`](../../scripts/README.md)** for the canonical table mirrored from
**`docs/tasklist/01-repository-and-tooling-setup.md`**.
