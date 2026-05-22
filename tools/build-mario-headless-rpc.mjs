import { cpSync, mkdirSync, rmSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { HeadlessCoordinator } from "../packages/mcp-server/dist/headless/headlessCoordinator.js";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const fixture = join(repoRoot, "tests", "_fixtures", "empty");
const laminer = "H:/Laminer/laminer";
const godotBinary =
  process.env.TERRAVOLT_GODOT_BINARY ??
  "C:/Users/marce/AppData/Local/Programs/Godot/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe";

const MARIO_SCRIPT = `extends CharacterBody2D

signal reached_goal

@export var move_speed: float = 220.0
@export var jump_velocity: float = -380.0
@export var gravity: float = 980.0

var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _won: bool = false


func _ready() -> void:
	position = Vector2(80, 280)
	_build_visual()
	call_deferred("_build_level")
	call_deferred("_build_hud")


func _physics_process(delta: float) -> void:
	if _won:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
		_coyote_left = maxf(_coyote_left - delta, 0.0)
	else:
		_coyote_left = 0.12

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_left = 0.1
	else:
		_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)

	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_left = 0.0
		_coyote_left = 0.0

	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		velocity.x = direction * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 8.0)

	move_and_slide()


func _build_visual() -> void:
	var body := ColorRect.new()
	body.name = "Body"
	body.size = Vector2(28, 36)
	body.position = Vector2(-14, -36)
	body.color = Color(0.92, 0.18, 0.14)
	add_child(body)
	var hat := ColorRect.new()
	hat.name = "Hat"
	hat.size = Vector2(32, 10)
	hat.position = Vector2(-16, -42)
	hat.color = Color(0.75, 0.1, 0.08)
	add_child(hat)


func _build_level() -> void:
	var parent := get_parent()
	_add_platform(parent, Vector2(640, 420), Vector2(1280, 40), Color(0.35, 0.55, 0.22), "Ground")
	_add_platform(parent, Vector2(320, 320), Vector2(180, 24), Color(0.55, 0.35, 0.18), "MidPlatform")
	_add_platform(parent, Vector2(560, 250), Vector2(140, 20), Color(0.55, 0.35, 0.18), "HighPlatform")
	_add_platform(parent, Vector2(860, 300), Vector2(160, 22), Color(0.55, 0.35, 0.18), "Bridge")
	_add_goal(parent, Vector2(1180, 360))


func _add_platform(parent: Node, center: Vector2, size: Vector2, color: Color, platform_name: String) -> void:
	var body := StaticBody2D.new()
	body.name = platform_name
	body.position = center - Vector2(size.x * 0.5, size.y * 0.5)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var visual := ColorRect.new()
	visual.size = size
	visual.color = color
	body.add_child(visual)
	parent.add_child(body)


func _add_goal(parent: Node, center: Vector2) -> void:
	var area := Area2D.new()
	area.name = "GoalFlag"
	area.position = center
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 80)
	shape.shape = rect
	area.add_child(shape)
	var pole := ColorRect.new()
	pole.size = Vector2(6, 80)
	pole.color = Color(0.9, 0.85, 0.2)
	area.add_child(pole)
	var flag := ColorRect.new()
	flag.size = Vector2(36, 22)
	flag.position = Vector2(6, 4)
	flag.color = Color(0.1, 0.55, 0.95)
	area.add_child(flag)
	area.body_entered.connect(_on_goal_entered)
	parent.add_child(area)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	var start_label := Label.new()
	start_label.name = "StartLabel"
	start_label.text = "START: Run right and reach the flag!  (A/D + Space)"
	start_label.position = Vector2(16, 12)
	start_label.add_theme_color_override("font_color", Color.WHITE)
	start_label.add_theme_color_override("font_outline_color", Color.BLACK)
	start_label.add_theme_constant_override("outline_size", 4)
	hud.add_child(start_label)
	var win_label := Label.new()
	win_label.name = "WinLabel"
	win_label.text = "YOU WIN! Press R to restart."
	win_label.position = Vector2(420, 220)
	win_label.visible = false
	win_label.add_theme_color_override("font_color", Color(1, 0.95, 0.2))
	win_label.add_theme_color_override("font_outline_color", Color.BLACK)
	win_label.add_theme_constant_override("outline_size", 6)
	win_label.add_theme_font_size_override("font_size", 36)
	hud.add_child(win_label)
	get_tree().root.add_child(hud)


func _on_goal_entered(body: Node2D) -> void:
	if body != self or _won:
		return
	_won = true
	velocity = Vector2.ZERO
	reached_goal.emit()
	var hud := get_tree().root.get_node_or_null("HUD/WinLabel")
	if hud is Label:
		(hud as Label).visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_R):
		get_tree().reload_current_scene()
`;

async function rpc(coordinator, method, params = {}) {
  const res = await coordinator.rpc(method, params);
  console.log(`✓ ${method}`, JSON.stringify(res).slice(0, 200));
  return res;
}

const coordinator = new HeadlessCoordinator(
  {
    godotBinaryEnv: godotBinary,
    projectPath: fixture,
    headlessBootTimeoutMs: 45_000,
    headlessOpTimeoutMs: 60_000,
  },
  (msg, detail) => console.error(`[${msg}]`, detail ?? ""),
  import.meta.url,
);

try {
  await coordinator.ensureSession(fixture);
  const levelPath = "res://scenes/mario_level.tscn";
  await rpc(coordinator, "scene.create", {
    path: levelPath,
    root_type: "Node2D",
    root_name: "MarioLevel",
  });
  await rpc(coordinator, "project.set_main_scene", { path: levelPath });
  await rpc(coordinator, "macro.player_controller_2d", {
    scene_path: levelPath,
    name: "Mario",
    with_sprite: false,
    camera: true,
    confirm_high_risk: true,
  });
  await rpc(coordinator, "script.write", {
    path: "res://scripts/Mario.gd",
    content: MARIO_SCRIPT,
    mode: "overwrite",
  });
  await rpc(coordinator, "script.validate", { path: "res://scripts/Mario.gd" });
  await rpc(coordinator, "scene.validate", { path: levelPath });

  for (const rel of ["scenes/mario_level.tscn", "scripts/Mario.gd"]) {
    const src = join(fixture, rel.replace(/\//g, "\\"));
    const dst = join(laminer, rel.replace(/\//g, "\\"));
    mkdirSync(dirname(dst), { recursive: true });
    cpSync(src, dst, { force: true });
    console.log("copied", rel, "-> Laminer");
  }

  console.log("\nMCP headless build succeeded; assets copied to Laminer.");
} catch (err) {
  console.error("BUILD FAILED", err);
  process.exitCode = 1;
} finally {
  await coordinator.stop(true);
}
