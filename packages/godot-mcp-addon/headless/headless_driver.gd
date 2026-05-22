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
const _MAX_LINE_BYTES_DEFAULT := 1048576

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
