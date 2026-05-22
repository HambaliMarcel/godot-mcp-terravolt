@tool
extends RefCounted
class_name TerravoltAnalysisHandlers

const _Utils := preload("./handler_utils.gd")
const _Analysis := preload("./analysis_helpers.gd")

var _dispatcher: TerravoltDispatcher
var _logger: TerravoltLogger


func attach(dispatcher: TerravoltDispatcher, logger: TerravoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var rp := {"type": "string", "minLength": 1}
	_dispatcher.register(
		"analysis.scene_complexity",
		_schema({"scope": {"type": "string"}, "scene_path": rp, "thresholds": {"type": "object"}}),
		_h_scene_complexity
	)
	_dispatcher.register("analysis.signal_flow", _schema({"scope": {"type": "string"}}), _h_signal_flow)
	_dispatcher.register("analysis.unused_resources", _schema({"kinds": {"type": "array"}, "exclude": {"type": "array"}}), _h_unused_resources)
	_dispatcher.register("analysis.metrics", _schema({"kinds": {"type": "array"}}), _h_metrics)


func _schema(props: Dictionary, required: Array = []) -> Dictionary:
	var s := {"type": "object", "properties": props, "additionalProperties": false}
	if not required.is_empty():
		s["required"] = required
	return s


func _h_scene_complexity(_ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(_ctx)
	var scope := str(p.get("scope", "active"))
	var scene_path := str(p.get("scene_path", ""))
	var thresholds: Dictionary = p.get("thresholds", {}) as Dictionary
	return {"ok": true, "result": _Analysis.scene_complexity(scope, scene_path, thresholds)}


func _h_signal_flow(_ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(_ctx)
	return {"ok": true, "result": _Analysis.signal_flow(str(p.get("scope", "project")))}


func _h_unused_resources(_ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(_ctx)
	var kinds: Array = p.get("kinds", []) as Array
	var exclude: Array = p.get("exclude", []) as Array
	return {"ok": true, "result": _Analysis.unused_resources(kinds, exclude)}


func _h_metrics(_ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(_ctx)
	var kinds: Array = p.get("kinds", []) as Array
	return {"ok": true, "result": _Analysis.project_metrics(kinds)}
