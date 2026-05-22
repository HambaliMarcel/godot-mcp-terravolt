@tool
extends RefCounted
class_name TerravoltNavigationHandlers

const _Utils := preload("./handler_utils.gd")
const _Nav := preload("./navigation_helpers.gd")
const _Phys := preload("./physics_helpers.gd")

var _dispatcher: TerravoltDispatcher
var _logger: TerravoltLogger
var _revisions: Dictionary = {}


func attach(dispatcher: TerravoltDispatcher, logger: TerravoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var np := {"type": "string", "minLength": 1}
	_dispatcher.register(
		"navigation.add_region",
		_schema(
			{
				"parent_path": np,
				"dimension": {"type": "string"},
				"name": {"type": "string"},
				"transform": {"type": "object"},
				"navmesh": {"type": "object"},
			},
			["parent_path", "dimension"],
		),
		_h_add_region,
	)
	_dispatcher.register(
		"navigation.bake",
		_schema(
			{
				"region_path": np,
				"scope": {"type": "string"},
				"cell_size": {"type": "number"},
				"agent_radius": {"type": "number"},
				"agent_height": {"type": "number"},
				"max_slope_deg": {"type": "number"},
				"edge_max_length": {"type": "number"},
			},
		),
		_h_bake,
	)
	_dispatcher.register(
		"navigation.add_agent",
		_schema(
			{
				"parent_path": np,
				"dimension": {"type": "string"},
				"path_max_distance": {"type": "number"},
				"target_desired_distance": {"type": "number"},
				"radius": {"type": "number"},
				"navigation_layers": {"type": "integer"},
			},
			["parent_path", "dimension"],
		),
		_h_add_agent,
	)
	_dispatcher.register(
		"navigation.set_layers",
		_schema(
			{
				"dimension": {"type": "string"},
				"layer_index": {"type": "integer"},
				"layer_name": {"type": "string"},
				"target_path": np,
				"navigation_layers": {"type": "integer"},
			},
		),
		_h_set_layers,
	)
	_dispatcher.register(
		"navigation.path",
		_schema(
			{
				"dimension": {"type": "string"},
				"from": {"type": "object"},
				"to": {"type": "object"},
				"layers": {"type": "integer"},
				"optimize": {"type": "boolean"},
			},
			["dimension", "from", "to"],
		),
		_h_path,
	)
	_dispatcher.register(
		"navigation.debug_overlay",
		_schema({"enabled": {"type": "boolean"}, "scope": {"type": "string"}}, ["enabled"]),
		_h_debug_overlay,
	)


func _schema(props: Dictionary, required: Array = []) -> Dictionary:
	var s := {"type": "object", "properties": props, "additionalProperties": false}
	if not required.is_empty():
		s["required"] = required
	return s


func _revision(path: String) -> String:
	return str(_revisions.get(path, Time.get_ticks_msec()))


func _bump_revision(path: String) -> String:
	var r := str(Time.get_ticks_msec())
	_revisions[path] = r
	return r


func _scene_root() -> Node:
	var ed := _Utils.require_editor(_dispatcher)
	if not ed.get("ok", false):
		return null
	return (ed.plugin as EditorPlugin).get_editor_interface().get_edited_scene_root()


func _h_add_region(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	var parent := _Utils.resolve_node(root, str(p.get("parent_path", ".")))
	if parent == null:
		return _Utils.err_node_not_found(str(p.get("parent_path", "")))
	var dimension := str(p.get("dimension", "3d"))
	var region := _Nav.create_region(dimension)
	if region == null:
		return _Utils.err_type_unknown(_Nav.region_class(dimension))
	if not str(p.get("name", "")).is_empty():
		region.name = str(p["name"])
	else:
		region.name = "NavigationRegion"
	_Phys.apply_transform(region, p.get("transform"))
	parent.add_child(region)
	region.owner = root
	var added := str(root.get_path_to(region))
	var navmesh_path: Variant = null
	return {
		"ok": true,
		"result": {
			"added_path": added,
			"region_path": added,
			"navmesh_path": navmesh_path,
			"state": "live",
			"revision": _bump_revision(added),
		},
	}


func _h_bake(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	var scope := str(p.get("scope", "region"))
	var region_path := str(p.get("region_path", ""))
	if scope == "region" and region_path.is_empty():
		return _Utils.err_node_not_found(region_path)
	var res := _Nav.bake_scope(root, region_path, scope, p)
	if res.get("missing", false):
		return _Utils.err_node_not_found(region_path)
	for err in res.get("errors", []) as Array:
		if str((err as Dictionary).get("message", "")) == "navigation.bake_timeout":
			return _err_bake_timeout()
	return {"ok": true, "result": {"baked": res.get("baked", 0), "durations_ms": res.get("durations_ms", []), "errors": res.get("errors", [])}}


func _h_add_agent(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	var parent := _Utils.resolve_node(root, str(p.get("parent_path", ".")))
	if parent == null:
		return _Utils.err_node_not_found(str(p.get("parent_path", "")))
	var dimension := str(p.get("dimension", "3d"))
	var agent := _Nav.create_agent(dimension)
	if agent == null:
		return _Utils.err_type_unknown(_Nav.agent_class(dimension))
	agent.name = "NavigationAgent"
	_Nav.configure_agent(agent, p)
	parent.add_child(agent)
	agent.owner = root
	var added := str(root.get_path_to(agent))
	return {
		"ok": true,
		"result": {"added_path": added, "agent_path": added, "state": "live", "revision": _bump_revision(added)},
	}


func _h_set_layers(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var dimension := str(p.get("dimension", "3d"))
	if p.has("layer_index") and p.has("layer_name"):
		_Nav.set_nav_layer_name(dimension, int(p.get("layer_index")), str(p.get("layer_name")))
	if p.has("target_path") and p.has("navigation_layers"):
		var root := _scene_root()
		if root == null:
			return _Utils.err_no_active_scene()
		var target := _Utils.resolve_node(root, str(p.get("target_path", "")))
		if target == null:
			return _Utils.err_node_not_found(str(p.get("target_path", "")))
		if target is NavigationAgent3D:
			(target as NavigationAgent3D).navigation_layers = int(p.get("navigation_layers"))
		elif target is NavigationAgent2D:
			(target as NavigationAgent2D).navigation_layers = int(p.get("navigation_layers"))
	return {"ok": true, "result": {"updated": true}}


func _h_path(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var ed := _Utils.require_editor(_dispatcher)
	if not ed.get("ok", false):
		return ed
	var tree := (ed.plugin as EditorPlugin).get_editor_interface().get_base_control().get_tree()
	var dimension := str(p.get("dimension", "3d"))
	var layers := int(p.get("layers", 1))
	var optimize := bool(p.get("optimize", true))
	var res := _Nav.compute_path(tree, dimension, p.get("from"), p.get("to"), layers, optimize)
	return {"ok": true, "result": res}


func _h_debug_overlay(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var scope := str(p.get("scope", "runtime"))
	if scope == "editor":
		return {
			"ok": true,
			"result": {"enabled": bool(p.get("enabled", false)), "note": "editor overlay requires EditorInterface"},
		}
	var ed := _Utils.require_editor(_dispatcher)
	if not ed.get("ok", false):
		return ed
	var tree := (ed.plugin as EditorPlugin).get_editor_interface().get_base_control().get_tree()
	return {"ok": true, "result": _Nav.set_debug_overlay(tree, bool(p.get("enabled", false)))}


func _err_bake_timeout() -> Dictionary:
	return {
		"ok": false,
		"error": TerravoltErrors.tv_rpc_error(
			TerravoltErrors.NAVIGATION_BAKE_TIMEOUT,
			"navigation.bake_timeout",
			"Navigation bake exceeded nav_bake_timeout_ms.",
			{"timeout_ms": _Nav.BAKE_TIMEOUT_MS},
		),
	}
