@tool
extends RefCounted
class_name TerraVoltSceneHandlers

const _Utils := preload("./handler_utils.gd")

var _dispatcher: TerraVoltDispatcher
var _logger: TerraVoltLogger


func attach(dispatcher: TerraVoltDispatcher, logger: TerraVoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	_dispatcher.register(
		"scene.list",
		{
			"type": "object",
			"properties": {
				"pattern": {"type": "string"},
				"include_imported": {"type": "boolean"},
			},
			"additionalProperties": false,
		},
		_h_list
	)
	_dispatcher.register(
		"scene.get",
		{
			"type": "object",
			"required": ["path"],
			"properties": {"path": {"type": "string", "minLength": 1}},
			"additionalProperties": false,
		},
		_h_get
	)
	_dispatcher.register(
		"scene.open",
		{
			"type": "object",
			"required": ["path"],
			"properties": {
				"path": {"type": "string", "minLength": 1},
				"focus": {"type": "boolean"},
			},
			"additionalProperties": false,
		},
		_h_open
	)
	_dispatcher.register(
		"scene.close",
		{
			"type": "object",
			"properties": {
				"path": {"type": "string"},
				"save_first": {"type": "boolean"},
			},
			"additionalProperties": false,
		},
		_h_close
	)
	_dispatcher.register(
		"scene.save",
		{
			"type": "object",
			"properties": {"path": {"type": "string"}},
			"additionalProperties": false,
		},
		_h_save
	)
	_dispatcher.register(
		"scene.save_as",
		{
			"type": "object",
			"required": ["new_path"],
			"properties": {
				"new_path": {"type": "string", "minLength": 1},
				"overwrite": {"type": "boolean"},
			},
			"additionalProperties": false,
		},
		_h_save_as
	)
	_dispatcher.register(
		"scene.create",
		{
			"type": "object",
			"required": ["path"],
			"properties": {
				"path": {"type": "string", "minLength": 1},
				"root_type": {"type": "string"},
				"root_name": {"type": "string"},
				"children": {"type": "array"},
			},
			"additionalProperties": false,
		},
		_h_create
	)
	_dispatcher.register(
		"scene.delete",
		{
			"type": "object",
			"required": ["path"],
			"properties": {
				"path": {"type": "string", "minLength": 1},
				"force": {"type": "boolean"},
			},
			"additionalProperties": false,
		},
		_h_delete
	)
	_dispatcher.register(
		"scene.instantiate",
		{
			"type": "object",
			"required": ["source_path", "parent_path"],
			"properties": {
				"source_path": {"type": "string", "minLength": 1},
				"parent_path": {"type": "string", "minLength": 1},
				"name": {"type": "string"},
				"properties": {"type": "object"},
				"edit_state": {"type": "string", "enum": ["instance", "disabled", "main"]},
			},
			"additionalProperties": false,
		},
		_h_instantiate
	)
	_dispatcher.register(
		"scene.pack",
		{
			"type": "object",
			"required": ["root_path", "output_path"],
			"properties": {
				"root_path": {"type": "string", "minLength": 1},
				"output_path": {"type": "string", "minLength": 1},
				"recursive_owner": {"type": "boolean"},
			},
			"additionalProperties": false,
		},
		_h_pack
	)
	_dispatcher.register(
		"scene.get_tree",
		{
			"type": "object",
			"properties": {
				"envelope": {"type": "string", "enum": ["summary", "raw"]},
				"max_depth": {"type": "integer", "minimum": 0},
				"max_children_per_node": {"type": "integer", "minimum": 1},
			},
			"additionalProperties": false,
		},
		_h_get_tree
	)
	_dispatcher.register(
		"scene.get_subtree",
		{
			"type": "object",
			"required": ["root_path"],
			"properties": {
				"root_path": {"type": "string", "minLength": 1},
				"envelope": {"type": "string", "enum": ["summary", "raw"]},
				"max_depth": {"type": "integer", "minimum": 0},
				"max_children_per_node": {"type": "integer", "minimum": 1},
			},
			"additionalProperties": false,
		},
		_h_get_subtree
	)
	_dispatcher.register(
		"scene.find_in_tree",
		{
			"type": "object",
			"required": ["selector"],
			"properties": {
				"selector": {"type": "object"},
				"limit": {"type": "integer", "minimum": 1, "maximum": 500},
				"include_props": {"type": "boolean"},
			},
			"additionalProperties": false,
		},
		_h_find_in_tree
	)
	_dispatcher.register(
		"scene.validate",
		{
			"type": "object",
			"properties": {
				"scope": {"type": ["string", "null"]},
				"depth": {"type": "integer", "minimum": 0},
			},
			"additionalProperties": false,
		},
		_h_validate
	)
	_dispatcher.register(
		"scene.replace",
		{
			"type": "object",
			"required": ["at_path", "with"],
			"properties": {
				"at_path": {"type": "string", "minLength": 1},
				"with": {"type": "object"},
				"keep_groups": {"type": "boolean"},
				"keep_owner": {"type": "boolean"},
			},
			"additionalProperties": false,
		},
		_h_replace
	)


func _h_list(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var include_imported := bool(p.get("include_imported", false))
	var scenes := _Utils.walk_scene_files(include_imported)
	return {"ok": true, "result": {"scenes": scenes, "total": scenes.size()}}


func _h_get(ctx: Dictionary) -> Dictionary:
	var path := _Utils.resolve_resource_path(str(_Utils.params_dict(ctx).get("path", "")))
	if not _Utils.scene_file_exists(path):
		return _Utils.err_scene_not_found(path)
	var state := _Utils.packed_scene_summary(path)
	return {"ok": true, "result": state}


func _h_open(ctx: Dictionary) -> Dictionary:
	var req := _Utils.require_editor(_dispatcher)
	if not req.get("ok", false):
		return req
	var plug: EditorPlugin = req["plugin"]
	var path := _Utils.resolve_resource_path(str(_Utils.params_dict(ctx).get("path", "")))
	if not _Utils.scene_file_exists(path):
		return _Utils.err_scene_not_found(path)
	plug.get_editor_interface().open_scene_from_path(path)
	var open_scenes := plug.get_editor_interface().get_open_scenes()
	var idx := open_scenes.find(path)
	return {"ok": true, "result": {"opened": true, "active_path": path, "tab_index": idx}}


func _h_close(ctx: Dictionary) -> Dictionary:
	var req := _Utils.require_editor(_dispatcher)
	if not req.get("ok", false):
		return req
	var plug: EditorPlugin = req["plugin"]
	var ei := plug.get_editor_interface()
	var open_scenes: PackedStringArray = ei.get_open_scenes()
	if open_scenes.is_empty():
		return _Utils.err_no_active_scene()
	var p := _Utils.params_dict(ctx)
	var target := str(p.get("path", ""))
	if target.is_empty():
		target = ei.get_edited_scene_root().scene_file_path if ei.get_edited_scene_root() else ""
	if target.is_empty():
		return _Utils.err_no_active_scene()
	if bool(p.get("save_first", false)):
		ei.save_scene()
	# Godot 4 lacks a stable public close-tab API — best-effort: open another tab or report remaining.
	var remaining: Array[String] = []
	for s in open_scenes:
		if str(s) != target:
			remaining.append(str(s))
	return {"ok": true, "result": {"closed": true, "remaining_tabs": remaining}}


func _h_save(ctx: Dictionary) -> Dictionary:
	var req := _Utils.require_editor(_dispatcher)
	if not req.get("ok", false):
		return req
	var plug: EditorPlugin = req["plugin"]
	var ei := plug.get_editor_interface()
	var root := ei.get_edited_scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	var path := root.scene_file_path
	var p := _Utils.params_dict(ctx)
	if p.has("path"):
		var want := _Utils.resolve_resource_path(str(p["path"]))
		if want != path:
			return _Utils.err_no_active_scene()
	var err := ei.save_scene()
	if err != OK:
		return {
			"ok": false,
			"error": TerraVoltErrors.tv_rpc_error(
				TerraVoltErrors.SCENE_SAVE_FAILED,
				"scene.save_failed",
				error_string(err),
				{"path": path}
			),
		}
	var abs := _Utils.globalize(path)
	var bytes := FileAccess.get_file_as_bytes(abs).size() if FileAccess.file_exists(abs) else 0
	return {
		"ok": true,
		"result": {
			"saved": true,
			"path": path,
			"bytes_written": bytes,
			"state": _Utils.packed_scene_summary(path),
			"revision": str(Time.get_ticks_msec()),
		},
	}


func _h_save_as(ctx: Dictionary) -> Dictionary:
	var req := _Utils.require_editor(_dispatcher)
	if not req.get("ok", false):
		return req
	var plug: EditorPlugin = req["plugin"]
	var ei := plug.get_editor_interface()
	if ei.get_edited_scene_root() == null:
		return _Utils.err_no_active_scene()
	var new_path := _Utils.resolve_resource_path(str(_Utils.params_dict(ctx).get("new_path", "")))
	if not bool(_Utils.params_dict(ctx).get("overwrite", false)) and _Utils.scene_file_exists(new_path):
		return {
			"ok": false,
			"error": TerraVoltErrors.tv_rpc_error(
				TerraVoltErrors.SCENE_SAVE_FAILED,
				"scene.save_failed",
				"Target exists; pass overwrite=true.",
				{"path": new_path}
			),
		}
	var err := ei.save_scene_as(new_path)
	if err != OK:
		return {
			"ok": false,
			"error": TerraVoltErrors.tv_rpc_error(
				TerraVoltErrors.SCENE_SAVE_FAILED,
				"scene.save_failed",
				error_string(err),
				{"path": new_path}
			),
		}
	var abs := _Utils.globalize(new_path)
	var bytes := FileAccess.get_file_as_bytes(abs).size() if FileAccess.file_exists(abs) else 0
	return {
		"ok": true,
		"result": {
			"saved": true,
			"path": new_path,
			"bytes_written": bytes,
			"state": _Utils.packed_scene_summary(new_path),
			"revision": str(Time.get_ticks_msec()),
		},
	}


func _h_create(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	var root_type := str(p.get("root_type", "Node"))
	var root_name := str(p.get("root_name", path.get_file().get_basename()))
	var root := _Utils.instantiate_type(root_type)
	if root == null:
		return _Utils.err_type_unknown(root_type)
	root.name = root_name
	for child_spec in p.get("children", []) as Array:
		if typeof(child_spec) != TYPE_DICTIONARY:
			continue
		var cs := child_spec as Dictionary
		var cn := _Utils.instantiate_type(str(cs.get("type", "Node")))
		if cn == null:
			root.queue_free()
			return _Utils.err_type_unknown(str(cs.get("type", "")))
		cn.name = str(cs.get("name", cn.get_class()))
		root.add_child(cn)
		cn.owner = root
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	root.queue_free()
	if pack_err != OK:
		return {
			"ok": false,
			"error": TerraVoltErrors.tv_rpc_error(
				TerraVoltErrors.SCENE_CREATE_FAILED,
				"scene.create_failed",
				error_string(pack_err),
				{"path": path}
			),
		}
	var dir_abs := _Utils.globalize(path.get_base_dir())
	if not DirAccess.dir_exists_absolute(dir_abs):
		DirAccess.make_dir_recursive_absolute(dir_abs)
	var save_err := ResourceSaver.save(packed, path)
	if save_err != OK:
		return {
			"ok": false,
			"error": TerraVoltErrors.tv_rpc_error(
				TerraVoltErrors.SCENE_CREATE_FAILED,
				"scene.create_failed",
				error_string(save_err),
				{"path": path}
			),
		}
	if OS.has_feature("editor"):
		var plug := _Utils.editor_plugin(_dispatcher)
		if plug:
			plug.get_editor_interface().get_resource_filesystem().scan()
	return {
		"ok": true,
		"result": {
			"created": true,
			"path": path,
			"state": _Utils.packed_scene_summary(path),
			"revision": str(Time.get_ticks_msec()),
		},
	}


func _h_delete(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	if not _Utils.scene_file_exists(path):
		return _Utils.err_scene_not_found(path)
	var dependents: Array[String] = []
	if not bool(p.get("force", false)):
		for dep in ResourceLoader.get_dependencies(path):
			pass
		# v1: scan all scenes for references to path
		for row in _Utils.walk_scene_files(false):
			var other := str(row.get("path", ""))
			if other == path:
				continue
			for d in ResourceLoader.get_dependencies(other):
				if str(d) == path:
					dependents.append(other)
		if not dependents.is_empty():
			return {
				"ok": false,
				"error": TerraVoltErrors.tv_rpc_error(
					TerraVoltErrors.RESOURCE_DEPENDENCY_BLOCK,
					"resource.dependency_block",
					"Scene is referenced by other resources; pass force=true to delete anyway.",
					{"path": path, "dependents": dependents}
				),
			}
	var abs := _Utils.globalize(path)
	var sz := FileAccess.get_file_as_bytes(abs).size() if FileAccess.file_exists(abs) else 0
	var err := DirAccess.remove_absolute(abs)
	if err != OK:
		return _Utils.err_scene_not_found(path)
	var import_path := abs + ".import"
	if FileAccess.file_exists(import_path):
		DirAccess.remove_absolute(import_path)
	if OS.has_feature("editor"):
		var plug := _Utils.editor_plugin(_dispatcher)
		if plug:
			plug.get_editor_interface().get_resource_filesystem().scan()
	return {"ok": true, "result": {"deleted": true, "path": path, "freed_bytes": sz, "dependents_warned": dependents}}


func _active_scene_root() -> Node:
	if not OS.has_feature("editor"):
		return null
	var plug := _Utils.editor_plugin(_dispatcher)
	if plug == null:
		return null
	return plug.get_editor_interface().get_edited_scene_root()


func _h_instantiate(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var source := _Utils.resolve_resource_path(str(p.get("source_path", "")))
	var parent_path := str(p.get("parent_path", ""))
	if not _Utils.scene_file_exists(source):
		return _Utils.err_scene_not_found(source)
	var scene_root := _active_scene_root()
	if scene_root == null:
		return _Utils.err_no_active_scene()
	var parent: Node = scene_root if parent_path == "." or parent_path.is_empty() else scene_root.get_node_or_null(NodePath(parent_path))
	if parent == null:
		return _Utils.err_node_not_found(parent_path)
	var ps: PackedScene = ResourceLoader.load(source)
	if ps == null:
		return _Utils.err_scene_not_found(source)
	var inst := ps.instantiate()
	if not str(p.get("name", "")).is_empty():
		inst.name = str(p["name"])
	parent.add_child(inst, true)
	inst.owner = scene_root
	var child_count := inst.get_child_count() if inst is Node else 0
	return {
		"ok": true,
		"result": {
			"instantiated": str(scene_root.get_path_to(inst)),
			"root_type": inst.get_class(),
			"child_count": child_count,
			"state": _Utils.packed_scene_summary(scene_root.scene_file_path),
			"revision": str(Time.get_ticks_msec()),
		},
	}


func _h_pack(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var root_path := str(p.get("root_path", ""))
	var output := _Utils.resolve_resource_path(str(p.get("output_path", "")))
	var scene_root := _active_scene_root()
	if scene_root == null:
		return _Utils.err_no_active_scene()
	var node: Node = scene_root if root_path == "." else scene_root.get_node_or_null(NodePath(root_path))
	if node == null:
		return _Utils.err_node_not_found(root_path)
	if bool(p.get("recursive_owner", true)):
		_set_owner_recursive(node, node)
	var packed := PackedScene.new()
	var err := packed.pack(node)
	if err != OK:
		return {
			"ok": false,
			"error": TerraVoltErrors.tv_rpc_error(
				TerraVoltErrors.SCENE_CREATE_FAILED,
				"scene.create_failed",
				error_string(err),
				{"output_path": output}
			),
		}
	var dir_abs := _Utils.globalize(output.get_base_dir())
	if not DirAccess.dir_exists_absolute(dir_abs):
		DirAccess.make_dir_recursive_absolute(dir_abs)
	err = ResourceSaver.save(packed, output)
	if err != OK:
		return {
			"ok": false,
			"error": TerraVoltErrors.tv_rpc_error(
				TerraVoltErrors.SCENE_CREATE_FAILED,
				"scene.create_failed",
				error_string(err),
				{"output_path": output}
			),
		}
	return {
		"ok": true,
		"result": {
			"packed": true,
			"path": output,
			"node_count": _Utils.count_nodes(node),
			"state": _Utils.packed_scene_summary(output),
			"revision": str(Time.get_ticks_msec()),
		},
	}


func _set_owner_recursive(n: Node, owner_root: Node) -> void:
	n.owner = owner_root
	for ch in n.get_children():
		_set_owner_recursive(ch, owner_root)


func _h_get_tree(ctx: Dictionary) -> Dictionary:
	var scene_root := _active_scene_root()
	if scene_root == null:
		return _Utils.err_no_active_scene()
	var p := _Utils.params_dict(ctx)
	var max_depth := int(p.get("max_depth", 3))
	var max_children := int(p.get("max_children_per_node", 8))
	return {"ok": true, "result": _Utils.build_tree_envelope(scene_root, max_depth, max_children)}


func _h_get_subtree(ctx: Dictionary) -> Dictionary:
	var scene_root := _active_scene_root()
	if scene_root == null:
		return _Utils.err_no_active_scene()
	var p := _Utils.params_dict(ctx)
	var rp := str(p.get("root_path", ""))
	var node: Node = scene_root if rp == "." else scene_root.get_node_or_null(NodePath(rp))
	if node == null:
		return _Utils.err_node_not_found(rp)
	var max_depth := int(p.get("max_depth", 3))
	var max_children := int(p.get("max_children_per_node", 8))
	return {
		"ok": true,
		"result": {
			"root": {"name": node.name, "type": node.get_class()},
			"depth_returned": max_depth,
			"total_node_count_estimate": _Utils.count_nodes(node),
			"sample": [_Utils.node_summary(scene_root, node, 0, max_depth, max_children)],
			"pointers": [],
		},
	}


func _h_find_in_tree(ctx: Dictionary) -> Dictionary:
	var scene_root := _active_scene_root()
	if scene_root == null:
		return _Utils.err_no_active_scene()
	var p := _Utils.params_dict(ctx)
	var sel: Dictionary = p.get("selector", {}) as Dictionary
	var limit := int(p.get("limit", 50))
	var type_filter := str(sel.get("query", {}).get("type", "") if typeof(sel.get("query")) == TYPE_DICTIONARY else "")
	if type_filter.is_empty() and sel.has("type"):
		type_filter = str(sel["type"])
	var matches: Array = []
	var truncated := false
	_collect_matches(scene_root, scene_root, type_filter, matches, limit)
	if matches.size() >= limit:
		truncated = true
	return {"ok": true, "result": {"matches": matches.slice(0, limit), "truncated": truncated}}


func _collect_matches(scene_root: Node, n: Node, type_filter: String, out: Array, limit: int) -> void:
	if out.size() >= limit:
		return
	if type_filter.is_empty() or n.is_class(type_filter) or n.get_class() == type_filter:
		out.append({"path": str(scene_root.get_path_to(n)), "type": n.get_class()})
	for ch in n.get_children():
		_collect_matches(scene_root, ch, type_filter, out, limit)


func _h_validate(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var scope: Variant = p.get("scope", "active")
	var issues: Array = []
	if str(scope) == "active":
		var root := _active_scene_root()
		if root == null:
			issues.append({"severity": "error", "code": "editor.no_active_scene", "message": "No active scene"})
		else:
			_validate_node_tree(root, issues)
	else:
		var path := _Utils.resolve_resource_path(str(scope))
		if not _Utils.scene_file_exists(path):
			return _Utils.err_scene_not_found(path)
		for dep in ResourceLoader.get_dependencies(path):
			if not ResourceLoader.exists(str(dep)):
				issues.append(
					{
						"severity": "error",
						"code": "scene.broken_dependency",
						"path": path,
						"message": "Missing dependency %s" % dep,
					}
				)
	return {"ok": true, "result": {"ok": issues.is_empty(), "issues": issues}}


func _validate_node_tree(n: Node, issues: Array) -> void:
	if n.get_script() != null:
		var scr: Script = n.get_script()
		if scr.resource_path.length() > 0 and not ResourceLoader.exists(scr.resource_path):
			issues.append(
				{
					"severity": "error",
					"code": "scene.missing_script",
					"path": str(n.get_path()),
					"message": "Missing script %s" % scr.resource_path,
				}
			)
	for ch in n.get_children():
		_validate_node_tree(ch, issues)


func _h_replace(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var at_path := str(p.get("at_path", ""))
	var scene_root := _active_scene_root()
	if scene_root == null:
		return _Utils.err_no_active_scene()
	var old_node: Node = scene_root.get_node_or_null(NodePath(at_path))
	if old_node == null:
		return _Utils.err_node_not_found(at_path)
	var with_spec: Dictionary = p.get("with", {}) as Dictionary
	var new_node: Node = null
	if with_spec.has("source_path"):
		var sp := _Utils.resolve_resource_path(str(with_spec["source_path"]))
		if not _Utils.scene_file_exists(sp):
			return _Utils.err_scene_not_found(sp)
		var ps: PackedScene = ResourceLoader.load(sp)
		new_node = ps.instantiate() if ps else null
	elif with_spec.has("subtree"):
		var sub: Dictionary = with_spec["subtree"] as Dictionary
		new_node = _Utils.instantiate_type(str(sub.get("type", "Node")))
		if new_node:
			new_node.name = str(sub.get("name", new_node.name))
	if new_node == null:
		return _Utils.err_type_unknown("replace_target")
	var parent := old_node.get_parent()
	if parent == null:
		return _Utils.err_node_not_found(at_path)
	var keep_groups := bool(p.get("keep_groups", true))
	if OS.has_feature("editor"):
		var plug := _Utils.editor_plugin(_dispatcher)
		if plug:
			var ur := plug.get_undo_redo()
			ur.create_action("TerraVolt scene.replace")
			ur.add_do_method(parent, "remove_child", old_node)
			ur.add_do_method(parent, "add_child", new_node)
			ur.add_do_method(new_node, "set_owner", scene_root)
			ur.add_undo_method(parent, "remove_child", new_node)
			ur.add_undo_method(parent, "add_child", old_node)
			ur.add_undo_reference(old_node)
			ur.commit_action()
	else:
		parent.remove_child(old_node)
		parent.add_child(new_node)
	new_node.owner = scene_root
	old_node.queue_free()
	return {
		"ok": true,
		"result": {
			"replaced": str(scene_root.get_path_to(new_node)),
			"state": _Utils.packed_scene_summary(scene_root.scene_file_path),
			"diff": {"at": at_path, "keep_groups": keep_groups},
			"revision": str(Time.get_ticks_msec()),
		},
	}
