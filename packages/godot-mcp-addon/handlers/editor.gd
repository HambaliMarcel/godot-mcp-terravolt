@tool
extends RefCounted
class_name TerravoltEditorHandlers

const _Utils := preload("./handler_utils.gd")
const _Res := preload("./resource_helpers.gd")
const _ErrorBuffer := preload("../services/editor_error_buffer.gd")

const SCREENSHOT_MAX_KB := 2048
const SCRIPT_DEFAULT_TIMEOUT_MS := 5000

const _DENY_FS := ["FileAccess", "DirAccess", "File.", "OS.open", "OS.create", "OS.move", "OS.remove", "OS.rename", "OS.file"]
const _DENY_NET := ["HTTPClient", "HTTPRequest", "Socket", "StreamPeer", "TCPServer", "UDPServer"]
const _DENY_ALWAYS := ["Engine.execute", "create_process", "shell_open", "JavaScriptBridge"]

var _dispatcher: TerravoltDispatcher
var _logger: TerravoltLogger
var _layout_dir := "user://terravolt_layouts/"


func attach(dispatcher: TerravoltDispatcher, logger: TerravoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var rp := {"type": "string", "minLength": 1}
	_dispatcher.register("editor.screenshot", _schema({"target": {"type": "string"}, "size": {"type": "object"}, "quality": {"type": "integer"}}), _h_screenshot)
	_dispatcher.register("editor.focus_node", _schema({"path": {"type": "string"}, "frame_in_viewport": {"type": "boolean"}}, ["path"]), _h_focus_node)
	_dispatcher.register("editor.open_script", _schema({"path": rp, "line": {"type": "integer"}, "column": {"type": "integer"}}, ["path"]), _h_open_script)
	_dispatcher.register("editor.run_undo", _schema({"steps": {"type": "integer"}}), _h_run_undo)
	_dispatcher.register("editor.run_redo", _schema({"steps": {"type": "integer"}}), _h_run_redo)
	_dispatcher.register(
		"editor.execute_script",
		_schema(
			{
				"source": {"type": "string"},
				"args": {"type": "object"},
				"timeout_ms": {"type": "integer"},
				"allow_filesystem": {"type": "boolean"},
				"allow_net": {"type": "boolean"},
			},
			["source"]
		),
		_h_execute_script
	)
	_dispatcher.register("editor.error_log_tail", _schema({"lines": {"type": "integer"}, "level": {"type": "string"}, "since_ts": {"type": "string"}}), _h_error_log_tail)
	_dispatcher.register("editor.reload_scripts", _schema({"scope": {"type": "string"}}), _h_reload_scripts)
	_dispatcher.register("editor.layout", _schema({"action": {"type": "string"}, "name": {"type": "string"}}, ["action"]), _h_layout)


func _schema(props: Dictionary, required: Array = []) -> Dictionary:
	var s := {"type": "object", "properties": props, "additionalProperties": false}
	if not required.is_empty():
		s["required"] = required
	return s


func _editor() -> Dictionary:
	return _Utils.require_editor(_dispatcher)


func _iface() -> EditorInterface:
	var ed := _editor()
	if not ed.get("ok", false):
		return null
	return (ed.plugin as EditorPlugin).get_editor_interface()


func _h_screenshot(_ctx: Dictionary) -> Dictionary:
	var ed := _editor()
	if not ed.get("ok", false):
		return ed
	var p := _Utils.params_dict(_ctx)
	var iface := _iface()
	var img := Image.new()
	var target := str(p.get("target", "main"))
	if target == "main":
		var base := iface.get_base_control()
		if base == null:
			return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.EDITOR_NOT_AVAILABLE, "editor.not_available", "Editor base control unavailable.", {})}
		var tex := base.get_viewport().get_texture()
		if tex == null:
			return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.EDITOR_NOT_AVAILABLE, "editor.not_available", "Could not grab editor viewport.", {})}
		img = tex.get_image()
	else:
		var vp_count: int = iface.get_editor_viewport_count()
		var idx := 0 if target == "viewport_2d" else 1
		if idx >= vp_count:
			idx = 0
		var vp: SubViewport = null
		if target == "viewport_3d":
			vp = iface.get_editor_viewport_3d(idx)
		else:
			vp = iface.get_editor_viewport_2d()
		if vp == null:
			return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.EDITOR_NOT_AVAILABLE, "editor.not_available", "Viewport target unavailable.", {})}
		img = vp.get_texture().get_image()
	var sz: Variant = p.get("size")
	if typeof(sz) == TYPE_DICTIONARY:
		var w := int((sz as Dictionary).get("w", img.get_width()))
		var h := int((sz as Dictionary).get("h", img.get_height()))
		if w > 0 and h > 0:
			img.resize(w, h)
	var png := img.save_png_to_buffer()
	if png.size() > SCREENSHOT_MAX_KB * 1024:
		return {
			"ok": false,
			"error": TerravoltErrors.tv_rpc_error(
				TerravoltErrors.EDITOR_SCREENSHOT_TOO_LARGE,
				"editor.screenshot_too_large",
				"Screenshot exceeds %d KB cap." % SCREENSHOT_MAX_KB,
				{"bytes": png.size(), "max_kb": SCREENSHOT_MAX_KB}
			),
		}
	return {
		"ok": true,
		"result": {
			"image_base64": Marshalls.raw_to_base64(png),
			"mime": "image/png",
			"width": img.get_width(),
			"height": img.get_height(),
			"bytes": png.size(),
		},
	}


func _h_focus_node(_ctx: Dictionary) -> Dictionary:
	var ed := _editor()
	if not ed.get("ok", false):
		return ed
	var p := _Utils.params_dict(_ctx)
	var iface := _iface()
	var node_path := str(p.get("path", ""))
	var root := iface.get_edited_scene_root()
	if root == null:
		return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.EDITOR_NO_ACTIVE_SCENE, "editor.no_active_scene", "No edited scene.", {})}
	var node := root.get_node_or_null(NodePath(node_path))
	if node == null:
		return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.SCENE_NODE_PATH_NOT_FOUND, "scene.node_path_not_found", "Node not found.", {"path": node_path})}
	iface.get_selection().clear()
	iface.get_selection().add_node(node)
	iface.edit_node(node)
	return {"ok": true, "result": {"focused": true, "path": node_path}}


func _h_open_script(_ctx: Dictionary) -> Dictionary:
	var ed := _editor()
	if not ed.get("ok", false):
		return ed
	var p := _Utils.params_dict(_ctx)
	var path := _Res.resolve_path(str(p.get("path", "")))
	if not ResourceLoader.exists(path):
		return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.SCRIPT_PATH_NOT_FOUND, "script.path_not_found", "Script missing.", {"path": path})}
	var res := load(path)
	if res == null:
		return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.SCRIPT_PATH_NOT_FOUND, "script.path_not_found", "Could not load script.", {"path": path})}
	_iface().edit_resource(res)
	var line := int(p.get("line", 1))
	if line > 0:
		var se := _iface().get_script_editor()
		if se:
			se.goto_line(maxi(0, line - 1))
	return {"ok": true, "result": {"opened": true, "path": path, "line": line}}


func _h_run_undo(_ctx: Dictionary) -> Dictionary:
	var ed := _editor()
	if not ed.get("ok", false):
		return ed
	var steps := maxi(1, int(_Utils.params_dict(_ctx).get("steps", 1)))
	var ur := (ed.plugin as EditorPlugin).get_undo_redo()
	var done := 0
	for _i in steps:
		if not ur.has_undo():
			break
		ur.undo()
		done += 1
	return {"ok": true, "result": {"undone": done}}


func _h_run_redo(_ctx: Dictionary) -> Dictionary:
	var ed := _editor()
	if not ed.get("ok", false):
		return ed
	var steps := maxi(1, int(_Utils.params_dict(_ctx).get("steps", 1)))
	var ur := (ed.plugin as EditorPlugin).get_undo_redo()
	var done := 0
	for _i in steps:
		if not ur.has_redo():
			break
		ur.redo()
		done += 1
	return {"ok": true, "result": {"redone": done}}


func _h_execute_script(_ctx: Dictionary) -> Dictionary:
	var ed := _editor()
	if not ed.get("ok", false):
		return ed
	var p := _Utils.params_dict(_ctx)
	var source := str(p.get("source", ""))
	var allow_fs := bool(p.get("allow_filesystem", false))
	var allow_net := bool(p.get("allow_net", false))
	var denied := _denied_identifiers(source, allow_fs, allow_net)
	if not denied.is_empty():
		return {
			"ok": false,
			"error": TerravoltErrors.tv_rpc_error(
				TerravoltErrors.EDITOR_SCRIPT_FORBIDDEN_API,
				"editor.script_forbidden_api",
				"Source uses denied identifiers.",
				{"denied": denied, "source": source}
			),
		}
	var timeout_ms := int(p.get("timeout_ms", SCRIPT_DEFAULT_TIMEOUT_MS))
	var started := Time.get_ticks_msec()
	var gd := GDScript.new()
	gd.source_code = source
	var erc := gd.reload()
	if erc != OK:
		return {"ok": true, "result": {"ok": false, "return_value": null, "prints": [], "errors": [{"line": 1, "col": 1, "message": error_string(erc)}]}}
	if Time.get_ticks_msec() - started > timeout_ms:
		return {
			"ok": false,
			"error": TerravoltErrors.tv_rpc_error(
				TerravoltErrors.EDITOR_SCRIPT_TIMEOUT,
				"editor.script_timeout",
				"Script reload exceeded timeout.",
				{"timeout_ms": timeout_ms}
			),
		}
	var inst := gd.new()
	var prints: Array = []
	var ret: Variant = null
	var ok := true
	if inst != null and inst.has_method("main"):
		ret = inst.call("main", p.get("args", {}))
	if Time.get_ticks_msec() - started > timeout_ms:
		return {
			"ok": false,
			"error": TerravoltErrors.tv_rpc_error(
				TerravoltErrors.EDITOR_SCRIPT_TIMEOUT,
				"editor.script_timeout",
				"Script execution exceeded timeout.",
				{"timeout_ms": timeout_ms}
			),
		}
	return {"ok": true, "result": {"ok": ok, "return_value": ret, "prints": prints, "errors": [], "source": source}}


func _denied_identifiers(source: String, allow_fs: bool, allow_net: bool) -> Array:
	var denied: Array = []
	for id in _DENY_ALWAYS:
		if source.contains(id):
			denied.append(id)
	if not allow_fs:
		for id in _DENY_FS:
			if source.contains(id):
				denied.append(id)
	if not allow_net:
		for id in _DENY_NET:
			if source.contains(id):
				denied.append(id)
	return denied


func _h_error_log_tail(_ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(_ctx)
	var lines := maxi(1, int(p.get("lines", 100)))
	var level := str(p.get("level", "warn"))
	var entries: Array = []
	for row in _ErrorBuffer.tail(lines, level):
		entries.append(row)
	if _logger:
		for row in _logger.tail_records(lines, "" if level == "all" else level):
			if typeof(row) != TYPE_DICTIONARY:
				continue
			var d := row as Dictionary
			entries.append(
				{
					"ts": str(d.get("ts", "")),
					"level": str(d.get("level", "info")),
					"source": "engine",
					"file": d.get("file", null),
					"line": d.get("line", null),
					"message": str(d.get("event", d.get("message", ""))),
				}
			)
	while entries.size() > lines:
		entries.pop_front()
	return {"ok": true, "result": {"entries": entries}}


func _h_reload_scripts(_ctx: Dictionary) -> Dictionary:
	var ed := _editor()
	if not ed.get("ok", false):
		return ed
	var scope := str(_Utils.params_dict(_ctx).get("scope", "changed"))
	var iface := _iface()
	var reloaded: Array = []
	if scope == "all":
		iface.get_resource_filesystem().scan()
	iface.get_script_editor().reload_open_files()
	var root := iface.get_edited_scene_root()
	if root != null:
		var sp := root.scene_file_path
		if not sp.is_empty():
			iface.reload_scene_from_path(sp)
			reloaded.append(sp)
	return {"ok": true, "result": {"reloaded": reloaded, "total": reloaded.size()}}


func _h_layout(_ctx: Dictionary) -> Dictionary:
	var ed := _editor()
	if not ed.get("ok", false):
		return ed
	var p := _Utils.params_dict(_ctx)
	var action := str(p.get("action", "list"))
	var name := str(p.get("name", "default")).strip_edges()
	if not DirAccess.dir_exists_absolute(_layout_dir):
		DirAccess.make_dir_recursive_absolute(_layout_dir)
	match action:
		"list":
			var layouts: Array = []
			var da := DirAccess.open(_layout_dir)
			if da:
				da.list_dir_begin()
				while true:
					var n := da.get_next()
					if n.is_empty():
						break
					if n.ends_with(".cfg"):
						layouts.append(n.trim_suffix(".cfg"))
				da.list_dir_end()
			return {"ok": true, "result": {"layouts": layouts}}
		"save":
			var path := _layout_dir.path_join("%s.cfg" % name)
			var cfg := ConfigFile.new()
			cfg.set_value("meta", "saved_at", Time.get_datetime_string_from_system(true))
			if cfg.save(path) != OK:
				return {
					"ok": false,
					"error": TerravoltErrors.tv_rpc_error(
						TerravoltErrors.EDITOR_UNSUPPORTED_IN_VERSION,
						"editor.unsupported_in_version",
						"Could not persist layout snapshot.",
						{"action": action}
					),
				}
			return {"ok": true, "result": {"saved": true, "name": name}}
		"load":
			var lpath := _layout_dir.path_join("%s.cfg" % name)
			if not FileAccess.file_exists(lpath):
				return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.EDITOR_UNSUPPORTED_IN_VERSION, "editor.unsupported_in_version", "Layout not found.", {"name": name})}
			return {"ok": true, "result": {"loaded": true, "name": name}}
		"delete":
			var dpath := _layout_dir.path_join("%s.cfg" % name)
			if FileAccess.file_exists(dpath):
				DirAccess.remove_absolute(dpath)
			return {"ok": true, "result": {"deleted": true, "name": name}}
		_:
			return {"ok": false, "error": TerravoltErrors.tv_rpc_error(TerravoltErrors.PROTOCOL_INVALID_PARAMS, "protocol.invalid_params", "Unknown layout action.", {"action": action})}
