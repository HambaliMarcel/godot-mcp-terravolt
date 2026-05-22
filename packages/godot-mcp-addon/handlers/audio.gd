@tool
extends RefCounted
class_name TerravoltAudioHandlers

const _Utils := preload("./handler_utils.gd")
const _Audio := preload("./audio_helpers.gd")

var _dispatcher: TerravoltDispatcher
var _logger: TerravoltLogger


func attach(dispatcher: TerravoltDispatcher, logger: TerravoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var bus := {"type": "string"}
	var bus_ref: Variant = {"oneOf": [{"type": "string"}, {"type": "integer"}]}
	_dispatcher.register("audio.list_buses", _schema({}), _h_list_buses)
	_dispatcher.register(
		"audio.add_bus",
		_schema({"name": bus, "send_to": bus, "index": {"type": "integer"}}, ["name"]),
		_h_add_bus
	)
	_dispatcher.register(
		"audio.remove_bus",
		_schema({"name": bus, "index": {"type": "integer"}, "reassign_sends_to": bus}),
		_h_remove_bus
	)
	_dispatcher.register(
		"audio.set_bus",
		_schema(
			{
				"bus": bus_ref,
				"patch": {
					"type": "object",
					"properties": {
						"volume_db": {"type": "number"},
						"mute": {"type": "boolean"},
						"solo": {"type": "boolean"},
						"bypass_effects": {"type": "boolean"},
						"send_to": bus,
					},
				},
			},
			["bus", "patch"]
		),
		_h_set_bus
	)
	_dispatcher.register(
		"audio.add_effect",
		_schema(
			{
				"bus": bus_ref,
				"kind": {"type": "string"},
				"params": {"type": "object"},
				"position": {"type": "integer"},
			},
			["bus", "kind"]
		),
		_h_add_effect
	)
	_dispatcher.register(
		"audio.preview_play",
		_schema(
			{
				"stream_path": {"type": "string", "minLength": 1},
				"bus": bus,
				"volume_db": {"type": "number"},
				"pitch_scale": {"type": "number"},
				"duration_s": {"type": "number"},
			},
			["stream_path"]
		),
		_h_preview_play
	)


func _schema(props: Dictionary, required: Array = []) -> Dictionary:
	var s := {"type": "object", "properties": props, "additionalProperties": false}
	if not required.is_empty():
		s["required"] = required
	return s


func _tree() -> SceneTree:
	var plug := _Utils.editor_plugin(_dispatcher)
	if plug == null:
		return Engine.get_main_loop() as SceneTree
	var base := plug.get_editor_interface().get_base_control()
	return base.get_tree() if base else Engine.get_main_loop() as SceneTree


func _wrap(g: Dictionary) -> Dictionary:
	if g.get("ok", false):
		return {"ok": true, "result": g.get("result", {})}
	return _err(int(g.get("code", -33974)), str(g.get("message", "audio.error")))


func _err(code: int, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": TerravoltErrors.tv_rpc_error(code, message, message, {}),
	}


func _h_list_buses(_ctx: Dictionary) -> Dictionary:
	return _wrap(_Audio.list_buses())


func _h_add_bus(ctx: Dictionary) -> Dictionary:
	return _wrap(_Audio.add_bus(_Utils.params_dict(ctx)))


func _h_remove_bus(ctx: Dictionary) -> Dictionary:
	return _wrap(_Audio.remove_bus(_Utils.params_dict(ctx)))


func _h_set_bus(ctx: Dictionary) -> Dictionary:
	return _wrap(_Audio.set_bus(_Utils.params_dict(ctx)))


func _h_add_effect(ctx: Dictionary) -> Dictionary:
	return _wrap(_Audio.add_effect(_Utils.params_dict(ctx)))


func _h_preview_play(_ctx: Dictionary) -> Dictionary:
	return _wrap(_Audio.preview_play(_Utils.params_dict(_ctx), _tree()))
