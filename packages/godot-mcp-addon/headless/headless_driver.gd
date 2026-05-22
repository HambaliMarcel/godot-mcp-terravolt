extends SceneTree

## Headless TerraVolt driver: newline-delimited JSON-RPC over TCP loopback.
## Self-contained — no `res://` dependency, so it works from any
## `--path <project>` regardless of whether the addon is mounted.
##
## Stderr handshake (parsed by the Node router):
##   TERRAVOLT_HEADLESS_PORT=<port>
##
## Catalog meta is injected through environment variables:
##   TERRAVOLT_CATALOG_VERSION   (string)  default: "unknown"
##   TERRAVOLT_REGISTRY_SHA256   (string)  default: "unknown"

const _PROTOCOL_INVALID_JSONRPC_VERSION := -33100
const _PROTOCOL_METHOD_NOT_FOUND := -33101
const _PROTOCOL_INVALID_PARAMS := -33102
const _TRANSPORT_UNSUPPORTED_FRAME := -33006
const _EDITOR_NOT_AVAILABLE := -33400
const _MAX_LINE_BYTES_DEFAULT := 1048576
const _Ops := preload("./catalog_ops.gd")

var _tcp := TCPServer.new()
var _peer: StreamPeerTCP
var _buf := ""
var _stop := false
var _catalog_version := "unknown"
var _registry_sha256 := "unknown"


func _initialize() -> void:
	_catalog_version = OS.get_environment("TERRAVOLT_CATALOG_VERSION")
	if _catalog_version.is_empty():
		_catalog_version = "unknown"
	_registry_sha256 = OS.get_environment("TERRAVOLT_REGISTRY_SHA256")
	if _registry_sha256.is_empty():
		_registry_sha256 = "unknown"

	if _tcp.listen(0, "127.0.0.1") != OK:
		printerr("Terravolt headless: listen failed")
		quit(127)
		return
	printerr("TERRAVOLT_HEADLESS_PORT=%d\n" % _tcp.get_local_port())
	_Ops.ensure_main_scene(self)
	process_frame.connect(_tick)


func _tick() -> void:
	if _stop:
		quit(0)
		return
	if _peer == null:
		if _tcp.is_connection_available():
			_peer = _tcp.take_connection()
			_buf = ""
		return
	_peer.poll()
	var st := _peer.get_status()
	if st != StreamPeerTCP.STATUS_CONNECTED:
		_peer = null
		_buf = ""
		return

	var nbytes := _peer.get_available_bytes()
	if nbytes <= 0:
		return

	var pkt := _peer.get_partial_data(nbytes)
	if pkt[0] != OK:
		return

	_buf += (pkt[1] as PackedByteArray).get_string_from_utf8()

	while true:
		var nl := _buf.find("\n")
		if nl < 0:
			break
		var line := _buf.substr(0, nl).strip_edges()
		_buf = _buf.substr(nl + 1)
		if line.is_empty():
			continue
		var out := _dispatch(line)
		if out.length() == 0:
			continue
		if _peer.put_data((out + "\n").to_utf8_buffer()) != OK:
			_stop = true
			break


func _finalize() -> void:
	if _tcp.is_listening():
		_tcp.stop()


func _wr_ok(idv: Variant, res: Variant) -> Dictionary:
	return {"jsonrpc": "2.0", "result": res, "id": idv}


func _wr_err(idv: Variant, err: Dictionary) -> Dictionary:
	return {"jsonrpc": "2.0", "error": err, "id": idv}


func _err(spec_code: int, message: String, tv_code: int, hint: String, context: Variant = null) -> Dictionary:
	var data: Dictionary = {"tv_code": tv_code, "hint": hint}
	if context != null and typeof(context) == TYPE_DICTIONARY:
		data["context"] = context
	return {"code": spec_code, "message": message, "data": data}


func _dispatch(line: String) -> String:
	if line.to_utf8_buffer().size() > _MAX_LINE_BYTES_DEFAULT:
		var e := _err(-32603, "Frame too large", _TRANSPORT_UNSUPPORTED_FRAME, "", {})
		return JSON.stringify(_wr_err(null, e))

	var parsed: Variant = JSON.parse_string(line)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		var pe := _err(-32700, "Parse error", _PROTOCOL_INVALID_PARAMS, "", {})
		return JSON.stringify(_wr_err(null, pe))

	var obj := parsed as Dictionary
	if str(obj.get("jsonrpc", "")) != "2.0":
		var ve := _err(-32600, "Invalid Request", _PROTOCOL_INVALID_JSONRPC_VERSION, "", {})
		var hid := obj.has("id")
		return JSON.stringify(_wr_err(obj.get("id", null) if hid else null, ve))

	var m: Variant = obj.get("method", null)
	var has_id := obj.has("id")
	var rid: Variant = obj.get("id", null)
	if typeof(m) != TYPE_STRING:
		var me := _err(-32600, "Invalid Request", _PROTOCOL_INVALID_PARAMS, "method string", {})
		return JSON.stringify(_wr_err(rid if has_id else null, me))

	var method := m as String
	var params_variant: Variant = {}
	if obj.has("params"):
		params_variant = obj["params"]

	if has_id:
		var bad := typeof(params_variant) != TYPE_DICTIONARY and typeof(params_variant) != TYPE_ARRAY
		if bad:
			var ip := _err(-32602, "Invalid params", _PROTOCOL_INVALID_PARAMS, "object/array", {})
			return JSON.stringify(_wr_err(rid, ip))

	var pd: Dictionary = {}
	if typeof(params_variant) == TYPE_DICTIONARY:
		pd = params_variant as Dictionary

	if not has_id:
		printerr("Terravolt headless notification `%s`" % method)
		return ""

	match method:
		"ping":
			return JSON.stringify(_wr_ok(rid, {"ok": true, "ts": Time.get_ticks_msec()}))
		"server.info":
			var gv := Engine.get_version_info()
			var info := {
				"name": "terravolt-godot-headless",
				"catalog_version": _catalog_version,
				"registry_sha256": _registry_sha256,
				"godot_version": gv.get("string", JSON.stringify(gv)),
				"build_mode": "headless_tcp",
				"supported_methods_count": 34,
			}
			return JSON.stringify(_wr_ok(rid, info))
		"server.list_methods":
			var lst: Array[String] = [
				"dispatch.cancel",
				"ping",
				"project.get_settings",
				"project.info",
				"project.list_autoloads",
				"project.set_main_scene",
				"project.set_settings",
				"scene.create",
				"scene.delete",
				"scene.get",
				"scene.list",
				"scene.validate",
				"script.validate_syntax",
				"server.info",
				"server.list_methods",
			]
			lst.sort()
			return JSON.stringify(_wr_ok(rid, lst))
		"dispatch.cancel":
			return JSON.stringify(_wr_ok(rid, null))
		"script.validate_syntax":
			return JSON.stringify(_wr_ok(rid, _validate_syntax(pd)))
		"scene.list":
			var scenes := _Ops.walk_scenes()
			return JSON.stringify(_wr_ok(rid, {"scenes": scenes, "total": scenes.size()}))
		"scene.get":
			return JSON.stringify(_headless_scene_get(rid, pd))
		"scene.create":
			return JSON.stringify(_headless_scene_create(rid, pd))
		"scene.delete":
			return JSON.stringify(_headless_scene_delete(rid, pd))
		"scene.validate":
			var path := _Ops.resolve_path(str(pd.get("scope", "active")))
			if str(pd.get("scope", "active")) != "active":
				var g := _Ops.scene_get(path)
				if not g.get("ok", false):
					return JSON.stringify(
						_wr_err(
							rid,
							_err(-32603, str(g.get("message", "scene.path_not_found")), int(g.get("code", -33500)), "", {"path": path})
						)
					)
			return JSON.stringify(_wr_ok(rid, {"ok": true, "issues": []}))
		"project.info":
			return JSON.stringify(_wr_ok(rid, _Ops.project_info().result))
		"project.get_settings":
			return JSON.stringify(_wr_ok(rid, _Ops.project_get_settings(pd).result))
		"project.set_settings":
			return JSON.stringify(_wr_ok(rid, _Ops.project_set_settings(pd).result))
		"project.list_autoloads":
			return JSON.stringify(_wr_ok(rid, {"autoloads": []}))
		"project.set_main_scene":
			var mp := _Ops.resolve_path(str(pd.get("path", "")))
			if bool(pd.get("validate", true)) and not _Ops.scene_exists(mp):
				return JSON.stringify(
					_wr_err(rid, _err(-32603, "scene.path_not_found", -33500, "", {"path": mp}))
				)
			ProjectSettings.set_setting("application/run/main_scene", mp)
			ProjectSettings.save()
			return JSON.stringify(_wr_ok(rid, {"set": true, "path": mp}))
		"scene.open", "scene.close", "scene.save", "scene.save_as":
			var ed := _err(-32603, "editor.not_available", _EDITOR_NOT_AVAILABLE, "Open the editor for this method.", {})
			return JSON.stringify(_wr_err(rid, ed))
		"node.get", "node.add", "node.delete", "node.is_a", "node.modify", "node.evaluate_expression", "node.find_path", "node.list_groups", "node.list_signals":
			return JSON.stringify(_headless_node(rid, method, pd))
		"node.duplicate", "node.move", "node.rename", "node.attach_script", "node.detach_script":
			var na := _err(-32603, "editor.no_active_scene", -33580, "Headless v1 partial node support.", {})
			return JSON.stringify(_wr_err(rid, na))
		"script.list", "script.read", "script.write", "script.patch", "script.validate", "script.find_usages", "script.format":
			return JSON.stringify(_headless_catalog(rid, method, pd))
		"script.rename_symbol":
			var ed2 := _err(-32603, "editor.no_active_scene", -33580, "Rename requires editor v1.", {})
			return JSON.stringify(_wr_err(rid, ed2))
		"signal.list_declared", "signal.list_connections", "signal.find_listeners", "signal.graph", "signal.add_declaration", "signal.remove_declaration":
			return JSON.stringify(_headless_catalog(rid, method, pd))
		"signal.connect", "signal.disconnect", "signal.bulk_connect", "signal.bulk_disconnect":
			var sg := _err(-32603, "editor.no_active_scene", -33580, "Signal wiring requires active scene in editor.", {})
			return JSON.stringify(_wr_err(rid, sg))
		"scene.get_tree", "scene.get_subtree", "scene.find_in_tree", "scene.instantiate", "scene.pack", "scene.replace":
			var na := _err(-32603, "editor.no_active_scene", -33580, "No active scene in headless v1.", {})
			return JSON.stringify(_wr_err(rid, na))
		_:
			var nf := _err(-32601, "Method not found", _PROTOCOL_METHOD_NOT_FOUND, "", {"method": method})
			return JSON.stringify(_wr_err(rid, nf))


func _validate_syntax(p: Dictionary) -> Dictionary:
	var raw := str(p.get("path", "")).strip_edges()
	if raw.is_empty():
		return {"ok": false, "errors": [{"line": 0, "col": 0, "message": "`path` required"}]}
	var fs := raw
	if raw.begins_with("res://") or raw.begins_with("user://"):
		fs = ProjectSettings.globalize_path(raw)
	elif not raw.begins_with("/") and not (raw.length() >= 3 and raw[1] == ":"):
		fs = ProjectSettings.globalize_path("res://%s" % raw.lstrip("/"))
	if not raw.to_lower().ends_with(".gd") and not fs.to_lower().ends_with(".gd"):
		return {"ok": false, "errors": [{"line": 0, "col": 0, "message": "Headless validates .gd (use router for .cs CLI)"}]}
	if not FileAccess.file_exists(fs):
		return {"ok": false, "errors": [{"line": 0, "col": 0, "message": "missing: %s" % fs}]}

	var gd := GDScript.new()
	gd.source_code = FileAccess.get_file_as_string(fs)

	var erc := gd.reload()
	if erc != OK:
		return {"ok": false, "errors": [{"line": 1, "col": 1, "message": error_string(erc)}]}
	return {"ok": true}


func _headless_scene_get(rid: Variant, pd: Dictionary) -> Dictionary:
	var g := _Ops.scene_get(str(pd.get("path", "")))
	if not g.get("ok", false):
		return _wr_err(
			rid,
			_err(-32603, str(g.get("message", "scene.path_not_found")), int(g.get("code", -33500)), "", {})
		)
	return _wr_ok(rid, g.get("result", {}))


func _headless_scene_create(rid: Variant, pd: Dictionary) -> Dictionary:
	var g := _Ops.scene_create(pd)
	if not g.get("ok", false):
		return _wr_err(
			rid,
			_err(-32603, str(g.get("message", "scene.create_failed")), int(g.get("code", -33510)), "", {})
		)
	return _wr_ok(rid, g.get("result", {}))


func _headless_scene_delete(rid: Variant, pd: Dictionary) -> Dictionary:
	var path := _Ops.resolve_path(str(pd.get("path", "")))
	if not _Ops.scene_exists(path):
		return _wr_err(rid, _err(-32603, "scene.path_not_found", -33500, "", {"path": path}))
	var abs := _Ops.globalize(path)
	var sz := FileAccess.get_file_as_bytes(abs).size()
	DirAccess.remove_absolute(abs)
	return _wr_ok(rid, {"deleted": true, "path": path, "freed_bytes": sz})


func _headless_node(rid: Variant, method: String, pd: Dictionary) -> Dictionary:
	var g := _Ops.headless_node_dispatch(method, pd)
	if not g.get("ok", false):
		return _wr_err(
			rid,
			_err(-32603, str(g.get("message", "node.error")), int(g.get("code", -33501)), "", {})
		)
	return _wr_ok(rid, g.get("result", {}))


func _headless_catalog(rid: Variant, method: String, pd: Dictionary) -> Dictionary:
	var g: Dictionary = _Ops.headless_script_dispatch(method, pd)
	if not g.get("ok", false):
		return _wr_err(
			rid,
			_err(-32603, str(g.get("message", "catalog.error")), int(g.get("code", -33101)), "", {})
		)
	return _wr_ok(rid, g.get("result", {}))
