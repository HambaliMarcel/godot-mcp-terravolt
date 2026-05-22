extends Node

## Game-process TCP JSON-RPC bridge (task 17). Listens on terravolt_mcp/runtime/port (default 6506).

const _Helpers := preload("../handlers/runtime_helpers.gd")

var _tcp := TCPServer.new()
var _peer: StreamPeerTCP
var _buf := ""
var _bound := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var port := _Helpers.bridge_port()
	if _tcp.listen(port, "127.0.0.1") != OK:
		push_warning("TerraVolt runtime bridge: listen failed on port %d" % port)
		return
	_bound = true
	printerr("TERRAVOLT_RUNTIME_PORT=%d\n" % _tcp.get_local_port())
	_Helpers.capture_log("runtime bridge listening on %d" % _tcp.get_local_port(), "info", "bridge")
	set_process(true)


func _input(event: InputEvent) -> void:
	_Helpers.on_input_event(event)


func _process(_delta: float) -> void:
	if not _bound:
		return
	if _peer == null:
		if _tcp.is_connection_available():
			_peer = _tcp.take_connection()
			_buf = ""
		return
	_peer.poll()
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
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
		var out := _dispatch_line(line)
		if out.length() == 0:
			continue
		if _peer.put_data((out + "\n").to_utf8_buffer()) != OK:
			_peer = null
			break


func _exit_tree() -> void:
	if _tcp.is_listening():
		_tcp.stop()


func _dispatch_line(line: String) -> String:
	var parsed: Variant = JSON.parse_string(line)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return JSON.stringify({"jsonrpc": "2.0", "error": {"code": -32700, "message": "Parse error"}, "id": null})
	var obj := parsed as Dictionary
	if str(obj.get("jsonrpc", "")) != "2.0":
		return JSON.stringify({"jsonrpc": "2.0", "error": {"code": -32600, "message": "Invalid Request"}, "id": obj.get("id")})
	var method := str(obj.get("method", ""))
	var params: Dictionary = obj.get("params", {}) as Dictionary
	if typeof(params) != TYPE_DICTIONARY:
		params = {}
	var idv: Variant = obj.get("id", null)
	var handled := _Helpers.dispatch_bridge(method, params)
	if handled.get("ok", false):
		return JSON.stringify({"jsonrpc": "2.0", "result": handled.get("result", {}), "id": idv})
	var err: Dictionary = handled.get("error", {})
	return JSON.stringify({"jsonrpc": "2.0", "error": err, "id": idv})
