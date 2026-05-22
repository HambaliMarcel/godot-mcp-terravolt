@tool
extends RefCounted
class_name TerravoltAnimationTreeHandlers

const _Utils := preload("./handler_utils.gd")
const _Anim := preload("./animation_helpers.gd")

var _dispatcher: TerravoltDispatcher
var _logger: TerravoltLogger
var _transient_roots: Array[Node] = []


func attach(dispatcher: TerravoltDispatcher, logger: TerravoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var np := {"type": "string", "minLength": 1}
	_dispatcher.register("animation_tree.describe", _schema({"tree_path": np, "scene_path": np}, ["tree_path"]), _h_describe)
	_dispatcher.register(
		"animation_tree.set_active",
		_schema({"tree_path": np, "active": {"type": "boolean"}, "scene_path": np}, ["tree_path", "active"]),
		_h_set_active
	)
	_dispatcher.register(
		"animation_tree.set_parameter",
		_schema(
			{
				"tree_path": np,
				"parameter": {"type": "string"},
				"value": {},
				"mode": {"type": "string"},
				"scene_path": np,
			},
			["tree_path", "parameter", "value"]
		),
		_h_set_parameter
	)
	_dispatcher.register(
		"animation_tree.add_state",
		_schema({"tree_path": np, "state": {"type": "object"}, "scene_path": np}, ["tree_path", "state"]),
		_h_add_state
	)
	_dispatcher.register(
		"animation_tree.remove_state",
		_schema({"tree_path": np, "name": {"type": "string"}, "scene_path": np}, ["tree_path", "name"]),
		_h_remove_state
	)
	_dispatcher.register(
		"animation_tree.add_transition",
		_schema(
			{
				"tree_path": np,
				"from": {"type": "string"},
				"to": {"type": "string"},
				"transition": {"type": "object"},
				"scene_path": np,
			},
			["tree_path", "from", "to", "transition"]
		),
		_h_add_transition
	)
	_dispatcher.register(
		"animation_tree.remove_transition",
		_schema({"tree_path": np, "from": {"type": "string"}, "to": {"type": "string"}, "scene_path": np}, ["tree_path", "from", "to"]),
		_h_remove_transition
	)
	_dispatcher.register("animation_tree.blend_audit", _schema({"tree_path": np, "scene_path": np}, ["tree_path"]), _h_blend_audit)


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


func _tree_from_params(p: Dictionary) -> Dictionary:
	var sc := _scene_ctx(p)
	if not sc.get("ok", false):
		return sc
	var tree := _Anim.resolve_tree(sc["root"], str(p.get("tree_path", "")))
	if tree == null:
		return {
			"ok": false,
			"error": TerravoltErrors.tv_rpc_error(
				TerravoltErrors.ANIMATION_TREE_NOT_FOUND,
				"animation_tree.not_found",
				"AnimationTree not found.",
				{"tree_path": str(p.get("tree_path", ""))}
			),
		}
	return {"ok": true, "tree": tree}


func _map_tree_error(got: Dictionary) -> Dictionary:
	var code: int = int(got.get("code", TerravoltErrors.ANIMATION_TREE_NOT_FOUND))
	match code:
		TerravoltErrors.ANIMATION_TREE_PARAMETER_UNKNOWN:
			return {
				"ok": false,
				"error": TerravoltErrors.tv_rpc_error(code, "animation_tree.parameter_unknown", "Unknown AnimationTree parameter.", {}),
			}
		TerravoltErrors.ANIMATION_TREE_STATE_EXISTS:
			return {
				"ok": false,
				"error": TerravoltErrors.tv_rpc_error(code, "animation_tree.state_exists", "State already exists.", {}),
			}
		TerravoltErrors.ANIMATION_TREE_STATE_UNKNOWN:
			return {
				"ok": false,
				"error": TerravoltErrors.tv_rpc_error(code, "animation_tree.state_unknown", "State not found.", {}),
			}
		_:
			return {
				"ok": false,
				"error": TerravoltErrors.tv_rpc_error(code, "animation_tree.not_found", "AnimationTree or state machine root unavailable.", {}),
			}


func _h_describe(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var got := _tree_from_params(p)
	if not got.get("ok", false):
		return got
	return {"ok": true, "result": _Anim.describe_tree(got["tree"])}


func _h_set_active(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var got := _tree_from_params(p)
	if not got.get("ok", false):
		return got
	return {"ok": true, "result": _Anim.set_tree_active(got["tree"], bool(p.get("active", true)))["result"]}


func _h_set_parameter(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var got := _tree_from_params(p)
	if not got.get("ok", false):
		return got
	var res := _Anim.set_tree_parameter(
		got["tree"],
		str(p.get("parameter", "")),
		p.get("value"),
		str(p.get("mode", "set"))
	)
	if not res.get("ok", false):
		return _map_tree_error(res)
	return {"ok": true, "result": res["result"]}


func _h_add_state(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var got := _tree_from_params(p)
	if not got.get("ok", false):
		return got
	var state: Dictionary = p.get("state", {}) as Dictionary
	var res := _Anim.add_state(got["tree"], state)
	if not res.get("ok", false):
		return _map_tree_error(res)
	return {"ok": true, "result": res["result"]}


func _h_remove_state(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var got := _tree_from_params(p)
	if not got.get("ok", false):
		return got
	var res := _Anim.remove_state(got["tree"], str(p.get("name", "")))
	if not res.get("ok", false):
		return _map_tree_error(res)
	return {"ok": true, "result": res["result"]}


func _h_add_transition(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var got := _tree_from_params(p)
	if not got.get("ok", false):
		return got
	var transition: Dictionary = p.get("transition", {}) as Dictionary
	var res := _Anim.add_transition(got["tree"], str(p.get("from", "")), str(p.get("to", "")), transition)
	if not res.get("ok", false):
		return _map_tree_error(res)
	return {"ok": true, "result": res["result"]}


func _h_remove_transition(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var got := _tree_from_params(p)
	if not got.get("ok", false):
		return got
	var res := _Anim.remove_transition(got["tree"], str(p.get("from", "")), str(p.get("to", "")))
	if not res.get("ok", false):
		return _map_tree_error(res)
	return {"ok": true, "result": res["result"]}


func _h_blend_audit(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var got := _tree_from_params(p)
	if not got.get("ok", false):
		return got
	return {"ok": true, "result": _Anim.blend_audit(got["tree"])}
