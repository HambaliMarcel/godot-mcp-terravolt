@tool
extends RefCounted
class_name TerravoltHandlerUtils

## Shared helpers for category handlers (task 11+).

const _Err := preload("../error_codes.gd")


static func params_dict(ctx: Dictionary) -> Dictionary:
	var p: Variant = ctx.get("params")
	return p as Dictionary if typeof(p) == TYPE_DICTIONARY else {}


static func editor_plugin(dispatcher: Variant) -> EditorPlugin:
	var wr: WeakRef = dispatcher.editor_plugin_ref
	if wr == null:
		return null
	return wr.get_ref() as EditorPlugin


static func require_editor(dispatcher: Variant) -> Dictionary:
	if not OS.has_feature("editor"):
		return {
			"ok": false,
			"error": _Err.tv_rpc_error(
				_Err.EDITOR_NOT_AVAILABLE,
				"editor.not_available",
				"Open the Godot editor with the Terravolt addon enabled, or use a headless-capable method.",
				{}
			),
		}
	var plug := editor_plugin(dispatcher)
	if plug == null:
		return {
			"ok": false,
			"error": _Err.tv_rpc_error(
				_Err.EDITOR_NOT_AVAILABLE,
				"editor.not_available",
				"Editor plugin reference is unavailable.",
				{}
			),
		}
	return {"ok": true, "plugin": plug}


static func resolve_resource_path(raw: String) -> String:
	var s := raw.strip_edges()
	if s.is_empty():
		return ""
	if s.begins_with("res://") or s.begins_with("user://"):
		return s
	if s.begins_with("/") or (s.length() >= 3 and s[1] == ":"):
		return ProjectSettings.localize_path(s)
	return "res://%s" % s.lstrip("/")


static func scene_file_exists(path: String) -> bool:
	var p := resolve_resource_path(path)
	if p.is_empty():
		return false
	return ResourceLoader.exists(p) or FileAccess.file_exists(ProjectSettings.globalize_path(p))


static func globalize(path: String) -> String:
	return ProjectSettings.globalize_path(resolve_resource_path(path))


static func scene_uid(res_path: String) -> Variant:
	var uid: int = ResourceLoader.get_resource_uid(res_path)
	if uid != ResourceUID.INVALID_ID and ResourceUID.has_id(uid):
		return ResourceUID.id_to_text(uid)
	return null


static func file_modified_iso(abs_path: String) -> String:
	if not FileAccess.file_exists(abs_path):
		return ""
	var mtime := FileAccess.get_modified_time(abs_path)
	return Time.get_datetime_string_from_unix_time(int(mtime), true)


static func scene_glob_patterns(pattern: String) -> PackedStringArray:
	if pattern.is_empty():
		return PackedStringArray(["**/*.tscn", "**/*.scn"])
	return PackedStringArray([pattern])


static func walk_scene_files(include_imported: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var root := ProjectSettings.globalize_path("res://")
	_collect_scenes(root, root, include_imported, out)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("path", "")) < str(b.get("path", "")))
	return out


static func _collect_scenes(base: String, dir_abs: String, include_imported: bool, out: Array[Dictionary]) -> void:
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
			_collect_scenes(base, full, include_imported, out)
			continue
		if not (name.ends_with(".tscn") or name.ends_with(".scn")):
			continue
		if not include_imported and name.ends_with(".import"):
			continue
		var rel := full.substr(base.length()).replace("\\", "/").lstrip("/")
		var res_path := "res://%s" % rel
		var uid_str: Variant = scene_uid(res_path)
		out.append(
			{
				"path": res_path,
				"uid": uid_str,
				"size_bytes": FileAccess.get_file_as_bytes(full).size(),
				"modified_at": file_modified_iso(full),
			}
		)
	da.list_dir_end()


static func packed_scene_summary(path: String) -> Dictionary:
	var res_path := resolve_resource_path(path)
	if not scene_file_exists(res_path):
		return {}
	var deps: Array[String] = []
	for d in ResourceLoader.get_dependencies(res_path):
		deps.append(str(d))
	var root_type := "Unknown"
	var node_count := 0
	var has_script := false
	if ResourceLoader.exists(res_path):
		var ps: PackedScene = ResourceLoader.load(res_path)
		if ps != null:
			var st := ps.get_state()
			node_count = st.get_node_count()
			if node_count > 0:
				root_type = str(st.get_node_type(0))
				var rp := st.get_node_path(0)
				if st.get_node_instance(0) != null:
					has_script = true
				elif st.get_node_property_count(0) > 0:
					pass
	var abs := globalize(res_path)
	return {
		"path": res_path,
		"uid": scene_uid(res_path),
		"root_type": root_type,
		"node_count": node_count,
		"has_script": has_script,
		"last_modified": file_modified_iso(abs),
		"dependencies": deps,
	}


static func build_tree_envelope(root: Node, max_depth: int, max_children: int) -> Dictionary:
	if root == null:
		return {}
	var total := count_nodes(root)
	return {
		"root": {"name": root.name, "type": root.get_class()},
		"depth_returned": max_depth,
		"total_node_count_estimate": total,
		"sample": [node_summary(root, root, 0, max_depth, max_children)],
		"pointers": [],
	}


static func count_nodes(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += count_nodes(ch)
	return c


static func node_summary(scene_root: Node, n: Node, depth: int, max_depth: int, max_children: int) -> Dictionary:
	var sample_children: Array = []
	if depth < max_depth:
		var lim := mini(n.get_child_count(), max_children)
		for i in lim:
			sample_children.append(node_summary(scene_root, n.get_child(i), depth + 1, max_depth, max_children))
	var children_count := n.get_child_count()
	return {
		"name": n.name,
		"type": n.get_class(),
		"path": str(scene_root.get_path_to(n)),
		"has_script": n.get_script() != null,
		"children_count": children_count,
		"sample_children": sample_children,
		"truncated": children_count > max_children,
	}


static func instantiate_type(type_name: String) -> Node:
	if not ClassDB.class_exists(type_name):
		return null
	if not ClassDB.is_parent_class(type_name, "Node"):
		return null
	return ClassDB.instantiate(type_name) as Node


static func err_scene_not_found(path: String) -> Dictionary:
	return {
		"ok": false,
		"error": _Err.tv_rpc_error(
			_Err.SCENE_PATH_NOT_FOUND,
			"scene.path_not_found",
			"Scene file not found at the given path.",
			{"path": path}
		),
	}


static func err_node_not_found(path: String) -> Dictionary:
	return {
		"ok": false,
		"error": _Err.tv_rpc_error(
			_Err.SCENE_NODE_PATH_NOT_FOUND,
			"scene.node_path_not_found",
			"Node path not found in the active scene.",
			{"path": path}
		),
	}


static func err_no_active_scene() -> Dictionary:
	return {
		"ok": false,
		"error": _Err.tv_rpc_error(
			_Err.EDITOR_NO_ACTIVE_SCENE,
			"editor.no_active_scene",
			"No scene is currently being edited.",
			{}
		),
	}


static func err_type_unknown(type_name: String) -> Dictionary:
	return {
		"ok": false,
		"error": _Err.tv_rpc_error(
			_Err.NODE_TYPE_UNKNOWN,
			"node.type_unknown",
			"Unknown or non-Node Godot class.",
			{"type": type_name}
		),
	}


static func resolve_node(scene_root: Node, path: String) -> Node:
	if scene_root == null:
		return null
	var p := path.strip_edges()
	if p.is_empty() or p == ".":
		return scene_root
	return scene_root.get_node_or_null(NodePath(p))


static func is_ancestor(ancestor: Node, node: Node) -> bool:
	var cur := node
	while cur != null:
		if cur == ancestor:
			return true
		cur = cur.get_parent()
	return false


static func sibling_name_taken(parent: Node, name: String, skip: Node = null) -> bool:
	if parent == null:
		return false
	for ch in parent.get_children():
		if ch == skip:
			continue
		if str(ch.name) == name:
			return true
	return false


static func class_hierarchy(node: Node) -> Array[String]:
	var out: Array[String] = []
	var c := node.get_class()
	while ClassDB.class_exists(c) and c.length() > 0:
		out.append(c)
		c = ClassDB.get_parent_class(c)
	return out


static func has_property(obj: Object, key: String) -> bool:
	for pi in obj.get_property_list():
		if typeof(pi) != TYPE_DICTIONARY:
			continue
		if str((pi as Dictionary).get("name", "")) == key:
			return true
	return false


static func read_node_properties(
	node: Node, prop_filter: Variant, include_hint: bool, include_export: bool
) -> Dictionary:
	var out: Dictionary = {}
	var want_all: bool = prop_filter == "all" or prop_filter == null
	var want_keys: Array = []
	if typeof(prop_filter) == TYPE_ARRAY:
		for k in prop_filter:
			want_keys.append(str(k))
	for pi in node.get_property_list():
		if typeof(pi) != TYPE_DICTIONARY:
			continue
		var pd := pi as Dictionary
		var name := str(pd.get("name", ""))
		if name.is_empty() or name.begins_with("_"):
			continue
		if not want_all and not want_keys.has(name):
			continue
		var entry: Dictionary = {"value": node.get(name), "type": int(pd.get("type", TYPE_NIL))}
		if include_hint:
			entry["hint"] = int(pd.get("hint", PROPERTY_HINT_NONE))
			entry["hint_string"] = str(pd.get("hint_string", ""))
		out[name] = entry
	return out


static func node_snapshot(node: Node, scene_root: Node, prop_filter: Variant = "all") -> Dictionary:
	var script_path: Variant = null
	var scr: Variant = node.get_script()
	if scr != null:
		if scr is Script and (scr as Script).resource_path.length() > 0:
			script_path = (scr as Script).resource_path
	return {
		"path": str(scene_root.get_path_to(node)),
		"name": node.name,
		"type": node.get_class(),
		"script": script_path,
		"owner_path": str(scene_root.get_path_to(node.owner)) if node.owner else null,
		"groups": node.get_groups(),
		"unique_name_in_owner": node.is_unique_name_in_owner(),
		"properties": read_node_properties(node, prop_filter, true, true),
	}


static func instantiate_from_type_or_script(type_or_script: String) -> Node:
	if type_or_script.begins_with("res://") or type_or_script.begins_with("user://"):
		if not ResourceLoader.exists(type_or_script):
			return null
		var res: Resource = ResourceLoader.load(type_or_script)
		if res is Script:
			var n := Node.new()
			n.set_script(res)
			return n
		if res is PackedScene:
			return (res as PackedScene).instantiate()
		return null
	return instantiate_type(type_or_script)


static func selector_paths(scene_root: Node, selector: Dictionary) -> Array[String]:
	var paths: Array[String] = []
	if selector.has("node_path"):
		var np := str(selector["node_path"])
		var n := resolve_node(scene_root, np)
		if n != null:
			paths.append(str(scene_root.get_path_to(n)))
		return paths
	if selector.has("query"):
		var q: Dictionary = selector["query"] as Dictionary
		var type_f := str(q.get("type", ""))
		var pattern := str(q.get("name_pattern", "*"))
		var group := str(q.get("group", ""))
		var subtree := str(q.get("in_subtree_of", ""))
		var root: Node = scene_root
		if not subtree.is_empty():
			root = resolve_node(scene_root, subtree)
			if root == null:
				return paths
		if not group.is_empty():
			for gn in scene_root.get_tree().get_nodes_in_group(group):
				if root == scene_root or is_ancestor(root, gn) or gn == root:
					paths.append(str(scene_root.get_path_to(gn)))
		else:
			for n in root.find_children(pattern, type_f, true, true):
				paths.append(str(scene_root.get_path_to(n)))
		return paths
	return paths


static func expression_forbidden(expr: String, deny: PackedStringArray) -> String:
	for id in deny:
		var re := RegEx.new()
		if re.compile("\\b%s\\b" % id) != OK:
			continue
		if re.search(expr) != null:
			return id
	for pat in ["execute", "shell_open", "create_process", "create_instance"]:
		if expr.find(pat) >= 0:
			return pat
	return ""


static func duplicate_flags(flags_spec: Dictionary) -> int:
	var f := Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS
	if flags_spec.has("signals") and not bool(flags_spec["signals"]):
		f &= ~Node.DUPLICATE_SIGNALS
	if flags_spec.has("groups") and not bool(flags_spec["groups"]):
		f &= ~Node.DUPLICATE_GROUPS
	if flags_spec.has("scripts") and not bool(flags_spec["scripts"]):
		f &= ~Node.DUPLICATE_SCRIPTS
	return f
