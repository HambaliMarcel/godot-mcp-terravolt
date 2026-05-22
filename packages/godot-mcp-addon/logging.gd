@tool
extends RefCounted
class_name TerraVoltLogger

## Structured JSON-lines logger with ring buffer + rotation.

signal last_line_preview(line: String)
signal verbosity_changed(level: String)

var addon_version_string: String = "0.1.0"
var _ring: Array = []
var _ring_max: int = 500
var _min_level_rank: int = 1

const FEATURE_WHITELIST := ["editor", "template", "release", "debug", "pc", "mobile", "web", "wasm"]


func _rank(level: String) -> int:
	match level:
		"debug":
			return 0
		"info":
			return 1
		"warn":
			return 2
		"error":
			return 3
		_:
			return 1


func configure_from_project() -> void:
	var lv := str(ProjectSettings.get_setting("terravolt_mcp/logging/level", "info"))
	set_verbosity(lv)


func set_verbosity(level: String) -> void:
	if level.is_empty():
		level = "info"
	_min_level_rank = _rank(level)
	emit_signal(&"verbosity_changed", level)


func get_verbosity_level() -> String:
	return _verbosity_name()


func _verbosity_name() -> String:
	match _min_level_rank:
		0:
			return "debug"
		1:
			return "info"
		2:
			return "warn"
		_:
			return "error"


func log_editor(level: String, subsystem: String, event: String, fields: Dictionary = {}) -> void:
	if not _should_emit(level):
		return
	_write_record(level, subsystem, event, fields)


func log_info(message: String, fields: Dictionary = {}) -> void:
	var f := fields.duplicate()
	f["message"] = message
	log_editor("info", "lifecycle", "message", f)


func log_warn(message: String, fields: Dictionary = {}) -> void:
	var f := fields.duplicate()
	f["message"] = message
	log_editor("warn", "lifecycle", "message", f)


func log_error(message: String, fields: Dictionary = {}) -> void:
	var f := fields.duplicate()
	f["message"] = message
	log_editor("error", "lifecycle", "message", f)


func log_force(level: String, subsystem: String, event: String, fields: Dictionary = {}) -> void:
	_write_record(level, subsystem, event, fields)


func _should_emit(level: String) -> bool:
	return _rank(level) >= _min_level_rank


func _feature_tags_filtered() -> Array[String]:
	var out: Array[String] = []
	for nm in FEATURE_WHITELIST:
		if OS.has_feature(nm):
			out.append(nm)
	return out


func _write_record(level: String, subsystem: String, event: String, fields: Dictionary) -> void:
	var iso := Time.get_datetime_dict_from_system()
	var frac := Time.get_ticks_msec() % 1000
	var iso_str := "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ" % [
		iso.year,
		iso.month,
		iso.day,
		iso.hour,
		iso.minute,
		iso.second,
		frac
	]

	var vi := Engine.get_version_info()

	var rec := {
		"ts": iso_str,
		"level": level,
		"subsystem": subsystem,
		"event": event,
		"addon_version": addon_version_string,
		"godot_version": str(vi.get(&"string", "?")),
		"pid": OS.get_process_id(),
		"feature_tags": _feature_tags_filtered(),
	}
	for k in fields.keys():
		rec[k] = fields[k]

	_append_ring(rec)
	var line := JSON.stringify(rec)
	emit_signal(&"last_line_preview", "[%s] %s %s" % [level, subsystem, event])
	_try_write_line(line)


func tail_records(max_lines: int = 100, level_filter: String = "") -> Array:
	var rank_cut := _rank(level_filter) if not level_filter.is_empty() else 0
	var out: Array = []
	var i := _ring.size() - 1
	while i >= 0 and out.size() < max_lines:
		var row: Variant = _ring[i]
		if typeof(row) == TYPE_DICTIONARY:
			var d := row as Dictionary
			if level_filter.is_empty() or _rank(str(d.get(&"level", "info"))) >= rank_cut:
				out.append(d)
		i -= 1
	return out


func copy_tail_json(max_chars: int = 32000) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var used := 0
	var idx := _ring.size() - 1
	while idx >= 0 and used < max_chars:
		var js := JSON.stringify(_ring[idx])
		if used + js.length() + 1 >= max_chars:
			break
		parts.insert(0, js)
		used += js.length() + 1
		idx -= 1
	return "\n".join(parts)


func _append_ring(rec: Dictionary) -> void:
	_ring.append(rec)
	while _ring.size() > _ring_max:
		_ring.pop_front()


func resolved_log_path_absolute() -> String:
	var lp := str(ProjectSettings.get_setting("terravolt_mcp/logging/path", "user://mcp_log.txt"))
	return ProjectSettings.globalize_path(lp)


func _rotate_if_needed(abs_path: String) -> void:
	var max_kb := int(ProjectSettings.get_setting("terravolt_mcp/logging/rotate_size_kb", 5120))
	var max_arch := int(ProjectSettings.get_setting("terravolt_mcp/logging/max_archives", 5))
	if not FileAccess.file_exists(abs_path):
		return
	# Godot 4.6: there is no static `FileAccess.get_file_size` (see
	# references/godot-docs/classes/class_fileaccess.rst). Open R-mode and
	# read `get_length()` instead — the file handle closes on scope exit.
	var sz_handle := FileAccess.open(abs_path, FileAccess.READ)
	if sz_handle == null:
		return
	var sz := sz_handle.get_length()
	sz_handle.close()
	if sz <= max_kb * 1024:
		return

	var dir := abs_path.get_base_dir()
	var fn := abs_path.get_file()
	var stem := fn.get_basename() if fn.ends_with(".txt") else fn

	for idx in range(max_arch, 0, -1):
		var prev := dir.path_join("%s.%d.txt" % [stem, idx])
		if idx == max_arch:
			if FileAccess.file_exists(prev):
				DirAccess.remove_absolute(prev)
			continue
		var nxt := dir.path_join("%s.%d.txt" % [stem, idx + 1])
		if FileAccess.file_exists(prev):
			var err := DirAccess.rename_absolute(prev, nxt)
			if err != OK:
				push_warning("[TerraVolt MCP] log rotate rename failed: %s" % str(err))

	var first_arc := dir.path_join("%s.1.txt" % stem)
	DirAccess.rename_absolute(abs_path, first_arc)


static func mkdir_for_file(path_abs: String) -> void:
	var dir := path_abs.get_base_dir()
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("[TerraVolt MCP] mkdir log dir failed (%s): %s" % [dir, err])


func _try_write_line(line: String) -> void:
	var abs_path := resolved_log_path_absolute()
	mkdir_for_file(abs_path)
	if FileAccess.file_exists(abs_path):
		_rotate_if_needed(abs_path)

	var f := FileAccess.open(abs_path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(abs_path, FileAccess.WRITE_READ)
	if f == null:
		f = FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		push_warning("[TerraVolt MCP] log open failed: %s" % abs_path)
		return

	f.seek_end()
	f.store_line(line)
	f.close()
