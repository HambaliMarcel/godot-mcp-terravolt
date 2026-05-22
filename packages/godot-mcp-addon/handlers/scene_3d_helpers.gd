@tool
extends RefCounted
class_name TerraVoltScene3dHelpers

## Shared 3D scene authoring helpers (task 22).

const DEFAULT_LIGHT_ENERGY := 1.0
const DEFAULT_CAMERA_FOV := 75.0
const MAX_CELLS_PER_CALL := 4096

const _Phys := preload("./physics_helpers.gd")
const _Res := preload("./resource_helpers.gd")

const PRIMITIVE_MESH := {
	"box": "BoxMesh",
	"sphere": "SphereMesh",
	"capsule": "CapsuleMesh",
	"cylinder": "CylinderMesh",
	"plane": "PlaneMesh",
	"quad": "PlaneMesh",
	"prism": "PrismMesh",
	"torus": "TorusMesh",
}


static func resolve_node(root: Node, path: String) -> Node:
	if root == null:
		return null
	var p := path.strip_edges()
	if p.is_empty() or p == ".":
		return root
	return root.get_node_or_null(NodePath(p))


static func add_mesh_instance(root: Node, params: Dictionary) -> Dictionary:
	var parent := resolve_node(root, str(params.get("parent_path", ".")))
	if parent == null:
		return {"ok": false, "code": -33501, "message": "scene.node_path_not_found"}
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = str(params.get("name", "MeshInstance3D"))
	var mesh_resource_path: Variant = null
	if params.has("mesh") and typeof(params.get("mesh")) == TYPE_DICTIONARY:
		var mesh_spec: Dictionary = params.get("mesh") as Dictionary
		var mesh_result := _assign_mesh(mesh_inst, mesh_spec)
		if not mesh_result.get("ok", false):
			return mesh_result
		mesh_resource_path = mesh_result.get("mesh_resource_path")
	var material_resource_path: Variant = null
	if params.has("material") and typeof(params.get("material")) == TYPE_DICTIONARY:
		var mat_result := _assign_material(mesh_inst, params.get("material") as Dictionary)
		if not mat_result.get("ok", false):
			return mat_result
		material_resource_path = mat_result.get("material_resource_path")
	_apply_shadow_and_gi(mesh_inst, params)
	_Phys.apply_transform(mesh_inst, params.get("transform"))
	parent.add_child(mesh_inst)
	mesh_inst.owner = root
	var added := str(root.get_path_to(mesh_inst))
	return {
		"ok": true,
		"result": {
			"added_path": added,
			"mesh_resource_path": mesh_resource_path,
			"material_resource_path": material_resource_path,
			"state": "live",
			"revision": str(Time.get_ticks_msec()),
		},
	}


static func add_camera(root: Node, params: Dictionary) -> Dictionary:
	var parent := resolve_node(root, str(params.get("parent_path", ".")))
	if parent == null:
		return {"ok": false, "code": -33501, "message": "scene.node_path_not_found"}
	var cam: Camera3D = Camera3D.new()
	cam.name = str(params.get("name", "Camera3D"))
	cam.fov = float(params.get("fov", DEFAULT_CAMERA_FOV))
	cam.near = float(params.get("near", 0.05))
	cam.far = float(params.get("far", 4000.0))
	cam.projection = _camera_projection(str(params.get("projection", "perspective")))
	if params.has("cull_mask"):
		cam.cull_mask = int(params.get("cull_mask"))
	_Phys.apply_transform(cam, params.get("transform"))
	parent.add_child(cam)
	cam.owner = root
	var make_current := bool(params.get("current", false))
	if make_current:
		cam.make_current()
	var added := str(root.get_path_to(cam))
	return {
		"ok": true,
		"result": {
			"added_path": added,
			"current": make_current,
			"state": "live",
			"revision": str(Time.get_ticks_msec()),
		},
	}


static func add_light(root: Node, params: Dictionary) -> Dictionary:
	var parent := resolve_node(root, str(params.get("parent_path", ".")))
	if parent == null:
		return {"ok": false, "code": -33501, "message": "scene.node_path_not_found"}
	var kind := str(params.get("kind", "omni"))
	var light: Light3D = _create_light(kind)
	if light == null:
		return {"ok": false, "code": -33520, "message": "node.type_unknown"}
	if params.has("color"):
		light.light_color = _parse_color(params.get("color"))
	light.light_energy = float(params.get("energy", DEFAULT_LIGHT_ENERGY))
	light.shadow_enabled = bool(params.get("shadow_enabled", true))
	light.light_bake_mode = _light_bake_mode(str(params.get("bake_mode", "dynamic")))
	if light is OmniLight3D and params.has("range"):
		(light as OmniLight3D).omni_range = float(params.get("range"))
	if light is SpotLight3D:
		var spot := light as SpotLight3D
		if params.has("range"):
			spot.spot_range = float(params.get("range"))
		if params.has("angle_deg"):
			spot.spot_angle = float(params.get("angle_deg"))
		if params.has("inner_angle_deg"):
			spot.spot_angle_attenuation = float(params.get("inner_angle_deg"))
	light.name = str(params.get("name", _default_light_name(kind)))
	_Phys.apply_transform(light, params.get("transform"))
	parent.add_child(light)
	light.owner = root
	var added := str(root.get_path_to(light))
	return {
		"ok": true,
		"result": {
			"added_path": added,
			"kind": kind,
			"state": "live",
			"revision": str(Time.get_ticks_msec()),
		},
	}


static func set_environment(root: Node, params: Dictionary) -> Dictionary:
	var scene_root := root
	if params.has("scene_root_path"):
		var custom := resolve_node(root, str(params.get("scene_root_path", "")))
		if custom == null:
			return {"ok": false, "code": -33501, "message": "scene.node_path_not_found"}
		scene_root = custom
	var we := _find_world_environment(scene_root)
	if we == null:
		we = WorldEnvironment.new()
		we.name = "WorldEnvironment"
		scene_root.add_child(we)
		we.owner = root
	var env: Environment = we.environment
	if env == null:
		env = Environment.new()
		we.environment = env
	var spec: Dictionary = params.get("spec", {}) as Dictionary
	_apply_environment_spec(env, spec)
	return {
		"ok": true,
		"result": {
			"environment_path": str(root.get_path_to(we)),
			"environment_resource_path": null,
			"state": "live",
			"revision": str(Time.get_ticks_msec()),
		},
	}


static func add_gridmap(root: Node, params: Dictionary) -> Dictionary:
	var parent := resolve_node(root, str(params.get("parent_path", ".")))
	if parent == null:
		return {"ok": false, "code": -33501, "message": "scene.node_path_not_found"}
	var lib_path := _Res.resolve_path(str(params.get("mesh_library_path", "")))
	if lib_path.is_empty() or not ResourceLoader.exists(lib_path):
		return {"ok": false, "code": -33981, "message": "scene_3d.mesh_library_unknown"}
	var mesh_lib: MeshLibrary = ResourceLoader.load(lib_path) as MeshLibrary
	if mesh_lib == null:
		return {"ok": false, "code": -33981, "message": "scene_3d.mesh_library_unknown"}
	var grid: GridMap = GridMap.new()
	grid.name = str(params.get("name", "GridMap"))
	grid.mesh_library = mesh_lib
	if params.has("cell_size"):
		grid.cell_size = _vec3(params.get("cell_size"))
	_Phys.apply_transform(grid, params.get("transform"))
	parent.add_child(grid)
	grid.owner = root
	var cells_written := 0
	if params.has("cells"):
		var cells: Array = params.get("cells") as Array
		if cells.size() > MAX_CELLS_PER_CALL:
			return {"ok": false, "code": -33982, "message": "scene_3d.gridmap_cells_invalid"}
		for row in cells:
			if typeof(row) != TYPE_DICTIONARY:
				return {"ok": false, "code": -33982, "message": "scene_3d.gridmap_cells_invalid"}
			var cell: Dictionary = row as Dictionary
			var pos_v: Variant = cell.get("position")
			if typeof(pos_v) != TYPE_ARRAY or (pos_v as Array).size() < 3:
				return {"ok": false, "code": -33982, "message": "scene_3d.gridmap_cells_invalid"}
			var pos_arr: Array = pos_v as Array
			var pos := Vector3i(int(pos_arr[0]), int(pos_arr[1]), int(pos_arr[2]))
			var item := int(cell.get("item", -1))
			var orientation := int(cell.get("orientation", 0))
			grid.set_cell_item(pos, item, orientation)
			cells_written += 1
	var added := str(root.get_path_to(grid))
	return {
		"ok": true,
		"result": {
			"added_path": added,
			"mesh_library_path": lib_path,
			"cells_written": cells_written,
			"state": "live",
			"revision": str(Time.get_ticks_msec()),
		},
	}


static func frame_subject(root: Node, params: Dictionary) -> Dictionary:
	var cam_node := resolve_node(root, str(params.get("camera_path", "")))
	if cam_node == null or not cam_node is Camera3D:
		return {"ok": false, "code": -33501, "message": "scene.node_path_not_found"}
	var cam := cam_node as Camera3D
	var subjects: Array = params.get("subjects", []) as Array
	if subjects.is_empty():
		return {"ok": false, "code": -33501, "message": "scene.node_path_not_found"}
	var combined := AABB()
	var first := true
	for sp in subjects:
		var subj := resolve_node(root, str(sp))
		if subj == null or not subj is VisualInstance3D:
			return {"ok": false, "code": -33501, "message": "scene.node_path_not_found"}
		var gaabb := _global_aabb(subj as VisualInstance3D)
		if first:
			combined = gaabb
			first = false
		else:
			combined = combined.merge(gaabb)
	var margin := float(params.get("margin", 1.2))
	var pitch := deg_to_rad(float(params.get("pitch_deg", -15.0)))
	var yaw := deg_to_rad(float(params.get("yaw_deg", 30.0)))
	var center := combined.get_center()
	var dist := _fit_distance(combined, cam.fov, margin)
	var dir := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)).normalized()
	cam.global_position = center - dir * dist
	cam.look_at(center, Vector3.UP)
	return {
		"ok": true,
		"result": {
			"updated": true,
			"applied_transform": _transform_dict(cam),
			"framed_aabb": {
				"center": _vec3_dict(center),
				"size": _vec3_dict(combined.size),
			},
		},
	}


static func count_world_environments(root: Node) -> int:
	var count := 0
	if root is WorldEnvironment:
		count += 1
	for ch in root.get_children():
		count += count_world_environments(ch)
	return count


static func _assign_mesh(mesh_inst: MeshInstance3D, spec: Dictionary) -> Dictionary:
	var source := str(spec.get("source", "primitive"))
	if source == "resource":
		var rp := _Res.resolve_path(str(spec.get("resource_path", "")))
		if rp.is_empty() or not ResourceLoader.exists(rp):
			return {"ok": false, "code": -33980, "message": "scene_3d.primitive_unknown"}
		var mesh: Mesh = ResourceLoader.load(rp) as Mesh
		if mesh == null:
			return {"ok": false, "code": -33980, "message": "scene_3d.primitive_unknown"}
		mesh_inst.mesh = mesh
		return {"ok": true, "mesh_resource_path": rp}
	if source != "primitive":
		return {"ok": false, "code": -33980, "message": "scene_3d.primitive_unknown"}
	var kind := str(spec.get("primitive_kind", "box"))
	var cls := str(PRIMITIVE_MESH.get(kind, ""))
	if cls.is_empty() or not ClassDB.class_exists(cls):
		return {"ok": false, "code": -33980, "message": "scene_3d.primitive_unknown"}
	var mesh_res: Mesh = ClassDB.instantiate(cls) as Mesh
	if mesh_res == null:
		return {"ok": false, "code": -33980, "message": "scene_3d.primitive_unknown"}
	if spec.has("primitive_params") and typeof(spec.get("primitive_params")) == TYPE_DICTIONARY:
		_Res.apply_properties(mesh_res, spec.get("primitive_params") as Dictionary)
	mesh_inst.mesh = mesh_res
	return {"ok": true, "mesh_resource_path": null}


static func _assign_material(mesh_inst: MeshInstance3D, spec: Dictionary) -> Dictionary:
	var source := str(spec.get("source", "none"))
	if source == "none":
		return {"ok": true, "material_resource_path": null}
	var mat: Material = null
	var mat_path: Variant = null
	if source == "resource":
		var rp := _Res.resolve_path(str(spec.get("resource_path", "")))
		if rp.is_empty() or not ResourceLoader.exists(rp):
			return {"ok": false, "code": -33980, "message": "scene_3d.primitive_unknown"}
		mat = ResourceLoader.load(rp) as Material
		if mat == null:
			return {"ok": false, "code": -33980, "message": "scene_3d.primitive_unknown"}
		mat_path = rp
	elif source == "inline":
		mat = StandardMaterial3D.new()
		if spec.has("inline") and typeof(spec.get("inline")) == TYPE_DICTIONARY:
			_Res.apply_properties(mat, spec.get("inline") as Dictionary)
	else:
		return {"ok": true, "material_resource_path": null}
	mesh_inst.set_surface_override_material(0, mat)
	return {"ok": true, "material_resource_path": mat_path}


static func _apply_shadow_and_gi(mesh_inst: MeshInstance3D, params: Dictionary) -> void:
	var cast := str(params.get("cast_shadow", "on"))
	match cast:
		"off":
			mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"double_sided":
			mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		"shadows_only":
			mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		_:
			mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var gi := str(params.get("gi_mode", "static"))
	match gi:
		"disabled":
			mesh_inst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		"dynamic":
			mesh_inst.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		_:
			mesh_inst.gi_mode = GeometryInstance3D.GI_MODE_STATIC


static func _camera_projection(name: String) -> Camera3D.ProjectionType:
	match name:
		"orthogonal":
			return Camera3D.PROJECTION_ORTHOGONAL
		"frustum":
			return Camera3D.PROJECTION_FRUSTUM
		_:
			return Camera3D.PROJECTION_PERSPECTIVE


static func _light_bake_mode(name: String) -> Light3D.BakeMode:
	match name:
		"disabled":
			return Light3D.BAKE_DISABLED
		"static":
			return Light3D.BAKE_STATIC
		_:
			return Light3D.BAKE_DYNAMIC


static func _create_light(kind: String) -> Light3D:
	match kind:
		"directional":
			return DirectionalLight3D.new()
		"spot":
			return SpotLight3D.new()
		"omni":
			return OmniLight3D.new()
		_:
			return null


static func _default_light_name(kind: String) -> String:
	match kind:
		"directional":
			return "DirectionalLight3D"
		"spot":
			return "SpotLight3D"
		_:
			return "OmniLight3D"


static func _find_world_environment(root: Node) -> WorldEnvironment:
	if root is WorldEnvironment:
		return root as WorldEnvironment
	for ch in root.get_children():
		var found := _find_world_environment(ch)
		if found != null:
			return found
	return null


static func _apply_environment_spec(env: Environment, spec: Dictionary) -> void:
	if spec.has("background"):
		env.background_mode = _background_mode(str(spec.get("background")))
	if spec.has("sky") and typeof(spec.get("sky")) == TYPE_DICTIONARY:
		var sky_spec: Dictionary = spec.get("sky") as Dictionary
		var sky := Sky.new()
		var kind := str(sky_spec.get("kind", "procedural"))
		if kind == "procedural":
			var mat := ProceduralSkyMaterial.new()
			if sky_spec.has("params") and typeof(sky_spec.get("params")) == TYPE_DICTIONARY:
				_Res.apply_properties(mat, sky_spec.get("params") as Dictionary)
			sky.sky_material = mat
		elif kind == "physical":
			var mat := PhysicalSkyMaterial.new()
			if sky_spec.has("params") and typeof(sky_spec.get("params")) == TYPE_DICTIONARY:
				_Res.apply_properties(mat, sky_spec.get("params") as Dictionary)
			sky.sky_material = mat
		elif kind == "panorama":
			var mat := PanoramaSkyMaterial.new()
			if sky_spec.has("params") and typeof(sky_spec.get("params")) == TYPE_DICTIONARY:
				_Res.apply_properties(mat, sky_spec.get("params") as Dictionary)
			sky.sky_material = mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	if spec.has("ambient_light") and typeof(spec.get("ambient_light")) == TYPE_DICTIONARY:
		var amb: Dictionary = spec.get("ambient_light") as Dictionary
		env.ambient_light_source = _ambient_source(str(amb.get("source", "background")))
		if amb.has("color"):
			env.ambient_light_color = _parse_color(amb.get("color"))
		if amb.has("energy"):
			env.ambient_light_energy = float(amb.get("energy"))
	if spec.has("tonemap") and typeof(spec.get("tonemap")) == TYPE_DICTIONARY:
		var tm: Dictionary = spec.get("tonemap") as Dictionary
		env.tonemap_mode = _tonemap_mode(str(tm.get("mode", "linear")))
		if tm.has("exposure"):
			env.tonemap_exposure = float(tm.get("exposure"))
		if tm.has("white"):
			env.tonemap_white = float(tm.get("white"))
	if spec.has("fog") and typeof(spec.get("fog")) == TYPE_DICTIONARY:
		var fog: Dictionary = spec.get("fog") as Dictionary
		env.fog_enabled = bool(fog.get("enabled", false))
		if fog.has("color"):
			env.fog_light_color = _parse_color(fog.get("color"))
		if fog.has("density"):
			env.fog_density = float(fog.get("density"))
		if fog.has("height"):
			env.fog_height = float(fog.get("height"))
		if fog.has("sun_scatter"):
			env.fog_sun_scatter = float(fog.get("sun_scatter"))
	if spec.has("glow") and typeof(spec.get("glow")) == TYPE_DICTIONARY:
		var glow: Dictionary = spec.get("glow") as Dictionary
		env.glow_enabled = bool(glow.get("enabled", false))
		if glow.has("intensity"):
			env.glow_intensity = float(glow.get("intensity"))
		if glow.has("strength"):
			env.glow_strength = float(glow.get("strength"))
		if glow.has("bloom"):
			env.glow_bloom = float(glow.get("bloom"))
	if spec.has("ssao") and typeof(spec.get("ssao")) == TYPE_DICTIONARY:
		var ssao: Dictionary = spec.get("ssao") as Dictionary
		env.ssao_enabled = bool(ssao.get("enabled", false))
		if ssao.has("radius"):
			env.ssao_radius = float(ssao.get("radius"))
		if ssao.has("intensity"):
			env.ssao_intensity = float(ssao.get("intensity"))
	if spec.has("ssr") and typeof(spec.get("ssr")) == TYPE_DICTIONARY:
		var ssr: Dictionary = spec.get("ssr") as Dictionary
		env.ssr_enabled = bool(ssr.get("enabled", false))
		if ssr.has("max_steps"):
			env.ssr_max_steps = int(ssr.get("max_steps"))


static func _background_mode(name: String) -> Environment.BGMode:
	match name:
		"sky":
			return Environment.BG_SKY
		"color":
			return Environment.BG_COLOR
		"canvas":
			return Environment.BG_CANVAS
		"custom_color":
			return Environment.BG_COLOR
		_:
			return Environment.BG_CLEAR_COLOR


static func _ambient_source(name: String) -> Environment.AmbientSource:
	match name:
		"disabled":
			return Environment.AMBIENT_SOURCE_DISABLED
		"color":
			return Environment.AMBIENT_SOURCE_COLOR
		"sky":
			return Environment.AMBIENT_SOURCE_SKY
		_:
			return Environment.AMBIENT_SOURCE_BG


static func _tonemap_mode(name: String) -> Environment.ToneMapper:
	match name:
		"reinhard", "reinhardt":
			return Environment.TONE_MAPPER_REINHARDT
		"filmic":
			return Environment.TONE_MAPPER_FILMIC
		"aces":
			return Environment.TONE_MAPPER_ACES
		_:
			return Environment.TONE_MAPPER_LINEAR


static func _global_aabb(vi: VisualInstance3D) -> AABB:
	var local := vi.get_aabb()
	if local.size == Vector3.ZERO:
		local = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	var gt := vi.global_transform
	var merged := AABB()
	var started := false
	for i in range(8):
		var corner: Vector3 = gt * local.get_endpoint(i)
		if not started:
			merged = AABB(corner, Vector3.ZERO)
			started = true
		else:
			merged = merged.expand(corner)
	return merged


static func _fit_distance(aabb: AABB, fov_deg: float, margin: float) -> float:
	var radius := aabb.size.length() * 0.5
	var fov_rad := deg_to_rad(fov_deg)
	var denom := tan(fov_rad * 0.5)
	if denom <= 0.0001:
		denom = 0.0001
	return maxf(radius * margin / denom, 0.1)


static func _transform_dict(n: Node3D) -> Dictionary:
	return {
		"position": _vec3_dict(n.position),
		"rotation": _vec3_dict(n.rotation),
		"scale": _vec3_dict(n.scale),
	}


static func _vec3(v: Variant) -> Vector3:
	if typeof(v) == TYPE_DICTIONARY:
		var d := v as Dictionary
		return Vector3(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0)))
	if typeof(v) == TYPE_ARRAY:
		var a := v as Array
		return Vector3(float(a[0] if a.size() > 0 else 0), float(a[1] if a.size() > 1 else 0), float(a[2] if a.size() > 2 else 0))
	return Vector3.ZERO


static func _vec3_dict(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}


static func _parse_color(v: Variant) -> Color:
	if typeof(v) != TYPE_DICTIONARY:
		return Color.WHITE
	var d := v as Dictionary
	if d.has("r") or d.has("g") or d.has("b"):
		return Color(float(d.get("r", 1)), float(d.get("g", 1)), float(d.get("b", 1)), float(d.get("a", 1)))
	var converted: Variant = _Res.json_to_variant(v)
	if converted is Color:
		return converted as Color
	return Color.WHITE
