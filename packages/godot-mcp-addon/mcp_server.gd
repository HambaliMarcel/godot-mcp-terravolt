@tool
extends RefCounted
class_name TerravoltMCPServer

signal connection_state_changed(new_state: int, details: Dictionary)
signal peer_connected_signal(peer_id: int, addr: String)
signal peer_disconnected_signal(peer_id: int, reason: String)
signal heartbeat_pulse(direction: String, peer_id: int)
signal transport_diagnostic(ev: Dictionary)

enum ConnState { IDLE = 0, LISTENING = 1, CLIENT_CONNECTED = 2, ERROR = 3 }

const MAX_INBOUND_FRAMES_PER_TICK := 32
const MAX_QUEUE := 1024

var dispatcher: TerravoltDispatcher = null
var logger: TerravoltLogger = null

var _tcp := TCPServer.new()
var _running := false
var _listen_label := ""
var _conn_fsm := ConnState.IDLE
var _handshake_peers: Array = []
var _active_peer_by_id: Dictionary = {}
var _peer_seq := 1
var _heartbeat_accum := 0.0


func configure(p_dispatcher: TerravoltDispatcher, p_logger: TerravoltLogger) -> void:
	dispatcher = p_dispatcher
	logger = p_logger


func connection_state_enum() -> int:
	return _conn_fsm as int


func is_running() -> bool:
	return _running


func get_listen_label() -> String:
	return _listen_label


func peer_count_ready() -> int:
	return _active_peer_by_id.size()


func restart() -> void:
	stop()
	start()


func stop() -> void:
	if logger and _running:
		logger.log_force("info", "transport", "server_stop", {})
	for pk in _active_peer_by_id.keys():
		_close_ready(int(pk), 1001, "Server stopping")
	for h in _handshake_peers:
		var w: Variant = (h as Dictionary).get(&"ws")
		if w is WebSocketPeer:
			(w as WebSocketPeer).close(1001, "Server stopping")
	_tcp.stop()
	_handshake_peers.clear()
	_active_peer_by_id.clear()
	_running = false
	_listen_label = ""
	_heartbeat_accum = 0.0
	_set_fsm(ConnState.IDLE, {"stopped": true})


func start() -> void:
	stop()
	_heartbeat_accum = 0.0
	var port := int(ProjectSettings.get_setting("terravolt_mcp/server/port", 6505))
	var bind_s := str(ProjectSettings.get_setting("terravolt_mcp/server/bind_address", "127.0.0.1"))
	if port < 1024 or port > 65535:
		_listen_label = "(invalid-port)"
		if logger:
			logger.log_force("warn", "transport", "bind_invalid_port", {"port": port})
		_set_fsm(ConnState.ERROR, {"cause": "invalid_port"})
		return
	var err := _tcp.listen(port, bind_s)
	if err != OK:
		if logger:
			logger.log_force("error", "transport", "bind_failed", {"port": port, "bind": bind_s, "code": err})
		emit_signal(&"transport_diagnostic", {"event": "bind_failed"})
		_listen_label = "bind_failed %s:%d" % [bind_s, port]
		_set_fsm(ConnState.ERROR, {"cause": TerravoltErrors.symbol_for(TerravoltErrors.TRANSPORT_BIND_FAILED)})
		return
	_running = true
	_listen_label = "%s:%d" % [bind_s, port]
	if logger:
		logger.log_force("info", "transport", "listening", {"address": bind_s, "port": port})
	emit_signal(&"transport_diagnostic", {"event": "listen_ok", "label": _listen_label})
	_set_fsm(ConnState.LISTENING, {"label": _listen_label})


func process_tick(delta: float) -> void:
	if not _running:
		return
	while _tcp.is_connection_available():
		var tcp := _tcp.take_connection()
		var pid := _peer_seq
		_peer_seq += 1
		var ws_peer := WebSocketPeer.new()
		ws_peer.inbound_buffer_size = int(
			ProjectSettings.get_setting("terravolt_mcp/server/inbound_buffer_size", 8388608)
		)
		ws_peer.outbound_buffer_size = int(
			ProjectSettings.get_setting("terravolt_mcp/server/outbound_buffer_size", 8388608)
		)
		var a := ws_peer.accept_stream(tcp)
		var peer := {
			"id": pid,
			"ws": ws_peer,
			"tcp": tcp,
			"inbound_queue": PackedStringArray(),
			"outbound_queue": PackedStringArray(),
			"phase": &"handshake",
			"last_activity_ms": Time.get_ticks_msec(),
			"address": "%s:%s" % [tcp.get_connected_host(), str(tcp.get_connected_port())],
		}
		if a != OK:
			if logger:
				logger.log_force("error", "transport", "handshake_accept_failed", {"peer_id": pid, "code": a})
			emit_signal(&"transport_diagnostic", {"event": "handshake_failed", "peer_id": pid})
			ws_peer.close(1002, "Handshake failed")
		else:
			emit_signal(&"transport_diagnostic", {"event": "peer_accept_tcp", "peer_id": pid})
			_handshake_peers.append(peer)

	for hp in _handshake_peers.duplicate():
		_poll_peer(hp as Dictionary)
	for k in _active_peer_by_id.keys():
		if _active_peer_by_id[k] != null:
			_poll_peer((_active_peer_by_id[k]) as Dictionary)
	_drive_heartbeat(delta)


func notify_server_event(method: String, params: Variant) -> void:
	if dispatcher == null:
		return
	broadcast_raw(dispatcher.enqueue_server_notification_obj(method, params))


func broadcast_raw(text: String) -> void:

	for pk in _active_peer_by_id.keys():
		var p := _active_peer_by_id[pk] as Dictionary
		var ws_var: Variant = p.get(&"ws")
		if ws_var is WebSocketPeer:
			var wsp := ws_var as WebSocketPeer
			if wsp.get_ready_state() != WebSocketPeer.STATE_OPEN:

				continue
			_enqueue_out(p, text)


func _set_fsm(s: ConnState, details: Dictionary) -> void:
	_conn_fsm = s
	emit_signal(&"connection_state_changed", int(s), details)


func _remove_hs(peer: Dictionary) -> void:
	var ix := _handshake_peers.find(peer)
	if ix >= 0:
		_handshake_peers.remove_at(ix)


func _promote_to_ready(peer: Dictionary) -> void:
	_remove_hs(peer)
	var pid := int(peer[&"id"])
	peer[&"phase"] = &"ready"
	_active_peer_by_id[pid] = peer
	if logger:
		logger.log_force("info", "transport", "peer_ready", {"peer_id": pid, "addr": peer.get(&"address", "")})
	emit_signal(&"peer_connected_signal", pid, str(peer.get(&"address", "?")))
	emit_signal(&"transport_diagnostic", {"event": "peer_ready", "peer_id": pid})
	var hello := "{\"note\":\"terravolt_mcp_server_hello_opaque\"}"
	var ws: WebSocketPeer = peer[&"ws"] as WebSocketPeer
	var hb_ms := int(ProjectSettings.get_setting("terravolt_mcp/server/heartbeat_interval_ms", 15000))
	var hb_secs_ws: float = clampf(float(hb_ms) / 1000.0, 0.0, 86400.0)
	ws.set_heartbeat_interval(hb_secs_ws)
	ws.send_text(hello)
	_set_fsm(ConnState.CLIENT_CONNECTED, {"peer_id": pid})


func _drive_heartbeat(delta: float) -> void:
	if dispatcher == null:
		return
	var mode := str(ProjectSettings.get_setting("terravolt_mcp/server/heartbeat_mode", "control_frame"))
	var hb_secs := float(ProjectSettings.get_setting("terravolt_mcp/server/heartbeat_interval_ms", 15000)) / 1000.0
	var tout_ms := float(ProjectSettings.get_setting("terravolt_mcp/server/heartbeat_timeout_ms", 45000))
	var now_ms := Time.get_ticks_msec()
	# When using native WS ping/pong only, `last_activity_ms` tracks data frames; pruning on that
	# timer would drop quiet JSON-RPC peers. Rely on WebSocketPeer.heartbeat_interval + engine close.
	var skip_data_idle_prune := mode == "control_frame"
	_heartbeat_accum += delta

	if hb_secs <= 0.0:
		hb_secs = 999999.0

	if tout_ms <= 500.0:
		tout_ms = 45000.0

	if _active_peer_by_id.size() == 1:
		var lone: Variant = _active_peer_by_id[_active_peer_by_id.keys()[0]]
		var peer_ld := lone as Dictionary
		if "rpc" in mode or mode == "both":
			if _heartbeat_accum >= hb_secs:
				_heartbeat_accum = 0.0
				var note := dispatcher.enqueue_server_notification_obj("server.heartbeat", {"tick": now_ms})
				_enqueue_out(peer_ld, note)
				emit_signal(&"heartbeat_pulse", "out", int(peer_ld[&"id"]))

	if skip_data_idle_prune:
		return

	for kp in _active_peer_by_id.keys():
		var dp2 := (_active_peer_by_id[kp] as Dictionary)
		var last2 := float(dp2.get(&"last_activity_ms", now_ms))

		if now_ms - last2 > tout_ms:
			if logger:
				logger.log_force("warn", "transport", "heartbeat_timeout", {"peer_id": kp})
			emit_signal(&"transport_diagnostic", {"event": "heartbeat_timeout"})
			_close_ready(int(kp), 4000, "Heartbeat timeout")
func _close_ready(pid: int, code: int, reason: String) -> void:
	if not _active_peer_by_id.has(pid):
		return
	var peer: Variant = _active_peer_by_id[pid]
	var ws: Variant = (peer as Dictionary).get(&"ws")
	if ws is WebSocketPeer:
		var w := ws as WebSocketPeer
		w.close(code, reason)
	emit_signal(&"peer_disconnected_signal", pid, reason)
	_active_peer_by_id.erase(pid)
	if logger:
		logger.log_force("info", "transport", "peer_closed_by_server", {"peer_id": pid, "code": code})
	if _running and _active_peer_by_id.is_empty():
		_set_fsm(ConnState.LISTENING, {})


func _enqueue_out(peer: Dictionary, txt: String) -> void:
	var q: PackedStringArray = peer.get(&"outbound_queue", PackedStringArray())
	q = q.duplicate()
	while q.size() >= MAX_QUEUE:
		q.remove_at(0)
	q.append(txt)
	peer[&"outbound_queue"] = q


func _enqueue_in(peer: Dictionary, txt: String) -> bool:
	var q: PackedStringArray = peer.get(&"inbound_queue", PackedStringArray())
	q = q.duplicate()
	if q.size() >= MAX_QUEUE:
		if logger:
			logger.log_force("warn", "transport", "queue_overflow_drop", {"peer_id": peer.get(&"id", -1)})
		emit_signal(&"transport_diagnostic", {"code": TerravoltErrors.TRANSPORT_QUEUE_OVERFLOW})
		q.remove_at(0)
	q.append(txt)
	peer[&"inbound_queue"] = q
	return true


func _remove_dead(peer: Dictionary) -> void:
	_remove_hs(peer)
	var pid := int(peer[&"id"])
	if _active_peer_by_id.erase(pid):
		emit_signal(&"peer_disconnected_signal", pid, "closed")
	if _running and _active_peer_by_id.is_empty():
		emit_signal(&"transport_diagnostic", {"event": "all_peers_closed"})
		_set_fsm(ConnState.LISTENING, {})


func _poll_peer(peer: Dictionary) -> void:
	var ws: WebSocketPeer = peer.get(&"ws") as WebSocketPeer
	if ws == null:
		return
	ws.poll()
	var rs := ws.get_ready_state()
	if rs != WebSocketPeer.STATE_OPEN:
		if rs == WebSocketPeer.STATE_CLOSED:
			_remove_dead(peer)
		return

	var phase := peer.get(&"phase", &"handshake")
	if phase != &"ready":
		var maxp := int(ProjectSettings.get_setting("terravolt_mcp/server/max_peers", 1))
		if maxp <= 0:
			maxp = 1
		if _active_peer_by_id.size() >= maxp:
			if logger:
				logger.log_force("warn", "transport", "peer_busy", {"peer_id": peer.get(&"id", -1)})
			emit_signal(&"transport_diagnostic", {"code": TerravoltErrors.TRANSPORT_PEER_BUSY})
			emit_signal(&"peer_disconnected_signal", int(peer.get(&"id", -1)), "peer_busy")
			ws.close(1008, "policy violation: server busy")
			_remove_hs(peer)
			return
		_promote_to_ready(peer)

	var drained := 0
	while ws.get_available_packet_count() > 0 and drained < MAX_INBOUND_FRAMES_PER_TICK:
		var pkt := ws.get_packet()
		if not ws.was_string_packet():
			if logger:
				logger.log_force("warn", "transport", "binary_rejected", {"peer_id": peer.get(&"id", -1)})
			emit_signal(&"transport_diagnostic", {"code": TerravoltErrors.TRANSPORT_UNSUPPORTED_FRAME})
			if dispatcher:
				var bogus := JSON.stringify(
					{
						"jsonrpc": "2.0",
						"id": null,
						"error":
						TerravoltErrors.tv_rpc_error(
							TerravoltErrors.TRANSPORT_UNSUPPORTED_FRAME,
							"Binary unsupported",
							"Send UTF-8 JSON-RPC text frames",
							{}
						)
					}
				)
				for line in dispatcher.dispatch_peer_inbound(int(peer[&"id"]), bogus):
					_enqueue_out(peer, line)
			drained += 1
			continue

		var text := pkt.get_string_from_utf8()
		_enqueue_in(peer, text)
		peer[&"last_activity_ms"] = Time.get_ticks_msec()

		emit_signal(&"heartbeat_pulse", "in", int(peer[&"id"]))

		drained += 1

	while dispatcher != null and peer.get(&"inbound_queue", PackedStringArray()).size() > 0:

		var qtmp: PackedStringArray = peer.get(&"inbound_queue", PackedStringArray()).duplicate()

		if qtmp.size() == 0:

			break

		var frame := str(qtmp[0])

		qtmp.remove_at(0)

		peer[&"inbound_queue"] = qtmp

		for outbound in dispatcher.dispatch_peer_inbound(int(peer[&"id"]), frame):

			_enqueue_out(peer, outbound)

	var qsend: PackedStringArray = peer.get(&"outbound_queue", PackedStringArray()).duplicate()

	while qsend.size() > 0 and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:

		var pkt_out := qsend[0]

		if ws.send_text(pkt_out) != OK:

			break

		qsend.remove_at(0)

	peer[&"outbound_queue"] = qsend