@tool
extends RefCounted
class_name TerravoltNavigationHelpers

## Shared navigation helpers (task 19).

const BAKE_TIMEOUT_MS := 120000

const NAV_LAYER_PREFIX := {
	"2d": "layer_names/2d_navigation",
	"3d": "layer_names/3d_navigation",
}


static func nav_layer_key(dimension: String, index_1: int) -> String:
	return "%s/layer_%d" % [NAV_LAYER_PREFIX.get(dimension, NAV_LAYER_PREFIX["3d"]), index_1]


static func region_class(dimension: String) -> String:
	return "NavigationRegion2D" if dimension == "2d" else "NavigationRegion3D"


static func agent_class(dimension: String) -> String:
	return "NavigationAgent2D" if dimension == "2d" else "NavigationAgent3D"


static func create_region(dimension: String) -> Node:
	var cls := region_class(dimension)
	if not ClassDB.class_exists(cls):
		return null
	var region: Node = ClassDB.instantiate(cls)
	if dimension == "3d" and region is NavigationRegion3D:
		var mesh := NavigationMesh.new()
		mesh.agent_radius = 0.5
		mesh.agent_height = 2.0
		(region as NavigationRegion3D).navigation_mesh = mesh
	elif dimension == "2d" and region is NavigationRegion2D:
		var poly := NavigationPolygon.new()
		(region as NavigationRegion2D).navigation_polygon = poly
	return region


static func create_agent(dimension: String) -> Node:
	var cls := agent_class(dimension)
	if not ClassDB.class_exists(cls):
		return null
	return ClassDB.instantiate(cls) as Node


static func configure_agent(agent: Node, params: Dictionary) -> void:
	if agent is NavigationAgent3D:
		var a3 := agent as NavigationAgent3D
		if params.has("path_max_distance"):
			a3.path_max_distance = float(params.get("path_max_distance"))
		if params.has("target_desired_distance"):
			a3.target_desired_distance = float(params.get("target_desired_distance"))
		if params.has("radius"):
			a3.radius = float(params.get("radius"))
		if params.has("navigation_layers"):
			a3.navigation_layers = int(params.get("navigation_layers"))
	elif agent is NavigationAgent2D:
		var a2 := agent as NavigationAgent2D
		if params.has("path_max_distance"):
			a2.path_max_distance = float(params.get("path_max_distance"))
		if params.has("target_desired_distance"):
			a2.target_desired_distance = float(params.get("target_desired_distance"))
		if params.has("radius"):
			a2.radius = float(params.get("radius"))
		if params.has("navigation_layers"):
			a2.navigation_layers = int(params.get("navigation_layers"))


static func configure_mesh_from_params(mesh: NavigationMesh, params: Dictionary) -> void:
	if params.has("cell_size"):
		mesh.cell_size = float(params.get("cell_size"))
	if params.has("agent_radius"):
		mesh.agent_radius = float(params.get("agent_radius"))
	if params.has("agent_height"):
		mesh.agent_height = float(params.get("agent_height"))
	if params.has("max_slope_deg"):
		mesh.agent_max_slope = deg_to_rad(float(params.get("max_slope_deg")))
	if params.has("edge_max_length"):
		mesh.edge_max_length = float(params.get("edge_max_length"))


static func bake_region(region: Node, params: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	if region is NavigationRegion3D:
		var r3 := region as NavigationRegion3D
		if r3.navigation_mesh != null:
			configure_mesh_from_params(r3.navigation_mesh, params)
		r3.bake_navigation_mesh()
	elif region is NavigationRegion2D:
		var r2 := region as NavigationRegion2D
		r2.bake_navigation_polygon()
	var dt := Time.get_ticks_msec() - t0
	if dt > BAKE_TIMEOUT_MS:
		return {"ok": false, "timeout": true, "duration_ms": dt}
	return {"ok": true, "duration_ms": dt}


static func bake_scope(root: Node, region_path: String, scope: String, params: Dictionary) -> Dictionary:
	var regions: Array = []
	if scope == "all_in_scene":
		for n in root.find_children("*", region_class("3d"), true, true):
			regions.append(n)
		for n in root.find_children("*", region_class("2d"), true, true):
			if not regions.has(n):
				regions.append(n)
	else:
		var target := root.get_node_or_null(NodePath(region_path))
		if target == null:
			return {"ok": false, "missing": true}
		regions.append(target)
	var baked := 0
	var durations: Array = []
	var errors: Array = []
	for reg in regions:
		var res := bake_region(reg, params)
		if res.get("timeout", false):
			errors.append({"region_path": str(root.get_path_to(reg)), "message": "navigation.bake_timeout"})
			continue
		if not res.get("ok", false):
			errors.append({"region_path": str(root.get_path_to(reg)), "message": "bake_failed"})
			continue
		baked += 1
		durations.append(int(res.get("duration_ms", 0)))
	return {"ok": true, "baked": baked, "durations_ms": durations, "errors": errors}


static func compute_path(tree: SceneTree, dimension: String, from_v: Variant, to_v: Variant, layers: int, optimize: bool) -> Dictionary:
	if dimension == "3d":
		var map := NavigationServer3D.get_maps()[0] if NavigationServer3D.get_maps().size() > 0 else RID()
		if map == RID():
			return {"path": [], "length": 0.0, "ok": false}
		var from3 := _vec3(from_v)
		var to3 := _vec3(to_v)
		var packed: PackedVector3Array = NavigationServer3D.map_get_path(map, from3, to3, optimize, layers)
		var path: Array = []
		var length := 0.0
		for i in packed.size():
			var p := packed[i]
			path.append({"x": p.x, "y": p.y, "z": p.z})
			if i > 0:
				length += packed[i - 1].distance_to(p)
		return {"path": path, "length": length, "ok": path.size() > 0}
	var map2 := NavigationServer2D.get_maps()[0] if NavigationServer2D.get_maps().size() > 0 else RID()
	if map2 == RID():
		return {"path": [], "length": 0.0, "ok": false}
	var from2 := _vec2(from_v)
	var to2 := _vec2(to_v)
	var packed2: PackedVector2Array = NavigationServer2D.map_get_path(map2, from2, to2, optimize, layers)
	var path2: Array = []
	var length2 := 0.0
	for i in packed2.size():
		var p2 := packed2[i]
		path2.append({"x": p2.x, "y": p2.y})
		if i > 0:
			length2 += packed2[i - 1].distance_to(p2)
	return {"path": path2, "length": length2, "ok": path2.size() > 0}


static func set_debug_overlay(tree: SceneTree, enabled: bool) -> Dictionary:
	tree.debug_navigation_hint = enabled
	return {"enabled": enabled}


static func set_nav_layer_name(dimension: String, index: int, layer_name: String) -> void:
	ProjectSettings.set_setting(nav_layer_key(dimension, index), layer_name)
	ProjectSettings.save()


static func _vec2(v: Variant) -> Vector2:
	if v is Vector2:
		return v
	if typeof(v) == TYPE_DICTIONARY:
		var d := v as Dictionary
		return Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
	return Vector2.ZERO


static func _vec3(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	if typeof(v) == TYPE_DICTIONARY:
		var d := v as Dictionary
		return Vector3(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0)))
	return Vector3.ZERO
