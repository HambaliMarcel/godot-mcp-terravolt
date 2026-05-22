@tool
extends RefCounted
class_name TerravoltThemeUiHandlers

const _Utils := preload("./handler_utils.gd")
const _Ui := preload("./theme_ui_helpers.gd")

var _dispatcher: TerravoltDispatcher
var _logger: TerravoltLogger


func attach(dispatcher: TerravoltDispatcher, logger: TerravoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var rp := {"type": "string", "minLength": 1}
	var target := {
		"type": "object",
		"properties": {"theme_path": rp, "control_path": {"type": "string"}},
		"additionalProperties": false,
	}
	_dispatcher.register(
		"theme_ui.describe",
		_schema({"theme_path": rp, "control_path": {"type": "string"}}),
		_h_describe
	)
	_dispatcher.register(
		"theme_ui.set_color",
		_schema({"target": target, "type": {"type": "string"}, "name": {"type": "string"}, "value": {}}, ["target", "type", "name", "value"]),
		_h_set_color
	)
	_dispatcher.register(
		"theme_ui.set_font",
		_schema(
			{
				"target": target,
				"type": {"type": "string"},
				"name": {"type": "string"},
				"font_path": rp,
				"size": {"type": "integer"},
			},
			["target", "font_path"]
		),
		_h_set_font
	)
	_dispatcher.register(
		"theme_ui.set_stylebox",
		_schema(
			{
				"target": target,
				"type": {"type": "string"},
				"name": {"type": "string"},
				"stylebox": {"type": "object"},
			},
			["target", "type", "name", "stylebox"]
		),
		_h_set_stylebox
	)
	_dispatcher.register(
		"theme_ui.preview",
		_schema({"theme_path": rp, "widgets": {"type": "array"}, "size": {"type": "object"}}, ["theme_path"]),
		_h_preview
	)
	_dispatcher.register(
		"theme_ui.scaffold_screen",
		_schema(
			{
				"output_path": rp,
				"kind": {"type": "string"},
				"theme_path": rp,
				"options": {"type": "object"},
			},
			["output_path", "kind"]
		),
		_h_scaffold
	)


func _schema(props: Dictionary, required: Array = []) -> Dictionary:
	var s := {"type": "object", "properties": props, "additionalProperties": false}
	if not required.is_empty():
		s["required"] = required
	return s


func _scene_root() -> Node:
	var plug := _Utils.editor_plugin(_dispatcher)
	if plug == null:
		return null
	return plug.get_editor_interface().get_edited_scene_root()


func _wrap(g: Dictionary) -> Dictionary:
	if g.get("ok", false):
		return {"ok": true, "result": g.get("result", {})}
	return _err(int(g.get("code", -33965)), str(g.get("message", "theme.error")))


func _h_describe(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	if p.has("control_path") and not str(p.get("control_path", "")).is_empty():
		return _wrap(_Ui.describe(_scene_root(), p))
	return _wrap(_Ui.describe(null, p))


func _h_set_color(ctx: Dictionary) -> Dictionary:
	return _wrap(_Ui.set_color(_scene_root(), _Utils.params_dict(ctx)))


func _h_set_font(ctx: Dictionary) -> Dictionary:
	return _wrap(_Ui.set_font(_scene_root(), _Utils.params_dict(ctx)))


func _h_set_stylebox(ctx: Dictionary) -> Dictionary:
	return _wrap(_Ui.set_stylebox(_scene_root(), _Utils.params_dict(ctx)))


func _h_preview(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var widgets: Array = p.get("widgets", []) as Array
	var size: Dictionary = p.get("size", {}) as Dictionary
	return _wrap(_Ui.preview(str(p.get("theme_path", "")), widgets, size))


func _h_scaffold(ctx: Dictionary) -> Dictionary:
	var g := _Ui.scaffold_screen(_Utils.params_dict(ctx))
	if g.get("ok", false):
		_scan()
	return _wrap(g)


func _scan() -> void:
	if OS.has_feature("editor"):
		var plug := _Utils.editor_plugin(_dispatcher)
		if plug:
			plug.get_editor_interface().get_resource_filesystem().scan()


func _err(code: int, symbol: String) -> Dictionary:
	return {"ok": false, "error": TerravoltErrors.tv_rpc_error(code, symbol, symbol, {})}
