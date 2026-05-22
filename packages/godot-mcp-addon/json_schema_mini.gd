@tool
extends RefCounted
class_name TerravoltJsonSchemaMini

## Minimal JSON Schema Draft subset (tasks 02–04). Dependency-free GDScript validator.

static func validate(value: Variant, schema: Variant) -> Dictionary:
	if typeof(schema) != TYPE_DICTIONARY:
		return _err("invalid_schema_root", [])
	return _validate_value(value, schema as Dictionary)


static func _err(code: String, path: PackedStringArray) -> Dictionary:
	return {"ok": false, "code": code, "path": "|".join(path)}


static func _ok() -> Dictionary:
	return {"ok": true}


static func _validate_value(value: Variant, schema: Dictionary, path: PackedStringArray = PackedStringArray()) -> Dictionary:
	if schema.has("type"):
		var t: String = str(schema["type"])
		var ok_types := false
		match t:
			"object":
				ok_types = typeof(value) == TYPE_DICTIONARY
			"array":
				ok_types = typeof(value) == TYPE_ARRAY
			"string":
				ok_types = typeof(value) == TYPE_STRING
			"number":
				ok_types = typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT
			"integer":
				ok_types = typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_equal_approx(round(value as float), value as float))
			"boolean":
				ok_types = typeof(value) == TYPE_BOOL
			_:
				return _err("unknown_type_keyword", path)
		if not ok_types:
			return _err("type_mismatch", path)

	if typeof(value) == TYPE_STRING and schema.has("minLength"):
		if len(value as String) < int(schema["minLength"]):
			return _err("minLength", path)
	if typeof(value) == TYPE_STRING and schema.has("maxLength"):
		if len(value as String) > int(schema["maxLength"]):
			return _err("maxLength", path)
	if typeof(value) == TYPE_STRING and schema.has("pattern"):
		var rx := RegEx.new()
		var pe := rx.compile(str(schema["pattern"]))
		if pe != OK:
			return _err("bad_pattern_schema", path)
		if rx.search(value as String) == null:
			return _err("pattern", path)

	if (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and schema.has("minimum"):
		var n := float(value)
		if n < float(schema["minimum"]):
			return _err("minimum", path)
	if (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and schema.has("maximum"):
		var n2 := float(value)
		if n2 > float(schema["maximum"]):
			return _err("maximum", path)

	if schema.has("enum"):
		var allowed: Array = schema["enum"] as Array
		var hits := false
		for a in allowed:
			if a == value:
				hits = true
				break
		if not hits:
			return _err("enum", path)

	if typeof(value) == TYPE_DICTIONARY and schema.has("properties"):
		var props: Dictionary = schema["properties"] as Dictionary
		var add_ok := bool(schema["additionalProperties"]) if schema.has("additionalProperties") else true
		if schema.has("required"):
			var req: Array = schema["required"] as Array
			for rk in req:
				var key := str(rk)
				if not (value as Dictionary).has(key):
					var p_req := path.duplicate()
					p_req.append(key)
					return _err("required_missing", p_req)

		var d := value as Dictionary
		for k in d.keys():
			if props.has(str(k)):
				var p_child := path.duplicate()
				p_child.append(str(k))
				var sub := validate(d[str(k)], props[str(k)])
				if not sub.get("ok", false):
					return sub
			elif not add_ok:
				var p_unknown := path.duplicate()
				p_unknown.append(str(k))
				return _err("additionalProperties", p_unknown)

	if typeof(value) == TYPE_ARRAY and schema.has("items"):
		var it: Variant = schema["items"]
		var arr := value as Array
		var i := 0
		for elt in arr:
			var pi := path.duplicate()
			pi.append("[%d]" % i)
			if typeof(it) != TYPE_DICTIONARY:
				return _err("invalid_items_schema", pi)
			var sub2 := _validate_value(elt, it as Dictionary, pi)
			if not sub2.get("ok", false):
				return sub2
			i += 1

	if schema.has("oneOf"):
		var opts: Array = schema["oneOf"] as Array
		var successes := 0
		var last_bad: Dictionary = _ok()
		for o in opts:
			var subo := validate(value, o)
			if subo.get("ok", false):
				successes += 1
			else:
				last_bad = subo
		if successes != 1:
			return last_bad if successes == 0 else _err("oneOf_not_exclusive", path)

	if schema.has("anyOf"):
		var anys: Array = schema["anyOf"] as Array
		var any_hit := false
		for ao in anys:
			var sa := validate(value, ao)
			if sa.get("ok", false):
				any_hit = true
				break
		if not any_hit:
			return _err("anyOf", path)

	return _ok()
