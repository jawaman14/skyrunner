class_name RoadSurface
extends RefCounted
## One road ribbon supplies rendering, collision and ground-vehicle queries.
## Cached triangle bins make wheel queries independent of the total road count.
const HALF_WIDTH := 4.5
const BIN := 128.0
const APPROACH_GRADE := 0.10
var vertices := PackedVector3Array()
var _bins := {}

func _init(world: World) -> void:
	for road in world.map.roads:
		var cross := samples(world, road)
		for i in range(1, cross.size()):
			var a := edge(cross[i - 1], HALF_WIDTH)
			var b := edge(cross[i], HALF_WIDTH)
			var c := edge(cross[i], -HALF_WIDTH)
			var d := edge(cross[i - 1], -HALF_WIDTH)
			_triangle(a, b, c)
			_triangle(a, c, d)

static func samples(world: World, road: Array) -> Array:
	if road.size() < 2:
		return []
	var points := PackedVector2Array()
	for i in road.size() - 1:
		var a := Vector2(road[i][0], road[i][1])
		var b := Vector2(road[i + 1][0], road[i + 1][1])
		var count := int(a.distance_to(b) / 12.0) + 1
		for j in count:
			points.append(a.lerp(b, float(j) / count))
	points.append(Vector2(road[-1][0], road[-1][1]))
	var out := []
	for i in points.size():
		var direction := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		out.append([points[i], direction, deck_height(world, points[i], Vector2(-direction.y, direction.x) * HALF_WIDTH)])
	# Only bridge clearance propagates onto land: do not reshape hill roads.
	var clearance := PackedFloat64Array()
	for p in points:
		clearance.append(2.65 if world.is_water(p.x, p.y) else 0.0)
	for i in range(1, points.size()):
		clearance[i] = maxf(clearance[i], clearance[i - 1] - points[i].distance_to(points[i - 1]) * APPROACH_GRADE)
	for i in range(points.size() - 2, -1, -1):
		clearance[i] = maxf(clearance[i], clearance[i + 1] - points[i].distance_to(points[i + 1]) * APPROACH_GRADE)
	for i in out.size():
		out[i][2] = maxf(float(out[i][2]), clearance[i])
	return out

static func deck_height(world: World, p: Vector2, side: Vector2) -> float:
	var ground_height := maxf(maxf(world.ground(p.x + side.x, p.y + side.y), world.ground(p.x - side.x, p.y - side.y)), world.ground(p.x, p.y))
	return maxf(ground_height + 0.45, 2.65 if world.is_water(p.x, p.y) else 0.0)

static func edge(sample: Array, lateral: float) -> Vector3:
	var p: Vector2 = sample[0]
	var direction: Vector2 = sample[1]
	var side := Vector2(-direction.y, direction.x) * lateral
	return Vector3(p.x + side.x, sample[2], -(p.y + side.y))

func _triangle(a: Vector3, b: Vector3, c: Vector3) -> void:
	var index := vertices.size()
	vertices.append_array(PackedVector3Array([a, b, c]))
	var x0 := int(floor(minf(a.x, minf(b.x, c.x)) / BIN))
	var x1 := int(floor(maxf(a.x, maxf(b.x, c.x)) / BIN))
	var y0 := int(floor(minf(-a.z, minf(-b.z, -c.z)) / BIN))
	var y1 := int(floor(maxf(-a.z, maxf(-b.z, -c.z)) / BIN))
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var key := Vector2i(x, y)
			if not _bins.has(key):
				_bins[key] = []
			_bins[key].append(index)

func sample(p: Vector2) -> Dictionary:
	var result := {"on_surface": false, "height": 0.0}
	for index in _bins.get(Vector2i(int(floor(p.x / BIN)), int(floor(p.y / BIN))), []):
		var a := Vector2(vertices[index].x, -vertices[index].z)
		var b := Vector2(vertices[index + 1].x, -vertices[index + 1].z)
		var c := Vector2(vertices[index + 2].x, -vertices[index + 2].z)
		var denominator := (b - a).cross(c - a)
		if absf(denominator) < 0.00001:
			continue
		var u := (p - a).cross(c - a) / denominator
		var v := (b - a).cross(p - a) / denominator
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
			var height: float = vertices[index].y * (1.0 - u - v) + vertices[index + 1].y * u + vertices[index + 2].y * v
			result.on_surface = true
			result.height = maxf(float(result.height), height)
	return result
