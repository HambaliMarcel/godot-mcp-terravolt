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
const PROTOCOL_CATALOG_MISMATCH := -33104
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

#region headless (mirror packages/shared/errors/registry.json + docs/tasklist/07)
const HEADLESS_BINARY_MISSING := -33810
const HEADLESS_NO_PROJECT := -33811
const HEADLESS_SPAWN_FAILED := -33812
const HEADLESS_DRIVER_HANDSHAKE_FAILED := -33813
const HEADLESS_SESSION_BUSY := -33814
const HEADLESS_CRASHED := -33815
const HEADLESS_TIMEOUT := -33816
const HEADLESS_DISALLOWED := -33817
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


## Single canonical mapping (Dictionary keeps Godot's `match` parser happy and
## makes future code additions a one-line change instead of two `match` arms).
const _CODE_TO_SYMBOL := {
	TRANSPORT_BIND_FAILED: "transport.bind_failed",
	TRANSPORT_PEER_BUSY: "transport.peer_busy",
	TRANSPORT_HANDSHAKE_FAILED: "transport.handshake_failed",
	TRANSPORT_HEARTBEAT_TIMEOUT: "transport.heartbeat_timeout",
	TRANSPORT_ABRUPT_CLOSE: "transport.abrupt_close",
	TRANSPORT_QUEUE_OVERFLOW: "transport.queue_overflow",
	TRANSPORT_UNSUPPORTED_FRAME: "transport.unsupported_frame",
	PROTOCOL_INVALID_JSONRPC_VERSION: "protocol.invalid_jsonrpc_version",
	PROTOCOL_METHOD_NOT_FOUND: "protocol.method_not_found",
	PROTOCOL_INVALID_PARAMS: "protocol.invalid_params",
	PROTOCOL_BATCH_TOO_LARGE: "protocol.batch_too_large",
	PROTOCOL_CATALOG_MISMATCH: "protocol.catalog_mismatch",
	AUTH_TOKEN_REQUIRED: "auth.token_required",
	AUTH_TOKEN_INVALID: "auth.token_invalid",
	DISPATCH_HANDLER_THREW: "dispatch.handler_threw",
	EDITOR_NOT_AVAILABLE: "editor.not_available",
	EDITOR_NO_OPEN_PROJECT: "editor.no_open_project",
	HEADLESS_BINARY_MISSING: "headless.binary_missing",
	HEADLESS_NO_PROJECT: "headless.no_project",
	HEADLESS_SPAWN_FAILED: "headless.spawn_failed",
	HEADLESS_DRIVER_HANDSHAKE_FAILED: "headless.driver_handshake_failed",
	HEADLESS_SESSION_BUSY: "headless.session_busy",
	HEADLESS_CRASHED: "headless.crashed",
	HEADLESS_TIMEOUT: "headless.timeout",
	HEADLESS_DISALLOWED: "headless.disallowed",
}


static func category_for(tv_code: int) -> String:
	var sym: String = _CODE_TO_SYMBOL.get(tv_code, "internal.unexpected")
	var dot := sym.find(".")
	return sym.substr(0, dot) if dot > 0 else "internal"


static func symbol_for(tv_code: int) -> String:
	return _CODE_TO_SYMBOL.get(tv_code, "internal.unexpected")


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
