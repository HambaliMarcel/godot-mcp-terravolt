@tool
extends RefCounted
class_name TerraVoltInputHandlers

const _Utils := preload("./handler_utils.gd")
const _Input := preload("./input_helpers.gd")

var _dispatcher: TerraVoltDispatcher
var _logger: TerraVoltLogger


func attach(dispatcher: TerraVoltDispatcher, logger: TerraVoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var name := {"type": "string", "minLength": 1}
	_dispatcher.register(
		"input.list_actions",
		_schema({"include_builtin": {"type": "boolean"}}),
		_h_list_actions
	)
	_dispatcher.register(
		"input.add_action",
		_schema({"name": name, "deadzone": {"type": "number"}, "events": {"type": "array"}}, ["name"]),
		_h_add_action
	)
	_dispatcher.register("input.remove_action", _schema({"name": name}, ["name"]), _h_remove_action)
	_dispatcher.register(
		"input.set_action_events",
		_schema({"name": name, "events": {"type": "array"}}, ["name", "events"]),
		_h_set_action_events
	)
	_dispatcher.register(
		"input.rename_action",
		_schema(
			{
				"from": name,
				"to": name,
				"update_references": {"type": "boolean"},
				"dry_run": {"type": "boolean"},
			},
			["from", "to"]
		),
		_h_rename_action
	)
	_dispatcher.register(
		"input.simulate_action",
		_schema(
			{
				"action": name,
				"strength": {"type": "number"},
				"hold_ms": {"type": "integer"},
				"then_release": {"type": "boolean"},
			},
			["action"]
		),
		_h_simulate_action
	)
	_dispatcher.register(
		"input.describe_event",
		_schema({"event": {"type": "object"}}, ["event"]),
		_h_describe_event
	)


func _schema(props: Dictionary, required: Array = []) -> Dictionary:
	var s := {"type": "object", "properties": props, "additionalProperties": false}
	if not required.is_empty():
		s["required"] = required
	return s


func _wrap(g: Dictionary) -> Dictionary:
	if g.get("ok", false):
		return {"ok": true, "result": g.get("result", {})}
	return _err(int(g.get("code", -33977)), str(g.get("message", "input.error")))


func _err(code: int, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": TerraVoltErrors.tv_rpc_error(code, message, message, {}),
	}


func _h_list_actions(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	return _wrap(_Input.list_actions(bool(p.get("include_builtin", false))))


func _h_add_action(ctx: Dictionary) -> Dictionary:
	return _wrap(_Input.add_action(_Utils.params_dict(ctx)))


func _h_remove_action(ctx: Dictionary) -> Dictionary:
	return _wrap(_Input.remove_action(_Utils.params_dict(ctx)))


func _h_set_action_events(ctx: Dictionary) -> Dictionary:
	return _wrap(_Input.set_action_events(_Utils.params_dict(ctx)))


func _h_rename_action(ctx: Dictionary) -> Dictionary:
	return _wrap(_Input.rename_action(_Utils.params_dict(ctx)))


func _h_simulate_action(ctx: Dictionary) -> Dictionary:
	return _wrap(_Input.simulate_action(_Utils.params_dict(ctx)))


func _h_describe_event(ctx: Dictionary) -> Dictionary:
	return _wrap(_Input.describe_event(_Utils.params_dict(ctx)))
