@tool
extends RefCounted
class_name TerravoltAndroidHandlers

const _Utils := preload("./handler_utils.gd")
const _H := preload("./android_helpers.gd")

var _dispatcher: TerravoltDispatcher
var _logger: TerravoltLogger


func attach(dispatcher: TerravoltDispatcher, logger: TerravoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	_dispatcher.register("android.list_devices", _schema({}, []), _h_list_devices)
	_dispatcher.register(
		"android.preset_info",
		_schema(
			{
				"preset_name": {"type": "string"},
				"preset_index": {"type": "integer", "minimum": -1},
			},
			[]
		),
		_h_preset_info
	)
	_dispatcher.register(
		"android.deploy",
		_schema(
			{
				"preset_name": {"type": "string"},
				"preset_index": {"type": "integer", "minimum": -1},
				"device_serial": {"type": "string"},
				"debug": {"type": "boolean"},
				"launch": {"type": "boolean"},
				"skip_export": {"type": "boolean"},
			},
			[]
		),
		_h_deploy
	)


func _schema(props: Dictionary, required: Array = []) -> Dictionary:
	var s := {"type": "object", "properties": props, "additionalProperties": false}
	if not required.is_empty():
		s["required"] = required
	return s


func _wrap(g: Dictionary) -> Dictionary:
	if g.get("ok", false):
		return {"ok": true, "result": g.get("result", {})}
	return _err(int(g.get("code", -33997)), str(g.get("message", "android.error")))


func _h_list_devices(ctx: Dictionary) -> Dictionary:
	return _wrap(_H.list_devices(_Utils.params_dict(ctx)))


func _h_preset_info(ctx: Dictionary) -> Dictionary:
	return _wrap(_H.preset_info(_Utils.params_dict(ctx)))


func _h_deploy(ctx: Dictionary) -> Dictionary:
	return _wrap(_H.deploy(_Utils.params_dict(ctx)))


func _err(code: int, symbol: String) -> Dictionary:
	return {"ok": false, "error": TerravoltErrors.tv_rpc_error(code, symbol, symbol, {})}
