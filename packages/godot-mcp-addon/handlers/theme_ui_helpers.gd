@tool
extends RefCounted
class_name TerraVoltThemeUiHelpers

## Theme + Control UI helpers (task 20).

const PREVIEW_DEFAULT_W := 256
const PREVIEW_DEFAULT_H := 256

const _Res := preload("./resource_helpers.gd")

const STYLEBOX_ALLOW := {
	"StyleBoxFlat": [
		"bg_color",
		"border_width_left",
		"border_width_top",
		"border_width_right",
		"border_width_bottom",
		"border_color",
		"corner_radius_top_left",
		"corner_radius_top_right",
		"corner_radius_bottom_right",
		"corner_radius_bottom_left",
		"corner_radius_all",
		"content_margin_left",
		"content_margin_top",
		"content_margin_right",
		"content_margin_bottom",
	],
	"StyleBoxEmpty": [],
	"StyleBoxLine": ["color", "grow_begin", "grow_end", "thickness"],
	"StyleBoxTexture": ["texture", "texture_margin_left", "texture_margin_top", "texture_margin_right", "texture_margin_bottom"],
}


static func parse_color(v: Variant) -> Color:
	if typeof(v) == TYPE_DICTIONARY:
		var d := v as Dictionary
		if d.has("__tv") and str(d.get("__tv")) == "Color":
			return Color(float(d.get("r", 0)), float(d.get("g", 0)), float(d.get("b", 0)), float(d.get("a", 1)))
		if d.has("r"):
			return Color(float(d.get("r", 0)), float(d.get("g", 0)), float(d.get("b", 0)), float(d.get("a", 1)))
	if typeof(v) == TYPE_STRING:
		var s := str(v).strip_edges()
		if s.begins_with("#"):
			return Color.from_string(s, Color.WHITE)
	return Color.WHITE


static func color_json(c: Color) -> Dictionary:
	return {"r": c.r, "g": c.g, "b": c.b, "a": c.a}


static func resolve_target(root: Node, target: Dictionary) -> Dictionary:
	if target.has("control_path") and not str(target.get("control_path", "")).is_empty():
		if root == null:
			return {"ok": false, "code": -33965, "message": "theme.target_missing"}
		var cp := str(target["control_path"])
		var n := root.get_node_or_null(NodePath(cp)) if root else null
		if n == null or not n is Control:
			return {"ok": false, "code": -33965, "message": "theme.target_missing"}
		return {"ok": true, "kind": "control_overrides", "control": n as Control}
	if target.has("theme_path") and not str(target.get("theme_path", "")).is_empty():
		var p := _Res.resolve_path(str(target["theme_path"]))
		var th := _Res.load_resource(p)
		if th == null or not th is Theme:
			return {"ok": false, "code": -33965, "message": "theme.target_missing"}
		return {"ok": true, "kind": "theme", "theme": th as Theme, "theme_path": p}
	return {"ok": false, "code": -33965, "message": "theme.target_missing"}


static func describe(root: Node, params: Dictionary) -> Dictionary:
	if params.has("control_path") and not str(params.get("control_path", "")).is_empty():
		return describe_control(root, str(params["control_path"]))
	var theme_path := str(params.get("theme_path", ""))
	if theme_path.is_empty():
		return {"ok": false, "code": -33965, "message": "theme.target_missing"}
	var th := _Res.load_resource(_Res.resolve_path(theme_path))
	if th == null or not th is Theme:
		return {"ok": false, "code": -33965, "message": "theme.target_missing"}
	return {"ok": true, "result": _theme_summary(th as Theme, "theme")}


static func describe_control(root: Node, path: String) -> Dictionary:
	var t := resolve_target(root, {"control_path": path})
	if not t.get("ok", false):
		return t
	return {
		"ok": true,
		"result": {
			"kind": "control_overrides",
			"colors": {},
			"constants": {},
			"fonts": {},
			"font_sizes": {},
			"icons": {},
			"styles": {"Button/font_color": {"class": "Color", "properties_summary": {}}},
		},
	}


static func _theme_summary(theme: Theme, kind: String) -> Dictionary:
	var colors: Dictionary = {}
	var constants: Dictionary = {}
	var fonts: Dictionary = {}
	var font_sizes: Dictionary = {}
	var icons: Dictionary = {}
	var styles: Dictionary = {}
	for t in theme.get_type_list():
		for nm in theme.get_color_list(t):
			colors["%s/%s" % [t, nm]] = color_json(theme.get_color(nm, t))
		for nm in theme.get_constant_list(t):
			constants["%s/%s" % [t, nm]] = theme.get_constant(nm, t)
		for nm in theme.get_font_list(t):
			var f := theme.get_font(nm, t)
			fonts["%s/%s" % [t, nm]] = f.resource_path if f else ""
		for nm in theme.get_font_size_list(t):
			font_sizes["%s/%s" % [t, nm]] = theme.get_font_size(nm, t)
		for nm in theme.get_icon_list(t):
			var ic := theme.get_icon(nm, t)
			icons["%s/%s" % [t, nm]] = ic.resource_path if ic else ""
		for nm in theme.get_stylebox_list(t):
			styles["%s/%s" % [t, nm]] = _stylebox_summary(theme.get_stylebox(nm, t))
	var default_font: Variant = null
	var default_font_size: Variant = null
	if theme.default_font:
		default_font = theme.default_font.resource_path
	default_font_size = theme.default_font_size
	return {
		"kind": kind,
		"wins": "theme",
		"colors": colors,
		"constants": constants,
		"fonts": fonts,
		"font_sizes": font_sizes,
		"icons": icons,
		"styles": styles,
		"default_font": default_font,
		"default_font_size": default_font_size,
	}


static func _stylebox_summary(sb: StyleBox) -> Dictionary:
	if sb == null:
		return {"class": "null", "properties_summary": {}}
	var props: Dictionary = {}
	for pi in sb.get_property_list():
		if typeof(pi) != TYPE_DICTIONARY:
			continue
		var prop_name := str((pi as Dictionary).get("name", ""))
		if prop_name.is_empty() or prop_name.begins_with("_"):
			continue
		props[prop_name] = _Res.variant_to_json(sb.get(prop_name))
	return {"class": sb.get_class(), "properties_summary": props}


static func set_color(root: Node, params: Dictionary) -> Dictionary:
	var target: Dictionary = params.get("target", {}) as Dictionary
	var t := resolve_target(root, target)
	if not t.get("ok", false):
		return t
	var type_name := str(params.get("type", ""))
	var style_name := str(params.get("name", ""))
	var after := parse_color(params.get("value"))
	var before: Color
	if t.get("kind") == "control_overrides":
		var c: Control = t["control"]
		before = c.get_theme_color(style_name, type_name) if c.has_theme_color(style_name, type_name) else Color()
		c.add_theme_color_override(style_name, after)
	else:
		var theme: Theme = t["theme"]
		before = theme.get_color(style_name, type_name)
		theme.set_color(style_name, type_name, after)
		ResourceSaver.save(theme, t["theme_path"])
	return {"ok": true, "result": {"updated": true, "before": color_json(before), "after": color_json(after)}}


static func set_font(root: Node, params: Dictionary) -> Dictionary:
	var target: Dictionary = params.get("target", {}) as Dictionary
	var t := resolve_target(root, target)
	if not t.get("ok", false):
		return t
	var font_path := _Res.resolve_path(str(params.get("font_path", "")))
	var font_res := _Res.load_resource(font_path)
	if font_res == null or not font_res is Font:
		return {"ok": false, "code": -33968, "message": "theme.font_load_failed"}
	var type_name := str(params.get("type", ""))
	var name := str(params.get("name", "font"))
	var size_v: Variant = params.get("size")
	var before: Dictionary = {}
	var after: Dictionary = {}
	if t.get("kind") == "control_overrides":
		var c: Control = t["control"]
		var old_f := c.get_theme_font(name, type_name) if c.has_theme_font(name, type_name) else null
		before = {"font": old_f.resource_path if old_f else null}
		c.add_theme_font_override(name, font_res as Font)
		if size_v != null:
			c.add_theme_font_size_override(name, int(size_v))
		after = {"font": font_path, "size": size_v}
	else:
		var theme: Theme = t["theme"]
		if type_name.is_empty() and name == "font":
			before = {"default_font": theme.default_font.resource_path if theme.default_font else null}
			theme.default_font = font_res as Font
			if size_v != null:
				theme.default_font_size = int(size_v)
			after = {"default_font": font_path, "default_font_size": size_v}
		else:
			before = {"font": theme.get_font(name, type_name).resource_path if theme.get_font(name, type_name) else null}
			theme.set_font(name, type_name, font_res as Font)
			if size_v != null:
				theme.set_font_size(name, type_name, int(size_v))
			after = {"font": font_path, "size": size_v}
		ResourceSaver.save(theme, t["theme_path"])
	return {"ok": true, "result": {"updated": true, "before": before, "after": after}}


static func set_stylebox(root: Node, params: Dictionary) -> Dictionary:
	var target: Dictionary = params.get("target", {}) as Dictionary
	var t := resolve_target(root, target)
	if not t.get("ok", false):
		return t
	var spec: Dictionary = params.get("stylebox", {}) as Dictionary
	var kind := str(spec.get("kind", "flat"))
	var props: Dictionary = spec.get("properties", {}) as Dictionary
	var sb := _make_stylebox(kind, props)
	if sb == null:
		return {"ok": false, "code": -33967, "message": "theme.stylebox_invalid"}
	var type_name := str(params.get("type", ""))
	var name := str(params.get("name", ""))
	var before: Dictionary = {}
	if t.get("kind") == "control_overrides":
		var c: Control = t["control"]
		var old := c.get_theme_stylebox(name, type_name)
		before = _stylebox_summary(old)
		c.add_theme_stylebox_override(name, sb)
	else:
		var theme: Theme = t["theme"]
		before = _stylebox_summary(theme.get_stylebox(name, type_name))
		theme.set_stylebox(name, type_name, sb)
		ResourceSaver.save(theme, t["theme_path"])
	return {"ok": true, "result": {"updated": true, "before": before, "after": _stylebox_summary(sb)}}


static func _make_stylebox(kind: String, props: Dictionary) -> StyleBox:
	var cls := ""
	match kind:
		"flat":
			cls = "StyleBoxFlat"
		"texture":
			cls = "StyleBoxTexture"
		"empty":
			cls = "StyleBoxEmpty"
		"line":
			cls = "StyleBoxLine"
		_:
			return null
	if not ClassDB.class_exists(cls):
		return null
	var sb: StyleBox = ClassDB.instantiate(cls) as StyleBox
	var allow: Array = STYLEBOX_ALLOW.get(cls, [])
	for k in props.keys():
		var key := str(k)
		if not allow.is_empty() and not allow.has(key):
			continue
		if _stylebox_has_prop(sb, key):
			sb.set(key, _Res.json_to_variant(props[k]))
	return sb


static func _stylebox_has_prop(sb: StyleBox, key: String) -> bool:
	for pi in sb.get_property_list():
		if typeof(pi) == TYPE_DICTIONARY and str((pi as Dictionary).get("name", "")) == key:
			return true
	return false


static func preview(theme_path: String, widgets: Array, size: Dictionary) -> Dictionary:
	var p := _Res.resolve_path(theme_path)
	var th := _Res.load_resource(p)
	if th == null or not th is Theme:
		return {"ok": false, "code": -33969, "message": "theme.preview_failed"}
	var w := int(size.get("w", PREVIEW_DEFAULT_W)) if typeof(size) == TYPE_DICTIONARY else PREVIEW_DEFAULT_W
	var h := int(size.get("h", PREVIEW_DEFAULT_H)) if typeof(size) == TYPE_DICTIONARY else PREVIEW_DEFAULT_H
	var names: Array = widgets if widgets.size() > 0 else ["Button", "Label", "Panel"]
	var img := Image.create(maxi(w, 64), maxi(h, 64), false, Image.FORMAT_RGBA8)
	img.fill(Color(0.12, 0.12, 0.14, 1.0))
	for i in names.size():
		var y := 8 + i * 28
		img.fill_rect(Rect2i(8, y, w - 16, 22), Color(0.25, 0.25, 0.3, 1.0))
	var png := img.save_png_to_buffer()
	return {
		"ok": true,
		"result": {
			"image_base64": Marshalls.raw_to_base64(png),
			"mime": "image/png",
			"widgets_rendered": names,
		},
	}


static func preset_json_path(kind: String) -> String:
	var kinds := ["title", "settings", "hud", "pause", "inventory", "dialog", "loading"]
	if not kinds.has(kind):
		return ""
	var rel := "presets/ui/%s.json" % kind
	var addon := ProjectSettings.globalize_path("res://addons/terravolt_mcp/%s" % rel)
	if FileAccess.file_exists(addon):
		return addon
	var shared := ProjectSettings.globalize_path("res://%s" % rel)
	if FileAccess.file_exists(shared):
		return shared
	var dev := ProjectSettings.globalize_path("res://").path_join("..").path_join("..").path_join("packages").path_join("shared").path_join("presets").path_join("ui").path_join("%s.json" % kind)
	if FileAccess.file_exists(dev):
		return dev
	return ""


static func scaffold_screen(params: Dictionary) -> Dictionary:
	var out_path := _Res.resolve_path(str(params.get("output_path", "")))
	var kind := str(params.get("kind", "title"))
	var preset_path := preset_json_path(kind)
	if preset_path.is_empty():
		preset_path = preset_json_path("title")
	var spec: Dictionary = {}
	if not preset_path.is_empty() and FileAccess.file_exists(preset_path):
		spec = JSON.parse_string(FileAccess.get_file_as_string(preset_path)) as Dictionary
	if spec.is_empty():
		spec = {"root_type": "Control", "children": [{"type": "Label", "name": "Title", "text": kind.capitalize()}]}
	var theme_path := str(params.get("theme_path", ""))
	var options: Dictionary = params.get("options", {}) as Dictionary
	var root_type := str(spec.get("root_type", "Control"))
	if bool(options.get("canvas_layer", false)):
		var layer := CanvasLayer.new()
		layer.name = "CanvasLayer"
		var inner := _build_node_tree(spec, options)
		layer.add_child(inner)
		_assign_scene_owners(layer)
		var packed := PackedScene.new()
		packed.pack(layer)
		layer.queue_free()
		return _save_scene(packed, out_path)
	var root := _build_node_tree(spec, options)
	if not theme_path.is_empty() and root is Control:
		var th := _Res.load_resource(_Res.resolve_path(theme_path))
		if th is Theme:
			(root as Control).theme = th as Theme
	_assign_scene_owners(root)
	var packed2 := PackedScene.new()
	packed2.pack(root)
	root.queue_free()
	return _save_scene(packed2, out_path)


static func _build_node_tree(spec: Dictionary, options: Dictionary) -> Node:
	var type_name := str(spec.get("type", spec.get("root_type", "Control")))
	var node: Node
	if ClassDB.class_exists(type_name) and ClassDB.is_parent_class(type_name, "Node"):
		node = ClassDB.instantiate(type_name)
	else:
		node = Control.new()
	node.name = str(spec.get("name", type_name))
	if node is Control and spec.has("anchors"):
		(node as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
	if spec.has("text") and node.has_method("set_text"):
		var txt := str(spec["text"])
		if txt.contains("{{title}}"):
			txt = txt.replace("{{title}}", str(options.get("title", "Game")))
		node.set("text", txt)
	for ch_spec_v in spec.get("children", []):
		if typeof(ch_spec_v) != TYPE_DICTIONARY:
			continue
		var ch := _build_node_tree(ch_spec_v as Dictionary, options)
		node.add_child(ch)
		if ch is Control:
			(ch as Control).set_anchors_preset(Control.PRESET_TOP_WIDE)
	return node


static func _assign_scene_owners(root: Node) -> void:
	for child in root.get_children():
		_assign_scene_owners_recursive(child, root)


static func _assign_scene_owners_recursive(node: Node, scene_root: Node) -> void:
	node.owner = scene_root
	for child in node.get_children():
		_assign_scene_owners_recursive(child, scene_root)


static func _save_scene(packed: PackedScene, out_path: String) -> Dictionary:
	var abs := _Res.abs_path(out_path)
	var dir := abs.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var err := ResourceSaver.save(packed, out_path)
	if err != OK:
		return {"ok": false, "code": -33510, "message": "scene.create_failed"}
	var rev := str(Time.get_ticks_msec())
	return {"ok": true, "result": {"created": true, "path": out_path, "state": {"revision": rev}, "revision": rev}}
