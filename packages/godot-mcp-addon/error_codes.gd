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
const PROTOCOL_IDEMPOTENCY_CONFLICT := -33105
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
const EDITOR_NO_ACTIVE_SCENE := -33580
#endregion

#region scene
const SCENE_PATH_NOT_FOUND := -33500
const SCENE_NODE_PATH_NOT_FOUND := -33501
const SCENE_CREATE_FAILED := -33510
const SCENE_SAVE_FAILED := -33511
const NODE_TYPE_UNKNOWN := -33520
const NODE_CYCLE_DETECTED := -33521
const NODE_NAME_COLLISION := -33522
const NODE_PROPERTY_UNKNOWN := -33523
const NODE_VALUE_TYPE_MISMATCH := -33524
const SELECTOR_NO_MATCH := -33525
const NODE_SCRIPT_ALREADY_ATTACHED := -33526
const EXPRESSION_PARSE_ERROR := -33527
const EXPRESSION_EXECUTE_ERROR := -33528
const EXPRESSION_FORBIDDEN_IDENTIFIER := -33529
const SCRIPT_PATH_NOT_FOUND := -33530
const RESOURCE_DEPENDENCY_BLOCK := -33550
#endregion

#region script (task 13)
const SCRIPT_PATH_NOT_FOUND_CAT := -33600
const SCRIPT_PATH_EXISTS := -33601
const SCRIPT_PATCH_CONFLICT := -33602
const SCRIPT_DOTNET_UNAVAILABLE := -33603
const SCRIPT_VALIDATE_TIMEOUT := -33604
const SCRIPT_RENAME_CONFLICT := -33605
const SCRIPT_FORMATTER_MISSING := -33606
#endregion

#region signal (task 13)
const SIGNAL_NAME_EXISTS := -33700
const SIGNAL_UNKNOWN := -33701
const SIGNAL_TARGET_UNKNOWN := -33702
const SIGNAL_METHOD_UNKNOWN := -33703
#endregion

#region project
const PROJECT_SETTING_LOCKED := -33590
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
	PROTOCOL_IDEMPOTENCY_CONFLICT: "protocol.idempotency_conflict",
	AUTH_TOKEN_REQUIRED: "auth.token_required",
	AUTH_TOKEN_INVALID: "auth.token_invalid",
	DISPATCH_HANDLER_THREW: "dispatch.handler_threw",
	EDITOR_NOT_AVAILABLE: "editor.not_available",
	EDITOR_NO_OPEN_PROJECT: "editor.no_open_project",
	EDITOR_NO_ACTIVE_SCENE: "editor.no_active_scene",
	SCENE_PATH_NOT_FOUND: "scene.path_not_found",
	SCENE_NODE_PATH_NOT_FOUND: "scene.node_path_not_found",
	SCENE_CREATE_FAILED: "scene.create_failed",
	SCENE_SAVE_FAILED: "scene.save_failed",
	NODE_TYPE_UNKNOWN: "node.type_unknown",
	NODE_CYCLE_DETECTED: "node.cycle_detected",
	NODE_NAME_COLLISION: "node.name_collision",
	NODE_PROPERTY_UNKNOWN: "node.property_unknown",
	NODE_VALUE_TYPE_MISMATCH: "node.value_type_mismatch",
	SELECTOR_NO_MATCH: "selector.no_match",
	NODE_SCRIPT_ALREADY_ATTACHED: "node.script_already_attached",
	EXPRESSION_PARSE_ERROR: "expression.parse_error",
	EXPRESSION_EXECUTE_ERROR: "expression.execute_error",
	EXPRESSION_FORBIDDEN_IDENTIFIER: "expression.forbidden_identifier",
	SCRIPT_PATH_NOT_FOUND: "script.path_not_found",
	SCRIPT_PATH_NOT_FOUND_CAT: "script.path_not_found",
	SCRIPT_PATH_EXISTS: "script.path_exists",
	SCRIPT_PATCH_CONFLICT: "script.patch_conflict",
	SCRIPT_DOTNET_UNAVAILABLE: "script.dotnet_unavailable",
	SCRIPT_VALIDATE_TIMEOUT: "script.validate_timeout",
	SCRIPT_RENAME_CONFLICT: "script.rename_conflict",
	SCRIPT_FORMATTER_MISSING: "script.formatter_missing",
	SIGNAL_NAME_EXISTS: "signal.name_exists",
	SIGNAL_UNKNOWN: "signal.unknown",
	SIGNAL_TARGET_UNKNOWN: "signal.target_unknown",
	SIGNAL_METHOD_UNKNOWN: "signal.method_unknown",
	RESOURCE_DEPENDENCY_BLOCK: "resource.dependency_block",
	PROJECT_SETTING_LOCKED: "project.setting_locked",
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
