# Software requirements — TerraVolt Godot MCP

Formal intent: **dual-stack** MCP for Godot 4.x (`.NET-compatible` target), exceeding aggregate
patterns from **`youichi-uda/godot-mcp-pro`**, **`tomyud1/godot-mcp`**, and
**`Coding-Solo/godot-mcp`**.

| Document                                                             | Purpose                                                                                            |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| [system_architecture_blueprint.md](system_architecture_blueprint.md) | Topology: Node MCP (stdio), Godot daemon (WS :6505), headless fallback; JSON-RPC, sync, perf notes |
| [superset_tool_registry.md](superset_tool_registry.md)               | Target tool surface (~200 ops); categorical schemas — implement iteratively                        |
| [execution_roadmap.md](execution_roadmap.md)                         | Phased build: Phase 1 Godot plugin → Phase 2 Node router → tools → optimization                    |
| [**00-fundamentals-contract.md**](00-fundamentals-contract.md)       | **Baseline contracts** locked _before_ Phase 1 coding (constants, gates, layering)                 |

## Reading order

1. Blueprint + fundamentals contract — **why** dual transport and strict JSON-RPC matter.
2. Execution roadmap — **when** each layer ships (do not skip transport verification gates).
3. Tool registry — **what** the long-term surface looks like; wire tools only when the roadmap phase
   allows.

Implement shippable code under **`packages/mcp-server/`** and **`packages/godot-mcp-addon/`**
([packages/README.md](../../packages/README.md)).
