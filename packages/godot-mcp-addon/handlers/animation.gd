@tool
extends RefCounted
class_name TerraVoltAnimationHandlers

const _Utils := preload("./handler_utils.gd")
const _Anim := preload("./animation_helpers.gd")

var _dispatcher: TerraVoltDispatcher
var _logger: TerraVoltLogger
var _transient_roots: Array[Node] = []


func attach(dispatcher: TerraVoltDispatcher, logger: TerraVoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var np := {"type": "string", "minLength": 1}
	_dispatcher.register("animation.list", _schema({"scope": {"type": "string"}, "scene_path": np}), _h_list)
	_dispatcher.register(
		"animation.create",
		_schema(
			{
				"player_path": np,
				"library": {"type": "string"},
				"name": {"type": "string"},
				"length": {"type": "number"},
				"step": {"type": "number"},
				"loop_mode": {"type": "string"},
				"scene_path": np,
			},
			["player_path", "name"]
		),
		_h_create
	)
	_dispatcher.register(
		"animation.add_track",
		_schema(
			{
				"player_path": np,
				"animation": {"type": "string"},
				"library": {"type": "string"},
				"track": {"type": "object"},
				"index": {"type": "integer"},
				"scene_path": np,
			},
			["player_path", "animation", "track"]
		),
		_h_add_track
	)
	_dispatcher.register(
		"animation.set_keyframes",
		_schema(
			{
				"player_path": np,
				"animation": {"type": "string"},
				"library": {"type": "string"},
				"track_index": {"type": "integer"},
				"keys": {"type": "array"},
				"mode": {"type": "string"},
				"scene_path": np,
			},
			["player_path", "animation", "track_index", "keys"]
		),
		_h_set_keyframes
	)
	_dispatcher.register(
		"animation.play",
		_schema(
			{
				"player_path": np,
				"name": {"type": "string"},
				"library": {"type": "string"},
				"action": {"type": "string"},
				"custom_blend": {"type": "number"},
				"from_end": {"type": "boolean"},
				"scene_path": np,
			},
			["player_path"]
		),
		_h_play
	)
	_dispatcher.register(
		"animation.preview_export",
		_schema(
			{
				"player_path": np,
				"name": {"type": "string"},
				"format": {"type": "string"},
				"fps": {"type": "integer"},
				"duration_s": {"type": "number"},
				"scene_path": np,
			},
			["player_path", "name"]
		),
		_h_preview_export
	)


func _schema(props: Dictionary, required: Array = []) -> Dictionary:
	var s := {"type": "object", "properties": props, "additionalProperties": false}
	if not required.is_empty():
		s["required"] = required
	return s


func _scene_ctx(p: Dictionary) -> Dictionary:
	var scene_path := str(p.get("scene_path", ""))
	if not scene_path.is_empty():
		var res := _Utils.resolve_resource_path(scene_path)
		if not _Utils.scene_file_exists(res):
			return {"ok": false, "error": _Utils.err_scene_not_found(res)}
		var ps: PackedScene = ResourceLoader.load(res)
		if ps == null:
			return {"ok": false, "error": _Utils.err_scene_not_found(res)}
		var inst := ps.instantiate()
		_transient_roots.append(inst)
		return {"ok": true, "root": inst}
	var root := _active_scene_root()
	if root == null:
		return {"ok": false, "error": _Utils.err_no_active_scene()}
	return {"ok": true, "root": root}


func _active_scene_root() -> Node:
	if not OS.has_feature("editor"):
		return null
	var plug := _Utils.editor_plugin(_dispatcher)
	if plug == null:
		return null
	return plug.get_editor_interface().get_edited_scene_root()


func _player_from_params(p: Dictionary) -> Dictionary:
	var sc := _scene_ctx(p)
	if not sc.get("ok", false):
		return sc
	var root: Node = sc["root"]
	var player := _Anim.resolve_player(root, str(p.get("player_path", "")))
	if player == null:
		return _err_player_not_found(str(p.get("player_path", "")))
	return {"ok": true, "player": player, "root": root}


func _err(code: int, symbol: String, hint: String, ctx: Dictionary = {}) -> Dictionary:
	return {"ok": false, "error": TerraVoltErrors.tv_rpc_error(code, symbol, hint, ctx)}


func _err_player_not_found(path: String) -> Dictionary:
	return _err(TerraVoltErrors.ANIMATION_PLAYER_NOT_FOUND, "animation.player_not_found", "AnimationPlayer not found.", {"player_path": path})


func _map_anim_error(got: Dictionary) -> Dictionary:
	var code: int = int(got.get("code", TerraVoltErrors.ANIMATION_UNKNOWN))
	match code:
		TerraVoltErrors.ANIMATION_NAME_EXISTS:
			return _err(code, "animation.name_exists", "Animation name already exists in library.", {})
		TerraVoltErrors.ANIMATION_TRACK_KIND_UNKNOWN:
			return _err(code, "animation.track_kind_unknown", "Unknown animation track type.", {})
		TerraVoltErrors.ANIMATION_EXPORTER_MISSING:
			return _err(code, "animation.exporter_missing", "FFmpeg not available for requested format.", got)
		TerraVoltErrors.ANIMATION_PLAYER_NOT_FOUND:
			return _err_player_not_found("")
		_:
			return _err(code, "animation.unknown", "Animation or library not found.", {})


func _h_list(_ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(_ctx)
	var scope := str(p.get("scope", "active"))
	var scene_path := str(p.get("scene_path", ""))
	var active_root: Node = null
	if scope == "active":
		var sc := _scene_ctx({})
		if sc.get("ok", false):
			active_root = sc["root"]
	return {"ok": true, "result": _Anim.list_animations(scope, scene_path, active_root)}


func _h_create(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var got := _player_from_params(p)
	if not got.get("ok", false):
		return got
	var player: AnimationPlayer = got["player"]
	var created := _Anim.create_animation(
		player,
		str(p.get("library", "")),
		str(p.get("name", "")),
		float(p.get("length", 1.0)),
		float(p.get("step", 0.1)),
		str(p.get("loop_mode", "none"))
	)
	if not created.get("ok", false):
		return _map_anim_error(created)
	created["result"]["player_path"] = str(p.get("player_path", ""))
	return {"ok": true, "result": created["result"]}


func _h_add_track(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var got := _player_from_params(p)
	if not got.get("ok", false):
		return got
	var anim_got := _Anim.get_animation_on_player(got["player"], str(p.get("animation", "")), str(p.get("library", "")))
	if not anim_got.get("ok", false):
		return _map_anim_error(anim_got)
	var track: Dictionary = p.get("track", {}) as Dictionary
	var added := _Anim.add_track(anim_got["animation"], track, int(p.get("index", -1)))
	if not added.get("ok", false):
		return _map_anim_error(added)
	return {"ok": true, "result": added["result"]}


func _h_set_keyframes(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var got := _player_from_params(p)
	if not got.get("ok", false):
		return got
	var anim_got := _Anim.get_animation_on_player(got["player"], str(p.get("animation", "")), str(p.get("library", "")))
	if not anim_got.get("ok", false):
		return _map_anim_error(anim_got)
	var keys: Array = p.get("keys", []) as Array
	var res := _Anim.set_keyframes(anim_got["animation"], int(p.get("track_index", 0)), keys, str(p.get("mode", "upsert")))
	if not res.get("ok", false):
		return _map_anim_error(res)
	return {"ok": true, "result": res["result"]}


func _h_play(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var got := _player_from_params(p)
	if not got.get("ok", false):
		return got
	var res := _Anim.play(got["player"], p)
	if not res.get("ok", false):
		return _map_anim_error(res)
	return {"ok": true, "result": res["result"]}


func _h_preview_export(ctx: Dictionary) -> Dictionary:
	var ed := _Utils.require_editor(_dispatcher)
	if not ed.get("ok", false):
		return ed
	var p := _Utils.params_dict(ctx)
	var got := _player_from_params(p)
	if not got.get("ok", false):
		return got
	var res := _Anim.preview_export(
		got["player"],
		str(p.get("name", "")),
		str(p.get("format", "gif")),
		int(p.get("fps", 24)),
		float(p.get("duration_s", 0.0))
	)
	if not res.get("ok", false):
		return _map_anim_error(res)
	return {"ok": true, "result": res["result"]}
