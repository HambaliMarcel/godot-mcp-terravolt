@tool
extends EditorPlugin

## Terravolt MCP — Phase 1 addon (tasks 02–04).

const ADDON_VERSION := "0.1.0"

const _StatusDockScr = preload("./editor_ui/status_dock.gd")

var _logger: TerravoltLogger = null
var _dispatcher: TerravoltDispatcher = null
var _server: TerravoltMCPServer = null
var _dock: MarginContainer = null

var _tree_budget_ms: int = -1_000_000
# Latched true when the loaded TerravoltMCPServer class is missing methods this
# build expects (e.g. a stale `addons/terravolt_mcp/` copy from `addon:link`
# fallback). We stop polling and surface ONE clear error instead of spamming
# `process_tick` 3000+ times per second.
var _server_api_stale := false


func _enter_tree() -> void:
	_define_settings()
	_logger = TerravoltLogger.new()
	_logger.addon_version_string = ADDON_VERSION
	_logger.configure_from_project()
	_logger.log_info("Terravolt MCP addon entered tree", {})

	_dispatcher = TerravoltDispatcher.new()
	_server = TerravoltMCPServer.new()
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
	var editor_handlers := preload("./handlers/editor.gd").new()
	editor_handlers.attach(_dispatcher, _logger)
	var analysis_handlers := preload("./handlers/analysis.gd").new()
	analysis_handlers.attach(_dispatcher, _logger)
	var animation_handlers := preload("./handlers/animation.gd").new()
	animation_handlers.attach(_dispatcher, _logger)
	var animation_tree_handlers := preload("./handlers/animation_tree.gd").new()
	animation_tree_handlers.attach(_dispatcher, _logger)
	var physics_handlers := preload("./handlers/physics.gd").new()
	physics_handlers.attach(_dispatcher, _logger)
	var particle_handlers := preload("./handlers/particle.gd").new()
	particle_handlers.attach(_dispatcher, _logger)
	var navigation_handlers := preload("./handlers/navigation.gd").new()
	navigation_handlers.attach(_dispatcher, _logger)
	var runtime_handlers := preload("./handlers/runtime.gd").new()
	runtime_handlers.attach(_dispatcher, _logger)
	var tilemap_handlers := preload("./handlers/tilemap.gd").new()
	tilemap_handlers.attach(_dispatcher, _logger)
	var theme_ui_handlers := preload("./handlers/theme_ui.gd").new()
	theme_ui_handlers.attach(_dispatcher, _logger)
	var scene_3d_handlers := preload("./handlers/scene_3d.gd").new()
	scene_3d_handlers.attach(_dispatcher, _logger)
	var testing_handlers := preload("./handlers/testing.gd").new()
	testing_handlers.attach(_dispatcher, _logger)
	var profile_handlers := preload("./handlers/profile.gd").new()
	profile_handlers.attach(_dispatcher, _logger)
	var export_handlers := preload("./handlers/export.gd").new()
	export_handlers.attach(_dispatcher, _logger)
	var macro_handlers := preload("./handlers/macro.gd").new()
	macro_handlers.attach(_dispatcher, _logger)
	var audio_handlers := preload("./handlers/audio.gd").new()
	audio_handlers.attach(_dispatcher, _logger)
	var input_handlers := preload("./handlers/input.gd").new()
	input_handlers.attach(_dispatcher, _logger)
	var android_handlers := preload("./handlers/android.gd").new()
	android_handlers.attach(_dispatcher, _logger)

	_install_runtime_bridge_autoload()

	_dock = _StatusDockScr.new()
	_dock.name = "TerravoltMCPStatus"
	(_dock as TerravoltStatusDock).setup(self, _logger, _dispatcher, _server)
	add_control_to_bottom_panel(_dock, "Terravolt MCP")

	var base := get_editor_interface().get_base_control()
	if base and base.get_tree():
		if not base.get_tree().tree_changed.is_connected(_on_editor_tree_changed):

			base.get_tree().tree_changed.connect(_on_editor_tree_changed)

	if not ProjectSettings.settings_changed.is_connected(_on_settings_changed):
		ProjectSettings.settings_changed.connect(_on_settings_changed)

	set_process(true)

	if ProjectSettings.get_setting("terravolt_mcp/server/auto_start_on_open", true):
		if _server.has_method(&"start"):
			_server.start()
		else:
			_flag_server_api_stale("start")


func _exit_tree() -> void:
	_remove_runtime_bridge_autoload()
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
		_logger.log_info("Terravolt MCP addon exited tree", {})
	if _server and _server.has_method(&"stop"):
		_server.stop()
	_server = null
	_dispatcher = null
	_logger = null


func _process(delta: float) -> void:
	if _server_api_stale or _server == null:
		return
	if not _server.has_method(&"process_tick"):
		_flag_server_api_stale("process_tick")
		return
	_server.process_tick(delta)


# Surfaces a stale-addon mismatch ONCE and then disables polling so the user
# isn't drowned in identical errors. The most common cause is `addon:link`
# falling back to a plain copy on Windows (no symlink permission) and the
# project still holding the older copy.
func _flag_server_api_stale(missing: String) -> void:
	if _server_api_stale:
		return
	_server_api_stale = true
	set_process(false)
	var msg := (
		"Terravolt addon: loaded TerravoltMCPServer is missing `%s`. "
		+ "Your `addons/terravolt_mcp/` copy is stale. "
		+ "Re-run `npm run addon:link -- --force` (or replace the folder) and "
		+ "then Project → Reload Current Project."
	) % missing
	push_error(msg)
	if _logger:
		_logger.log_force(
			"error",
			"addon",
			"stale_addon_copy",
			{"missing_method": missing, "hint": "addon:link --force then reload project"}
		)


func _on_settings_changed() -> void:
	if _logger:
		_logger.configure_from_project()

	if _dock and (_dock as TerravoltStatusDock).has_method(&"mark_live_settings_maybe_stale"):

		(_dock as TerravoltStatusDock).mark_live_settings_maybe_stale()



func _on_editor_tree_changed() -> void:

	var now := Time.get_ticks_msec()
	if now - _tree_budget_ms < 150:

		return
	_tree_budget_ms = now

	if _server_api_stale or _server == null:
		return
	if not _server.has_method(&"peer_count_ready") or not _server.has_method(&"notify_server_event"):
		_flag_server_api_stale("peer_count_ready/notify_server_event")
		return
	if _server.peer_count_ready() > 0:
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

	# Default bumped to 2 so a Cursor MCP client can coexist with a debug script,
	# OR a fresh Cursor reconnect can take over without waiting for the prior
	# socket to drain. Single-peer mode is still available by overriding to 1.
	_set_def("terravolt_mcp/server/max_peers", 2)

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

	_set_def("terravolt_mcp/runtime/port", 6506)
	_info("terravolt_mcp/runtime/port", TYPE_INT, PROPERTY_HINT_RANGE, "1024,65535,1")

	_info("terravolt_mcp/server/auto_start_on_open", TYPE_BOOL)
	_info("terravolt_mcp/server/bind_address", TYPE_STRING)
	_info("terravolt_mcp/logging/path", TYPE_STRING)
	_info("terravolt_mcp/logging/level", TYPE_STRING)
	_info("terravolt_mcp/server/heartbeat_mode", TYPE_STRING)


func restart() -> void:
	if _server:
		_server.restart()


func _runtime_bridge_script_path() -> String:
	return get_script().resource_path.get_base_dir().path_join("autoloads/runtime_bridge.gd")


func _install_runtime_bridge_autoload() -> void:
	var path := _runtime_bridge_script_path()
	if not FileAccess.file_exists(path):
		return
	if ProjectSettings.has_setting("autoload/TerravoltRuntimeBridge"):
		return
	add_autoload_singleton("TerravoltRuntimeBridge", path)


func _remove_runtime_bridge_autoload() -> void:
	if ProjectSettings.has_setting("autoload/TerravoltRuntimeBridge"):
		remove_autoload_singleton("TerravoltRuntimeBridge")
