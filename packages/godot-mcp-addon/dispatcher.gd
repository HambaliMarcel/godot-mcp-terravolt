@tool
extends RefCounted
class_name TerraVoltDispatcher

## Strict JSON-RPC 2.0 dispatch + built-in plumbing methods (task 04).

signal rpc_ledger_record(
	method: String, peer_id: int, latency_ms: int, ok: bool, err_code: Variant
)

var logger: TerraVoltLogger
var server_ref: WeakRef
var addon_version: String = "0.1.0"
var editor_plugin_ref: WeakRef

var _methods: Dictionary = {}
var _start_ms: int = 0


func _init() -> void:
	_start_ms = Time.get_ticks_msec()


func configure(
	p_logger: TerraVoltLogger,
	p_server: Variant,
	p_editor_plugin: EditorPlugin,
	p_addon_ver: String
) -> void:
	logger = p_logger
	server_ref = weakref(p_server)
	editor_plugin_ref = weakref(p_editor_plugin)
	addon_version = p_addon_ver
	_register_builtin()


func uptime_sec() -> float:
	return float(Time.get_ticks_msec() - _start_ms) / 1000.0


func register(method_name: String, schema: Variant, handler: Callable) -> bool:
	if method_name.is_empty():
		return false
	_methods[method_name] = {"handler": handler, "schema": schema}
	return true


func unregister(method_name: String) -> bool:
	return _methods.erase(method_name)


func list_registered_methods() -> Array[String]:
	var keys: Array[String] = []
	for k in _methods.keys():
		keys.append(str(k))
	keys.sort()
	return keys


func dispatch_peer_inbound(peer_id: int, text: String) -> PackedStringArray:
	var outs: PackedStringArray = PackedStringArray()
	var t_batch := Time.get_ticks_msec()
	var max_bytes := int(ProjectSettings.get_setting("terravolt_mcp/server/max_frame_bytes", 4194304))
	if text.to_utf8_buffer().size() > max_bytes:
		logger.log_force(
			"warn",
			"transport",
			"frame_discarded_oversized",
			{"peer_id": peer_id, "bytes": text.to_utf8_buffer().size(), "limit": max_bytes}
		)
		var err_ov := TerraVoltErrors.tv_rpc_error(
			TerraVoltErrors.TRANSPORT_UNSUPPORTED_FRAME,
			"Frame too large",
			"Shrink payload or raise terravolt_mcp/server/max_frame_bytes",
			{"peer_id": peer_id}
		)
		outs.append(
			JSON.stringify({"jsonrpc": "2.0", "error": err_ov, "id": null})
		)
		emit_signal(
			&"rpc_ledger_record",
			"<oversized>",
			peer_id,
			Time.get_ticks_msec() - t_batch,

			false,
			err_ov.get(&"code", TerraVoltErrors.TRANSPORT_UNSUPPORTED_FRAME)
		)
		return outs

	if text.strip_edges().is_empty():
		return outs

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		var pe := TerraVoltErrors.json_rpc_error(
			-32700,
			"Parse error",
			TerraVoltErrors.PROTOCOL_INVALID_PARAMS,
			"Body is not valid JSON",
			{}
		)
		outs.append(JSON.stringify({"jsonrpc": "2.0", "error": pe, "id": null}))
		emit_signal(&"rpc_ledger_record", "<parse>", peer_id, Time.get_ticks_msec() - t_batch, false, -32700)
		logger.log_force("warn", "protocol", "parse_error", {"peer_id": peer_id})
		return outs

	if typeof(parsed) == TYPE_ARRAY:
		var batch_cap := int(ProjectSettings.get_setting("terravolt_mcp/protocol/batch_max_size", 50))
		if batch_cap <= 0:
			batch_cap = 50
		var arr := parsed as Array
		if arr.size() > batch_cap:
			var be := TerraVoltErrors.json_rpc_error(
				-32600,
				"Invalid Request",
				TerraVoltErrors.PROTOCOL_BATCH_TOO_LARGE,
				"Batch exceeds configured limit",
				{"batch_size": arr.size(), "limit": batch_cap}
			)
			outs.append(JSON.stringify({"jsonrpc": "2.0", "error": be, "id": null}))
			emit_signal(
				&"rpc_ledger_record",
				"<batch>",
				peer_id,
				Time.get_ticks_msec() - t_batch,
				false,
				-32600
			)
			return outs

		var batch_out: Array = []
		for elt in arr:
			var packed := _handle_single(peer_id, elt)
			if packed is Dictionary:
				var dpack := packed as Dictionary
				if not dpack.get(&"skip_response", false):
					batch_out.append(dpack.get(&"payload", {}))
		if batch_out.size() > 0:
			outs.append(JSON.stringify(batch_out))
		return outs

	var single := _handle_single(peer_id, parsed)
	if single is Dictionary:
		var sp := single as Dictionary
		if not sp.get(&"skip_response", false):
			outs.append(JSON.stringify(sp.get(&"payload", {})))

	return outs


func enqueue_server_notification_obj(method: String, params: Variant) -> String:
	if params == null:
		params = {}
	return JSON.stringify({"jsonrpc": "2.0", "method": method, "params": params})


func _handle_single(peer_id: int, elt: Variant) -> Variant:
	var t_req := Time.get_ticks_msec()
	if typeof(elt) != TYPE_DICTIONARY:
		var ir := TerraVoltErrors.json_rpc_error(
			-32600,
			"Invalid Request",
			TerraVoltErrors.PROTOCOL_INVALID_JSONRPC_VERSION,
			"Each JSON-RPC envelope must be an object",
			{}
		)
		emit_signal(&"rpc_ledger_record", "<invalid>", peer_id, Time.get_ticks_msec() - t_req, false, -32600)
		return {"payload": {"jsonrpc": "2.0", "error": ir, "id": null}}

	var obj := elt as Dictionary
	var has_id_key := obj.has("id")

	var proto := obj.get(&"jsonrpc", null)
	var proto_bad := proto == null or str(proto) != "2.0"

	if proto_bad:
		var verr := TerraVoltErrors.json_rpc_error(
			-32600,
			"Invalid Request",
			TerraVoltErrors.PROTOCOL_INVALID_JSONRPC_VERSION,
			'`jsonrpc` must be `"2.0"`',
			{}
		)
		emit_signal(
			&"rpc_ledger_record",
			obj.get(&"method", "<unknown>"),
			peer_id,
			Time.get_ticks_msec() - t_req,
			false,
			-32600
		)
		return {"payload": {"jsonrpc": "2.0", "error": verr, "id": obj.get(&"id", null) if has_id_key else null}}

	if not obj.has(&"method") or typeof(obj[&"method"]) != TYPE_STRING:
		var mr := TerraVoltErrors.json_rpc_error(
			-32600,
			"Invalid Request",
			TerraVoltErrors.PROTOCOL_INVALID_JSONRPC_VERSION,
			"A string `method` is required",
			{}
		)
		emit_signal(&"rpc_ledger_record", "<method>", peer_id, Time.get_ticks_msec() - t_req, false, -32600)
		return {
			"payload": {"jsonrpc": "2.0", "error": mr, "id": obj.get(&"id", null) if has_id_key else null}
		}

	var params_variant: Variant = {}
	if obj.has(&"params"):
		params_variant = obj[&"params"]
		if typeof(params_variant) != TYPE_DICTIONARY and typeof(params_variant) != TYPE_ARRAY:
			var pt := TerraVoltErrors.json_rpc_error(
				-32602,
				"Invalid params",
				TerraVoltErrors.PROTOCOL_INVALID_PARAMS,
				"`params` must be object or array when present",
				{}
			)
			emit_signal(&"rpc_ledger_record", str(obj[&"method"]), peer_id, Time.get_ticks_msec() - t_req, false, -32602)
			return {
				"payload":
				{"jsonrpc": "2.0", "error": pt, "id": obj.get(&"id", null) if has_id_key else null}
			}

	var method := str(obj[&"method"])
	var wants_response := has_id_key

	if not _methods.has(method):
		var nf := TerraVoltErrors.json_rpc_error(
			-32601,
			"Method not found",
			TerraVoltErrors.PROTOCOL_METHOD_NOT_FOUND,
			"Use server.list_methods to inspect supported methods",
			{"method": method}
		)
		emit_signal(&"rpc_ledger_record", method, peer_id, Time.get_ticks_msec() - t_req, false, -32601)
		if wants_response:
			return {
				"payload": {"jsonrpc": "2.0", "error": nf, "id": obj.get(&"id", null)},
			}
		return {"skip_response": true}

	var entry: Variant = _methods[method]
	var schema: Variant = (entry as Dictionary)[&"schema"]
	var callable_handler: Callable = (entry as Dictionary)[&"handler"]

	var pv_for_schema := params_variant

	var val: Dictionary
	if typeof(schema) == TYPE_DICTIONARY:
		val = TerraVoltJsonSchemaMini.validate(pv_for_schema, schema)
	else:
		val = {"ok": true}

	if not val.get(&"ok", false):
		var inf := TerraVoltErrors.json_rpc_error(
			-32602,
			"Invalid params",
			TerraVoltErrors.PROTOCOL_INVALID_PARAMS,
			"Params failed schema validation",
			{"errors": [val]}
		)
		emit_signal(&"rpc_ledger_record", method, peer_id, Time.get_ticks_msec() - t_req, false, -32602)
		if wants_response:
			return {
				"payload": {"jsonrpc": "2.0", "error": inf, "id": obj.get(&"id", null)},
			}
		logger.log_force("warn", "protocol", "invalid_params", {"peer_id": peer_id, "method": method, "detail": val})
		return {"skip_response": true}

	var ctx := {
		"peer_id": peer_id,
		"method": method,
		"params": params_variant,
		"request_id": obj.get(&"id", null) if has_id_key else null,
		"is_notification": not wants_response,
	}

	var result: Variant = callable_handler.call(ctx)
	var lat := Time.get_ticks_msec() - t_req

	if typeof(result) != TYPE_DICTIONARY or not (result as Dictionary).has(&"ok"):
		var ie := TerraVoltErrors.json_rpc_error(
			-32603,
			"Internal error",
			TerraVoltErrors.DISPATCH_HANDLER_THREW,
			"Handler returned an unexpected signature",
			{}
		)
		emit_signal(&"rpc_ledger_record", method, peer_id, lat, false, -32603)
		logger.log_force("error", "dispatch", "bad_handler_return", {"method": method, "peer_id": peer_id})
		if wants_response:
			return {"payload": {"jsonrpc": "2.0", "error": ie, "id": obj.get(&"id", null)}}
		return {"skip_response": true}

	var rd := result as Dictionary
	if bool(rd[&"ok"]):
		emit_signal(&"rpc_ledger_record", method, peer_id, lat, true, OK)
		if wants_response:
			return {
				"payload": {"jsonrpc": "2.0", "result": rd.get(&"result", null), "id": obj.get(&"id", null)},
			}
		logger.log_force("debug", "handler", "notification_ok", {"method": method, "peer_id": peer_id})
		return {"skip_response": true}

	var err_wire = rd.get(&"error", null)
	var ecc := -32603

	if typeof(err_wire) == TYPE_DICTIONARY:

		ecc = int((err_wire as Dictionary).get(&"code", -32603))
	emit_signal(&"rpc_ledger_record", method, peer_id, lat, false, ecc)

	if wants_response:
		return {"payload": {"jsonrpc": "2.0", "error": err_wire, "id": obj.get(&"id", null)}}

	return {"skip_response": true}


func _register_builtin() -> void:
	register("ping", {"type": "object", "properties": {}, "additionalProperties": false}, _h_ping)

	register(
		"echo",
		{
			"type": "object",
			"required": ["message"],
			"properties": {"message": {"type": "string", "minLength": 1}},
			"additionalProperties": false
		},
		_h_echo
	)

	register("server.info", {"type": "object", "properties": {}, "additionalProperties": false}, _h_server_info)

	register(
		"server.list_methods",
		{
			"type": "object",
			"properties": {"prefix": {"type": "string"}},
			"additionalProperties": false
		},
		_h_server_list_methods
	)

	register("server.heartbeat", {"type": "object", "properties": {}, "additionalProperties": false}, _h_heartbeat)

	register(
		"server.shutdown",
		{
			"type": "object",
			"properties": {"reason": {"type": "string"}},
			"additionalProperties": false
		},
		_h_server_shutdown
	)

	register(
		"log.tail",
		{
			"type": "object",
			"properties": {
				"lines": {"type": "integer", "minimum": 1, "maximum": 500},
				"level": {"type": "string"}
			},
			"additionalProperties": false
		},
		_h_log_tail
	)

	register(
		"log.set_level",
		{
			"type": "object",
			"required": ["level"],
			"properties": {
				"level": {"type": "string", "enum": ["debug", "info", "warn", "error"]}
			},
			"additionalProperties": false
		},
		_h_log_set_level
	)


func _h_ping(_ctx: Dictionary) -> Dictionary:
	return {"ok": true, "result": {"ok": true, "ts": Time.get_ticks_msec()}}


func _h_echo(ctx: Dictionary) -> Dictionary:
	var msg := ""
	if typeof(ctx[&"params"]) == TYPE_DICTIONARY:
		msg = str((ctx[&"params"] as Dictionary)[&"message"])
	return {
		"ok": true,
		"result": {"message": msg, "peer_id": ctx["peer_id"], "ts": Time.get_ticks_msec()}
	}


func _h_server_list_methods(ctx: Dictionary) -> Dictionary:
	var pref := ""
	if typeof(ctx[&"params"]) == TYPE_DICTIONARY and (ctx[&"params"] as Dictionary).has(&"prefix"):
		pref = str((ctx[&"params"] as Dictionary)[&"prefix"])
	var ms := list_registered_methods()
	var out: Array[String] = []
	for m in ms:
		if pref.is_empty() or str(m).begins_with(pref):
			out.append(m)
	out.sort()
	return {"ok": true, "result": out}


func _h_heartbeat(_ctx: Dictionary) -> Dictionary:
	return {"ok": true, "result": {"pong": true, "ts": Time.get_ticks_msec()}}


func _h_server_shutdown(ctx: Dictionary) -> Dictionary:
	if not ProjectSettings.get_setting("terravolt_mcp/server/allow_remote_shutdown", false):
		var deny := TerraVoltErrors.json_rpc_error(
			-32600,
			"Forbidden",
			TerraVoltErrors.PROTOCOL_INVALID_PARAMS,
			"Enable terravolt_mcp/server/allow_remote_shutdown first",
			{}
		)
		return {"ok": false, "error": deny}
	var svc := server_ref.get_ref()
	if svc != null and svc.has_method("request_restart_after_shutdown_rpc"):
		svc.call(&"request_restart_after_shutdown_rpc", ctx)

	var reason := ""
	if typeof(ctx[&"params"]) == TYPE_DICTIONARY:
		reason = str((ctx[&"params"] as Dictionary).get(&"reason", ""))
	logger.log_force("warn", "lifecycle", "remote_shutdown_requested", {"peer_id": ctx["peer_id"], "reason": reason})
	return {"ok": true, "result": {"ok": true, "accepted": false, "hint": "Stop the daemon manually from the dock"}}


func _h_server_info(_ctx: Dictionary) -> Dictionary:
	var listen := "(stopped)"
	var s := server_ref.get_ref()
	if s != null and s.has_method("get_listen_label"):
		listen = str(s.call(&"get_listen_label"))
	var gv := Engine.get_version_info()
	var gv_string := gv.get(&"string", JSON.stringify(gv))
	var info := {
		"name": "terravolt-godot-mcp",
		"version": "0.1.0",
		"godot_version": gv_string,
		"addon_version": addon_version,
		"build_mode": "editor" if OS.has_feature("editor") else "runtime",
		"listen_address": listen,
		"uptime_sec": uptime_sec(),
		"supported_methods_count": _methods.size(),
		"log_path_resolved": logger.resolved_log_path_absolute(),
	}
	return {"ok": true, "result": info}


func _h_log_tail(ctx: Dictionary) -> Dictionary:
	var lines := 100
	var level := ""
	if typeof(ctx[&"params"]) == TYPE_DICTIONARY:
		var p := ctx[&"params"] as Dictionary
		if p.has(&"lines"):
			lines = int(p[&"lines"])
		if p.has(&"level"):
			level = str(p[&"level"])
	var tail := logger.tail_records(lines, level)
	return {"ok": true, "result": tail}


func _h_log_set_level(ctx: Dictionary) -> Dictionary:
	var new_lv := str((ctx[&"params"] as Dictionary)[&"level"])
	var prev := logger.get_verbosity_level()
	logger.set_verbosity(new_lv)
	logger.log_force("info", "lifecycle", "log_level_changed", {"previous": prev, "new": new_lv})
	return {"ok": true, "result": {"ok": true, "previous_level": prev, "new_level": new_lv}}
