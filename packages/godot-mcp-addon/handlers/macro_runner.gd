@tool
extends RefCounted
class_name TerraVoltMacroRunner

## Per-macro execution state (task 24) — separate file so scene ops can call catalog_ops.

const MAX_OPS := 200

const _Err := preload("../error_codes.gd")
const _Ops := preload("../headless/catalog_ops.gd")
const _Utils := preload("./handler_utils.gd")
const _Script := preload("./script_helpers.gd")
const _Journal := preload("../services/macro_journal.gd")

var macro_name: String
var params: Dictionary
var tree: SceneTree
var dry_run: bool = false
var confirm_high_risk: bool = false
var ops_plan: Array = []
var created: Array = []
var modified: Array = []
var snapshots: Dictionary = {}
var ops_applied: int = 0
var _blocked: String = ""


func _init(p_macro: String, p_params: Dictionary, p_tree: SceneTree) -> void:
	macro_name = p_macro
	params = p_params
	tree = p_tree
	dry_run = bool(params.get("dry_run", false))
	confirm_high_risk = bool(params.get("confirm_high_risk", false))


static func _cat() -> RefCounted:
	return _Ops


static func _assign_owners(node: Node, scene_root: Node) -> void:
	node.owner = scene_root
	for child in node.get_children():
		_assign_owners(child, scene_root)


func fail(code: int, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}


func plan(kind: String, args: Dictionary, why: String) -> void:
	if not _blocked.is_empty():
		return
	if ops_plan.size() >= MAX_OPS:
		_blocked = "macro.ops_limit"
		return
	ops_plan.append({"kind": kind, "args": args, "why": why})


func track_created(kind: String, path: String) -> void:
	created.append({"kind": kind, "path": path})


func track_modified(kind: String, path: String) -> void:
	modified.append({"kind": kind, "path": path})


func snapshot_path(res_path: String) -> void:
	var p: String = _Utils.resolve_resource_path(res_path)
	var abs: String = _Utils.globalize(p)
	if FileAccess.file_exists(abs):
		snapshots[p] = FileAccess.get_file_as_string(abs)
	else:
		snapshots[p] = null


func write_file(res_path: String, content: String, mode: String = "create_only") -> Dictionary:
	var p: String = _Utils.resolve_resource_path(res_path)
	plan("script.write", {"path": p, "mode": mode, "bytes": content.length()}, "write %s" % p)
	if dry_run:
		return {"ok": true}
	var exists := FileAccess.file_exists(_Utils.globalize(p))
	if exists and mode == "create_only" and not confirm_high_risk:
		return fail(_Err.MACRO_FILE_EXISTS, "macro.file_exists")
	if exists:
		snapshot_path(p)
		track_modified("file", p)
	else:
		track_created("file", p)
	var w := _Script.write_script(p, content, "overwrite" if exists else mode)
	if not w.get("ok", false):
		if w.get("exists", false):
			return fail(_Err.MACRO_FILE_EXISTS, "macro.file_exists")
		return fail(_Err.MACRO_APPLY_FAILED, "macro.apply_failed")
	ops_applied += 1
	return {"ok": true}


func add_node(parent_path: String, type_name: String, node_name: String) -> Dictionary:
	plan(
		"node.add",
		{"parent_path": parent_path, "type": type_name, "name": node_name},
		"add %s %s" % [type_name, node_name]
	)
	if dry_run:
		return {"ok": true, "path": "%s/%s" % [parent_path.trim_suffix("/"), node_name]}
	var ops := _cat()
	if ops == null:
		return fail(_Err.MACRO_APPLY_FAILED, "macro.apply_failed")
	ops.ensure_main_scene(tree)
	var g: Dictionary = ops.node_add({"parent_path": parent_path, "type": type_name, "name": node_name})
	if not g.get("ok", false):
		return fail(int(g.get("code", -34006)), str(g.get("message", "macro.apply_failed")))
	ops_applied += 1
	return {"ok": true, "path": str(g.get("result", {}).get("added_path", node_name))}


func attach_script(node_path: String, script_path: String) -> Dictionary:
	plan("node.attach_script", {"path": node_path, "script_path": script_path}, "attach script")
	if dry_run:
		return {"ok": true}
	var ops := _cat()
	if ops == null:
		return fail(_Err.MACRO_APPLY_FAILED, "macro.apply_failed")
	var node: Node = ops.resolve_node(node_path)
	if node == null:
		return fail(_Err.MACRO_SCENE_REQUIRED, "macro.scene_required")
	var scr: Script = load(_Utils.resolve_resource_path(script_path)) as Script
	if scr == null:
		return fail(_Err.MACRO_TEMPLATE_MISSING, "macro.template_missing")
	node.set_script(scr)
	ops_applied += 1
	return {"ok": true}


func save_active_scene(scene_path: String) -> Dictionary:
	var p: String = _Utils.resolve_resource_path(scene_path)
	plan("scene.save", {"path": p}, "persist active scene")
	if dry_run:
		return {"ok": true}
	var ops := _cat()
	if ops == null:
		return fail(_Err.MACRO_APPLY_FAILED, "macro.apply_failed")
	ops.ensure_main_scene(tree)
	var root: Node = ops.scene_root()
	if root == null:
		return fail(_Err.MACRO_SCENE_REQUIRED, "macro.scene_required")
	snapshot_path(p)
	track_modified("scene", p)
	var packed := PackedScene.new()
	_assign_owners(root, root)
	var err := packed.pack(root)
	if err != OK:
		return fail(_Err.MACRO_APPLY_FAILED, "macro.apply_failed")
	var abs_dir: String = _Utils.globalize(p.get_base_dir())
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)
	err = ResourceSaver.save(packed, p)
	if err != OK:
		return fail(_Err.MACRO_APPLY_FAILED, "macro.apply_failed")
	ops_applied += 1
	return {"ok": true}


func ensure_input_action(action: String, physical_key: Key) -> Dictionary:
	plan("input.add_action", {"action": action, "key": physical_key}, "register input %s" % action)
	if dry_run:
		return {"ok": true}
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_key
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)
	ops_applied += 1
	return {"ok": true}


func add_autoload(autoload_name: String, script_path: String) -> Dictionary:
	var p: String = _Utils.resolve_resource_path(script_path)
	plan("project.add_autoload", {"name": autoload_name, "path": p}, "autoload %s" % autoload_name)
	if dry_run:
		return {"ok": true}
	var key := "autoload/%s" % autoload_name
	if ProjectSettings.has_setting(key) and not confirm_high_risk:
		return fail(_Err.MACRO_FILE_EXISTS, "macro.file_exists")
	if ProjectSettings.has_setting(key):
		snapshot_path("project.godot")
	ProjectSettings.set_setting(key, "*%s" % p)
	ProjectSettings.save()
	track_modified("autoload", autoload_name)
	ops_applied += 1
	return {"ok": true}


func save_packed_scene(out_path: String, root: Node) -> Dictionary:
	var p: String = _Utils.resolve_resource_path(out_path)
	plan("scene.create", {"path": p}, "write scene %s" % p)
	if dry_run:
		track_created("scene", p)
		return {"ok": true}
	if FileAccess.file_exists(_Utils.globalize(p)):
		snapshot_path(p)
		if not confirm_high_risk:
			return fail(_Err.MACRO_FILE_EXISTS, "macro.file_exists")
		track_modified("scene", p)
	else:
		track_created("scene", p)
	_assign_owners(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		return fail(_Err.MACRO_APPLY_FAILED, "macro.apply_failed")
	var abs_dir: String = _Utils.globalize(p.get_base_dir())
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)
	err = ResourceSaver.save(packed, p)
	root.queue_free()
	if err != OK:
		return fail(_Err.MACRO_APPLY_FAILED, "macro.apply_failed")
	ops_applied += 1
	return {"ok": true}


func ops_ensure() -> Dictionary:
	var ops := _cat()
	if ops == null:
		return fail(_Err.MACRO_APPLY_FAILED, "macro.apply_failed")
	ops.ensure_main_scene(tree)
	return {"ok": true}


func result(summary: String) -> Dictionary:
	if not _blocked.is_empty():
		return fail(_Err.MACRO_OPS_LIMIT, _blocked)
	var out := {
		"ok": true,
		"ops_applied": ops_plan.size() if dry_run else ops_applied,
		"created": created,
		"modified": modified,
		"dry_run": dry_run,
		"summary": summary,
	}
	if dry_run:
		out["plan"] = {"ops": ops_plan}
		return out
	var token := _Journal.new_revert_token(macro_name)
	out["revert_token"] = token
	_Journal.store_revert_snapshots(token, snapshots)
	_Journal.append_entry(
		{
			"id": token.substr(0, 12),
			"macro": macro_name,
			"params": params,
			"applied_at": Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()), true),
			"ops_applied": ops_applied,
			"revert_token": token,
		}
	)
	return out
