@tool
extends MarginContainer
class_name TerravoltStatusDock

## Bottom-panel UI for MCP transport + dispatcher (tasks 02–04).

signal restart_hint_changed(needs_restart: bool)

var plugin: EditorPlugin
var logger: TerravoltLogger
var dispatcher: TerravoltDispatcher
var server: TerravoltMCPServer

var _state_lbl: Label
var _addr_lbl: Label
var _last_lbl: Label
var _heart_lbl: Label
var _ledger: ItemList
var _ledger_rows: Array[String] = []
var _log_body: RichTextLabel


func setup(
	p_plugin: EditorPlugin,
	p_logger: TerravoltLogger,
	p_dispatcher: TerravoltDispatcher,
	p_server: TerravoltMCPServer
) -> void:
	plugin = p_plugin
	logger = p_logger
	dispatcher = p_dispatcher
	server = p_server
	_build_ui()
	if server:
		server.connection_state_changed.connect(_on_conn_state_changed)
		server.peer_connected_signal.connect(_on_peer)
		server.peer_disconnected_signal.connect(_on_peer_gone)
		server.heartbeat_pulse.connect(_on_heartbeat_pulse)
	if dispatcher:
		dispatcher.rpc_ledger_record.connect(_on_ledger_record)
	if logger:
		logger.last_line_preview.connect(_on_preview_line)


func mark_live_settings_maybe_stale() -> void:
	emit_signal(&"restart_hint_changed", server != null and server.is_running())


func bump_after_rpc_activity() -> void:
	_refresh_log_view()


func _mk_btn(lbl: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = lbl
	b.pressed.connect(cb)
	return b


func _build_ui() -> void:
	custom_minimum_size = Vector2(420, 220)
	var mv := MarginContainer.new()
	mv.add_theme_constant_override(&"margin_left", 8)
	mv.add_theme_constant_override(&"margin_right", 8)
	mv.add_theme_constant_override(&"margin_top", 6)
	mv.add_theme_constant_override(&"margin_bottom", 10)
	var tabs := TabContainer.new()
	tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	mv.add_child(tabs)
	add_child(mv)

	var stat := MarginContainer.new()
	var vbox := VBoxContainer.new()
	stat.add_child(vbox)

	_state_lbl = Label.new()
	_state_lbl.text = "State: —"
	vbox.add_child(_state_lbl)

	_addr_lbl = Label.new()
	_addr_lbl.text = "Listen: —"
	vbox.add_child(_addr_lbl)

	_last_lbl = Label.new()
	_last_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_last_lbl.text = "Last log line: —"
	vbox.add_child(_last_lbl)

	_heart_lbl = Label.new()
	_heart_lbl.text = "♥ —"
	vbox.add_child(_heart_lbl)

	var hint := Label.new()
	hint.text = "If you change WS port/bind, click Restart."
	vbox.add_child(hint)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override(&"separation", 8)
	row1.add_child(_mk_btn(&"Start", Callable(self, &"_on_start")))
	row1.add_child(_mk_btn(&"Stop", Callable(self, &"_on_stop")))
	row1.add_child(_mk_btn(&"Restart", Callable(self, &"_on_restart")))
	vbox.add_child(row1)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override(&"separation", 8)
	row2.add_child(_mk_btn(&"Open log file", Callable(self, &"_on_open_log")))
	row2.add_child(_mk_btn(&"Copy log tail", Callable(self, &"_on_copy_tail")))
	row2.add_child(_mk_btn(&"Refresh log view", Callable(self, &"_on_refresh_log")))
	vbox.add_child(row2)

	tabs.add_child(stat)
	tabs.set_tab_title(stat.get_index(), &"Status")

	_ledger = ItemList.new()
	_ledger.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(_ledger)
	tabs.set_tab_title(_ledger.get_index(), &"RPC ledger")

	_log_body = RichTextLabel.new()
	_log_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_body.scroll_active = true
	tabs.add_child(_log_body)
	tabs.set_tab_title(_log_body.get_index(), &"Log tail")

	if server:
		_on_conn_state_changed(server.connection_state_enum(), {})
	else:
		_refresh_address()


func _state_name(s: int) -> String:
	match s:
		TerravoltMCPServer.ConnState.IDLE:
			return "Idle"
		TerravoltMCPServer.ConnState.LISTENING:
			return "Listening"
		TerravoltMCPServer.ConnState.CLIENT_CONNECTED:
			return "Client connected"
		TerravoltMCPServer.ConnState.ERROR:
			return "Error"
	return "Unknown"


func _on_conn_state_changed(state: int, _details: Dictionary) -> void:
	_state_lbl.text = "State: " + _state_name(state)
	_refresh_address()


func _on_peer(_id: int, _addr: String) -> void:
	_refresh_address()


func _on_peer_gone(_id: int, _reason: String) -> void:
	_refresh_address()


func _refresh_address() -> void:
	if server == null:
		return
	_addr_lbl.text = "Listen: %s · peers %d" % [server.get_listen_label(), server.peer_count_ready()]


func _on_heartbeat_pulse(direction: String, peer_id: int) -> void:
	_heart_lbl.text = "♥ %s · peer %d" % [direction, peer_id]


func _on_ledger_record(method: String, peer_id: int, latency_ms: int, ok: bool, err_code: Variant) -> void:
	var line := "%dms #%d · %s · %s" % [latency_ms, peer_id, method, ("ok" if ok else str(err_code))]
	_ledger_rows.insert(0, line)
	if _ledger_rows.size() > 50:
		_ledger_rows.resize(50)
	_ledger.clear()
	for r in _ledger_rows:
		_ledger.add_item(r)
	bump_after_rpc_activity()


func _on_preview_line(text: String) -> void:
	var t := text
	if t.length() > 220:
		t = t.substr(0, 217) + "..."
	_last_lbl.text = "Last log line: " + t


func _refresh_log_view() -> void:
	if logger == null:
		return
	var snap := logger.tail_records(100, "")
	var acc := ""
	for ix in snap.size():
		if ix > 0:
			acc += "\n"
		acc += JSON.stringify(snap[ix])
	_log_body.text = acc


func _on_start() -> void:
	if server:
		server.start()
	_refresh_address()


func _on_stop() -> void:
	if server:
		server.stop()
	emit_signal(&"restart_hint_changed", false)
	_refresh_address()


func _on_restart() -> void:
	if server:
		server.restart()
	emit_signal(&"restart_hint_changed", false)
	_refresh_address()


func _on_open_log() -> void:
	if logger:
		OS.shell_open(logger.resolved_log_path_absolute())


func _on_copy_tail() -> void:
	if logger:
		DisplayServer.clipboard_set(logger.copy_tail_json())


func _on_refresh_log() -> void:
	_refresh_log_view()
