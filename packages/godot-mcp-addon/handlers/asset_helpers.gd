@tool
extends RefCounted
class_name TerravoltAssetHelpers

## Shared asset pipeline helpers (task 15).

const _ResourceHelpers := preload("./resource_helpers.gd")

const MAX_INLINE_KB := 256
const BATCH_MAX_FILES := 500

const EXT_TEXTURE := [".png", ".jpg", ".jpeg", ".webp", ".exr", ".svg"]
const EXT_AUDIO := [".ogg", ".wav", ".mp3"]
const EXT_MODEL := [".gltf", ".glb", ".fbx", ".obj"]
const EXT_FONT := [".ttf", ".otf", ".woff", ".woff2"]

const IMPORT_PRESETS := {
	"compressed_albedo": {"compress/mode": 2, "mipmaps/generate": true},
	"unfiltered_pixel_art": {"compress/mode": 0, "process/fix_alpha_border": true, "process/hdr_as_srgb": false},
}


static func resolve_path(raw: String) -> String:
	var s := raw.strip_edges()
	if s.is_empty():
		return ""
	if s.begins_with("res://") or s.begins_with("user://"):
		return s
	if s.begins_with("/") or (s.length() >= 3 and s[1] == ":"):
		return ProjectSettings.localize_path(s)
	return "res://%s" % s.lstrip("/")


static func abs_path(res_path: String) -> String:
	var p := resolve_path(res_path)
	if p.begins_with("res://") or p.begins_with("user://"):
		return ProjectSettings.globalize_path(p)
	return p


static func modified_iso(path_abs: String) -> String:
	if not FileAccess.file_exists(path_abs):
		return ""
	return Time.get_datetime_string_from_unix_time(int(FileAccess.get_modified_time(path_abs)), true)


static func kind_for_name(name: String) -> String:
	var lower := name.to_lower()
	for ext in EXT_TEXTURE:
		if lower.ends_with(ext):
			return "texture"
	for ext in EXT_AUDIO:
		if lower.ends_with(ext):
			return "audio"
	for ext in EXT_MODEL:
		if lower.ends_with(ext):
			return "model"
	for ext in EXT_FONT:
		if lower.ends_with(ext):
			return "font"
	return "any"


static func is_asset_file(name: String) -> bool:
	return kind_for_name(name) != "any"


static func sidecar_path(res_path: String) -> String:
	return "%s.import" % res_path


static func sidecar_abs(res_path: String) -> String:
	return "%s.import" % abs_path(res_path)


static func file_exists(res_path: String) -> bool:
	return FileAccess.file_exists(abs_path(res_path))


static func walk_assets(kind_filter: String, pattern: String, include_imports: bool) -> Array:
	var out: Array = []
	var base := ProjectSettings.globalize_path("res://")
	_collect_assets(base, base, include_imports, out)
	if kind_filter != "any" and not kind_filter.is_empty():
		var filtered: Array = []
		for row in out:
			if str(row.get("kind", "")) == kind_filter:
				filtered.append(row)
		out = filtered
	if not pattern.is_empty() and pattern != "**/*":
		var needle := pattern.replace("**/", "").replace("*", "")
		if not needle.is_empty():
			var pat_filtered: Array = []
			for row in out:
				if str(row.get("path", "")).contains(needle):
					pat_filtered.append(row)
			out = pat_filtered
	out.sort_custom(func(a, b): return str(a.get("path", "")) < str(b.get("path", "")))
	return out


static func _collect_assets(base: String, dir_abs: String, include_imports: bool, out: Array) -> void:
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
			_collect_assets(base, full, include_imports, out)
			continue
		if name.ends_with(".import"):
			continue
		if not is_asset_file(name):
			continue
		var rel := full.substr(base.length()).replace("\\", "/").lstrip("/")
		var res_path := "res://%s" % rel
		var side := sidecar_abs(res_path)
		var import_class := ""
		if FileAccess.file_exists(side):
			var parsed := parse_import_sidecar(res_path)
			import_class = str(parsed.get("type", ""))
		out.append(
			{
				"path": res_path,
				"kind": kind_for_name(name),
				"size_bytes": FileAccess.get_file_as_bytes(full).size(),
				"modified_at": modified_iso(full),
				"has_import_metadata": FileAccess.file_exists(side),
				"import_target_class": import_class,
			}
		)
	da.list_dir_end()


static func parse_import_sidecar(res_path: String) -> Dictionary:
	var side := sidecar_abs(res_path)
	if not FileAccess.file_exists(side):
		return {}
	var cfg := ConfigFile.new()
	if cfg.load(side) != OK:
		return {}
	var settings: Dictionary = {}
	if cfg.has_section("params"):
		for k in cfg.get_section_keys("params"):
			settings[str(k)] = cfg.get_value("params", k)
	return {
		"importer": str(cfg.get_value("remap", "importer", "")),
		"type": str(cfg.get_value("remap", "type", "")),
		"uid": str(cfg.get_value("remap", "uid", "")),
		"path": str(cfg.get_value("remap", "path", "")),
		"settings": settings,
		"last_modified": modified_iso(side),
	}


static func import_status_for(path: String, scope: String, folder: String) -> Array:
	var items: Array = []
	var targets: Array = []
	if path.is_empty():
		for row in walk_assets("any", "", true):
			var rp := str(row.get("path", ""))
			if scope == "folder" and not folder.is_empty():
				if not rp.begins_with(resolve_path(folder)):
					continue
			targets.append(rp)
	else:
		targets.append(resolve_path(path))
	for rp in targets:
		if not file_exists(rp):
			continue
		var side := parse_import_sidecar(rp)
		var abs := abs_path(rp)
		var side_abs := sidecar_abs(rp)
		var dirty := false
		if FileAccess.file_exists(side_abs):
			dirty = FileAccess.get_modified_time(abs) > FileAccess.get_modified_time(side_abs)
		items.append(
			{
				"path": rp,
				"imported": not side.is_empty(),
				"importer": str(side.get("importer", "")),
				"type": str(side.get("type", "")),
				"last_modified": modified_iso(abs),
				"last_imported": str(side.get("last_modified", "")),
				"dirty": dirty,
			}
		)
	return items


static func get_import_settings(path: String) -> Dictionary:
	var rp := resolve_path(path)
	if not file_exists(rp):
		return {}
	var side := parse_import_sidecar(rp)
	return {
		"path": rp,
		"importer": str(side.get("importer", "")),
		"type": str(side.get("type", "")),
		"settings": side.get("settings", {}),
		"default_settings": {},
	}


static func set_import_settings(path: String, patch: Dictionary, reimport_after: bool) -> Dictionary:
	var rp := resolve_path(path)
	if not file_exists(rp):
		return {"ok": false}
	var side_abs := sidecar_abs(rp)
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(side_abs):
		cfg.load(side_abs)
	var applied: Dictionary = {}
	for k in patch.keys():
		var key := str(k)
		var before = cfg.get_value("params", key, null)
		cfg.set_value("params", key, patch[k])
		applied[key] = {"before": before, "after": patch[k]}
	if not cfg.has_section("params"):
		cfg.set_value("params", "__tv", true)
	cfg.save(side_abs)
	return {"ok": true, "applied": applied, "reimported": reimport_after}


static func project_text_files() -> Array:
	var out: Array = []
	var base := ProjectSettings.globalize_path("res://")
	_collect_text_files(base, base, out)
	return out


static func _collect_text_files(base: String, dir_abs: String, out: Array) -> void:
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
			_collect_text_files(base, full, out)
			continue
		var lower := name.to_lower()
		if lower.ends_with(".res") or lower.ends_with(".import"):
			continue
		if lower.ends_with(".gd") or lower.ends_with(".tscn") or lower.ends_with(".tres") or lower.ends_with(".gdshader") or lower.ends_with(".cs") or lower.ends_with(".png") or lower.ends_with(".jpg"):
			var rel := full.substr(base.length()).replace("\\", "/").lstrip("/")
			out.append("res://%s" % rel)
	da.list_dir_end()


static func references_asset(target: String) -> bool:
	var needle := resolve_path(target)
	for fp in project_text_files():
		if fp == needle:
			continue
		var text := FileAccess.get_file_as_string(abs_path(fp))
		if text.contains(needle):
			return true
		var short := needle.replace("res://", "")
		if text.contains(short):
			return true
		if text.contains('preload("%s")' % needle) or text.contains('load("%s")' % needle):
			return true
	return false


static func find_unused(kind_filter: String, exclude: Array) -> Array:
	var unused: Array = []
	for row in walk_assets(kind_filter if not kind_filter.is_empty() else "any", "", true):
		var rp := str(row.get("path", ""))
		if _excluded(rp, exclude):
			continue
		if not references_asset(rp):
			unused.append({"path": rp, "size_bytes": int(row.get("size_bytes", 0))})
	return unused


static func _excluded(path: String, exclude: Array) -> bool:
	for pat in exclude:
		if path.contains(str(pat).replace("*", "")):
			return true
	return false


static func metadata_for(path: String) -> Dictionary:
	var rp := resolve_path(path)
	if not file_exists(rp):
		return {}
	var kind := kind_for_name(rp)
	var meta: Dictionary = {}
	match kind:
		"texture":
			var img := Image.new()
			var ap := abs_path(rp)
			if img.load(ap) == OK:
				meta = {"width": img.get_width(), "height": img.get_height(), "format": img.get_format(), "mipmaps": false}
			else:
				var bytes := FileAccess.get_file_as_bytes(ap)
				if img.load_png_from_buffer(bytes) == OK:
					meta = {"width": img.get_width(), "height": img.get_height(), "format": img.get_format(), "mipmaps": false}
		"audio":
			var stream: AudioStream = ResourceLoader.load(rp, "", ResourceLoader.CACHE_MODE_IGNORE)
			if stream != null:
				meta = {
					"duration_s": stream.get_length() if stream.has_method("get_length") else 0.0,
					"sample_rate": stream.mix_rate if "mix_rate" in stream else 0,
					"channels": 1,
				}
		"font":
			meta = {"family": rp.get_file().get_basename(), "weight": "regular", "style": "normal"}
		"model":
			meta = {"mesh_count": 0, "animation_count": 0, "has_skeleton": false}
	return {"kind": kind, "metadata": meta}


static func rename_asset(from_path: String, to_path: String, update_refs: bool, dry_run: bool) -> Dictionary:
	var from_p := resolve_path(from_path)
	var to_p := resolve_path(to_path)
	if not file_exists(from_p):
		return {"ok": false}
	var refs: Array = []
	if update_refs:
		var rr := _ResourceHelpers.replace_references(from_p, to_p, dry_run, [])
		for rw in rr.get("rewrites", []):
			refs.append(rw)
	if dry_run:
		return {"renamed": true, "from": from_p, "to": to_p, "sidecar_moved": FileAccess.file_exists(sidecar_abs(from_p)), "references_updated": refs, "dry_run": true}
	var err := DirAccess.rename_absolute(abs_path(from_p), abs_path(to_p))
	if err != OK:
		return {"ok": false}
	var side_moved := false
	if FileAccess.file_exists(sidecar_abs(from_p)):
		DirAccess.rename_absolute(sidecar_abs(from_p), sidecar_abs(to_p))
		side_moved = true
	return {"renamed": true, "from": from_p, "to": to_p, "sidecar_moved": side_moved, "references_updated": refs, "dry_run": false}


static func delete_asset(path: String, force: bool) -> Dictionary:
	var rp := resolve_path(path)
	if not file_exists(rp):
		return {"ok": false}
	if not force and references_asset(rp):
		return {"ok": false, "blocked": true}
	var bytes := FileAccess.get_file_as_bytes(abs_path(rp)).size()
	var side_removed := false
	if FileAccess.file_exists(sidecar_abs(rp)):
		DirAccess.remove_absolute(sidecar_abs(rp))
		side_removed = true
	DirAccess.remove_absolute(abs_path(rp))
	return {"deleted": true, "path": rp, "freed_bytes": bytes, "sidecar_removed": side_removed}


static func add_asset(path: String, bytes: PackedByteArray, overwrite: bool) -> Dictionary:
	var rp := resolve_path(path)
	if file_exists(rp) and not overwrite:
		return {"ok": false, "exists": true}
	if bytes.size() > MAX_INLINE_KB * 1024:
		return {"ok": false, "too_large": true}
	var dir := abs_path(rp.get_base_dir())
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	FileAccess.open(abs_path(rp), FileAccess.WRITE).store_buffer(bytes)
	return {"added": true, "path": rp, "size_bytes": bytes.size(), "kind": kind_for_name(rp), "import_triggered": false}
