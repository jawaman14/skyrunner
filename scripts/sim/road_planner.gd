class_name RoadPlanner
extends RefCounted
## Plans a road network over a height field, the way a surveyor would: connect the places that matter,
## one at a time, by the cheapest route to the roads already built, where cost climbs steeply with
## grade and reusing an existing road is cheap. That gives a trunk with branches and real junctions
## (routes join at shared grid cells), curves that follow the ground, and no road up a cliff.
##
## Pure geometry (no Terrain or World dependency): the caller supplies `height(x, y)` and
## `passable(x, y)` (0 = forbidden, 1 = open ground, >1 = a costlier crossing such as a bridge site),
## so it can be tested on a synthetic hill. The tool (tools/plan_roads.gd) runs it once and commits
## the result; nothing here runs at game start.
##
## plan() returns {"roads": [[[x, y], ...], ...], "bridges": [[[x, y], [x, y]], ...],
## "links": [[a, b], ...], "unreached": [place index, ...], "tracks": [place index, ...]} - the places that
## needed a steeper mountain track to be reached are in "tracks".

const CELL := 62.5  ## the terrain's own cell, so the grades the planner sees are the grades the player drives
const MAX_GRADE := 0.10  ## no step steeper than this on a road
const TRACK_GRADE := 0.18  ## ... or this on a mountain track, tried only when a place can't be reached otherwise
const GRADE_SCALE := 0.04  ## cost is run * (1 + (grade / this)^2)
const REUSE := 0.35  ## an existing road costs this fraction to ride again
const SMOOTH_PASSES := 3
const RESAMPLE_M := 40.0

var half := 16000.0
var n := 513
var max_grade := MAX_GRADE
var heights := PackedFloat32Array()
var pass_cost := PackedFloat32Array()  ## per cell: 0 forbidden, else the ground's cost multiplier
var net := PackedByteArray()  ## 1 where a road runs
var edges := {}  ## "a-b" (a < b) -> true
var _height: Callable
var _passable: Callable


func _init(height: Callable, passable: Callable, half_m := 16000.0) -> void:
	_height = height
	_passable = passable
	half = half_m
	n = int(round(2.0 * half / CELL)) + 1  # nodes on the terrain's own grid points
	heights.resize(n * n)
	pass_cost.resize(n * n)
	net.resize(n * n)
	for j in n:
		for i in n:
			var p := centre(i, j)
			heights[j * n + i] = _height.call(p.x, p.y)
			pass_cost[j * n + i] = _passable.call(p.x, p.y)


func centre(i: int, j: int) -> Vector2:
	return Vector2(-half + i * CELL, -half + j * CELL)


func cell_of(p: Vector2) -> int:
	var i := clampi(int(round((p.x + half) / CELL)), 0, n - 1)
	var j := clampi(int(round((p.y + half) / CELL)), 0, n - 1)
	return j * n + i


## The nearest passable cell to `p` (a place on the shore or a strip's apron may sit on a blocked cell).
func snap(p: Vector2) -> int:
	var c := cell_of(p)
	if pass_cost[c] > 0.0:
		return c
	var ci := c % n
	var cj := c / n
	for r in range(1, 12):
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				if maxi(absi(di), absi(dj)) != r:
					continue
				var i := ci + di
				var j := cj + dj
				if i >= 0 and i < n and j >= 0 and j < n and pass_cost[j * n + i] > 0.0:
					return j * n + i
	return -1


# ------------------------------------------------------------------ routing
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


func _step_cost(a: int, b: int, run: float) -> float:
	var m := pass_cost[b]
	if m <= 0.0:
		return -1.0
	var grade := absf(heights[b] - heights[a]) / run
	if grade > max_grade:
		return -1.0
	var g := grade / GRADE_SCALE
	var c := run * (1.0 + g * g) * maxf(m, pass_cost[a] if pass_cost[a] > 0.0 else 1.0)
	if net[b] == 1 and net[a] == 1:
		c *= REUSE
	return c


## Cheapest route from `start` to the network (or to `goal` when >= 0). Returns the cell path start..end,
## empty when there is none.
func route(start: int, goal := -1) -> PackedInt32Array:
	var dist := PackedFloat32Array()
	dist.resize(n * n)
	dist.fill(1e30)
	var parent := PackedInt32Array()
	parent.resize(n * n)
	parent.fill(-1)
	var heap_k := PackedFloat32Array()
	var heap_v := PackedInt32Array()
	dist[start] = 0.0
	_push(heap_k, heap_v, 0.0, start)
	var end := -1
	while heap_v.size() > 0:
		var top := _pop(heap_k, heap_v)
		var d: float = top[0]
		var c: int = top[1]
		if d > dist[c]:
			continue
		if (goal >= 0 and c == goal) or (goal < 0 and net[c] == 1 and c != start):
			end = c
			break
		var ci := c % n
		var cj := c / n
		for dir in DIRS:
			var i: int = ci + dir.x
			var j: int = cj + dir.y
			if i < 0 or i >= n or j < 0 or j >= n:
				continue
			var b := j * n + i
			var run := CELL * (1.4142 if dir.x != 0 and dir.y != 0 else 1.0)
			var sc := _step_cost(c, b, run)
			if sc < 0.0:
				continue
			var nd := d + sc
			if nd < dist[b]:
				dist[b] = nd
				parent[b] = c
				_push(heap_k, heap_v, nd, b)
	var out := PackedInt32Array()
	if end < 0:
		return out
	var c := end
	while c != -1:
		out.append(c)
		c = parent[c]
	out.reverse()
	return out


func _push(hk: PackedFloat32Array, hv: PackedInt32Array, k: float, v: int) -> void:
	hk.append(k)
	hv.append(v)
	var i := hk.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if hk[p] <= hk[i]:
			break
		var tk := hk[p]
		hk[p] = hk[i]
		hk[i] = tk
		var tv := hv[p]
		hv[p] = hv[i]
		hv[i] = tv
		i = p


func _pop(hk: PackedFloat32Array, hv: PackedInt32Array) -> Array:
	var top := [hk[0], hv[0]]
	var last := hk.size() - 1
	hk[0] = hk[last]
	hv[0] = hv[last]
	hk.resize(last)
	hv.resize(last)
	var i := 0
	while true:
		var l := 2 * i + 1
		var r := l + 1
		var s := i
		if l < last and hk[l] < hk[s]:
			s = l
		if r < last and hk[r] < hk[s]:
			s = r
		if s == i:
			break
		var tk := hk[s]
		hk[s] = hk[i]
		hk[i] = tk
		var tv := hv[s]
		hv[s] = hv[i]
		hv[i] = tv
		i = s
	return top


func _add_path(path: PackedInt32Array) -> void:
	for k in path.size():
		net[path[k]] = 1
		if k > 0:
			var a := mini(path[k - 1], path[k])
			var b := maxi(path[k - 1], path[k])
			edges["%d-%d" % [a, b]] = true


# ------------------------------------------------------------------ the network
## `places`: Vector2 positions, the first is the seed of the network. `extra`: [a, b] index pairs that
## get a direct link too (the loops that make a network more than a tree).
func plan(places: Array, extra := []) -> Dictionary:
	var cells := []
	for p in places:
		cells.append(snap(p))
	var links := []
	var tracks := []
	var unreached := []
	var done := {}
	var first := 0
	while cells[first] < 0:
		first += 1
	done[first] = true
	net[cells[first]] = 1
	while done.size() + unreached.size() < places.size():
		var best := -1
		var bd := 1e30
		for i in places.size():
			if done.has(i) or unreached.has(i):
				continue
			for j in done:
				var d: float = places[i].distance_to(places[j])
				if d < bd:
					bd = d
					best = i
		if cells[best] < 0:
			unreached.append(best)
			continue
		var path := route(cells[best])
		if path.is_empty():
			max_grade = TRACK_GRADE  # a mountain track: steeper, but still a way in
			path = route(cells[best])
			max_grade = MAX_GRADE
			if not path.is_empty():
				tracks.append(best)
		if path.is_empty():
			unreached.append(best)
			continue
		var joined := path[path.size() - 1]
		_add_path(path)
		var to := first
		var td := 1e30
		for j in done:
			var d2: float = centre(cells[j] % n, cells[j] / n).distance_to(centre(joined % n, joined / n))
			if d2 < td:
				td = d2
				to = j
		links.append([best, to])
		done[best] = true
	for pair in extra:
		var a: int = pair[0]
		var b: int = pair[1]
		if cells[a] < 0 or cells[b] < 0:
			continue
		var path2 := route(cells[a], cells[b])
		if not path2.is_empty():
			_add_path(path2)
			links.append([a, b])
	return {"roads": _chains(), "bridges": [], "links": links, "unreached": unreached, "tracks": tracks}


## The edge set as smoothed polylines between junctions and ends (their end points are the exact grid
## cell centres, so where routes meet the polylines share a point).
func _chains() -> Array:
	var adj := {}
	for key in edges:
		var ab: PackedStringArray = key.split("-")
		var a := int(ab[0])
		var b := int(ab[1])
		if not adj.has(a):
			adj[a] = []
		if not adj.has(b):
			adj[b] = []
		adj[a].append(b)
		adj[b].append(a)
	var seen := {}
	var out := []
	var keys := adj.keys()
	keys.sort()
	for start in keys:
		if adj[start].size() == 2:
			continue
		for nb in adj[start]:
			var ek := "%d-%d" % [mini(start, nb), maxi(start, nb)]
			if seen.has(ek):
				continue
			var chain := [start]
			var prev: int = start
			var cur: int = nb
			seen[ek] = true
			chain.append(cur)
			while adj[cur].size() == 2:
				var nxt: int = adj[cur][0] if adj[cur][0] != prev else adj[cur][1]
				seen["%d-%d" % [mini(cur, nxt), maxi(cur, nxt)]] = true
				prev = cur
				cur = nxt
				chain.append(cur)
			var pts := PackedVector2Array()
			for c in chain:
				pts.append(centre(c % n, c / n))
			out.append(_smooth(pts))
	return out


func _smooth(pts: PackedVector2Array) -> Array:
	for pass_i in SMOOTH_PASSES:
		var q := PackedVector2Array()
		q.append(pts[0])
		for k in pts.size() - 1:
			q.append(pts[k] * 0.75 + pts[k + 1] * 0.25)
			q.append(pts[k] * 0.25 + pts[k + 1] * 0.75)
		q.append(pts[pts.size() - 1])
		pts = q
	# resample at about RESAMPLE_M
	var out := [[snappedf(pts[0].x, 0.1), snappedf(pts[0].y, 0.1)]]
	var acc := 0.0
	for k in range(1, pts.size()):
		acc += pts[k].distance_to(pts[k - 1])
		if acc >= RESAMPLE_M or k == pts.size() - 1:
			out.append([snappedf(pts[k].x, 0.1), snappedf(pts[k].y, 0.1)])
			acc = 0.0
	return out


# ------------------------------------------------------------------ checks
## Grade over each `window` metres of a polyline, and the water runs on it.
## Returns {"length", "max_grade", "steep_m" (grade > 8%), "water": [[start_m, end_m], ...]}.
static func measure(road: Array, height: Callable, is_water: Callable, window := 40.0) -> Dictionary:
	var length := 0.0
	var max_grade := 0.0
	var steep := 0.0
	var water := []
	var in_water := false
	var w0 := 0.0
	var last_h := 0.0
	var last_s := 0.0
	var first := true
	for k in road.size() - 1:
		var a := Vector2(road[k][0], road[k][1])
		var b := Vector2(road[k + 1][0], road[k + 1][1])
		var seg := a.distance_to(b)
		var steps := maxi(1, int(seg / 10.0))
		for q in steps + 1:
			var p := a.lerp(b, float(q) / steps)
			var s := length + seg * float(q) / steps
			var h: float = height.call(p.x, p.y)
			if first:
				last_h = h
				last_s = s
				first = false
			elif s - last_s >= window:
				var g := absf(h - last_h) / (s - last_s)
				max_grade = maxf(max_grade, g)
				if g > 0.08:
					steep += s - last_s
				last_h = h
				last_s = s
			var wet: bool = is_water.call(p.x, p.y)
			if wet and not in_water:
				w0 = s
			if not wet and in_water:
				water.append([w0, s])
			in_water = wet
		length += seg
	if in_water:
		water.append([w0, length])
	return {"length": length, "max_grade": max_grade, "steep_m": steep, "water": water}


## A bridge is straight: where a road runs over water, replace the wandering stretch (plus `pad` metres of
## bank each side) with one straight span between the two land points. Returns the new polyline.
static func straighten_bridges(road: Array, is_water: Callable, pad := 15.0) -> Array:
	var pts := PackedVector2Array()
	var cum := PackedFloat32Array()
	var total := 0.0
	for k in road.size():
		var p := Vector2(road[k][0], road[k][1])
		if k > 0:
			total += p.distance_to(pts[k - 1])
		pts.append(p)
		cum.append(total)
	var cuts := []  # [from_m, to_m]
	var in_water := false
	var w0 := 0.0
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var seg := a.distance_to(b)
		var steps := maxi(1, int(seg / 5.0))
		for q in steps:
			var p := a.lerp(b, float(q) / steps)
			var sm: float = cum[k] + seg * float(q) / steps
			var wet: bool = is_water.call(p.x, p.y)
			if wet and not in_water:
				w0 = sm
			if not wet and in_water:
				cuts.append([maxf(0.0, w0 - pad), minf(total, sm + pad)])
			in_water = wet
	if in_water:
		cuts.append([maxf(0.0, w0 - pad), total])
	if cuts.is_empty():
		return road
	# merge cuts that touch
	var merged := []
	for c in cuts:
		if not merged.is_empty() and c[0] <= merged[-1][1]:
			merged[-1][1] = maxf(merged[-1][1], c[1])
		else:
			merged.append(c)
	var result := []
	var ci := 0
	for k in pts.size():
		var d: float = cum[k]
		# spans that start at or before this vertex are emitted first (their end points, in order)
		while ci < merged.size() and merged[ci][0] <= d:
			if d > merged[ci][1] or d >= merged[ci][0]:
				for e in [merged[ci][0], merged[ci][1]]:
					var q := _at(pts, cum, e)
					result.append([snappedf(q.x, 0.1), snappedf(q.y, 0.1)])
				ci += 1
				continue
		var inside := false
		for m in merged:
			if d >= m[0] and d <= m[1]:
				inside = true
				break
		if not inside:
			result.append([road[k][0], road[k][1]])
	while ci < merged.size():
		for e in [merged[ci][0], merged[ci][1]]:
			var q2 := _at(pts, cum, e)
			result.append([snappedf(q2.x, 0.1), snappedf(q2.y, 0.1)])
		ci += 1
	return result


## The point `dist` metres along a polyline with cumulative lengths `cum` (binary search, so it's cheap).
static func _at(pts: PackedVector2Array, cum: PackedFloat32Array, dist: float) -> Vector2:
	if dist <= 0.0:
		return pts[0]
	if dist >= cum[cum.size() - 1]:
		return pts[pts.size() - 1]
	var lo := 0
	var hi := cum.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if cum[mid] <= dist:
			lo = mid
		else:
			hi = mid
	var t := (dist - cum[lo]) / maxf(0.001, cum[hi] - cum[lo])
	return pts[lo].lerp(pts[hi], t)
