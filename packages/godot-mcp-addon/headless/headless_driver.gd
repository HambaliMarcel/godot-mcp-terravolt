extends SceneTree

## Headless TerraVolt: newline-delimited JSON-RPC over TCP loopback.
## Stderr announces: TERRAVOLT_HEADLESS_PORT=<port>

const _CatalogMeta := preload("../_generated/catalog_meta.gd")
const TV := preload("../error_codes.gd")

var _tcp := TCPServer.new()
var _peer: StreamPeerTCP
var _buf := ""
var _stop := false


func _initialize() -> void:
	if _tcp.listen(0, "127.0.0.1") != OK:
		printerr("Terravolt headless: listen failed")
		OS.exit(127)
	printerr("TERRAVOLT_HEADLESS_PORT=%d\n" % _tcp.get_local_port())
	process_frame.connect(_tick)


func _tick() -> void:
	if _stop:
		quit(0)
		return
	if _peer == null:
		if _tcp.is_connection_available():
			_peer = _tcp.take_connection()
		return
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		printerr("Terravolt headless: peer disconnected")
		_stop = true
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


func _dispatch(line: String) -> String:
	var lim := int(ProjectSettings.get_setting("terravolt_mcp/transport/max_jsonrpc_line_bytes", 1048576))
	if line.to_utf8_buffer().size() > lim:
		var e := TV.json_rpc_error(-32603, "Frame too large", TV.TRANSPORT_UNSUPPORTED_FRAME, "", {})
		return JSON.stringify(_wr_err(null, e))

	var parsed := JSON.parse_string(line)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		var pe := TV.json_rpc_error(-32700, "Parse error", TV.PROTOCOL_INVALID_PARAMS, "", {})
		return JSON.stringify(_wr_err(null, pe))

	var obj := parsed as Dictionary
	if str(obj.get("jsonrpc", "")) != "2.0":
		var ve := TV.json_rpc_error(-32600, "Invalid Request", TV.PROTOCOL_INVALID_JSONRPC_VERSION, "", {})
		var hid := obj.has("id")
		return JSON.stringify(_wr_err(obj.get("id", null) if hid else null, ve))

	var m := obj.get("method", null)
	var has_id := obj.has("id")
	var rid := obj.get("id", null)
	if typeof(m) != TYPE_STRING:
		var me := TV.json_rpc_error(-32600, "Invalid Request", TV.PROTOCOL_INVALID_PARAMS, "method string", {})
		return JSON.stringify(_wr_err(rid if has_id else null, me))

	var method := m as String
	var params_variant: Variant = {}
	if obj.has("params"):
		params_variant = obj["params"]

	if has_id:
		var bad := typeof(params_variant) != TYPE_DICTIONARY and typeof(params_variant) != TYPE_ARRAY
		if bad:
			var ip := TV.json_rpc_error(-32602, "Invalid params", TV.PROTOCOL_INVALID_PARAMS, "object/array", {})
			return JSON.stringify(_wr_err(rid, ip))

	var pd := {} if typeof(params_variant) != TYPE_DICTIONARY else (params_variant as Dictionary)

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
				"catalog_version": _CatalogMeta.CATALOG_VERSION,
				"registry_sha256": _CatalogMeta.REGISTRY_SHA256,
				"godot_version": gv.get("string", JSON.stringify(gv)),
				"build_mode": "headless_tcp",
				"supported_methods_count": 5,
			}
			return JSON.stringify(_wr_ok(rid, info))
		"server.list_methods":
			var lst: Array[String] = ["dispatch.cancel", "ping", "script.validate_syntax", "server.info", "server.list_methods"]
			lst.sort()
			return JSON.stringify(_wr_ok(rid, lst))
		"dispatch.cancel":
			return JSON.stringify(_wr_ok(rid, null))
		"script.validate_syntax":
			return JSON.stringify(_wr_ok(rid, _validate_syntax(pd)))
		_:
			var nf := TV.json_rpc_error(-32601, "Method not found", TV.PROTOCOL_METHOD_NOT_FOUND, "", {"method": method})
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
