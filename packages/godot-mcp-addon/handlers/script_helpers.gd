@tool
extends RefCounted
class_name TerravoltScriptHelpers

## Shared script file operations (task 13).

const MAX_INLINE_KB := 96
const SCRIPT_EXTS := [".gd", ".cs", ".shader", ".vshader"]


static func language_for(path: String) -> String:
	var lower := path.to_lower()
	if lower.ends_with(".gd"):
		return "gd"
	if lower.ends_with(".cs"):
		return "cs"
	if lower.ends_with(".vshader"):
		return "vshader"
	if lower.ends_with(".shader"):
		return "shader"
	return "unknown"


static func walk_scripts(pattern: String, include_addon: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var base := ProjectSettings.globalize_path("res://")
	_collect_scripts(base, base, include_addon, out)
	if not pattern.is_empty() and pattern != "**/*.{gd,cs,vshader,shader}":
		var filtered: Array[Dictionary] = []
		for row in out:
			if _glob_match(str(row.get("path", "")), pattern):
				filtered.append(row)
		out = filtered
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("path", "")) < str(b.get("path", "")))
	return out


static func _collect_scripts(base: String, dir_abs: String, include_addon: bool, out: Array[Dictionary]) -> void:
	var da := DirAccess.open(dir_abs)
	if da == null:
		return
	da.list_dir_begin()
	while true:
		var name := da.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var full := dir_abs.path_join(name)
		if da.current_is_dir():
			if not include_addon and name == "addons":
				continue
			_collect_scripts(base, full, include_addon, out)
			continue
		var ext := name.get_extension()
		if ext != "gd" and ext != "cs" and ext != "shader" and ext != "vshader":
			continue
		var rel := full.substr(base.length()).replace("\\", "/").lstrip("/")
		var res_path := "res://%s" % rel
		var content := FileAccess.get_file_as_string(full)
		out.append(
			{
				"path": res_path,
				"language": language_for(res_path),
				"size_bytes": FileAccess.get_file_as_bytes(full).size(),
				"modified_at": _modified_iso(full),
				"is_tool": content.contains("@tool"),
				"has_class_name": _has_class_name(content),
				"class_name": _class_name(content),
			}
		)
	da.list_dir_end()


static func _modified_iso(abs_path: String) -> String:
	if not FileAccess.file_exists(abs_path):
		return ""
	return Time.get_datetime_string_from_unix_time(int(FileAccess.get_modified_time(abs_path)), true)


static func _has_class_name(content: String) -> bool:
	return _class_name(content).length() > 0


static func _class_name(content: String) -> String:
	for line in content.split("\n"):
		var t := line.strip_edges()
		if t.begins_with("class_name "):
			return t.substr("class_name ".length()).split(" ", false)[0]
	return ""


static func _glob_match(path: String, pattern: String) -> bool:
	if pattern.is_empty():
		return true
	return path.contains(pattern.replace("**/", "").replace("*", ""))


static func abs_path(res_path: String) -> String:
	var p := res_path.strip_edges()
	if p.begins_with("res://") or p.begins_with("user://"):
		return ProjectSettings.globalize_path(p)
	if p.begins_with("/") or (p.length() >= 3 and p[1] == ":"):
		return p
	return ProjectSettings.globalize_path("res://%s" % p.lstrip("/"))


static func res_path(abs_or_res: String) -> String:
	if abs_or_res.begins_with("res://") or abs_or_res.begins_with("user://"):
		return abs_or_res
	return ProjectSettings.localize_path(abs_or_res)


static func read_script(path: String, range_spec: Variant, fmt: String) -> Dictionary:
	var abs := abs_path(path)
	if not FileAccess.file_exists(abs):
		return {"ok": false}
	var text := FileAccess.get_file_as_string(abs)
	var lines := text.split("\n", false)
	var start := 1
	var end := lines.size()
	if typeof(range_spec) == TYPE_DICTIONARY:
		start = maxi(1, int((range_spec as Dictionary).get("start_line", 1)))
		end = mini(lines.size(), int((range_spec as Dictionary).get("end_line", lines.size())))
	var slice := "\n".join(lines.slice(start - 1, end))
	var truncated := text.to_utf8_buffer().size() > MAX_INLINE_KB * 1024
	if truncated and fmt != "chunks":
		slice = slice.substr(0, MAX_INLINE_KB * 1024)
	return {
		"ok": true,
		"path": res_path(path),
		"language": language_for(path),
		"size_bytes": text.to_utf8_buffer().size(),
		"content": slice,
		"truncated": truncated,
	}


static func write_script(path: String, content: String, mode: String) -> Dictionary:
	var abs := abs_path(path)
	if mode == "create_only" and FileAccess.file_exists(abs):
		return {"ok": false, "exists": true}
	var dir := abs.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(abs, FileAccess.WRITE)
	if f == null:
		return {"ok": false}
	f.store_string(content)
	return {
		"ok": true,
		"path": res_path(abs),
		"bytes_written": content.to_utf8_buffer().size(),
		"lines": content.split("\n", false).size(),
	}


static func apply_hunks(path: String, hunks: Array) -> Dictionary:
	var abs := abs_path(path)
	if not FileAccess.file_exists(abs):
		return {"ok": false, "missing": true}
	var lines: Array = FileAccess.get_file_as_string(abs).split("\n", false)
	var lines_before := lines.size()
	var applied := 0
	for h_v in hunks:
		if typeof(h_v) != TYPE_DICTIONARY:
			continue
		var h := h_v as Dictionary
		var start := int(h.get("start_line", 1)) - 1
		var end := int(h.get("end_line", start + 1)) - 1
		var replacement: Array = str(h.get("replacement", "")).split("\n", false)
		if start < 0 or end >= lines.size():
			return {"ok": false, "conflict": true}
		var chunk := lines.slice(start, end + 1)
		if str("\n".join(chunk)) != str(h.get("expected", "\n".join(chunk))):
			pass
		for i in range(end - start + 1):
			lines.remove_at(start)
		for i in replacement.size():
			lines.insert(start + i, replacement[i])
		applied += 1
	var out_text := "\n".join(lines)
	FileAccess.open(abs, FileAccess.WRITE).store_string(out_text)
	return {"ok": true, "hunks_applied": applied, "lines_before": lines_before, "lines_after": lines.size()}


static func validate_gd(path: String) -> Dictionary:
	var abs := abs_path(path)
	if not FileAccess.file_exists(abs):
		return {"ok": false, "missing": true}
	var t0 := Time.get_ticks_msec()
	var gd := GDScript.new()
	gd.source_code = FileAccess.get_file_as_string(abs)
	var erc := gd.reload()
	var duration := Time.get_ticks_msec() - t0
	if erc != OK:
		return {
			"ok": false,
			"errors": [{"line": 1, "col": 1, "message": error_string(erc), "severity": "error"}],
			"warnings": [],
			"duration_ms": duration,
		}
	return {"ok": true, "errors": [], "warnings": [], "duration_ms": duration}


static func find_usages(symbol: String, kind: String, case_sensitive: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var base := ProjectSettings.globalize_path("res://")
	_scan_usages_dir(base, base, symbol, kind, case_sensitive, out)
	return out


static func _scan_usages_dir(base: String, dir_abs: String, symbol: String, kind: String, case_sensitive: bool, out: Array[Dictionary]) -> void:
	var da := DirAccess.open(dir_abs)
	if da == null:
		return
	da.list_dir_begin()
	while true:
		var name := da.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var full := dir_abs.path_join(name)
		if da.current_is_dir():
			_scan_usages_dir(base, full, symbol, kind, case_sensitive, out)
			continue
		var ext := name.get_extension()
		if ext != "gd" and ext != "cs" and ext != "tscn" and ext != "tres":
			continue
		var text := FileAccess.get_file_as_string(full)
		var rel := "res://%s" % full.substr(base.length()).replace("\\", "/").lstrip("/")
		var line_no := 0
		for line in text.split("\n", false):
			line_no += 1
			var hay := line if case_sensitive else line.to_lower()
			var needle := symbol if case_sensitive else symbol.to_lower()
			if hay.find(needle) < 0:
				continue
			out.append(
				{
					"path": rel,
					"line": line_no,
					"col": line.find(symbol) + 1,
					"snippet": line.strip_edges(),
					"kind": kind,
					"confidence": "exact",
				}
			)
	da.list_dir_end()


static func minimal_format(content: String) -> String:
	var lines := content.split("\n", false)
	var out: PackedStringArray = []
	for line in lines:
		out.append(line.rstrip(" \t\r"))
	return "\n".join(out) + ("\n" if content.ends_with("\n") else "")


static func parse_signal_declarations(script_path: String) -> Array[Dictionary]:
	var abs := abs_path(script_path)
	if not FileAccess.file_exists(abs):
		return []
	var declared: Array[Dictionary] = []
	var line_no := 0
	for line in FileAccess.get_file_as_string(abs).split("\n", false):
		line_no += 1
		var t := line.strip_edges()
		if not t.begins_with("signal "):
			continue
		var rest := t.substr("signal ".length()).strip_edges()
		var name_part := rest.split("(", false)[0].strip_edges()
		declared.append({"name": name_part, "args": [], "source_line": line_no})
	return declared
