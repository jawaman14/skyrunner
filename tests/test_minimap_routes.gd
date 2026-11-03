extends TestCase
## The chart's destination lines that were missing after #390/#391: our own squads' routes and the AI pilot's legs still to fly.


func after_each() -> void:
	World.use_map(0)


func _war() -> Session:
	var s := Session.new({"seed": 3, "map_seed": MapCity.SEED, "location": "QRY",
		"features": Session.SANDBOX_FEATURES, "ground_war": true})
	s.police.frozen = true
	s.ground._started = true
	for f in s.ground.commanders:
		s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	return s


func test_only_our_moving_squads_get_a_line_to_their_route_end() -> void:
	var s := _war()
	var g := s.ground
	var ours = g.recruit("org", "foot", g.hq("org"), false)
	ours.route = PackedVector2Array([ours.pos(), ours.pos() + Vector2(300, 40)])
	var theirs = g.recruit("rival", "foot", g.hq("rival"), false)
	theirs.route = PackedVector2Array([theirs.pos(), theirs.pos() + Vector2(500, 0)])
	var parked = g.recruit("org", "foot", g.hq("org"), false)
	parked.route = PackedVector2Array()
	var before := JSON.stringify(g.squad_view(ours, "org"))
	var lines := Minimap.own_squad_lines(s)
	check_eq(lines.size(), 1, "one line: our moving squad; the rival's plan and a parked squad draw nothing")
	check_eq(lines[0].id, ours.id)
	check_near(float(lines[0].tx), ours.route[-1].x, 0.001)
	check_near(float(lines[0].ty), ours.route[-1].y, 0.001)
	check_eq(JSON.stringify(g.squad_view(ours, "org")), before, "reading the lines changes nothing")
	s.dispose()


func test_no_ground_war_no_lines() -> void:
	var s := Session.new({"seed": 3, "location": "QRY", "features": Session.SANDBOX_FEATURES})
	check(Minimap.own_squad_lines(s).is_empty())
	s.dispose()


func test_ai_route_is_the_legs_still_to_fly() -> void:
	var s := Session.new({"seed": 3, "map_seed": MapCity.SEED, "location": "QRY", "features": Session.SANDBOX_FEATURES})
	var runner := AutoRunner.new(s)
	check(Minimap.ai_route_of(runner).is_empty(), "no plan yet: no route")
	check(Minimap.ai_route_of(null).is_empty(), "a human flying: no route")
	var af := World.airfield("HAR")
	runner.bot = PilotBot.new(s, [PilotBot.Leg.new("goto", 100.0, 200.0), PilotBot.Leg.new("drop", 300.0, 400.0),
		PilotBot.Leg.new("land", af.x, af.y, "HAR")])
	var route := Minimap.ai_route_of(runner)
	check_eq(route.size(), 3)
	check_eq(route[1].kind, "drop")
	runner.bot.leg_i = 2
	route = Minimap.ai_route_of(runner)
	check_eq(route.size(), 1, "flown legs drop off the line")
	check_eq(route[0].kind, "land")
	check_near(float(route[0].x), af.x, 0.001)
	s.dispose()


func test_chart_draws_both_without_errors() -> void:
	var s := _war()
	var g := s.ground
	var ours = g.recruit("org", "foot", g.hq("org"), false)
	ours.route = PackedVector2Array([ours.pos(), ours.pos() + Vector2(300, 40)])
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 768)
	Engine.get_main_loop().root.add_child(viewport)
	var map := Minimap.new()
	viewport.add_child(map)
	map.setup(s)
	map.ai_route = [{"x": s.state.x + 2000.0, "y": s.state.y, "kind": "land"}]
	for big in [false, true]:
		map.big = big
		map.queue_redraw()
		await Engine.get_main_loop().process_frame
	check(true, "drew the scope and the chart")
	viewport.queue_free()
	s.dispose()


## Codex's review of #493: a route to a point off the scope stops at its rim (the scope draws with no clip rect).
func test_lines_are_clipped_to_the_scope() -> void:
	var map := Minimap.new()
	map._c = Vector2(100, 100)
	map._r = 50.0
	map.big = false
	var seg := map.clip_to_scope(Vector2(100, 100), Vector2(400, 100))
	check_eq(seg.size(), 2)
	check_near(seg[1].x, 150.0, 0.01, "stops at the rim, 50 px out")
	check(map.clip_to_scope(Vector2(300, 300), Vector2(400, 300)).is_empty(), "wholly off the disc: nothing drawn")
	var inside := map.clip_to_scope(Vector2(90, 100), Vector2(110, 100))
	check_near(inside[0].x, 90.0, 0.01, "inside: untouched")
	check_near(inside[1].x, 110.0, 0.01)
	map.free()
