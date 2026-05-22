@tool
extends RefCounted
class_name TerravoltInputHelpers

## InputMap + ProjectSettings persistence helpers (task 21).

const ACTION_NAME_MAX_LEN := 64

const _ScriptHelpers := preload("./script_helpers.gd")


static func ensure_actions_from_project() -> void:
	for prop in ProjectSettings.get_property_list():
		var key := str((prop as Dictionary).get("name", ""))
		if not key.begins_with("input/"):
			continue
		var action_name := key.substr("input/".length())
		if action_name.is_empty() or InputMap.has_action(action_name):
			continue
		var data: Variant = ProjectSettings.get_setting(key)
		if typeof(data) != TYPE_DICTIONARY:
			continue
		var d := data as Dictionary
		InputMap.add_action(action_name, float(d.get("deadzone", 0.5)))
		for ev in d.get("events", []) as Array:
			if ev is InputEvent:
				InputMap.action_add_event(action_name, ev)


static func list_actions(include_builtin: bool) -> Dictionary:
	ensure_actions_from_project()
	var actions: Array = []
	for name in InputMap.get_actions():
		var n := str(name)
		if not include_builtin and n.begins_with("ui_"):
			continue
		actions.append(_action_info(n))
	return {"ok": true, "result": {"actions": actions}}


static func add_action(params: Dictionary) -> Dictionary:
	ensure_actions_from_project()
	var name := str(params.get("name", "")).strip_edges()
	var invalid := _validate_action_name(name)
	if invalid != "":
		return {"ok": false, "code": -33976, "message": invalid}
	if InputMap.has_action(name):
		return {"ok": false, "code": -33975, "message": "input.action_exists"}
	var deadzone := float(params.get("deadzone", 0.5))
	InputMap.add_action(name, deadzone)
	var events: Array = params.get("events", []) as Array
	for spec in events:
		var ev := build_input_event(spec as Dictionary)
		if ev != null:
			InputMap.action_add_event(name, ev)
	_persist_action(name, deadzone)
	return {"ok": true, "result": {"added": true, "name": name, "events": events.size()}}


static func remove_action(params: Dictionary) -> Dictionary:
	var name := str(params.get("name", ""))
	if not InputMap.has_action(name):
		return {"ok": false, "code": -33977, "message": "input.action_unknown"}
	InputMap.erase_action(name)
	_erase_persisted(name)
	return {"ok": true, "result": {"removed": true, "name": name}}


static func set_action_events(params: Dictionary) -> Dictionary:
	var name := str(params.get("name", ""))
	if not InputMap.has_action(name):
		return {"ok": false, "code": -33977, "message": "input.action_unknown"}
	var before := InputMap.action_get_events(name).size()
	InputMap.action_erase_events(name)
	var events: Array = params.get("events", []) as Array
	for spec in events:
		var ev := build_input_event(spec as Dictionary)
		if ev != null:
			InputMap.action_add_event(name, ev)
	var deadzone := InputMap.action_get_deadzone(name)
	_persist_action(name, deadzone)
	return {
		"ok": true,
		"result": {
			"updated": true,
			"name": name,
			"before_count": before,
			"after_count": InputMap.action_get_events(name).size(),
		},
	}


static func rename_action(params: Dictionary) -> Dictionary:
	var from_name := str(params.get("from", ""))
	var to_name := str(params.get("to", ""))
	var dry_run := bool(params.get("dry_run", false))
	if not InputMap.has_action(from_name):
		return {"ok": false, "code": -33977, "message": "input.action_unknown"}
	var invalid := _validate_action_name(to_name)
	if invalid != "":
		return {"ok": false, "code": -33976, "message": invalid}
	var events := InputMap.action_get_events(from_name)
	var deadzone := InputMap.action_get_deadzone(from_name)
	var refs: Array = []
	if bool(params.get("update_references", true)):
		refs = _rewrite_action_references(from_name, to_name, dry_run)
	if not dry_run:
		InputMap.erase_action(from_name)
		_erase_persisted(from_name)
		if not InputMap.has_action(to_name):
			InputMap.add_action(to_name, deadzone)
		for ev in events:
			InputMap.action_add_event(to_name, ev)
		_persist_action(to_name, deadzone)
	return {"ok": true, "result": {"renamed": true, "references_updated": refs, "dry_run": dry_run}}


static func simulate_action(params: Dictionary) -> Dictionary:
	var action := str(params.get("action", ""))
	if not InputMap.has_action(action):
		return {"ok": false, "code": -33977, "message": "input.action_unknown"}
	var strength := float(params.get("strength", 1.0))
	var hold_ms := int(params.get("hold_ms", 50))
	var then_release := bool(params.get("then_release", true))
	Input.action_press(action, strength)
	OS.delay_msec(hold_ms)
	if then_release:
		Input.action_release(action)
	return {"ok": true, "result": {"simulated": true, "action": action, "duration_ms": hold_ms}}


static func describe_event(params: Dictionary) -> Dictionary:
	var spec: Dictionary = params.get("event", {}) as Dictionary
	var ev := build_input_event(spec)
	if ev == null:
		return {"ok": false, "code": -33976, "message": "input.action_name_invalid"}
	var matched: Array = []
	for name in InputMap.get_actions():
		if InputMap.event_is_action(ev, str(name), false):
			matched.append(str(name))
	var display := ""
	if ev.has_method("as_text"):
		display = str(ev.call("as_text"))
	elif ev is InputEventKey:
		display = (ev as InputEventKey).as_text_keycode()
	return {
		"ok": true,
		"result": {
			"display_string": display,
			"normalized": serialize_input_event(ev),
			"matched_actions": matched,
		},
	}


static func build_input_event(spec: Dictionary) -> InputEvent:
	var typ := str(spec.get("type", ""))
	match typ:
		"key":
			var ev := InputEventKey.new()
			if spec.has("keycode_or_physical_key"):
				ev.physical_keycode = int(spec["keycode_or_physical_key"])
			if spec.has("physical_keycode"):
				ev.physical_keycode = int(spec["physical_keycode"])
			if spec.has("key") or spec.has("keycode"):
				ev.keycode = int(spec.get("key", spec.get("keycode", 0)))
			if spec.has("modifier_flags"):
				ev.modifier_mask = int(spec["modifier_flags"])
			ev.pressed = bool(spec.get("pressed", true))
			return ev
		"mouse_button":
			var mb := InputEventMouseButton.new()
			mb.button_index = int(spec.get("button_index", MOUSE_BUTTON_LEFT))
			mb.pressed = bool(spec.get("pressed", true))
			if spec.has("position"):
				var pos: Array = spec["position"] as Array
				mb.position = Vector2(float(pos[0]), float(pos[1]))
			return mb
		"joypad_button":
			var jb := InputEventJoypadButton.new()
			jb.device = int(spec.get("device", 0))
			jb.button_index = int(spec.get("button_index", 0))
			jb.pressed = bool(spec.get("pressed", true))
			return jb
		"joypad_motion":
			var jm := InputEventJoypadMotion.new()
			jm.device = int(spec.get("device", 0))
			jm.axis = int(spec.get("axis", 0))
			jm.axis_value = float(spec.get("axis_value", 0.0))
			return jm
		"action":
			var ea := InputEventAction.new()
			ea.action = str(spec.get("action", ""))
			ea.pressed = bool(spec.get("pressed", true))
			ea.strength = float(spec.get("strength", 1.0))
			return ea
	return null


static func serialize_input_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var k := event as InputEventKey
		return {
			"type": "key",
			"keycode": k.keycode,
			"physical_keycode": k.physical_keycode,
			"modifier_flags": k.modifier_mask,
			"pressed": k.pressed,
		}
	if event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		return {
			"type": "mouse_button",
			"button_index": m.button_index,
			"pressed": m.pressed,
			"position": [m.position.x, m.position.y],
		}
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		return {
			"type": "joypad_button",
			"device": jb.device,
			"button_index": jb.button_index,
			"pressed": jb.pressed,
		}
	if event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		return {
			"type": "joypad_motion",
			"device": jm.device,
			"axis": jm.axis,
			"axis_value": jm.axis_value,
		}
	if event is InputEventAction:
		var a := event as InputEventAction
		return {"type": "action", "action": a.action, "pressed": a.pressed, "strength": a.strength}
	return {"type": "unknown"}


static func _action_info(name: String) -> Dictionary:
	var events: Array = []
	for ev in InputMap.action_get_events(name):
		events.append(serialize_input_event(ev))
	return {"name": name, "deadzone": InputMap.action_get_deadzone(name), "events": events}


static func _validate_action_name(name: String) -> String:
	if name.is_empty() or name.length() > ACTION_NAME_MAX_LEN:
		return "input.action_name_invalid"
	if name.find(" ") >= 0:
		return "input.action_name_invalid"
	return ""


static func _persist_action(name: String, deadzone: float) -> void:
	var events: Array = []
	for ev in InputMap.action_get_events(name):
		events.append(serialize_input_event(ev))
	ProjectSettings.set_setting("input/%s" % name, {"deadzone": deadzone, "events": events})
	if OS.has_feature("editor"):
		ProjectSettings.save()


static func _erase_persisted(name: String) -> void:
	if ProjectSettings.has_setting("input/%s" % name):
		ProjectSettings.set_setting("input/%s" % name, null)
	if OS.has_feature("editor"):
		ProjectSettings.save()


static func _rewrite_action_references(from_name: String, to_name: String, dry_run: bool) -> Array:
	var patterns := [
		'is_action_pressed("%s")' % from_name,
		'is_action_just_pressed("%s")' % from_name,
		'is_action_just_released("%s")' % from_name,
		'"%s"' % from_name,
	]
	var edits: Array = []
	var base := ProjectSettings.globalize_path("res://")
	_collect_rewrite(base, base, from_name, to_name, patterns, edits, dry_run)
	return edits


static func _collect_rewrite(
	base: String,
	dir_abs: String,
	from_name: String,
	to_name: String,
	patterns: Array,
	edits: Array,
	dry_run: bool
) -> void:
	var da := DirAccess.open(dir_abs)
	if da == null:
		return
	da.list_dir_begin()
	while true:
		var entry := da.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		var full := dir_abs.path_join(entry)
		if da.current_is_dir():
			_collect_rewrite(base, full, from_name, to_name, patterns, edits, dry_run)
			continue
		var ext := entry.get_extension()
		if ext != "gd" and ext != "tscn":
			continue
		var text := FileAccess.get_file_as_string(full)
		var rel := "res://%s" % full.substr(base.length()).replace("\\", "/").lstrip("/")
		var changed := false
		for pat in patterns:
			var repl := str(pat).replace(from_name, to_name)
			if text.find(pat) >= 0:
				text = text.replace(pat, repl)
				changed = true
				edits.append({"path": rel, "pattern": pat})
		if changed and not dry_run:
			FileAccess.open(full, FileAccess.WRITE).store_string(text)
	da.list_dir_end()
