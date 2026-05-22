extends RefCounted
class_name TerravoltMacroJournal

## Macro apply history + revert snapshots (task 24).

const HISTORY_PATH := "user://terravolt/macro_history.json"
const REVERT_DIR := "user://terravolt/macro_reverts"
const MAX_ENTRIES := 100


static func _load_doc() -> Dictionary:
	if not FileAccess.file_exists(HISTORY_PATH):
		return {"entries": []}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(HISTORY_PATH))
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return {"entries": []}
	return parsed as Dictionary


static func _save_doc(doc: Dictionary) -> void:
	var dir := HISTORY_PATH.get_base_dir()
	var abs := ProjectSettings.globalize_path(dir)
	if not DirAccess.dir_exists_absolute(abs):
		DirAccess.make_dir_recursive_absolute(abs)
	FileAccess.open(HISTORY_PATH, FileAccess.WRITE).store_string(JSON.stringify(doc, "\t"))


static func new_revert_token(macro: String) -> String:
	return "%s_%d_%s" % [macro, Time.get_ticks_msec(), str(randi()).sha256_text().substr(0, 8)]


static func store_revert_snapshots(token: String, snapshots: Dictionary) -> void:
	var dir_abs := ProjectSettings.globalize_path(REVERT_DIR)
	if not DirAccess.dir_exists_absolute(dir_abs):
		DirAccess.make_dir_recursive_absolute(dir_abs)
	var path := "%s/%s.json" % [REVERT_DIR, token]
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(snapshots, "\t"))


static func load_revert_snapshots(token: String) -> Dictionary:
	var path := "%s/%s.json" % [REVERT_DIR, token]
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}


static func append_entry(entry: Dictionary) -> void:
	var doc := _load_doc()
	var entries: Array = doc.get("entries", []) as Array
	entries.insert(0, entry)
	while entries.size() > MAX_ENTRIES:
		entries.pop_back()
	doc["entries"] = entries
	_save_doc(doc)


static func history(limit: int) -> Array:
	var out: Array = []
	for row in (_load_doc().get("entries", []) as Array):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		out.append(row)
		if out.size() >= limit:
			break
	return out
