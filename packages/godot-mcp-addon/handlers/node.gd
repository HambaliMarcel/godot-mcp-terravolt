@tool
extends RefCounted
class_name TerravoltNodeHandlers

const _Utils := preload("./handler_utils.gd")

const _EXPR_DENY := PackedStringArray([
	"OS", "File", "DirAccess", "FileAccess", "Engine", "JavaScriptBridge", "HTTPClient", "HTTPRequest",
	"Socket", "StreamPeer", "TCPServer", "UDPServer", "ResourceLoader", "ResourceSaver", "ProjectSettings",
	"ClassDB", "GDScript", "Expression",
])

var _dispatcher: TerravoltDispatcher
var _logger: TerravoltLogger
var _transient_roots: Array[Node] = []


func attach(dispatcher: TerravoltDispatcher, logger: TerravoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var np := {"type": "string", "minLength": 1}
	_dispatcher.register("node.add", _schema({"parent_path": np, "type": {"type": "string"}, "name": {"type": "string"}, "properties": {"type": "object"}, "groups": {"type": "array"}, "index": {"type": "integer"}, "unique_name": {"type": "boolean"}, "scene_path": {"type": "string"}}, ["parent_path", "type"]), _h_add)
	_dispatcher.register("node.delete", _schema({"path": np, "defer": {"type": "boolean"}, "free_resources": {"type": "boolean"}, "scene_path": {"type": "string"}}, ["path"]), _h_delete)
	_dispatcher.register("node.duplicate", _schema({"source_path": np, "target_parent_path": {"type": "string"}, "new_name": {"type": "string"}, "flags": {"type": "object"}, "shallow": {"type": "boolean"}, "scene_path": {"type": "string"}}, ["source_path"]), _h_duplicate)
	_dispatcher.register("node.move", _schema({"source_path": np, "target_parent_path": np, "index": {"type": "integer"}, "keep_global_transform": {"type": "boolean"}, "new_name": {"type": "string"}, "scene_path": {"type": "string"}}, ["source_path", "target_parent_path"]), _h_move)
	_dispatcher.register("node.rename", _schema({"path": np, "new_name": {"type": "string"}, "update_references": {"type": "boolean"}, "dry_run": {"type": "boolean"}, "scene_path": {"type": "string"}}, ["path", "new_name"]), _h_rename)
	_dispatcher.register("node.get", _schema({"path": np, "properties": {}, "include_hint": {"type": "boolean"}, "include_export": {"type": "boolean"}, "envelope": {"type": "string"}, "scene_path": {"type": "string"}}, ["path"]), _h_get)
	_dispatcher.register("node.modify", _schema({"path": np, "ops": {"type": "array"}, "dry_run": {"type": "boolean"}, "if_match": {}, "scene_path": {"type": "string"}}, ["path", "ops"]), _h_modify)
	_dispatcher.register("node.list_groups", _schema({"path": {"type": "string"}, "recursive": {"type": "boolean"}, "scope": {"type": "string"}, "scene_path": {"type": "string"}}), _h_list_groups)
	_dispatcher.register("node.list_signals", _schema({"path": np, "include_inherited": {"type": "boolean"}, "include_connections": {"type": "boolean"}, "scene_path": {"type": "string"}}, ["path"]), _h_list_signals)
	_dispatcher.register("node.find_path", _schema({"selector": {"type": "object"}, "expect": {"type": "string"}, "scene_path": {"type": "string"}}, ["selector"]), _h_find_path)
	_dispatcher.register("node.is_a", _schema({"path": np, "type": {"type": "string"}, "scene_path": {"type": "string"}}, ["path", "type"]), _h_is_a)
	_dispatcher.register("node.attach_script", _schema({"path": np, "script_path": np, "replace_existing": {"type": "boolean"}, "scene_path": {"type": "string"}}, ["path", "script_path"]), _h_attach_script)
	_dispatcher.register("node.detach_script", _schema({"path": np, "scene_path": {"type": "string"}}, ["path"]), _h_detach_script)
	_dispatcher.register("node.evaluate_expression", _schema({"path": np, "expression": {"type": "string"}, "inputs": {"type": "object"}, "scene_path": {"type": "string"}}, ["path", "expression"]), _h_evaluate_expression)


func _schema(props: Dictionary, required: Array = []) -> Dictionary:
	var s := {"type": "object", "properties": props, "additionalProperties": false}
	if not required.is_empty():
		s["required"] = required
	return s


func _scene_ctx(p: Dictionary) -> Dictionary:
	var scene_path := str(p.get("scene_path", ""))
	if not scene_path.is_empty():
		var res := _Utils.resolve_resource_path(scene_path)
		if not _Utils.scene_file_exists(res):
			return {"ok": false, "error": _Utils.err_scene_not_found(res)}
		var ps: PackedScene = ResourceLoader.load(res)
		if ps == null:
			return {"ok": false, "error": _Utils.err_scene_not_found(res)}
		var inst := ps.instantiate()
		_transient_roots.append(inst)
		return {"ok": true, "root": inst, "scene_path": res}
	var root := _active_scene_root()
	if root == null:
		return {"ok": false, "error": _Utils.err_no_active_scene()}
	return {"ok": true, "root": root, "scene_path": root.scene_file_path if root.scene_file_path else ""}


func _active_scene_root() -> Node:
	if not OS.has_feature("editor"):
		return null
	var plug := _Utils.editor_plugin(_dispatcher)
	if plug == null:
		return null
	return plug.get_editor_interface().get_edited_scene_root()


func _revision() -> String:
	return str(Time.get_ticks_msec())


func _h_add(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var sc := _scene_ctx(p)
	if not sc.get("ok", false):
		return sc
	var scene_root: Node = sc["root"]
	var parent_path := str(p.get("parent_path", "."))
	var parent := _Utils.resolve_node(scene_root, parent_path)
	if parent == null:
		return _Utils.err_node_not_found(parent_path)
	var type_name := str(p.get("type", "Node"))
	var child := _Utils.instantiate_from_type_or_script(type_name)
	if child == null:
		return _Utils.err_type_unknown(type_name)
	if not str(p.get("name", "")).is_empty():
		child.name = str(p["name"])
	if _Utils.sibling_name_taken(parent, child.name):
		child.queue_free()
		return _err_name_collision(child.name)
	var props: Dictionary = p.get("properties", {}) as Dictionary
	for k in props.keys():
		if _Utils.has_property(child, str(k)):
			child.set(str(k), props[k])
	var groups: Array = p.get("groups", []) as Array
	for g in groups:
		child.add_to_group(str(g))
	if bool(p.get("unique_name", false)):
		child.unique_name_in_owner = true
	if OS.has_feature("editor") and _Utils.editor_plugin(_dispatcher):
		var ur := _Utils.editor_plugin(_dispatcher).get_undo_redo()
		ur.create_action("Terravolt node.add")
		ur.add_do_method(parent, "add_child", child, true)
		ur.add_do_method(child, "set_owner", scene_root)
		if p.has("index"):
			ur.add_do_method(parent, "move_child", child, int(p["index"]))
		ur.add_undo_method(parent, "remove_child", child)
		ur.add_undo_reference(child)
		ur.commit_action()
	else:
		parent.add_child(child, true)
		if p.has("index"):
			parent.move_child(child, int(p["index"]))
	child.owner = scene_root
	return {
		"ok": true,
		"result": {
			"added_path": str(scene_root.get_path_to(child)),
			"type": child.get_class(),
			"owner": str(scene_root.get_path_to(scene_root)),
			"state": _Utils.node_snapshot(child, scene_root),
			"diff": {"added_nodes": [str(scene_root.get_path_to(child))]},
			"revision": _revision(),
		},
	}


func _h_delete(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var sc := _scene_ctx(p)
	if not sc.get("ok", false):
		return sc
	var scene_root: Node = sc["root"]
	var path := str(p.get("path", ""))
	var node := _Utils.resolve_node(scene_root, path)
	if node == null or node == scene_root:
		return _Utils.err_node_not_found(path)
	var count := _Utils.count_nodes(node)
	var defer := bool(p.get("defer", true))
	if OS.has_feature("editor") and _Utils.editor_plugin(_dispatcher):
		var ur := _Utils.editor_plugin(_dispatcher).get_undo_redo()
		ur.create_action("Terravolt node.delete")
		ur.add_do_method(node.get_parent(), "remove_child", node)
		if defer:
			ur.add_do_method(node, "queue_free")
		else:
			ur.add_do_method(node, "free")
		ur.add_undo_reference(node)
		ur.commit_action()
	else:
		node.get_parent().remove_child(node)
		if defer:
			node.queue_free()
		else:
			node.free()
	return {
		"ok": true,
		"result": {
			"deleted_path": path,
			"removed_node_count": count,
			"state": _Utils.node_snapshot(scene_root, scene_root, []),
			"diff": {"removed_nodes": [path]},
			"revision": _revision(),
		},
	}


func _h_duplicate(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var sc := _scene_ctx(p)
	if not sc.get("ok", false):
		return sc
	var scene_root: Node = sc["root"]
	var source_path := str(p.get("source_path", ""))
	var source := _Utils.resolve_node(scene_root, source_path)
	if source == null:
		return _Utils.err_node_not_found(source_path)
	var flags_spec: Dictionary = p.get("flags", {}) as Dictionary
	var dup := source.duplicate(_Utils.duplicate_flags(flags_spec))
	if dup == null:
		return _Utils.err_node_not_found(source_path)
	if bool(p.get("shallow", false)):
		for ch in dup.get_children():
			ch.queue_free()
	var target_parent := source.get_parent()
	if p.has("target_parent_path"):
		var tp := _Utils.resolve_node(scene_root, str(p["target_parent_path"]))
		if tp == null:
			dup.queue_free()
			return _Utils.err_node_not_found(str(p["target_parent_path"]))
		target_parent = tp
	if not str(p.get("new_name", "")).is_empty():
		dup.name = str(p["new_name"])
	target_parent.add_child(dup, true)
	dup.owner = scene_root
	return {
		"ok": true,
		"result": {
			"duplicate_path": str(scene_root.get_path_to(dup)),
			"name": dup.name,
			"state": _Utils.node_snapshot(dup, scene_root),
			"diff": {"added_nodes": [str(scene_root.get_path_to(dup))]},
			"revision": _revision(),
		},
	}


func _h_move(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var sc := _scene_ctx(p)
	if not sc.get("ok", false):
		return sc
	var scene_root: Node = sc["root"]
	var source_path := str(p.get("source_path", ""))
	var node := _Utils.resolve_node(scene_root, source_path)
	if node == null:
		return _Utils.err_node_not_found(source_path)
	var target_parent_path := str(p.get("target_parent_path", ""))
	var target_parent := _Utils.resolve_node(scene_root, target_parent_path)
	if target_parent == null:
		return _Utils.err_node_not_found(target_parent_path)
	if _Utils.is_ancestor(node, target_parent):
		return {
			"ok": false,
			"error": TerravoltErrors.tv_rpc_error(
				TerravoltErrors.NODE_CYCLE_DETECTED,
				"node.cycle_detected",
				"Cannot reparent under self or descendant.",
				{"source_path": source_path, "target_parent_path": target_parent_path}
			),
		}
	var previous := str(scene_root.get_path_to(node))
	var keep := bool(p.get("keep_global_transform", true))
	node.reparent(target_parent, keep)
	if p.has("index"):
		target_parent.move_child(node, int(p["index"]))
	if not str(p.get("new_name", "")).is_empty():
		node.name = str(p["new_name"])
	return {
		"ok": true,
		"result": {
			"new_path": str(scene_root.get_path_to(node)),
			"previous_path": previous,
			"state": _Utils.node_snapshot(node, scene_root),
			"diff": {"renamed": [{"from": previous, "to": str(scene_root.get_path_to(node))}]},
			"revision": _revision(),
		},
	}


func _h_rename(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var sc := _scene_ctx(p)
	if not sc.get("ok", false):
		return sc
	var scene_root: Node = sc["root"]
	var path := str(p.get("path", ""))
	var node := _Utils.resolve_node(scene_root, path)
	if node == null:
		return _Utils.err_node_not_found(path)
	var new_name := str(p.get("new_name", ""))
	if _Utils.sibling_name_taken(node.get_parent(), new_name, node):
		return _err_name_collision(new_name)
	var dry_run := bool(p.get("dry_run", false))
	var refs: Array = []
	if bool(p.get("update_references", true)) and not dry_run:
		refs = _rewrite_nodepath_refs(scene_root, path, str(node.get_parent().get_path_to(node)) if node.get_parent() else ".", new_name)
	if not dry_run:
		node.name = new_name
	return {
		"ok": true,
		"result": {
			"new_path": str(scene_root.get_path_to(node)),
			"references_updated": refs,
			"dry_run": dry_run,
			"state": _Utils.node_snapshot(node, scene_root),
			"diff": {"renamed": [{"from": path, "to": str(scene_root.get_path_to(node))}]},
			"revision": _revision(),
		},
	}


func _rewrite_nodepath_refs(scene_root: Node, old_segment_path: String, _parent_path: String, new_name: String) -> Array:
	# v1: scan exported NodePath properties on siblings only
	var refs: Array = []
	var old_node := _Utils.resolve_node(scene_root, old_segment_path)
	if old_node == null:
		return refs
	var new_path := str(scene_root.get_path_to(old_node))
	for n in scene_root.find_children("*", "", true, true):
		for pi in n.get_property_list():
			if typeof(pi) != TYPE_DICTIONARY:
				continue
			var pd := pi as Dictionary
			if int(pd.get("type", TYPE_NIL)) != TYPE_NODE_PATH:
				continue
			var key := str(pd.get("name", ""))
			var before: NodePath = n.get(key)
			if str(before).find(old_segment_path) >= 0:
				var after := NodePath(str(before).replace(old_segment_path, new_path))
				n.set(key, after)
				refs.append({"from_path": str(before), "property_or_script": key, "before": str(before), "after": str(after)})
	return refs


func _h_get(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var sc := _scene_ctx(p)
	if not sc.get("ok", false):
		return sc
	var scene_root: Node = sc["root"]
	var path := str(p.get("path", ""))
	var node := _Utils.resolve_node(scene_root, path)
	if node == null:
		return _Utils.err_node_not_found(path)
	var prop_filter: Variant = p.get("properties", "all")
	return {"ok": true, "result": _Utils.node_snapshot(node, scene_root, prop_filter)}


func _h_modify(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var sc := _scene_ctx(p)
	if not sc.get("ok", false):
		return sc
	var scene_root: Node = sc["root"]
	var path := str(p.get("path", ""))
	var node := _Utils.resolve_node(scene_root, path)
	if node == null:
		return _Utils.err_node_not_found(path)
	var ops: Array = p.get("ops", []) as Array
	var dry_run := bool(p.get("dry_run", false))
	var applied: Array = []
	var skipped: Array = []
	var ur: Variant = null
	if not dry_run and OS.has_feature("editor") and _Utils.editor_plugin(_dispatcher):
		ur = _Utils.editor_plugin(_dispatcher).get_undo_redo()
		ur.create_action("Terravolt node.modify")
	for op_variant in ops:
		if typeof(op_variant) != TYPE_DICTIONARY:
			skipped.append({"op": op_variant, "reason": "invalid_op"})
			continue
		var op := op_variant as Dictionary
		var kind := str(op.get("kind", ""))
		var result := _apply_modify_op(node, scene_root, kind, op, dry_run, ur)
		if result.get("ok", false):
			applied.append(result.get("entry", {}))
		else:
			skipped.append({"op": op, "reason": result.get("reason", "failed")})
	if ur != null and not dry_run:
		ur.commit_action()
	return {
		"ok": true,
		"result": {
			"applied": applied,
			"skipped": skipped,
			"dry_run": dry_run,
			"state": _Utils.node_snapshot(node, scene_root),
			"diff": {"property_changes": applied},
			"revision": _revision(),
		},
	}


func _apply_modify_op(node: Node, scene_root: Node, kind: String, op: Dictionary, dry_run: bool, ur: Variant) -> Dictionary:
	match kind:
		"set":
			var key := str(op.get("key", ""))
			if not _Utils.has_property(node, key):
				return {"ok": false, "reason": "node.property_unknown"}
			var before = node.get(key)
			var val = op.get("value")
			if not dry_run:
				if ur:
					ur.add_do_method(node, "set", key, val)
					ur.add_undo_method(node, "set", key, before)
				node.set(key, val)
			return {"ok": true, "entry": {"kind": kind, "key": key, "before": before, "after": val}}
		"add_to_group":
			var group := str(op.get("group", ""))
			if not dry_run:
				node.add_to_group(group, bool(op.get("persistent", false)))
			return {"ok": true, "entry": {"kind": kind, "group": group}}
		"remove_from_group":
			var group := str(op.get("group", ""))
			if not dry_run:
				node.remove_from_group(group)
			return {"ok": true, "entry": {"kind": kind, "group": group}}
		"connect":
			var sig := str(op.get("signal", ""))
			var target_path := str(op.get("target_path", ""))
			var method := str(op.get("method", ""))
			var target := _Utils.resolve_node(scene_root, target_path)
			if target == null:
				return {"ok": false, "reason": "scene.node_path_not_found"}
			if not dry_run:
				node.connect(sig, Callable(target, method), int(op.get("flags", 0)))
			return {"ok": true, "entry": {"kind": kind, "signal": sig, "target_path": target_path, "method": method}}
		"disconnect":
			var sig := str(op.get("signal", ""))
			var target_path := str(op.get("target_path", ""))
			var method := str(op.get("method", ""))
			var target := _Utils.resolve_node(scene_root, target_path)
			if target == null:
				return {"ok": false, "reason": "scene.node_path_not_found"}
			if not dry_run:
				node.disconnect(sig, Callable(target, method))
			return {"ok": true, "entry": {"kind": kind, "signal": sig}}
		"set_meta":
			var key := str(op.get("key", ""))
			if not dry_run:
				node.set_meta(key, op.get("value"))
			return {"ok": true, "entry": {"kind": kind, "key": key}}
		"remove_meta":
			var key := str(op.get("key", ""))
			if not dry_run and node.has_meta(key):
				node.remove_meta(key)
			return {"ok": true, "entry": {"kind": kind, "key": key}}
		_:
			return {"ok": false, "reason": "protocol.invalid_params"}


func _h_list_groups(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var sc := _scene_ctx(p)
	if not sc.get("ok", false):
		return sc
	var scene_root: Node = sc["root"]
	if bool(p.get("recursive", false)):
		var by_path: Dictionary = {}
		var distinct: Dictionary = {}
		for n in scene_root.find_children("*", "", true, true):
			var gs: Array = n.get_groups()
			by_path[str(scene_root.get_path_to(n))] = gs
			for g in gs:
				distinct[g] = true
		var keys: Array = distinct.keys()
		keys.sort()
		return {"ok": true, "result": {"by_path": by_path, "distinct": keys}}
	var path := str(p.get("path", "."))
	var node := _Utils.resolve_node(scene_root, path)
	if node == null:
		return _Utils.err_node_not_found(path)
	return {"ok": true, "result": {"groups": node.get_groups()}}


func _h_list_signals(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var sc := _scene_ctx(p)
	if not sc.get("ok", false):
		return sc
	var scene_root: Node = sc["root"]
	var path := str(p.get("path", ""))
	var node := _Utils.resolve_node(scene_root, path)
	if node == null:
		return _Utils.err_node_not_found(path)
	var include_conn := bool(p.get("include_connections", true))
	var rows: Array = []
	for sd in node.get_signal_list():
		if typeof(sd) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = {"name": str((sd as Dictionary).get("name", "")), "args": (sd as Dictionary).get("args", [])}
		if include_conn:
			row["connections"] = []
			for c in node.get_signal_connection_list(row["name"]):
				if typeof(c) != TYPE_DICTIONARY:
					continue
				var cd := c as Dictionary
				var target: Object = cd.get("callable", Callable()).get_object() if cd.has("callable") else null
				var tp := str(scene_root.get_path_to(target)) if target is Node else ""
				row["connections"].append({"target_path": tp, "method": cd.get("method", ""), "flags": cd.get("flags", 0)})
		rows.append(row)
	return {"ok": true, "result": {"signals": rows}}


func _h_find_path(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var sc := _scene_ctx(p)
	if not sc.get("ok", false):
		return sc
	var scene_root: Node = sc["root"]
	var sel: Dictionary = p.get("selector", {}) as Dictionary
	var paths := _Utils.selector_paths(scene_root, sel)
	var expect := str(p.get("expect", "many"))
	if expect == "single" and paths.size() != 1:
		return {
			"ok": false,
			"error": TerravoltErrors.tv_rpc_error(
				TerravoltErrors.SELECTOR_NO_MATCH,
				"selector.no_match",
				"Expected exactly one match.",
				{"count": paths.size()}
			),
		}
	return {"ok": true, "result": {"paths": paths, "scene_path": sc.get("scene_path", "")}}


func _h_is_a(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var sc := _scene_ctx(p)
	if not sc.get("ok", false):
		return sc
	var scene_root: Node = sc["root"]
	var path := str(p.get("path", ""))
	var node := _Utils.resolve_node(scene_root, path)
	if node == null:
		return _Utils.err_node_not_found(path)
	var type_name := str(p.get("type", ""))
	var match := node.is_class(type_name) or (node.get_script() != null and str(node.get_script().resource_path) == type_name)
	return {
		"ok": true,
		"result": {"match": match, "actual_type": node.get_class(), "class_hierarchy": _Utils.class_hierarchy(node)},
	}


func _h_attach_script(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var sc := _scene_ctx(p)
	if not sc.get("ok", false):
		return sc
	var scene_root: Node = sc["root"]
	var path := str(p.get("path", ""))
	var node := _Utils.resolve_node(scene_root, path)
	if node == null:
		return _Utils.err_node_not_found(path)
	if node.get_script() != null and not bool(p.get("replace_existing", false)):
		return {
			"ok": false,
			"error": TerravoltErrors.tv_rpc_error(
				TerravoltErrors.NODE_SCRIPT_ALREADY_ATTACHED,
				"node.script_already_attached",
				"Node already has a script.",
				{"path": path}
			),
		}
	var script_path := _Utils.resolve_resource_path(str(p.get("script_path", "")))
	if not ResourceLoader.exists(script_path):
		return {
			"ok": false,
			"error": TerravoltErrors.tv_rpc_error(
				TerravoltErrors.SCRIPT_PATH_NOT_FOUND,
				"script.path_not_found",
				"Script file not found.",
				{"script_path": script_path}
			),
		}
	var prev: Variant = null
	if node.get_script() != null:
		prev = node.get_script().resource_path
	var scr: Script = ResourceLoader.load(script_path)
	node.set_script(scr)
	return {
		"ok": true,
		"result": {
			"attached": true,
			"script_path": script_path,
			"previous_script_path": prev,
			"state": _Utils.node_snapshot(node, scene_root),
			"revision": _revision(),
		},
	}


func _h_detach_script(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var sc := _scene_ctx(p)
	if not sc.get("ok", false):
		return sc
	var scene_root: Node = sc["root"]
	var path := str(p.get("path", ""))
	var node := _Utils.resolve_node(scene_root, path)
	if node == null:
		return _Utils.err_node_not_found(path)
	var prev: Variant = null
	if node.get_script() != null:
		prev = node.get_script().resource_path
	node.set_script(null)
	return {
		"ok": true,
		"result": {
			"detached": true,
			"previous_script_path": prev,
			"state": _Utils.node_snapshot(node, scene_root),
			"revision": _revision(),
		},
	}


func _h_evaluate_expression(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var sc := _scene_ctx(p)
	if not sc.get("ok", false):
		return sc
	var scene_root: Node = sc["root"]
	var path := str(p.get("path", ""))
	var node := _Utils.resolve_node(scene_root, path)
	if node == null:
		return _Utils.err_node_not_found(path)
	var expr_text := str(p.get("expression", ""))
	var forbidden := _Utils.expression_forbidden(expr_text, _EXPR_DENY)
	if not forbidden.is_empty():
		return {
			"ok": false,
			"error": TerravoltErrors.tv_rpc_error(
				TerravoltErrors.EXPRESSION_FORBIDDEN_IDENTIFIER,
				"expression.forbidden_identifier",
				"Expression uses a forbidden identifier.",
				{"identifier": forbidden}
			),
		}
	var ex := Expression.new()
	var inputs: Dictionary = p.get("inputs", {}) as Dictionary
	var names: Array[String] = []
	var values: Array = []
	for k in inputs.keys():
		names.append(str(k))
		values.append(inputs[k])
	var err := ex.parse(expr_text, names)
	if err != OK:
		return {
			"ok": false,
			"error": TerravoltErrors.tv_rpc_error(
				TerravoltErrors.EXPRESSION_PARSE_ERROR,
				"expression.parse_error",
				error_string(err),
				{}
			),
		}
	var val: Variant = ex.execute(values, node)
	if ex.has_execute_failed():
		return {
			"ok": false,
			"error": TerravoltErrors.tv_rpc_error(
				TerravoltErrors.EXPRESSION_EXECUTE_ERROR,
				"expression.execute_error",
				"Expression execution failed.",
				{}
			),
		}
	return {"ok": true, "result": {"value": val, "type": typeof(val)}}


func _err_name_collision(name: String) -> Dictionary:
	return {
		"ok": false,
		"error": TerravoltErrors.tv_rpc_error(
			TerravoltErrors.NODE_NAME_COLLISION,
			"node.name_collision",
			"Sibling name already taken.",
			{"name": name}
		),
	}
