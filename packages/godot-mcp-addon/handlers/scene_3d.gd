@tool
extends RefCounted
class_name TerraVoltScene3dHandlers

const _Utils := preload("./handler_utils.gd")
const _S3d := preload("./scene_3d_helpers.gd")

var _dispatcher: TerraVoltDispatcher
var _logger: TerraVoltLogger


func attach(dispatcher: TerraVoltDispatcher, logger: TerraVoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var np := {"type": "string", "minLength": 1}
	_dispatcher.register(
		"scene_3d.add_mesh_instance",
		_schema(
			{
				"parent_path": np,
				"name": {"type": "string"},
				"transform": {"type": "object"},
				"mesh": {"type": "object"},
				"material": {"type": "object"},
				"cast_shadow": {"type": "string"},
				"gi_mode": {"type": "string"},
			},
			["parent_path"],
		),
		_h_add_mesh_instance,
	)
	_dispatcher.register(
		"scene_3d.add_camera",
		_schema(
			{
				"parent_path": np,
				"name": {"type": "string"},
				"transform": {"type": "object"},
				"fov": {"type": "number"},
				"near": {"type": "number"},
				"far": {"type": "number"},
				"projection": {"type": "string"},
				"current": {"type": "boolean"},
				"cull_mask": {},
			},
			["parent_path"],
		),
		_h_add_camera,
	)
	_dispatcher.register(
		"scene_3d.add_light",
		_schema(
			{
				"parent_path": np,
				"name": {"type": "string"},
				"transform": {"type": "object"},
				"kind": {"type": "string"},
				"color": {},
				"energy": {"type": "number"},
				"shadow_enabled": {"type": "boolean"},
				"bake_mode": {"type": "string"},
				"range": {"type": "number"},
				"angle_deg": {"type": "number"},
				"inner_angle_deg": {"type": "number"},
			},
			["parent_path", "kind"],
		),
		_h_add_light,
	)
	_dispatcher.register(
		"scene_3d.set_environment",
		_schema({"scene_root_path": np, "spec": {"type": "object"}}, ["spec"]),
		_h_set_environment,
	)
	_dispatcher.register(
		"scene_3d.add_gridmap",
		_schema(
			{
				"parent_path": np,
				"name": {"type": "string"},
				"transform": {"type": "object"},
				"mesh_library_path": np,
				"cell_size": {"type": "object"},
				"cells": {"type": "array"},
			},
			["parent_path", "mesh_library_path"],
		),
		_h_add_gridmap,
	)
	_dispatcher.register(
		"scene_3d.frame_subject",
		_schema(
			{
				"camera_path": np,
				"subjects": {"type": "array"},
				"margin": {"type": "number"},
				"pitch_deg": {"type": "number"},
				"yaw_deg": {"type": "number"},
			},
			["camera_path", "subjects"],
		),
		_h_frame_subject,
	)


func _schema(props: Dictionary, required: Array = []) -> Dictionary:
	var s := {"type": "object", "properties": props, "additionalProperties": false}
	if not required.is_empty():
		s["required"] = required
	return s


func _scene_root() -> Node:
	var plug := _Utils.editor_plugin(_dispatcher)
	if plug == null:
		return null
	return plug.get_editor_interface().get_edited_scene_root()


func _wrap(g: Dictionary) -> Dictionary:
	if g.get("ok", false):
		return {"ok": true, "result": g.get("result", {})}
	return _err(int(g.get("code", -33980)), str(g.get("message", "scene_3d.error")))


func _h_add_mesh_instance(ctx: Dictionary) -> Dictionary:
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	return _wrap(_S3d.add_mesh_instance(root, _Utils.params_dict(ctx)))


func _h_add_camera(ctx: Dictionary) -> Dictionary:
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	return _wrap(_S3d.add_camera(root, _Utils.params_dict(ctx)))


func _h_add_light(ctx: Dictionary) -> Dictionary:
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	return _wrap(_S3d.add_light(root, _Utils.params_dict(ctx)))


func _h_set_environment(ctx: Dictionary) -> Dictionary:
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	return _wrap(_S3d.set_environment(root, _Utils.params_dict(ctx)))


func _h_add_gridmap(ctx: Dictionary) -> Dictionary:
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	return _wrap(_S3d.add_gridmap(root, _Utils.params_dict(ctx)))


func _h_frame_subject(ctx: Dictionary) -> Dictionary:
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	return _wrap(_S3d.frame_subject(root, _Utils.params_dict(ctx)))


func _err(code: int, symbol: String) -> Dictionary:
	return {"ok": false, "error": TerraVoltErrors.tv_rpc_error(code, symbol, symbol, {})}
