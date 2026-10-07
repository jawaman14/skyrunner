extends TestCase
## The road planner (RoadPlanner) on a made-up landscape, and the committed city network
## (data/maps/city_roads.json, tools/plan_roads.gd).

const LIMIT := 8000.0  ## the synthetic map is 16 km square


func after_each() -> void:
	World.use_map(0)  # the suite's default island, for whatever runs next


## Historical search retained only as a parity oracle for priority-queue changes.
func _linear_path(graph: RoadGraph, a: int, b: int, penalty: Callable, clear: Callable) -> Array:
	var g := {a: 0.0}
	var came := {}
	var open := [a]
	while not open.is_empty():
		var cur: int = open[0]
		var cf: float = g[cur] + graph.nodes[cur].distance_to(graph.nodes[b])
		for o in open:
			var f: float = g[o] + graph.nodes[o].distance_to(graph.nodes[b])
			if f < cf:
				cf = f
				cur = o
		if cur == b:
			var out := [b]
			while came.has(out[0]):
				out.push_front(came[out[0]])
			return out
		open.erase(cur)
		for e in graph.adj[cur]:
			if clear.is_valid() and not clear.call(graph.nodes[cur], graph.nodes[e[0]]):
				continue
			var ng: float = g[cur] + e[1]
			if penalty.is_valid():
				ng += maxf(0.0, float(penalty.call(graph.nodes[cur], graph.nodes[e[0]], e[1])))
			if not g.has(e[0]) or ng < g[e[0]]:
				g[e[0]] = ng
				came[e[0]] = cur
				if not open.has(e[0]):
					open.append(e[0])
	return []


func test_heap_search_preserves_linear_search_paths_with_ties_penalties_and_obstructions() -> void:
	var roads := []
	for x in 8:
		var row := []
		var col := []
		for y in 8:
			row.append([x * 500, y * 500])
			col.append([y * 500, x * 500])
		roads.append(row)
		roads.append(col)
	var graph := RoadGraph.new(roads)
	var penalty := func(a, b, _length): return 600.0 if a.x == b.x and b.x == 1500 else 0.0
	var clear := func(a, b): return not (a.y == b.y and a.y == 1000)
	for a in range(0, graph.nodes.size(), 5):
		for b in range(0, graph.nodes.size(), 7):
			for rules in [[Callable(), Callable()], [penalty, Callable()], [penalty, clear]]:
				check_eq(graph.path(a, b, rules[0], rules[1]), _linear_path(graph, a, b, rules[0], rules[1]), "exact node path parity")


func test_villa_approach_reaches_loading_both_ways_without_crossing_its_walls() -> void:
	World.use_map(MapCity.SEED)
	var world := World.new()
	var sites := world.site_records()
	var villa: Dictionary = sites.filter(func(site): return site.id == "stash/villa")[0]
	var access := SiteAccess.new(world, sites)
	var graph := RoadGraph.new(world.map.roads)
	var loading: Vector2 = Vector2(villa.loading.x, -villa.loading.z)
	var south := Vector2(-5500, 5418)
	for ends in [[south, loading], [loading, south]]:
		var route := access.checked_vehicle_route(graph, ends[0], ends[1])
		check(route.reachable, "villa loading area connects in both directions")
		for i in route.points.size() - 1:
			check_eq(access.segment_reason(route.points[i], route.points[i + 1], true), "", "all access segments clear")
	var road: Array = world.map.roads.filter(func(line): return Vector2(line[-1][0], line[-1][1]) == Vector2(-5514, 5508))[0]
	var padded := Geometry2D.offset_polygon(villa.footprint, RoadSurface.HALF_WIDTH)[0]
	for i in range(road.size() - 3, road.size() - 1):
		check(not SiteAccess._crosses(Vector2(road[i][0], road[i][1]), Vector2(road[i + 1][0], road[i + 1][1]), padded), "full road width clears villa")


func test_checked_short_routes_follow_authored_edges_without_false_tees() -> void:
	var graph := RoadGraph.new([[[0, 0], [0, 1000], [200, 1000], [200, 0]]])
	var result := graph.checked_route(Vector2.ZERO, Vector2(200, 0))
	check(result.reachable)
	check(RoadGraph.length(result.points) > 2100.0, "short trip must take the authored U, not the speculative 200m tee")
	var disconnected := RoadGraph.new([[[0, 0], [0, 1000]], [[200, 0], [200, -1000]]])
	var refused := disconnected.checked_route(Vector2.ZERO, Vector2(200, 0))
	check(not refused.reachable and refused.points.is_empty() and refused.reason != "")
	var blocked := graph.checked_route(Vector2(-30, 0), Vector2(200, 0), Callable(), func(a, _b): return a.x >= 0)
	check(not blocked.reachable and "access" in blocked.reason)
	check(not graph.checked_route(Vector2(NAN, 0), Vector2.ZERO).reachable)


## A round hill in the middle (steep: 150 m up, about 13% at its steepest), a river along y = 2000 (water
## 200 m wide), flat elsewhere.
func _hill(x: float, y: float) -> float:
	var d := Vector2(x, y).length()
	return 150.0 * exp(-pow(d / 1000.0, 2.0))


func _river(x: float, y: float) -> bool:
	return absf(y - 2000.0) < 100.0


func _height(x: float, y: float) -> float:
	return -3.0 if _river(x, y) else _hill(x, y)


func _passable(x: float, y: float) -> float:
	return 40.0 if _river(x, y) else 1.0


func _plan(places: Array) -> Dictionary:
	var pl := RoadPlanner.new(_height, _passable, LIMIT)
	return pl.plan(places)


func test_a_road_goes_round_a_hill_not_over_it() -> void:
	var res := _plan([Vector2(-4000, -200), Vector2(4000, 200)])
	check(res.unreached.is_empty(), "both places connected")
	var worst := 0.0
	var longest := 0.0
	for r in res.roads:
		var m := RoadPlanner.measure(r, _height, _river)
		worst = maxf(worst, m.max_grade)
		longest = maxf(longest, m.length)
	check(worst <= 0.11, "no steeper than about 10%%: %.1f%%" % (worst * 100.0))
	check(longest > 8100.0, "it's longer than the straight line over the top (8.0 km): %.0f m" % longest)
	check(longest < 10500.0, "but not a huge detour: %.0f m" % longest)


func test_the_planner_bridges_a_river_only_when_it_has_to() -> void:
	# both places north of the river: no bridge; one each side: exactly one
	var same := _plan([Vector2(-3000, 3500), Vector2(3000, 3500)])
	var over := 0
	for r in same.roads:
		over += RoadPlanner.measure(r, _height, _river).water.size()
	check_eq(over, 0, "no crossing when none is needed")
	var res := _plan([Vector2(-3000, 3500), Vector2(-2500, 300)])
	check(res.unreached.is_empty(), "a place across the river is reached")
	var crossings := 0
	for r in res.roads:
		crossings += RoadPlanner.measure(r, _height, _river).water.size()
	check_eq(crossings, 1, "by one bridge")


func test_a_bridge_is_straightened_and_junctions_are_shared() -> void:
	var wiggly := [[-100.0, 1500.0], [-60.0, 1800.0], [60.0, 1950.0], [-70.0, 2050.0], [40.0, 2200.0], [30.0, 2600.0]]
	var straight := RoadPlanner.straighten_bridges(wiggly, _river)
	var wet := 0
	for p in straight:
		if _river(p[0], p[1]):
			wet += 1
	check_eq(wet, 0, "no vertex left in the water (the span is one straight leg)")
	check(straight.size() < wiggly.size() + 2, "the wandering is gone")
	var res := _plan([Vector2(-3000, -3000), Vector2(0, -3000), Vector2(3000, -3000), Vector2(0, -600)])
	var ends := {}
	for r in res.roads:
		for e in [r[0], r[r.size() - 1]]:
			var key := "%d,%d" % [int(e[0]), int(e[1])]
			ends[key] = int(ends.get(key, 0)) + 1
	var shared := 0
	for k in ends:
		if ends[k] >= 3:
			shared += 1
	check(shared >= 1, "routes meet at a shared junction point")


func test_grade_measure_sees_a_hill() -> void:
	var over := [[-2000.0, 0.0], [2000.0, 0.0]]
	var m := RoadPlanner.measure(over, _height, _river)
	check(m.max_grade > 0.09, "straight over the hill is steep: %.1f%%" % (m.max_grade * 100.0))
	check(m.steep_m > 100.0, "for a good while: %.0f m" % m.steep_m)


# ------------------------------------------------------------------ the committed network
func test_the_city_network_connects_the_places_that_matter() -> void:
	var w := World.new()
	World.use_map(MapCity.SEED)
	w = World.new()
	var roads: Array = w.map.roads
	check(roads.size() > 10, "a network: %d roads" % roads.size())
	var g := RoadGraph.new(roads)
	var har := World.airfield("HAR")
	var downtown := g.nearest(MapCity.ORG_AT)
	check(g.connected(Vector2(har.x, har.y), MapCity.ORG_AT), "the airport to downtown")
	for code in ["VAL", "FRM", "MGR", "COV"]:
		var af := World.airfield(code)
		check(g.connected(Vector2(har.x, har.y), Vector2(af.x, af.y)), "the airport to %s" % code)
	for st in w.map.stashes:
		if st.id == "boathouse":
			continue  # on a cay
		var near := MapCity.RoadIndex.new(roads, 400.0).dist(Vector2(st.x, st.y))
		check(near < 400.0, "%s is %.0f m from a road" % [st.id, near])
	check(downtown >= 0, "downtown is on the graph")

## A ring link is a second way, not a copy of the first: on flat ground the planner joins two places,
## then a ring link between them finds a corridor clear of that road, so a roadblock on one leaves the other.
func test_a_ring_link_is_a_second_road_not_the_first_again() -> void:
	var a := Vector2(-4000, -3000)
	var b := Vector2(4000, -3000)
	var tree := RoadPlanner.new(_height, _passable, LIMIT).plan([a, b])
	var ring := RoadPlanner.new(_height, _passable, LIMIT).plan([a, b], [], [[0, 1]])
	var g1 := RoadGraph.new(tree.roads)
	var g2 := RoadGraph.new(ring.roads)
	var mid := Vector2(0, -3000)
	var block := func(p: Vector2, q: Vector2, _l: float) -> float:
		return 4000.0 if RoadGraph.seg_distance(p, q, mid) < 300.0 else 0.0
	var first := g1.route(a, b, block)
	var through := false
	for i in first.size() - 1:
		through = through or RoadGraph.seg_distance(first[i], first[i + 1], mid) < 300.0
	check(through, "with one road there is no way round the roadblock")
	var second := g2.route(a, b, block)
	var clear := true
	for i in second.size() - 1:
		clear = clear and RoadGraph.seg_distance(second[i], second[i + 1], mid) >= 300.0
	check(clear, "with the ring link the roadblock is bypassed (%.0f m vs %.0f m)" % [RoadGraph.length(second), RoadGraph.length(g2.route(a, b))])
	check(RoadGraph.length(second) < 2.0 * RoadGraph.length(g1.route(a, b)), "and the second way is not absurd")


func test_the_city_has_a_road_round_a_checkpoint() -> void:
	World.use_map(MapCity.SEED)
	var w := World.new()
	var g := RoadGraph.new(w.map.roads)
	var har := World.airfield("HAR")
	var a := Vector2(har.x, har.y)
	var base := g.route(a, MapCity.ORG_AT)
	check(base.size() >= 3, "a road from the airport to downtown")
	var cp := RoadGraph.along(base, RoadGraph.length(base) * 0.5)
	var block := func(p: Vector2, q: Vector2, _l: float) -> float:
		return 4000.0 if RoadGraph.seg_distance(p, q, cp) < GroundWar.AVOID_M else 0.0
	var alt := g.route(a, MapCity.ORG_AT, block)
	var clear := true
	for i in alt.size() - 1:
		clear = clear and RoadGraph.seg_distance(alt[i], alt[i + 1], cp) >= GroundWar.AVOID_M
	check(clear, "a checkpoint halfway along the airport-downtown road can be driven round (%.0f m vs %.0f m)" % [RoadGraph.length(alt), RoadGraph.length(base)])


func test_the_city_roads_are_gentle_and_dry() -> void:
	World.use_map(MapCity.SEED)
	var w := World.new()
	var total := 0.0
	var steep := 0.0
	var worst_bridge := 0.0
	var bridges := 0
	for ri in w.map.roads.size():
		var m := RoadPlanner.measure(w.map.roads[ri], func(x: float, y: float) -> float: return w.terrain.height64(x, y),
			func(x: float, y: float) -> bool: return w.terrain.height64(x, y) < 0.3)
		total += m.length
		steep += m.steep_m
		for span in m.water:
			bridges += 1
			worst_bridge = maxf(worst_bridge, span[1] - span[0])
	check(total > 60000.0, "a real network: %.0f km" % (total / 1000.0))
	check(steep / total < 0.12, "under 12%% of it steeper than 8%%: %.1f%%" % (steep / total * 100.0))
	check(bridges <= 3, "a few bridges at most: %d" % bridges)
	check(worst_bridge < 350.0, "none of them huge: %.0f m" % worst_bridge)
	check_eq(w.map.bridges.size(), bridges, "and every water crossing is a listed bridge")


func test_no_road_crosses_a_runway() -> void:
	World.use_map(MapCity.SEED)
	var w := World.new()
	for af in w.airfields:
		for r in w.map.roads:
			for k in r.size() - 1:
				var a := Vector2(r[k][0], r[k][1])
				var b := Vector2(r[k + 1][0], r[k + 1][1])
				var hit := false
				for q in 9:
					var p := a.lerp(b, q / 8.0)
					if af.contains(p.x, p.y, 5.0):
						hit = true
				check(not hit, "%s: a road runs across the strip" % af.code)
				if hit:
					return

func test_checked_geometry_keeps_close_bends_and_real_crossing_junctions() -> void:
	var roads := [[[0, 0], [25, 0], [25, 25], [200, 25]], [[100, -100], [100, 100]]]
	var graph := RoadGraph.new(roads)
	var original_nodes := graph.nodes.duplicate(true)
	var original_adj := graph.adj.duplicate(true)
	var checked := graph.checked_network()
	check(checked.nodes.has(Vector2(25, 0)) and checked.nodes.has(Vector2(25, 25)), "60m legacy merging cannot cut a checked corner")
	check(checked.nodes.has(Vector2(100, 25)), "real crossing is a junction")
	var route := graph.checked_route(Vector2.ZERO, Vector2(100, 100))
	check(route.reachable and route.points.has(Vector2(100, 25)))
	check(route.points.has(Vector2(25, 0)) and route.points.has(Vector2(25, 25)))
	check_eq(graph.nodes, original_nodes)
	check_eq(graph.adj, original_adj, "legacy simulation topology is unchanged")
	check_eq(checked, graph.checked_network(), "checked topology is cached")

func test_checked_nearby_parallel_roads_do_not_become_connected() -> void:
	var graph := RoadGraph.new([[[0, 0], [100, 0]], [[0, 40], [100, 40]]])
	var result := graph.checked_route(Vector2.ZERO, Vector2(100, 40))
	check(not result.reachable and result.points.is_empty(), "nearby endpoints cannot invent a connection")
