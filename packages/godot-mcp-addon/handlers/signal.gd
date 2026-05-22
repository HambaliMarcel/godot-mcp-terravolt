@tool
extends RefCounted
class_name TerravoltSignalHandlers

const _Utils := preload("./handler_utils.gd")
const _Scripts := preload("./script_helpers.gd")

var _dispatcher: TerravoltDispatcher
var _logger: TerravoltLogger


func attach(dispatcher: TerravoltDispatcher, logger: TerravoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var np := {"type": "string", "minLength": 1}
	var rp := {"type": "string", "minLength": 1}
	_dispatcher.register("signal.list_declared", _schema({"path": np}, ["path"]), _h_list_declared)
	_dispatcher.register("signal.add_declaration", _schema({"script_path": rp, "signal_name": {"type": "string"}, "args": {"type": "array"}, "doc_comment": {"type": "string"}}, ["script_path", "signal_name"]), _h_add_declaration)
	_dispatcher.register("signal.remove_declaration", _schema({"script_path": rp, "signal_name": {"type": "string"}}, ["script_path", "signal_name"]), _h_remove_declaration)
	_dispatcher.register("signal.connect", _schema({"from_path": np, "signal_name": {"type": "string"}, "to_path": np, "method": {"type": "string"}, "flags": {"type": "integer"}, "binds": {"type": "array"}}, ["from_path", "signal_name", "to_path", "method"]), _h_connect)
	_dispatcher.register("signal.disconnect", _schema({"from_path": np, "signal_name": {"type": "string"}, "to_path": np, "method": {"type": "string"}}, ["from_path", "signal_name", "to_path", "method"]), _h_disconnect)
	_dispatcher.register("signal.list_connections", _schema({"path": np, "signal_name": {"type": "string"}}, ["path"]), _h_list_connections)
	_dispatcher.register("signal.find_listeners", _schema({"from_path": np, "signal_name": {"type": "string"}, "scope": {"type": "string"}}, ["from_path", "signal_name"]), _h_find_listeners)
	_dispatcher.register("signal.bulk_connect", _schema({"connections": {"type": "array"}, "if_match": {}}, ["connections"]), _h_bulk_connect)
	_dispatcher.register("signal.bulk_disconnect", _schema({"connections": {"type": "array"}}, ["connections"]), _h_bulk_disconnect)
	_dispatcher.register("signal.graph", _schema({"scope": {"type": "string"}, "format": {"type": "string"}, "include_engine_signals": {"type": "boolean"}}), _h_graph)


func _schema(props: Dictionary, required: Array = []) -> Dictionary:
	var s := {"type": "object", "properties": props, "additionalProperties": false}
	if not required.is_empty():
		s["required"] = required
	return s


func _scene_root() -> Node:
	if not OS.has_feature("editor"):
		return null
	var plug := _Utils.editor_plugin(_dispatcher)
	if plug == null:
		return null
	return plug.get_editor_interface().get_edited_scene_root()


func _resolve(path: String) -> Node:
	var root := _scene_root()
	if root == null:
		return null
	return _Utils.resolve_node(root, path)


func _h_list_declared(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var node := _resolve(str(p.get("path", "")))
	if node == null:
		return _Utils.err_no_active_scene() if _scene_root() == null else _Utils.err_node_not_found(str(p.get("path", "")))
	var scr := node.get_script()
	if scr == null or str(scr.resource_path).is_empty():
		return {"ok": true, "result": {"declared": []}}
	var declared := _Scripts.parse_signal_declarations(scr.resource_path)
	return {"ok": true, "result": {"declared": declared}}


func _h_add_declaration(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var script_path := _Utils.resolve_resource_path(str(p.get("script_path", "")))
	var sig_name := str(p.get("signal_name", ""))
	var abs := _Scripts.abs_path(script_path)
	if not FileAccess.file_exists(abs):
		return _err_script_not_found(script_path)
	var existing := _Scripts.parse_signal_declarations(script_path)
	for row in existing:
		if str(row.get("name", "")) == sig_name:
			return _err_signal_exists(sig_name)
	var args: Array = p.get("args", []) as Array
	var arg_str := ""
	if not args.is_empty():
		var parts: PackedStringArray = []
		for a_v in args:
			if typeof(a_v) != TYPE_DICTIONARY:
				continue
			var a := a_v as Dictionary
			parts.append("%s: %s" % [str(a.get("name", "arg")), str(a.get("type", "Variant"))])
		arg_str = "(%s)" % ", ".join(parts)
	var line_text := "signal %s%s" % [sig_name, arg_str]
	if not str(p.get("doc_comment", "")).is_empty():
		line_text = "## %s\n%s" % [str(p["doc_comment"]), line_text]
	var text := FileAccess.get_file_as_string(abs)
	var lines: Array = text.split("\n", false)
	var insert_at := mini(1, lines.size())
	for i in lines.size():
		var t := str(lines[i]).strip_edges()
		if t.begins_with("extends ") or t.begins_with("class_name "):
			insert_at = i + 1
	lines.insert(insert_at, line_text)
	FileAccess.open(abs, FileAccess.WRITE).store_string("\n".join(lines))
	return {"ok": true, "result": {"added": true, "line": insert_at + 1, "revision": str(Time.get_ticks_msec())}}


func _h_remove_declaration(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var script_path := _Utils.resolve_resource_path(str(p.get("script_path", "")))
	var sig_name := str(p.get("signal_name", ""))
	var abs := _Scripts.abs_path(script_path)
	if not FileAccess.file_exists(abs):
		return _err_script_not_found(script_path)
	var line_no := 0
	var removed_line := -1
	var out_lines: PackedStringArray = []
	for line in FileAccess.get_file_as_string(abs).split("\n", false):
		line_no += 1
		if line.strip_edges().begins_with("signal %s" % sig_name) or line.strip_edges().begins_with("signal %s(" % sig_name):
			removed_line = line_no
			continue
		out_lines.append(line)
	if removed_line < 0:
		return _err_signal_unknown(sig_name)
	FileAccess.open(abs, FileAccess.WRITE).store_string("\n".join(out_lines))
	return {"ok": true, "result": {"removed": true, "line": removed_line, "revision": str(Time.get_ticks_msec())}}


func _h_connect(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var from := _resolve(str(p.get("from_path", "")))
	if from == null:
		return _Utils.err_node_not_found(str(p.get("from_path", "")))
	var to := _resolve(str(p.get("to_path", "")))
	if to == null:
		return {
			"ok": false,
			"error": TerravoltErrors.tv_rpc_error(
				TerravoltErrors.SIGNAL_TARGET_UNKNOWN,
				"signal.target_unknown",
				"Target node not found.",
				{"to_path": str(p.get("to_path", ""))}
			),
		}
	var sig := str(p.get("signal_name", ""))
	var method := str(p.get("method", ""))
	if not from.has_signal(sig):
		return _err_signal_unknown(sig)
	if not to.has_method(method):
		return {
			"ok": false,
			"error": TerravoltErrors.tv_rpc_error(
				TerravoltErrors.SIGNAL_METHOD_UNKNOWN,
				"signal.method_unknown",
				"Target method not found.",
				{"method": method}
			),
		}
	var binds: Array = p.get("binds", []) as Array
	var cb := Callable(to, method)
	if not binds.is_empty():
		cb = cb.bindv(binds)
	from.connect(sig, cb, int(p.get("flags", 0)))
	return {
		"ok": true,
		"result": {
			"connected": true,
			"from_path": str(p.get("from_path", "")),
			"signal_name": sig,
			"to_path": str(p.get("to_path", "")),
			"method": method,
		},
	}


func _h_disconnect(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var from := _resolve(str(p.get("from_path", "")))
	var to := _resolve(str(p.get("to_path", "")))
	if from == null or to == null:
		return _Utils.err_node_not_found(str(p.get("from_path", "")))
	var sig := str(p.get("signal_name", ""))
	var method := str(p.get("method", ""))
	var callable := Callable(to, method)
	var was_connected := from.is_connected(sig, callable)
	if was_connected:
		from.disconnect(sig, callable)
	return {"ok": true, "result": {"disconnected": was_connected}}


func _h_list_connections(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var node := _resolve(str(p.get("path", "")))
	if node == null:
		return _Utils.err_node_not_found(str(p.get("path", "")))
	var root := _scene_root()
	var sig_filter := str(p.get("signal_name", ""))
	var connections: Array = []
	for sd in node.get_signal_list():
		if typeof(sd) != TYPE_DICTIONARY:
			continue
		var sn := str((sd as Dictionary).get("name", ""))
		if not sig_filter.is_empty() and sn != sig_filter:
			continue
		for c in node.get_signal_connection_list(sn):
			if typeof(c) != TYPE_DICTIONARY:
				continue
			var cd := c as Dictionary
			var target: Object = cd.get("callable", Callable()).get_object() if cd.has("callable") else null
			var tp := str(root.get_path_to(target)) if target is Node and root else ""
			connections.append({"signal": sn, "target_path": tp, "method": cd.get("method", ""), "flags": cd.get("flags", 0), "binds": []})
	return {"ok": true, "result": {"connections": connections}}


func _h_find_listeners(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var from := _resolve(str(p.get("from_path", "")))
	if from == null:
		return _Utils.err_node_not_found(str(p.get("from_path", "")))
	var sig := str(p.get("signal_name", ""))
	var listeners: Array = []
	for c in from.get_signal_connection_list(sig):
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var cd := c as Dictionary
		var target: Object = cd.get("callable", Callable()).get_object() if cd.has("callable") else null
		var root := _scene_root()
		var tp := str(root.get_path_to(target)) if target is Node and root else ""
		listeners.append({"to_path": tp, "method": cd.get("method", ""), "defined_in": null})
	return {"ok": true, "result": {"listeners": listeners}}


func _h_bulk_connect(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var applied: Array = []
	var skipped: Array = []
	for c_v in p.get("connections", []) as Array:
		if typeof(c_v) != TYPE_DICTIONARY:
			skipped.append({"connection": c_v, "reason": "invalid"})
			continue
		var sub := _h_connect({"params": c_v as Dictionary})
		if sub.get("ok", false):
			applied.append(sub.get("result", {}))
		else:
			skipped.append({"connection": c_v, "reason": sub.get("error", {})})
	return {"ok": true, "result": {"applied": applied, "skipped": skipped, "revision": str(Time.get_ticks_msec())}}


func _h_bulk_disconnect(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var count := 0
	for c_v in p.get("connections", []) as Array:
		if typeof(c_v) != TYPE_DICTIONARY:
			continue
		var sub := _h_disconnect({"params": c_v as Dictionary})
		if sub.get("ok", false) and sub.get("result", {}).get("disconnected", false):
			count += 1
	return {"ok": true, "result": {"disconnected": count}}


func _h_graph(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var fmt := str(p.get("format", "json"))
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	var nodes: Array = []
	var edges: Array = []
	for n in root.find_children("*", "", true, true):
		var declared: Array = []
		if n.get_script() != null:
			declared = _Scripts.parse_signal_declarations(n.get_script().resource_path)
		nodes.append({"path": str(root.get_path_to(n)), "type": n.get_class(), "declared_signals": declared.map(func(d): return d.get("name", ""))})
		for sd in n.get_signal_list():
			if typeof(sd) != TYPE_DICTIONARY:
				continue
			var sn := str((sd as Dictionary).get("name", ""))
			for c in n.get_signal_connection_list(sn):
				if typeof(c) != TYPE_DICTIONARY:
					continue
				var cd := c as Dictionary
				var target: Object = cd.get("callable", Callable()).get_object() if cd.has("callable") else null
				var tp := str(root.get_path_to(target)) if target is Node else ""
				edges.append({"from_path": str(root.get_path_to(n)), "signal": sn, "to_path": tp, "method": cd.get("method", ""), "flags": cd.get("flags", 0)})
	if fmt == "mermaid":
		var lines: PackedStringArray = ["flowchart LR"]
		for e in edges:
			lines.append('  %s -->|%s| %s' % [str(e.from_path).replace("/", "_"), e.signal, str(e.to_path).replace("/", "_")])
		return {"ok": true, "result": {"format": "mermaid", "content_string": "\n".join(lines)}}
	if fmt == "dot":
		var dot := "digraph signals {\n"
		for e in edges:
			dot += '  "%s" -> "%s" [label="%s"];\n' % [e.from_path, e.to_path, e.signal]
		dot += "}"
		return {"ok": true, "result": {"format": "dot", "content_string": dot}}
	return {"ok": true, "result": {"format": "json", "graph": {"nodes": nodes, "edges": edges}}}


func _err_script_not_found(path: String) -> Dictionary:
	return {
		"ok": false,
		"error": TerravoltErrors.tv_rpc_error(
			TerravoltErrors.SCRIPT_PATH_NOT_FOUND_CAT,
			"script.path_not_found",
			"Script not found.",
			{"path": path}
		),
	}


func _err_signal_exists(name: String) -> Dictionary:
	return {
		"ok": false,
		"error": TerravoltErrors.tv_rpc_error(
			TerravoltErrors.SIGNAL_NAME_EXISTS,
			"signal.name_exists",
			"Signal already declared.",
			{"signal_name": name}
		),
	}


func _err_signal_unknown(name: String) -> Dictionary:
	return {
		"ok": false,
		"error": TerravoltErrors.tv_rpc_error(
			TerravoltErrors.SIGNAL_UNKNOWN,
			"signal.unknown",
			"Signal not found.",
			{"signal_name": name}
		),
	}
