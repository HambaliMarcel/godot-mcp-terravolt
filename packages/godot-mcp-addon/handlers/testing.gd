@tool
extends RefCounted
class_name TerravoltTestingHandlers

const _Utils := preload("./handler_utils.gd")
const _H := preload("./testing_helpers.gd")

var _dispatcher: TerravoltDispatcher
var _logger: TerravoltLogger


func attach(dispatcher: TerravoltDispatcher, logger: TerravoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var rp := {"type": "string", "minLength": 1, "pattern": "^(res://|user://|/|[A-Za-z]:)"}
	var np := {"type": "string", "minLength": 1}
	_dispatcher.register(
		"testing.list_suites",
		_schema({"framework": {"type": "string"}}, []),
		_h_list_suites
	)
	_dispatcher.register(
		"testing.run",
		_schema(
			{
				"framework": {"type": "string"},
				"suites": {"type": "array"},
				"tags": {"type": "array"},
				"parallel": {"type": "boolean"},
				"timeout_ms": {"type": "integer"},
				"fail_fast": {"type": "boolean"},
			},
			[]
		),
		_h_run
	)
	_dispatcher.register(
		"testing.assert_state",
		_schema({"assertions": {"type": "array"}}, ["assertions"]),
		_h_assert_state
	)
	_dispatcher.register(
		"testing.screenshot_compare",
		_schema(
			{
				"source": {"type": "object"},
				"golden_path": rp,
				"tolerance": {"type": "number"},
				"save_diff_to": rp,
			},
			["source", "golden_path"]
		),
		_h_screenshot_compare
	)
	_dispatcher.register("testing.list_reports", _schema({"limit": {"type": "integer"}}, []), _h_list_reports)
	_dispatcher.register("testing.get_report", _schema({"id": np}, ["id"]), _h_get_report)
	_dispatcher.register(
		"testing.run_scenario",
		_schema(
			{
				"steps": {"type": "array"},
				"stop_on_fail": {"type": "boolean"},
				"step_timeout_ms": {"type": "integer", "minimum": 1},
			},
			["steps"]
		),
		_h_run_scenario
	)


func _schema(props: Dictionary, required: Array = []) -> Dictionary:
	var s := {"type": "object", "properties": props, "additionalProperties": false}
	if not required.is_empty():
		s["required"] = required
	return s


func _wrap(g: Dictionary) -> Dictionary:
	if g.get("ok", false):
		return {"ok": true, "result": g.get("result", {})}
	return _err(int(g.get("code", -33990)), str(g.get("message", "testing.error")))


func _scene_root() -> Node:
	var plug := _Utils.editor_plugin(_dispatcher)
	if plug == null:
		return null
	return plug.get_editor_interface().get_edited_scene_root()


func _h_list_suites(ctx: Dictionary) -> Dictionary:
	return _wrap(_H.list_suites(_Utils.params_dict(ctx)))


func _h_run(ctx: Dictionary) -> Dictionary:
	var g := _H.run_tests(_Utils.params_dict(ctx))
	if not g.get("ok", false) and g.has("code"):
		return _err(int(g.get("code", -33990)), str(g.get("message", "testing.error")))
	var res: Dictionary = g.get("result", {})
	return {"ok": res.get("ok", false), "result": res}


func _h_assert_state(ctx: Dictionary) -> Dictionary:
	var root := _scene_root()
	return _wrap(_H.assert_state(_Utils.params_dict(ctx), root))


func _h_screenshot_compare(ctx: Dictionary) -> Dictionary:
	return _wrap(_H.screenshot_compare(_Utils.params_dict(ctx)))


func _h_list_reports(ctx: Dictionary) -> Dictionary:
	return _wrap(_H.list_reports(_Utils.params_dict(ctx)))


func _h_get_report(ctx: Dictionary) -> Dictionary:
	return _wrap(_H.get_report(_Utils.params_dict(ctx)))


func _h_run_scenario(ctx: Dictionary) -> Dictionary:
	var root := _scene_root()
	return _wrap(_H.run_scenario(_Utils.params_dict(ctx), root))


func _err(code: int, symbol: String) -> Dictionary:
	return {"ok": false, "error": TerravoltErrors.tv_rpc_error(code, symbol, symbol, {})}
