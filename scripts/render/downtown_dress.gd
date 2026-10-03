class_name DowntownDress
extends RefCounted
## Landmark buildings for the heart of San Telmo, from Quaternius's Downtown City MegaKit (CC0,
## assets/models/quaternius/downtown_city): three finished, textured brick-and-glass buildings (large, medium, small),
## stood on the footprints of the tallest towers nearest the city centre in place of the Kenney lot models.
##
## The kit's buildings are real-scale and textured with their own materials (20 m wide, 28 m high, 9,000 to 21,000
## triangles), so they cannot ride CityDress's one-colour-map MultiMeshes: each landmark is its own node, drawn within
## CityDress's range (nothing on low), and beyond it the tower's shader box is drawn as before. The footprints and heights
## are untouched, so the sim's obstacles and the colliders are what they were. Picked from the map alone (the nearest
## towers to the centre, the model by the tower's number), so it is the same every time. Behind ENABLED; a missing kit
## draws nothing and the towers keep their Kenney models.

static var ENABLED := true

const DIR := "res://assets/models/quaternius/downtown_city/"
const MODELS := ["Building_Large_2", "Building_Medium_2_001", "Building_Small_1"]
const MAX_LANDMARKS := 12
const NEAR_M := 520.0  ## from the city's centre
const MIN_W := 14.0
const MIN_D := 12.0
const FILL := 0.94
const SINK := 0.4

static var marks := {}  ## building index -> model name (set by pick() when the city is built)
static var _scenes := {}


## Which of `boxes` become landmarks: {index: model}. Empty when off or the kit is not there.
static func pick(boxes: Array) -> Dictionary:
	marks = {}
	if not ENABLED or not available():
		return marks
	var cands := []
	for i in boxes.size():
		var b: Dictionary = boxes[i]
		if b.style != "tower" or float(b.w) < MIN_W or float(b.d) < MIN_D:
			continue
		var d := Vector2(b.x, b.y).distance_to(MapCity.CITY_C)
		if d <= NEAR_M:
			cands.append([d, i])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	for k in mini(MAX_LANDMARKS, cands.size()):
		var i: int = cands[k][1]
		marks[i] = MODELS[(i * 7 + k) % MODELS.size()]
	return marks


static func available() -> bool:
	return ResourceLoader.exists(DIR + MODELS[0] + ".gltf")


static func _scene(name: String) -> PackedScene:
	if not _scenes.has(name):
		_scenes[name] = load(DIR + name + ".gltf") if ResourceLoader.exists(DIR + name + ".gltf") else null
	return _scenes[name]


## The landmarks as a node (empty when none were picked, or on low quality).
static func build(boxes: Array, q: Quality) -> Node3D:
	var root := Node3D.new()
	root.name = "downtown"
	var reach := CityDress.draw_range(q)
	if marks.is_empty() or reach <= 0.0:
		return root
	var shadows := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if q.shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in marks:
		var ps := _scene(marks[i])
		if ps == null:
			continue
		var b: Dictionary = boxes[i]
		var m: Node3D = ps.instantiate()
		var bb := ModelLib.bounds(m)
		var s := clampf(minf(float(b.w) * FILL / maxf(0.01, bb.size.x), float(b.d) * FILL / maxf(0.01, bb.size.z)), 0.5, 1.5)
		var sy := clampf(float(b.h) / maxf(0.01, bb.size.y), 0.8 * s, 1.35 * s)
		var pivot := Node3D.new()
		pivot.name = "%s-%d" % [marks[i], i]
		var basis := Basis(Vector3.UP, CityDress.street_yaw(b.x, b.y)) * Basis.from_scale(Vector3(s, sy, s))
		var centre := Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
		pivot.transform = Transform3D(basis, Vector3(b.x, float(b.z) - SINK, -float(b.y)) - basis * centre)
		pivot.add_child(m)
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).visibility_range_end = reach + CityDress.FADE_M
			(mi as MeshInstance3D).visibility_range_end_margin = CityDress.FADE_M
			(mi as MeshInstance3D).visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			(mi as MeshInstance3D).cast_shadow = shadows
		root.add_child(pivot)
	return root
