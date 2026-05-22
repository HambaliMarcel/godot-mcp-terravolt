@tool
extends RefCounted
class_name TerraVoltScriptHandlers

const _Utils := preload("./handler_utils.gd")
const _Scripts := preload("./script_helpers.gd")

var _dispatcher: TerraVoltDispatcher
var _logger: TerraVoltLogger
var _revisions: Dictionary = {}


func attach(dispatcher: TerraVoltDispatcher, logger: TerraVoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var rp := {"type": "string", "minLength": 1}
	_dispatcher.register("script.list", _schema({"pattern": {"type": "string"}, "include_addon": {"type": "boolean"}}), _h_list)
	_dispatcher.register("script.read", _schema({"path": rp, "range": {"type": "object"}, "format": {"type": "string"}}, ["path"]), _h_read)
	_dispatcher.register("script.write", _schema({"path": rp, "content": {"type": "string"}, "mode": {"type": "string"}, "if_match": {}}, ["path", "content"]), _h_write)
	_dispatcher.register("script.patch", _schema({"path": rp, "hunks": {"type": "array"}, "if_match": {}}, ["path", "hunks"]), _h_patch)
	_dispatcher.register("script.validate", _schema({"path": rp, "mode": {"type": "string"}}, ["path"]), _h_validate)
	_dispatcher.register("script.find_usages", _schema({"symbol": {"type": "string"}, "kind": {"type": "string"}, "case_sensitive": {"type": "boolean"}}, ["symbol"]), _h_find_usages)
	_dispatcher.register("script.rename_symbol", _schema({"scope": {}, "from": {"type": "string"}, "to": {"type": "string"}, "kind": {"type": "string"}, "dry_run": {"type": "boolean"}, "exclude": {"type": "array"}}, ["from", "to", "kind"]), _h_rename_symbol)
	_dispatcher.register("script.format", _schema({"path": rp, "in_place": {"type": "boolean"}}, ["path"]), _h_format)


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
	var rows := _Scripts.walk_scripts(str(p.get("pattern", "")), bool(p.get("include_addon", false)))
	return {"ok": true, "result": {"scripts": rows, "total": rows.size()}}


func _h_read(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	var r := _Scripts.read_script(path, p.get("range"), str(p.get("format", "text")))
	if not r.get("ok", false):
		return _err_path_not_found(path)
	return {"ok": true, "result": r}


func _h_write(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	if p.has("if_match") and str(p.get("if_match", "")) != _revision(path):
		return _err_idempotency()
	var w := _Scripts.write_script(path, str(p.get("content", "")), str(p.get("mode", "overwrite")))
	if w.get("exists", false):
		return {
			"ok": false,
			"error": TerraVoltErrors.tv_rpc_error(
				TerraVoltErrors.SCRIPT_PATH_EXISTS,
				"script.path_exists",
				"File already exists; use overwrite mode.",
				{"path": path}
			),
		}
	if not w.get("ok", false):
		return _err_path_not_found(path)
	_rescan(path)
	return {"ok": true, "result": {"written": true, "path": path, "bytes_written": w.bytes_written, "lines": w.lines, "revision": _bump_revision(path)}}


func _h_patch(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	if p.has("if_match") and str(p.get("if_match", "")) != _revision(path):
		return _err_idempotency()
	var hunks: Array = p.get("hunks", []) as Array
	var r := _Scripts.apply_hunks(path, hunks)
	if r.get("missing", false):
		return _err_path_not_found(path)
	if r.get("conflict", false):
		return {
			"ok": false,
			"error": TerraVoltErrors.tv_rpc_error(
				TerraVoltErrors.SCRIPT_PATCH_CONFLICT,
				"script.patch_conflict",
				"Hunk line range does not match current file.",
				{"path": path}
			),
		}
	_rescan(path)
	return {
		"ok": true,
		"result": {
			"patched": true,
			"hunks_applied": r.hunks_applied,
			"lines_before": r.lines_before,
			"lines_after": r.lines_after,
			"revision": _bump_revision(path),
		},
	}


func _h_validate(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	var lang := _Scripts.language_for(path)
	if lang == "cs":
		if not OS.has_feature("dotnet"):
			return {
				"ok": false,
				"error": TerraVoltErrors.tv_rpc_error(
					TerraVoltErrors.SCRIPT_DOTNET_UNAVAILABLE,
					"script.dotnet_unavailable",
					".NET / C# toolchain not available in this Godot build.",
					{"path": path}
				),
			}
		return {"ok": true, "result": {"ok": true, "errors": [], "warnings": [], "duration_ms": 0}}
	if lang != "gd":
		return {"ok": true, "result": {"ok": true, "errors": [], "warnings": [], "duration_ms": 0}}
	var r := _Scripts.validate_gd(path)
	if r.get("missing", false):
		return _err_path_not_found(path)
	return {"ok": true, "result": r}


func _h_find_usages(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var usages := _Scripts.find_usages(
		str(p.get("symbol", "")),
		str(p.get("kind", "any")),
		bool(p.get("case_sensitive", true))
	)
	return {"ok": true, "result": {"usages": usages, "truncated": false}}


func _h_rename_symbol(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var from_sym := str(p.get("from", ""))
	var to_sym := str(p.get("to", ""))
	var dry_run := bool(p.get("dry_run", false))
	var usages := _Scripts.find_usages(from_sym, str(p.get("kind", "any")), true)
	var edits: Array = []
	var files: Dictionary = {}
	for u in usages:
		if str(u.get("confidence", "")) != "exact":
			continue
		var fp := str(u.get("path", ""))
		files[fp] = true
		edits.append({"path": fp, "line": u.line, "col": u.col, "before": from_sym, "after": to_sym})
	if not dry_run:
		for fp in files.keys():
			var abs := _Scripts.abs_path(fp)
			var text := FileAccess.get_file_as_string(abs)
			var re := RegEx.new()
			var pat := "\\b%s\\b" % from_sym.replace(".", "\\.")
			if re.compile(pat) == OK:
				text = re.sub(from_sym, to_sym, text)
				FileAccess.open(abs, FileAccess.WRITE).store_string(text)
			_rescan(fp)
	return {
		"ok": true,
		"result": {"edits": edits, "applied": not dry_run, "dry_run": dry_run, "files_changed": files.size()},
	}


func _h_format(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	var abs := _Scripts.abs_path(path)
	if not FileAccess.file_exists(abs):
		return _err_path_not_found(path)
	var before := FileAccess.get_file_as_string(abs)
	var lines_before := before.split("\n", false).size()
	var formatted := _Scripts.minimal_format(before)
	if bool(p.get("in_place", true)):
		FileAccess.open(abs, FileAccess.WRITE).store_string(formatted)
	_rescan(path)
	return {
		"ok": true,
		"result": {
			"formatted": formatted != before,
			"path": path,
			"lines_before": lines_before,
			"lines_after": formatted.split("\n", false).size(),
			"diff_summary": "minimal_format",
		},
	}


func _rescan(path: String) -> void:
	if OS.has_feature("editor"):
		var plug := _Utils.editor_plugin(_dispatcher)
		if plug:
			plug.get_editor_interface().get_resource_filesystem().scan()


func _err_path_not_found(path: String) -> Dictionary:
	return {
		"ok": false,
		"error": TerraVoltErrors.tv_rpc_error(
			TerraVoltErrors.SCRIPT_PATH_NOT_FOUND_CAT,
			"script.path_not_found",
			"Script file not found.",
			{"path": path}
		),
	}


func _err_idempotency() -> Dictionary:
	return {
		"ok": false,
		"error": TerraVoltErrors.tv_rpc_error(
			TerraVoltErrors.PROTOCOL_IDEMPOTENCY_CONFLICT,
			"protocol.idempotency_conflict",
			"Revision token mismatch.",
			{}
		),
	}
