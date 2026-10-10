class_name SiteAccess
extends RefCounted
## Read-only access checks shared by diagnostics and checked travel callers.
## A clear candidate verifies access legs, not the entire public-road network.
const SAMPLE_M := 4.0
const MAX_CONNECTOR_M := 120.0
var world: World
var sites: Array
var _walking_footprints: Array = []
var _vehicle_footprints: Array = []
var _vehicle_edges := {}  ## immutable map geometry; checkpoint penalties are never cached

func _init(world_: World, sites_: Array) -> void:
	world = world_
	sites = sites_.duplicate(true)
	for site in sites:
		if site.kind == "dock": continue
		for mode in [false, true]:
			for polygon in Geometry2D.offset_polygon(site.footprint, 2.6 if mode else 0.8):
				var minimum: Vector2 = polygon[0]
				var maximum := minimum
				for point in polygon:
					minimum = minimum.min(point)
					maximum = maximum.max(point)
				var shape := {"id": str(site.id), "polygon": polygon, "bounds": Rect2(minimum, maximum - minimum).grow(0.001)}
				if mode: _vehicle_footprints.append(shape)
				else: _walking_footprints.append(shape)

static func _crosses(from: Vector2, to: Vector2, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(from, polygon) or Geometry2D.is_point_in_polygon(to, polygon): return true
	for i in polygon.size():
		if Geometry2D.segment_intersects_segment(from, to, polygon[i], polygon[(i + 1) % polygon.size()]) != null: return true
	return false

func segment_reason(from: Vector2, to: Vector2, vehicle := false, ignore_id := "") -> String:
	if not from.is_finite() or not to.is_finite(): return "Invalid access coordinates."
	var bounds := Rect2(from.min(to), (to - from).abs()).grow(0.001)
	var footprints: Array = _vehicle_footprints if vehicle else _walking_footprints
	for shape in footprints:
		if shape.id == ignore_id or not bounds.intersects(shape.bounds): continue
		if _crosses(from, to, shape.polygon): return "Access intersects " + str(shape.id) + "."
	for af in world.airfields:
		if _crosses(from, to, SiteLayout.runway_footprint(af, 8.0)): return "Access crosses runway clearance at " + af.code + "."
	var count := maxi(1, int(ceil(from.distance_to(to) / SAMPLE_M)))
	var previous := from
	var height := world.travel_surface(from.x, from.y)
	for i in count + 1:
		var point := from.lerp(to, float(i) / count)
		var surface := world.travel_surface(point.x, point.y)
		if world.is_water(point.x, point.y) and surface <= world.ground(point.x, point.y) + 0.05:
			return "Access crosses water without a road deck."
		var distance := previous.distance_to(point)
		if distance > 0.01 and absf(surface - height) / distance > (0.18 if vehicle else 1.0):
			return "Access grade is too steep for a vehicle." if vehicle else "Access grade is too steep to walk."
		previous = point
		height = surface
	return ""


## Deterministic visibility routing around nearby authoring footprints.
## Terrain/water failures stay explicit; this never invents a road or bridge.
func path(from: Vector2, to: Vector2, vehicle := false) -> Dictionary:
	var reason := segment_reason(from, to, vehicle)
	if reason == "": return {"reachable": true, "points": PackedVector2Array([from, to]), "reason": ""}
	var failure := {"reachable": false, "points": PackedVector2Array(), "reason": reason}
	if not from.is_finite() or not to.is_finite() or not "intersects" in reason: return failure
	var corridor := Rect2(from.min(to), (to - from).abs()).grow(50.0)
	var nodes: Array[Vector2] = [from, to]
	for site in sites:
		if site.kind == "dock": continue
		var expanded := Geometry2D.offset_polygon(site.footprint, 2.65 if vehicle else 0.85)
		for polygon in expanded:
			for corner in polygon:
				if corridor.has_point(corner): nodes.append(corner)
	var costs := {0: 0.0}
	var previous := {}
	var closed := {}
	while true:
		var current := -1
		var best := INF
		for i in nodes.size():
			if not closed.has(i) and float(costs.get(i, INF)) < best:
				current = i
				best = float(costs[i])
		if current < 0: return failure
		if current == 1:
			var route := PackedVector2Array([to])
			while current != 0:
				current = int(previous[current])
				route.insert(0, nodes[current])
			return {"reachable": true, "points": route, "reason": ""}
		closed[current] = true
		for next in nodes.size():
			if closed.has(next): continue
			var candidate := best + nodes[current].distance_to(nodes[next])
			if candidate >= float(costs.get(next, INF)): continue
			if segment_reason(nodes[current], nodes[next], vehicle) != "": continue
			costs[next] = candidate
			previous[next] = current
	return failure

func verify(site: Dictionary) -> Dictionary:
	var result := site.duplicate(true)
	result.connection_verified = false
	result.connection_reason = "No public-road connector; remote access requires a separate route."
	if not site.connector is Vector2: return result
	var connector: Vector2 = site.connector
	var approach: Vector3 = site.approach[0]
	var walking := Vector2(approach.x, -approach.z)
	var loading: Vector3 = site.loading
	var driving := Vector2(loading.x, -loading.z)
	if maxf(walking.distance_to(connector), driving.distance_to(connector)) > MAX_CONNECTOR_M:
		result.connection_reason = "Public road is too far away for a direct access leg."
		return result
	var walk := path(walking, connector)
	var drive := path(driving, connector, true)
	result.walking_connector = walk.points
	result.loading_connector = drive.points
	result.connection_reason = walk.reason if not walk.reachable else drive.reason
	result.connection_verified = walk.reachable and drive.reachable
	return result

func verified_records() -> Array:
	var out := []
	for site in sites: out.append(verify(site))
	return out

## Nearest usable authored node, with deterministic ties and bounded detours.
func _vehicle_connector(graph: RoadGraph, at: Vector2, arriving := false) -> Dictionary:
	var candidates := []
	for i in graph.nodes.size():
		var distance := at.distance_to(graph.nodes[i])
		if distance <= MAX_CONNECTOR_M: candidates.append({"index": i, "distance": distance})
	candidates.sort_custom(func(a, b): return a.index < b.index if a.distance == b.distance else a.distance < b.distance)
	var failure := {"reachable": false, "points": PackedVector2Array(), "reason": "No nearby checked vehicle access.", "index": -1}
	for candidate in candidates:
		var point: Vector2 = graph.nodes[candidate.index]
		var connector := path(point, at, true) if arriving else path(at, point, true)
		if not connector.reachable:
			failure.reason = connector.reason
			continue
		if RoadGraph.length(connector.points) > MAX_CONNECTOR_M:
			failure.reason = "Access detour exceeds the local connector limit."
			continue
		connector.index = candidate.index
		return connector
	return failure


func checked_vehicle_route(graph: RoadGraph, from: Vector2, to: Vector2, penalty := Callable()) -> Dictionary:
	if not from.is_finite() or not to.is_finite():
		return {"reachable": false, "points": PackedVector2Array(), "reason": "Invalid route endpoints."}
	graph = graph.checked_network()
	# Local loading legs use the same validated detours as site diagnostics.
	# Only graph edges carry public-road travel; an obstacle never becomes a
	# straight-line fallback merely because the endpoint is close to a node.
	var departure := _vehicle_connector(graph, from)
	var arrival := _vehicle_connector(graph, to, true)
	if not departure.reachable or not arrival.reachable:
		return {"reachable": false, "points": PackedVector2Array(), "reason": departure.reason if not departure.reachable else arrival.reason}
	var clear_edges: Dictionary = _vehicle_edges
	var clear := func(a: Vector2, b: Vector2) -> bool:
		var key := Vector4(a.x, a.y, b.x, b.y)
		if not clear_edges.has(key):
			var allowed := segment_reason(a, b, true) == ""
			clear_edges[key] = allowed
			clear_edges[Vector4(b.x, b.y, a.x, a.y)] = allowed
		return bool(clear_edges[key])
	var network := graph.checked_route(graph.nodes[departure.index], graph.nodes[arrival.index], penalty, clear)
	if not network.reachable: return network
	var points: PackedVector2Array = departure.points.duplicate()
	for leg in [network.points, arrival.points]:
		for point in leg:
			if points[-1].distance_to(point) > 0.01: points.append(point)
	return {"reachable": true, "points": points, "reason": ""}

## Rebuild after an explicit authoring/geometry change; simulation hazards use penalties.
func invalidate_geometry() -> void:
	_vehicle_edges.clear()
