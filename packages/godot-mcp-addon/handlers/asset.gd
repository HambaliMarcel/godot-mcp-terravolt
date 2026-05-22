@tool
extends RefCounted
class_name TerravoltAssetHandlers

const _Utils := preload("./handler_utils.gd")
const _Assets := preload("./asset_helpers.gd")

var _dispatcher: TerravoltDispatcher
var _logger: TerravoltLogger
var _revisions: Dictionary = {}


func attach(dispatcher: TerravoltDispatcher, logger: TerravoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var rp := {"type": "string", "minLength": 1}
	_dispatcher.register("asset.list", _schema({"kind": {"type": "string"}, "pattern": {"type": "string"}, "include_imports": {"type": "boolean"}}), _h_list)
	_dispatcher.register("asset.import_status", _schema({"path": rp, "scope": {"type": "string"}, "folder": rp}), _h_import_status)
	_dispatcher.register("asset.reimport", _schema({"path": rp, "scope": {"type": "string"}, "folder": rp}), _h_reimport)
	_dispatcher.register("asset.get_import_settings", _schema({"path": rp}, ["path"]), _h_get_import_settings)
	_dispatcher.register("asset.set_import_settings", _schema({"path": rp, "patch": {"type": "object"}, "reimport_after": {"type": "boolean"}}, ["path", "patch"]), _h_set_import_settings)
	_dispatcher.register("asset.add", _schema({"path": rp, "content_base64": {"type": "string"}, "source_url": {"type": "string"}, "overwrite": {"type": "boolean"}}, ["path"]), _h_add)
	_dispatcher.register("asset.delete", _schema({"path": rp, "force": {"type": "boolean"}}, ["path"]), _h_delete)
	_dispatcher.register("asset.rename", _schema({"from": rp, "to": rp, "update_references": {"type": "boolean"}, "dry_run": {"type": "boolean"}}, ["from", "to"]), _h_rename)
	_dispatcher.register("asset.preview", _schema({"path": rp, "size": {"type": "object"}}, ["path"]), _h_preview)
	_dispatcher.register("asset.metadata", _schema({"path": rp}, ["path"]), _h_metadata)
	_dispatcher.register("asset.batch_import_presets", _schema({"preset": {"type": "string"}, "paths": {"type": "array"}, "pattern": {"type": "string"}, "dry_run": {"type": "boolean"}}, ["preset"]), _h_batch_presets)
	_dispatcher.register("asset.find_unused", _schema({"kind": {"type": "string"}, "exclude": {"type": "array"}}), _h_find_unused)


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
	var rows := _Assets.walk_assets(str(p.get("kind", "any")), str(p.get("pattern", "")), bool(p.get("include_imports", true)))
	return {"ok": true, "result": {"assets": rows, "total": rows.size()}}


func _h_import_status(_ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(_ctx)
	var items := _Assets.import_status_for(str(p.get("path", "")), str(p.get("scope", "all")), str(p.get("folder", "")))
	return {"ok": true, "result": {"items": items}}


func _h_reimport(ctx: Dictionary) -> Dictionary:
	var ed := _Utils.require_editor(_dispatcher)
	if not ed.get("ok", false):
		return ed
	var p := _Utils.params_dict(ctx)
	var scope := str(p.get("scope", "file"))
	var paths: Array = []
	if scope == "project":
		for row in _Assets.walk_assets("any", "", true):
			paths.append(str(row.get("path", "")))
	elif scope == "folder":
		var folder := _Utils.resolve_resource_path(str(p.get("folder", "")))
		for row in _Assets.walk_assets("any", "", true):
			var rp := str(row.get("path", ""))
			if rp.begins_with(folder):
				paths.append(rp)
	else:
		paths.append(_Utils.resolve_resource_path(str(p.get("path", ""))))
	var t0 := Time.get_ticks_msec()
	var fs := (ed.plugin as EditorPlugin).get_editor_interface().get_resource_filesystem()
	var reimported: Array = []
	var errors: Array = []
	for rp in paths:
		if not _Assets.file_exists(str(rp)):
			errors.append({"path": rp, "message": "missing"})
			continue
		fs.reimport_files(PackedStringArray([str(rp)]))
		reimported.append(rp)
	_scan()
	return {"ok": true, "result": {"reimported": reimported, "duration_ms": Time.get_ticks_msec() - t0, "errors": errors}}


func _h_get_import_settings(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	if not _Assets.file_exists(path):
		return _err_path_not_found(path)
	return {"ok": true, "result": _Assets.get_import_settings(path)}


func _h_set_import_settings(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	if not _Assets.file_exists(path):
		return _err_path_not_found(path)
	var patch: Dictionary = p.get("patch", {}) as Dictionary
	var applied := _Assets.set_import_settings(path, patch, bool(p.get("reimport_after", true)))
	if not applied.get("ok", false):
		return _err_path_not_found(path)
	if bool(p.get("reimport_after", true)):
		var ed := _Utils.require_editor(_dispatcher)
		if ed.get("ok", false):
			var fs := (ed.plugin as EditorPlugin).get_editor_interface().get_resource_filesystem()
			fs.reimport_files(PackedStringArray([path]))
	_scan()
	return {"ok": true, "result": {"updated": true, "applied": applied.get("applied", {}), "reimported": bool(p.get("reimport_after", true)), "revision": _bump_revision(path)}}


func _h_add(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	if _Assets.file_exists(path) and not bool(p.get("overwrite", false)):
		return _err_path_exists(path)
	var bytes := PackedByteArray()
	if p.has("content_base64"):
		bytes = Marshalls.base64_to_raw(str(p.get("content_base64", "")))
	elif p.has("source_url"):
		var url := str(p.get("source_url", ""))
		if url.begins_with("file://"):
			var local := url.substr(7)
			if FileAccess.file_exists(local):
				bytes = FileAccess.get_file_as_bytes(local)
	if bytes.is_empty():
		return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.ASSET_TOO_LARGE, "asset.too_large", "No asset bytes provided.", {})}
	if bytes.size() > _Assets.MAX_INLINE_KB * 1024:
		return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.ASSET_TOO_LARGE, "asset.too_large", "Asset exceeds inline byte limit.", {"max_kb": _Assets.MAX_INLINE_KB})}
	var added := _Assets.add_asset(path, bytes, bool(p.get("overwrite", false)))
	if added.get("exists", false):
		return _err_path_exists(path)
	if added.get("too_large", false):
		return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.ASSET_TOO_LARGE, "asset.too_large", "Asset exceeds inline byte limit.", {})}
	_scan()
	return {"ok": true, "result": {"added": true, "path": added.path, "size_bytes": added.size_bytes, "kind": added.kind, "import_triggered": true}}


func _h_delete(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	if not _Assets.file_exists(path):
		return _err_path_not_found(path)
	var deleted := _Assets.delete_asset(path, bool(p.get("force", false)))
	if deleted.get("blocked", false):
		return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.RESOURCE_DEPENDENCY_BLOCK, "resource.dependency_block", "Asset has inbound references.", {"path": path})}
	if not deleted.get("deleted", false):
		return _err_path_not_found(path)
	_scan()
	return {"ok": true, "result": deleted}


func _h_rename(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var from_p := _Utils.resolve_resource_path(str(p.get("from", "")))
	var to_p := _Utils.resolve_resource_path(str(p.get("to", "")))
	if not _Assets.file_exists(from_p):
		return _err_path_not_found(from_p)
	if _Assets.file_exists(to_p):
		return _err_path_exists(to_p)
	var result := _Assets.rename_asset(from_p, to_p, bool(p.get("update_references", true)), bool(p.get("dry_run", false)))
	if result.get("ok", true) == false:
		return _err_path_not_found(from_p)
	if not bool(p.get("dry_run", false)):
		_scan()
	return {"ok": true, "result": result}


func _h_preview(ctx: Dictionary) -> Dictionary:
	var ed := _Utils.require_editor(_dispatcher)
	if not ed.get("ok", false):
		return ed
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	if not _Assets.file_exists(path):
		return _err_path_not_found(path)
	var tex: Texture2D = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if tex == null:
		return {"ok": true, "result": {"kind": _Assets.kind_for_name(path), "content_base64": "", "mime": "image/png"}}
	var img := tex.get_image()
	if img == null or img.is_empty():
		img = Image.new()
		if img.load(_Assets.abs_path(path)) != OK:
			return {"ok": true, "result": {"kind": _Assets.kind_for_name(path), "content_base64": "", "mime": "image/png"}}
	var size := p.get("size", {}) as Dictionary
	var w := int(size.get("w", 256))
	var h := int(size.get("h", 256))
	img.resize(maxi(1, w), maxi(1, h))
	return {"ok": true, "result": {"kind": _Assets.kind_for_name(path), "content_base64": Marshalls.raw_to_base64(img.save_png_to_buffer()), "mime": "image/png"}}


func _h_metadata(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	if not _Assets.file_exists(path):
		return _err_path_not_found(path)
	return {"ok": true, "result": _Assets.metadata_for(path)}


func _h_batch_presets(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var preset := str(p.get("preset", ""))
	if not _Assets.IMPORT_PRESETS.has(preset):
		return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.ASSET_PRESET_UNKNOWN, "asset.preset_unknown", "Unknown import preset.", {"preset": preset})}
	var patch: Dictionary = _Assets.IMPORT_PRESETS[preset]
	var targets: Array = []
	if p.has("paths"):
		for rp in p.get("paths", []):
			targets.append(_Utils.resolve_resource_path(str(rp)))
	else:
		var pat := str(p.get("pattern", ""))
		for row in _Assets.walk_assets("texture", pat, true):
			targets.append(str(row.get("path", "")))
	var applied: Array = []
	var dry := bool(p.get("dry_run", false))
	for rp in targets:
		if dry:
			applied.append(rp)
			continue
		_Assets.set_import_settings(str(rp), patch, false)
		applied.append(rp)
	if not dry:
		var ed := _Utils.require_editor(_dispatcher)
		if ed.get("ok", false):
			var fs := (ed.plugin as EditorPlugin).get_editor_interface().get_resource_filesystem()
			var ps := PackedStringArray()
			for rp in applied:
				ps.append(str(rp))
			if ps.size() > 0:
				fs.reimport_files(ps)
		_scan()
	return {"ok": true, "result": {"applied_to": applied, "reimported": not dry, "dry_run": dry}}


func _h_find_unused(_ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(_ctx)
	var unused := _Assets.find_unused(str(p.get("kind", "any")), p.get("exclude", []) as Array)
	var total_bytes := 0
	for row in unused:
		total_bytes += int(row.get("size_bytes", 0))
	return {"ok": true, "result": {"unused": unused, "total": unused.size(), "total_freed_estimate_bytes": total_bytes}}


func _scan() -> void:
	if OS.has_feature("editor"):
		var plug := _Utils.editor_plugin(_dispatcher)
		if plug:
			plug.get_editor_interface().get_resource_filesystem().scan()


func _err_path_not_found(path: String) -> Dictionary:
	return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.RESOURCE_PATH_NOT_FOUND, "resource.path_not_found", "Asset file not found.", {"path": path})}


func _err_path_exists(path: String) -> Dictionary:
	return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.ASSET_PATH_EXISTS, "asset.path_exists", "Asset path already exists.", {"path": path})}
