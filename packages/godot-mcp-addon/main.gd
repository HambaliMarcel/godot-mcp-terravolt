@tool
extends EditorPlugin

## TerraVolt MCP — Phase 1 addon (tasks 02–04).

const ADDON_VERSION := "0.1.0"

const _StatusDockScr = preload("./editor_ui/status_dock.gd")

var _logger: TerraVoltLogger = null
var _dispatcher: TerraVoltDispatcher = null
var _server: TerraVoltMCPServer = null
var _dock: MarginContainer = null

var _tree_budget_ms: int = -1_000_000


func _enter_tree() -> void:
	_define_settings()
	_logger = TerraVoltLogger.new()
	_logger.addon_version_string = ADDON_VERSION
	_logger.configure_from_project()
	_logger.log_info("TerraVolt MCP addon entered tree", {})

	_dispatcher = TerraVoltDispatcher.new()
	_server = TerraVoltMCPServer.new()
	_server.configure(_dispatcher, _logger)
	_dispatcher.configure(_logger, _server, self, ADDON_VERSION)

	var scene_handlers := preload("./handlers/scene.gd").new()
	scene_handlers.attach(_dispatcher, _logger)
	var project_handlers := preload("./handlers/project.gd").new()
	project_handlers.attach(_dispatcher, _logger)
	var node_handlers := preload("./handlers/node.gd").new()
	node_handlers.attach(_dispatcher, _logger)
	var script_handlers := preload("./handlers/script.gd").new()
	script_handlers.attach(_dispatcher, _logger)
	var signal_handlers := preload("./handlers/signal.gd").new()
	signal_handlers.attach(_dispatcher, _logger)
	var resource_handlers := preload("./handlers/resource.gd").new()
	resource_handlers.attach(_dispatcher, _logger)
	var shader_handlers := preload("./handlers/shader.gd").new()
	shader_handlers.attach(_dispatcher, _logger)
	var asset_handlers := preload("./handlers/asset.gd").new()
	asset_handlers.attach(_dispatcher, _logger)
	var batch_handlers := preload("./handlers/batch_refactor.gd").new()
	batch_handlers.attach(_dispatcher, _logger)

	_dock = _StatusDockScr.new()
	_dock.name = "TerraVoltMCPStatus"
	(_dock as TerraVoltStatusDock).setup(self, _logger, _dispatcher, _server)
	add_control_to_bottom_panel(_dock, "TerraVolt MCP")

	var base := get_editor_interface().get_base_control()
	if base and base.get_tree():
		if not base.get_tree().tree_changed.is_connected(_on_editor_tree_changed):

			base.get_tree().tree_changed.connect(_on_editor_tree_changed)

	if not ProjectSettings.settings_changed.is_connected(_on_settings_changed):
		ProjectSettings.settings_changed.connect(_on_settings_changed)

	set_process(true)

	if ProjectSettings.get_setting("terravolt_mcp/server/auto_start_on_open", true):

		_server.start()


func _exit_tree() -> void:
	set_process(false)
	var base := get_editor_interface().get_base_control()

	if base and base.get_tree():

		if base.get_tree().tree_changed.is_connected(_on_editor_tree_changed):

			base.get_tree().tree_changed.disconnect(_on_editor_tree_changed)

	if ProjectSettings.settings_changed.is_connected(_on_settings_changed):
		ProjectSettings.settings_changed.disconnect(_on_settings_changed)

	if _dock:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()
		_dock = null

	if _logger:
		_logger.log_info("TerraVolt MCP addon exited tree", {})
	if _server:

		_server.stop()
	_server = null
	_dispatcher = null
	_logger = null


func _process(delta: float) -> void:

	if _server:
		_server.process_tick(delta)



func _on_settings_changed() -> void:
	if _logger:
		_logger.configure_from_project()

	if _dock and (_dock as TerraVoltStatusDock).has_method(&"mark_live_settings_maybe_stale"):

		(_dock as TerraVoltStatusDock).mark_live_settings_maybe_stale()



func _on_editor_tree_changed() -> void:

	var now := Time.get_ticks_msec()
	if now - _tree_budget_ms < 150:

		return
	_tree_budget_ms = now

	if _server and _server.peer_count_ready() > 0:

		_server.notify_server_event("event.runtime.tree_changed", {"source": "SceneTree"})



func _set_def(path: String, value: Variant) -> void:
	if not ProjectSettings.has_setting(path):
		ProjectSettings.set_setting(path, value)


func _info(path: String, type_c: int, hint: int = PROPERTY_HINT_NONE, hint_s: String = "") -> void:
	var d := {"name": path, "type": type_c}
	if hint != PROPERTY_HINT_NONE:
		d["hint"] = hint
	if hint_s.length() > 0:
		d["hint_string"] = hint_s
	ProjectSettings.add_property_info(d)


func _define_settings() -> void:
	_set_def("terravolt_mcp/server/port", 6505)
	_info("terravolt_mcp/server/port", TYPE_INT, PROPERTY_HINT_RANGE, "1024,65535,1")

	_set_def("terravolt_mcp/server/bind_address", "127.0.0.1")

	_set_def("terravolt_mcp/server/auto_start_on_open", true)
	_set_def("terravolt_mcp/server/heartbeat_interval_ms", 15000)
	_set_def("terravolt_mcp/server/heartbeat_timeout_ms", 45000)
	_set_def("terravolt_mcp/server/heartbeat_mode", "control_frame")

	_set_def("terravolt_mcp/server/max_peers", 1)

	_set_def("terravolt_mcp/server/max_frame_bytes", 4194304)

	_set_def("terravolt_mcp/server/inbound_buffer_size", 8388608)

	_set_def("terravolt_mcp/server/outbound_buffer_size", 8388608)

	_set_def("terravolt_mcp/server/allow_remote_shutdown", false)

	_set_def("terravolt_mcp/protocol/batch_max_size", 50)

	_set_def("terravolt_mcp/logging/path", "user://mcp_log.txt")
	_set_def("terravolt_mcp/logging/level", "info")
	_set_def("terravolt_mcp/logging/rotate_size_kb", 5120)
	_set_def("terravolt_mcp/logging/max_archives", 5)

	_set_def("terravolt_mcp/security/require_token", false)
	_set_def("terravolt_mcp/security/token", "")

	_set_def("terravolt_mcp/context/max_tree_nodes", 5000)
	_set_def("terravolt_mcp/context/max_payload_kb", 4096)

	_info("terravolt_mcp/server/auto_start_on_open", TYPE_BOOL)
	_info("terravolt_mcp/server/bind_address", TYPE_STRING)
	_info("terravolt_mcp/logging/path", TYPE_STRING)
	_info("terravolt_mcp/logging/level", TYPE_STRING)
	_info("terravolt_mcp/server/heartbeat_mode", TYPE_STRING)


func restart() -> void:
	if _server:
		_server.restart()
