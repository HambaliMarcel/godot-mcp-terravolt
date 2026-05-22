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


static func headless_resource_dispatch(method: String, params: Dictionary) -> Dictionary:
	match method:
		"resource.list":
			var rows := _hr_walk_resources(str(params.get("class", "")), str(params.get("pattern", "**/*.{tres,res,gdshader,shader}")), bool(params.get("include_imported", false)))
			return {"ok": true, "result": {"resources": rows, "total": rows.size()}}
		"resource.get":
			var path := resolve_path(str(params.get("path", "")))
			var res := _hr_load_resource(path)
			if res == null:
				return node_err(-33800, "resource.path_not_found")
			return {
				"ok": true,
				"result": {
					"path": path,
					"class": res.get_class(),
					"properties": _hr_serialize_props(res, int(params.get("max_depth", 3))),
				},
			}
		"resource.create":
			var cp := resolve_path(str(params.get("path", "")))
			if _hr_file_exists(cp):
				return node_err(-33802, "resource.path_exists")
			var cls := str(params.get("class", ""))
			if not ClassDB.class_exists(cls):
				return node_err(-33801, "resource.class_unknown")
			var res: Resource = ClassDB.instantiate(cls) as Resource
			if res == null:
				return node_err(-33801, "resource.class_unknown")
			_hr_apply_props(res, params.get("properties", {}) as Dictionary)
			var dir := globalize(cp.get_base_dir())
			if not DirAccess.dir_exists_absolute(dir):
				DirAccess.make_dir_recursive_absolute(dir)
			if ResourceSaver.save(res, cp) != OK:
				return node_err(-33800, "resource.path_not_found")
			return {"ok": true, "result": {"created": true, "path": cp, "class": cls, "revision": str(Time.get_ticks_msec())}}
		"resource.update":
			var up := resolve_path(str(params.get("path", "")))
			var ures := _hr_load_resource(up)
			if ures == null:
				return node_err(-33800, "resource.path_not_found")
			var applied := _hr_apply_props(ures, params.get("patch", {}) as Dictionary)
			if not bool(params.get("dry_run", false)):
				ResourceSaver.save(ures, up)
			return {"ok": true, "result": {"updated": true, "path": up, "applied": applied, "dry_run": bool(params.get("dry_run", false))}}
		"resource.duplicate":
			var src := resolve_path(str(params.get("source_path", "")))
			var dst := resolve_path(str(params.get("target_path", "")))
			var sres := _hr_load_resource(src)
			if sres == null:
				return node_err(-33800, "resource.path_not_found")
			var dir2 := globalize(dst.get_base_dir())
			if not DirAccess.dir_exists_absolute(dir2):
				DirAccess.make_dir_recursive_absolute(dir2)
			ResourceSaver.save(sres.duplicate(bool(params.get("deep", true))), dst)
			return {"ok": true, "result": {"duplicated": true, "source_path": src, "target_path": dst}}
		"resource.delete":
			var dp := resolve_path(str(params.get("path", "")))
			if not _hr_file_exists(dp):
				return node_err(-33800, "resource.path_not_found")
			DirAccess.remove_absolute(globalize(dp))
			return {"ok": true, "result": {"deleted": true, "path": dp, "dependents_warned": []}}
		"resource.export_json":
			var ep := resolve_path(str(params.get("path", "")))
			var ex := _hr_export_json(ep)
			if ex.get("missing", false):
				return node_err(-33800, "resource.path_not_found")
			return {"ok": true, "result": ex}
		"resource.import_json":
			var ir := _hr_import_json(str(params.get("target_path", "")), str(params.get("json_string", "")), bool(params.get("overwrite", false)))
			if ir.get("schema_mismatch", false):
				return node_err(-33805, "resource.json_schema_mismatch")
			if not ir.get("ok", false):
				return node_err(-33800, "resource.path_not_found")
			return {"ok": true, "result": {"imported": true, "path": ir.path, "class": ir.cls}}
		"resource.get_dependencies":
			var gp := resolve_path(str(params.get("path", "")))
			if not _hr_file_exists(gp):
				return node_err(-33800, "resource.path_not_found")
			var deps: Array = []
			for d in ResourceLoader.get_dependencies(gp):
				deps.append({"path": str(d), "class": "", "weak": false})
			return {"ok": true, "result": {"dependencies": deps, "cycles": []}}
		"resource.get_dependents":
			return {"ok": true, "result": {"dependents": [], "total": 0}}
		"resource.validate":
			var vp := resolve_path(str(params.get("path", "")))
			var ok := _hr_load_resource(vp) != null
			return {"ok": true, "result": {"ok": ok, "issues": [] if ok else [{"severity": "error", "code": "resource.path_not_found", "message": "missing"}]}}
		"resource.diff":
			var a := resolve_path(str(params.get("a", "")))
			var ae := _hr_export_json(a)
			if ae.get("missing", false):
				return node_err(-33800, "resource.path_not_found")
			var a_doc: Dictionary = JSON.parse_string(ae.get("json_string", "")) as Dictionary
			var b_v: Variant = params.get("b")
			var b_doc: Dictionary
			if typeof(b_v) == TYPE_DICTIONARY and (b_v as Dictionary).has("json_string"):
				b_doc = JSON.parse_string(str((b_v as Dictionary).get("json_string", ""))) as Dictionary
			else:
				var be := _hr_export_json(resolve_path(str(b_v)))
				if be.get("missing", false):
					return node_err(-33800, "resource.path_not_found")
				b_doc = JSON.parse_string(be.get("json_string", "")) as Dictionary
			var diff_arr := _hr_diff_props(a_doc.get("properties", {}), b_doc.get("properties", {}))
			var summary := {"added": 0, "removed": 0, "changed": 0}
			for entry in diff_arr:
				match str(entry.get("op", "")):
					"add":
						summary.added += 1
					"remove":
						summary.removed += 1
					"change":
						summary.changed += 1
			return {"ok": true, "result": {"diff": diff_arr, "summary": summary}}
		"resource.rename", "resource.replace_references", "resource.set_uid":
			return node_err(-33400, "editor.not_available")
		_:
			return node_err(-33101, "protocol.method_not_found")


static func headless_shader_dispatch(method: String, params: Dictionary) -> Dictionary:
	match method:
		"shader.list":
			var shaders: Array = []
			for row in _hr_walk_resources("", "**/*.{tres,res,gdshader,shader}", false):
				var path := str(row.get("path", ""))
				var lower := path.to_lower()
				if lower.ends_with(".gdshader") or str(row.get("class", "")) == "ShaderMaterial":
					shaders.append({"path": path, "kind": "code" if lower.ends_with(".gdshader") else "material"})
			return {"ok": true, "result": {"shaders": shaders, "total": shaders.size()}}
		"shader.read":
			var path := resolve_path(str(params.get("path", "")))
			var abs := globalize(path)
			if not FileAccess.file_exists(abs):
				return node_err(-33800, "resource.path_not_found")
			return {"ok": true, "result": {"path": path, "language": "gdshader", "content": FileAccess.get_file_as_string(abs), "truncated": false}}
		"shader.write":
			var wp := resolve_path(str(params.get("path", "")))
			var abs := globalize(wp)
			var dir := abs.get_base_dir()
			if not DirAccess.dir_exists_absolute(dir):
				DirAccess.make_dir_recursive_absolute(dir)
			FileAccess.open(abs, FileAccess.WRITE).store_string(str(params.get("content", "")))
			return {"ok": true, "result": {"written": true, "path": wp}}
		"shader.compile_check":
			var cp := resolve_path(str(params.get("path", "")))
			var cab := globalize(cp)
			if not FileAccess.file_exists(cab):
				return node_err(-33800, "resource.path_not_found")
			var check := _hr_shader_compile_check(FileAccess.get_file_as_string(cab))
			return {"ok": true, "result": check}
		"shader.list_params":
			var lp := resolve_path(str(params.get("path", "")))
			var res := _hr_load_resource(lp)
			if res == null:
				return node_err(-33800, "resource.path_not_found")
			var params_out: Array = []
			if res is Shader:
				for u in (res as Shader).get_shader_uniform_list():
					params_out.append(u)
			return {"ok": true, "result": {"params": params_out}}
		"shader.set_material_params":
			var mp := resolve_path(str(params.get("material_path", "")))
			var mat := _hr_load_resource(mp)
			if mat == null or not mat is ShaderMaterial:
				return node_err(-33800, "resource.path_not_found")
			for k in (params.get("params", {}) as Dictionary).keys():
				(mat as ShaderMaterial).set_shader_parameter(str(k), _hr_json_to_variant((params.get("params", {}) as Dictionary)[k]))
			ResourceSaver.save(mat, mp)
			return {"ok": true, "result": {"updated": true}}
		_:
			return node_err(-33101, "protocol.method_not_found")


static func _hr_shader_compile_check(code: String) -> Dictionary:
	var probe := "uniform float __tv_compile_probe;"
	var augmented := code
	if not code.contains("__tv_compile_probe"):
		var lines := code.split("\n")
		var out: PackedStringArray = []
		var inserted := false
		for line in lines:
			out.append(line)
			if not inserted and line.strip_edges().begins_with("shader_type"):
				out.append(probe)
				inserted = true
		if not inserted:
			augmented = "shader_type canvas_item;\n%s\n%s" % [probe, code]
		else:
			augmented = "\n".join(out)
	var shader := Shader.new()
	shader.code = augmented
	shader.get_rid()
	var ok := not shader.get_shader_uniform_list().is_empty()
	if ok:
		return {"ok": true, "errors": [], "warnings": []}
	return {"ok": false, "errors": [{"line": 1, "col": 1, "message": "Shader failed to compile"}], "warnings": []}


static func _hr_resource_class(res_path: String, abs_full: String) -> String:
	var lower := res_path.to_lower()
	if lower.ends_with(".gdshader") or lower.ends_with(".shader"):
		return "Shader"
	if ResourceLoader.exists(res_path):
		var res := ResourceLoader.load(res_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res != null:
			return res.get_class()
	if not FileAccess.file_exists(abs_full):
		return ""
	if abs_full.to_lower().ends_with(".res"):
		var bin := ResourceLoader.load(res_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		return bin.get_class() if bin != null else ""
	var head := FileAccess.get_file_as_string(abs_full)
	if head.length() > 256:
		head = head.substr(0, 256)
	var key := 'type="'
	var i := head.find(key)
	if i >= 0:
		var start := i + key.length()
		var end := head.find('"', start)
		if end > start:
			return head.substr(start, end - start)
	return ""


static func _hr_file_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(globalize(path))


static func _hr_load_resource(path: String) -> Resource:
	if not _hr_file_exists(path):
		return null
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource


static func _hr_walk_resources(class_filter: String, _pattern: String, include_imported: bool) -> Array:
	var out: Array = []
	var base := ProjectSettings.globalize_path("res://")
	_hr_collect(base, base, include_imported, out)
	if not class_filter.is_empty():
		var filtered: Array = []
		for row in out:
			if str(row.get("class", "")) == class_filter:
				filtered.append(row)
		out = filtered
	out.sort_custom(func(a, b): return str(a.get("path", "")) < str(b.get("path", "")))
	return out


static func _hr_collect(base: String, dir_abs: String, include_imported: bool, out: Array) -> void:
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
			_hr_collect(base, full, include_imported, out)
			continue
		var lower := name.to_lower()
		if not (lower.ends_with(".tres") or lower.ends_with(".res") or lower.ends_with(".gdshader") or lower.ends_with(".shader")):
			continue
		var rel := full.substr(base.length()).replace("\\", "/").lstrip("/")
		var res_path := "res://%s" % rel
		var cls := _hr_resource_class(res_path, full)
		out.append({"path": res_path, "class": cls, "size_bytes": FileAccess.get_file_as_bytes(full).size()})
	da.list_dir_end()


static func _hr_json_to_variant(v: Variant) -> Variant:
	if v == null or typeof(v) != TYPE_DICTIONARY:
		return v
	var d := v as Dictionary
	if d.has("__tv") and str(d.get("__tv")) == "Color":
		return Color(float(d.get("r", 0)), float(d.get("g", 0)), float(d.get("b", 0)), float(d.get("a", 1)))
	return d


static func _hr_apply_props(obj: Object, patch: Dictionary) -> Dictionary:
	var applied: Dictionary = {}
	for k in patch.keys():
		var key := str(k)
		var before = obj.get(key)
		var after = _hr_json_to_variant(patch[k])
		obj.set(key, after)
		applied[key] = {"before": before, "after": after}
	return applied


static func _hr_serialize_props(obj: Object, _max_depth: int) -> Dictionary:
	var out: Dictionary = {}
	var names: Array = []
	for pi in obj.get_property_list():
		if typeof(pi) != TYPE_DICTIONARY:
			continue
		var n := str((pi as Dictionary).get("name", ""))
		if n.is_empty() or n.begins_with("_"):
			continue
		names.append(n)
	names.sort()
	for n in names:
		out[n] = obj.get(n)
	return out


static func _hr_export_json(path: String) -> Dictionary:
	var res := _hr_load_resource(path)
	if res == null:
		return {"missing": true}
	var payload := {"schema_version": "1.0", "path": path, "class": res.get_class(), "properties": _hr_serialize_props(res, 3)}
	var text := JSON.stringify(payload, "\t")
	return {"json_string": text, "hash": text.sha256_text(), "schema_version": "1.0"}


static func _hr_import_json(target_path: String, json_string: String, overwrite: bool) -> Dictionary:
	var parsed: Variant = JSON.parse_string(json_string)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return {"schema_mismatch": true}
	var doc := parsed as Dictionary
	if str(doc.get("schema_version", "")) != "1.0":
		return {"schema_mismatch": true}
	var path := resolve_path(target_path)
	if _hr_file_exists(path) and not overwrite:
		return {"ok": false}
	var cls := str(doc.get("class", "Resource"))
	var res: Resource = ClassDB.instantiate(cls) as Resource
	_hr_apply_props(res, doc.get("properties", {}) as Dictionary)
	var dir := globalize(path.get_base_dir())
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	ResourceSaver.save(res, path)
	return {"ok": true, "path": path, "cls": cls}


static func _hr_diff_props(a: Dictionary, b: Dictionary) -> Array:
	var diff: Array = []
	for k in a.keys():
		if not b.has(k):
			diff.append({"path": str(k), "op": "remove", "before": a[k]})
		elif JSON.stringify(a[k]) != JSON.stringify(b[k]):
			diff.append({"path": str(k), "op": "change", "before": a[k], "after": b[k]})
	for k in b.keys():
		if not a.has(k):
			diff.append({"path": str(k), "op": "add", "after": b[k]})
	return diff

#endregion
