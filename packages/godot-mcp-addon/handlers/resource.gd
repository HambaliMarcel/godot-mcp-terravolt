@tool
extends RefCounted
class_name TerravoltResourceHandlers

const _Utils := preload("./handler_utils.gd")
const _Res := preload("./resource_helpers.gd")

var _dispatcher: TerravoltDispatcher
var _logger: TerravoltLogger
var _revisions: Dictionary = {}


func attach(dispatcher: TerravoltDispatcher, logger: TerravoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var rp := {"type": "string", "minLength": 1}
	_dispatcher.register("resource.list", _schema({"class": {"type": "string"}, "pattern": {"type": "string"}, "include_imported": {"type": "boolean"}}), _h_list)
	_dispatcher.register("resource.get", _schema({"path": rp, "include_subresources": {"type": "boolean"}, "max_depth": {"type": "integer"}}, ["path"]), _h_get)
	_dispatcher.register("resource.create", _schema({"path": rp, "class": {"type": "string"}, "properties": {"type": "object"}, "take_over_path": {"type": "boolean"}}, ["path", "class"]), _h_create)
	_dispatcher.register("resource.update", _schema({"path": rp, "patch": {"type": "object"}, "if_match": {}, "dry_run": {"type": "boolean"}}, ["path", "patch"]), _h_update)
	_dispatcher.register("resource.duplicate", _schema({"source_path": rp, "target_path": rp, "deep": {"type": "boolean"}, "overwrite": {"type": "boolean"}}, ["source_path", "target_path"]), _h_duplicate)
	_dispatcher.register("resource.delete", _schema({"path": rp, "force": {"type": "boolean"}}, ["path"]), _h_delete)
	_dispatcher.register("resource.rename", _schema({"from": rp, "to": rp, "update_references": {"type": "boolean"}, "dry_run": {"type": "boolean"}}, ["from", "to"]), _h_rename)
	_dispatcher.register("resource.get_dependencies", _schema({"path": rp, "deep": {"type": "boolean"}}, ["path"]), _h_get_dependencies)
	_dispatcher.register("resource.get_dependents", _schema({"path": rp, "scope": {"type": "string"}, "folder": rp}, ["path"]), _h_get_dependents)
	_dispatcher.register("resource.replace_references", _schema({"from_path": rp, "to_path": rp, "dry_run": {"type": "boolean"}, "exclude": {"type": "array"}}, ["from_path", "to_path"]), _h_replace_references)
	_dispatcher.register("resource.export_json", _schema({"path": rp, "include_subresources": {"type": "boolean"}}, ["path"]), _h_export_json)
	_dispatcher.register("resource.import_json", _schema({"target_path": rp, "json_string": {"type": "string"}, "overwrite": {"type": "boolean"}}, ["target_path", "json_string"]), _h_import_json)
	_dispatcher.register("resource.set_uid", _schema({"path": rp, "uid": {"type": "string"}, "force": {"type": "boolean"}}, ["path"]), _h_set_uid)
	_dispatcher.register("resource.validate", _schema({"path": rp}, ["path"]), _h_validate)
	_dispatcher.register("resource.diff", _schema({"a": rp, "b": {}}, ["a", "b"]), _h_diff)


func _schema(props: Dictionary, required: Array = []) -> Dictionary:
	var s := {"type": "object", "properties": props, "additionalProperties": false}
	if not required.is_empty():
		s["required"] = required
	return s


func _revision(path: String) -> String:
	return str(_revisions.get(path, Time.get_ticks_msec()))


func _bump_revision(path: String) -> String:
	var r := str(Time.get_ticks_msec())
	_revisions[path] = r
	return r


func _h_list(_ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(_ctx)
	var rows := _Res.walk_resources(str(p.get("class", "")), str(p.get("pattern", _Res.RESOURCE_GLOB)), bool(p.get("include_imported", false)))
	return {"ok": true, "result": {"resources": rows, "total": rows.size()}}


func _h_get(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	var res := _Res.load_resource(path)
	if res == null:
		return _err_path_not_found(path)
	var max_depth := int(p.get("max_depth", 3))
	var props := _Res.serialize_properties(res, max_depth)
	return {
		"ok": true,
		"result": {
			"path": path,
			"class": res.get_class(),
			"uid": _Res.resource_uid(path),
			"resource_name": res.resource_name if res.resource_name.length() > 0 else null,
			"properties": props,
		},
	}


func _h_create(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	if _Res.file_exists(path):
		return _err_path_exists(path)
	var cls := str(p.get("class", ""))
	if not ClassDB.class_exists(cls):
		return _err_class_unknown(cls)
	var res: Resource = ClassDB.instantiate(cls) as Resource
	if res == null:
		return _err_class_unknown(cls)
	if bool(p.get("take_over_path", false)):
		res.take_over_path(path)
	var patch: Dictionary = p.get("properties", {}) as Dictionary
	_Res.apply_properties(res, patch)
	var dir := _Res.abs_path(path.get_base_dir())
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		return _err_path_not_found(path)
	_scan()
	return {
		"ok": true,
		"result": {"created": true, "path": path, "class": cls, "uid": _Res.resource_uid(path), "revision": _bump_revision(path)},
	}


func _h_update(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	if p.has("if_match") and str(p.get("if_match", "")) != _revision(path):
		return _err_idempotency()
	var res := _Res.load_resource(path)
	if res == null:
		return _err_path_not_found(path)
	var patch: Dictionary = p.get("patch", {}) as Dictionary
	var dry_run := bool(p.get("dry_run", false))
	var applied := _Res.apply_properties(res, patch)
	if not dry_run:
		ResourceSaver.save(res, path)
		_scan()
	return {"ok": true, "result": {"updated": true, "path": path, "applied": applied, "dry_run": dry_run, "revision": _bump_revision(path)}}


func _h_duplicate(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var src := _Utils.resolve_resource_path(str(p.get("source_path", "")))
	var dst := _Utils.resolve_resource_path(str(p.get("target_path", "")))
	if _Res.file_exists(dst) and not bool(p.get("overwrite", false)):
		return _err_path_exists(dst)
	var res := _Res.load_resource(src)
	if res == null:
		return _err_path_not_found(src)
	var dup := res.duplicate(bool(p.get("deep", true)))
	var dir := _Res.abs_path(dst.get_base_dir())
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	ResourceSaver.save(dup, dst)
	_scan()
	return {"ok": true, "result": {"duplicated": true, "source_path": src, "target_path": dst, "revision": _bump_revision(dst)}}


func _h_delete(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	if not _Res.file_exists(path):
		return _err_path_not_found(path)
	var dependents: Array = []
	for row in _Res.get_dependents(path, "project", ""):
		dependents.append(str((row as Dictionary).get("path", "")))
	if not bool(p.get("force", false)) and not dependents.is_empty():
		return {
			"ok": false,
			"error": TerravoltErrors.tv_rpc_error(
				TerravoltErrors.RESOURCE_DEPENDENCY_BLOCK,
				"resource.dependency_block",
				"Resource is referenced by other files; pass force=true to delete anyway.",
				{"path": path, "dependents": dependents}
			),
		}
	var abs := _Res.abs_path(path)
	var sz := FileAccess.get_file_as_bytes(abs).size() if FileAccess.file_exists(abs) else 0
	DirAccess.remove_absolute(abs)
	var import_path := abs + ".import"
	if FileAccess.file_exists(import_path):
		DirAccess.remove_absolute(import_path)
	_scan()
	return {"ok": true, "result": {"deleted": true, "path": path, "freed_bytes": sz, "dependents_warned": dependents}}


func _h_rename(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var from_p := _Utils.resolve_resource_path(str(p.get("from", "")))
	var to_p := _Utils.resolve_resource_path(str(p.get("to", "")))
	if not _Res.file_exists(from_p):
		return _err_path_not_found(from_p)
	if _Res.file_exists(to_p):
		return _err_path_exists(to_p)
	var dry_run := bool(p.get("dry_run", false))
	var refs: Array = []
	if bool(p.get("update_references", true)):
		var rr := _Res.replace_references(from_p, to_p, dry_run, p.get("exclude", []))
		refs = rr.get("rewrites", [])
	if not dry_run:
		var abs_from := _Res.abs_path(from_p)
		var abs_to := _Res.abs_path(to_p)
		var dir := _Res.abs_path(to_p.get_base_dir())
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)
		DirAccess.rename_absolute(abs_from, abs_to)
		_scan()
	return {"ok": true, "result": {"renamed": not dry_run, "from": from_p, "to": to_p, "references_updated": refs, "dry_run": dry_run}}


func _h_get_dependencies(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	if not _Res.file_exists(path):
		return _err_path_not_found(path)
	var r := _Res.get_dependencies(path, bool(p.get("deep", false)))
	return {"ok": true, "result": r}


func _h_get_dependents(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	var rows := _Res.get_dependents(path, str(p.get("scope", "project")), str(p.get("folder", "")))
	return {"ok": true, "result": {"dependents": rows, "total": rows.size()}}


func _h_replace_references(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var r := _Res.replace_references(
		str(p.get("from_path", "")),
		str(p.get("to_path", "")),
		bool(p.get("dry_run", false)),
		p.get("exclude", [])
	)
	if not bool(p.get("dry_run", false)):
		_scan()
	return {"ok": true, "result": r}


func _h_export_json(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	var r := _Res.export_json(path, bool(p.get("include_subresources", true)))
	if r.get("missing", false):
		return _err_path_not_found(path)
	return {"ok": true, "result": {"json_string": r.json_string, "hash": r.hash, "schema_version": r.schema_version}}


func _h_import_json(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var r := _Res.import_json(str(p.get("target_path", "")), str(p.get("json_string", "")), bool(p.get("overwrite", false)))
	if r.get("schema_mismatch", false):
		return _err_json_schema()
	if r.get("exists", false):
		return _err_path_exists(str(p.get("target_path", "")))
	if r.get("class_unknown", false):
		return _err_class_unknown("unknown")
	if not r.get("ok", false):
		return _err_path_not_found(str(p.get("target_path", "")))
	_scan()
	return {"ok": true, "result": {"imported": true, "path": r.path, "class": r["class"], "revision": r.revision}}


func _h_set_uid(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	var r := _Res.assign_uid(path, str(p.get("uid", "")), bool(p.get("force", false)))
	if r.get("missing", false):
		return _err_path_not_found(path)
	return {"ok": true, "result": {"uid": r.uid, "previous_uid": r.get("previous_uid")}}


func _h_validate(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	var r := _Res.validate_resource(path)
	return {"ok": true, "result": r}


func _h_diff(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var a_path := _Utils.resolve_resource_path(str(p.get("a", "")))
	var b_v: Variant = p.get("b")
	var a_exp := _Res.export_json(a_path, true)
	if a_exp.get("missing", false):
		return _err_path_not_found(a_path)
	var a_doc: Dictionary = JSON.parse_string(a_exp.json_string) as Dictionary
	var b_doc: Dictionary
	if typeof(b_v) == TYPE_DICTIONARY and (b_v as Dictionary).has("json_string"):
		b_doc = JSON.parse_string(str((b_v as Dictionary).get("json_string", ""))) as Dictionary
	else:
		var b_path := _Utils.resolve_resource_path(str(b_v))
		var b_exp := _Res.export_json(b_path, true)
		if b_exp.get("missing", false):
			return _err_path_not_found(b_path)
		b_doc = JSON.parse_string(b_exp.json_string) as Dictionary
	var diff := _Res.diff_json(a_doc.get("properties", {}), b_doc.get("properties", {}))
	var summary := {"added": 0, "removed": 0, "changed": 0}
	for d in diff:
		match str((d as Dictionary).get("op", "")):
			"add":
				summary.added += 1
			"remove":
				summary.removed += 1
			"change":
				summary.changed += 1
	return {"ok": true, "result": {"diff": diff, "summary": summary}}


func _scan() -> void:
	if OS.has_feature("editor"):
		var plug := _Utils.editor_plugin(_dispatcher)
		if plug:
			plug.get_editor_interface().get_resource_filesystem().scan()


func _err_path_not_found(path: String) -> Dictionary:
	return {
		"ok": false,
		"error": TerravoltErrors.tv_rpc_error(
			TerravoltErrors.RESOURCE_PATH_NOT_FOUND,
			"resource.path_not_found",
			"Resource file not found at the given path.",
			{"path": path}
		),
	}


func _err_path_exists(path: String) -> Dictionary:
	return {
		"ok": false,
		"error": TerravoltErrors.tv_rpc_error(
			TerravoltErrors.RESOURCE_PATH_EXISTS,
			"resource.path_exists",
			"Resource already exists at the target path.",
			{"path": path}
		),
	}


func _err_class_unknown(cls: String) -> Dictionary:
	return {
		"ok": false,
		"error": TerravoltErrors.tv_rpc_error(
			TerravoltErrors.RESOURCE_CLASS_UNKNOWN,
			"resource.class_unknown",
			"Unknown Godot resource class.",
			{"class": cls}
		),
	}


func _err_json_schema() -> Dictionary:
	return {
		"ok": false,
		"error": TerravoltErrors.tv_rpc_error(
			TerravoltErrors.RESOURCE_JSON_SCHEMA_MISMATCH,
			"resource.json_schema_mismatch",
			"JSON payload does not match the resource export schema.",
			{}
		),
	}


func _err_idempotency() -> Dictionary:
	return {
		"ok": false,
		"error": TerravoltErrors.tv_rpc_error(
			TerravoltErrors.PROTOCOL_IDEMPOTENCY_CONFLICT,
			"protocol.idempotency_conflict",
			"Revision mismatch (if_match).",
			{}
		),
	}
