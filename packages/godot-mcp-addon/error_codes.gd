@tool
extends RefCounted
class_name TerraVoltErrors

## Stable TerraVolt application codes (-33000 … -33999) plus JSON-RPC helper builders.

#region transport
const TRANSPORT_BIND_FAILED := -33000
const TRANSPORT_PEER_BUSY := -33001
const TRANSPORT_HANDSHAKE_FAILED := -33002
const TRANSPORT_HEARTBEAT_TIMEOUT := -33003
const TRANSPORT_ABRUPT_CLOSE := -33004
const TRANSPORT_QUEUE_OVERFLOW := -33005
const TRANSPORT_UNSUPPORTED_FRAME := -33006
#endregion

#region protocol (app-coded JSON-RPC anomalies)
const PROTOCOL_INVALID_JSONRPC_VERSION := -33100
const PROTOCOL_METHOD_NOT_FOUND := -33101
const PROTOCOL_INVALID_PARAMS := -33102
const PROTOCOL_BATCH_TOO_LARGE := -33103
#endregion

#region auth
const AUTH_TOKEN_REQUIRED := -33200
const AUTH_TOKEN_INVALID := -33201
#endregion

#region dispatch
const DISPATCH_HANDLER_THREW := -33300
#endregion

#region editor
const EDITOR_NOT_AVAILABLE := -33400
const EDITOR_NO_OPEN_PROJECT := -33401
#endregion

static func meta_for_tv_code(tv_code: int) -> Dictionary:
	var sym := symbol_for(tv_code)
	return {"app_code": sym, "category": category_for(tv_code), "recoverable": recoverable_for(tv_code)}


static func recoverable_for(tv_code: int) -> bool:
	match tv_code:
		TRANSPORT_BIND_FAILED, TRANSPORT_HANDSHAKE_FAILED:
			return false
		_:
			return true


static func category_for(tv_code: int) -> String:
	match tv_code:
		TRANSPORT_BIND_FAILED,
		TRANSPORT_PEER_BUSY,
		TRANSPORT_HANDSHAKE_FAILED,
		TRANSPORT_HEARTBEAT_TIMEOUT,
		TRANSPORT_ABRUPT_CLOSE,
		TRANSPORT_QUEUE_OVERFLOW,
		TRANSPORT_UNSUPPORTED_FRAME:
			return "transport"
		PROTOCOL_INVALID_JSONRPC_VERSION,
		PROTOCOL_METHOD_NOT_FOUND,
		PROTOCOL_INVALID_PARAMS,
		PROTOCOL_BATCH_TOO_LARGE:
			return "protocol"
		AUTH_TOKEN_REQUIRED,
		AUTH_TOKEN_INVALID:
			return "auth"
		DISPATCH_HANDLER_THREW:
			return "dispatch"
		EDITOR_NOT_AVAILABLE,
		EDITOR_NO_OPEN_PROJECT:
			return "editor"
		_:
			return "internal"


static func symbol_for(tv_code: int) -> String:
	match tv_code:
		TRANSPORT_BIND_FAILED:
			return "transport.bind_failed"
		TRANSPORT_PEER_BUSY:
			return "transport.peer_busy"
		TRANSPORT_HANDSHAKE_FAILED:
			return "transport.handshake_failed"
		TRANSPORT_HEARTBEAT_TIMEOUT:
			return "transport.heartbeat_timeout"
		TRANSPORT_ABRUPT_CLOSE:
			return "transport.abrupt_close"
		TRANSPORT_QUEUE_OVERFLOW:
			return "transport.queue_overflow"
		TRANSPORT_UNSUPPORTED_FRAME:
			return "transport.unsupported_frame"
		PROTOCOL_INVALID_JSONRPC_VERSION:
			return "protocol.invalid_jsonrpc_version"
		PROTOCOL_METHOD_NOT_FOUND:
			return "protocol.method_not_found"
		PROTOCOL_INVALID_PARAMS:
			return "protocol.invalid_params"
		PROTOCOL_BATCH_TOO_LARGE:
			return "protocol.batch_too_large"
		AUTH_TOKEN_REQUIRED:
			return "auth.token_required"
		AUTH_TOKEN_INVALID:
			return "auth.token_invalid"
		DISPATCH_HANDLER_THREW:
			return "dispatch.handler_threw"
		EDITOR_NOT_AVAILABLE:
			return "editor.not_available"
		EDITOR_NO_OPEN_PROJECT:
			return "editor.no_open_project"
		_:
			return "internal.unexpected"


static func tv_rpc_error(tv_code: int, message: String, hint: String, context: Variant = null) -> Dictionary:
	var data: Dictionary = meta_for_tv_code(tv_code)
	data["hint"] = hint
	if context != null and typeof(context) == TYPE_DICTIONARY:
		data["context"] = context
	data["tv_code"] = tv_code
	var msg := message if message.length() > 0 else hint
	return {"code": tv_code, "message": msg, "data": data}


static func json_rpc_error(
	spec_code: int,
	message: String,
	tv_code: int,
	hint: String,
	context: Variant = null
) -> Dictionary:
	var data := meta_for_tv_code(tv_code)
	data["hint"] = hint
	if context != null and typeof(context) == TYPE_DICTIONARY:
		data["context"] = context
	data["tv_code"] = tv_code
	return {"code": spec_code, "message": message, "data": data}
