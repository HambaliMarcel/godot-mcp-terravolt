@tool
extends RefCounted
class_name TerravoltParticleHandlers

const _Utils := preload("./handler_utils.gd")
const _Parts := preload("./particle_helpers.gd")

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
		"particle.add_system",
		_schema(
			{
				"parent_path": np,
				"dimension": {"type": "string"},
				"use_gpu": {"type": "boolean"},
				"name": {"type": "string"},
				"transform": {"type": "object"},
				"amount": {"type": "integer"},
				"lifetime": {"type": "number"},
				"emitting": {"type": "boolean"},
				"material": {"type": "object"},
			},
			["parent_path", "dimension"],
		),
		_h_add_system,
	)
	_dispatcher.register(
		"particle.set_material",
		_schema({"material_path": np, "patch": {"type": "object"}, "if_match": {}}, ["material_path", "patch"]),
		_h_set_material,
	)
	_dispatcher.register(
		"particle.preview",
		_schema(
			{
				"system_path": np,
				"duration_s": {"type": "number"},
				"fps": {"type": "integer"},
				"format": {"type": "string"},
			},
			["system_path"],
		),
		_h_preview,
	)
	_dispatcher.register(
		"particle.set_emission",
		_schema({"system_path": np, "action": {"type": "string"}, "amount": {"type": "integer"}}, ["system_path", "action"]),
		_h_set_emission,
	)
	_dispatcher.register(
		"particle.list_presets",
		_schema({"apply_to": np, "preset_name": {"type": "string"}}),
		_h_list_presets,
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


func _h_add_system(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	var parent := _Utils.resolve_node(root, str(p.get("parent_path", ".")))
	if parent == null:
		return _Utils.err_node_not_found(str(p.get("parent_path", "")))
	var dimension := str(p.get("dimension", "3d"))
	var use_gpu := bool(p.get("use_gpu", true))
	var gpu_note := false
	if use_gpu and not _Parts.gpu_supported():
		use_gpu = false
		gpu_note = true
	var cls := _Parts.particle_node_class(dimension, use_gpu)
	var system: Node = ClassDB.instantiate(cls)
	if not str(p.get("name", "")).is_empty():
		system.name = str(p["name"])
	else:
		system.name = "Particles"
	if p.has("amount"):
		system.set("amount", int(p.get("amount")))
	if p.has("lifetime"):
		system.set("lifetime", float(p.get("lifetime")))
	system.set("emitting", bool(p.get("emitting", true)))
	var mat := _Parts.process_material(system)
	var material_path: Variant = null
	if mat != null:
		if p.has("material"):
			_Parts.apply_material_patch(mat, p.get("material", {}) as Dictionary)
		var save_path := "res://terravolt_particles/%s_material.tres" % system.name
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://terravolt_particles"))
		ResourceSaver.save(mat, save_path)
		material_path = save_path
	_Phys_apply_transform(system, p.get("transform"))
	parent.add_child(system)
	system.owner = root
	var added := str(root.get_path_to(system))
	var result := {
		"added_path": added,
		"system_path": added,
		"material_path": material_path,
		"state": "live",
		"revision": _bump_revision(added),
	}
	if gpu_note:
		result["gpu_fallback"] = true
	return {"ok": true, "result": result}


func _Phys_apply_transform(node: Node, spec: Variant) -> void:
	if typeof(spec) != TYPE_DICTIONARY:
		return
	const Phys := preload("./physics_helpers.gd")
	Phys.apply_transform(node, spec)


func _h_set_material(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var path := _Utils.resolve_resource_path(str(p.get("material_path", "")))
	if not ResourceLoader.exists(path):
		return _err_material_missing(path)
	if p.has("if_match") and str(p.get("if_match", "")) != _revision(path):
		return _err_idempotency()
	var mat: Resource = ResourceLoader.load(path)
	if not mat is ParticleProcessMaterial:
		return _err_material_missing(path)
	var applied := _Parts.apply_material_patch(mat as ParticleProcessMaterial, p.get("patch", {}) as Dictionary)
	ResourceSaver.save(mat, path)
	return {"ok": true, "result": {"updated": true, "applied": applied}}


func _h_preview(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var ed := _Utils.require_editor(_dispatcher)
	if not ed.get("ok", false):
		return ed
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	var system_node := _Utils.resolve_node(root, str(p.get("system_path", "")))
	var system := _Parts.resolve_particles(system_node)
	if system == null:
		return _Utils.err_node_not_found(str(p.get("system_path", "")))
	var tree := (ed.plugin as EditorPlugin).get_editor_interface().get_base_control().get_tree()
	var duration := float(p.get("duration_s", 1.0))
	var fps := int(p.get("fps", 24))
	var fmt := str(p.get("format", "gif"))
	var exported: Dictionary = await _Parts.preview_export(tree, system, duration, fps, fmt)
	return {"ok": true, "result": exported}


func _h_set_emission(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	var system_node := _Utils.resolve_node(root, str(p.get("system_path", "")))
	var system := _Parts.resolve_particles(system_node)
	if system == null:
		return _Utils.err_node_not_found(str(p.get("system_path", "")))
	var res := _Parts.set_emission(system, str(p.get("action", "play")), int(p.get("amount", 1)))
	return {"ok": true, "result": res}


func _h_list_presets(ctx: Dictionary) -> Dictionary:
	var p := _Utils.params_dict(ctx)
	var out := {"presets": _Parts.list_presets()}
	if p.has("apply_to") and p.has("preset_name"):
		var root := _scene_root()
		if root == null:
			return _Utils.err_no_active_scene()
		var target := _Utils.resolve_node(root, str(p.get("apply_to", "")))
		var system := _Parts.resolve_particles(target)
		if system == null:
			return _Utils.err_node_not_found(str(p.get("apply_to", "")))
		var preset := str(p.get("preset_name", ""))
		if _Parts.preset_doc(preset).is_empty():
			return _err_preset_unknown(preset)
		_Parts.apply_preset_to_system(system, preset)
		out["applied"] = {"preset_name": preset, "applied_to": str(root.get_path_to(target))}
	return {"ok": true, "result": out}


func _err_material_missing(path: String) -> Dictionary:
	return {
		"ok": false,
		"error": TerravoltErrors.tv_rpc_error(
			TerravoltErrors.RESOURCE_PATH_NOT_FOUND,
			"resource.path_not_found",
			"Particle process material not found.",
			{"path": path},
		),
	}


func _err_idempotency() -> Dictionary:
	return {
		"ok": false,
		"error": TerravoltErrors.tv_rpc_error(
			TerravoltErrors.PROTOCOL_IDEMPOTENCY_CONFLICT,
			"protocol.idempotency_conflict",
			"if_match revision does not match current material revision.",
			{},
		),
	}


func _err_preset_unknown(name: String) -> Dictionary:
	return {
		"ok": false,
		"error": TerravoltErrors.tv_rpc_error(
			TerravoltErrors.ASSET_PRESET_UNKNOWN,
			"asset.preset_unknown",
			"Unknown particle preset name.",
			{"preset": name},
		),
	}


func _err_gpu_unsupported() -> Dictionary:
	return {
		"ok": false,
		"error": TerravoltErrors.tv_rpc_error(
			TerravoltErrors.PARTICLE_GPU_UNSUPPORTED,
			"particle.gpu_unsupported",
			"GPU particles unavailable; fell back to CPU.",
			{},
		),
	}
