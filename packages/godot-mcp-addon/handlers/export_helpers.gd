@tool
extends RefCounted
class_name TerraVoltExportHelpers

## export.* helpers (task 23).

const _Err := preload("../error_codes.gd")
const _Testing := preload("./testing_helpers.gd")

const DEFAULT_EXPORT_TIMEOUT_MS := 600000
const PRESETS_FILE := "res://export_presets.cfg"


static func list_presets() -> Dictionary:
	var presets: Array = []
	var cfg_path := ProjectSettings.globalize_path(PRESETS_FILE)
	if not FileAccess.file_exists(cfg_path):
		return {"ok": true, "result": {"presets": presets}}
	var cfg := ConfigFile.new()
	if cfg.load(cfg_path) != OK:
		return {"ok": true, "result": {"presets": presets}}
	var sections := cfg.get_sections()
	for section in sections:
		if not str(section).begins_with("preset."):
			continue
		var name := str(cfg.get_value(section, "name", ""))
		if name.is_empty():
			continue
		presets.append(
			{
				"name": name,
				"platform": str(cfg.get_value(section, "platform", "")),
				"runnable": bool(cfg.get_value(section, "runnable", false)),
				"export_path": str(cfg.get_value(section, "export_path", "")),
				"encryption_directory_filters": str(cfg.get_value(section, "encryption_directory_filters", "")),
				"custom_features": _split_csv(str(cfg.get_value(section, "custom_features", ""))),
				"options_summary": {"section": section},
			}
		)
	return {"ok": true, "result": {"presets": presets}}


static func template_info() -> Dictionary:
	var templates_dir := _export_templates_dir()
	var installed: Array = []
	var current := "%s.%s.%s" % [
		Engine.get_version_info().get("major", 0),
		Engine.get_version_info().get("minor", 0),
		Engine.get_version_info().get("patch", 0),
	]
	var mismatched := false
	if DirAccess.dir_exists_absolute(templates_dir):
		var da := DirAccess.open(templates_dir)
		if da:
			da.list_dir_begin()
			while true:
				var name := da.get_next()
				if name.is_empty():
					break
				if name.begins_with("."):
					continue
				if da.current_is_dir():
					installed.append(
						{
							"version": name,
							"platforms": ["*"],
							"path": templates_dir.path_join(name),
						}
					)
					if not name.begins_with(str(Engine.get_version_info().get("major", 0))):
						mismatched = true
			da.list_dir_end()
	if installed.is_empty():
		mismatched = true
	return {
		"ok": true,
		"result": {
			"templates_dir": templates_dir,
			"installed": installed,
			"current_godot_version": current,
			"mismatched": mismatched,
		},
	}


static func build(params: Dictionary) -> Dictionary:
	var preset := str(params.get("preset", "")).strip_edges()
	if preset.is_empty():
		return {"ok": false, "code": _Err.EXPORT_PRESET_UNKNOWN, "message": "export.preset_unknown"}
	var listed := list_presets()
	var found := false
	for row in listed.get("result", {}).get("presets", []) as Array:
		if typeof(row) == TYPE_DICTIONARY and str((row as Dictionary).get("name", "")) == preset:
			found = true
			break
	if not found:
		return {"ok": false, "code": _Err.EXPORT_PRESET_UNKNOWN, "message": "export.preset_unknown"}
	var templates := template_info()
	if (templates.get("result", {}) as Dictionary).get("installed", []).is_empty():
		return {"ok": false, "code": _Err.EXPORT_TEMPLATE_MISSING, "message": "export.template_missing"}
	var debug := bool(params.get("debug", true))
	var pck_only := bool(params.get("with_pck_only", false))
	var out_path := str(params.get("output_path", "")).strip_edges()
	if out_path.is_empty():
		out_path = "res://.godot/exported/%s.pck" % preset.replace("/", "_").replace(" ", "_")
	out_path = _resolve_path(out_path)
	_ensure_parent_dir(_globalize(out_path))
	var flag := "--export-pack" if pck_only else ("--export-debug" if debug else "--export-release")
	var args: PackedStringArray = [
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		flag,
		preset,
		_globalize(out_path),
	]
	var timeout_ms := int(params.get("timeout_ms", DEFAULT_EXPORT_TIMEOUT_MS))
	var t0 := Time.get_ticks_msec()
	var proc: Dictionary = _Testing.execute_with_timeout(_resolve_godot_exe(), args, timeout_ms)
	if proc.get("timed_out", false):
		return {"ok": false, "code": _Err.EXPORT_TIMEOUT, "message": "export.timeout"}
	var exit_code := int(proc.get("exit_code", 1))
	var log_tail := str(proc.get("stdout", "")) + str(proc.get("stderr", ""))
	if log_tail.length() > 4000:
		log_tail = log_tail.substr(log_tail.length() - 4000)
	var artifacts: Array = []
	var abs_out := _globalize(out_path)
	if FileAccess.file_exists(abs_out):
		artifacts.append(
			{
				"path": out_path,
				"size_bytes": FileAccess.get_file_as_bytes(abs_out).size(),
				"kind": "pck" if out_path.ends_with(".pck") else "binary",
			}
		)
	return {
		"ok": true,
		"result": {
			"ok": exit_code == 0 and not artifacts.is_empty(),
			"exit_code": exit_code,
			"duration_ms": Time.get_ticks_msec() - t0,
			"artifacts": artifacts,
			"log_tail": log_tail,
		},
	}


static func _export_templates_dir() -> String:
	if ClassDB.class_exists("EditorExportPlatform"):
		var plat: Object = ClassDB.instantiate("EditorExportPlatform")
		if plat != null and plat.has_method("get_export_templates_dir"):
			return str(plat.call("get_export_templates_dir"))
	var home := OS.get_environment("HOME")
	if home.is_empty():
		home = OS.get_environment("USERPROFILE")
	var ver := Engine.get_version_info()
	var folder := "%s.%s.%s" % [ver.get("major", 4), ver.get("minor", 0), ver.get("patch", 0)]
	if OS.get_name() == "Windows":
		return home.path_join("AppData/Roaming/Godot/export_templates").path_join(folder)
	return home.path_join(".local/share/godot/export_templates").path_join(folder)


static func _split_csv(raw: String) -> Array:
	if raw.is_empty():
		return []
	return raw.split(",", false)


static func _resolve_godot_exe() -> String:
	var exe := OS.get_environment("TERRAVOLT_GODOT_BINARY").strip_edges()
	if exe.is_empty():
		exe = OS.get_executable_path()
	return exe


static func _ensure_parent_dir(abs_path: String) -> void:
	var dir := abs_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)


static func _resolve_path(raw: String) -> String:
	var s := raw.strip_edges()
	if s.is_empty():
		return ""
	if s.begins_with("res://") or s.begins_with("user://"):
		return s
	if s.begins_with("/") or (s.length() >= 3 and s[1] == ":"):
		return ProjectSettings.localize_path(s)
	return "res://%s" % s.lstrip("/")


static func _globalize(path: String) -> String:
	return ProjectSettings.globalize_path(_resolve_path(path))
