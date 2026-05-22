@tool
extends RefCounted
class_name TerravoltShaderHandlers

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
	_dispatcher.register("shader.list", _schema({"kind": {"type": "string"}}), _h_list)
	_dispatcher.register("shader.read", _schema({"path": rp, "range": {"type": "object"}}, ["path"]), _h_read)
	_dispatcher.register("shader.write", _schema({"path": rp, "content": {"type": "string"}, "mode": {"type": "string"}, "if_match": {}}, ["path", "content"]), _h_write)
	_dispatcher.register("shader.compile_check", _schema({"path": rp}, ["path"]), _h_compile_check)
	_dispatcher.register("shader.list_params", _schema({"path": rp}, ["path"]), _h_list_params)
	_dispatcher.register(
		"shader.set_material_params",
		_schema({"material_path": rp, "params": {"type": "object"}, "if_match": {}}, ["material_path", "params"]),
		_h_set_material_params
	)


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
	var kind := str(p.get("kind", "any"))
	var shaders: Array = []
	for row in _Res.walk_resources("", _Res.RESOURCE_GLOB, false):
		var path := str(row.get("path", ""))
		var cls := str(row.get("class", ""))
		var lower := path.to_lower()
		var entry_kind := "material"
		if lower.ends_with(".gdshader") or lower.ends_with(".shader"):
			entry_kind = "code"
		elif cls != "ShaderMaterial":
			continue
		if kind == "code" and entry_kind != "code":
			continue
		if kind == "material" and entry_kind != "material":
			continue
		shaders.append({"path": path, "kind": entry_kind, "uses_global_uniforms": false})
	return {"ok": true, "result": {"shaders": shaders, "total": shaders.size()}}


func _h_read(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	var abs := _Res.abs_path(path)
	if not FileAccess.file_exists(abs):
		return _err_path_not_found(path)
	var content := FileAccess.get_file_as_string(abs)
	var truncated := false
	if p.has("range") and typeof(p.get("range")) == TYPE_DICTIONARY:
		var r: Dictionary = p.get("range") as Dictionary
		var lines := content.split("\n")
		var start := maxi(0, int(r.get("start_line", 1)) - 1)
		var end := mini(lines.size(), int(r.get("end_line", lines.size())))
		content = "\n".join(lines.slice(start, end))
		truncated = end - start < lines.size()
	return {"ok": true, "result": {"path": path, "language": "gdshader", "content": content, "truncated": truncated, "includes": []}}


func _h_write(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	if p.has("if_match") and str(p.get("if_match", "")) != _revision(path):
		return _err_idempotency()
	var mode := str(p.get("mode", "overwrite"))
	if mode == "create_only" and _Res.file_exists(path):
		return _err_path_exists(path)
	var content := str(p.get("content", ""))
	var abs := _Res.abs_path(path)
	var dir := abs.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	FileAccess.open(abs, FileAccess.WRITE).store_string(content)
	_scan()
	return {
		"ok": true,
		"result": {"written": true, "path": path, "bytes_written": content.to_utf8_buffer().size(), "revision": _bump_revision(path)},
	}


func _h_compile_check(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	var abs := _Res.abs_path(path)
	if not FileAccess.file_exists(abs):
		return _err_path_not_found(path)
	var code := FileAccess.get_file_as_string(abs)
	return {"ok": true, "result": _Res.shader_compile_check_code(code)}


func _h_list_params(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	var res := _Res.load_resource(path)
	if res == null:
		return _err_path_not_found(path)
	var params: Array = []
	if res is Shader:
		for u in (res as Shader).get_shader_uniform_list():
			if typeof(u) != TYPE_DICTIONARY:
				continue
			var ud := u as Dictionary
			params.append(
				{
					"name": str(ud.get("name", "")),
					"type": int(ud.get("type", TYPE_NIL)),
					"hint": int(ud.get("hint", PROPERTY_HINT_NONE)),
					"hint_string": str(ud.get("hint_string", "")),
				}
			)
	elif res is ShaderMaterial:
		var mat := res as ShaderMaterial
		if mat.shader:
			for u in mat.shader.get_shader_uniform_list():
				if typeof(u) != TYPE_DICTIONARY:
					continue
				var ud := u as Dictionary
				var nm := str(ud.get("name", ""))
				params.append({"name": nm, "type": int(ud.get("type", TYPE_NIL)), "default": mat.get_shader_parameter(nm)})
	return {"ok": true, "result": {"params": params}}


func _h_set_material_params(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("material_path", "")))
	if p.has("if_match") and str(p.get("if_match", "")) != _revision(path):
		return _err_idempotency()
	var res := _Res.load_resource(path)
	if res == null or not res is ShaderMaterial:
		return _err_path_not_found(path)
	var mat := res as ShaderMaterial
	var patch: Dictionary = p.get("params", {}) as Dictionary
	var applied: Dictionary = {}
	for k in patch.keys():
		var key := str(k)
		var before := mat.get_shader_parameter(key)
		mat.set_shader_parameter(key, _Res.json_to_variant(patch[k]))
		applied[key] = {"before": _Res.variant_to_json(before), "after": _Res.variant_to_json(mat.get_shader_parameter(key))}
	ResourceSaver.save(mat, path)
	_scan()
	return {"ok": true, "result": {"updated": true, "applied": applied, "revision": _bump_revision(path)}}


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
			"Shader or material path not found.",
			{"path": path}
		),
	}


func _err_path_exists(path: String) -> Dictionary:
	return {
		"ok": false,
		"error": TerravoltErrors.tv_rpc_error(
			TerravoltErrors.RESOURCE_PATH_EXISTS,
			"resource.path_exists",
			"Shader file already exists.",
			{"path": path}
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
