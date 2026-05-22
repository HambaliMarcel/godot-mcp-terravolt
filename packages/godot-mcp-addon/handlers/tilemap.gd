@tool
extends RefCounted
class_name TerravoltTilemapHandlers

const _Utils := preload("./handler_utils.gd")
const _Tm := preload("./tilemap_helpers.gd")

var _dispatcher: TerravoltDispatcher
var _logger: TerravoltLogger


func attach(dispatcher: TerravoltDispatcher, logger: TerravoltLogger) -> void:
	_dispatcher = dispatcher
	_logger = logger
	_register_all()


func _register_all() -> void:
	var np := {"type": "string", "minLength": 1}
	_dispatcher.register("tilemap.describe", _schema({"path": np}, ["path"]), _h_describe)
	_dispatcher.register(
		"tilemap.set_cells",
		_schema({"path": np, "layer_name": {"type": "string"}, "cells": {"type": "array"}, "if_match": {}}, ["path", "cells"]),
		_h_set_cells
	)
	_dispatcher.register(
		"tilemap.fill",
		_schema(
			{
				"path": np,
				"layer_name": {"type": "string"},
				"rect": {"type": "object"},
				"polygon": {"type": "array"},
				"source_id": {"type": "integer"},
				"atlas_coords": {"type": "array"},
				"alternative_id": {"type": "integer"},
			},
			["path", "source_id", "atlas_coords"]
		),
		_h_fill
	)
	_dispatcher.register(
		"tilemap.query_cells",
		_schema({"path": np, "layer_name": {"type": "string"}, "rect": {"type": "object"}, "used_rect_only": {"type": "boolean"}}, ["path"]),
		_h_query_cells
	)
	_dispatcher.register("tilemap.tileset_info", _schema({"tileset_path": np}, ["tileset_path"]), _h_tileset_info)
	_dispatcher.register(
		"tilemap.terrain_paint",
		_schema(
			{
				"path": np,
				"layer_name": {"type": "string"},
				"cells": {"type": "array"},
				"terrain_set": {"type": "integer"},
				"terrain": {"type": "integer"},
				"ignore_empty_terrains": {"type": "boolean"},
			},
			["path", "cells", "terrain_set", "terrain"]
		),
		_h_terrain_paint
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
	return _err(int(g.get("code", -33964)), str(g.get("message", "tilemap.error")))


func _h_describe(ctx: Dictionary) -> Dictionary:
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	return _wrap(_Tm.describe(root, str(_Utils.params_dict(ctx).get("path", ""))))


func _h_set_cells(ctx: Dictionary) -> Dictionary:
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	return _wrap(_Tm.set_cells(root, _Utils.params_dict(ctx)))


func _h_fill(ctx: Dictionary) -> Dictionary:
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	var g := _Tm.fill(root, _Utils.params_dict(ctx))
	if not g.get("ok", false):
		return _err(int(g.get("code", -33964)), str(g.get("message", "tilemap.error")))
	var res: Dictionary = g.get("result", {})
	res["rect_or_poly_used"] = true
	return {"ok": true, "result": res}


func _h_query_cells(ctx: Dictionary) -> Dictionary:
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	return _wrap(_Tm.query_cells(root, _Utils.params_dict(ctx)))


func _h_tileset_info(ctx: Dictionary) -> Dictionary:
	var g := _Tm.tileset_info(str(_Utils.params_dict(ctx).get("tileset_path", "")))
	return _wrap(g)


func _h_terrain_paint(ctx: Dictionary) -> Dictionary:
	var root := _scene_root()
	if root == null:
		return _Utils.err_no_active_scene()
	return _wrap(_Tm.terrain_paint(root, _Utils.params_dict(ctx)))


func _err(code: int, symbol: String) -> Dictionary:
	return {"ok": false, "error": TerravoltErrors.tv_rpc_error(code, symbol, symbol, {})}
