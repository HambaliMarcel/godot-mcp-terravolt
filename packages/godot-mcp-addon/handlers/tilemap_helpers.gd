@tool
extends RefCounted
class_name TerraVoltTilemapHelpers

## Shared tilemap / TileMapLayer helpers (task 20).

const MAX_CELLS_PER_CALL := 4096

const _Res := preload("./resource_helpers.gd")


static func api_uses_tilemap_layer() -> bool:
	return ClassDB.class_exists("TileMapLayer")


static func resolve_node(root: Node, path: String) -> Node:
	if root == null:
		return null
	var p := path.strip_edges()
	if p.is_empty() or p == ".":
		return root
	return root.get_node_or_null(NodePath(p))


static func resolve_target(root: Node, path: String, layer_name: String = "") -> Dictionary:
	var n := resolve_node(root, path)
	if n == null:
		return {"ok": false, "code": -33964, "message": "tilemap.node_invalid"}
	if n is TileMapLayer:
		return {"ok": true, "layer": n as TileMapLayer, "kind": "tilemaplayer", "api_version": "layer"}
	if n is TileMap:
		var tm := n as TileMap
		if api_uses_tilemap_layer():
			var layer: TileMapLayer = null
			if not layer_name.is_empty():
				for ch in tm.get_children():
					if ch is TileMapLayer and str(ch.name) == layer_name:
						layer = ch as TileMapLayer
						break
			if layer == null:
				for ch in tm.get_children():
					if ch is TileMapLayer:
						layer = ch as TileMapLayer
						break
			if layer != null:
				return {"ok": true, "layer": layer, "kind": "tilemap", "api_version": "layer", "parent": tm}
		return {"ok": true, "tilemap": tm, "kind": "tilemap", "api_version": "legacy"}
	return {"ok": false, "code": -33964, "message": "tilemap.node_invalid"}


static func describe(root: Node, path: String) -> Dictionary:
	var t := resolve_target(root, path)
	if not t.get("ok", false):
		return t
	var layers: Array = []
	var used_rect := Rect2i()
	var atlas_sources: Array = []
	var tileset_path: Variant = null
	if t.has("layer"):
		var layer: TileMapLayer = t["layer"]
		var ts := layer.tile_set
		if ts:
			tileset_path = ts.resource_path if ts.resource_path.length() > 0 else null
			atlas_sources = _atlas_sources(ts)
		used_rect = layer.get_used_rect()
		return {
			"ok": true,
			"result": {
				"kind": str(t.get("kind", "tilemaplayer")),
				"api_version": str(t.get("api_version", "layer")),
				"tileset_path": tileset_path,
				"layers": layers,
				"used_rect": _rect_dict(used_rect),
				"atlas_sources": atlas_sources,
			},
		}
	var tm: TileMap = t["tilemap"]
	if api_uses_tilemap_layer():
		for ch in tm.get_children():
			if ch is TileMapLayer:
				var lay := ch as TileMapLayer
				layers.append({"name": lay.name, "z_index": lay.z_index, "modulate": _Res.variant_to_json(lay.modulate)})
	else:
		for i in tm.get_layers_count():
			layers.append(
				{
					"name": tm.get_layer_name(i),
					"z_index": tm.get_layer_z_index(i),
					"modulate": _Res.variant_to_json(tm.get_layer_modulate(i)),
				}
			)
	var ts2 := tm.tile_set
	if ts2:
		tileset_path = ts2.resource_path if ts2.resource_path.length() > 0 else null
		atlas_sources = _atlas_sources(ts2)
	used_rect = tm.get_used_rect()
	return {
		"ok": true,
		"result": {
			"kind": "tilemap",
			"api_version": "legacy",
			"tileset_path": tileset_path,
			"layers": layers,
			"used_rect": _rect_dict(used_rect),
			"atlas_sources": atlas_sources,
		},
	}


static func set_cells(root: Node, params: Dictionary) -> Dictionary:
	var cells: Array = params.get("cells", [])
	if cells.size() > MAX_CELLS_PER_CALL:
		return {"ok": false, "code": -33960, "message": "tilemap.cell_batch_too_large"}
	var layer_name := str(params.get("layer_name", ""))
	var t := resolve_target(root, str(params.get("path", "")), layer_name)
	if not t.get("ok", false):
		return t
	var written := 0
	var cleared := 0
	if t.has("layer"):
		var layer: TileMapLayer = t["layer"]
		var ts := layer.tile_set
		for c_v in cells:
			if typeof(c_v) != TYPE_DICTIONARY:
				continue
			var c := c_v as Dictionary
			var pos := _cell_pos(c.get("position"))
			if bool(c.get("clear", false)):
				layer.erase_cell(pos)
				cleared += 1
				continue
			var sid := int(c.get("source_id", -1))
			var atlas := _cell_atlas(c.get("atlas_coords"))
			if ts and sid >= 0 and not _source_exists(ts, sid):
				return {"ok": false, "code": -33961, "message": "tilemap.atlas_unknown"}
			var alt := int(c.get("alternative_id", 0))
			layer.set_cell(pos, sid, atlas, alt)
			written += 1
	else:
		var tm: TileMap = t["tilemap"]
		var li := _legacy_layer_index(tm, layer_name)
		if li < 0:
			return {"ok": false, "code": -33963, "message": "tilemap.layer_unknown"}
		for c_v in cells:
			if typeof(c_v) != TYPE_DICTIONARY:
				continue
			var c := c_v as Dictionary
			var pos := _cell_pos(c.get("position"))
			if bool(c.get("clear", false)):
				tm.erase_cell(li, pos)
				cleared += 1
				continue
			var sid := int(c.get("source_id", 0))
			var atlas := _cell_atlas(c.get("atlas_coords"))
			var alt := int(c.get("alternative_id", 0))
			tm.set_cell(li, pos, sid, atlas, alt)
			written += 1
	var rev := str(Time.get_ticks_msec())
	return {
		"ok": true,
		"result": {
			"written": written,
			"cleared": cleared,
			"state": {"revision": rev},
			"revision": rev,
		},
	}


static func fill(root: Node, params: Dictionary) -> Dictionary:
	var t := resolve_target(root, str(params.get("path", "")), str(params.get("layer_name", "")))
	if not t.get("ok", false):
		return t
	var sid := int(params.get("source_id", 0))
	var atlas := _cell_atlas(params.get("atlas_coords"))
	var alt := int(params.get("alternative_id", 0))
	var positions: Array[Vector2i] = []
	if params.has("polygon") and typeof(params.get("polygon")) == TYPE_ARRAY:
		positions = _polygon_cells(params.get("polygon") as Array)
	elif params.has("rect") and typeof(params.get("rect")) == TYPE_DICTIONARY:
		var r: Dictionary = params.get("rect") as Dictionary
		var x0 := int(r.get("x", 0))
		var y0 := int(r.get("y", 0))
		var w := int(r.get("w", 0))
		var h := int(r.get("h", 0))
		for x in range(x0, x0 + w):
			for y in range(y0, y0 + h):
				positions.append(Vector2i(x, y))
	if positions.size() > MAX_CELLS_PER_CALL:
		return {"ok": false, "code": -33960, "message": "tilemap.cell_batch_too_large"}
	var cells: Array = []
	for pos in positions:
		cells.append({"position": [pos.x, pos.y], "source_id": sid, "atlas_coords": [atlas.x, atlas.y], "alternative_id": alt})
	return set_cells(root, {"path": params.get("path", ""), "layer_name": params.get("layer_name", ""), "cells": cells})


static func query_cells(root: Node, params: Dictionary) -> Dictionary:
	var t := resolve_target(root, str(params.get("path", "")), str(params.get("layer_name", "")))
	if not t.get("ok", false):
		return t
	var used_only := bool(params.get("used_rect_only", false))
	var rect: Rect2i = Rect2i()
	if params.has("rect") and typeof(params.get("rect")) == TYPE_DICTIONARY:
		var r: Dictionary = params.get("rect") as Dictionary
		rect = Rect2i(int(r.get("x", 0)), int(r.get("y", 0)), int(r.get("w", 0)), int(r.get("h", 0)))
	var cells: Array = []
	if t.has("layer"):
		var layer: TileMapLayer = t["layer"]
		var used := layer.get_used_rect() if used_only else rect
		if used_only:
			rect = used
		for coords in layer.get_used_cells():
			if used_only or _in_rect(coords, rect):
				cells.append(_cell_out(layer, coords, true))
	else:
		var tm: TileMap = t["tilemap"]
		var li := _legacy_layer_index(tm, str(params.get("layer_name", "")))
		if li < 0:
			return {"ok": false, "code": -33963, "message": "tilemap.layer_unknown"}
		for coords in tm.get_used_cells(li):
			if used_only or _in_rect(coords, rect):
				cells.append(_cell_out_legacy(tm, li, coords))
	return {"ok": true, "result": {"cells": cells, "rect_used": _rect_dict(rect)}}


static func tileset_info(tileset_path: String) -> Dictionary:
	var p := _Res.resolve_path(tileset_path)
	var ts := _Res.load_resource(p)
	if ts == null or not ts is TileSet:
		return {"ok": false, "code": -33800, "message": "resource.path_not_found"}
	var tile_set := ts as TileSet
	var sources: Array = []
	for i in tile_set.get_source_count():
		var sid := tile_set.get_source_id(i)
		var src := tile_set.get_source(sid)
		var entry := {"source_id": sid, "class": src.get_class() if src else "Unknown"}
		if src is TileSetAtlasSource:
			var atlas := src as TileSetAtlasSource
			var tex_path := atlas.texture.resource_path if atlas.texture else ""
			entry["atlas_path"] = tex_path
			entry["size"] = {"w": atlas.texture_region_size.x, "h": atlas.texture_region_size.y}
			entry["texture_region"] = _rect_dict(Rect2i(Vector2i.ZERO, atlas.texture_region_size))
		sources.append(entry)
	var custom: Array = []
	for ci in tile_set.get_custom_data_layers_count():
		custom.append({"name": tile_set.get_custom_data_layer_name(ci), "type": tile_set.get_custom_data_layer_type(ci)})
	var terrain_sets: Array = []
	for ti in tile_set.get_terrain_sets_count():
		var terrains: Array = []
		for j in tile_set.get_terrain_count(ti):
			terrains.append(
				{
					"name": tile_set.get_terrain_name(ti, j),
					"color": _Res.variant_to_json(tile_set.get_terrain_color(ti, j)),
				}
			)
		terrain_sets.append(
			{
				"name": tile_set.get_terrain_set_name(ti),
				"mode": tile_set.get_terrain_set_mode(ti),
				"terrains": terrains,
			}
		)
	return {
		"ok": true,
		"result": {
			"tile_size": {"w": tile_set.tile_size.x, "h": tile_set.tile_size.y},
			"sources": sources,
			"custom_data_layers": custom,
			"terrain_sets": terrain_sets,
		},
	}


static func terrain_paint(root: Node, params: Dictionary) -> Dictionary:
	var cells_v: Array = params.get("cells", [])
	if cells_v.size() > MAX_CELLS_PER_CALL:
		return {"ok": false, "code": -33960, "message": "tilemap.cell_batch_too_large"}
	var t := resolve_target(root, str(params.get("path", "")), str(params.get("layer_name", "")))
	if not t.get("ok", false):
		return t
	var terrain_set := int(params.get("terrain_set", 0))
	var terrain := int(params.get("terrain", 0))
	var ignore_empty := bool(params.get("ignore_empty_terrains", true))
	var cells: Array[Vector2i] = []
	for v in cells_v:
		if typeof(v) == TYPE_ARRAY:
			var a: Array = v
			if a.size() >= 2:
				cells.append(Vector2i(int(a[0]), int(a[1])))
		elif typeof(v) == TYPE_DICTIONARY:
			var d: Dictionary = v
			cells.append(Vector2i(int(d.get("x", 0)), int(d.get("y", 0))))
	if t.has("layer"):
		var layer: TileMapLayer = t["layer"]
		var ts := layer.tile_set
		if ts == null or terrain_set >= ts.get_terrain_sets_count():
			return {"ok": false, "code": -33962, "message": "tilemap.terrain_unknown"}
		if terrain >= ts.get_terrain_count(terrain_set):
			return {"ok": false, "code": -33962, "message": "tilemap.terrain_unknown"}
		layer.set_cells_terrain_connect(cells, terrain_set, terrain, ignore_empty)
	else:
		var tm: TileMap = t["tilemap"]
		var li := _legacy_layer_index(tm, str(params.get("layer_name", "")))
		if li < 0:
			return {"ok": false, "code": -33963, "message": "tilemap.layer_unknown"}
		tm.set_cells_terrain_connect(li, cells, terrain_set, terrain, ignore_empty)
	var rev := str(Time.get_ticks_msec())
	return {
		"ok": true,
		"result": {
			"written": cells.size(),
			"neighbors_recomputed": cells.size(),
			"state": {"revision": rev},
			"revision": rev,
		},
	}


static func _legacy_layer_index(tm: TileMap, layer_name: String) -> int:
	if tm.get_layers_count() == 0:
		return -1
	if layer_name.is_empty():
		return 0
	for i in tm.get_layers_count():
		if tm.get_layer_name(i) == layer_name:
			return i
	return -1


static func _source_exists(ts: TileSet, source_id: int) -> bool:
	for i in ts.get_source_count():
		if ts.get_source_id(i) == source_id:
			return true
	return false


static func _atlas_sources(ts: TileSet) -> Array:
	var out: Array = []
	for i in ts.get_source_count():
		var sid := ts.get_source_id(i)
		var src := ts.get_source(sid)
		if src is TileSetAtlasSource:
			var atlas := src as TileSetAtlasSource
			out.append(
				{
					"source_id": sid,
					"atlas_path": atlas.texture.resource_path if atlas.texture else "",
					"size": {"w": atlas.texture_region_size.x, "h": atlas.texture_region_size.y},
					"texture_region": _rect_dict(Rect2i(Vector2i.ZERO, atlas.texture_region_size)),
				}
			)
	return out


static func _cell_pos(v: Variant) -> Vector2i:
	if typeof(v) == TYPE_ARRAY:
		var a: Array = v
		if a.size() >= 2:
			return Vector2i(int(a[0]), int(a[1]))
	return Vector2i.ZERO


static func _cell_atlas(v: Variant) -> Vector2i:
	if typeof(v) == TYPE_ARRAY:
		var a: Array = v
		if a.size() >= 2:
			return Vector2i(int(a[0]), int(a[1]))
	return Vector2i.ZERO


static func _rect_dict(r: Rect2i) -> Dictionary:
	return {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y}


static func _in_rect(c: Vector2i, r: Rect2i) -> bool:
	if r.size.x <= 0 or r.size.y <= 0:
		return true
	return c.x >= r.position.x and c.y >= r.position.y and c.x < r.position.x + r.size.x and c.y < r.position.y + r.size.y


static func _cell_out(layer: TileMapLayer, coords: Vector2i, layer_mode: bool) -> Dictionary:
	return {
		"position": [coords.x, coords.y],
		"source_id": layer.get_cell_source_id(coords),
		"atlas_coords": [layer.get_cell_atlas_coords(coords).x, layer.get_cell_atlas_coords(coords).y],
		"alternative_id": layer.get_cell_alternative_tile(coords),
	}


static func _cell_out_legacy(tm: TileMap, layer: int, coords: Vector2i) -> Dictionary:
	return {
		"position": [coords.x, coords.y],
		"source_id": tm.get_cell_source_id(layer, coords),
		"atlas_coords": [tm.get_cell_atlas_coords(layer, coords).x, tm.get_cell_atlas_coords(layer, coords).y],
		"alternative_id": tm.get_cell_alternative_tile(layer, coords),
	}


static func _polygon_cells(poly: Array) -> Array[Vector2i]:
	var pts: PackedVector2Array = PackedVector2Array()
	for v in poly:
		if typeof(v) == TYPE_ARRAY:
			var a: Array = v
			if a.size() >= 2:
				pts.append(Vector2(float(a[0]), float(a[1])))
		elif typeof(v) == TYPE_DICTIONARY:
			var d: Dictionary = v
			pts.append(Vector2(float(d.get("x", 0)), float(d.get("y", 0))))
	if pts.size() < 3:
		return []
	var min_x := int(floor(pts[0].x))
	var max_x := min_x
	var min_y := int(floor(pts[0].y))
	var max_y := min_y
	for i in range(1, pts.size()):
		min_x = mini(min_x, int(floor(pts[i].x)))
		max_x = maxi(max_x, int(ceil(pts[i].x)))
		min_y = mini(min_y, int(floor(pts[i].y)))
		max_y = maxi(max_y, int(ceil(pts[i].y)))
	var out: Array[Vector2i] = []
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				out.append(Vector2i(x, y))
	return out
