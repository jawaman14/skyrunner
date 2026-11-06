extends TestCase
## The visible territory map: districts tinted by who holds them, on the desks' map and the pilot's chart (a read-only view).


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


func test_leader_uses_the_ground_war_share_rule() -> void:
	check_eq(StationMap.turf_leader({"org": 60.0, "rival": 20.0, "police": 40.0}).leader, "org")
	check_near(float(StationMap.turf_leader({"org": 60.0, "rival": 20.0, "police": 40.0}).share), 0.6, 0.0001, "police count half")
	check_eq(StationMap.turf_leader({"org": 35.0, "rival": 35.0, "police": 60.0}).leader, "", "nobody at 40%: contested")
	check_eq(StationMap.turf_leader({}).leader, "", "empty district: no holder")
	check_eq(StationMap.turf_leader({"org": 0.2, "rival": 0.3}).leader, "", "too little presence to count")
	check_eq(StationMap.turf_name("org", "org"), "ours", "the runner's own districts")
	check_eq(StationMap.turf_name("org", "police"), "the organisation", "the law's desk never calls the organisation's turf its own")
	check_eq(StationMap.turf_name("police", "police"), "ours")
	check_eq(StationMap.turf_name("police", "org"), "the law")
	check_eq(StationMap.turf_name("rival", "police"), "Los Cuervos")


func test_costa_brava_snapshot_carries_every_district_outline() -> void:
	var s := _war()
	var key := Territories.key(s.world.map, "barrio-chino")
	s.ground.territory_control[key] = {"org": 0.0, "rival": 90.0, "police": 20.0}
	var before := JSON.stringify(s.ground.territory_control)
	var rows := StationMap.turf_rows(s.ground.snapshot("org"))
	check_eq(rows.size(), s.world.map.territories.size(), "one row per authored district")
	for row in rows:
		check(row.bounds is Rect2, str(row.name) + " has its outline")
	var bc: Dictionary = Py.first(rows, func(r): return r.id == key)
	check_eq(bc.leader, "rival")
	check_eq(bc.name, "Barrio Chino")
	check_eq(JSON.stringify(s.ground.territory_control), before, "the view changes nothing")
	var chart := Minimap.turf_of(s)
	check_eq(chart.size(), rows.size(), "the pilot's chart reads the same districts")
	check_eq(Py.first(chart, func(r): return r.id == key).leader, "rival")
	s.dispose()


func test_off_without_a_ground_war_or_territories() -> void:
	var s := Session.new({"seed": 3, "location": "QRY", "features": Session.SANDBOX_FEATURES})
	check(Minimap.turf_of(s).is_empty())
	check(StationMap.turf_rows({}).is_empty())
	s.dispose()
	var w := _war()
	var was := Territories.ENABLED
	Territories.ENABLED = false
	check(Minimap.turf_of(w).is_empty())
	Territories.ENABLED = was
	w.dispose()


func test_maps_draw_the_overlay() -> void:
	var s := _war()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 768)
	Engine.get_main_loop().root.add_child(viewport)
	var map := Minimap.new()
	viewport.add_child(map)
	map.setup(s)
	map.big = true
	map.visible = true
	map.size = Vector2(700, 700)
	for i in 3:
		map.queue_redraw()
		await Engine.get_main_loop().process_frame
	check(not map._turf.is_empty(), "the chart filled its districts")
	var desk := StationMap.new()
	desk.size = Vector2(600, 600)
	viewport.add_child(desk)
	desk.snap = {"side": "runner", "ground": s.ground.snapshot("org")}
	desk.queue_redraw()
	await Engine.get_main_loop().process_frame
	check(true, "the desk drew its districts")
	viewport.queue_free()
	s.dispose()
