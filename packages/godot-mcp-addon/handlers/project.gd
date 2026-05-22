@tool
extends RefCounted
class_name TerraVoltProjectHandlers

const _Utils := preload("./handler_utils.gd")

var _dispatcher: TerraVoltDispatcher
var _logger: TerraVoltLogger

const _LOCKED_PREFIXES: PackedStringArray = PackedStringArray(["application/config/features"])


func attach(dispatcher: TerraVoltDispatcher, logger: TerraVoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	_dispatcher.register(
		"project.info",
		{"type": "object", "properties": {}, "additionalProperties": false},
		_h_info
	)
	_dispatcher.register(
		"project.get_settings",
		{
			"type": "object",
			"properties": {
				"keys": {"type": "array", "items": {"type": "string"}},
				"group": {"type": "string"},
				"include_defaults": {"type": "boolean"},
			},
			"additionalProperties": false,
		},
		_h_get_settings
	)
	_dispatcher.register(
		"project.set_settings",
		{
			"type": "object",
			"required": ["patch"],
			"properties": {
				"patch": {"type": "object"},
				"save": {"type": "boolean"},
				"dry_run": {"type": "boolean"},
				"confirm_high_risk": {"type": "boolean"},
			},
			"additionalProperties": false,
		},
		_h_set_settings
	)
	_dispatcher.register(
		"project.list_autoloads",
		{"type": "object", "properties": {}, "additionalProperties": false},
		_h_list_autoloads
	)
	_dispatcher.register(
		"project.add_autoload",
		{
			"type": "object",
			"required": ["name", "path"],
			"properties": {
				"name": {"type": "string", "minLength": 1},
				"path": {"type": "string", "minLength": 1},
				"singleton": {"type": "boolean"},
			},
			"additionalProperties": false,
		},
		_h_add_autoload
	)
	_dispatcher.register(
		"project.remove_autoload",
		{
			"type": "object",
			"required": ["name"],
			"properties": {"name": {"type": "string", "minLength": 1}},
			"additionalProperties": false,
		},
		_h_remove_autoload
	)
	_dispatcher.register(
		"project.set_main_scene",
		{
			"type": "object",
			"required": ["path"],
			"properties": {
				"path": {"type": "string", "minLength": 1},
				"validate": {"type": "boolean"},
			},
			"additionalProperties": false,
		},
		_h_set_main_scene
	)


func _h_info(_ctx: Dictionary) -> Dictionary:
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	var dotnet := ProjectSettings.has_setting("dotnet/project/assembly_name")
	var info := {
		"name": str(ProjectSettings.get_setting("application/config/name", "")),
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"godot_version_required": str(ProjectSettings.get_setting("config/features", PackedStringArray())),
		"main_scene": main_scene,
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"dotnet": dotnet,
		"autoload_count": _list_autoload_rows().size(),
		"addon_count": 0,
		"feature_tags": PackedStringArray(OS.get_feature_list()),
		"path_user_dir": ProjectSettings.globalize_path("user://"),
		"path_res_dir": ProjectSettings.globalize_path("res://"),
	}
	return {"ok": true, "result": info}


func _h_get_settings(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var include_defaults := bool(p.get("include_defaults", false))
	var settings: Dictionary = {}
	if p.has("keys"):
		for k in p["keys"] as Array:
			var key := str(k)
			settings[key] = _setting_row(key, include_defaults)
	elif p.has("group"):
		var group := str(p["group"])
		for pi in ProjectSettings.get_property_list():
			if typeof(pi) != TYPE_DICTIONARY:
				continue
			var name := str((pi as Dictionary).get("name", ""))
			if name.begins_with(group):
				settings[name] = _setting_row(name, include_defaults)
	else:
		for pi in ProjectSettings.get_property_list():
			if typeof(pi) != TYPE_DICTIONARY:
				continue
			var name := str((pi as Dictionary).get("name", ""))
			if name.begins_with("application/") or name.begins_with("rendering/"):
				settings[name] = _setting_row(name, include_defaults)
	return {"ok": true, "result": {"settings": settings}}


func _setting_row(key: String, include_defaults: bool) -> Dictionary:
	var has := ProjectSettings.has_setting(key)
	var val: Variant = ProjectSettings.get_setting(key) if has else null
	var row := {
		"value": val,
		"type": typeof(val),
		"hint": 0,
		"hint_string": "",
		"default": null,
		"is_overridden": has,
	}
	if include_defaults and ProjectSettings.has_setting(key):
		row["default"] = ProjectSettings.get_setting(key)
	return row


func _h_set_settings(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var patch: Dictionary = p.get("patch", {}) as Dictionary
	var dry_run := bool(p.get("dry_run", false))
	var save := bool(p.get("save", true))
	var confirm_high_risk := bool(p.get("confirm_high_risk", false))
	var applied: Dictionary = {}
	for key in patch.keys():
		var k := str(key)
		if _is_locked(k) and not confirm_high_risk:
			return {
				"ok": false,
				"error": TerraVoltErrors.tv_rpc_error(
					TerraVoltErrors.PROJECT_SETTING_LOCKED,
					"project.setting_locked",
					"High-risk or locked key; pass confirm_high_risk=true.",
					{"key": k}
				),
			}
		var before: Variant = ProjectSettings.get_setting(k) if ProjectSettings.has_setting(k) else null
		applied[k] = {"before": before, "after": patch[key]}
		if not dry_run:
			ProjectSettings.set_setting(k, patch[key])
	if not dry_run and save:
		ProjectSettings.save()
		if _dispatcher.server_ref:
			var svc = _dispatcher.server_ref.get_ref()
			if svc != null and svc.has_method("notify_server_event"):
				svc.call("notify_server_event", "event.project.setting_changed", {"keys": patch.keys()})
	return {"ok": true, "result": {"applied": applied, "dry_run": dry_run, "state": _h_info({}).get("result", {})}}


func _is_locked(key: String) -> bool:
	for pref in _LOCKED_PREFIXES:
		if key.begins_with(pref):
			return true
	if key == "application/config/name":
		return true
	return false


func _list_autoload_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for pi in ProjectSettings.get_property_list():
		if typeof(pi) != TYPE_DICTIONARY:
			continue
		var name := str((pi as Dictionary).get("name", ""))
		if not name.begins_with("autoload/"):
			continue
		var val := str(ProjectSettings.get_setting(name, ""))
		var singleton := val.begins_with("*")
		var path := val.lstrip("*")
		rows.append(
			{
				"name": name.substr("autoload/".length()),
				"path": path,
				"singleton": singleton,
				"source": "project",
			}
		)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("name", "")) < str(b.get("name", "")))
	return rows


func _h_list_autoloads(_ctx: Dictionary) -> Dictionary:
	return {"ok": true, "result": {"autoloads": _list_autoload_rows()}}


func _h_add_autoload(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var name := str(p.get("name", ""))
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	var singleton := bool(p.get("singleton", true))
	if OS.has_feature("editor"):
		var plug := _Utils.editor_plugin(_dispatcher)
		if plug:
			plug.add_autoload_singleton(name, path)
			return {"ok": true, "result": {"added": true, "autoload": {"name": name, "path": path, "singleton": singleton}, "state": {"autoloads": _list_autoload_rows()}}}
	var prefix := "*" if singleton else ""
	ProjectSettings.set_setting("autoload/%s" % name, "%s%s" % [prefix, path])
	ProjectSettings.save()
	return {"ok": true, "result": {"added": true, "autoload": {"name": name, "path": path, "singleton": singleton}, "state": {"autoloads": _list_autoload_rows()}}}


func _h_remove_autoload(ctx: Dictionary) -> Dictionary:
	var name := str(_Utils.params_dict(ctx).get("name", ""))
	if OS.has_feature("editor"):
		var plug := _Utils.editor_plugin(_dispatcher)
		if plug:
			plug.remove_autoload_singleton(name)
			return {"ok": true, "result": {"removed": true, "name": name, "state": {"autoloads": _list_autoload_rows()}}}
	if ProjectSettings.has_setting("autoload/%s" % name):
		ProjectSettings.clear("autoload/%s" % name)
		ProjectSettings.save()
	return {"ok": true, "result": {"removed": true, "name": name, "state": {"autoloads": _list_autoload_rows()}}}


func _h_set_main_scene(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("path", "")))
	var validate := bool(p.get("validate", true))
	if validate and not _Utils.scene_file_exists(path):
		return _Utils.err_scene_not_found(path)
	var previous: Variant = ProjectSettings.get_setting("application/run/main_scene", null)
	ProjectSettings.set_setting("application/run/main_scene", path)
	ProjectSettings.save()
	return {
		"ok": true,
		"result": {"set": true, "path": path, "previous": previous, "state": _h_info({}).get("result", {})},
	}
