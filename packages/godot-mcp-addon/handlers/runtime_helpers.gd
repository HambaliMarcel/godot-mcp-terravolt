extends RefCounted
class_name TerraVoltRuntimeHelpers

const RECORDING_CAPACITY := 10_000
const NAV_DEFAULT_SPEED := 200.0
const THROTTLE_HZ := 30

const _PROTOCOL_METHOD_NOT_FOUND := -33101
const _SCENE_NODE_PATH_NOT_FOUND := -33501
const _NODE_PROPERTY_UNKNOWN := -33523
const _EXPRESSION_FORBIDDEN_IDENTIFIER := -33529
const _EXPRESSION_PARSE_ERROR := -33527
const _SIGNAL_UNKNOWN := -33701
const _RUNTIME_BRIDGE_UNAVAILABLE := -33931
const _RUNTIME_UI_NOT_FOUND := -33932
const _RUNTIME_NAVIGATE_TIMEOUT := -33933

const _EXPR_DENY = [
	"OS", "File", "DirAccess", "FileAccess", "Engine", "JavaScriptBridge", "HTTPClient", "HTTPRequest",
	"Socket", "StreamPeer", "TCPServer", "UDPServer", "ResourceLoader", "ResourceSaver", "ProjectSettings",
	"ClassDB", "GDScript", "Expression",
]

static var _log_ring: Array = []
static var _log_cursor := 0
static var _recording := false
static var _record_buffer_id := ""
static var _record_events: Array = []
static var _record_started_ms := 0
static var _buffers: Dictionary = {}
static var _last_inspect_ms := 0


static func bridge_port() -> int:
	var env := OS.get_environment("TERRAVOLT_RUNTIME_PORT")
	if not env.is_empty() and env.is_valid_int():
		return int(env)
	if ProjectSettings.has_setting("terravolt_mcp/runtime/port"):
		return int(ProjectSettings.get_setting("terravolt_mcp/runtime/port"))
	return 6506


static func dispatch_bridge(method: String, params: Dictionary) -> Dictionary:
	var now := Time.get_ticks_msec()
	if now - _last_inspect_ms < int(1000.0 / THROTTLE_HZ) and method in ["list_nodes", "inspect_node"]:
		OS.delay_msec(1)
	_last_inspect_ms = now

	match method:
		"ping":
			return {"ok": true, "result": {"pong": true, "port": bridge_port()}}
		"list_nodes":
			return _list_nodes(params)
		"inspect_node":
			return _inspect_node(params)
		"evaluate":
			return _evaluate(params)
		"set_property":
			return _set_property(params)
		"call_method":
			return _call_method(params)
		"emit_signal":
			return _emit_signal(params)
		"send_input":
			return _send_input(params)
		"simulate_sequence":
			return _simulate_sequence(params)
		"click_ui":
			return _click_ui(params)
		"navigate":
			return _navigate(params)
		"record_inputs":
			return _record_inputs(params)
		"replay_inputs":
			return _replay_inputs(params)
		"log_tail":
			return _log_tail(params)
		"screenshot":
			return _screenshot(params)
		"set_engine_param":
			return _set_engine_param(params)
		_:
			return _err_bridge(_PROTOCOL_METHOD_NOT_FOUND, "protocol.method_not_found", "Unknown bridge method.", {"method": method})


static func capture_log(message: String, level: String = "info", source: String = "game") -> void:
	var entry := {
		"ts": Time.get_datetime_string_from_system(true),
		"level": level,
		"source": source,
		"message": message,
	}
	_log_ring.append(entry)
	if _log_ring.size() > 500:
		_log_ring.pop_front()
	_log_cursor += 1
	if _recording and _record_events.size() < RECORDING_CAPACITY:
		_record_events.append({"dt_ms": Time.get_ticks_msec() - _record_started_ms, "event": {"type": "log", "message": message}})


static func on_input_event(event: InputEvent) -> void:
	if not _recording or _record_events.size() >= RECORDING_CAPACITY:
		return
	_record_events.append({"dt_ms": Time.get_ticks_msec() - _record_started_ms, "event": _serialize_input(event)})


static func _tree_root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root


static func _resolve_live(path: String) -> Node:
	var root := _tree_root()
	if root == null:
		return null
	return _resolve_node(root, path)


static func _list_nodes(params: Dictionary) -> Dictionary:
	var root := _tree_root()
	if root == null:
		return _err_bridge(_RUNTIME_BRIDGE_UNAVAILABLE, "runtime.bridge_unavailable", "No scene tree.", {})
	var sub := str(params.get("root", ""))
	var start: Node = root
	if not sub.is_empty():
		start = _resolve_live(sub)
		if start == null:
			return _err_bridge(_SCENE_NODE_PATH_NOT_FOUND, "scene.node_path_not_found", "Root path not found.", {"path": sub})
	var max_depth := int(params.get("max_depth", 4))
	var max_children := int(ProjectSettings.get_setting("terravolt_mcp/context/max_tree_nodes", 5000))
	max_children = mini(max_children, 64)
	return {"ok": true, "result": _build_tree_envelope(start, max_depth, max_children)}


static func _inspect_node(params: Dictionary) -> Dictionary:
	var path := str(params.get("path", ""))
	var node := _resolve_live(path)
	if node == null:
		return _err_bridge(_SCENE_NODE_PATH_NOT_FOUND, "scene.node_path_not_found", "Node not found.", {"path": path})
	var props_filter: Variant = params.get("properties", "all")
	var include_signals := bool(params.get("include_signals", false))
	var out := {
		"path": path,
		"type": node.get_class(),
		"properties": _read_node_properties(node, props_filter),
		"groups": node.get_groups(),
	}
	if include_signals:
		out["signals"] = node.get_signal_list()
	return {"ok": true, "result": out}


static func _evaluate(params: Dictionary) -> Dictionary:
	var path := str(params.get("path", ""))
	var node := _resolve_live(path)
	if node == null:
		return _err_bridge(_SCENE_NODE_PATH_NOT_FOUND, "scene.node_path_not_found", "Node not found.", {"path": path})
	var expr_text := str(params.get("expression", ""))
	var forbidden := _expression_forbidden(expr_text)
	if not forbidden.is_empty():
		return _err_bridge(
			_EXPRESSION_FORBIDDEN_IDENTIFIER,
			"expression.forbidden_identifier",
			"Forbidden identifier in expression.",
			{"identifier": forbidden}
		)
	var ex := Expression.new()
	var inputs: Dictionary = params.get("inputs", {}) as Dictionary
	var names: Array[String] = []
	var values: Array = []
	for k in inputs.keys():
		names.append(str(k))
		values.append(inputs[k])
	if ex.parse(expr_text, names) != OK:
		return _err_bridge(_EXPRESSION_PARSE_ERROR, "expression.parse_error", error_string(ex.get_error_code()), {})
	var val: Variant = ex.execute(values, node)
	if ex.has_execute_failed():
		return {"ok": true, "result": {"value": null, "type": TYPE_NIL, "error": "execute_failed"}}
	return {"ok": true, "result": {"value": val, "type": typeof(val)}}


static func _set_property(params: Dictionary) -> Dictionary:
	var path := str(params.get("path", ""))
	var key := str(params.get("key", ""))
	var node := _resolve_live(path)
	if node == null:
		return _err_bridge(_SCENE_NODE_PATH_NOT_FOUND, "scene.node_path_not_found", "Node not found.", {"path": path})
	if not _has_property(node, key):
		return _err_bridge(_NODE_PROPERTY_UNKNOWN, "node.property_unknown", "Unknown property.", {"key": key})
	var before: Variant = node.get(key)
	node.set(key, params.get("value"))
	var after: Variant = node.get(key)
	return {"ok": true, "result": {"set": true, "path": path, "key": key, "before": before, "after": after}}


static func _call_method(params: Dictionary) -> Dictionary:
	var path := str(params.get("path", ""))
	var method := str(params.get("method", ""))
	var node := _resolve_live(path)
	if node == null:
		return _err_bridge(_SCENE_NODE_PATH_NOT_FOUND, "scene.node_path_not_found", "Node not found.", {"path": path})
	if not node.has_method(method):
		return _err_bridge(-33531, "node.method_unknown", "Method not found.", {"method": method})
	var args: Array = params.get("args", []) as Array
	var t0 := Time.get_ticks_msec()
	var ret: Variant = node.callv(method, args)
	return {"ok": true, "result": {"called": true, "return_value": ret, "took_ms": Time.get_ticks_msec() - t0}}


static func _emit_signal(params: Dictionary) -> Dictionary:
	var path := str(params.get("path", ""))
	var sig := str(params.get("signal", ""))
	var node := _resolve_live(path)
	if node == null:
		return _err_bridge(_SCENE_NODE_PATH_NOT_FOUND, "scene.node_path_not_found", "Node not found.", {"path": path})
	if not node.has_signal(sig):
		return _err_bridge(_SIGNAL_UNKNOWN, "signal.unknown", "Signal not found.", {"signal": sig})
	var args: Array = params.get("args", []) as Array
	_emit_with_args(node, sig, args)
	return {"ok": true, "result": {"emitted": true}}


static func _emit_with_args(node: Object, sig: String, args: Array) -> void:
	match args.size():
		0:
			node.emit_signal(sig)
		1:
			node.emit_signal(sig, args[0])
		2:
			node.emit_signal(sig, args[0], args[1])
		3:
			node.emit_signal(sig, args[0], args[1], args[2])
		_:
			node.emit_signal(sig, args[0], args[1], args[2])


static func _send_input(params: Dictionary) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.paused and not bool(params.get("force", false)):
		capture_log("runtime.send_input while tree paused", "warn", "runtime")
	var events: Array = params.get("events", []) as Array
	var delay_ms := int(params.get("delay_between_ms", 0))
	var sent := 0
	for ev_spec in events:
		if typeof(ev_spec) != TYPE_DICTIONARY:
			continue
		var ie := _build_input_event(ev_spec as Dictionary)
		if ie == null:
			continue
		Input.parse_input_event(ie)
		sent += 1
		if delay_ms > 0:
			OS.delay_msec(delay_ms)
	return {"ok": true, "result": {"sent": sent}}


static func _simulate_sequence(params: Dictionary) -> Dictionary:
	var seq: Array = params.get("sequence", []) as Array
	var pace := int(params.get("pace_ms", 16))
	var events: Array = []
	for step in seq:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var st := step as Dictionary
		var action := str(st.get("action", ""))
		if action.is_empty():
			continue
		events.append({"type": "action", "action": action, "pressed": true})
		var hold := int(st.get("hold_ms", 100))
		if bool(st.get("then_release", true)):
			events.append({"type": "action", "action": action, "pressed": false})
		OS.delay_msec(hold)
		OS.delay_msec(pace)
	var t0 := Time.get_ticks_msec()
	var r := _send_input({"events": events, "delay_between_ms": pace})
	var dur := Time.get_ticks_msec() - t0
	return {"ok": true, "result": {"done": true, "total_duration_ms": dur, "sent": (r.get("result", {}) as Dictionary).get("sent", 0)}}


static func _click_ui(params: Dictionary) -> Dictionary:
	var sel: Dictionary = params.get("selector", {}) as Dictionary
	var target: Control = null
	if sel.has("path"):
		var n := _resolve_live(str(sel["path"]))
		if n is Control:
			target = n as Control
	if target == null and sel.has("text"):
		target = _find_control_by_text(str(sel["text"]), str(sel.get("role", "")))
	if target == null:
		return _err_bridge(_RUNTIME_UI_NOT_FOUND, "runtime.ui_not_found", "UI control not found.", {"selector": sel})
	var rect := target.get_global_rect()
	var pos := rect.position + rect.size / 2.0
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)
	ev = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)
	var wait_ms := int(params.get("wait_animation_ms", 250))
	if wait_ms > 0:
		OS.delay_msec(wait_ms)
	var root := _tree_root()
	var rel_path := str(root.get_path_to(target)) if root else str(target.get_path())
	return {"ok": true, "result": {"clicked": true, "path": rel_path}}


static func _find_control_by_text(text: String, role: String) -> Control:
	var root := _tree_root()
	if root == null:
		return null
	for n in root.find_children("*", "Control", true, false):
		if not (n is Control):
			continue
		var c := n as Control
		if not role.is_empty() and c.get_class() != role:
			continue
		if c is Button and (c as Button).text == text:
			return c
		if c is Label and (c as Label).text == text:
			return c
		if "text" in c and str(c.get("text")) == text:
			return c
	return null


static func _navigate(params: Dictionary) -> Dictionary:
	var agent_path := str(params.get("agent_path", ""))
	var agent := _resolve_live(agent_path)
	if agent == null:
		return _err_bridge(_SCENE_NODE_PATH_NOT_FOUND, "scene.node_path_not_found", "Agent not found.", {"path": agent_path})
	var target_spec: Dictionary = params.get("target", {}) as Dictionary
	var goal := Vector2.ZERO
	if target_spec.has("vec2"):
		var v: Array = target_spec["vec2"] as Array
		goal = Vector2(float(v[0]), float(v[1]))
	elif target_spec.has("node_path"):
		var tn := _resolve_live(str(target_spec["node_path"]))
		if tn is Node2D:
			goal = (tn as Node2D).global_position
		elif tn is Node3D:
			var p3 := (tn as Node3D).global_position
			goal = Vector2(p3.x, p3.z)
	var speed := float(params.get("speed", NAV_DEFAULT_SPEED))
	var timeout_ms := int(params.get("timeout_ms", 10000))
	var arrival := float(params.get("arrival_radius", 8.0))
	var t0 := Time.get_ticks_msec()
	var start_pos := Vector2.ZERO
	if agent is Node2D:
		start_pos = (agent as Node2D).global_position
	var path_len := 0.0
	while Time.get_ticks_msec() - t0 < timeout_ms:
		if not is_instance_valid(agent):
			break
		var cur := Vector2.ZERO
		if agent is Node2D:
			cur = (agent as Node2D).global_position
		var delta := goal - cur
		path_len += delta.length()
		if delta.length() <= arrival:
			return {
				"ok": true,
				"result": {
					"arrived": true,
					"end_position": [cur.x, cur.y],
					"duration_ms": Time.get_ticks_msec() - t0,
					"path_length": path_len,
				},
			}
		if agent is CharacterBody2D:
			var body := agent as CharacterBody2D
			body.velocity = delta.normalized() * speed
			body.move_and_slide()
		elif agent is Node2D:
			(agent as Node2D).global_position += delta.normalized() * speed * 0.016
		OS.delay_msec(16)
	var end := Vector2.ZERO
	if is_instance_valid(agent) and agent is Node2D:
		end = (agent as Node2D).global_position
	return {
		"ok": false,
		"error": _tv_err(
			_RUNTIME_NAVIGATE_TIMEOUT,
			"runtime.navigate_timeout",
			"Navigation timed out before arrival.",
			{"end_position": [end.x, end.y], "goal": [goal.x, goal.y]}
		),
	}


static func _record_inputs(params: Dictionary) -> Dictionary:
	var action := str(params.get("action", "start"))
	if action == "stop":
		_recording = false
		if not _record_buffer_id.is_empty():
			_buffers[_record_buffer_id] = {
				"buffer_id": _record_buffer_id,
				"started_at": _record_started_ms,
				"ended_at": Time.get_ticks_msec(),
				"events": _record_events.duplicate(true),
			}
		return {"ok": true, "result": {"recording": false, "buffer_id": _record_buffer_id, "event_count": _record_events.size()}}
	_record_buffer_id = str(params.get("buffer_id", "default-%d" % Time.get_ticks_msec()))
	_record_events = []
	_record_started_ms = Time.get_ticks_msec()
	_recording = true
	return {"ok": true, "result": {"recording": true, "buffer_id": _record_buffer_id, "event_count": 0}}


static func _replay_inputs(params: Dictionary) -> Dictionary:
	var bid := str(params.get("buffer_id", ""))
	if not _buffers.has(bid):
		return _err_bridge(-33939, "runtime.buffer_not_found", "Recording buffer not found.", {"buffer_id": bid})
	var buf: Dictionary = _buffers[bid]
	var events: Array = buf.get("events", []) as Array
	var speed := float(params.get("speed", 1.0))
	var t0 := Time.get_ticks_msec()
	var last_dt := 0
	for row in events:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var rd := row as Dictionary
		var ev_spec: Variant = rd.get("event")
		if typeof(ev_spec) != TYPE_DICTIONARY:
			continue
		var wait := int(float(int(rd.get("dt_ms", 0)) - last_dt) / maxf(speed, 0.01))
		if wait > 0:
			OS.delay_msec(wait)
		last_dt = int(rd.get("dt_ms", 0))
		var ie := _build_input_event(ev_spec as Dictionary)
		if ie != null:
			Input.parse_input_event(ie)
	return {
		"ok": true,
		"result": {"replayed": true, "duration_ms": Time.get_ticks_msec() - t0, "event_count": events.size()},
	}


static func _log_tail(params: Dictionary) -> Dictionary:
	var lines := maxi(1, int(params.get("lines", 100)))
	var level := str(params.get("level", "all"))
	var out: Array = []
	for i in range(_log_ring.size() - 1, -1, -1):
		var e: Dictionary = _log_ring[i]
		if level != "all" and str(e.get("level", "")) != level:
			continue
		out.append(e)
		if out.size() >= lines:
			break
	out.reverse()
	return {"ok": true, "result": {"entries": out, "next_cursor": _log_cursor}}


static func _screenshot(params: Dictionary) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return _err_bridge(_RUNTIME_BRIDGE_UNAVAILABLE, "runtime.bridge_unavailable", "No viewport.", {})
	var vp := tree.root.get_viewport()
	if vp == null:
		return _err_bridge(_RUNTIME_BRIDGE_UNAVAILABLE, "runtime.bridge_unavailable", "No viewport.", {})
	var tex := vp.get_texture()
	if tex == null:
		return _err_bridge(_RUNTIME_BRIDGE_UNAVAILABLE, "runtime.bridge_unavailable", "No viewport texture.", {})
	var img := tex.get_image()
	var sz: Variant = params.get("size")
	if typeof(sz) == TYPE_DICTIONARY:
		var w := int((sz as Dictionary).get("w", img.get_width()))
		var h := int((sz as Dictionary).get("h", img.get_height()))
		if w > 0 and h > 0:
			img.resize(w, h)
	var png := img.save_png_to_buffer()
	return {
		"ok": true,
		"result": {
			"image_base64": Marshalls.raw_to_base64(png),
			"mime": "image/png",
			"width": img.get_width(),
			"height": img.get_height(),
			"bytes": png.size(),
		},
	}


static func _set_engine_param(params: Dictionary) -> Dictionary:
	var p: Dictionary = params.get("params", {}) as Dictionary
	var applied: Dictionary = {}
	if p.has("time_scale"):
		var before := Engine.time_scale
		Engine.time_scale = float(p["time_scale"])
		applied["time_scale"] = {"before": before, "after": Engine.time_scale}
	if p.has("physics_ticks_per_second"):
		var before_pt := Engine.physics_ticks_per_second
		Engine.physics_ticks_per_second = int(p["physics_ticks_per_second"])
		applied["physics_ticks_per_second"] = {"before": before_pt, "after": Engine.physics_ticks_per_second}
	if p.has("vsync"):
		var mode := DisplayServer.VSYNC_ENABLED
		match str(p["vsync"]):
			"disabled":
				mode = DisplayServer.VSYNC_DISABLED
			"adaptive":
				mode = DisplayServer.VSYNC_ADAPTIVE
			"mailbox":
				mode = DisplayServer.VSYNC_MAILBOX
		DisplayServer.window_set_vsync_mode(mode)
		applied["vsync"] = {"before": null, "after": str(p["vsync"])}
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		if p.has("debug_collisions"):
			var b := bool(p["debug_collisions"])
			tree.debug_collisions_hint = b
			applied["debug_collisions"] = {"before": null, "after": b}
		if p.has("debug_navigation"):
			var bn := bool(p["debug_navigation"])
			tree.debug_navigation_hint = bn
			applied["debug_navigation"] = {"before": null, "after": bn}
	return {"ok": true, "result": {"applied": applied}}


static func _build_input_event(spec: Dictionary) -> InputEvent:
	var typ := str(spec.get("type", ""))
	match typ:
		"key":
			var ev := InputEventKey.new()
			if spec.has("key"):
				ev.keycode = int(spec["key"])
			if spec.has("physical_keycode"):
				ev.physical_keycode = int(spec["physical_keycode"])
			ev.pressed = bool(spec.get("pressed", true))
			return ev
		"mouse_button":
			var mb := InputEventMouseButton.new()
			mb.button_index = int(spec.get("button_index", MOUSE_BUTTON_LEFT))
			mb.pressed = bool(spec.get("pressed", true))
			if spec.has("position"):
				var pos: Array = spec["position"] as Array
				mb.position = Vector2(float(pos[0]), float(pos[1]))
				mb.global_position = mb.position
			return mb
		"mouse_motion":
			var mm := InputEventMouseMotion.new()
			if spec.has("position"):
				var posm: Array = spec["position"] as Array
				mm.position = Vector2(float(posm[0]), float(posm[1]))
				mm.global_position = mm.position
			if spec.has("velocity"):
				var vel: Array = spec["velocity"] as Array
				mm.velocity = Vector2(float(vel[0]), float(vel[1]))
			return mm
		"action":
			var ea := InputEventAction.new()
			ea.action = str(spec.get("action", ""))
			ea.pressed = bool(spec.get("pressed", true))
			ea.strength = float(spec.get("strength", 1.0))
			return ea
		"joy_button":
			var jb := InputEventJoypadButton.new()
			jb.button_index = int(spec.get("button_index", 0))
			jb.pressed = bool(spec.get("pressed", true))
			return jb
		"joy_axis":
			var ja := InputEventJoypadMotion.new()
			ja.axis = int(spec.get("axis", 0))
			ja.axis_value = float(spec.get("axis_value", 0.0))
			return ja
	return null


static func _serialize_input(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var k := event as InputEventKey
		return {"type": "key", "key": k.keycode, "pressed": k.pressed}
	if event is InputEventAction:
		var a := event as InputEventAction
		return {"type": "action", "action": a.action, "pressed": a.pressed, "strength": a.strength}
	if event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		return {"type": "mouse_button", "button_index": m.button_index, "pressed": m.pressed, "position": [m.position.x, m.position.y]}
	return {"type": "unknown"}


static func _tv_err(tv_code: int, symbol: String, message: String, ctx: Dictionary) -> Dictionary:
	var data: Dictionary = {"tv_code": tv_code, "hint": message, "app_code": symbol}
	if not ctx.is_empty():
		data["context"] = ctx
	return {"code": tv_code, "message": symbol, "data": data}


static func _err_bridge(tv_code: int, symbol: String, message: String, ctx: Dictionary) -> Dictionary:
	return {"ok": false, "error": _tv_err(tv_code, symbol, message, ctx)}


static func _resolve_node(scene_root: Node, path: String) -> Node:
	if scene_root == null:
		return null
	var p := path.strip_edges()
	if p.is_empty() or p == ".":
		return scene_root
	return scene_root.get_node_or_null(NodePath(p))


static func _build_tree_envelope(root: Node, max_depth: int, max_children: int) -> Dictionary:
	if root == null:
		return {}
	var total := _count_nodes(root)
	return {
		"root": {"name": root.name, "type": root.get_class()},
		"depth_returned": max_depth,
		"total_node_count_estimate": total,
		"sample": [_node_summary(root, root, 0, max_depth, max_children)],
		"pointers": [],
	}


static func _count_nodes(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count_nodes(ch)
	return c


static func _node_summary(scene_root: Node, n: Node, depth: int, max_depth: int, max_children: int) -> Dictionary:
	var sample_children: Array = []
	if depth < max_depth:
		var lim := mini(n.get_child_count(), max_children)
		for i in lim:
			sample_children.append(_node_summary(scene_root, n.get_child(i), depth + 1, max_depth, max_children))
	return {
		"name": n.name,
		"type": n.get_class(),
		"path": str(scene_root.get_path_to(n)),
		"has_script": n.get_script() != null,
		"children_count": n.get_child_count(),
		"sample_children": sample_children,
		"truncated": n.get_child_count() > max_children,
	}


static func _read_node_properties(node: Node, prop_filter: Variant) -> Dictionary:
	var out: Dictionary = {}
	var want_all: bool = prop_filter == null
	if typeof(prop_filter) == TYPE_STRING:
		want_all = str(prop_filter) == "all"
	var want_keys: Array = []
	if typeof(prop_filter) == TYPE_ARRAY:
		for k in prop_filter:
			want_keys.append(str(k))
	for pi in node.get_property_list():
		if typeof(pi) != TYPE_DICTIONARY:
			continue
		var name := str((pi as Dictionary).get("name", ""))
		if name.is_empty() or name.begins_with("_"):
			continue
		if not want_all and not want_keys.has(name):
			continue
		out[name] = {"value": node.get(name), "type": int((pi as Dictionary).get("type", TYPE_NIL))}
	return out


static func _has_property(obj: Object, key: String) -> bool:
	for pi in obj.get_property_list():
		if typeof(pi) != TYPE_DICTIONARY:
			continue
		if str((pi as Dictionary).get("name", "")) == key:
			return true
	return false


static func _expression_forbidden(expr: String) -> String:
	for id in _EXPR_DENY:
		var re := RegEx.new()
		if re.compile("\\b%s\\b" % id) != OK:
			continue
		if re.search(expr) != null:
			return id
	return ""
