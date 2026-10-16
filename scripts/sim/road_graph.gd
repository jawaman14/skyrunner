class_name RoadGraph
extends RefCounted
## The map's roads as a graph for ground units: nodes at the polyline
## vertices (shared vertices and ends within MERGE_M are one junction; a road's
## loose end within TEE_M of another road joins it as a T), edges along the
## polylines. Places off the network (stash houses, HQs, strips) get a stub to
## the nearest node. `path` is A* over the nodes and returns the points to
## drive; `route` adds the off-road legs at each end.
##
## Maps with no roads (the classic island, the generated islands) get a sparse
## graph of straight tracks between the strips and HQ sites instead, so squads
## still have somewhere to go; GroundWar only runs there when asked to.

const MERGE_M := 60.0
const TEE_M := 450.0

var nodes: Array = []  ## Vector2
var adj: Array = []  ## node -> [[other, length], ...]
var road_nodes := 0  ## nodes before the stubs
var _authored_roads: Array = []
var _checked_graph: RoadGraph
var _merge_m := MERGE_M
var _exact_bins := {}
var _network_edges := {}  ## authored road/track edges, excluding speculative T links/stubs


func _init(roads: Array, places: Array = []) -> void:
	_authored_roads = roads.duplicate(true)
	for r in roads:
		var prev := -1
		for p in r:
			var i := _node(Vector2(p[0], p[1]))
			if prev >= 0 and prev != i:
				_link(prev, i, true)
			prev = i
	# a loose end near another road: a T junction
	for i in nodes.size():
		if adj[i].size() == 1:
			var best := -1
			var bd := TEE_M
			for j in nodes.size():
				if j != i and adj[i][0][0] != j:
					var d: float = nodes[i].distance_to(nodes[j])
					if d < bd and not _linked(i, j):
						bd = d
						best = j
			if best >= 0:
				_link(i, best)
	road_nodes = nodes.size()
	for p in places:
		stub(Vector2(p[0], p[1]))


## A graph of straight tracks between `points` (maps without roads): each
## point to its three nearest neighbours.
static func tracks(points: Array) -> RoadGraph:
	var g := RoadGraph.new([])
	for p in points:
		g._node(Vector2(p[0], p[1]))
	for i in g.nodes.size():
		var d := []
		for j in g.nodes.size():
			if j != i:
				d.append([g.nodes[i].distance_to(g.nodes[j]), j])
		d.sort_custom(func(a, b): return a[0] < b[0])
		for k in mini(3, d.size()):
			if not g._linked(i, d[k][1]):
				g._link(i, d[k][1], true)
	g.road_nodes = g.nodes.size()
	return g


func _node(p: Vector2) -> int:
	if _merge_m <= 0.05:
		var cell := Vector2i(floori(p.x / 0.05), floori(p.y / 0.05))
		for x in range(cell.x - 1, cell.x + 2):
			for y in range(cell.y - 1, cell.y + 2):
				for i in _exact_bins.get(Vector2i(x, y), []):
					if nodes[i].distance_to(p) < _merge_m: return i
		var index := nodes.size()
		nodes.append(p)
		adj.append([])
		if not _exact_bins.has(cell): _exact_bins[cell] = []
		_exact_bins[cell].append(index)
		return index
	for i in nodes.size():
		if nodes[i].distance_to(p) < _merge_m: return i
	nodes.append(p)
	adj.append([])
	return nodes.size() - 1


func _linked(a: int, b: int) -> bool:
	for e in adj[a]:
		if e[0] == b:
			return true
	return false


func _link(a: int, b: int, authored := false) -> void:
	var d: float = nodes[a].distance_to(nodes[b])
	adj[a].append([b, d])
	adj[b].append([a, d])
	if authored:
		_network_edges[Vector2i(a, b)] = true
		_network_edges[Vector2i(b, a)] = true


## Tie a place to the nearest road node; returns the new node.
func stub(p: Vector2) -> int:
	var n := nearest(p)
	var i := nodes.size()
	nodes.append(p)
	adj.append([])
	if n >= 0:
		_link(i, n)
	return i


func nearest(p: Vector2, roads_only := true) -> int:
	var best := -1
	var bd := INF
	for i in (road_nodes if roads_only and road_nodes > 0 else nodes.size()):
		var d := p.distance_squared_to(nodes[i])
		if d < bd:
			bd = d
			best = i
	return best


## A* from node a to node b: the node indices, or [] if unreachable. `penalty`, if given, is
## called as penalty(from: Vector2, to: Vector2, length: float) -> float for every edge the search
## considers and returns extra metres of cost for it (never negative, so the straight-line
## heuristic stays admissible): a hill, a checkpoint, a place that is hot.
func path(a: int, b: int, penalty := Callable(), clear := Callable()) -> Array:
	if a < 0 or b < 0 or a >= nodes.size() or b >= nodes.size():
		return []
	if a == b:
		return [a]
	var g := {a: 0.0}
	var came := {}
	var open := {a: 0}
	var serial := 1
	var heap := []
	_heap_push(heap, [nodes[a].distance_to(nodes[b]), 0, a, 0.0])
	while not open.is_empty():
		var item: Array = _heap_pop(heap)
		var cur: int = item[2]
		if not open.has(cur) or open[cur] != item[1] or g[cur] != item[3]:
			continue
		if cur == b:
			var out := [b]
			while came.has(out[0]):
				out.push_front(came[out[0]])
			return out
		open.erase(cur)
		for e in adj[cur]:
			if clear.is_valid() and not clear.call(nodes[cur], nodes[e[0]]):
				continue
			var ng: float = g[cur] + e[1]
			if penalty.is_valid():
				ng += maxf(0.0, float(penalty.call(nodes[cur], nodes[e[0]], e[1])))
			if not g.has(e[0]) or ng < g[e[0]]:
				g[e[0]] = ng
				came[e[0]] = cur
				if not open.has(e[0]):
					open[e[0]] = serial
					serial += 1
				_heap_push(heap, [ng + nodes[e[0]].distance_to(nodes[b]), open[e[0]], e[0], ng])
	return []


## Equal costs retain the original open-list insertion order, including decreases.
static func _heap_before(a: Array, b: Array) -> bool:
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])


static func _heap_push(heap: Array, item: Array) -> void:
	heap.append(item)
	var index := heap.size() - 1
	while index > 0:
		var parent := (index - 1) >> 1
		if not _heap_before(item, heap[parent]):
			break
		heap[index] = heap[parent]
		index = parent
	heap[index] = item


static func _heap_pop(heap: Array) -> Array:
	var first: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return first
	var index := 0
	while index * 2 + 1 < heap.size():
		var child := index * 2 + 1
		if child + 1 < heap.size() and _heap_before(heap[child + 1], heap[child]):
			child += 1
		if not _heap_before(heap[child], last):
			break
		heap[index] = heap[child]
		index = child
	heap[index] = last
	return first


## The points to drive from `from` to `to`: off-road to the nearest node, the
## roads, off-road to the target. Straight line if the network can't connect them.
func route(from: Vector2, to: Vector2, penalty := Callable()) -> PackedVector2Array:
	var out := PackedVector2Array([from])
	var a := nearest(from, false)
	var b := nearest(to, false)
	var p := path(a, b, penalty)
	if p.is_empty() or from.distance_to(to) < 400.0:
		out.append(to)
		return out
	for i in p:
		if out[out.size() - 1].distance_to(nodes[i]) > 1.0:
			out.append(nodes[i])
	if out[out.size() - 1].distance_to(to) > 1.0:
		out.append(to)
	return out


## Checked callers receive explicit failure, never an implicit straight line.
## `clear(a,b)` validates access and graph edges against their own world data.
## Legacy route() remains unchanged until each simulation consumer is measured.
func checked_route(from: Vector2, to: Vector2, penalty := Callable(), clear := Callable()) -> Dictionary:
	if not _authored_roads.is_empty():
		return checked_network().checked_route(from, to, penalty, clear)
	var failure := {"reachable": false, "points": PackedVector2Array(), "reason": "No connected travel network."}
	if not from.is_finite() or not to.is_finite():
		failure.reason = "Invalid route endpoints."
		return failure
	var a := nearest(from)
	var b := nearest(to)
	if a < 0 or b < 0:
		return failure
	if clear.is_valid() and (not clear.call(from, nodes[a]) or not clear.call(nodes[b], to)):
		failure.reason = "An access leg is obstructed."
		return failure
	var indices := {}
	for i in nodes.size(): indices[nodes[i]] = i
	var allowed := func(start: Vector2, end: Vector2) -> bool:
		return _network_edges.has(Vector2i(indices[start], indices[end])) and (not clear.is_valid() or clear.call(start, end))
	var route_nodes := path(a, b, penalty, allowed)
	if route_nodes.is_empty():
		return failure
	var points := PackedVector2Array([from])
	for index in route_nodes:
		if points[-1].distance_to(nodes[index]) > 0.01:
			points.append(nodes[index])
	if points[-1].distance_to(to) > 0.01:
		points.append(to)
	return {"reachable": true, "points": points, "reason": ""}


## How close the segment a-b comes to p.
static func seg_distance(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var t := 0.0 if l2 < 1e-9 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func length(pts: PackedVector2Array) -> float:
	var s := 0.0
	for i in pts.size() - 1:
		s += pts[i].distance_to(pts[i + 1])
	return s


## The point `dist` metres along `pts`.
static func along(pts: PackedVector2Array, dist: float) -> Vector2:
	if pts.is_empty():
		return Vector2.ZERO
	var left := dist
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if left <= seg:
			return pts[i].lerp(pts[i + 1], left / maxf(seg, 1e-6))
		left -= seg
	return pts[pts.size() - 1]


## A chokepoint on `pts`: a road node at least `min_d` along (where an ambush
## waits), or the midpoint.
func chokepoint(pts: PackedVector2Array, min_d := 800.0) -> Vector2:
	var run := 0.0
	for i in range(1, pts.size()):
		run += pts[i - 1].distance_to(pts[i])
		if run >= min_d and i < pts.size() - 1:
			for k in road_nodes:
				if nodes[k].distance_to(pts[i]) < 1.0 and adj[k].size() >= 2:
					return pts[i]
	return along(pts, length(pts) * 0.5)


func connected(a: Vector2, b: Vector2) -> bool:
	return not path(nearest(a, false), nearest(b, false)).is_empty()

## Geometry-preserving checked topology, reusing the same A* and penalty hook.
## Legacy nodes/routes remain untouched; only actual crossings become junctions.
func checked_network() -> RoadGraph:
	if _authored_roads.is_empty(): return self
	if _checked_graph != null: return _checked_graph
	var segments := []
	for road in _authored_roads:
		for i in road.size() - 1:
			var a := Vector2(road[i][0], road[i][1])
			var b := Vector2(road[i + 1][0], road[i + 1][1])
			if a.distance_to(b) > 0.01:
				segments.append({"a": a, "b": b, "points": [a, b], "bounds": Rect2(a.min(b), (b - a).abs()).grow(0.05)})
	var bins := {}
	var pairs := {}
	for i in segments.size():
		var bounds: Rect2 = segments[i].bounds
		for x in range(floori(bounds.position.x / 256.0), floori(bounds.end.x / 256.0) + 1):
			for y in range(floori(bounds.position.y / 256.0), floori(bounds.end.y / 256.0) + 1):
				var cell := Vector2i(x, y)
				for j in bins.get(cell, []): pairs[Vector2i(j, i)] = true
				if not bins.has(cell): bins[cell] = []
				bins[cell].append(i)
	var ordered: Array = pairs.keys()
	ordered.sort_custom(func(a, b): return a.x < b.x if a.x != b.x else a.y < b.y)
	for pair in ordered:
		var first: Dictionary = segments[pair.x]
		var second: Dictionary = segments[pair.y]
		if not first.bounds.intersects(second.bounds): continue
		var crossing = Geometry2D.segment_intersects_segment(first.a, first.b, second.a, second.b)
		if crossing != null:
			first.points.append(crossing)
			second.points.append(crossing)
		else:
			# Collinear overlap still splits at real endpoints, never a nearby T.
			for point in [first.a, first.b]:
				if seg_distance(second.a, second.b, point) < 0.05: second.points.append(point)
			for point in [second.a, second.b]:
				if seg_distance(first.a, first.b, point) < 0.05: first.points.append(point)
	var graph := RoadGraph.new([])
	graph._merge_m = 0.05
	for segment in segments:
		var start: Vector2 = segment.a
		var points: Array = segment.points
		points.sort_custom(func(a, b): return start.distance_squared_to(a) < start.distance_squared_to(b))
		var previous := -1
		for point in points:
			var index := graph._node(point)
			if previous >= 0 and previous != index and not graph._linked(previous, index): graph._link(previous, index, true)
			previous = index
	graph.road_nodes = graph.nodes.size()
	_checked_graph = graph
	return graph
