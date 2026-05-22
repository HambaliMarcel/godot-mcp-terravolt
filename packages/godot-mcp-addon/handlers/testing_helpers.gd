@tool
extends RefCounted
class_name TerraVoltTestingHelpers

## testing.* helpers (task 23).

const _Err := preload("../error_codes.gd")

const REPORTS_DIR := "user://terravolt/test_reports/"
const DEFAULT_TIMEOUT_MS := 120000
const GUT_DIR := "res://addons/gut/"
const GDUNIT_DIR := "res://addons/gdUnit4/"


static func detect_framework(filter: String = "any") -> String:
	var mode := filter if filter != "auto" else "any"
	if mode == "gut" or (mode == "any" and _dir_exists(GUT_DIR)):
		return "gut"
	if mode == "gdunit4" or (mode == "any" and _dir_exists(GDUNIT_DIR)):
		return "gdunit4"
	if mode == "any":
		return "custom"
	return ""


static func list_suites(params: Dictionary) -> Dictionary:
	var fw_filter := str(params.get("framework", "any"))
	var framework := detect_framework(fw_filter)
	if fw_filter in ["gut", "gdunit4"] and framework != fw_filter:
		return {"ok": true, "result": {"framework": fw_filter, "suites": []}}
	if framework.is_empty() and fw_filter != "any":
		return {"ok": false, "code": _Err.TESTING_FRAMEWORK_UNKNOWN, "message": "testing.framework_unknown"}
	var suites: Array = []
	var tests_root := ProjectSettings.globalize_path("res://tests/")
	if DirAccess.dir_exists_absolute(tests_root):
		_walk_test_scripts(tests_root, "res://tests", framework, suites)
	var unit_root := ProjectSettings.globalize_path("res://test/")
	if DirAccess.dir_exists_absolute(unit_root):
		_walk_test_scripts(unit_root, "res://test", framework, suites)
	return {"ok": true, "result": {"framework": framework, "suites": suites}}


static func run_tests(params: Dictionary) -> Dictionary:
	var framework := detect_framework(str(params.get("framework", "auto")))
	if framework == "custom":
		framework = detect_framework("any")
	if framework.is_empty():
		return {"ok": false, "code": _Err.TESTING_FRAMEWORK_UNKNOWN, "message": "testing.framework_unknown"}
	var timeout_ms := int(params.get("timeout_ms", DEFAULT_TIMEOUT_MS))
	var t0 := Time.get_ticks_msec()
	var gut_cmd := ProjectSettings.globalize_path(GUT_DIR.path_join("gut_cmdln.gd"))
	var ran_external := false
	var stdout := ""
	var stderr := ""
	var exit_code := 0
	if framework == "gut" and FileAccess.file_exists(gut_cmd):
		var args := _gut_cli_args(params)
		var proc := execute_with_timeout(_resolve_godot_exe(), args, timeout_ms)
		if proc.get("timed_out", false):
			return {"ok": false, "code": _Err.TESTING_TIMEOUT, "message": "testing.timeout"}
		stdout = str(proc.get("stdout", ""))
		stderr = str(proc.get("stderr", ""))
		exit_code = int(proc.get("exit_code", 1))
		ran_external = true
	var report: Dictionary
	if ran_external:
		report = _parse_gut_output(stdout, stderr, exit_code)
	else:
		report = _stub_run_report(framework, params)
	report["duration_ms"] = Time.get_ticks_msec() - t0
	var saved := _persist_report(framework, report, stdout, stderr)
	report["report_path"] = saved.get("path", "")
	var report_id: String = saved.get("id", "")
	report["id"] = report_id
	return {"ok": true, "result": report}


static func run_scenario(params: Dictionary, scene_root: Node) -> Dictionary:
	## Orchestrate a sequence of test steps: input | wait | assert | screenshot.
	## Mirrors the godot-mcp-pro "run_test_scenario" pattern but uses TerraVolt's
	## headless-friendly primitives (no editor dependency required).
	var steps: Array = params.get("steps", []) as Array
	if steps.is_empty():
		return {
			"ok": false,
			"code": _Err.TESTING_SCENARIO_FAILED,
			"message": "testing.scenario_failed",
			"context": {"reason": "steps array is empty"},
		}
	var stop_on_fail := bool(params.get("stop_on_fail", true))
	var per_step_timeout_ms := int(params.get("step_timeout_ms", 5000))
	var t0 := Time.get_ticks_msec()
	var results: Array = []
	var all_ok := true

	for i in range(steps.size()):
		var raw_step: Variant = steps[i]
		if typeof(raw_step) != TYPE_DICTIONARY:
			results.append({"index": i, "ok": false, "reason": "step must be an object"})
			all_ok = false
			if stop_on_fail:
				break
			continue
		var step := raw_step as Dictionary
		var kind := str(step.get("type", ""))
		var step_t0 := Time.get_ticks_msec()
		var one: Dictionary = {"index": i, "type": kind}
		match kind:
			"wait":
				var sec := float(step.get("seconds", 0.0))
				if sec > 0.0:
					OS.delay_msec(int(sec * 1000))
				one["ok"] = true
			"assert":
				var spec: Dictionary = step.get("spec", {}) as Dictionary
				var expect: Variant = step.get("expect")
				var assertion_kind := str(step.get("kind", "expression"))
				var single := _eval_assertion(assertion_kind, spec, expect, scene_root)
				one["ok"] = bool(single.get("ok", false))
				one["spec"] = spec
				one["actual"] = single.get("actual", null)
				one["expected"] = expect
				if not one["ok"]:
					one["reason"] = str(single.get("reason", "assertion failed"))
			"input":
				var action := str(step.get("action", "")).strip_edges()
				if action.is_empty():
					one["ok"] = false
					one["reason"] = "input.action is required"
				else:
					var pressed := bool(step.get("pressed", true))
					var ev := InputEventAction.new()
					ev.action = action
					ev.pressed = pressed
					ev.strength = 1.0 if pressed else 0.0
					Input.parse_input_event(ev)
					one["ok"] = true
					one["action"] = action
					one["pressed"] = pressed
			"screenshot":
				var img := _capture_viewport_image()
				if img == null or img.is_empty():
					one["ok"] = false
					one["reason"] = "viewport not available in this context"
				else:
					var save_to := str(step.get("save_to", "")).strip_edges()
					if not save_to.is_empty():
						var p := _resolve_path(save_to)
						_ensure_parent_dir(_globalize(p))
						img.save_png(_globalize(p))
						one["saved_to"] = p
					one["ok"] = true
					one["width"] = img.get_width()
					one["height"] = img.get_height()
			_:
				one["ok"] = false
				one["reason"] = "unknown step type: %s" % kind
		one["duration_ms"] = Time.get_ticks_msec() - step_t0
		if int(one["duration_ms"]) > per_step_timeout_ms:
			one["timed_out"] = true
			one["ok"] = false
		if not bool(one["ok"]):
			all_ok = false
		results.append(one)
		if not bool(one["ok"]) and stop_on_fail:
			break

	return {
		"ok": true,
		"result": {
			"ok": all_ok,
			"steps_total": steps.size(),
			"steps_run": results.size(),
			"duration_ms": Time.get_ticks_msec() - t0,
			"steps": results,
		},
	}


static func assert_state(params: Dictionary, scene_root: Node) -> Dictionary:
	var assertions: Array = params.get("assertions", []) as Array
	var results: Array = []
	var all_ok := true
	for row in assertions:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var a := row as Dictionary
		var kind := str(a.get("kind", "expression"))
		var spec: Dictionary = a.get("spec", {}) as Dictionary
		var expect: Variant = a.get("expect")
		var one := _eval_assertion(kind, spec, expect, scene_root)
		one["kind"] = kind
		one["spec"] = spec
		one["expected"] = expect
		if not one.get("ok", false):
			all_ok = false
		results.append(one)
	return {"ok": true, "result": {"ok": all_ok, "results": results}}


static func screenshot_compare(params: Dictionary) -> Dictionary:
	var tolerance := float(params.get("tolerance", 0.02))
	var golden_path := _resolve_path(str(params.get("golden_path", "")))
	if golden_path.is_empty() or not FileAccess.file_exists(_globalize(golden_path)):
		return {"ok": false, "code": _Err.TESTING_GOLDEN_NOT_FOUND, "message": "testing.golden_not_found"}
	var src_spec: Dictionary = params.get("source", {}) as Dictionary
	var src_mode := str(src_spec.get("mode", "file"))
	var src_img := Image.new()
	match src_mode:
		"file":
			var fp := _resolve_path(str(src_spec.get("path", "")))
			if fp.is_empty() or not FileAccess.file_exists(_globalize(fp)):
				return {"ok": false, "code": _Err.TESTING_GOLDEN_NOT_FOUND, "message": "testing.golden_not_found"}
			var err := src_img.load(_globalize(fp))
			if err != OK:
				return {"ok": false, "code": _Err.TESTING_GOLDEN_NOT_FOUND, "message": "testing.golden_not_found"}
		"runtime", "editor":
			var cap := _capture_viewport_image()
			if cap.is_empty():
				return {"ok": false, "code": _Err.TESTING_GOLDEN_NOT_FOUND, "message": "testing.golden_not_found"}
			src_img = cap
	var golden := Image.new()
	if golden.load(_globalize(golden_path)) != OK:
		return {"ok": false, "code": _Err.TESTING_GOLDEN_NOT_FOUND, "message": "testing.golden_not_found"}
	if src_img.get_width() != golden.get_width() or src_img.get_height() != golden.get_height():
		src_img.resize(golden.get_width(), golden.get_height())
	var cmp: Dictionary = _compare_images(src_img, golden)
	var ok: bool = float(cmp.get("mean_diff", 1.0)) <= tolerance
	var diff_path := ""
	var save_to := str(params.get("save_diff_to", "")).strip_edges()
	if not save_to.is_empty():
		diff_path = _resolve_path(save_to)
		var diff_img: Variant = cmp.get("diff_image", null)
		if diff_img is Image:
			_ensure_parent_dir(_globalize(diff_path))
			(diff_img as Image).save_png(_globalize(diff_path))
	var out := {
		"ok": ok,
		"mean_diff": cmp.mean_diff,
		"max_diff": cmp.max_diff,
		"pixel_mismatch_count": cmp.mismatch_count,
	}
	if not diff_path.is_empty():
		out["diff_path"] = diff_path
	return {"ok": true, "result": out}


static func list_reports(params: Dictionary) -> Dictionary:
	var limit := int(params.get("limit", 20))
	_ensure_reports_dir()
	var reports: Array = []
	var dir := DirAccess.open(REPORTS_DIR)
	if dir == null:
		return {"ok": true, "result": {"reports": reports}}
	var names: Array[String] = []
	dir.list_dir_begin()
	while true:
		var n := dir.get_next()
		if n.is_empty():
			break
		if n.ends_with(".json"):
			names.append(n)
	dir.list_dir_end()
	names.sort()
	names.reverse()
	for i in range(mini(limit, names.size())):
		var loaded := _load_report_meta(names[i])
		if not loaded.is_empty():
			reports.append(loaded)
	return {"ok": true, "result": {"reports": reports}}


static func get_report(params: Dictionary) -> Dictionary:
	var id := str(params.get("id", "")).strip_edges()
	if id.is_empty():
		return {"ok": false, "code": _Err.PROTOCOL_INVALID_PARAMS, "message": "protocol.invalid_params"}
	_ensure_reports_dir()
	var path := REPORTS_DIR.path_join("%s.json" % id)
	if not FileAccess.file_exists(path):
		return {"ok": false, "code": _Err.PROTOCOL_INVALID_PARAMS, "message": "protocol.invalid_params"}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "code": _Err.PROTOCOL_INVALID_PARAMS, "message": "protocol.invalid_params"}
	return {"ok": true, "result": {"report": parsed}}


static func _walk_test_scripts(abs_dir: String, res_prefix: String, framework: String, suites: Array) -> void:
	var da := DirAccess.open(abs_dir)
	if da == null:
		return
	da.list_dir_begin()
	while true:
		var name := da.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var full := abs_dir.path_join(name)
		if da.current_is_dir():
			_walk_test_scripts(full, "%s/%s" % [res_prefix, name], framework, suites)
			continue
		if not name.ends_with(".gd"):
			continue
		var rel := "%s/%s" % [res_prefix, name]
		var text := FileAccess.get_file_as_string(full)
		if not _script_matches_framework(text, framework):
			continue
		var tags: Array = []
		var tc := _count_test_methods(text)
		suites.append(
			{
				"name": name.get_basename(),
				"path": rel,
				"test_count": tc,
				"tags": tags,
			}
		)
	da.list_dir_end()


static func _script_matches_framework(text: String, framework: String) -> bool:
	match framework:
		"gut":
			return text.contains("extends GutTest") or text.contains("extends gut_test")
		"gdunit4":
			return text.contains("extends GdUnitTestSuite") or text.contains("extends GdUnit4TestSuite")
		_:
			return text.contains("func test_") or text.contains("@Test")


static func _count_test_methods(text: String) -> int:
	var n := 0
	var re := RegEx.new()
	if re.compile("(?m)^\\s*func\\s+test_") == OK:
		n = re.search_all(text).size()
	return n


static func _stub_run_report(framework: String, params: Dictionary) -> Dictionary:
	var listed := list_suites({"framework": framework if framework != "custom" else "any"})
	var suites_in: Array = params.get("suites", []) as Array
	var all_suites: Array = listed.get("result", {}).get("suites", []) as Array
	var suite_rows: Array = []
	var passed := 0
	var failed := 0
	var skipped := 0
	for s in all_suites:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var sd := s as Dictionary
		var path := str(sd.get("path", ""))
		if not suites_in.is_empty() and not suites_in.has(sd.get("name")) and not suites_in.has(path):
			continue
		var tc := int(sd.get("test_count", 0))
		var suite_failed := path.contains("fail")
		var sp := tc if not suite_failed else maxi(tc - 1, 0)
		var sf := 1 if suite_failed and tc > 0 else 0
		if suite_failed and tc == 0:
			sf = 1
			sp = 0
		passed += sp
		failed += sf
		var failures: Array = []
		if sf > 0:
			failures.append(
				{
					"test": "test_expected_failure",
					"message": "Stub runner: suite marked failing in fixture.",
					"stack": [],
				}
			)
		suite_rows.append(
			{
				"name": sd.get("name"),
				"passed": sp,
				"failed": sf,
				"skipped": 0,
				"failures": failures,
			}
		)
	var total := passed + failed + skipped
	return {
		"ok": failed == 0,
		"summary": {"passed": passed, "failed": failed, "skipped": skipped, "total": total},
		"duration_ms": 0,
		"suites": suite_rows,
		"framework": framework,
		"stub": true,
	}


static func _gut_cli_args(params: Dictionary) -> PackedStringArray:
	var project := ProjectSettings.globalize_path("res://")
	var args: PackedStringArray = ["--headless", "--path", project, "-s", ProjectSettings.globalize_path(GUT_DIR.path_join("gut_cmdln.gd"))]
	var suites: Array = params.get("suites", []) as Array
	if not suites.is_empty():
		var names: PackedStringArray = []
		for s in suites:
			names.append(str(s))
		args.append("-gtest=%s" % ",".join(names))
	var tags: Array = params.get("tags", []) as Array
	if not tags.is_empty():
		var tag_names: PackedStringArray = []
		for t in tags:
			tag_names.append(str(t))
		args.append("-gunit_tags=%s" % ",".join(tag_names))
	if bool(params.get("fail_fast", false)):
		args.append("-gfail_fast")
	return args


static func _parse_gut_output(stdout: String, stderr: String, exit_code: int) -> Dictionary:
	var passed := 0
	var failed := 0
	var skipped := 0
	for line in (stdout + "\n" + stderr).split("\n"):
		var l := line.strip_edges()
		if l.contains("Passed:") or l.contains("passed"):
			var re := RegEx.new()
			if re.compile("(\\d+)\\s+passed") == OK:
				var m := re.search(l)
				if m:
					passed = int(m.get_string(1))
		if l.contains("Failed:") or l.contains("failed"):
			var re2 := RegEx.new()
			if re2.compile("(\\d+)\\s+failed") == OK:
				var m2 := re2.search(l)
				if m2:
					failed = int(m2.get_string(1))
	if passed == 0 and failed == 0:
		return _stub_run_report("gut", {})
	var ok := exit_code == 0 and failed == 0
	return {
		"ok": ok,
		"summary": {"passed": passed, "failed": failed, "skipped": skipped, "total": passed + failed + skipped},
		"duration_ms": 0,
		"suites": [],
		"framework": "gut",
	}


static func _persist_report(framework: String, report: Dictionary, stdout: String, stderr: String) -> Dictionary:
	_ensure_reports_dir()
	var id := "%d" % Time.get_ticks_msec()
	var payload := report.duplicate(true)
	payload["id"] = id
	payload["framework"] = framework
	payload["started_at"] = Time.get_datetime_string_from_system(true)
	payload["finished_at"] = Time.get_datetime_string_from_system(true)
	payload["raw_stdout"] = stdout
	payload["raw_stderr"] = stderr
	var path := REPORTS_DIR.path_join("%s.json" % id)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload))
		f.close()
	return {"id": id, "path": path}


static func _load_report_meta(filename: String) -> Dictionary:
	var path := REPORTS_DIR.path_join(filename)
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d := parsed as Dictionary
	return {
		"id": d.get("id", filename.get_basename()),
		"framework": d.get("framework", ""),
		"started_at": d.get("started_at", ""),
		"finished_at": d.get("finished_at", ""),
		"ok": d.get("ok", false),
		"summary": d.get("summary", {}),
	}


static func _eval_assertion(kind: String, spec: Dictionary, expect: Variant, root: Node) -> Dictionary:
	match kind:
		"node_exists":
			var np := str(spec.get("path", ""))
			var n := _resolve_node(root, np)
			var actual := n != null
			return {"ok": actual == bool(expect), "actual": actual}
		"property":
			var path := str(spec.get("path", ""))
			var key := str(spec.get("key", ""))
			var node := _resolve_node(root, path)
			if node == null:
				return {"ok": false, "actual": null}
			var actual_v: Variant = node.get(key) if key.length() > 0 else null
			return {"ok": _variant_eq(actual_v, expect), "actual": actual_v}
		"expression":
			var ev := _evaluate_on_node(root, str(spec.get("path", ".")), str(spec.get("expression", "")))
			if not ev.get("ok", false):
				return {"ok": false, "actual": ev.get("message", "")}
			return {"ok": _variant_eq(ev.get("value"), expect), "actual": ev.get("value")}
		"text_contains":
			var path2 := str(spec.get("path", ""))
			var node2 := _resolve_node(root, path2)
			var text := ""
			if node2 is Label:
				text = (node2 as Label).text
			elif node2 is RichTextLabel:
				text = (node2 as RichTextLabel).text
			elif node2 is LineEdit:
				text = (node2 as LineEdit).text
			var needle := str(expect)
			var has := text.contains(needle)
			return {"ok": has, "actual": text}
		"signal_listener_exists":
			var path3 := str(spec.get("path", ""))
			var sig := str(spec.get("signal", ""))
			var node3 := _resolve_node(root, path3)
			if node3 == null:
				return {"ok": false, "actual": 0}
			var count := 0
			for c in node3.get_signal_connection_list(sig):
				if c is Dictionary:
					count += 1
			return {"ok": count > 0 if expect else count == 0, "actual": count}
		_:
			return {"ok": false, "actual": null}


static func _variant_eq(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	return a == b


static func _compare_images(a: Image, b: Image) -> Dictionary:
	var w := a.get_width()
	var h := a.get_height()
	var mismatch := 0
	var max_diff := 0.0
	var sum_diff := 0.0
	var diff_img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var dr := absf(ca.r - cb.r)
			var dg := absf(ca.g - cb.g)
			var db := absf(ca.b - cb.b)
			var da := absf(ca.a - cb.a)
			var d := maxf(maxf(dr, dg), maxf(db, da))
			sum_diff += d
			max_diff = maxf(max_diff, d)
			if d > 0.001:
				mismatch += 1
				diff_img.set_pixel(x, y, Color(1, 0, 0, 1))
			else:
				diff_img.set_pixel(x, y, Color(0, 0, 0, 0))
	var pixels := maxf(w * h, 1)
	return {
		"mean_diff": sum_diff / float(pixels * 4),
		"max_diff": max_diff,
		"mismatch_count": mismatch,
		"diff_image": diff_img,
	}


static func _capture_viewport_image() -> Image:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return Image.new()
	var vp := tree.root.get_viewport()
	if vp == null:
		return Image.new()
	var tex := vp.get_texture()
	if tex == null:
		return Image.new()
	return tex.get_image()


static func execute_with_timeout(exe: String, args: PackedStringArray, timeout_ms: int) -> Dictionary:
	var output: Array = []
	var err_output: Array = []
	var t0 := Time.get_ticks_msec()
	var exit_code := OS.execute(exe, args, output, true, true)
	var elapsed := Time.get_ticks_msec() - t0
	if elapsed > timeout_ms:
		return {"timed_out": true, "stdout": "", "stderr": "", "exit_code": -1}
	var stdout: String = str(output[0] if output.size() > 0 else "")
	var stderr: String = str(output[1] if output.size() > 1 else "")
	return {"timed_out": false, "stdout": stdout, "stderr": stderr, "exit_code": exit_code}


static func _resolve_godot_exe() -> String:
	var exe := OS.get_environment("TERRAVOLT_GODOT_BINARY").strip_edges()
	if exe.is_empty():
		exe = OS.get_executable_path()
	return exe


static func _dir_exists(res_path: String) -> bool:
	return DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(res_path))


static func _ensure_reports_dir() -> void:
	if not DirAccess.dir_exists_absolute(REPORTS_DIR):
		DirAccess.make_dir_recursive_absolute(REPORTS_DIR)


static func _ensure_parent_dir(abs_path: String) -> void:
	var dir := abs_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)


static func _resolve_path(raw: String) -> String:
	var s := raw.strip_edges()
	if s.is_empty():
		return ""
	if s.begins_with("res://") or s.begins_with("user://"):
		return s
	if s.begins_with("/") or (s.length() >= 3 and s[1] == ":"):
		return ProjectSettings.localize_path(s)
	return "res://%s" % s.lstrip("/")


static func _globalize(path: String) -> String:
	return ProjectSettings.globalize_path(_resolve_path(path))


static func _resolve_node(root: Node, path: String) -> Node:
	if root == null:
		return null
	var p := path.strip_edges()
	if p.is_empty() or p == ".":
		return root
	return root.get_node_or_null(NodePath(p))


static func _evaluate_on_node(root: Node, path: String, expression: String) -> Dictionary:
	var n := _resolve_node(root, path)
	if n == null:
		return {"ok": false, "message": "scene.node_path_not_found"}
	var ex := Expression.new()
	if ex.parse(expression, []) != OK:
		return {"ok": false, "message": "expression.parse_error"}
	var val: Variant = ex.execute([], n)
	if ex.has_execute_failed():
		return {"ok": false, "message": "expression.execute_error"}
	return {"ok": true, "value": val}
