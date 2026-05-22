@tool
extends RefCounted
class_name TerravoltBatchRefactorHandlers

const _Utils := preload("./handler_utils.gd")
const _Assets := preload("./asset_helpers.gd")
const _Res := preload("./resource_helpers.gd")
const _Journal := preload("../services/batch_journal.gd")

var _dispatcher: TerravoltDispatcher
var _logger: TerravoltLogger


func attach(dispatcher: TerravoltDispatcher, logger: TerravoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var rp := {"type": "string", "minLength": 1}
	_dispatcher.register("batch_refactor.preview", _schema({"plan": {"type": "object"}}, ["plan"]), _h_preview)
	_dispatcher.register("batch_refactor.apply", _schema({"plan": {"type": "object"}, "confirm_token": {"type": "string"}, "if_match": {}}), _h_apply)
	_dispatcher.register("batch_refactor.rename_class", _schema({"from": {"type": "string"}, "to": {"type": "string"}, "also_rename_file": {"type": "boolean"}, "dry_run": {"type": "boolean"}}, ["from", "to"]), _h_rename_class)
	_dispatcher.register("batch_refactor.move_folder", _schema({"from": rp, "to": rp, "dry_run": {"type": "boolean"}}, ["from", "to"]), _h_move_folder)
	_dispatcher.register("batch_refactor.replace_in_files", _schema({"pattern": {}, "replacement": {"type": "string"}, "files": {"type": "array"}, "dry_run": {"type": "boolean"}, "max_edits": {"type": "integer"}}, ["pattern", "replacement"]), _h_replace_in_files)
	_dispatcher.register("batch_refactor.normalize_names", _schema({"target": {"type": "string"}, "selector": {"type": "object"}, "dry_run": {"type": "boolean"}}, ["target", "selector"]), _h_normalize_names)
	_dispatcher.register("batch_refactor.change_class", _schema({"selector": {"type": "object"}, "target_class": {"type": "string"}, "preserve_props": {"type": "boolean"}, "dry_run": {"type": "boolean"}}, ["selector", "target_class"]), _h_change_class)
	_dispatcher.register("batch_refactor.history", _schema({"limit": {"type": "integer"}}), _h_history)


func _schema(props: Dictionary, required: Array = []) -> Dictionary:
	var s := {"type": "object", "properties": props, "additionalProperties": false}
	if not required.is_empty():
		s["required"] = required
	return s


func _h_preview(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var plan: Dictionary = p.get("plan", {}) as Dictionary
	var executed := _execute_plan(plan, true)
	var token := _Journal.append_preview(plan, executed)
	executed["confirm_token"] = token
	return {"ok": true, "result": executed}


func _h_apply(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var plan: Dictionary = p.get("plan", {}) as Dictionary
	if p.has("confirm_token"):
		var expected := _Journal.token_for_plan(plan)
		if str(p.get("confirm_token", "")) != expected:
			return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.BATCH_CONFIRM_MISMATCH, "batch.confirm_mismatch", "confirm_token does not match plan.", {})}
	var snapshots := _snapshot_plan_files(plan)
	var executed := _execute_plan(plan, false)
	var revert_token: String = str(Time.get_ticks_msec()) + str(executed.get("total_edits", 0))
	executed["applied"] = true
	executed["revert_token"] = revert_token
	executed["summary"] = "%d ops on %d files" % [plan.get("ops", []).size(), executed.get("total_files", 0)]
	_Journal.append_apply(plan, executed, snapshots)
	if executed.get("ops_failed", 0) > 0:
		return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.BATCH_PARTIAL_FAILURE, "batch.partial_failure", "Some batch ops failed.", executed)}
	_scan()
	return {"ok": true, "result": executed}


func _h_rename_class(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var plan := {"ops": [{"kind": "rename", "from": str(p.get("from", "")), "to": str(p.get("to", "")), "kind_target": "class_name"}]}
	var dry := bool(p.get("dry_run", false))
	var executed := _execute_plan(plan, dry)
	return {"ok": true, "result": {"files_changed": executed.get("total_files", 0), "edits": executed.get("edits", []), "dry_run": dry}}


func _h_move_folder(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var plan := {"ops": [{"kind": "move_folder", "from": str(p.get("from", "")), "to": str(p.get("to", ""))}]}
	var dry := bool(p.get("dry_run", false))
	var executed := _execute_plan(plan, dry)
	return {"ok": true, "result": {"moved": not dry, "files_moved": executed.get("total_files", 0), "references_updated": executed.get("total_edits", 0), "dry_run": dry}}


func _h_replace_in_files(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var plan := {
		"ops": [
			{
				"kind": "replace_string",
				"pattern": p.get("pattern", ""),
				"replacement": str(p.get("replacement", "")),
				"files": p.get("files", []),
				"max_edits": int(p.get("max_edits", 500)),
			}
		]
	}
	var dry := bool(p.get("dry_run", false))
	var executed := _execute_plan(plan, dry)
	return {"ok": true, "result": {"edits": executed.get("edits", []), "applied": not dry, "dry_run": dry}}


func _h_normalize_names(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var plan := {"ops": [{"kind": "normalize_names", "target": str(p.get("target", "snake_case")), "selector": p.get("selector", {})}]}
	var dry := bool(p.get("dry_run", false))
	var executed := _execute_plan(plan, dry)
	return {"ok": true, "result": {"renames": executed.get("edits", []), "applied": not dry, "dry_run": dry}}


func _h_change_class(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var selector: Dictionary = p.get("selector", {}) as Dictionary
	var plan := {
		"ops": [
			{
				"kind": "change_class",
				"selector": selector,
				"from_class": str(selector.get("class", "")),
				"to_class": str(p.get("target_class", "")),
				"preserve_props": bool(p.get("preserve_props", true)),
			}
		]
	}
	var dry := bool(p.get("dry_run", false))
	var executed := _execute_plan(plan, dry)
	if executed.get("ops_failed", 0) > 0:
		return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.BATCH_INCOMPATIBLE_CLASSES, "batch.incompatible_classes", "Class conversion failed.", executed)}
	return {"ok": true, "result": {"converted": executed.get("edits", []), "applied": not dry, "dry_run": dry}}


func _h_history(_ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(_ctx)
	return {"ok": true, "result": {"history": _Journal.history(int(p.get("limit", 20)))}}


func _execute_plan(plan: Dictionary, dry_run: bool) -> Dictionary:
	var ops: Array = plan.get("ops", []) as Array
	var op_results: Array = []
	var all_edits: Array = []
	var total_files := 0
	var ops_failed := 0
	for op_v in ops:
		if typeof(op_v) != TYPE_DICTIONARY:
			continue
		var op := op_v as Dictionary
		var kind := str(op.get("kind", ""))
		var result := _execute_op(kind, op, dry_run)
		op_results.append(result)
		for e in result.get("edits", []):
			all_edits.append(e)
		total_files += int(result.get("files", 0))
		if str(result.get("status", "ok")) != "ok":
			ops_failed += 1
	return {
		"ops": op_results,
		"edits": all_edits,
		"total_edits": all_edits.size(),
		"total_files": total_files,
		"ops_failed": ops_failed,
		"dry_run": dry_run,
	}


func _execute_op(kind: String, op: Dictionary, dry_run: bool) -> Dictionary:
	match kind:
		"rename":
			return _op_rename_class(op, dry_run)
		"move_folder":
			return _op_move_folder(op, dry_run)
		"replace_string":
			return _op_replace_string(op, dry_run)
		"normalize_names":
			return _op_normalize_names(op, dry_run)
		"change_class":
			return _op_change_class(op, dry_run)
		"revert":
			return _op_revert(op, dry_run)
		_:
			return {"op": kind, "status": "failed", "edits": [], "files": 0, "errors": [{"message": "unknown op"}]}


func _op_rename_class(op: Dictionary, dry_run: bool) -> Dictionary:
	var from_name := str(op.get("from", ""))
	var to_name := str(op.get("to", ""))
	var edits: Array = []
	var files := 0
	for fp in _Assets.project_text_files():
		if not str(fp).ends_with(".gd"):
			continue
		var abs := _Assets.abs_path(str(fp))
		var text := FileAccess.get_file_as_string(abs)
		var needle := "class_name %s" % from_name
		if not text.contains(needle):
			continue
		var after := text.replace(needle, "class_name %s" % to_name)
		edits.append({"in_file": fp, "before": needle, "after": "class_name %s" % to_name})
		files += 1
		if not dry_run:
			FileAccess.open(abs, FileAccess.WRITE).store_string(after)
	return {"op": "rename", "status": "ok", "edits": edits, "files": files}


func _op_move_folder(op: Dictionary, dry_run: bool) -> Dictionary:
	var from_p := _Assets.resolve_path(str(op.get("from", "")))
	var to_p := _Assets.resolve_path(str(op.get("to", "")))
	var rr := _Res.replace_references(from_p, to_p, dry_run, [])
	var files := int(rr.get("files_changed", 0))
	if not dry_run:
		var from_abs := _Assets.abs_path(from_p)
		var to_abs := _Assets.abs_path(to_p)
		if DirAccess.dir_exists_absolute(from_abs):
			DirAccess.make_dir_recursive_absolute(to_abs)
			var da := DirAccess.open(from_abs)
			if da:
				da.list_dir_begin()
				while true:
					var name := da.get_next()
					if name.is_empty():
						break
					DirAccess.rename_absolute(from_abs.path_join(name), to_abs.path_join(name))
				da.list_dir_end()
	return {"op": "move_folder", "status": "ok", "edits": rr.get("rewrites", []), "files": files}


func _op_replace_string(op: Dictionary, dry_run: bool) -> Dictionary:
	var pattern_v: Variant = op.get("pattern", "")
	var replacement := str(op.get("replacement", ""))
	var max_edits := int(op.get("max_edits", 500))
	var file_globs: Array = op.get("files", []) as Array
	var edits: Array = []
	var files := 0
	for fp in _target_files(file_globs):
		if not str(fp).ends_with(".gd") and not str(fp).ends_with(".tscn") and not str(fp).ends_with(".tres"):
			continue
		var abs := _Assets.abs_path(str(fp))
		var text := FileAccess.get_file_as_string(abs)
		var after := text
		if typeof(pattern_v) == TYPE_DICTIONARY:
			var re := RegEx.new()
			re.compile(str((pattern_v as Dictionary).get("regex", "")))
			after = re.sub(text, replacement, true)
		else:
			after = text.replace(str(pattern_v), replacement)
		if after == text:
			continue
		edits.append({"in_file": fp, "before": str(pattern_v), "after": replacement})
		files += 1
		if edits.size() > max_edits:
			return {"op": "replace_string", "status": "failed", "edits": edits, "files": files, "errors": [{"message": "too_many_edits"}]}
		if not dry_run:
			FileAccess.open(abs, FileAccess.WRITE).store_string(after)
	return {"op": "replace_string", "status": "ok", "edits": edits, "files": files}


func _op_normalize_names(op: Dictionary, dry_run: bool) -> Dictionary:
	var target := str(op.get("target", "snake_case"))
	var selector: Dictionary = op.get("selector", {}) as Dictionary
	var paths: Array = selector.get("paths", []) as Array
	var edits: Array = []
	var files := 0
	for fp in _target_files(paths):
		if not str(fp).ends_with(".gd"):
			continue
		var base := str(fp).get_file()
		var stem := base.get_basename()
		var new_stem := stem.to_snake_case() if target == "snake_case" else stem
		if new_stem == stem:
			continue
		var new_path := "%s/%s.gd" % [str(fp).get_base_dir(), new_stem]
		edits.append({"from": fp, "to": new_path})
		files += 1
		if not dry_run:
			DirAccess.rename_absolute(_Assets.abs_path(str(fp)), _Assets.abs_path(new_path))
	return {"op": "normalize_names", "status": "ok", "edits": edits, "files": files}


func _op_change_class(op: Dictionary, dry_run: bool) -> Dictionary:
	var from_class := str(op.get("from_class", op.get("selector", {}).get("class", "")))
	var to_class := str(op.get("to_class", op.get("target_class", "")))
	if from_class.is_empty() or to_class.is_empty():
		return {"op": "change_class", "status": "failed", "edits": [], "files": 0}
	if not ClassDB.class_exists(to_class):
		return {"op": "change_class", "status": "failed", "edits": [], "files": 0, "errors": [{"message": "incompatible"}]}
	var selector: Dictionary = op.get("selector", {}) as Dictionary
	var paths: Array = selector.get("paths", []) as Array
	var edits: Array = []
	var files := 0
	for fp in _target_files(paths):
		if not str(fp).ends_with(".tscn"):
			continue
		var abs := _Assets.abs_path(str(fp))
		var text := FileAccess.get_file_as_string(abs)
		var needle := 'type="%s"' % from_class
		if not text.contains(needle):
			continue
		var after := text.replace(needle, 'type="%s"' % to_class)
		edits.append({"path": fp, "location": fp, "before_class": from_class, "after_class": to_class})
		files += 1
		if not dry_run:
			FileAccess.open(abs, FileAccess.WRITE).store_string(after)
	return {"op": "change_class", "status": "ok", "edits": edits, "files": files}


func _op_revert(op: Dictionary, dry_run: bool) -> Dictionary:
	var token := str(op.get("token", ""))
	var entry := _Journal.find_entry(token)
	if entry.is_empty():
		return {"op": "revert", "status": "failed", "edits": [], "files": 0}
	var snapshots: Dictionary = entry.get("snapshots", {}) as Dictionary
	var edits: Array = []
	var files := 0
	for path in snapshots.keys():
		var snap := str(snapshots[path])
		var abs := _Assets.abs_path(str(path))
		if dry_run:
			edits.append({"in_file": path, "before": "current", "after": "snapshot"})
			files += 1
			continue
		FileAccess.open(abs, FileAccess.WRITE).store_string(snap)
		edits.append({"in_file": path, "before": "applied", "after": "reverted"})
		files += 1
	return {"op": "revert", "status": "ok", "edits": edits, "files": files}


func _target_files(globs: Array) -> Array:
	if globs.is_empty():
		return _Assets.project_text_files()
	var out: Array = []
	for fp in _Assets.project_text_files():
		for g in globs:
			if str(fp).contains(str(g).replace("*", "")):
				out.append(fp)
				break
	return out


func _snapshot_plan_files(plan: Dictionary) -> Dictionary:
	var snaps: Dictionary = {}
	for fp in _Assets.project_text_files():
		snaps[fp] = FileAccess.get_file_as_string(_Assets.abs_path(str(fp)))
		if snaps.size() >= _Assets.BATCH_MAX_FILES:
			break
	return snaps


func _scan() -> void:
	if OS.has_feature("editor"):
		var plug := _Utils.editor_plugin(_dispatcher)
		if plug:
			plug.get_editor_interface().get_resource_filesystem().scan()
