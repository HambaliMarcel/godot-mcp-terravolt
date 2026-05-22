@tool
extends RefCounted
class_name TerraVoltRuntimeHandlers

const _Utils := preload("./handler_utils.gd")
const _Proxy := preload("../services/runtime_proxy.gd")
const _Session := preload("../services/runtime_session.gd")

var _dispatcher: TerraVoltDispatcher
var _logger: TerraVoltLogger


func attach(dispatcher: TerraVoltDispatcher, logger: TerraVoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var np := {"type": "string", "minLength": 1}
	var rp := {"type": "string", "minLength": 1, "pattern": "^(res://|user://|/|[A-Za-z]:)"}

	_dispatcher.register(
		"runtime.play",
		_schema({"mode": {"type": "string"}, "scene": rp, "args": {"type": "array"}}, []),
		_h_play
	)
	_dispatcher.register("runtime.stop", _schema({"force": {"type": "boolean"}}, []), _h_stop)
	_dispatcher.register(
		"runtime.start_headless",
		_schema({"scene": rp, "project_path": rp, "args": {"type": "array"}, "wait_handshake_ms": {"type": "integer"}}, []),
		_h_start_headless
	)
	_dispatcher.register("runtime.status", _schema({}, []), _h_status)
	_dispatcher.register(
		"runtime.list_nodes",
		_schema({"envelope": {"type": "string"}, "max_depth": {"type": "integer"}, "root": np}, []),
		_h_bridge
	)
	_dispatcher.register(
		"runtime.inspect_node",
		_schema({"path": np, "properties": {}, "include_signals": {"type": "boolean"}}, ["path"]),
		_h_bridge
	)
	_dispatcher.register(
		"runtime.evaluate",
		_schema({"path": np, "expression": {"type": "string"}, "inputs": {"type": "object"}}, ["path", "expression"]),
		_h_bridge
	)
	_dispatcher.register(
		"runtime.set_property",
		_schema({"path": np, "key": {"type": "string"}, "value": {}}, ["path", "key"]),
		_h_bridge
	)
	_dispatcher.register(
		"runtime.call_method",
		_schema({"path": np, "method": {"type": "string"}, "args": {"type": "array"}}, ["path", "method"]),
		_h_bridge
	)
	_dispatcher.register(
		"runtime.emit_signal",
		_schema({"path": np, "signal": {"type": "string"}, "args": {"type": "array"}}, ["path", "signal"]),
		_h_bridge
	)
	_dispatcher.register(
		"runtime.send_input",
		_schema({"events": {"type": "array"}, "delay_between_ms": {"type": "integer"}, "force": {"type": "boolean"}}, ["events"]),
		_h_bridge
	)
	_dispatcher.register(
		"runtime.simulate_sequence",
		_schema({"sequence": {"type": "array"}, "pace_ms": {"type": "integer"}}, ["sequence"]),
		_h_bridge
	)
	_dispatcher.register(
		"runtime.click_ui",
		_schema({"selector": {"type": "object"}, "scroll_into_view": {"type": "boolean"}, "wait_animation_ms": {"type": "integer"}}, ["selector"]),
		_h_bridge
	)
	_dispatcher.register(
		"runtime.navigate",
		_schema(
			{
				"agent_path": np,
				"target": {"type": "object"},
				"speed": {"type": "number"},
				"timeout_ms": {"type": "integer"},
				"arrival_radius": {"type": "number"},
			},
			["agent_path", "target"]
		),
		_h_bridge
	)
	_dispatcher.register(
		"runtime.record_inputs",
		_schema({"action": {"type": "string"}, "buffer_id": {"type": "string"}}, ["action"]),
		_h_bridge
	)
	_dispatcher.register(
		"runtime.replay_inputs",
		_schema({"buffer_id": {"type": "string"}, "speed": {"type": "number"}, "loop": {"type": "boolean"}}, ["buffer_id"]),
		_h_bridge
	)
	_dispatcher.register(
		"runtime.log_tail",
		_schema({"lines": {"type": "integer"}, "level": {"type": "string"}, "since_ts": {"type": "string"}}, []),
		_h_bridge
	)
	_dispatcher.register(
		"runtime.screenshot",
		_schema({"size": {"type": "object"}, "quality": {"type": "integer"}}, []),
		_h_bridge
	)
	_dispatcher.register(
		"runtime.set_engine_param",
		_schema({"params": {"type": "object"}}, ["params"]),
		_h_bridge
	)


func _schema(props: Dictionary, required: Array = []) -> Dictionary:
	var s := {"type": "object", "properties": props, "additionalProperties": false}
	if not required.is_empty():
		s["required"] = required
	return s


func _editor() -> Dictionary:
	return _Utils.require_editor(_dispatcher)


func _iface() -> EditorInterface:
	var ed := _editor()
	if not ed.get("ok", false):
		return null
	return (ed.plugin as EditorPlugin).get_editor_interface()


func _h_play(_ctx: Dictionary) -> Dictionary:
	var ed := _editor()
	if not ed.get("ok", false):
		return ed
	var p := _Utils.params_dict(_ctx)
	var iface := _iface()
	var mode := str(p.get("mode", "current_scene"))
	var port := _Session.default_bridge_port()
	match mode:
		"project":
			iface.play_main_scene()
		"specific":
			var scene := str(p.get("scene", ""))
			if scene.is_empty():
				return {
					"ok": false,
					"error": TerraVoltErrors.tv_rpc_error(
						TerraVoltErrors.PROTOCOL_INVALID_PARAMS,
						"protocol.invalid_params",
						"scene required for mode specific.",
						{}
					),
				}
			iface.play_custom_scene(scene)
		_:
			iface.play_current_scene()
	_Session.mark_active("editor", OS.get_process_id(), port, str(p.get("scene", "")))
	return {
		"ok": true,
		"result": {
			"playing": true,
			"pid": OS.get_process_id(),
			"started_at": Time.get_datetime_string_from_system(true),
			"bridge_port": port,
			"mode": mode,
		},
	}


func _h_stop(_ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(_ctx)
	var was_pid := _Session.pid
	if _Session.mode == "editor":
		var ed := _editor()
		if ed.get("ok", false):
			_iface().stop_playing_scene()
	elif _Session.mode == "headless" and was_pid > 0 and bool(p.get("force", false)):
		OS.kill(was_pid)
	elif _Session.mode == "headless" and was_pid > 0:
		OS.kill(was_pid)
	_Session.reset()
	return {"ok": true, "result": {"stopped": true, "was_pid": was_pid}}


func _h_start_headless(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var spawned := _spawn_headless_game(p)
	if not spawned.get("ok", false):
		return spawned
	var result: Dictionary = spawned.get("result", {})
	_Session.mark_active(
		"headless",
		int(result.get("pid", -1)),
		int(result.get("bridge_port", _Session.default_bridge_port())),
		str(p.get("scene", ""))
	)
	return {"ok": true, "result": result}


func _spawn_headless_game(params: Dictionary) -> Dictionary:
	var exe := OS.get_environment("TERRAVOLT_GODOT_BINARY")
	if exe.is_empty():
		exe = OS.get_executable_path()
	var project := ProjectSettings.globalize_path("res://")
	var project_override := str(params.get("project_path", "")).strip_edges()
	if not project_override.is_empty():
		project = (
			ProjectSettings.globalize_path(project_override)
			if project_override.begins_with("res://")
			else project_override
		)
	var scene := str(params.get("scene", ""))
	var port := _Session.default_bridge_port()
	var args: PackedStringArray = ["--headless", "--path", project]
	if not scene.is_empty():
		args.append(_Utils.resolve_resource_path(scene))
	var wait_ms := int(params.get("wait_handshake_ms", 5000))
	var t0 := Time.get_ticks_msec()
	var pid := OS.create_process(exe, args, false)
	if pid <= 0:
		return {
			"ok": false,
			"error": TerraVoltErrors.tv_rpc_error(
				TerraVoltErrors.RUNTIME_SPAWN_FAILED,
				"runtime.spawn_failed",
				"Failed to spawn headless game process.",
				{"exe": exe}
			),
		}
	var bound_port := port
	if wait_ms > 0:
		bound_port = _wait_bridge_port(port, mini(wait_ms, 8000))
		if bound_port <= 0:
			bound_port = port
	if wait_ms > 8000 and bound_port > 0:
		var late := _wait_bridge_port(bound_port, wait_ms - 8000)
		if late > 0:
			bound_port = late
	return {
		"ok": true,
		"result": {
			"started": true,
			"pid": pid,
			"bridge_port": bound_port,
			"handshake_duration_ms": Time.get_ticks_msec() - t0,
		},
	}


func _wait_bridge_port(preferred: int, timeout_ms: int) -> int:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		var ping := _Proxy.bridge_call_sync(preferred, "ping", {}, 400)
		if ping.get("ok", false):
			return preferred
		OS.delay_msec(50)
	return -1


func _h_status(_ctx: Dictionary) -> Dictionary:
	if _Session.mode == "editor":
		var ed := _editor()
		if ed.get("ok", false):
			var playing := _iface().is_playing_scene()
			_Session.alive = playing
			if not playing:
				_Session.reset()
	return {"ok": true, "result": {"session": _Session.session_dict()}}


func _h_bridge(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var method := str(ctx.get(&"method", ""))
	var fwd := _Proxy.forward_runtime(method, p)
	if not fwd.get("ok", false):
		return fwd
	return {"ok": true, "result": fwd.get("result", {})}
