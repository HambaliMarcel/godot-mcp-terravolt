@tool
extends RefCounted
class_name TerravoltResourceHelpers

## Shared resource / variant JSON helpers (task 14).

const MAX_INLINE_KB := 64
const JSON_SCHEMA_VERSION := "1.0"
const RESOURCE_GLOB := "**/*.{tres,res,gdshader,shader}"


static func abs_path(res_path: String) -> String:
	var p := res_path.strip_edges()
	if p.begins_with("res://") or p.begins_with("user://"):
		return ProjectSettings.globalize_path(p)
	if p.begins_with("/") or (p.length() >= 3 and p[1] == ":"):
		return p
	return ProjectSettings.globalize_path("res://%s" % p.lstrip("/"))


static func resolve_path(raw: String) -> String:
	var s := raw.strip_edges()
	if s.is_empty():
		return ""
	if s.begins_with("res://") or s.begins_with("user://"):
		return s
	if s.begins_with("/") or (s.length() >= 3 and s[1] == ":"):
		return ProjectSettings.localize_path(s)
	return "res://%s" % s.lstrip("/")


static func file_exists(path: String) -> bool:
	var p := resolve_path(path)
	return ResourceLoader.exists(p) or FileAccess.file_exists(abs_path(p))


static func resource_uid(res_path: String) -> Variant:
	var uid: int = ResourceLoader.get_resource_uid(res_path)
	if uid != ResourceUID.INVALID_ID and ResourceUID.has_id(uid):
		return ResourceUID.id_to_text(uid)
	return null


static func modified_iso(abs_path: String) -> String:
	if not FileAccess.file_exists(abs_path):
		return ""
	return Time.get_datetime_string_from_unix_time(int(FileAccess.get_modified_time(abs_path)), true)


static func is_resource_file(name: String) -> bool:
	var lower := name.to_lower()
	return (
		lower.ends_with(".tres")
		or lower.ends_with(".res")
		or lower.ends_with(".gdshader")
		or lower.ends_with(".shader")
	)


static func resource_class_from_path(res_path: String, abs_full: String = "") -> String:
	var lower := res_path.to_lower()
	if lower.ends_with(".gdshader") or lower.ends_with(".shader"):
		return "Shader"
	if ResourceLoader.exists(res_path):
		var res := ResourceLoader.load(res_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res != null:
			return res.get_class()
	var ap := abs_full if not abs_full.is_empty() else abs_path(res_path)
	if not FileAccess.file_exists(ap):
		return ""
	if ap.to_lower().ends_with(".res"):
		var bin := ResourceLoader.load(res_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		return bin.get_class() if bin != null else ""
	var head := FileAccess.get_file_as_string(ap)
	if head.length() > 256:
		head = head.substr(0, 256)
	var key := 'type="'
	var i := head.find(key)
	if i >= 0:
		var start := i + key.length()
		var end := head.find('"', start)
		if end > start:
			return head.substr(start, end - start)
	return ""


static func walk_resources(class_filter: String, pattern: String, include_imported: bool) -> Array:
	var out: Array = []
	var base := ProjectSettings.globalize_path("res://")
	_collect_resources(base, base, include_imported, out)
	if not class_filter.is_empty():
		var filtered: Array = []
		for row in out:
			if str(row.get("class", "")) == class_filter:
				filtered.append(row)
		out = filtered
	if not pattern.is_empty() and pattern != RESOURCE_GLOB:
		var pat_filtered: Array = []
		for row in out:
			if str(row.get("path", "")).contains(pattern.replace("**/", "").replace("*", "")):
				pat_filtered.append(row)
		out = pat_filtered
	out.sort_custom(func(a, b): return str(a.get("path", "")) < str(b.get("path", "")))
	return out


static func _collect_resources(base: String, dir_abs: String, include_imported: bool, out: Array) -> void:
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
			_collect_resources(base, full, include_imported, out)
			continue
		if not is_resource_file(name):
			continue
		if not include_imported and name.ends_with(".import"):
			continue
		var rel := full.substr(base.length()).replace("\\", "/").lstrip("/")
		var res_path := "res://%s" % rel
		var cls := resource_class_from_path(res_path, full)
		out.append(
			{
				"path": res_path,
				"class": cls,
				"uid": resource_uid(res_path),
				"size_bytes": FileAccess.get_file_as_bytes(full).size(),
				"modified_at": modified_iso(full),
			}
		)
	da.list_dir_end()


static func load_resource(path: String) -> Resource:
	var p := resolve_path(path)
	var res: Resource = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
	if res != null:
		return res
	var abs := abs_path(p)
	if FileAccess.file_exists(abs):
		return ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
	return null


static func variant_to_json(v: Variant) -> Variant:
	match typeof(v):
		TYPE_NIL:
			return null
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return v
		TYPE_VECTOR2:
			return {"__tv": "Vector2", "x": (v as Vector2).x, "y": (v as Vector2).y}
		TYPE_VECTOR3:
			return {"__tv": "Vector3", "x": (v as Vector3).x, "y": (v as Vector3).y, "z": (v as Vector3).z}
		TYPE_VECTOR4:
			return {"__tv": "Vector4", "x": (v as Vector4).x, "y": (v as Vector4).y, "z": (v as Vector4).z, "w": (v as Vector4).w}
		TYPE_COLOR:
			return {"__tv": "Color", "r": (v as Color).r, "g": (v as Color).g, "b": (v as Color).b, "a": (v as Color).a}
		TYPE_ARRAY:
			var arr: Array = []
			for item in v as Array:
				arr.append(variant_to_json(item))
			return arr
		TYPE_DICTIONARY:
			var keys: Array = (v as Dictionary).keys()
			keys.sort()
			var d: Dictionary = {}
			for k in keys:
				d[str(k)] = variant_to_json((v as Dictionary)[k])
			return d
		TYPE_OBJECT:
			var o := v as Object
			if o == null:
				return null
			if o is Resource and (o as Resource).resource_path.length() > 0:
				return {"__tv": "ResourceRef", "path": (o as Resource).resource_path, "class": o.get_class()}
			return {"__tv": "Object", "class": o.get_class()}
		_:
			return str(v)


static func json_to_variant(v: Variant) -> Variant:
	if v == null:
		return null
	if typeof(v) != TYPE_DICTIONARY:
		return v
	var d := v as Dictionary
	if d.has("__tv"):
		match str(d.get("__tv", "")):
			"Vector2":
				return Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
			"Vector3":
				return Vector3(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0)))
			"Vector4":
				return Vector4(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0)), float(d.get("w", 0)))
			"Color":
				return Color(float(d.get("r", 0)), float(d.get("g", 0)), float(d.get("b", 0)), float(d.get("a", 1)))
			"ResourceRef":
				var rp := str(d.get("path", ""))
				if ResourceLoader.exists(rp):
					return ResourceLoader.load(rp)
				return null
	return d


static func serialize_properties(obj: Object, max_depth: int, depth: int = 0) -> Dictionary:
	var out: Dictionary = {}
	var names: Array[String] = []
	for pi in obj.get_property_list():
		if typeof(pi) != TYPE_DICTIONARY:
			continue
		var name := str((pi as Dictionary).get("name", ""))
		if name.is_empty() or name.begins_with("_") or name == "script":
			continue
		names.append(name)
	names.sort()
	for name in names:
		var val: Variant = obj.get(name)
		if val is Resource and depth < max_depth:
			var sub := val as Resource
			out[name] = {
				"__tv": "SubResource",
				"class": sub.get_class(),
				"properties": serialize_properties(sub, max_depth, depth + 1),
			}
		else:
			out[name] = variant_to_json(val)
	return out


static func apply_properties(obj: Object, patch: Dictionary) -> Dictionary:
	var applied: Dictionary = {}
	for k in patch.keys():
		var key := str(k)
		var before: Variant = obj.get(key) if obj.has_method("get") else null
		var after_v: Variant = json_to_variant(patch[k])
		obj.set(key, after_v)
		applied[key] = {"before": variant_to_json(before), "after": variant_to_json(after_v)}
	return applied


static func export_json(path: String, include_subresources: bool = true) -> Dictionary:
	var res := load_resource(path)
	if res == null:
		return {"ok": false, "missing": true}
	var payload := {
		"schema_version": JSON_SCHEMA_VERSION,
		"path": resolve_path(path),
		"class": res.get_class(),
		"properties": serialize_properties(res, 3 if include_subresources else 0),
	}
	var text := JSON.stringify(payload, "\t")
	var hash := text.sha256_text()
	return {"ok": true, "json_string": text, "hash": hash, "schema_version": JSON_SCHEMA_VERSION}


static func import_json(target_path: String, json_string: String, overwrite: bool) -> Dictionary:
	var parsed: Variant = JSON.parse_string(json_string)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "schema_mismatch": true}
	var doc := parsed as Dictionary
	if str(doc.get("schema_version", "")) != JSON_SCHEMA_VERSION:
		return {"ok": false, "schema_mismatch": true}
	var path := resolve_path(target_path)
	if file_exists(path) and not overwrite:
		return {"ok": false, "exists": true}
	var cls := str(doc.get("class", "Resource"))
	if not ClassDB.class_exists(cls):
		return {"ok": false, "class_unknown": true}
	var res: Resource = ClassDB.instantiate(cls) as Resource
	if res == null:
		return {"ok": false, "class_unknown": true}
	var props: Dictionary = doc.get("properties", {}) as Dictionary
	apply_properties(res, props)
	var dir := abs_path(path.get_base_dir())
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		return {"ok": false, "save_failed": true}
	return {"ok": true, "path": path, "class": cls, "revision": str(Time.get_ticks_msec())}


static func diff_json(a_doc: Dictionary, b_doc: Dictionary, prefix: String = "") -> Array:
	var diff: Array = []
	var keys: Array = []
	for k in a_doc.keys():
		if not keys.has(k):
			keys.append(k)
	for k in b_doc.keys():
		if not keys.has(k):
			keys.append(k)
	keys.sort()
	for k in keys:
		var key := str(k)
		var pth := "%s.%s" % [prefix, key] if not prefix.is_empty() else key
		var in_a := a_doc.has(k)
		var in_b := b_doc.has(k)
		if not in_a:
			diff.append({"path": pth, "op": "add", "after": b_doc[k]})
		elif not in_b:
			diff.append({"path": pth, "op": "remove", "before": a_doc[k]})
		elif JSON.stringify(a_doc[k]) != JSON.stringify(b_doc[k]):
			if typeof(a_doc[k]) == TYPE_DICTIONARY and typeof(b_doc[k]) == TYPE_DICTIONARY:
				diff.append_array(diff_json(a_doc[k] as Dictionary, b_doc[k] as Dictionary, pth))
			else:
				diff.append({"path": pth, "op": "change", "before": a_doc[k], "after": b_doc[k]})
	return diff


static func get_dependencies(path: String, deep: bool) -> Dictionary:
	var p := resolve_path(path)
	var deps: Array = []
	var seen: Dictionary = {}
	_collect_deps(p, deep, seen, deps)
	return {"dependencies": deps, "cycles": []}


static func _collect_deps(path: String, deep: bool, seen: Dictionary, out: Array) -> void:
	if seen.has(path):
		return
	seen[path] = true
	for d in ResourceLoader.get_dependencies(path):
		var dp := str(d)
		var cls := resource_class_from_path(dp) if ResourceLoader.exists(dp) else ""
		out.append({"path": dp, "class": cls, "weak": false})
		if deep:
			_collect_deps(dp, true, seen, out)


static func get_dependents(path: String, scope: String, folder: String) -> Array:
	var target := resolve_path(path)
	var out: Array = []
	for row in walk_resources("", RESOURCE_GLOB, false):
		var other := str(row.get("path", ""))
		if other == target:
			continue
		if scope == "folder" and not folder.is_empty():
			var fp := resolve_path(folder)
			if not other.begins_with(fp):
				continue
		var count := 0
		for d in ResourceLoader.get_dependencies(other):
			if str(d) == target:
				count += 1
		if count == 0 and _text_references(other, target):
			count = 1
		if count > 0:
			out.append({"path": other, "class": str(row.get("class", "")), "ref_count": count})
	return out


static func _text_references(file_path: String, target: String) -> bool:
	var abs := abs_path(file_path)
	if not FileAccess.file_exists(abs):
		return false
	var lower := abs.to_lower()
	if lower.ends_with(".res"):
		return false
	var text := FileAccess.get_file_as_string(abs)
	return text.contains(target)


static func replace_references(from_path: String, to_path: String, dry_run: bool, exclude: Array) -> Dictionary:
	var from_p := resolve_path(from_path)
	var to_p := resolve_path(to_path)
	var rewrites: Array = []
	var files_changed := 0
	for row in walk_resources("", "**/*.{tscn,tres,gd,cs,gdshader}", false):
		var fp := str(row.get("path", ""))
		if _excluded(fp, exclude):
			continue
		var abs := abs_path(fp)
		if abs.to_lower().ends_with(".res"):
			continue
		if not FileAccess.file_exists(abs):
			continue
		var before := FileAccess.get_file_as_string(abs)
		if not before.contains(from_p):
			continue
		var after := before.replace(from_p, to_p)
		rewrites.append({"in_file": fp, "before": from_p, "after": to_p})
		if not dry_run:
			FileAccess.open(abs, FileAccess.WRITE).store_string(after)
			files_changed += 1
	return {"rewrites": rewrites, "applied": not dry_run and files_changed > 0, "files_changed": files_changed}


static func _excluded(path: String, exclude: Array) -> bool:
	for pat in exclude:
		if path.contains(str(pat).replace("*", "")):
			return true
	return false


static func validate_resource(path: String) -> Dictionary:
	var p := resolve_path(path)
	if not file_exists(p):
		return {"ok": false, "issues": [{"severity": "error", "code": "resource.path_not_found", "message": "Missing file", "path": p}]}
	var issues: Array = []
	var res := load_resource(p)
	if res == null:
		issues.append({"severity": "error", "code": "resource.load_failed", "message": "ResourceLoader.load returned null", "path": p})
		return {"ok": false, "issues": issues}
	for dep in ResourceLoader.get_dependencies(p):
		if not ResourceLoader.exists(str(dep)):
			issues.append(
				{
					"severity": "error",
					"code": "resource.missing_dependency",
					"message": "Missing dependency %s" % dep,
					"path": str(dep),
				}
			)
	return {"ok": issues.is_empty(), "issues": issues}


static func shader_compile_check_code(code: String) -> Dictionary:
	var probe := "uniform float __tv_compile_probe;"
	var augmented := code
	if not code.contains("__tv_compile_probe"):
		var lines := code.split("\n")
		var out: PackedStringArray = []
		var inserted := false
		for line in lines:
			out.append(line)
			if not inserted and line.strip_edges().begins_with("shader_type"):
				out.append(probe)
				inserted = true
		if not inserted:
			augmented = "shader_type canvas_item;\n%s\n%s" % [probe, code]
		else:
			augmented = "\n".join(out)
	var shader := Shader.new()
	shader.code = augmented
	shader.get_rid()
	var ok := not shader.get_shader_uniform_list().is_empty()
	if ok:
		return {"ok": true, "errors": [], "warnings": []}
	return {"ok": false, "errors": [{"line": 1, "col": 1, "message": "Shader failed to compile"}], "warnings": []}


static func assign_uid(path: String, uid_text: String, force: bool) -> Dictionary:
	var p := resolve_path(path)
	if not file_exists(p):
		return {"ok": false, "missing": true}
	var previous: Variant = resource_uid(p)
	if previous != null and not force:
		return {"ok": true, "uid": previous, "previous_uid": previous}
	var new_uid := uid_text
	if new_uid.is_empty():
		new_uid = ResourceUID.id_to_text(ResourceUID.create_id())
	var id := ResourceUID.text_to_id(new_uid)
	ResourceUID.add_id(id, p)
	return {"ok": true, "uid": new_uid, "previous_uid": previous}
