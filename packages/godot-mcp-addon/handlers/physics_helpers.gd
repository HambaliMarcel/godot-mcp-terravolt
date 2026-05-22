@tool
extends RefCounted
class_name TerraVoltPhysicsHelpers

## Shared physics helpers (task 19).

const RAYCAST_MAX_PER_CALL := 64

const BODY_CLASS := {
	"static": {"2d": "StaticBody2D", "3d": "StaticBody3D"},
	"rigid": {"2d": "RigidBody2D", "3d": "RigidBody3D"},
	"character": {"2d": "CharacterBody2D", "3d": "CharacterBody3D"},
	"area": {"2d": "Area2D", "3d": "Area3D"},
	"animatable": {"2d": "AnimatableBody2D", "3d": "AnimatableBody3D"},
}

const SHAPE_CLASS_3D := {
	"box": "BoxShape3D",
	"sphere": "SphereShape3D",
	"capsule": "CapsuleShape3D",
	"cylinder": "CylinderShape3D",
	"convex": "ConvexPolygonShape3D",
	"concave": "ConcavePolygonShape3D",
	"world_boundary": "WorldBoundaryShape3D",
}

const SHAPE_CLASS_2D := {
	"rectangle": "RectangleShape2D",
	"box": "RectangleShape2D",
	"circle": "CircleShape2D",
	"capsule": "CapsuleShape2D",
	"segment": "SegmentShape2D",
	"world_boundary": "WorldBoundaryShape2D",
}


static func layer_setting_prefix(dimension: String) -> String:
	return "layer_names/2d_physics" if dimension == "2d" else "layer_names/3d_physics"


static func layer_setting_key(dimension: String, index_1: int) -> String:
	return "%s/layer_%d" % [layer_setting_prefix(dimension), index_1]


static func list_layers(dimension: String) -> Array:
	var out: Array = []
	for i in range(1, 33):
		var key := layer_setting_key(dimension, i)
		var name := str(ProjectSettings.get_setting(key, ""))
		if not name.is_empty():
			out.append({"index": i, "name": name})
	return out


static func layer_name_to_index(dimension: String, layer_name: String) -> int:
	for row in list_layers(dimension):
		if str(row.get("name", "")) == layer_name:
			return int(row.get("index", 0))
	return 0


static func parse_bitmask(spec: Variant, dimension: String) -> int:
	if spec == null:
		return 0xFFFFFFFF
	if typeof(spec) == TYPE_INT or typeof(spec) == TYPE_FLOAT:
		return int(spec)
	if typeof(spec) != TYPE_DICTIONARY:
		return 0xFFFFFFFF
	var d := spec as Dictionary
	if d.has("bits"):
		return int(d.get("bits", 0))
	if d.has("named"):
		var bits := 0
		for nm in d.get("named", []) as Array:
			var idx := layer_name_to_index(dimension, str(nm))
			if idx > 0:
				bits |= 1 << (idx - 1)
		return bits
	return 0xFFFFFFFF


static func bitmask_dict(bits: int, dimension: String) -> Dictionary:
	var names: Array[String] = []
	for row in list_layers(dimension):
		var idx := int(row.get("index", 0))
		if idx > 0 and (bits & (1 << (idx - 1))) != 0:
			names.append(str(row.get("name", "")))
	return {"bits": bits, "names": names}


static func apply_transform(node: Node, spec: Variant) -> void:
	if typeof(spec) != TYPE_DICTIONARY:
		return
	var d := spec as Dictionary
	if node is Node2D:
		var n2 := node as Node2D
		if d.has("position"):
			n2.position = _vec2(d.get("position"))
		if d.has("rotation"):
			var rot: Variant = d.get("rotation")
			if typeof(rot) == TYPE_FLOAT or typeof(rot) == TYPE_INT:
				n2.rotation = float(rot)
			else:
				n2.rotation = float(_vec2(rot).x)
		if d.has("scale"):
			n2.scale = _vec2(d.get("scale"))
		if d.has("transform2d"):
			n2.transform = _transform2d_from_array(d.get("transform2d"))
	elif node is Node3D:
		var n3 := node as Node3D
		if d.has("position"):
			n3.position = _vec3(d.get("position"))
		if d.has("rotation"):
			var rot: Variant = d.get("rotation")
			if typeof(rot) == TYPE_DICTIONARY and rot.has("w"):
				n3.rotation = (_quat(rot) as Quaternion).get_euler()
			else:
				n3.rotation = _vec3(rot)
		if d.has("scale"):
			n3.scale = _vec3(d.get("scale"))
		if d.has("transform3d"):
			n3.transform = _transform3d_from_array(d.get("transform3d"))


static func create_body(kind: String, dimension: String) -> Node:
	var map: Dictionary = BODY_CLASS.get(kind, {}) as Dictionary
	var cls := str(map.get(dimension, ""))
	if cls.is_empty() or not ClassDB.class_exists(cls):
		return null
	return ClassDB.instantiate(cls) as Node


static func create_shape(kind: String, dimension: String, params: Dictionary) -> Variant:
	var table := SHAPE_CLASS_3D if dimension == "3d" else SHAPE_CLASS_2D
	var cls := str(table.get(kind, ""))
	if cls.is_empty() or not ClassDB.class_exists(cls):
		return null
	var shape: Variant = ClassDB.instantiate(cls)
	_apply_shape_params(shape, kind, dimension, params)
	return shape


static func _apply_shape_params(shape: Variant, kind: String, dimension: String, params: Dictionary) -> void:
	if shape == null:
		return
	match kind:
		"box", "rectangle":
			if dimension == "3d" and shape is BoxShape3D:
				var ext := _vec3(params.get("extents", params.get("size", {"x": 0.5, "y": 0.5, "z": 0.5})))
				(shape as BoxShape3D).size = ext * 2.0
			elif shape is RectangleShape2D:
				var sz := _vec2(params.get("size", {"x": 1, "y": 1}))
				(shape as RectangleShape2D).size = sz
		"sphere", "circle":
			var r := float(params.get("radius", 0.5))
			if shape is SphereShape3D:
				(shape as SphereShape3D).radius = r
			elif shape is CircleShape2D:
				(shape as CircleShape2D).radius = r
		"capsule":
			if shape is CapsuleShape3D:
				(shape as CapsuleShape3D).radius = float(params.get("radius", 0.5))
				(shape as CapsuleShape3D).height = float(params.get("height", 1.0))
			elif shape is CapsuleShape2D:
				(shape as CapsuleShape2D).radius = float(params.get("radius", 0.5))
				(shape as CapsuleShape2D).height = float(params.get("height", 1.0))
		"cylinder":
			if shape is CylinderShape3D:
				(shape as CylinderShape3D).radius = float(params.get("radius", 0.5))
				(shape as CylinderShape3D).height = float(params.get("height", 1.0))
		"segment":
			if shape is SegmentShape2D:
				(shape as SegmentShape2D).a = _vec2(params.get("a", {"x": -0.5, "y": 0}))
				(shape as SegmentShape2D).b = _vec2(params.get("b", {"x": 0.5, "y": 0}))
		"world_boundary":
			if shape is WorldBoundaryShape3D:
				(shape as WorldBoundaryShape3D).plane = Plane(_vec3(params.get("normal", {"x": 0, "y": 1, "z": 0})), float(params.get("distance", 0)))
			elif shape is WorldBoundaryShape2D:
				(shape as WorldBoundaryShape2D).normal = _vec2(params.get("normal", {"x": 0, "y": -1}))
				(shape as WorldBoundaryShape2D).distance = float(params.get("distance", 0))
		_:
			pass


static func collision_object(node: Node) -> Variant:
	if node is CollisionObject2D or node is CollisionObject3D:
		return node
	return null


static func set_collision_layers(node: Node, layer_bits: int, mask_bits: int) -> void:
	var co: Variant = collision_object(node)
	if co == null:
		return
	if co is CollisionObject2D:
		(co as CollisionObject2D).collision_layer = layer_bits
		(co as CollisionObject2D).collision_mask = mask_bits
	elif co is CollisionObject3D:
		(co as CollisionObject3D).collision_layer = layer_bits
		(co as CollisionObject3D).collision_mask = mask_bits


static func get_collision_layers(node: Node, dimension: String) -> Dictionary:
	var co: Variant = collision_object(node)
	if co == null:
		return {"layer": {"bits": 0, "names": []}, "mask": {"bits": 0, "names": []}}
	var layer := 0
	var mask := 0
	if co is CollisionObject2D:
		layer = (co as CollisionObject2D).collision_layer
		mask = (co as CollisionObject2D).collision_mask
	elif co is CollisionObject3D:
		layer = (co as CollisionObject3D).collision_layer
		mask = (co as CollisionObject3D).collision_mask
	return {"layer": bitmask_dict(layer, dimension), "mask": bitmask_dict(mask, dimension)}


static func dimension_for_node(node: Node) -> String:
	if node is Node2D or node is CollisionObject2D:
		return "2d"
	if node is Node3D or node is CollisionObject3D:
		return "3d"
	return ""


static func gravity_state(dimension: String) -> Dictionary:
	if dimension == "2d":
		var vec := Vector2(ProjectSettings.get_setting("physics/2d/default_gravity_vector", Vector2.DOWN))
		var mag := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
		if vec.length_squared() < 0.0001:
			vec = Vector2.DOWN
		return {"direction": {"x": vec.normalized().x, "y": vec.normalized().y}, "magnitude": mag}
	var vec3 := Vector3(ProjectSettings.get_setting("physics/3d/default_gravity_vector", Vector3.DOWN))
	var mag3 := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if vec3.length_squared() < 0.0001:
		vec3 = Vector3.DOWN
	return {
		"direction": {"x": vec3.normalized().x, "y": vec3.normalized().y, "z": vec3.normalized().z},
		"magnitude": mag3,
	}


static func set_gravity(dimension: String, direction: Variant, magnitude: Variant) -> Dictionary:
	var before := gravity_state(dimension)
	if dimension == "2d":
		var dir := _vec2(direction if direction != null else before.get("direction"))
		if dir.length_squared() < 0.0001:
			dir = Vector2.DOWN
		var mag := float(magnitude) if magnitude != null else float(before.get("magnitude", 980.0))
		ProjectSettings.set_setting("physics/2d/default_gravity_vector", dir.normalized())
		ProjectSettings.set_setting("physics/2d/default_gravity", mag)
	else:
		var dir3 := _vec3(direction if direction != null else before.get("direction"))
		if dir3.length_squared() < 0.0001:
			dir3 = Vector3.DOWN
		var mag3 := float(magnitude) if magnitude != null else float(before.get("magnitude", 9.8))
		ProjectSettings.set_setting("physics/3d/default_gravity_vector", dir3.normalized())
		ProjectSettings.set_setting("physics/3d/default_gravity", mag3)
	ProjectSettings.save()
	return {"before": before, "after": gravity_state(dimension)}


static func raycast_batch(tree: SceneTree, dimension: String, queries: Array, hit_areas: bool) -> Array:
	var results: Array = []
	for q_v in queries:
		if typeof(q_v) != TYPE_DICTIONARY:
			continue
		var q := q_v as Dictionary
		results.append(
			raycast_one(
				tree,
				dimension,
				_vec_for_dim(dimension, q.get("from")),
				_vec_for_dim(dimension, q.get("to")),
				parse_bitmask(q.get("mask"), dimension),
				q.get("exclude", []) as Array,
				hit_areas,
			)
		)
	return results


static func raycast_one(
	tree: SceneTree,
	dimension: String,
	from_v: Variant,
	to_v: Variant,
	mask: int,
	exclude: Array,
	hit_areas: bool,
) -> Dictionary:
	if dimension == "2d":
		var space := tree.root.get_world_2d().direct_space_state
		var query := PhysicsRayQueryParameters2D.create(from_v as Vector2, to_v as Vector2)
		query.collision_mask = mask
		query.hit_from_inside = true
		query.collide_with_areas = hit_areas
		for ex in exclude:
			var n := tree.root.get_node_or_null(NodePath(str(ex)))
			if n is CollisionObject2D:
				query.exclude.append(n.get_rid())
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return {"hit": false}
		var collider: Object = hit.get("collider")
		var path := ""
		if collider is Node:
			path = str((collider as Node).get_path())
		return {
			"hit": true,
			"position": {"x": (hit.get("position") as Vector2).x, "y": (hit.get("position") as Vector2).y},
			"normal": {"x": (hit.get("normal") as Vector2).x, "y": (hit.get("normal") as Vector2).y},
			"collider_path": path,
			"distance": from_v.distance_to(hit.get("position")),
		}
	var space3 := tree.root.get_world_3d().direct_space_state
	var query3 := PhysicsRayQueryParameters3D.create(from_v as Vector3, to_v as Vector3)
	query3.collision_mask = mask
	query3.hit_from_inside = true
	query3.collide_with_areas = hit_areas
	for ex in exclude:
		var n3 := tree.root.get_node_or_null(NodePath(str(ex)))
		if n3 is CollisionObject3D:
			query3.exclude.append(n3.get_rid())
	var hit3 := space3.intersect_ray(query3)
	if hit3.is_empty():
		return {"hit": false}
	var collider3: Object = hit3.get("collider")
	var path3 := ""
	if collider3 is Node:
		path3 = str((collider3 as Node).get_path())
	var pos3: Vector3 = hit3.get("position")
	var norm3: Vector3 = hit3.get("normal")
	return {
		"hit": true,
		"position": {"x": pos3.x, "y": pos3.y, "z": pos3.z},
		"normal": {"x": norm3.x, "y": norm3.y, "z": norm3.z},
		"collider_path": path3,
		"distance": (from_v as Vector3).distance_to(pos3),
	}


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


static func _quat(v: Variant) -> Quaternion:
	if v is Quaternion:
		return v
	if typeof(v) == TYPE_DICTIONARY:
		var d := v as Dictionary
		return Quaternion(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0)), float(d.get("w", 1)))
	return Quaternion.IDENTITY


static func _vec_for_dim(dimension: String, v: Variant) -> Variant:
	return _vec2(v) if dimension == "2d" else _vec3(v)


static func _transform2d_from_array(raw: Variant) -> Transform2D:
	if typeof(raw) != TYPE_ARRAY or (raw as Array).size() < 3:
		return Transform2D.IDENTITY
	var a := raw as Array
	var row0: Array = a[0]
	var row1: Array = a[1]
	var row2: Array = a[2]
	return Transform2D(
		Vector2(float(row0[0]), float(row0[1])),
		Vector2(float(row1[0]), float(row1[1])),
		Vector2(float(row2[0]), float(row2[1])),
	)


static func _transform3d_from_array(raw: Variant) -> Transform3D:
	if typeof(raw) != TYPE_ARRAY or (raw as Array).size() < 4:
		return Transform3D.IDENTITY
	var a := raw as Array
	var bx: Array = a[0]
	var by: Array = a[1]
	var bz: Array = a[2]
	var origin: Array = a[3]
	return Transform3D(
		Basis(
			Vector3(float(bx[0]), float(bx[1]), float(bx[2])),
			Vector3(float(by[0]), float(by[1]), float(by[2])),
			Vector3(float(bz[0]), float(bz[1]), float(bz[2])),
		),
		Vector3(float(origin[0]), float(origin[1]), float(origin[2])),
	)
