class_name StreetLights
extends Node3D
## Real light from the town's street lamps. The lamp heads are only glowing meshes (thousands of them: far too many
## to be lights), so a small pool of OmniLights follows the lamps nearest the camera and the ground under them
## actually lights up: warm sodium pools along the road, fading with the night. Medium keeps 5 lights, high 10.

const RANGE_M := 90.0  ## only lamps this near the camera get a light
const REFRESH_S := 0.25
const COLOUR := Color(1.0, 0.72, 0.4)

var heads := PackedVector3Array()
var pool: Array = []
var night := 0.0
var _t := 0.0


func setup(lamps: Node, n: int) -> StreetLights:
	name = "street_lights"
	if lamps != null and lamps.has_meta("heads"):
		heads = lamps.get_meta("heads")
	for i in n:
		var l := OmniLight3D.new()
		l.name = "lamp-%d" % i
		l.light_color = COLOUR
		l.omni_range = 34.0
		l.omni_attenuation = 1.2
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		pool.append(l)
	return self


## The `k` lamp heads nearest `at` within RANGE_M, nearest first.
static func nearest(all: PackedVector3Array, at: Vector3, k: int) -> Array:
	var best: Array = []  # [distance, index]
	for i in all.size():
		var d := all[i].distance_to(at)
		if d > RANGE_M:
			continue
		best.append([d, i])
	best.sort_custom(func(a, b): return a[0] < b[0])
	return best.slice(0, k).map(func(b): return all[b[1]])


## Put the pool on the nearest lamps (or switch it off by day).
func place(at: Vector3) -> void:
	var on := night > 0.3 and not heads.is_empty()
	var spots: Array = nearest(heads, at, pool.size()) if on else []
	for i in pool.size():
		var l: OmniLight3D = pool[i]
		if i < spots.size():
			l.global_position = spots[i] + Vector3(0, -0.4, 0)
			l.light_energy = 5.5 * clampf((night - 0.3) / 0.4, 0.0, 1.0)
			l.visible = true
		else:
			l.visible = false


func _process(dt: float) -> void:
	_t += dt
	if _t < REFRESH_S:
		return
	_t = 0.0
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		place(cam.global_position)
