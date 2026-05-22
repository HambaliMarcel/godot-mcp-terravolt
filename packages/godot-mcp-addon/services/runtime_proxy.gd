extends RefCounted
class_name TerravoltRuntimeProxy

## Forwards JSON-RPC to the game-process runtime bridge (TCP newline-delimited).

const DEFAULT_TIMEOUT_MS := 2000
const _Session := preload("./runtime_session.gd")


static func bridge_call_sync(
	port: int,
	method: String,
	params: Dictionary,
	timeout_ms: int = DEFAULT_TIMEOUT_MS
) -> Dictionary:
	if port <= 0:
		return _bridge_err(-33931, "runtime.bridge_unavailable", "Invalid bridge port.", {})
	var tcp := StreamPeerTCP.new()
	var err := tcp.connect_to_host("127.0.0.1", port)
	if err != OK:
		return _bridge_err(
			-33931,
			"runtime.bridge_unavailable",
			"Could not connect to runtime bridge on port %d." % port,
			{"port": port, "connect_error": err}
		)
	var connect_deadline := Time.get_ticks_msec() + mini(timeout_ms, 3000)
	while tcp.get_status() == StreamPeerTCP.STATUS_CONNECTING:
		tcp.poll()
		if Time.get_ticks_msec() >= connect_deadline:
			tcp.disconnect_from_host()
			return _bridge_err(
				-33931,
				"runtime.bridge_unavailable",
				"Timed out connecting to runtime bridge.",
				{"port": port}
			)
		OS.delay_msec(5)
	if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		tcp.disconnect_from_host()
		return _bridge_err(
			-33931,
			"runtime.bridge_unavailable",
			"Could not connect to runtime bridge on port %d." % port,
			{"port": port, "status": tcp.get_status()}
		)

	var req_id := randi() % 1_000_000_000
	var payload := JSON.stringify(
		{"jsonrpc": "2.0", "id": req_id, "method": method, "params": params}
	) + "\n"
	if tcp.put_data(payload.to_utf8_buffer()) != OK:
		tcp.disconnect_from_host()
		return _bridge_err(
			-33935,
			"runtime.bridge_rpc_failed",
			"Failed to send bridge request.",
			{"method": method}
		)

	var buf := ""
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		tcp.poll()
		if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
		var n := tcp.get_available_bytes()
		if n > 0:
			var pkt := tcp.get_partial_data(n)
			if pkt[0] == OK:
				buf += (pkt[1] as PackedByteArray).get_string_from_utf8()
				while true:
					var nl := buf.find("\n")
					if nl < 0:
						break
					var line := buf.substr(0, nl).strip_edges()
					buf = buf.substr(nl + 1)
					if line.is_empty():
						continue
					var parsed: Variant = JSON.parse_string(line)
					if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
						continue
					var obj := parsed as Dictionary
					if obj.get("id", null) != req_id:
						continue
					tcp.disconnect_from_host()
					if obj.has("error"):
						var er := obj["error"] as Dictionary
						var tv := int((er.get("data", {}) as Dictionary).get("tv_code", -33935))
						return {"ok": false, "error": er, "tv_code": tv}
					return {"ok": true, "result": obj.get("result", {})}
		OS.delay_msec(4)

	tcp.disconnect_from_host()
	return _bridge_err(
		-33935,
		"runtime.bridge_rpc_failed",
		"Bridge RPC timed out.",
		{"method": method, "timeout_ms": timeout_ms}
	)


static func forward_runtime(method: String, params: Dictionary, timeout_ms: int = DEFAULT_TIMEOUT_MS) -> Dictionary:
	if not _Session.alive:
		return _no_session()
	var bridge_method := method
	if bridge_method.begins_with("runtime."):
		bridge_method = bridge_method.substr(8)
	return bridge_call_sync(_Session.bridge_port, bridge_method, params, timeout_ms)


static func _tv_err(tv_code: int, symbol: String, message: String, ctx: Dictionary) -> Dictionary:
	var data: Dictionary = {"tv_code": tv_code, "hint": message, "app_code": symbol}
	if not ctx.is_empty():
		data["context"] = ctx
	return {"code": tv_code, "message": symbol, "data": data}


static func _bridge_err(tv_code: int, symbol: String, message: String, ctx: Dictionary) -> Dictionary:
	return {"ok": false, "error": _tv_err(tv_code, symbol, message, ctx)}


static func _no_session() -> Dictionary:
	return {
		"ok": false,
		"error": _tv_err(
			-33930,
			"runtime.no_session",
			"No active runtime session. Start with runtime.play (editor) or runtime.start_headless.",
			{
				"autoHeal": {
					"hint": "Start a game session before calling runtime inspection tools.",
					"steps": [
						"Call runtime.start_headless { } for CI/headless, or runtime.play { mode: \"current_scene\" } in the editor.",
						"Then retry this tool once runtime.status reports alive: true.",
					],
				},
			}
		),
	}
