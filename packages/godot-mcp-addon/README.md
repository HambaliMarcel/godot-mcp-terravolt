# TerraVolt MCP — Godot 4 addon

Editor plugin exposing a **localhost WebSocket JSON-RPC daemon** (`:6505` by default) plus
structured logging to **`user://mcp_log.txt`**.

## Requirements

- **Godot 4.x** (`.NET-compatible` builds are fine; addon is GDScript-only).
- This folder is symlinked/junctioned/copied into a dev Godot project as  
  **`addons/terravolt_mcp/`** (see linking below).

## Link into a Godot dev project

From repo root:

1. Set **`TERRAVOLT_GODOT_PROJECT`** to the absolute path of your Godot project **or** put
   `{ "godotProject": "<absolute/path>" }` in **`~/.terravolt-mcp-dev.json`** (Windows:
   **`%USERPROFILE%\.terravolt-mcp-dev.json`**).

2. Run:

```bash

npm run addon:link



```

Overwrite an existing addon dir:

```

npm run addon:link -- --force

```

Remove:

```bash

npm run addon:unlink

```

## Editor usage

Enable **TerraVolt MCP** in **Project Settings → Plugins**.  
Use the bottom panel tab **“TerraVolt MCP”** for status, ledger, Start/Stop/Restart, log actions.
Terravolt settings namespace: **`terravolt_mcp/...`** (port, bind, heartbeat, logging, etc.).

## Phase map

Implemented per **`docs/tasklist/02`**–**`04`**:

- **`02`** — plugin shell, bottom panel, project settings defaults, link scripts.
- **`03`** — `TCPServer` + `WebSocketPeer` listener, single-client policy, heartbeat. Default
  **`heartbeat_mode=control_frame`** drives native WS ping via
  `WebSocketPeer.set_heartbeat_interval`; use **`rpc`** or **`both`** for JSON-RPC
  `server.heartbeat` notifications plus data-idle timeout pruning.
- **`04`** — JSON-RPC 2.0 dispatch, TerraVolt error envelope, rotation logger, RPC plumbing methods
  (`ping`, `echo`, `server.info`, …).

## Automated tests

**GUT** is the planned harness (installation/deferred harness wiring in **`10`**).

## Operational constants

Aligned with **`docs/tasklist/00`** §0.3: **`6505`**, **`user://mcp_log.txt`**, TerraVolt app error
bucket **`-33000`…`-33999`**.
