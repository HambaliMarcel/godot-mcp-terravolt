#!/usr/bin/env node
/**
 * Builds a simple Mario-style platformer in Laminer using Terravolt MCP tools (headless).
 */
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const routerEntry = join(repoRoot, "packages", "mcp-server", "dist", "index.js");

const env = {
  ...process.env,
  TERRAVOLT_GODOT_BINARY:
    process.env.TERRAVOLT_GODOT_BINARY ??
    "C:/Users/marce/AppData/Local/Programs/Godot/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe",
  TERRAVOLT_PROJECT_PATH: process.env.TERRAVOLT_PROJECT_PATH ?? "H:/Laminer/laminer",
  TERRAVOLT_LOG_LEVEL: "warn",
};

const transport = new StdioClientTransport({
  command: process.execPath,
  args: [routerEntry],
  env,
  stderr: "pipe",
});

const client = new Client(
  { name: "mario-demo-builder", version: "1" },
  { capabilities: { tools: {} } },
);

function payload(res) {
  if (res.structuredContent) return res.structuredContent;
  try {
    return JSON.parse(res.content?.[0]?.text ?? "{}");
  } catch {
    return { raw: res };
  }
}

async function tool(name, args = {}) {
  const res = await client.callTool({ name, arguments: args });
  const data = payload(res);
  if (data?.ok === false) {
    throw new Error(`${name} failed: ${JSON.stringify(data)}`);
  }
  console.log(`✓ ${name}`, data?.result?.summary ?? data?.message ?? "");
  return data;
}

const MARIO_SCRIPT = `extends CharacterBody2D

signal reached_goal

@export var move_speed: float = 220.0
@export var jump_velocity: float = -380.0
@export var gravity: float = 980.0

var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _won: bool = false


func _ready() -> void:
\tposition = Vector2(80, 280)
\t_build_visual()
\t_build_level()
\t_build_hud()


func _physics_process(delta: float) -> void:
\tif _won:
\t\treturn
\tif not is_on_floor():
\t\tvelocity.y += gravity * delta
\t\t_coyote_left = maxf(_coyote_left - delta, 0.0)
\telse:
\t\t_coyote_left = 0.12

\tif Input.is_action_just_pressed("jump"):
\t\t_jump_buffer_left = 0.1
\telse:
\t\t_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)

\tif _jump_buffer_left > 0.0 and _coyote_left > 0.0:
\t\tvelocity.y = jump_velocity
\t\t_jump_buffer_left = 0.0
\t\t_coyote_left = 0.0

\tvar direction := Input.get_axis("move_left", "move_right")
\tif direction != 0.0:
\t\tvelocity.x = direction * move_speed
\telse:
\t\tvelocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 8.0)

\tmove_and_slide()


func _build_visual() -> void:
\tvar body := ColorRect.new()
\tbody.name = "Body"
\tbody.size = Vector2(28, 36)
\tbody.position = Vector2(-14, -36)
\tbody.color = Color(0.92, 0.18, 0.14)
\tadd_child(body)
\tvar hat := ColorRect.new()
\that.name = "Hat"
\that.size = Vector2(32, 10)
\that.position = Vector2(-16, -42)
\that.color = Color(0.75, 0.1, 0.08)
\tadd_child(hat)


func _build_level() -> void:
\tvar parent := get_parent()
\t_add_platform(parent, Vector2(640, 420), Vector2(1280, 40), Color(0.35, 0.55, 0.22), "Ground")
\t_add_platform(parent, Vector2(320, 320), Vector2(180, 24), Color(0.55, 0.35, 0.18), "MidPlatform")
\t_add_platform(parent, Vector2(560, 250), Vector2(140, 20), Color(0.55, 0.35, 0.18), "HighPlatform")
\t_add_platform(parent, Vector2(860, 300), Vector2(160, 22), Color(0.55, 0.35, 0.18), "Bridge")
\t_add_goal(parent, Vector2(1180, 360))


func _add_platform(parent: Node, center: Vector2, size: Vector2, color: Color, platform_name: String) -> void:
\tvar body := StaticBody2D.new()
\tbody.name = platform_name
\tbody.position = center - Vector2(size.x * 0.5, size.y * 0.5)
\tvar shape := CollisionShape2D.new()
\tvar rect := RectangleShape2D.new()
\trect.size = size
\tshape.shape = rect
\tbody.add_child(shape)
\tvar visual := ColorRect.new()
\tvisual.size = size
\tvisual.color = color
\tbody.add_child(visual)
\tparent.add_child(body)


func _add_goal(parent: Node, center: Vector2) -> void:
\tvar area := Area2D.new()
\tarea.name = "GoalFlag"
\tarea.position = center
\tvar shape := CollisionShape2D.new()
\tvar rect := RectangleShape2D.new()
\trect.size = Vector2(32, 80)
\tshape.shape = rect
\tarea.add_child(shape)
\tvar pole := ColorRect.new()
\tpole.size = Vector2(6, 80)
\tpole.color = Color(0.9, 0.85, 0.2)
\tarea.add_child(pole)
\tvar flag := ColorRect.new()
\tflag.size = Vector2(36, 22)
\tflag.position = Vector2(6, 4)
\tflag.color = Color(0.1, 0.55, 0.95)
\tarea.add_child(flag)
\tarea.body_entered.connect(_on_goal_entered)
\tparent.add_child(area)


func _build_hud() -> void:
\tvar hud := CanvasLayer.new()
\thud.name = "HUD"
\tvar start_label := Label.new()
\tstart_label.name = "StartLabel"
\tstart_label.text = "START: Run right and reach the flag!  (A/D + Space)"
\tstart_label.position = Vector2(16, 12)
\tstart_label.add_theme_color_override("font_color", Color.WHITE)
\tstart_label.add_theme_color_override("font_outline_color", Color.BLACK)
\tstart_label.add_theme_constant_override("outline_size", 4)
\thud.add_child(start_label)
\tvar win_label := Label.new()
\twin_label.name = "WinLabel"
\twin_label.text = "YOU WIN! Press R to restart."
\twin_label.position = Vector2(420, 220)
\twin_label.visible = false
\twin_label.add_theme_color_override("font_color", Color(1, 0.95, 0.2))
\twin_label.add_theme_color_override("font_outline_color", Color.BLACK)
\twin_label.add_theme_constant_override("outline_size", 6)
\twin_label.add_theme_font_size_override("font_size", 36)
\thud.add_child(win_label)
\tget_tree().root.add_child(hud)


func _on_goal_entered(body: Node2D) -> void:
\tif body != self or _won:
\t\treturn
\t_won = true
\tvelocity = Vector2.ZERO
\treached_goal.emit()
\tvar hud := get_tree().root.get_node_or_null("HUD/WinLabel")
\tif hud is Label:
\t\t(hud as Label).visible = true


func _unhandled_input(event: InputEvent) -> void:
\tif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_R):
\t\tget_tree().reload_current_scene()
`;

await client.connect(transport);
await new Promise((r) => setTimeout(r, 2500));

async function main() {
  try {
    await tool("headless_start_project");
    await tool("project_info");

    const levelPath = "res://scenes/mario_level.tscn";
    await tool("scene_create", {
      path: levelPath,
      root_type: "Node2D",
      root_name: "MarioLevel",
    });
    await tool("project_set_main_scene", { path: levelPath });

    await tool("macro_player_controller_2d", {
      scene_path: levelPath,
      name: "Mario",
      with_sprite: false,
      camera: true,
      confirm_high_risk: true,
    });

    await tool("script_write", {
      path: "res://scripts/Mario.gd",
      content: MARIO_SCRIPT,
      mode: "overwrite",
    });

    await tool("script_validate", { path: "res://scripts/Mario.gd" });
    await tool("scene_validate", { path: levelPath });
    await tool("project_set_main_scene", { path: levelPath, validate: true });

    const health = await tool("tools_health");
    console.log("\n=== Build complete ===");
    console.log(JSON.stringify(health?.result ?? health, null, 2));
  } finally {
    await client.close();
  }
}

await main();
