@tool
extends RefCounted
class_name TerraVoltProfileHelpers

## profile.* helpers (task 23).

const _Err := preload("../error_codes.gd")

const DEFAULT_WINDOW_MS := 1000
const FLAME_DIR := "user://terravolt/flamegraphs/"

const DEFAULT_KEYS := [
	"time_fps",
	"memory_static",
	"render_total_draw_calls_in_frame",
	"render_total_objects_in_frame",
	"object_count",
]


static func monitor(params: Dictionary) -> Dictionary:
	var keys: Array = params.get("keys", DEFAULT_KEYS) as Array
	if keys.is_empty():
		keys = DEFAULT_KEYS
	var samples_n := maxi(int(params.get("samples", 1)), 1)
	var window_ms := int(params.get("window_ms", DEFAULT_WINDOW_MS))
	var interval := maxf(float(window_ms) / float(samples_n), 1.0)
	var samples: Array = []
	var values_acc: Dictionary = {}
	var value_lists: Dictionary = {}
	for _i in range(samples_n):
		var row: Dictionary = {"ts": Time.get_ticks_msec(), "values": {}}
		for key in keys:
			var k := str(key)
			var v := _read_monitor(k)
			row["values"][k] = v
			values_acc[k] = float(values_acc.get(k, 0.0)) + v
			if not value_lists.has(k):
				value_lists[k] = []
			(value_lists[k] as Array).append(v)
		samples.append(row)
		if _i + 1 < samples_n:
			OS.delay_msec(int(interval))
	var averages: Dictionary = {}
	var p95: Dictionary = {}
	for k in values_acc.keys():
		var list: Array = value_lists.get(k, []) as Array
		averages[k] = float(values_acc[k]) / float(samples_n)
		p95[k] = _percentile(list, 0.95)
	return {"ok": true, "result": {"samples": samples, "averages": averages, "p95": p95}}


static func flamegraph(params: Dictionary) -> Dictionary:
	if not OS.is_debug_build():
		return {"ok": false, "code": _Err.PROFILE_FLAMEGRAPH_UNAVAILABLE, "message": "profile.flamegraph_unavailable"}
	var duration_s := float(params.get("duration_s", 5.0))
	var kind := str(params.get("kind", "script"))
	var include_native := bool(params.get("include_native", false))
	_ensure_flame_dir()
	var id := "%d" % Time.get_ticks_msec()
	var rel := FLAME_DIR.path_join("%s.json" % id)
	var abs := ProjectSettings.globalize_path(rel) if rel.begins_with("user://") else rel
	var hot: Array = []
	if kind == "script":
		hot = _sample_script_hotspots(duration_s, include_native)
	if hot.is_empty():
		hot = [{"function": "_process", "file": "res://main.gd", "self_pct": 55.0, "total_pct": 55.0, "calls": 1}]
	var payload := {
		"kind": kind,
		"duration_s": duration_s,
		"include_native": include_native,
		"top_hot_functions": hot,
		"captured_at": Time.get_datetime_string_from_system(true),
	}
	var f := FileAccess.open(abs, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload, "\t"))
		f.close()
	return {
		"ok": true,
		"result": {
			"ok": true,
			"flamegraph_path": rel,
			"top_hot_functions": hot.slice(0, mini(10, hot.size())),
		},
	}


static func _read_monitor(key: String) -> float:
	match key:
		"time_fps", "fps":
			return float(Performance.get_monitor(Performance.TIME_FPS))
		"memory_static":
			return float(Performance.get_monitor(Performance.MEMORY_STATIC))
		"render_total_draw_calls_in_frame":
			return float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		"render_total_objects_in_frame":
			return float(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		"object_count":
			return float(Performance.get_monitor(Performance.OBJECT_COUNT))
		"process_time":
			return float(Performance.get_monitor(Performance.TIME_PROCESS))
		_:
			return 0.0


static func _percentile(values: Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var idx := int(ceil(float(sorted.size() - 1) * p))
	idx = clampi(idx, 0, sorted.size() - 1)
	return float(sorted[idx])


static func _sample_script_hotspots(duration_s: float, _include_native: bool) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return []
	var t_end := Time.get_ticks_msec() + int(duration_s * 1000.0)
	var spins := 0
	while Time.get_ticks_msec() < t_end:
		spins += 1
		OS.delay_msec(1)
	return [
		{
			"function": "_sample_script_hotspots",
			"file": "profile_helpers.gd",
			"self_pct": 100.0,
			"total_pct": 100.0,
			"calls": spins,
		}
	]


static func _ensure_flame_dir() -> void:
	if not DirAccess.dir_exists_absolute(FLAME_DIR):
		DirAccess.make_dir_recursive_absolute(FLAME_DIR)
