@tool
extends RefCounted
class_name TerraVoltAndroidHelpers

## android.* helpers — Android deploy/inspection via adb + Godot export CLI (task 26).

const _Err := preload("../error_codes.gd")

const PRESETS_FILE := "res://export_presets.cfg"
const DEFAULT_EXPORT_TIMEOUT_MS := 600000


static func _resolve_adb() -> String:
	var configured := OS.get_environment("TERRAVOLT_ANDROID_ADB").strip_edges()
	if not configured.is_empty() and FileAccess.file_exists(configured):
		return configured
	if Engine.has_singleton("EditorInterface"):
		var ei: Object = Engine.get_singleton("EditorInterface")
		if ei != null and ei.has_method("get_editor_settings"):
			var es: Object = ei.call("get_editor_settings")
			if es != null and es.has_method("has_setting") and es.call("has_setting", "export/android/adb"):
				var v := str(es.call("get_setting", "export/android/adb"))
				if not v.is_empty() and FileAccess.file_exists(v):
					return v
	return "adb"


static func _run(cmd: String, args: PackedStringArray) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute(cmd, args, output, true)
	var stdout := ""
	if not output.is_empty():
		stdout = str(output[0])
	return {"exit_code": exit_code, "stdout": stdout}


static func list_devices(_params: Dictionary) -> Dictionary:
	var adb := _resolve_adb()
	var result := _run(adb, PackedStringArray(["devices", "-l"]))
	if int(result["exit_code"]) != 0:
		return {
			"ok": false,
			"code": _Err.ANDROID_ADB_NOT_FOUND,
			"message": "android.adb_not_found",
			"context": {"adb_path": adb, "output": result["stdout"]},
		}
	var devices: Array = []
	var lines: PackedStringArray = str(result["stdout"]).split("\n")
	for raw_line in lines:
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("List of devices") or line.begins_with("* daemon"):
			continue
		var parts: PackedStringArray = line.split(" ", false)
		if parts.size() < 2:
			continue
		var dev: Dictionary = {"serial": parts[0], "state": parts[1]}
		for i in range(2, parts.size()):
			var kv: String = parts[i]
			var eq: int = kv.find(":")
			if eq > 0:
				dev[kv.substr(0, eq)] = kv.substr(eq + 1)
		devices.append(dev)
	return {
		"ok": true,
		"result": {"devices": devices, "count": devices.size(), "adb_path": adb},
	}


static func _find_android_preset(preset_name: String, preset_index: int) -> Dictionary:
	var cfg_path := ProjectSettings.globalize_path(PRESETS_FILE)
	if not FileAccess.file_exists(cfg_path):
		return {}
	var cfg := ConfigFile.new()
	if cfg.load(cfg_path) != OK:
		return {}
	var idx := 0
	while cfg.has_section("preset.%d" % idx):
		var section := "preset.%d" % idx
		var platform := str(cfg.get_value(section, "platform", ""))
		var name := str(cfg.get_value(section, "name", ""))
		var matches := false
		if not preset_name.is_empty():
			matches = (name == preset_name)
		elif preset_index >= 0:
			matches = (idx == preset_index)
		else:
			matches = (platform == "Android")
		if matches:
			var options_section := "preset.%d.options" % idx
			var package_name := ""
			if cfg.has_section(options_section):
				package_name = str(cfg.get_value(options_section, "package/unique_name", ""))
			return {
				"index": idx,
				"name": name,
				"platform": platform,
				"runnable": bool(cfg.get_value(section, "runnable", false)),
				"export_path": str(cfg.get_value(section, "export_path", "")),
				"package_name": package_name,
			}
		idx += 1
	return {}


static func preset_info(params: Dictionary) -> Dictionary:
	var preset_name := str(params.get("preset_name", ""))
	var preset_index := int(params.get("preset_index", -1))
	var preset := _find_android_preset(preset_name, preset_index)
	if preset.is_empty():
		return {
			"ok": false,
			"code": _Err.ANDROID_PRESET_NOT_FOUND,
			"message": "android.preset_not_found",
			"context": {"hint": "Configure an Android preset in Project > Export first."},
		}
	if str(preset.get("platform", "")) != "Android":
		return {
			"ok": false,
			"code": _Err.ANDROID_PRESET_NOT_FOUND,
			"message": "android.preset_not_found",
			"context": {"preset": preset, "reason": "platform is not Android"},
		}
	return {"ok": true, "result": preset}


static func _resolve_godot_exe() -> String:
	var exe := OS.get_environment("TERRAVOLT_GODOT_BINARY").strip_edges()
	if exe.is_empty():
		exe = OS.get_executable_path()
	return exe


static func deploy(params: Dictionary) -> Dictionary:
	var preset_name := str(params.get("preset_name", ""))
	var preset_index := int(params.get("preset_index", -1))
	var device_serial := str(params.get("device_serial", ""))
	var debug := bool(params.get("debug", true))
	var launch := bool(params.get("launch", true))
	var skip_export := bool(params.get("skip_export", false))

	var preset_g := preset_info({"preset_name": preset_name, "preset_index": preset_index})
	if not preset_g.get("ok", false):
		return preset_g
	var preset: Dictionary = preset_g.get("result", {})

	var export_path_res := str(preset.get("export_path", "")).strip_edges()
	if export_path_res.is_empty():
		return {
			"ok": false,
			"code": _Err.ANDROID_EXPORT_FAILED,
			"message": "android.export_failed",
			"context": {"reason": "export_path not configured for preset"},
		}
	var export_path_abs := export_path_res
	if export_path_res.begins_with("res://"):
		export_path_abs = ProjectSettings.globalize_path(export_path_res)

	var steps: Array = []
	if not skip_export:
		var godot_bin := _resolve_godot_exe()
		var project_dir := ProjectSettings.globalize_path("res://")
		var flag := "--export-debug" if debug else "--export-release"
		var export_args := PackedStringArray(
			["--headless", "--path", project_dir, flag, str(preset.get("name", "")), export_path_abs]
		)
		var export_result := _run(godot_bin, export_args)
		steps.append(
			{
				"step": "export",
				"command": godot_bin,
				"args": export_args,
				"exit_code": export_result["exit_code"],
			}
		)
		if int(export_result["exit_code"]) != 0:
			return {
				"ok": false,
				"code": _Err.ANDROID_EXPORT_FAILED,
				"message": "android.export_failed",
				"context": {"steps": steps, "stdout": export_result["stdout"]},
			}

	if not FileAccess.file_exists(export_path_abs):
		return {
			"ok": false,
			"code": _Err.ANDROID_EXPORT_FAILED,
			"message": "android.export_failed",
			"context": {"reason": "APK not found after export", "path": export_path_abs, "steps": steps},
		}

	var adb := _resolve_adb()
	var install_args := PackedStringArray()
	if not device_serial.is_empty():
		install_args.append("-s")
		install_args.append(device_serial)
	install_args.append("install")
	install_args.append("-r")
	install_args.append(export_path_abs)
	var install_result := _run(adb, install_args)
	steps.append(
		{
			"step": "install",
			"command": adb,
			"args": install_args,
			"exit_code": install_result["exit_code"],
			"stdout": install_result["stdout"],
		}
	)
	if int(install_result["exit_code"]) != 0:
		return {
			"ok": false,
			"code": _Err.ANDROID_INSTALL_FAILED,
			"message": "android.install_failed",
			"context": {"steps": steps},
		}

	if launch:
		var package_name := str(preset.get("package_name", ""))
		if package_name.is_empty():
			steps.append({"step": "launch", "skipped": true, "reason": "package_name not found in preset"})
		else:
			var launch_args := PackedStringArray()
			if not device_serial.is_empty():
				launch_args.append("-s")
				launch_args.append(device_serial)
			launch_args.append("shell")
			launch_args.append("monkey")
			launch_args.append("-p")
			launch_args.append(package_name)
			launch_args.append("-c")
			launch_args.append("android.intent.category.LAUNCHER")
			launch_args.append("1")
			var launch_result := _run(adb, launch_args)
			steps.append(
				{
					"step": "launch",
					"command": adb,
					"args": launch_args,
					"exit_code": launch_result["exit_code"],
					"stdout": launch_result["stdout"],
				}
			)

	return {
		"ok": true,
		"result": {
			"preset": preset.get("name", ""),
			"apk_path": export_path_abs,
			"device": device_serial if not device_serial.is_empty() else "(default)",
			"package_name": preset.get("package_name", ""),
			"steps": steps,
		},
	}
