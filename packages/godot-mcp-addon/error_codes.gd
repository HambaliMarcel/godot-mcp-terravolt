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

#region resource / shader (task 14)
const RESOURCE_PATH_NOT_FOUND := -33800
const RESOURCE_CLASS_UNKNOWN := -33801
const RESOURCE_PATH_EXISTS := -33802
const RESOURCE_PROPERTY_UNKNOWN := -33803
const RESOURCE_VALUE_TYPE_MISMATCH := -33804
const RESOURCE_JSON_SCHEMA_MISMATCH := -33805
const SHADER_COMPILE_TIMEOUT := -33806
const SHADER_PARAM_UNKNOWN := -33807
const SHADER_PARAM_TYPE_MISMATCH := -33808
#endregion

#region asset / batch_refactor (task 15)
const ASSET_IMPORT_TIMEOUT := -33900
const ASSET_UNKNOWN_SETTING := -33901
const ASSET_TOO_LARGE := -33902
const ASSET_PATH_EXISTS := -33903
const ASSET_PRESET_UNKNOWN := -33904
const BATCH_CONFIRM_MISMATCH := -33910
const BATCH_PARTIAL_FAILURE := -33911
const BATCH_TOO_MANY_EDITS := -33912
const BATCH_INCOMPATIBLE_CLASSES := -33913
#endregion

#region editor / analysis (task 16)
const EDITOR_SCREENSHOT_TOO_LARGE := -33920
const EDITOR_SCRIPT_TIMEOUT := -33921
const EDITOR_SCRIPT_FORBIDDEN_API := -33922
const EDITOR_UNSUPPORTED_IN_VERSION := -33923
#endregion

#region runtime (task 17)
const RUNTIME_NO_SESSION := -33930
const RUNTIME_BRIDGE_UNAVAILABLE := -33931
const RUNTIME_UI_NOT_FOUND := -33932
const RUNTIME_NAVIGATE_TIMEOUT := -33933
const RUNTIME_GAME_PAUSED := -33934
const RUNTIME_BRIDGE_RPC_FAILED := -33935
const RUNTIME_SPAWN_FAILED := -33936
const RUNTIME_HANDSHAKE_FAILED := -33937
const RUNTIME_RECORDING_NOT_ACTIVE := -33938
const RUNTIME_BUFFER_NOT_FOUND := -33939
#endregion

#region animation / animation_tree (task 18)
const ANIMATION_NAME_EXISTS := -33940
const ANIMATION_UNKNOWN := -33941
const ANIMATION_TRACK_KIND_UNKNOWN := -33942
const ANIMATION_EXPORTER_MISSING := -33943
const ANIMATION_PLAYER_NOT_FOUND := -33944
const ANIMATION_TREE_PARAMETER_UNKNOWN := -33945
const ANIMATION_TREE_STATE_EXISTS := -33946
const ANIMATION_TREE_STATE_UNKNOWN := -33947
const ANIMATION_TREE_NOT_FOUND := -33948
const ANIMATION_TREE_TRANSITION_UNKNOWN := -33949
#endregion

#region physics / particle / navigation (task 19)
const PHYSICS_SHAPE_KIND_UNKNOWN := -33950
const PHYSICS_DIMENSION_MISMATCH := -33951
const PHYSICS_BATCH_TOO_LARGE := -33952
const PARTICLE_GPU_UNSUPPORTED := -33953
const NAVIGATION_BAKE_TIMEOUT := -33954
#endregion

#region tilemap / theme_ui (task 20)
const TILEMAP_CELL_BATCH_TOO_LARGE := -33960
const TILEMAP_ATLAS_UNKNOWN := -33961
const TILEMAP_TERRAIN_UNKNOWN := -33962
const TILEMAP_LAYER_UNKNOWN := -33963
const TILEMAP_NODE_INVALID := -33964
const THEME_TARGET_MISSING := -33965
const THEME_PROPERTY_UNKNOWN := -33966
const THEME_STYLEBOX_INVALID := -33967
const THEME_FONT_LOAD_FAILED := -33968
const THEME_PREVIEW_FAILED := -33969
#endregion

#region audio / input (task 21)
const AUDIO_BUS_NAME_EXISTS := -33970
const AUDIO_BUS_UNKNOWN := -33971
const AUDIO_CANNOT_REMOVE_MASTER := -33972
const AUDIO_EFFECT_KIND_UNKNOWN := -33973
const AUDIO_PREVIEW_UNAVAILABLE := -33974
const INPUT_ACTION_EXISTS := -33975
const INPUT_ACTION_NAME_INVALID := -33976
const INPUT_ACTION_UNKNOWN := -33977
#endregion

#region scene_3d (task 22)
const SCENE_3D_PRIMITIVE_UNKNOWN := -33980
const SCENE_3D_MESH_LIBRARY_UNKNOWN := -33981
const SCENE_3D_GRIDMAP_CELLS_INVALID := -33982
#endregion

#region testing / profile / export (task 23)
const TESTING_FRAMEWORK_UNKNOWN := -33990
const TESTING_TIMEOUT := -33991
const TESTING_GOLDEN_NOT_FOUND := -33992
const PROFILE_FLAMEGRAPH_UNAVAILABLE := -33993
const EXPORT_PRESET_UNKNOWN := -33994
const EXPORT_TEMPLATE_MISSING := -33995
const EXPORT_TIMEOUT := -33996
#endregion

#region macro (task 24)
const MACRO_NOT_IMPLEMENTED := -34000
const MACRO_OPS_LIMIT := -34001
const MACRO_SCENE_REQUIRED := -34002
const MACRO_FILE_EXISTS := -34003
const MACRO_TEMPLATE_MISSING := -34004
const MACRO_HIGH_RISK := -34005
const MACRO_APPLY_FAILED := -34006
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
	RESOURCE_PATH_NOT_FOUND: "resource.path_not_found",
	RESOURCE_CLASS_UNKNOWN: "resource.class_unknown",
	RESOURCE_PATH_EXISTS: "resource.path_exists",
	RESOURCE_PROPERTY_UNKNOWN: "resource.property_unknown",
	RESOURCE_VALUE_TYPE_MISMATCH: "resource.value_type_mismatch",
	RESOURCE_JSON_SCHEMA_MISMATCH: "resource.json_schema_mismatch",
	SHADER_COMPILE_TIMEOUT: "shader.compile_timeout",
	SHADER_PARAM_UNKNOWN: "shader.param_unknown",
	SHADER_PARAM_TYPE_MISMATCH: "shader.param_type_mismatch",
	ASSET_IMPORT_TIMEOUT: "asset.import_timeout",
	ASSET_UNKNOWN_SETTING: "asset.unknown_setting",
	ASSET_TOO_LARGE: "asset.too_large",
	ASSET_PATH_EXISTS: "asset.path_exists",
	ASSET_PRESET_UNKNOWN: "asset.preset_unknown",
	BATCH_CONFIRM_MISMATCH: "batch.confirm_mismatch",
	BATCH_PARTIAL_FAILURE: "batch.partial_failure",
	BATCH_TOO_MANY_EDITS: "batch.too_many_edits",
	BATCH_INCOMPATIBLE_CLASSES: "batch.incompatible_classes",
	EDITOR_SCREENSHOT_TOO_LARGE: "editor.screenshot_too_large",
	EDITOR_SCRIPT_TIMEOUT: "editor.script_timeout",
	EDITOR_SCRIPT_FORBIDDEN_API: "editor.script_forbidden_api",
	EDITOR_UNSUPPORTED_IN_VERSION: "editor.unsupported_in_version",
	RUNTIME_NO_SESSION: "runtime.no_session",
	RUNTIME_BRIDGE_UNAVAILABLE: "runtime.bridge_unavailable",
	RUNTIME_UI_NOT_FOUND: "runtime.ui_not_found",
	RUNTIME_NAVIGATE_TIMEOUT: "runtime.navigate_timeout",
	RUNTIME_GAME_PAUSED: "runtime.game_paused",
	RUNTIME_BRIDGE_RPC_FAILED: "runtime.bridge_rpc_failed",
	RUNTIME_SPAWN_FAILED: "runtime.spawn_failed",
	RUNTIME_HANDSHAKE_FAILED: "runtime.handshake_failed",
	RUNTIME_RECORDING_NOT_ACTIVE: "runtime.recording_not_active",
	RUNTIME_BUFFER_NOT_FOUND: "runtime.buffer_not_found",
	ANIMATION_NAME_EXISTS: "animation.name_exists",
	ANIMATION_UNKNOWN: "animation.unknown",
	ANIMATION_TRACK_KIND_UNKNOWN: "animation.track_kind_unknown",
	ANIMATION_EXPORTER_MISSING: "animation.exporter_missing",
	ANIMATION_PLAYER_NOT_FOUND: "animation.player_not_found",
	ANIMATION_TREE_PARAMETER_UNKNOWN: "animation_tree.parameter_unknown",
	ANIMATION_TREE_STATE_EXISTS: "animation_tree.state_exists",
	ANIMATION_TREE_STATE_UNKNOWN: "animation_tree.state_unknown",
	ANIMATION_TREE_NOT_FOUND: "animation_tree.not_found",
	ANIMATION_TREE_TRANSITION_UNKNOWN: "animation_tree.transition_unknown",
	PHYSICS_SHAPE_KIND_UNKNOWN: "physics.shape_kind_unknown",
	PHYSICS_DIMENSION_MISMATCH: "physics.dimension_mismatch",
	PHYSICS_BATCH_TOO_LARGE: "physics.batch_too_large",
	PARTICLE_GPU_UNSUPPORTED: "particle.gpu_unsupported",
	NAVIGATION_BAKE_TIMEOUT: "navigation.bake_timeout",
	TILEMAP_CELL_BATCH_TOO_LARGE: "tilemap.cell_batch_too_large",
	TILEMAP_ATLAS_UNKNOWN: "tilemap.atlas_unknown",
	TILEMAP_TERRAIN_UNKNOWN: "tilemap.terrain_unknown",
	TILEMAP_LAYER_UNKNOWN: "tilemap.layer_unknown",
	TILEMAP_NODE_INVALID: "tilemap.node_invalid",
	THEME_TARGET_MISSING: "theme.target_missing",
	THEME_PROPERTY_UNKNOWN: "theme.property_unknown",
	THEME_STYLEBOX_INVALID: "theme.stylebox_invalid",
	THEME_FONT_LOAD_FAILED: "theme.font_load_failed",
	THEME_PREVIEW_FAILED: "theme.preview_failed",
	AUDIO_BUS_NAME_EXISTS: "audio.bus_name_exists",
	AUDIO_BUS_UNKNOWN: "audio.bus_unknown",
	AUDIO_CANNOT_REMOVE_MASTER: "audio.cannot_remove_master",
	AUDIO_EFFECT_KIND_UNKNOWN: "audio.effect_kind_unknown",
	AUDIO_PREVIEW_UNAVAILABLE: "audio.preview_unavailable",
	INPUT_ACTION_EXISTS: "input.action_exists",
	INPUT_ACTION_NAME_INVALID: "input.action_name_invalid",
	INPUT_ACTION_UNKNOWN: "input.action_unknown",
	SCENE_3D_PRIMITIVE_UNKNOWN: "scene_3d.primitive_unknown",
	SCENE_3D_MESH_LIBRARY_UNKNOWN: "scene_3d.mesh_library_unknown",
	SCENE_3D_GRIDMAP_CELLS_INVALID: "scene_3d.gridmap_cells_invalid",
	TESTING_FRAMEWORK_UNKNOWN: "testing.framework_unknown",
	TESTING_TIMEOUT: "testing.timeout",
	TESTING_GOLDEN_NOT_FOUND: "testing.golden_not_found",
	PROFILE_FLAMEGRAPH_UNAVAILABLE: "profile.flamegraph_unavailable",
	EXPORT_PRESET_UNKNOWN: "export.preset_unknown",
	EXPORT_TEMPLATE_MISSING: "export.template_missing",
	EXPORT_TIMEOUT: "export.timeout",
	MACRO_NOT_IMPLEMENTED: "macro.not_implemented",
	MACRO_OPS_LIMIT: "macro.ops_limit",
	MACRO_SCENE_REQUIRED: "macro.scene_required",
	MACRO_FILE_EXISTS: "macro.file_exists",
	MACRO_TEMPLATE_MISSING: "macro.template_missing",
	MACRO_HIGH_RISK: "macro.high_risk",
	MACRO_APPLY_FAILED: "macro.apply_failed",
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
