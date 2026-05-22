@tool
extends RefCounted
class_name TerraVoltExportHandlers

const _Utils := preload("./handler_utils.gd")
const _H := preload("./export_helpers.gd")

var _dispatcher: TerraVoltDispatcher
var _logger: TerraVoltLogger


func attach(dispatcher: TerraVoltDispatcher, logger: TerraVoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var rp := {"type": "string", "minLength": 1, "pattern": "^(res://|user://|/|[A-Za-z]:)"}
	_dispatcher.register("export.list_presets", _schema({}, []), _h_list_presets)
	_dispatcher.register(
		"export.build",
		_schema(
			{
				"preset": {"type": "string"},
				"debug": {"type": "boolean"},
				"output_path": rp,
				"with_pck_only": {"type": "boolean"},
				"platform_args": {"type": "object"},
				"timeout_ms": {"type": "integer"},
			},
			["preset"]
		),
		_h_build
	)
	_dispatcher.register("export.template_info", _schema({}, []), _h_template_info)


func _schema(props: Dictionary, required: Array = []) -> Dictionary:
	var s := {"type": "object", "properties": props, "additionalProperties": false}
	if not required.is_empty():
		s["required"] = required
	return s


func _wrap(g: Dictionary) -> Dictionary:
	if g.get("ok", false):
		return {"ok": true, "result": g.get("result", {})}
	return _err(int(g.get("code", -33994)), str(g.get("message", "export.error")))


func _h_list_presets(_ctx: Dictionary) -> Dictionary:
	return _wrap(_H.list_presets())


func _h_build(ctx: Dictionary) -> Dictionary:
	var g := _H.build(_Utils.params_dict(ctx))
	if not g.get("ok", false) and g.has("code"):
		return _err(int(g.get("code", -33994)), str(g.get("message", "export.error")))
	var res: Dictionary = g.get("result", {})
	return {"ok": res.get("ok", false), "result": res}


func _h_template_info(_ctx: Dictionary) -> Dictionary:
	return _wrap(_H.template_info())


func _err(code: int, symbol: String) -> Dictionary:
	return {"ok": false, "error": TerraVoltErrors.tv_rpc_error(code, symbol, symbol, {})}
