@tool
extends RefCounted
class_name TerravoltMacroHelpers

## Macro orchestrator — composes lower-level helpers internally (task 24).

const ADDON_MACROS := "res://addons/terravolt_mcp/macros"
const USER_MACROS := "res://terravolt/macros"

const _Err := preload("../error_codes.gd")
const _Utils := preload("./handler_utils.gd")
const _Runner := preload("./macro_runner.gd")


static func execute(macro_name: String, params: Dictionary, tree: SceneTree) -> Dictionary:
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	var runner = _Runner.new(macro_name, params, tree)
	match macro_name:
		"player_controller_2d":
			return _run_player_controller_2d(runner)
		"dialog_system":
			return _run_dialog_system(runner)
		"hud_health_score":
			return _run_hud_health_score(runner)
		"player_controller_3d", "enemy_with_state_machine", "enemy_wave_spawner", "inventory_system", "save_load_system", "settings_menu", "main_menu", "pause_overlay", "day_night_cycle", "basic_2d_level", "basic_3d_level", "localization_setup":
			return _run_stub(runner)
		_:
			return runner.fail(_Err.MACRO_NOT_IMPLEMENTED, "macro.not_implemented")


static func headless_dispatch(method: String, params: Dictionary, tree: SceneTree) -> Dictionary:
	var macro := method.substr("macro.".length())
	var g := execute(macro, params, tree)
	if not g.get("ok", false):
		return {"ok": false, "code": int(g.get("code", -34000)), "message": str(g.get("message", "macro.error"))}
	return {"ok": true, "result": g}


static func template_text(macro: String, file_name: String, fallback: String = "") -> String:
	for base in [USER_MACROS.path_join(macro), ADDON_MACROS.path_join(macro)]:
		var abs := ProjectSettings.globalize_path(base)
		var p := abs.path_join(file_name)
		if FileAccess.file_exists(p):
			return FileAccess.get_file_as_string(p)
	return fallback


static func resolve_scene_path(params: Dictionary) -> String:
	var raw := str(params.get("scene_path", "active"))
	if raw == "active" or raw.is_empty():
		var main := str(ProjectSettings.get_setting("application/run/main_scene", ""))
		if not main.is_empty():
			return main
		return "res://main.tscn"
	return _Utils.resolve_resource_path(raw)


static func _run_stub(runner) -> Dictionary:
	runner.plan("macro.stub", {"macro": runner.macro_name}, "planned scaffold — not implemented")
	if runner.dry_run:
		return runner.result("%s dry-run preview (stub)" % runner.macro_name)
	return runner.fail(_Err.MACRO_NOT_IMPLEMENTED, "macro.not_implemented")


static func _run_player_controller_2d(runner) -> Dictionary:
	var player_name := str(runner.params.get("name", "Player"))
	var with_sprite := bool(runner.params.get("with_sprite", true))
	var with_camera := bool(runner.params.get("camera", true))
	var scene_path := resolve_scene_path(runner.params)
	var script_path := "res://scripts/%s.gd" % player_name
	var tpl := template_text("player_controller_2d", "Player.gd.template", _default_player_2d_script())
	var w: Dictionary = runner.write_file(script_path, tpl, "create_only")
	if not w.get("ok", true):
		return w
	var actions: Array = runner.params.get("input_actions", ["move_left", "move_right", "jump"]) as Array
	var key_map := {"move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE}
	for act_v in actions:
		var act := str(act_v)
		var key: Key = key_map.get(act, KEY_A) as Key
		var ig: Dictionary = runner.ensure_input_action(act, key)
		if not ig.get("ok", true):
			return ig
	if not runner.dry_run:
		var eg: Dictionary = runner.ops_ensure()
		if not eg.get("ok", true):
			return eg
	var add_body: Dictionary = runner.add_node(".", "CharacterBody2D", player_name)
	if not add_body.get("ok", true):
		return add_body
	var player_path := str(add_body.get("path", player_name))
	runner.add_node(player_path, "CollisionShape2D", "CollisionShape2D")
	if not runner.dry_run:
		var ops := _Runner._cat()
		if ops != null:
			var col: Node = ops.resolve_node("%s/CollisionShape2D" % player_path)
			if col is CollisionShape2D:
				var cap := CapsuleShape2D.new()
				cap.radius = 8.0
				cap.height = 24.0
				(col as CollisionShape2D).shape = cap
	if with_sprite:
		runner.add_node(player_path, "AnimatedSprite2D", "AnimatedSprite2D")
	if with_camera:
		runner.add_node(player_path, "Camera2D", "Camera2D")
	var attach: Dictionary = runner.attach_script(player_path, script_path)
	if not attach.get("ok", true):
		return attach
	var save: Dictionary = runner.save_active_scene(scene_path)
	if not save.get("ok", true):
		return save
	return runner.result("2D platformer player '%s' scaffolded" % player_name)


static func _run_dialog_system(runner) -> Dictionary:
	var ui_path := "res://ui/DialogUI.tscn"
	var runner_path := "res://scripts/DialogRunner.gd"
	var dialog_path := "res://dialogs/intro.tres"
	var typewriter := int(runner.params.get("typewriter_chars_per_s", 40))
	var runner_src := template_text("dialog_system", "DialogRunner.gd.template", _default_dialog_runner(typewriter))
	var ui_src := template_text("dialog_system", "DialogUI.gd.template", _default_dialog_ui_script(typewriter))
	for step in [
		runner.write_file(runner_path, runner_src, "create_only"),
		runner.add_autoload("DialogRunner", runner_path),
		runner.write_file("res://scripts/DialogUI.gd", ui_src, "create_only"),
	]:
		if not step.get("ok", true):
			return step
	runner.plan("scene.create", {"path": ui_path}, "dialog UI scene")
	runner.plan("resource.create", {"path": dialog_path}, "starter dialog lines")
	if runner.dry_run:
		runner.track_created("scene", ui_path)
		runner.track_created("resource", dialog_path)
		return runner.result("Dialog system dry-run (%d ops)" % runner.ops_plan.size())
	var eg: Dictionary = runner.ops_ensure()
	if not eg.get("ok", true):
		return eg
	var layer := CanvasLayer.new()
	layer.name = "DialogUI"
	var panel := PanelContainer.new()
	panel.name = "Panel"
	var body := RichTextLabel.new()
	body.name = "Body"
	body.text = "Hello, traveler."
	panel.add_child(body)
	body.owner = layer
	panel.owner = layer
	layer.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	var ui_script: Script = load(_Utils.resolve_resource_path("res://scripts/DialogUI.gd")) as Script
	if ui_script:
		layer.set_script(ui_script)
	var intro := "[gd_resource type=\"Resource\" format=3]\n\n[resource]\nlines = [\"Welcome.\", \"Press continue.\"]\n"
	var intro_w: Dictionary = runner.write_file(dialog_path, intro, "create_only")
	if not intro_w.get("ok", true):
		return intro_w
	var scene_save: Dictionary = runner.save_packed_scene(ui_path, layer)
	if not scene_save.get("ok", true):
		return scene_save
	return runner.result("Dialog system scaffolded with UI + autoload")


static func _run_hud_health_score(runner) -> Dictionary:
	var hud_path := "res://ui/HUD.tscn"
	var hud_script_path := "res://scripts/HUD.gd"
	var tpl := template_text("hud_health_score", "HUD.gd.template", _default_hud_script())
	var w: Dictionary = runner.write_file(hud_script_path, tpl, "create_only")
	if not w.get("ok", true):
		return w
	runner.plan("scene.create", {"path": hud_path}, "HUD scene")
	if runner.dry_run:
		runner.track_created("scene", hud_path)
		runner.plan("node.add", {"parent_path": ".", "type": "CanvasLayer", "name": "HUD"}, "instance HUD in active scene")
		return runner.result("HUD dry-run preview")
	var eg: Dictionary = runner.ops_ensure()
	if not eg.get("ok", true):
		return eg
	var layer := CanvasLayer.new()
	layer.name = "HUDRoot"
	var bar := ProgressBar.new()
	bar.name = "HealthBar"
	bar.max_value = 100.0
	bar.value = 100.0
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var score := Label.new()
	score.name = "ScoreLabel"
	score.text = "Score: 0"
	layer.add_child(bar)
	layer.add_child(score)
	bar.owner = layer
	score.owner = layer
	var hud_script: Script = load(_Utils.resolve_resource_path(hud_script_path)) as Script
	if hud_script:
		layer.set_script(hud_script)
	var save_hud: Dictionary = runner.save_packed_scene(hud_path, layer)
	if not save_hud.get("ok", true):
		return save_hud
	var add: Dictionary = runner.add_node(".", "CanvasLayer", "HUD")
	if not add.get("ok", true):
		return add
	var save_scene: Dictionary = runner.save_active_scene(resolve_scene_path(runner.params))
	if not save_scene.get("ok", true):
		return save_scene
	return runner.result("HUD with health bar + score scaffolded")


static func _default_player_2d_script() -> String:
	return """extends CharacterBody2D

signal health_changed(current: int, maximum: int)

@export var move_speed: float = 220.0
@export var jump_velocity: float = -360.0
@export var gravity: float = 980.0
@export var coyote_time_s: float = 0.12
@export var jump_buffer_s: float = 0.1

var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0


func _ready() -> void:
	health_changed.emit(100, 100)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		_coyote_left = maxf(_coyote_left - delta, 0.0)
	else:
		_coyote_left = coyote_time_s

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_left = jump_buffer_s
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
"""


static func _default_dialog_runner(chars_per_s: int) -> String:
	return """extends Node

signal line_started(text: String)
signal line_finished

@export var typewriter_chars_per_s: int = %d

var _lines: Array[String] = []


func load_lines_from_path(path: String) -> void:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res != null and res.get("lines") != null:
			_lines = res.get("lines")


func play() -> void:
	for line in _lines:
		line_started.emit(line)
		line_finished.emit()
""" % chars_per_s


static func _default_dialog_ui_script(chars_per_s: int) -> String:
	return """extends CanvasLayer

@export var typewriter_chars_per_s: int = %d


func _ready() -> void:
	var runner := get_node_or_null("/root/DialogRunner")
	if runner != null and runner.has_signal("line_started"):
		runner.line_started.connect(_on_line)
		runner.play()


func _on_line(text: String) -> void:
	var body := get_node_or_null("Panel/Body")
	if body is RichTextLabel:
		(body as RichTextLabel).text = text
""" % chars_per_s


static func _default_hud_script() -> String:
	return """extends CanvasLayer

@export var player_path: NodePath = ^"../Player"

@onready var _bar: ProgressBar = $HealthBar
@onready var _score: Label = $ScoreLabel


func _ready() -> void:
	var player := get_node_or_null(player_path)
	if player != null and player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
	_on_health_changed(100, 100)


func _on_health_changed(current: int, maximum: int) -> void:
	if _bar:
		_bar.max_value = maximum
		_bar.value = current
"""
