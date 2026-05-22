extends RefCounted
class_name TerraVoltRuntimeSession

## Tracks an active playmode or headless game subprocess (task 17).

static var alive: bool = false
static var pid: int = -1
static var bridge_port: int = 6506
static var mode: String = ""
static var started_at_ms: int = 0
static var scene_path: String = ""


static func reset() -> void:
	alive = false
	pid = -1
	bridge_port = 6506
	mode = ""
	started_at_ms = 0
	scene_path = ""


static func mark_active(p_mode: String, p_pid: int, p_port: int, p_scene: String = "") -> void:
	alive = true
	mode = p_mode
	pid = p_pid
	bridge_port = p_port
	started_at_ms = Time.get_ticks_msec()
	scene_path = p_scene


static func uptime_ms() -> int:
	if not alive or started_at_ms <= 0:
		return 0
	return Time.get_ticks_msec() - started_at_ms


static func session_dict() -> Dictionary:
	return {
		"alive": alive,
		"pid": pid if pid > 0 else null,
		"bridge_port": bridge_port if alive else null,
		"mode": mode if not mode.is_empty() else null,
		"uptime_ms": uptime_ms() if alive else null,
		"scene": scene_path if not scene_path.is_empty() else null,
	}


static func default_bridge_port() -> int:
	var env := OS.get_environment("TERRAVOLT_RUNTIME_PORT")
	if not env.is_empty() and env.is_valid_int():
		return int(env)
	if ProjectSettings.has_setting("terravolt_mcp/runtime/port"):
		return int(ProjectSettings.get_setting("terravolt_mcp/runtime/port"))
	return 6506
