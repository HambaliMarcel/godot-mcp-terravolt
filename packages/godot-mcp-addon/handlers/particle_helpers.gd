@tool
extends RefCounted
class_name TerraVoltParticleHelpers

## Shared particle helpers (task 19).

const _Utils := preload("./handler_utils.gd")

const PREVIEW_FRAMES_DEFAULT := 30
const PRESET_DIR := "res://addons/godot_mcp/presets/particle"

const BUILTIN_PRESETS := {
	"snow": {
		"description": "Gentle falling snowflakes with low gravity drift.",
		"material": {
			"gravity": {"x": 0, "y": 8, "z": 0},
			"initial_velocity_min": {"x": -0.5, "y": -1.0, "z": -0.5},
			"initial_velocity_max": {"x": 0.5, "y": -2.0, "z": 0.5},
			"scale_min": 0.05,
			"scale_max": 0.15,
		},
		"amount": 200,
		"lifetime": 4.0,
	},
	"fire": {
		"description": "Upward fire burst with warm color ramp.",
		"material": {
			"gravity": {"x": 0, "y": -2, "z": 0},
			"initial_velocity_min": {"x": -0.3, "y": 1.0, "z": -0.3},
			"initial_velocity_max": {"x": 0.3, "y": 3.0, "z": 0.3},
			"scale_min": 0.2,
			"scale_max": 0.8,
		},
		"amount": 300,
		"lifetime": 1.2,
	},
	"smoke": {
		"description": "Slow-rising grey smoke puffs.",
		"material": {
			"gravity": {"x": 0, "y": -0.5, "z": 0},
			"initial_velocity_min": {"x": -0.2, "y": 0.5, "z": -0.2},
			"initial_velocity_max": {"x": 0.2, "y": 1.5, "z": 0.2},
			"scale_min": 0.5,
			"scale_max": 1.5,
		},
		"amount": 150,
		"lifetime": 3.0,
	},
	"sparks": {
		"description": "Fast metallic sparks with short lifetime.",
		"material": {
			"gravity": {"x": 0, "y": -15, "z": 0},
			"initial_velocity_min": {"x": -4, "y": 2, "z": -4},
			"initial_velocity_max": {"x": 4, "y": 8, "z": 4},
			"scale_min": 0.02,
			"scale_max": 0.08,
		},
		"amount": 400,
		"lifetime": 0.6,
	},
	"dust": {
		"description": "Ground-hugging dust motes.",
		"material": {
			"gravity": {"x": 0, "y": -1, "z": 0},
			"initial_velocity_min": {"x": -0.8, "y": 0.1, "z": -0.8},
			"initial_velocity_max": {"x": 0.8, "y": 0.5, "z": 0.8},
			"scale_min": 0.03,
			"scale_max": 0.12,
		},
		"amount": 250,
		"lifetime": 2.0,
	},
}


static func gpu_supported() -> bool:
	return RenderingServer.get_rendering_device() != null


static func list_presets() -> Array:
	var out: Array = []
	for name in preset_names():
		var doc := preset_doc(name)
		out.append({"name": name, "description": str(doc.get("description", ""))})
	out.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))
	return out


static func preset_names() -> PackedStringArray:
	var names := PackedStringArray()
	for k in BUILTIN_PRESETS.keys():
		names.append(str(k))
	return names


static func preset_doc(name: String) -> Dictionary:
	var key := name.to_lower()
	if BUILTIN_PRESETS.has(key):
		return BUILTIN_PRESETS[key] as Dictionary
	var path := "%s/%s.json" % [PRESET_DIR, key]
	if ResourceLoader.exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(path)))
		if typeof(parsed) == TYPE_DICTIONARY:
			return parsed as Dictionary
	return {}


static func particle_node_class(dimension: String, use_gpu: bool) -> String:
	if dimension == "2d":
		return "GPUParticles2D" if use_gpu else "CPUParticles2D"
	return "GPUParticles3D" if use_gpu else "CPUParticles3D"


static func resolve_particles(node: Node) -> Variant:
	if node is GPUParticles2D or node is CPUParticles2D or node is GPUParticles3D or node is CPUParticles3D:
		return node
	return null


static func process_material(node: Variant) -> ParticleProcessMaterial:
	if node == null:
		return null
	var mat: Variant = node.process_material
	if mat is ParticleProcessMaterial:
		return mat
	var created := ParticleProcessMaterial.new()
	node.process_material = created
	return created


static func apply_material_patch(mat: ParticleProcessMaterial, patch: Dictionary) -> Dictionary:
	var applied: Dictionary = {}
	for k in patch.keys():
		var key := str(k)
		if not _Utils.has_property(mat, key):
			continue
		var before = mat.get(key)
		var after: Variant = _json_to_variant(patch[k], before)
		mat.set(key, after)
		applied[key] = {"before": before, "after": after}
	return applied


static func apply_preset_to_system(node: Variant, preset_name: String) -> Dictionary:
	var doc := preset_doc(preset_name)
	if doc.is_empty():
		return {"ok": false}
	if doc.has("amount"):
		node.set("amount", int(doc.get("amount", node.get("amount"))))
	if doc.has("lifetime"):
		node.set("lifetime", float(doc.get("lifetime", node.get("lifetime"))))
	var mat := process_material(node)
	if mat != null and doc.has("material"):
		apply_material_patch(mat, doc.get("material", {}) as Dictionary)
	return {"ok": true, "preset_name": preset_name}


static func set_emission(node: Variant, action: String, amount: int) -> Dictionary:
	match action:
		"play":
			node.emitting = true
		"stop":
			node.emitting = false
		"restart":
			node.restart()
			node.emitting = true
		"emit_once":
			if node.has_method("emit_particle"):
				node.emit_particle(node.transform, Vector3.ZERO, Color.WHITE, Color.WHITE, RID())
			else:
				node.restart()
				node.emitting = true
		_:
			pass
	return {"done": true, "emitting": bool(node.emitting)}


static func preview_export(tree: SceneTree, system: Variant, duration_s: float, fps: int, format: String) -> Dictionary:
	var frames := maxi(1, int(duration_s * fps))
	frames = mini(frames, PREVIEW_FRAMES_DEFAULT)
	var out_dir := "user://terravolt_particle_preview"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var paths: Array = []
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var dup: Node = system.duplicate()
	viewport.add_child(dup)
	if dup is Node2D:
		(dup as Node2D).position = Vector2(128, 128)
	elif dup is Node3D:
		(dup as Node3D).position = Vector3.ZERO
	dup.set("emitting", true)
	if dup.has_method("restart"):
		dup.restart()
	for i in frames:
		await tree.process_frame
		var img := viewport.get_texture().get_image()
		var rel := "%s/frame_%04d.png" % [out_dir, i]
		img.save_png(ProjectSettings.globalize_path(rel))
		paths.append(rel)
	viewport.queue_free()
	dup.queue_free()
	return {"exported": true, "paths": paths, "format": format if format != "png_sequence" else "png_sequence"}


static func _json_to_variant(v: Variant, hint: Variant) -> Variant:
	if v == null:
		return null
	if typeof(v) == TYPE_DICTIONARY:
		var d := v as Dictionary
		if d.has("__tv") and str(d.get("__tv")) == "Color":
			return Color(float(d.get("r", 1)), float(d.get("g", 1)), float(d.get("b", 1)), float(d.get("a", 1)))
		if hint is Vector2 or (typeof(hint) != TYPE_NIL and str(hint).begins_with("(")):
			return Vector3(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0))) if hint is Vector3 else Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
		if d.has("x") and d.has("y") and d.has("z"):
			return Vector3(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0)))
		if d.has("x") and d.has("y"):
			return Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
	return v
