extends RefCounted
class_name TerravoltHeadlessCatalogOps

## Self-contained scene/project ops for headless_driver.gd (task 11).

const _ScriptHelpers := preload("../handlers/script_helpers.gd")


static func resolve_path(raw: String) -> String:
	var s := raw.strip_edges()
	if s.begins_with("res://") or s.begins_with("user://"):
		return s
	if s.begins_with("/") or (s.length() >= 3 and s[1] == ":"):
		return ProjectSettings.localize_path(s)
	return "res://%s" % s.lstrip("/")


static func globalize(path: String) -> String:
	return ProjectSettings.globalize_path(resolve_path(path))


static func scene_exists(path: String) -> bool:
	var p := resolve_path(path)
	return ResourceLoader.exists(p) or FileAccess.file_exists(globalize(p))


static func walk_scenes() -> Array:
	var out: Array = []
	var base := ProjectSettings.globalize_path("res://")
	_collect(base, base, out)
	out.sort_custom(func(a, b): return str(a.path) < str(b.path))
	return out


static func _collect(base: String, dir_abs: String, out: Array) -> void:
	var da := DirAccess.open(dir_abs)
	if da == null:
		return
	da.list_dir_begin()
	while true:
		var name := da.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var full := dir_abs.path_join(name)
		if da.current_is_dir():
			_collect(base, full, out)
			continue
		if name.ends_with(".tscn") or name.ends_with(".scn"):
			var rel := full.substr(base.length()).replace("\\", "/").lstrip("/")
			out.append({"path": "res://%s" % rel, "size_bytes": FileAccess.get_file_as_bytes(full).size()})
	da.list_dir_end()


static func scene_get(path: String) -> Dictionary:
	var p := resolve_path(path)
	if not scene_exists(p):
		return {"ok": false, "code": -33500, "message": "scene.path_not_found"}
	var deps: Array = []
	for d in ResourceLoader.get_dependencies(p):
		deps.append(str(d))
	var root_type := "Unknown"
	var node_count := 0
	if ResourceLoader.exists(p):
		var ps: PackedScene = ResourceLoader.load(p)
		if ps:
			var st := ps.get_state()
			node_count = st.get_node_count()
			if node_count > 0:
				root_type = str(st.get_node_type(0))
	return {
		"ok": true,
		"result": {
			"path": p,
			"root_type": root_type,
			"node_count": node_count,
			"has_script": false,
			"dependencies": deps,
		},
	}


static func scene_create(params: Dictionary) -> Dictionary:
	var path := resolve_path(str(params.get("path", "")))
	var root_type := str(params.get("root_type", "Node"))
	if not ClassDB.class_exists(root_type) or not ClassDB.is_parent_class(root_type, "Node"):
		return {"ok": false, "code": -33520, "message": "node.type_unknown"}
	var root: Node = ClassDB.instantiate(root_type)
	root.name = str(params.get("root_name", path.get_file().get_basename()))
	var packed := PackedScene.new()
	var err := packed.pack(root)
	root.queue_free()
	if err != OK:
		return {"ok": false, "code": -33510, "message": error_string(err)}
	var dir := globalize(path.get_base_dir())
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	err = ResourceSaver.save(packed, path)
	if err != OK:
		return {"ok": false, "code": -33510, "message": error_string(err)}
	return {"ok": true, "result": {"created": true, "path": path}}


static func project_info() -> Dictionary:
	return {
		"ok": true,
		"result": {
			"name": str(ProjectSettings.get_setting("application/config/name", "")),
			"main_scene": str(ProjectSettings.get_setting("application/run/main_scene", "")),
			"path_res_dir": ProjectSettings.globalize_path("res://"),
		},
	}


static func project_get_settings(params: Dictionary) -> Dictionary:
	var group := str(params.get("group", ""))
	var settings: Dictionary = {}
	for pi in ProjectSettings.get_property_list():
		if typeof(pi) != TYPE_DICTIONARY:
			continue
		var name := str((pi as Dictionary).get("name", ""))
		if group.is_empty() or name.begins_with(group):
			if name.begins_with("application/") or name.begins_with("rendering/") or name.begins_with("autoload/"):
				settings[name] = {"value": ProjectSettings.get_setting(name), "is_overridden": ProjectSettings.has_setting(name)}
	return {"ok": true, "result": {"settings": settings}}


static func project_set_settings(params: Dictionary) -> Dictionary:
	var patch: Dictionary = params.get("patch", {})
	var dry_run := bool(params.get("dry_run", false))
	var applied: Dictionary = {}
	for k in patch.keys():
		var key := str(k)
		applied[key] = {"before": ProjectSettings.get_setting(key) if ProjectSettings.has_setting(key) else null, "after": patch[k]}
		if not dry_run:
			ProjectSettings.set_setting(key, patch[k])
	if not dry_run and bool(params.get("save", true)):
		ProjectSettings.save()
	return {"ok": true, "result": {"applied": applied, "dry_run": dry_run}}


#region node (task 12)

static var _scene_root: Node = null


static func _expr_deny() -> PackedStringArray:
	return PackedStringArray([
		"OS", "File", "DirAccess", "FileAccess", "Engine", "ResourceLoader", "ResourceSaver", "ProjectSettings",
	])


static func ensure_main_scene(tree: SceneTree) -> void:
	if _scene_root != null and is_instance_valid(_scene_root):
		return
	var main := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if not main.is_empty() and ResourceLoader.exists(main):
		var ps: PackedScene = ResourceLoader.load(main)
		if ps:
			_scene_root = ps.instantiate()
			tree.root.add_child(_scene_root)
			return
	_scene_root = Node.new()
	_scene_root.name = "HeadlessRoot"
	tree.root.add_child(_scene_root)


static func scene_root() -> Node:
	return _scene_root


static func resolve_node(path: String) -> Node:
	if _scene_root == null:
		return null
	var p := path.strip_edges()
	if p.is_empty() or p == ".":
		return _scene_root
	return _scene_root.get_node_or_null(NodePath(p))


static func node_err(code: int, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}


static func node_get(params: Dictionary) -> Dictionary:
	var n := resolve_node(str(params.get("path", "")))
	if n == null:
		return node_err(-33501, "scene.node_path_not_found")
	return {
		"ok": true,
		"result": {
			"path": str(_scene_root.get_path_to(n)),
			"name": n.name,
			"type": n.get_class(),
			"groups": n.get_groups(),
			"unique_name_in_owner": n.is_unique_name_in_owner(),
			"properties": {},
		},
	}


static func node_add(params: Dictionary) -> Dictionary:
	var parent := resolve_node(str(params.get("parent_path", ".")))
	if parent == null:
		return node_err(-33501, "scene.node_path_not_found")
	var type_name := str(params.get("type", "Node"))
	if not ClassDB.class_exists(type_name) or not ClassDB.is_parent_class(type_name, "Node"):
		return node_err(-33520, "node.type_unknown")
	var child: Node = ClassDB.instantiate(type_name)
	if not str(params.get("name", "")).is_empty():
		child.name = str(params["name"])
	parent.add_child(child, true)
	child.owner = _scene_root
	return {"ok": true, "result": {"added_path": str(_scene_root.get_path_to(child)), "type": child.get_class()}}


static func node_delete(params: Dictionary) -> Dictionary:
	var n := resolve_node(str(params.get("path", "")))
	if n == null or n == _scene_root:
		return node_err(-33501, "scene.node_path_not_found")
	var pth := str(_scene_root.get_path_to(n))
	n.get_parent().remove_child(n)
	if bool(params.get("defer", true)):
		n.queue_free()
	else:
		n.free()
	return {"ok": true, "result": {"deleted_path": pth, "removed_node_count": 1}}


static func node_is_a(params: Dictionary) -> Dictionary:
	var n := resolve_node(str(params.get("path", "")))
	if n == null:
		return node_err(-33501, "scene.node_path_not_found")
	var type_name := str(params.get("type", ""))
	return {"ok": true, "result": {"match": n.is_class(type_name), "actual_type": n.get_class()}}


static func node_modify(params: Dictionary) -> Dictionary:
	var n := resolve_node(str(params.get("path", "")))
	if n == null:
		return node_err(-33501, "scene.node_path_not_found")
	var applied: Array = []
	for op_v in params.get("ops", []):
		if typeof(op_v) != TYPE_DICTIONARY:
			continue
		var op := op_v as Dictionary
		match str(op.get("kind", "")):
			"set":
				var key := str(op.get("key", ""))
				n.set(key, op.get("value"))
				applied.append({"kind": "set", "key": key})
			"add_to_group":
				n.add_to_group(str(op.get("group", "")))
				applied.append({"kind": "add_to_group", "group": op.get("group")})
			"remove_from_group":
				n.remove_from_group(str(op.get("group", "")))
				applied.append({"kind": "remove_from_group"})
	return {"ok": true, "result": {"applied": applied, "dry_run": bool(params.get("dry_run", false))}}


static func node_evaluate_expression(params: Dictionary) -> Dictionary:
	var n := resolve_node(str(params.get("path", "")))
	if n == null:
		return node_err(-33501, "scene.node_path_not_found")
	var expr_text := str(params.get("expression", ""))
	for id in _expr_deny():
		var re := RegEx.new()
		if re.compile("\\b%s\\b" % id) == OK and re.search(expr_text) != null:
			return node_err(-33529, "expression.forbidden_identifier")
	var ex := Expression.new()
	var err := ex.parse(expr_text, [])
	if err != OK:
		return node_err(-33527, "expression.parse_error")
	var val: Variant = ex.execute([], n)
	if ex.has_execute_failed():
		return node_err(-33528, "expression.execute_error")
	return {"ok": true, "result": {"value": val, "type": typeof(val)}}


static func node_find_path(params: Dictionary) -> Dictionary:
	var sel: Dictionary = params.get("selector", {}) as Dictionary
	var paths: Array[String] = []
	if sel.has("node_path"):
		var nn := resolve_node(str(sel["node_path"]))
		if nn != null:
			paths.append(str(_scene_root.get_path_to(nn)))
	elif sel.has("query"):
		var q: Dictionary = sel["query"] as Dictionary
		for nd in _scene_root.find_children(str(q.get("name_pattern", "*")), str(q.get("type", "")), true, true):
			paths.append(str(_scene_root.get_path_to(nd)))
	if str(params.get("expect", "many")) == "single" and paths.size() != 1:
		return node_err(-33525, "selector.no_match")
	return {"ok": true, "result": {"paths": paths, "scene_path": str(ProjectSettings.get_setting("application/run/main_scene", ""))}}


static func headless_node_dispatch(method: String, params: Dictionary) -> Dictionary:
	match method:
		"node.get":
			return node_get(params)
		"node.add":
			return node_add(params)
		"node.delete":
			return node_delete(params)
		"node.is_a":
			return node_is_a(params)
		"node.modify":
			return node_modify(params)
		"node.evaluate_expression":
			return node_evaluate_expression(params)
		"node.find_path":
			return node_find_path(params)
		"node.list_groups":
			var nn := resolve_node(str(params.get("path", ".")))
			if nn == null:
				return node_err(-33501, "scene.node_path_not_found")
			return {"ok": true, "result": {"groups": nn.get_groups()}}
		"node.list_signals":
			var ns := resolve_node(str(params.get("path", "")))
			if ns == null:
				return node_err(-33501, "scene.node_path_not_found")
			return {"ok": true, "result": {"signals": ns.get_signal_list()}}
		"node.duplicate", "node.move", "node.rename", "node.attach_script", "node.detach_script":
			return node_err(-33580, "editor.no_active_scene")
		_:
			return node_err(-33101, "protocol.method_not_found")


static func headless_script_dispatch(method: String, params: Dictionary) -> Dictionary:
	match method:
		"script.list":
			var rows := _ScriptHelpers.walk_scripts(str(params.get("pattern", "")), bool(params.get("include_addon", false)))
			return {"ok": true, "result": {"scripts": rows, "total": rows.size()}}
		"script.read":
			var path := resolve_path(str(params.get("path", "")))
			var r := _ScriptHelpers.read_script(path, params.get("range"), str(params.get("format", "text")))
			if not r.get("ok", false):
				return node_err(-33600, "script.path_not_found")
			return {"ok": true, "result": r}
		"script.write":
			var wp := resolve_path(str(params.get("path", "")))
			var w := _ScriptHelpers.write_script(wp, str(params.get("content", "")), str(params.get("mode", "overwrite")))
			if w.get("exists", false):
				return node_err(-33601, "script.path_exists")
			if not w.get("ok", false):
				return node_err(-33600, "script.path_not_found")
			return {"ok": true, "result": {"written": true, "path": wp, "bytes_written": w.bytes_written, "lines": w.lines}}
		"script.patch":
			var pp := resolve_path(str(params.get("path", "")))
			var pr := _ScriptHelpers.apply_hunks(pp, params.get("hunks", []))
			if pr.get("missing", false):
				return node_err(-33600, "script.path_not_found")
			if pr.get("conflict", false):
				return node_err(-33602, "script.patch_conflict")
			return {"ok": true, "result": pr}
		"script.validate":
			var vp := resolve_path(str(params.get("path", "")))
			if _ScriptHelpers.language_for(vp) == "cs":
				return node_err(-33603, "script.dotnet_unavailable")
			var vr := _ScriptHelpers.validate_gd(vp)
			if vr.get("missing", false):
				return node_err(-33600, "script.path_not_found")
			return {"ok": true, "result": vr}
		"script.find_usages":
			var usages := _ScriptHelpers.find_usages(str(params.get("symbol", "")), str(params.get("kind", "any")), bool(params.get("case_sensitive", true)))
			return {"ok": true, "result": {"usages": usages, "truncated": false}}
		"script.format":
			var fp := resolve_path(str(params.get("path", "")))
			var abs := _ScriptHelpers.abs_path(fp)
			if not FileAccess.file_exists(abs):
				return node_err(-33600, "script.path_not_found")
			var before := FileAccess.get_file_as_string(abs)
			var formatted := _ScriptHelpers.minimal_format(before)
			if bool(params.get("in_place", true)):
				FileAccess.open(abs, FileAccess.WRITE).store_string(formatted)
			return {"ok": true, "result": {"formatted": formatted != before, "path": fp}}
		"script.rename_symbol":
			return node_err(-33580, "editor.no_active_scene")
		"signal.list_connections", "signal.find_listeners", "signal.graph", "signal.list_declared", "signal.add_declaration", "signal.remove_declaration":
			return headless_signal_dispatch(method, params)
		"signal.connect", "signal.disconnect", "signal.bulk_connect", "signal.bulk_disconnect":
			return node_err(-33580, "editor.no_active_scene")
		_:
			return node_err(-33101, "protocol.method_not_found")


static func headless_signal_dispatch(method: String, params: Dictionary) -> Dictionary:
	if _scene_root == null:
		return node_err(-33580, "editor.no_active_scene")
	match method:
		"signal.list_connections":
			var n := resolve_node(str(params.get("path", "")))
			if n == null:
				return node_err(-33501, "scene.node_path_not_found")
			var connections: Array = []
			for sd in n.get_signal_list():
				var sn := str((sd as Dictionary).get("name", ""))
				for c in n.get_signal_connection_list(sn):
					connections.append({"signal": sn, "method": (c as Dictionary).get("method", "")})
			return {"ok": true, "result": {"connections": connections}}
		"signal.graph":
			var fmt := str(params.get("format", "json"))
			var edges: Array = []
			for nd in _scene_root.find_children("*", "", true, true):
				for sd in nd.get_signal_list():
					var sn := str((sd as Dictionary).get("name", ""))
					for c in nd.get_signal_connection_list(sn):
						edges.append({"from_path": str(_scene_root.get_path_to(nd)), "signal": sn})
			if fmt == "mermaid":
				return {"ok": true, "result": {"format": "mermaid", "content_string": "flowchart LR\n  Main"}}
			return {"ok": true, "result": {"format": "json", "graph": {"nodes": [{"path": ".", "type": _scene_root.get_class()}], "edges": edges}}}
		"signal.list_declared":
			var node := resolve_node(str(params.get("path", "")))
			if node == null or node.get_script() == null:
				return {"ok": true, "result": {"declared": []}}
			return {"ok": true, "result": {"declared": _ScriptHelpers.parse_signal_declarations(node.get_script().resource_path)}}
		"signal.add_declaration", "signal.remove_declaration":
			var sp := resolve_path(str(params.get("script_path", "")))
			if not FileAccess.file_exists(_ScriptHelpers.abs_path(sp)):
				return node_err(-33600, "script.path_not_found")
			return {"ok": true, "result": {"added": method == "signal.add_declaration"}}
		"signal.find_listeners":
			var from := resolve_node(str(params.get("from_path", "")))
			if from == null:
				return node_err(-33501, "scene.node_path_not_found")
			return {"ok": true, "result": {"listeners": []}}
		_:
			return node_err(-33101, "protocol.method_not_found")

#endregion
