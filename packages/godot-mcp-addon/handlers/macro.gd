@tool
extends RefCounted
class_name TerravoltMacroHandlers

const _Utils := preload("./handler_utils.gd")
const _Macro := preload("./macro_helpers.gd")

var _dispatcher: TerravoltDispatcher
var _logger: TerravoltLogger


func attach(dispatcher: TerravoltDispatcher, logger: TerravoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var common := _common_props()
	_register("macro.player_controller_2d", _merge(common, {"name": {"type": "string"}, "with_sprite": {"type": "boolean"}, "camera": {"type": "boolean"}, "animation_set": {"type": "string"}, "input_actions": {"type": "array"}}), "player_controller_2d")
	_register("macro.player_controller_3d", _merge(common, {"name": {"type": "string"}, "perspective": {"type": "string"}, "with_mesh": {"type": "boolean"}, "camera_offset": {"type": "object"}, "with_jump": {"type": "boolean"}, "input_actions": {"type": "array"}}), "player_controller_3d")
	_register("macro.enemy_with_state_machine", _merge(common, {"name": {"type": "string"}, "dimension": {"type": "string"}, "patrol_radius": {"type": "number"}, "aggro_radius": {"type": "number"}, "attack_range": {"type": "number"}, "health": {"type": "integer"}}), "enemy_with_state_machine")
	_register("macro.enemy_wave_spawner", _merge(common, {"enemy_scene_path": {"type": "string"}, "spawn_points": {"type": "array"}, "wave_count": {"type": "integer"}, "base_enemies": {"type": "integer"}, "scale_per_wave": {"type": "number"}, "between_wave_pause_s": {"type": "number"}}), "enemy_wave_spawner", ["enemy_scene_path"])
	_register("macro.dialog_system", _merge(common, {"theme_path": {"type": "string"}, "with_portrait": {"type": "boolean"}, "with_choices": {"type": "boolean"}, "typewriter_chars_per_s": {"type": "integer"}}), "dialog_system")
	_register("macro.inventory_system", _merge(common, {"slot_count": {"type": "integer"}, "stackable": {"type": "boolean"}, "with_drag_drop": {"type": "boolean"}, "theme_path": {"type": "string"}}), "inventory_system")
	_register("macro.save_load_system", _schema({"dry_run": {"type": "boolean"}, "confirm_high_risk": {"type": "boolean"}, "scope": {"type": "string"}, "slot_count": {"type": "integer"}, "include_screenshot": {"type": "boolean"}}), "save_load_system")
	_register("macro.settings_menu", _schema({"dry_run": {"type": "boolean"}, "confirm_high_risk": {"type": "boolean"}, "theme_path": {"type": "string"}, "output_path": {"type": "string"}, "categories": {"type": "array"}, "bind_to_main_menu": {"type": "string"}}), "settings_menu")
	_register("macro.main_menu", _schema({"dry_run": {"type": "boolean"}, "confirm_high_risk": {"type": "boolean"}, "theme_path": {"type": "string"}, "output_path": {"type": "string"}, "with_continue": {"type": "boolean"}, "with_credits": {"type": "boolean"}, "start_scene_path": {"type": "string"}}), "main_menu")
	_register("macro.pause_overlay", _merge(common, {"theme_path": {"type": "string"}, "options": {"type": "array"}}), "pause_overlay")
	_register("macro.hud_health_score", _merge(common, {"player_path": {"type": "string"}, "theme_path": {"type": "string"}}), "hud_health_score")
	_register("macro.day_night_cycle", _merge(common, {"duration_s": {"type": "number"}, "start_hour": {"type": "number"}, "with_fog": {"type": "boolean"}}), "day_night_cycle")
	_register("macro.basic_2d_level", _schema({"dry_run": {"type": "boolean"}, "confirm_high_risk": {"type": "boolean"}, "output_path": {"type": "string"}, "with_parallax": {"type": "boolean"}, "tileset_path": {"type": "string"}, "level_width_tiles": {"type": "integer"}, "level_height_tiles": {"type": "integer"}}), "basic_2d_level", ["output_path"])
	_register("macro.basic_3d_level", _schema({"dry_run": {"type": "boolean"}, "confirm_high_risk": {"type": "boolean"}, "output_path": {"type": "string"}, "mesh_library_path": {"type": "string"}, "with_sky": {"type": "boolean"}, "size_meters": {"type": "number"}}), "basic_3d_level", ["output_path"])
	_register("macro.localization_setup", _schema({"dry_run": {"type": "boolean"}, "confirm_high_risk": {"type": "boolean"}, "locales": {"type": "array"}, "table_path": {"type": "string"}, "wire_into_ui_root": {"type": "string"}}), "localization_setup")


func _common_props() -> Dictionary:
	return {
		"dry_run": {"type": "boolean"},
		"confirm_high_risk": {"type": "boolean"},
		"scene_path": {"type": "string"},
	}


func _merge(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in extra.keys():
		out[k] = extra[k]
	return out


func _register(method: String, props: Dictionary, macro_id: String, required: Array = []) -> void:
	_dispatcher.register(method, _schema(props, required), func(ctx: Dictionary) -> Dictionary: return _run(ctx, macro_id))


func _schema(props: Dictionary, required: Array = []) -> Dictionary:
	var s := {"type": "object", "properties": props, "additionalProperties": false}
	if not required.is_empty():
		s["required"] = required
	return s


func _run(ctx: Dictionary, macro_id: String) -> Dictionary:
	var params := _Utils.params_dict(ctx)
	var tree := Engine.get_main_loop() as SceneTree
	var g := _Macro.execute(macro_id, params, tree)
	if not g.get("ok", false):
		return {
			"ok": false,
			"error": TerravoltErrors.tv_rpc_error(
				int(g.get("code", TerravoltErrors.MACRO_NOT_IMPLEMENTED)),
				str(g.get("message", "macro.error")),
				str(g.get("message", "macro.error")),
				{"macro": macro_id}
			),
		}
	return {"ok": true, "result": g}
