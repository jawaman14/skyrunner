extends TestCase
## Physical NPCs, step 5: roads that cost something beyond their length. The A* takes a
## penalty hook; GroundWar.route() uses it so the organisation's squads and trucks go round a
## police checkpoint (and a place that has just seen shooting) when there is a way round.


func after_each() -> void:
	GroundWar.SMART_ROUTES = true
	World.use_map(0)


func _diamond() -> RoadGraph:
	# two ways from (0,0) to (1000,0): straight through (500,0), or round by (500,300)
	return RoadGraph.new([[[0, 0], [500, 0], [1000, 0]], [[0, 0], [500, 300], [1000, 0]]])


func test_no_penalty_is_the_old_route() -> void:
	var g := _diamond()
	var a := Vector2(0, 0)
	var b := Vector2(1000, 0)
	check_eq(g.route(a, b), g.route(a, b, Callable()), "same route with no hook")
	check(RoadGraph.length(g.route(a, b)) < 1010.0, "the short way (%.0f m)" % RoadGraph.length(g.route(a, b)))


func test_a_penalised_road_is_gone_round() -> void:
	var g := _diamond()
	var a := Vector2(0, 0)
	var b := Vector2(1000, 0)
	var pen := func(p: Vector2, q: Vector2, _l: float) -> float:
		return 4000.0 if RoadGraph.seg_distance(p, q, Vector2(500, 0)) < 100.0 else 0.0
	var r := g.route(a, b, pen)
	check(RoadGraph.length(r) > 1100.0, "the long way round (%.0f m)" % RoadGraph.length(r))
	var near := false
	for p in r:
		near = near or p.distance_to(Vector2(500, 0)) < 100.0
	check(not near, "nowhere near the checkpoint")
	# no way round: it goes through (the penalty only ever steers, it never closes a road)
	var single := RoadGraph.new([[[0, 0], [500, 0], [1000, 0]]])
	check_eq(single.route(a, b, pen).size(), single.route(a, b).size(), "a lone road is still a road")


func test_segment_distance() -> void:
	check_eq(RoadGraph.seg_distance(Vector2(0, 0), Vector2(10, 0), Vector2(5, 3)), 3.0, "beside the middle")
	check_eq(RoadGraph.seg_distance(Vector2(0, 0), Vector2(10, 0), Vector2(-4, 3)), 5.0, "past the end: to the end point")
	check_eq(RoadGraph.seg_distance(Vector2(2, 2), Vector2(2, 2), Vector2(5, 6)), 5.0, "a zero-length segment is a point")


func _war() -> Session:
	var s := Session.new({"seed": 3, "map_seed": MapCity.SEED, "location": "QRY",
		"features": Session.SANDBOX_FEATURES, "ground_war": true})
	s.police.frozen = true
	s.ground._started = true
	for f in s.ground.commanders:
		s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	return s


func test_the_organisation_routes_round_a_checkpoint_the_police_do_not() -> void:
	var s := _war()
	var g := s.ground
	var a := g.hq("org")
	var b := g.hq("rival")
	var base := g.graph.route(a, b)
	check(base.size() >= 3, "a road between the two bases")
	var cops_before := g.route("police", a, b)
	var cp: GroundWar.Squad = g.recruit("police", "car", RoadGraph.along(base, RoadGraph.length(base) * 0.5), false)
	cp.tactic = "checkpoint"
	var org := g.route("org", a, b)
	var cops := g.route("police", a, b)
	check_eq(cops, cops_before, "the police know where their own checkpoints are: it changes nothing for them")
	check(RoadGraph.length(org) >= RoadGraph.length(base) - 0.01, "never a shorter way than the shortest (%.0f vs %.0f)" % [RoadGraph.length(org), RoadGraph.length(base)])
	var through := false
	for i in org.size() - 1:
		through = through or RoadGraph.seg_distance(org[i], org[i + 1], cp.pos()) < GroundWar.AVOID_M
	var bypass := false
	if org != base:
		bypass = true
		check(not through, "the long way round keeps clear of the checkpoint")
	print("  checkpoint bypass available on this road: %s (%.0f m vs %.0f m)" % [bypass, RoadGraph.length(org), RoadGraph.length(base)])
	GroundWar.SMART_ROUTES = false
	check_eq(g.route("org", a, b), base, "switched off: the old shortest route")
	s.dispose()


func test_hot_places_cost_the_organisation_only() -> void:
	var s := _war()
	var g := s.ground
	var a := g.hq("org")
	var b := g.hq("rival")
	var base := g.graph.route(a, b)
	var mid := RoadGraph.along(base, RoadGraph.length(base) * 0.5)
	var rival_before := g.route("rival", a, b)
	g.hot_spots.append([s.time, mid.x, mid.y])
	check_eq(g.route("rival", a, b), rival_before, "Los Cuervos don't mind the noise")
	check(RoadGraph.length(g.route("org", a, b)) >= RoadGraph.length(base) - 0.01, "the organisation never gets a shorter way")
	s.dispose()
