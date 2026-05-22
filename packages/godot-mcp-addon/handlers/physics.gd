@tool
extends RefCounted
class_name TerraVoltPhysicsHandlers

const _Utils := preload("./handler_utils.gd")
const _Phys := preload("./physics_helpers.gd")

var _dispatcher: TerraVoltDispatcher
var _logger: TerraVoltLogger
var _revisions: Dictionary = {}


func attach(dispatcher: TerraVoltDispatcher, logger: TerraVoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var np := {"type": "string", "minLength": 1}
	_dispatcher.register(
		"physics.add_body",
		_schema(
			{
				"parent_path": np,
				"kind": {"type": "string"},
				"dimension": {"type": "string"},
				"name": {"type": "string"},
				"transform": {"type": "object"},
				"shape": {"type": "object"},
				"mass": {"type": "number"},
				"gravity_scale": {"type": "number"},
				"layer": {"type": "object"},
				"mask": {"type": "object"},
			},
			["parent_path", "kind", "dimension"],
		),
		_h_add_body,
	)
	_dispatcher.register(
		"physics.set_layers",
		_schema({"path": np, "layer": {}, "mask": {}}, ["path"]),
		_h_set_layers,
	)
	_dispatcher.register("physics.list_layers", _schema({"dimension": {"type": "string"}}), _h_list_layers)
	_dispatcher.register(
		"physics.set_layer_name",
		_schema({"dimension": {"type": "string"}, "index": {"type": "integer"}, "name": {"type": "string"}}, ["dimension", "index", "name"]),
		_h_set_layer_name,
	)
	_dispatcher.register(
		"physics.raycast",
		_schema(
			{
				"dimension": {"type": "string"},
				"from": {"type": "object"},
				"to": {"type": "object"},
				"mask": {},
				"exclude": {"type": "array"},
				"hit_areas": {"type": "boolean"},
				"batch": {"type": "array"},
			},
			["dimension"],
		),
		_h_raycast,
	)
	_dispatcher.register(
		"physics.set_gravity",
		_schema({"dimension": {"type": "string"}, "direction": {"type": "object"}, "magnitude": {"type": "number"}}, ["dimension"]),
		_h_set_gravity,
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


func _h_add_body(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	var parent := _Utils.resolve_node(root, str(p.get("parent_path", ".")))
	if parent == null:
		return _Utils.err_node_not_found(str(p.get("parent_path", "")))
	var kind := str(p.get("kind", "static"))
	var dimension := str(p.get("dimension", "3d"))
	var body := _Phys.create_body(kind, dimension)
	if body == null:
		return _err_shape_unknown(str(p.get("kind", "")))
	var shape_path: Variant = null
	if p.has("shape") and typeof(p.get("shape")) == TYPE_DICTIONARY:
		var spec: Dictionary = p.get("shape") as Dictionary
		var shape_kind := str(spec.get("kind", "box"))
		var shape := _Phys.create_shape(shape_kind, dimension, spec.get("params", {}) as Dictionary)
		if shape == null:
			return _err_shape_unknown(shape_kind)
		var col_cls := "CollisionShape3D" if dimension == "3d" else "CollisionShape2D"
		var col: Node = ClassDB.instantiate(col_cls)
		col.name = "CollisionShape"
		col.set("shape", shape)
		body.add_child(col)
		col.owner = root
		shape_path = str(root.get_path_to(col))
	if not str(p.get("name", "")).is_empty():
		body.name = str(p["name"])
	_Phys.apply_transform(body, p.get("transform"))
	if body is RigidBody3D and p.has("mass"):
		(body as RigidBody3D).mass = float(p.get("mass"))
	elif body is RigidBody2D and p.has("mass"):
		(body as RigidBody2D).mass = float(p.get("mass"))
	if body is RigidBody3D and p.has("gravity_scale"):
		(body as RigidBody3D).gravity_scale = float(p.get("gravity_scale"))
	elif body is RigidBody2D and p.has("gravity_scale"):
		(body as RigidBody2D).gravity_scale = float(p.get("gravity_scale"))
	if p.has("layer") or p.has("mask"):
		var layer_bits := _Phys.parse_bitmask(p.get("layer"), dimension) if p.has("layer") else 0xFFFFFFFF
		var mask_bits := _Phys.parse_bitmask(p.get("mask"), dimension) if p.has("mask") else 0xFFFFFFFF
		if layer_bits == 0xFFFFFFFF and not p.has("layer"):
			layer_bits = 1
		if mask_bits == 0xFFFFFFFF and not p.has("mask"):
			mask_bits = 1
		_Phys.set_collision_layers(body, layer_bits, mask_bits)
	parent.add_child(body)
	body.owner = root
	var added := str(root.get_path_to(body))
	return {
		"ok": true,
		"result": {
			"added_path": added,
			"body_kind": kind,
			"shape_path": shape_path,
			"state": "live",
			"revision": _bump_revision(added),
		},
	}


func _h_set_layers(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	var n := _Utils.resolve_node(root, str(p.get("path", "")))
	if n == null:
		return _Utils.err_node_not_found(str(p.get("path", "")))
	var dimension := _Phys.dimension_for_node(n)
	if dimension.is_empty():
		return _err_dimension_mismatch()
	var co := _Phys.collision_object(n)
	if co == null:
		return _err_dimension_mismatch()
	var current := _Phys.get_collision_layers(n, dimension)
	var layer_bits := _Phys.parse_bitmask(p.get("layer"), dimension) if p.has("layer") else int(current.get("layer", {}).get("bits", 1))
	var mask_bits := _Phys.parse_bitmask(p.get("mask"), dimension) if p.has("mask") else int(current.get("mask", {}).get("bits", 1))
	_Phys.set_collision_layers(n, layer_bits, mask_bits)
	var after := _Phys.get_collision_layers(n, dimension)
	return {"ok": true, "result": {"updated": true, "layer": after.get("layer"), "mask": after.get("mask")}}


func _h_list_layers(_ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(_ctx)
	var dim := str(p.get("dimension", "both"))
	var out := {"layers_2d": [], "layers_3d": []}
	if dim == "2d" or dim == "both":
		out["layers_2d"] = _Phys.list_layers("2d")
	if dim == "3d" or dim == "both":
		out["layers_3d"] = _Phys.list_layers("3d")
	return {"ok": true, "result": out}


func _h_set_layer_name(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var dimension := str(p.get("dimension", "3d"))
	var index := clampi(int(p.get("index", 1)), 1, 32)
	var layer_name := str(p.get("name", ""))
	ProjectSettings.set_setting(_Phys.layer_setting_key(dimension, index), layer_name)
	ProjectSettings.save()
	return {"ok": true, "result": {"updated": true, "index": index, "name": layer_name}}


func _h_raycast(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var ed := _Utils.require_editor(_dispatcher)
	if not ed.get("ok", false):
		return ed
	var tree := (ed.plugin as EditorPlugin).get_editor_interface().get_base_control().get_tree()
	var dimension := str(p.get("dimension", "3d"))
	var hit_areas := bool(p.get("hit_areas", false))
	if p.has("batch"):
		var batch: Array = p.get("batch") as Array
		if batch.size() > _Phys.RAYCAST_MAX_PER_CALL:
			return _err_batch_too_large()
		return {"ok": true, "result": {"results": _Phys.raycast_batch(tree, dimension, batch, hit_areas)}}
	var from_v := p.get("from")
	var to_v := p.get("to")
	var mask := _Phys.parse_bitmask(p.get("mask"), dimension)
	var exclude: Array = p.get("exclude", []) as Array
	var one := _Phys.raycast_one(tree, dimension, from_v, to_v, mask, exclude, hit_areas)
	return {"ok": true, "result": {"results": [one]}}


func _h_set_gravity(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var dimension := str(p.get("dimension", "3d"))
	var res := _Phys.set_gravity(dimension, p.get("direction"), p.get("magnitude"))
	return {"ok": true, "result": res}


func _err_shape_unknown(kind: String) -> Dictionary:
	return {
		"ok": false,
		"error": TerraVoltErrors.tv_rpc_error(
			TerraVoltErrors.PHYSICS_SHAPE_KIND_UNKNOWN,
			"physics.shape_kind_unknown",
			"Unknown physics shape or body kind.",
			{"kind": kind},
		),
	}


func _err_dimension_mismatch() -> Dictionary:
	return {
		"ok": false,
		"error": TerraVoltErrors.tv_rpc_error(
			TerraVoltErrors.PHYSICS_DIMENSION_MISMATCH,
			"physics.dimension_mismatch",
			"Node dimension does not match requested shape or operation.",
			{},
		),
	}


func _err_batch_too_large() -> Dictionary:
	return {
		"ok": false,
		"error": TerraVoltErrors.tv_rpc_error(
			TerraVoltErrors.PHYSICS_BATCH_TOO_LARGE,
			"physics.batch_too_large",
			"Raycast batch exceeds physics_raycast_max_per_call.",
			{"max": _Phys.RAYCAST_MAX_PER_CALL},
		),
	}
