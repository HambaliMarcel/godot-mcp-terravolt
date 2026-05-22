@tool
extends RefCounted
class_name TerravoltAnalysisHelpers

const _Assets := preload("./asset_helpers.gd")
const _Res := preload("./resource_helpers.gd")
const _Scripts := preload("./script_helpers.gd")

const THRESHOLDS := {
	"node_count": 500,
	"max_depth": 12,
	"signal_fan_out": 32,
}


static func walk_scenes() -> Array:
	var out: Array = []
	var base := ProjectSettings.globalize_path("res://")
	_collect_scenes(base, base, out)
	out.sort_custom(func(a, b): return str(a.get("path", "")) < str(b.get("path", "")))
	return out


static func _collect_scenes(base: String, dir_abs: String, out: Array) -> void:
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
			_collect_scenes(base, full, out)
			continue
		if name.ends_with(".tscn") or name.ends_with(".scn"):
			var rel := full.substr(base.length()).replace("\\", "/").lstrip("/")
			out.append({"path": "res://%s" % rel})
	da.list_dir_end()


static func scene_complexity(scope: String, scene_path: String, thresholds: Dictionary) -> Dictionary:
	var scenes: Array = []
	if scope == "project":
		scenes = walk_scenes()
	elif scope == "active" or scene_path.is_empty():
		var main := str(ProjectSettings.get_setting("application/run/main_scene", ""))
		if not main.is_empty():
			scenes.append({"path": main})
	else:
		scenes.append({"path": _Res.resolve_path(scene_path)})
	var th := THRESHOLDS.duplicate()
	for k in thresholds.keys():
		th[str(k)] = thresholds[k]
	var per_scene: Array = []
	var offenders: Array = []
	var total_nodes := 0
	var max_depth := 0
	for row in scenes:
		var path := str(row.get("path", ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var packed: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if packed == null:
			continue
		var inst := packed.instantiate()
		if inst == null:
			continue
		var nodes := inst.find_children("*", "", true, true)
		var count := nodes.size() + 1
		var depth := _tree_depth(inst)
		total_nodes += count
		max_depth = maxi(max_depth, depth)
		per_scene.append({"path": path, "node_count": count, "max_depth": depth, "total_signal_connections": 0})
		if count > int(th.get("node_count", 500)):
			offenders.append({"path": path, "metric": "node_count", "value": count, "threshold": th.node_count})
		if depth > int(th.get("max_depth", 12)):
			offenders.append({"path": path, "metric": "max_depth", "value": depth, "threshold": th.max_depth})
		inst.free()
	return {
		"overall": {
			"node_count": total_nodes,
			"max_depth": max_depth,
			"total_signal_connections": 0,
			"external_resource_refs": 0,
		},
		"per_scene": per_scene,
		"offenders": offenders,
	}


static func _tree_depth(node: Node) -> int:
	var best := 1
	for c in node.get_children():
		best = maxi(best, 1 + _tree_depth(c))
	return best


static func signal_flow(scope: String) -> Dictionary:
	var nodes: Array = []
	var edges: Array = []
	var orphans: Array = []
	for fp in _Assets.project_text_files():
		if not str(fp).ends_with(".gd"):
			continue
		for sig in _Scripts.parse_signal_declarations(str(fp)):
			var name := str(sig.get("name", ""))
			nodes.append({"path": fp, "signal": name})
			if not _text_has_connection(str(fp), name):
				orphans.append({"path": fp, "signal": name, "reason": "no_connection_found"})
	for row in walk_scenes():
		var path := str(row.get("path", ""))
		var text := FileAccess.get_file_as_string(_Res.abs_path(path))
		for line in text.split("\n"):
			if "[connection" in line and "signal=" in line:
				edges.append({"line": line.strip_edges()})
	return {
		"graph_summary": {"nodes": nodes.size(), "edges": edges.size()},
		"orphans": orphans,
		"dead_listeners": [],
		"cycles": [],
	}


static func _text_has_connection(script_path: String, signal_name: String) -> bool:
	for fp in _Assets.project_text_files():
		var text := FileAccess.get_file_as_string(_Res.abs_path(str(fp)))
		if text.contains('connect("%s"' % signal_name) or text.contains("connect(&\"%s\"" % signal_name):
			return true
		if text.contains('[connection signal="%s"' % signal_name):
			return true
	return false


static func unused_resources(kinds: Array, exclude: Array) -> Dictionary:
	var unused: Array = []
	if kinds.is_empty() or "asset" in kinds:
		for row in _Assets.find_unused("any", exclude):
			unused.append({"path": str(row.get("path", "")), "kind": "asset", "size_bytes": int(row.get("size_bytes", 0))})
	if kinds.is_empty() or "resource" in kinds:
		for row in _Res.walk_resources("", _Res.RESOURCE_GLOB, false):
			var rp := str(row.get("path", ""))
			if _Assets.references_asset(rp):
				continue
			if not _Res.get_dependents(rp, "project", "").is_empty():
				continue
			unused.append({"path": rp, "kind": "resource", "size_bytes": int(row.get("size_bytes", 0))})
	var total_bytes := 0
	for row in unused:
		total_bytes += int(row.get("size_bytes", 0))
	return {"unused": unused, "total_count": unused.size(), "total_bytes_estimate": total_bytes}


static func project_metrics(kinds: Array) -> Dictionary:
	var all_kinds := kinds.is_empty()
	var loc := {"gd": 0, "cs": 0, "gdshader": 0, "total": 0}
	var scripts := {"count": 0, "avg_loc": 0, "p95_loc": 0}
	var scenes := {"count": 0, "avg_node_count": 0, "p95_node_count": 0}
	var resources := {"count": 0, "by_class": {}}
	var locs: Array = []
	if all_kinds or "loc" in kinds or "scripts" in kinds:
		for fp in _Assets.project_text_files():
			var lower := str(fp).to_lower()
			var abs := _Assets.abs_path(str(fp))
			var lines := FileAccess.get_file_as_string(abs).split("\n").size()
			if lower.ends_with(".gd"):
				loc.gd += lines
				scripts.count += 1
				locs.append(lines)
			elif lower.ends_with(".cs"):
				loc.cs += lines
			elif lower.ends_with(".gdshader"):
				loc.gdshader += lines
		loc.total = loc.gd + loc.cs + loc.gdshader
		if locs.size() > 0:
			locs.sort()
			var sum := 0
			for n in locs:
				sum += n
			scripts.avg_loc = sum / locs.size()
			scripts.p95_loc = locs[int(float(locs.size() - 1) * 0.95)]
	if all_kinds or "scenes" in kinds:
		var counts: Array = []
		for row in walk_scenes():
			scenes.count += 1
			var packed: PackedScene = ResourceLoader.load(str(row.path), "", ResourceLoader.CACHE_MODE_IGNORE)
			if packed == null:
				continue
			var inst := packed.instantiate()
			if inst == null:
				continue
			var c := inst.find_children("*", "", true, true).size() + 1
			counts.append(c)
			inst.free()
		if counts.size() > 0:
			counts.sort()
			var sum2 := 0
			for n in counts:
				sum2 += n
			scenes.avg_node_count = sum2 / counts.size()
			scenes.p95_node_count = counts[int(float(counts.size() - 1) * 0.95)]
	if all_kinds or "resources" in kinds:
		for row in _Res.walk_resources("", _Res.RESOURCE_GLOB, false):
			resources.count += 1
			var cls := str(row.get("class", ""))
			resources.by_class[cls] = int(resources.by_class.get(cls, 0)) + 1
	return {
		"loc": loc,
		"scenes": scenes,
		"scripts": scripts,
		"complexity": {"histogram": []},
		"resources": resources,
	}
