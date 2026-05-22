@tool
extends RefCounted
class_name TerraVoltProfileHandlers

const _Utils := preload("./handler_utils.gd")
const _H := preload("./profile_helpers.gd")

var _dispatcher: TerraVoltDispatcher
var _logger: TerraVoltLogger


func attach(dispatcher: TerraVoltDispatcher, logger: TerraVoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	_dispatcher.register(
		"profile.monitor",
		_schema({"keys": {"type": "array"}, "window_ms": {"type": "integer"}, "samples": {"type": "integer"}}, []),
		_h_monitor
	)
	_dispatcher.register(
		"profile.flamegraph",
		_schema(
			{
				"duration_s": {"type": "number"},
				"kind": {"type": "string"},
				"include_native": {"type": "boolean"},
			},
			[]
		),
		_h_flamegraph
	)


func _schema(props: Dictionary, required: Array = []) -> Dictionary:
	var s := {"type": "object", "properties": props, "additionalProperties": false}
	if not required.is_empty():
		s["required"] = required
	return s


func _wrap(g: Dictionary) -> Dictionary:
	if g.get("ok", false):
		return {"ok": true, "result": g.get("result", {})}
	return _err(int(g.get("code", -33993)), str(g.get("message", "profile.error")))


func _h_monitor(ctx: Dictionary) -> Dictionary:
	return _wrap(_H.monitor(_Utils.params_dict(ctx)))


func _h_flamegraph(ctx: Dictionary) -> Dictionary:
	return _wrap(_H.flamegraph(_Utils.params_dict(ctx)))


func _err(code: int, symbol: String) -> Dictionary:
	return {"ok": false, "error": TerraVoltErrors.tv_rpc_error(code, symbol, symbol, {})}
