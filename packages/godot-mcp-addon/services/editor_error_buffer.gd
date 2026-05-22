extends RefCounted
class_name TerravoltEditorErrorBuffer

## Rolling editor error/warn buffer (task 16).

const CAPACITY := 2000

static var _entries: Array = []


static func append(level: String, message: String, source: String = "engine", file: String = "", line: int = -1) -> void:
	_entries.append(
		{
			"ts": Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()), true),
			"level": level,
			"source": source,
			"file": file,
			"line": line if line >= 0 else null,
			"message": message,
		}
	)
	while _entries.size() > CAPACITY:
		_entries.pop_front()


static func tail(lines: int, level: String) -> Array:
	var out: Array = []
	var i := _entries.size() - 1
	while i >= 0 and out.size() < lines:
		var row: Variant = _entries[i]
		if typeof(row) != TYPE_DICTIONARY:
			i -= 1
			continue
		var lv := str((row as Dictionary).get("level", "info"))
		if level == "all" or lv == level or (level == "warn" and lv in ["warn", "error"]):
			out.append(row)
		i -= 1
	out.reverse()
	return out
