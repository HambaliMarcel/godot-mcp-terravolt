# Editor vs headless parity (living matrix)

Tracks which JSON-RPC daemon methods intentionally match between the `:6505` editor WebSocket and the §07 headless TCP driver.

## Legend

| Path | Meaning |
|------|---------|
| Editor | Daemon WebSocket reachable on `TERRAVOLT_GODOT_HOST`/`TERRAVOLT_GODOT_PORT`. |
| Headless TCP | Routed when `registry.json` sets `headlessFallback: true` and WS is disconnected. |

## Shipped parity (today)

| `method` | Editor | Headless TCP | Notes |
|---------|--------|---------------|-------|
| `ping` | Yes | Yes | Timestamp source differs (`daemonResult` retains raw payload). |
| `server.info` | Yes | Yes | Headless emits minimal subset from driver; parity fields converge over time (see backlog). |

## Backlog parity (planned)

Anything else in `packages/shared/methods/registry.json` **without** `headlessFallback: true` is **editor-first** unless a dedicated MCP headless router tool exposes it locally.

## Validation checklist

Structured repo validation for tasks **TV-00 … TV-09** (including honest partial scope for §07 §08 §09): **`docs/validation/tv-00-09-checkpoint.md`**.
