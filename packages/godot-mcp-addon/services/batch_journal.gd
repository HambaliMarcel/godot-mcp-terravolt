extends RefCounted
class_name TerravoltBatchJournal

## Persistent preview/apply/revert journal (task 15).

const HISTORY_PATH := "user://terravolt/batch_history.json"
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
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	FileAccess.open(HISTORY_PATH, FileAccess.WRITE).store_string(JSON.stringify(doc, "\t"))


static func token_for_plan(plan: Dictionary) -> String:
	return JSON.stringify(plan).sha256_text()


static func append_preview(plan: Dictionary, preview: Dictionary) -> String:
	var token := token_for_plan(plan)
	var doc := _load_doc()
	var entries: Array = doc.get("entries", []) as Array
	entries.insert(
		0,
		{
			"id": token.substr(0, 12),
			"token": token,
			"kind": "preview",
			"applied_at": Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()), true),
			"plan": plan,
			"preview": preview,
		}
	)
	while entries.size() > MAX_ENTRIES:
		entries.pop_back()
	doc["entries"] = entries
	_save_doc(doc)
	return token


static func append_apply(plan: Dictionary, result: Dictionary, snapshots: Dictionary) -> String:
	var token := str(result.get("revert_token", token_for_plan(plan)))
	var doc := _load_doc()
	var entries: Array = doc.get("entries", []) as Array
	entries.insert(
		0,
		{
			"id": token.substr(0, 12),
			"token": token,
			"kind": "apply",
			"applied_at": Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()), true),
			"plan": plan,
			"result": result,
			"snapshots": snapshots,
			"revert_token": token,
		}
	)
	while entries.size() > MAX_ENTRIES:
		entries.pop_back()
	doc["entries"] = entries
	_save_doc(doc)
	return token


static func history(limit: int) -> Array:
	var out: Array = []
	for row in (_load_doc().get("entries", []) as Array):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var e := row as Dictionary
		if str(e.get("kind", "")) != "apply":
			continue
		out.append(
			{
				"id": e.get("id", ""),
				"applied_at": e.get("applied_at", ""),
				"ops_count": (e.get("plan", {}) as Dictionary).get("ops", []).size(),
				"files_changed": int((e.get("result", {}) as Dictionary).get("files_changed", 0)),
				"revert_token": e.get("revert_token", ""),
				"summary": str((e.get("result", {}) as Dictionary).get("summary", "")),
			}
		)
		if out.size() >= limit:
			break
	return out


static func find_entry(token: String) -> Dictionary:
	for row in (_load_doc().get("entries", []) as Array):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var e := row as Dictionary
		if str(e.get("token", "")) == token or str(e.get("revert_token", "")) == token:
			return e
	return {}
