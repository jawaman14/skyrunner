class_name SaveVars
extends RefCounted
## Saving a system's plain data by name. A save is JSON, which has no ints (every number comes back a
## float), no Vector2 and only string keys, so this does the three things a hand-written to/from pair
## would each have to repeat:
##   capture(obj, keys)  a deep copy of those properties, Vectors tagged so JSON can hold them;
##   restore(obj, d, keys, ints)  put them back, each property coerced to the type it has now (an int
##     stays an int, a bool a bool), Vectors rebuilt, and any dictionary entry whose key is in `ints`
##     (wherever it is nested) turned back into an int;
##   through_json(d)  the round trip a save file does, for the tests.
## Properties missing from the saved data are left as they are, so a save from before a property
## existed still loads.

const V2 := "__v2"
const V3 := "__v3"


static func capture(obj: Object, keys: Array) -> Dictionary:
	var out := {}
	for k in keys:
		out[k] = encode(obj.get(k))
	return out


static func restore(obj: Object, d: Dictionary, keys: Array, ints: Array = []) -> void:
	for k in keys:
		if not d.has(k):
			continue
		var cur: Variant = obj.get(k)
		var v: Variant = decode(d[k], ints)
		match typeof(cur):
			TYPE_INT:
				v = int(v)
			TYPE_FLOAT:
				v = float(v)
			TYPE_BOOL:
				v = bool(v)
			TYPE_STRING:
				v = str(v)
		obj.set(k, v)


static func encode(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR2:
			return {V2: [v.x, v.y]}
		TYPE_VECTOR3:
			return {V3: [v.x, v.y, v.z]}
		TYPE_ARRAY:
			var a := []
			for x in v:
				a.append(encode(x))
			return a
		TYPE_DICTIONARY:
			var o := {}
			for k in v:
				o[k] = encode(v[k])
			return o
	return v


static func decode(v: Variant, ints: Array = []) -> Variant:
	match typeof(v):
		TYPE_ARRAY:
			var a := []
			for x in v:
				a.append(decode(x, ints))
			return a
		TYPE_DICTIONARY:
			if v.size() == 1 and v.has(V2):
				return Vector2(float(v[V2][0]), float(v[V2][1]))
			if v.size() == 1 and v.has(V3):
				return Vector3(float(v[V3][0]), float(v[V3][1]), float(v[V3][2]))
			var o := {}
			for k in v:
				var x: Variant = decode(v[k], ints)
				if ints.has(k) and (x is float):
					x = int(x)
				o[k] = x
			return o
	return v


## What a save file does to data: out as JSON text and back in.
static func through_json(d: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(d))
