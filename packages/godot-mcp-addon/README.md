# Godot MCP addon (`packages/godot-mcp-addon`)

Terravolt daemon code that runs **inside Godot 4 Editor** (`EditorPlugin`). Exposes
JSON-RPC/WebSocket (**`:6505`**) consumed exclusively by the Node router.

## Coding entry point

Detailed implementation kicks off at **`docs/tasklist/02-godot-plugin-foundation.md`** followed by
websocket + dispatcher tasks (`03`–`04`).

## Planned surface (mirror of task `01` §1.6.4)

| Path            | Responsibility                                                             |
| --------------- | -------------------------------------------------------------------------- |
| `plugin.cfg`    | Machine metadata + script alias — **written in task `02`**, **not before** |
| `main.gd`       | `@tool` EditorPlugin root                                                  |
| `mcp_server.gd` | Built-in multiplayer WebSocket server (`03`)                               |
| `dispatcher.gd` | Central JSON-RPC dispatch (`04`)                                           |
| `logging.gd`    | Append-only **`user://mcp_log.txt`** sink                                  |
| `handlers/`     | Per-category opcode handlers populated in **`08`**                         |
| `schemas/`      | Optional mirrored JSON schemas for daemon-side validation                  |
| `editor_ui/`    | Optional docks / inspectors (late **`02`** or polish sprint)               |

## Dev workflow rules

1. **Never hand-edit `.tscn/.tres` on disk.** Use **`EditorInterface` / PackedScene APIs**
   (`00 §0.7`) when coding begins.
2. **Godot’s official GDScript style guide applies.** Tabs for indentation, `snake_case`, static
   typing enforced in shipped code (`00 Appendix A`).
3. **Prefer symlinks**, fall back to copy + tooling when Windows blocks symlink
   creation.`addon:link` / `addon:unlink` helpers ship in **`02`** (planned scripts already reserved
   at repo root).

### Recommended local loop

1. Create a disposable Godot 4 `.NET-capable` project somewhere **outside** this monorepo.
2. Use **Project → Project Settings → Plugins → Create Plugin** once to seed `addons/<slug>/`.
3. Point that folder at this package via symlink (preferred) following instructions that land in
   **`02`**.
4. Enable the addon in Plugin settings; edits in this repo propagate immediately via symlink/mount.

Upstream manual references live under **`references/godot-docs/`** (local clone — **gitignored**)
for Appendix alignment.

Pre–Phase&nbsp;1 contracts (ports/logging/MCP transports) remain locked per
**`docs/srs/00-fundamentals-contract.md`** and \*\*`docs/tasklist/00-foundation-and-contracts.md`.

### Test harness decision

Defer **GUT vs gdUnit4** until **`02`** (`01 §1.8`).
