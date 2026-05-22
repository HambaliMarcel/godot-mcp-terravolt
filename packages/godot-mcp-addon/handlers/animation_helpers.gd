@tool
extends RefCounted
class_name TerravoltAnimationHelpers

const _Res := preload("./resource_helpers.gd")
const _Err := preload("../error_codes.gd")

const TRACK_MAX_KEYS_INLINE := 256
const DEFAULT_BLEND_SECONDS := 0.15

const TRACK_TYPE_MAP := {
	"value": Animation.TYPE_VALUE,
	"position3d": Animation.TYPE_POSITION_3D,
	"rotation3d": Animation.TYPE_ROTATION_3D,
	"scale3d": Animation.TYPE_SCALE_3D,
	"method": Animation.TYPE_METHOD,
	"audio": Animation.TYPE_AUDIO,
	"bezier": Animation.TYPE_BEZIER,
	"blend_shape": Animation.TYPE_BLEND_SHAPE,
	"animation": Animation.TYPE_ANIMATION,
}

const LOOP_MODE_MAP := {
	"none": Animation.LOOP_NONE,
	"linear": Animation.LOOP_LINEAR,
	"pingpong": Animation.LOOP_PINGPONG,
}


static func loop_mode_to_string(mode: int) -> String:
	match mode:
		Animation.LOOP_LINEAR:
			return "linear"
		Animation.LOOP_PINGPONG:
			return "pingpong"
		_:
			return "none"


static func revision_tag() -> String:
	return str(Time.get_ticks_msec())


static func resolve_player(root: Node, player_path: String) -> AnimationPlayer:
	if root == null:
		return null
	var p := player_path.strip_edges()
	if p.is_empty():
		return null
	if p == "." or p == "/":
		if root is AnimationPlayer:
			return root as AnimationPlayer
		return null
	var n := root.get_node_or_null(NodePath(p))
	return n as AnimationPlayer if n is AnimationPlayer else null


static func resolve_tree(root: Node, tree_path: String) -> AnimationTree:
	if root == null:
		return null
	var n := root.get_node_or_null(NodePath(tree_path.strip_edges()))
	return n as AnimationTree if n is AnimationTree else null


static func animation_entry(player: AnimationPlayer, lib_name: String, anim_name: String) -> Dictionary:
	var anim := player.get_animation(anim_name)
	if anim == null:
		return {}
	return {
		"name": anim_name,
		"length": anim.length,
		"step": anim.step,
		"loop_mode": loop_mode_to_string(anim.loop_mode),
		"library": lib_name,
	}


static func list_players_in_root(root: Node, base_path: String = "") -> Array:
	var players: Array = []
	if root is AnimationPlayer:
		players.append({"node": root, "path": base_path if not base_path.is_empty() else "."})
	for ch in root.get_children():
		var rel := "%s/%s" % [base_path, ch.name] if not base_path.is_empty() else str(ch.name)
		for row in list_players_in_root(ch, rel):
			players.append(row)
	return players


static func list_animations(scope: String, scene_path: String, active_root: Node) -> Dictionary:
	var scenes: Array = []
	if scope == "project":
		scenes = _walk_scene_paths()
	elif scope == "active":
		if active_root != null:
			var players := list_players_in_root(active_root)
			return _players_payload(players)
		var main := str(ProjectSettings.get_setting("application/run/main_scene", ""))
		if not main.is_empty():
			scenes.append(main)
	else:
		scenes.append(_Res.resolve_path(scene_path if not scene_path.is_empty() else scope))
	var out_players: Array = []
	for sp in scenes:
		var path := str(sp)
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var ps: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if ps == null:
			continue
		var inst := ps.instantiate()
		if inst == null:
			continue
		for row in list_players_in_root(inst):
			var node: AnimationPlayer = row["node"]
			out_players.append(_player_row(node, str(row["path"]), path))
		inst.queue_free()
	return {"players": out_players}


static func _players_payload(rows: Array) -> Dictionary:
	var out: Array = []
	for row in rows:
		var node: AnimationPlayer = row["node"]
		out.append(_player_row(node, str(row["path"])))
	return {"players": out}


static func _player_row(node: AnimationPlayer, rel_path: String, scene: String = "") -> Dictionary:
	var anims: Array = []
	var lib_count := 0
	for lib_name in node.get_animation_library_list():
		lib_count += 1
		var lib: AnimationLibrary = node.get_animation_library(lib_name)
		if lib == null:
			continue
		for anim_name in lib.get_animation_list():
			var anim := lib.get_animation(anim_name)
			if anim == null:
				continue
			anims.append(
				{
					"name": anim_name,
					"length": anim.length,
					"step": anim.step,
					"loop_mode": loop_mode_to_string(anim.loop_mode),
					"library": lib_name,
				}
			)
	var row := {"path": rel_path, "library_count": lib_count, "animations": anims}
	if not scene.is_empty():
		row["scene"] = scene
	return row


static func _walk_scene_paths() -> Array:
	var out: Array = []
	var base := ProjectSettings.globalize_path("res://")
	_collect_scene_paths(base, base, out)
	out.sort_custom(func(a, b): return str(a) < str(b))
	return out


static func _collect_scene_paths(base: String, dir_abs: String, out: Array) -> void:
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
			_collect_scene_paths(base, full, out)
			continue
		if name.ends_with(".tscn") or name.ends_with(".scn"):
			var rel := full.substr(base.length()).replace("\\", "/").lstrip("/")
			out.append("res://%s" % rel)
	da.list_dir_end()


static func get_animation_on_player(player: AnimationPlayer, anim_name: String, library: String) -> Dictionary:
	if player == null:
		return {"ok": false, "code": _Err.ANIMATION_PLAYER_NOT_FOUND}
	var lib_name := library.strip_edges()
	if lib_name.is_empty():
		if player.has_animation(anim_name):
			return {"ok": true, "animation": player.get_animation(anim_name), "library": ""}
		for ln in player.get_animation_library_list():
			var lib0: AnimationLibrary = player.get_animation_library(ln)
			if lib0 != null and lib0.has_animation(anim_name):
				return {"ok": true, "animation": lib0.get_animation(anim_name), "library": ln}
		return {"ok": false, "code": _Err.ANIMATION_UNKNOWN}
	if not player.has_animation_library(lib_name):
		return {"ok": false, "code": _Err.ANIMATION_UNKNOWN}
	var lib: AnimationLibrary = player.get_animation_library(lib_name)
	if lib == null or not lib.has_animation(anim_name):
		return {"ok": false, "code": _Err.ANIMATION_UNKNOWN}
	return {"ok": true, "animation": lib.get_animation(anim_name), "library": lib_name}


static func create_animation(
	player: AnimationPlayer,
	library: String,
	name: String,
	length: float,
	step: float,
	loop_mode: String
) -> Dictionary:
	var lib_name := library
	if lib_name.is_empty():
		lib_name = ""
	var lib: AnimationLibrary = null
	if player.has_animation_library(lib_name):
		lib = player.get_animation_library(lib_name)
	else:
		lib = AnimationLibrary.new()
		player.add_animation_library(lib_name, lib)
	if lib.has_animation(name):
		return {"ok": false, "code": _Err.ANIMATION_NAME_EXISTS}
	var anim := Animation.new()
	anim.length = maxf(0.01, length)
	anim.step = maxf(0.001, step)
	anim.loop_mode = int(LOOP_MODE_MAP.get(loop_mode, Animation.LOOP_NONE))
	lib.add_animation(name, anim)
	return {
		"ok": true,
		"result": {
			"created": true,
			"player_path": "",
			"library": lib_name,
			"name": name,
			"state": {"length": anim.length, "step": anim.step, "loop_mode": loop_mode_to_string(anim.loop_mode)},
			"revision": revision_tag(),
		},
	}


static func add_track(anim: Animation, track: Dictionary, index: int = -1) -> Dictionary:
	var type_key := str(track.get("type", ""))
	if not TRACK_TYPE_MAP.has(type_key):
		return {"ok": false, "code": _Err.ANIMATION_TRACK_KIND_UNKNOWN}
	var track_type: int = TRACK_TYPE_MAP[type_key]
	var track_path := NodePath(str(track.get("path", "")))
	var key_str := str(track.get("key", ""))
	var idx := anim.add_track(track_type, index)
	if track_type == Animation.TYPE_VALUE and not key_str.is_empty():
		anim.track_set_path(idx, NodePath("%s:%s" % [track_path, key_str]))
	else:
		anim.track_set_path(idx, track_path)
	return {"ok": true, "result": {"track_index": idx, "state": {"type": type_key}, "revision": revision_tag()}}


static func _transition_from_string(name: String) -> int:
	match name:
		"in":
			return Tween.TRANS_QUAD
		"out":
			return Tween.TRANS_QUAD
		"in_out":
			return Tween.TRANS_QUAD
		"cubic":
			return Tween.TRANS_CUBIC
		"bezier":
			return Tween.TRANS_LINEAR
		_:
			return Tween.TRANS_LINEAR


static func set_keyframes(anim: Animation, track_index: int, keys: Array, mode: String) -> Dictionary:
	if track_index < 0 or track_index >= anim.get_track_count():
		return {"ok": false, "code": _Err.ANIMATION_UNKNOWN}
	var inserted := 0
	var updated := 0
	var removed := 0
	if mode == "replace_all":
		while anim.track_get_key_count(track_index) > 0:
			anim.track_remove_key(track_index, 0)
			removed += 1
	for row_v in keys:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row := row_v as Dictionary
		var t := float(row.get("time", 0.0))
		var value: Variant = row.get("value")
		var trans := _transition_from_string(str(row.get("transition", "linear")))
		var existing := anim.track_find_key(track_index, t, Animation.FIND_MODE_NEAREST)
		if existing >= 0:
			anim.track_set_key_value(track_index, existing, value)
			updated += 1
		else:
			anim.track_insert_key(track_index, t, value, trans)
			inserted += 1
	return {
		"ok": true,
		"result": {"inserted": inserted, "updated": updated, "removed": removed, "revision": revision_tag()},
	}


static func play(player: AnimationPlayer, params: Dictionary) -> Dictionary:
	var action := str(params.get("action", "play"))
	var anim_name := str(params.get("name", ""))
	var library := str(params.get("library", ""))
	var blend := float(params.get("custom_blend", DEFAULT_BLEND_SECONDS))
	var from_end := bool(params.get("from_end", false))
	match action:
		"stop":
			player.stop()
		"pause":
			player.pause()
		"play_backwards":
			if anim_name.is_empty():
				player.play_backwards()
			else:
				player.play_backwards(anim_name, blend)
		"queue":
			if anim_name.is_empty():
				return {"ok": false, "code": _Err.ANIMATION_UNKNOWN}
			player.queue(anim_name)
		_:
			if anim_name.is_empty():
				player.play()
			else:
				player.play(anim_name, blend, from_end)
	return {"ok": true, "result": {"done": true, "current_animation": player.current_animation}}


static func preview_export(player: AnimationPlayer, anim_name: String, format: String, _fps: int, duration_s: float) -> Dictionary:
	var got := get_animation_on_player(player, anim_name, "")
	if not got.get("ok", false):
		return got
	var anim: Animation = got["animation"]
	var dur := duration_s if duration_s > 0.0 else anim.length
	var out_dir := "user://terravolt_exports/%s_%d" % [anim_name, Time.get_ticks_msec()]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var frames_dir := out_dir.path_join("frames")
	DirAccess.make_dir_recursive_absolute(frames_dir)
	player.play(anim_name)
	player.advance(dur * 0.5)
	var placeholder := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	placeholder.fill(Color(0.2, 0.4, 0.8))
	var frame_path := "%s/frame_0000.png" % frames_dir
	placeholder.save_png(frame_path)
	player.stop()
	if (format == "gif" or format == "mp4") and _find_ffmpeg().is_empty():
		var manifest := out_dir.path_join("frames.txt")
		var mf := FileAccess.open(manifest, FileAccess.WRITE)
		if mf:
			mf.store_line("format=png_sequence")
			mf.store_line("dir=%s" % frames_dir)
			mf.store_line("duration_s=%s" % dur)
			mf.close()
		return {
			"ok": false,
			"code": _Err.ANIMATION_EXPORTER_MISSING,
			"manifest": manifest,
			"frames_dir": frames_dir,
		}
	var export_path := frame_path if format == "gif" else frames_dir
	return {
		"ok": true,
		"result": {
			"exported": true,
			"path": export_path,
			"format": format if _find_ffmpeg().length() > 0 else "png_sequence",
			"size_bytes": FileAccess.get_file_as_bytes(frame_path).size(),
		},
	}


static func _find_ffmpeg() -> String:
	var env := OS.get_environment("FFMPEG_PATH")
	if not env.is_empty() and FileAccess.file_exists(env):
		return env
	return ""


static func _dir_size(dir_path: String) -> int:
	var total := 0
	var da := DirAccess.open(dir_path)
	if da == null:
		return 0
	da.list_dir_begin()
	while true:
		var name := da.get_next()
		if name.is_empty():
			break
		if da.current_is_dir():
			continue
		total += FileAccess.get_file_as_bytes(dir_path.path_join(name)).size()
	da.list_dir_end()
	return total


static func state_machine_root(tree: AnimationTree) -> AnimationNodeStateMachine:
	var root := tree.tree_root
	return root as AnimationNodeStateMachine if root is AnimationNodeStateMachine else null


static func describe_tree(tree: AnimationTree) -> Dictionary:
	var out := {
		"root_kind": _node_kind_name(tree.tree_root),
		"parameters": _tree_parameters(tree),
		"active": tree.active,
	}
	var sm := state_machine_root(tree)
	if sm != null:
		out["states"] = _state_machine_states(sm)
		var playback := _state_machine_playback(tree, sm)
		if playback != null:
			out["active_state"] = playback.get_current_node()
	return out


static func _node_kind_name(node: AnimationNode) -> String:
	if node == null:
		return "Unknown"
	if node is AnimationNodeBlendTree:
		return "BlendTree"
	if node is AnimationNodeStateMachine:
		return "StateMachine"
	if node is AnimationNodeBlendSpace2D:
		return "BlendSpace2D"
	if node is AnimationNodeBlendSpace1D:
		return "BlendSpace1D"
	if node is AnimationNodeAnimation:
		return "Animation"
	return node.get_class()


static func _tree_parameters(tree: AnimationTree) -> Array:
	var out: Array = []
	for info in tree.get_parameter_list():
		if typeof(info) != TYPE_DICTIONARY:
			continue
		var pd := info as Dictionary
		var param_name := str(pd.get("name", ""))
		if param_name.is_empty():
			continue
		out.append(
			{
				"name": param_name,
				"type": str(pd.get("type", TYPE_NIL)),
				"default": tree.get_parameter_default_value(param_name),
			}
		)
	return out


static func _state_machine_states(sm: AnimationNodeStateMachine) -> Array:
	var states: Array = []
	for state_name in sm.get_state_list():
		var node := sm.get_node(state_name)
		var anim_name: Variant = null
		if node is AnimationNodeAnimation:
			anim_name = (node as AnimationNodeAnimation).animation
		var transitions: Array = []
		for i in sm.get_transition_count():
			var from_name := sm.get_transition_from(i)
			var to_name := sm.get_transition_to(i)
			if from_name != state_name:
				continue
			var tr: AnimationNodeStateMachineTransition = sm.get_transition(i)
			transitions.append(
				{
					"to": to_name,
					"condition": str(tr.advance_condition) if tr else "",
					"advance_mode": tr.advance_mode if tr else 0,
				}
			)
		states.append({"name": state_name, "animation": anim_name, "transitions": transitions})
	return states


static func _state_machine_playback(tree: AnimationTree, sm: AnimationNodeStateMachine) -> AnimationNodeStateMachinePlayback:
	for info in tree.get_parameter_list():
		if typeof(info) != TYPE_DICTIONARY:
			continue
		var param_name := str((info as Dictionary).get("name", ""))
		if not param_name.ends_with("/playback"):
			continue
		var val: Variant = tree.get_parameter(param_name)
		if val is AnimationNodeStateMachinePlayback:
			return val
	return null


static func set_tree_active(tree: AnimationTree, active: bool) -> Dictionary:
	tree.active = active
	return {"ok": true, "result": {"active": tree.active}}


static func set_tree_parameter(tree: AnimationTree, parameter: String, value: Variant, mode: String) -> Dictionary:
	var before: Variant = null
	if tree.get_parameter_list().size() > 0:
		for info in tree.get_parameter_list():
			if typeof(info) != TYPE_DICTIONARY:
				continue
			if str((info as Dictionary).get("name", "")) == parameter:
				before = tree.get_parameter(parameter)
				break
	if before == null and not _tree_has_parameter(tree, parameter):
		return {"ok": false, "code": _Err.ANIMATION_TREE_PARAMETER_UNKNOWN}
	if mode == "travel":
		var playback: Variant = tree.get_parameter(parameter)
		if playback is AnimationNodeStateMachinePlayback:
			(playback as AnimationNodeStateMachinePlayback).travel(str(value))
			return {
				"ok": true,
				"result": {"set": true, "parameter": parameter, "before": before, "after": str(value)},
			}
		return {"ok": false, "code": _Err.ANIMATION_TREE_PARAMETER_UNKNOWN}
	if mode == "advance":
		var pb: Variant = tree.get_parameter(parameter)
		if pb is AnimationNodeStateMachinePlayback:
			(pb as AnimationNodeStateMachinePlayback).advance(float(value))
			return {"ok": true, "result": {"set": true, "parameter": parameter, "before": before, "after": value}}
		tree.set_parameter(parameter, value)
	return {"ok": true, "result": {"set": true, "parameter": parameter, "before": before, "after": tree.get_parameter(parameter)}}


static func _tree_has_parameter(tree: AnimationTree, parameter: String) -> bool:
	for info in tree.get_parameter_list():
		if typeof(info) != TYPE_DICTIONARY:
			continue
		if str((info as Dictionary).get("name", "")) == parameter:
			return true
	return false


static func add_state(tree: AnimationTree, state: Dictionary) -> Dictionary:
	var sm := state_machine_root(tree)
	if sm == null:
		return {"ok": false, "code": _Err.ANIMATION_TREE_NOT_FOUND}
	var state_name := str(state.get("name", ""))
	if sm.has_node(state_name):
		return {"ok": false, "code": _Err.ANIMATION_TREE_STATE_EXISTS}
	var sub := AnimationNodeAnimation.new()
	var anim_name := str(state.get("animation", ""))
	if not anim_name.is_empty():
		sub.animation = anim_name
	var pos_arr: Array = state.get("position", [0, 0]) as Array
	var pos := Vector2(float(pos_arr[0]) if pos_arr.size() > 0 else 0.0, float(pos_arr[1]) if pos_arr.size() > 1 else 0.0)
	sm.add_node(state_name, sub, pos)
	return {"ok": true, "result": {"added": true, "name": state_name, "state": {"animation": anim_name}, "revision": revision_tag()}}


static func remove_state(tree: AnimationTree, name: String) -> Dictionary:
	var sm := state_machine_root(tree)
	if sm == null:
		return {"ok": false, "code": _Err.ANIMATION_TREE_NOT_FOUND}
	if not sm.has_node(name):
		return {"ok": false, "code": _Err.ANIMATION_TREE_STATE_UNKNOWN}
	sm.remove_node(name)
	return {"ok": true, "result": {"removed": true, "name": name, "revision": revision_tag()}}


static func add_transition(tree: AnimationTree, from_state: String, to_state: String, transition: Dictionary) -> Dictionary:
	var sm := state_machine_root(tree)
	if sm == null:
		return {"ok": false, "code": _Err.ANIMATION_TREE_NOT_FOUND}
	var tr := AnimationNodeStateMachineTransition.new()
	tr.xfade_time = float(transition.get("xfade_time", 0.0))
	tr.switch_mode = _switch_mode_from_string(str(transition.get("switch_mode", "immediate")))
	tr.advance_mode = _advance_mode_from_string(str(transition.get("advance_mode", "enabled")))
	var cond := str(transition.get("advance_condition", ""))
	if not cond.is_empty():
		tr.advance_condition = cond
	tr.priority = int(transition.get("priority", 1))
	sm.add_transition(from_state, to_state, tr)
	return {
		"ok": true,
		"result": {"added": true, "from": from_state, "to": to_state, "state": {}, "revision": revision_tag()},
	}


static func remove_transition(tree: AnimationTree, from_state: String, to_state: String) -> Dictionary:
	var sm := state_machine_root(tree)
	if sm == null:
		return {"ok": false, "code": _Err.ANIMATION_TREE_NOT_FOUND}
	sm.remove_transition(from_state, to_state)
	return {"ok": true, "result": {"removed": true, "from": from_state, "to": to_state, "revision": revision_tag()}}


static func blend_audit(tree: AnimationTree) -> Dictionary:
	var active_state: Variant = null
	var current_transition: Variant = null
	var sm := state_machine_root(tree)
	if sm != null and tree.active:
		var playback := _state_machine_playback(tree, sm)
		if playback != null:
			active_state = str(playback.get_current_node())
			var fading_from := str(playback.get_fading_from_node())
			if fading_from.length() > 0:
				current_transition = {
					"from": fading_from,
					"to": str(playback.get_current_node()),
					"progress": float(playback.get_fading_progress()),
				}
	return {
		"active_state": active_state,
		"blends": {},
		"current_transition": current_transition,
		"processing_time_us": 0,
	}


static func _switch_mode_from_string(s: String) -> int:
	match s:
		"sync":
			return AnimationNodeStateMachineTransition.SWITCH_MODE_SYNC
		"at_end":
			return AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		_:
			return AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE


static func _advance_mode_from_string(s: String) -> int:
	match s:
		"disabled":
			return AnimationNodeStateMachineTransition.ADVANCE_MODE_DISABLED
		"auto":
			return AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
		_:
			return AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
