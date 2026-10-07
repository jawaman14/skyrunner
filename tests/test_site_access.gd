extends TestCase
class Land extends World:
	var water := false
	var bridge := false
	var grade := 0.0
	func ground(x: float, _y: float) -> float: return x * grade
	func is_water(x: float, _y: float) -> bool: return water and x > 4 and x < 12
	func travel_surface(x: float, y: float) -> float: return 2.65 if bridge else ground(x, y)

func _world() -> Land:
	var world := Land.new()
	world.airfields = []
	return world

func after_each() -> void: World.use_map(0)

func test_short_access_rejects_buildings_water_and_steep_ground() -> void:
	var world := _world()
	var site := SiteLayout.record(world, "wall", "stash", SiteLayout.frame(Vector2(8, 0), 0), Vector3(4, 3, 4))
	var access := SiteAccess.new(world, [site])
	check("wall" in access.segment_reason(Vector2.ZERO, Vector2(16, 0)), "short trips do not bypass footprints")
	access = SiteAccess.new(world, [])
	world.water = true
	check("water" in access.segment_reason(Vector2.ZERO, Vector2(16, 0)))
	world.bridge = true
	check_eq(access.segment_reason(Vector2.ZERO, Vector2(16, 0)), "", "shared deck makes water crossing legal")
	world.water = false
	world.bridge = false
	world.grade = 0.3
	check("grade" in access.segment_reason(Vector2.ZERO, Vector2(16, 0), true))
	check_eq(access.segment_reason(Vector2.ZERO, Vector2(16, 0)), "", "walkers have different slope constraints")

func test_connector_checks_both_legs_without_mutating_authoring_records() -> void:
	var world := _world()
	var site := SiteLayout.record(world, "one", "stash", SiteLayout.frame(Vector2.ZERO, 0), Vector3(8, 3, 8))
	site.connector = Vector2(0, 20)
	var before := site.duplicate(true)
	var access := SiteAccess.new(world, [site])
	var verified := access.verify(site)
	check(verified.connection_verified and verified.connection_reason == "")
	check_eq(site, before, "validation does not rewrite placement")
	site.connector = Vector2(0, 500)
	check(not access.verify(site).connection_verified, "remote sites do not acquire imaginary roads")
	site.connector = Vector2(0, -20)
	var detour := access.verify(site)
	check(detour.connection_verified, "access routes around the building instead of crossing it")
	check(detour.walking_connector.size() > 2)
	for i in detour.walking_connector.size() - 1:
		check_eq(access.segment_reason(detour.walking_connector[i], detour.walking_connector[i + 1]), "")

func test_runway_access_and_checked_network_failure_are_explicit() -> void:
	var world := _world()
	var af := Airfield.new("TEST", "Test", 8, 0, 90, 12, 4, 0, "grass", "bush")
	world.airfields = [af]
	var access := SiteAccess.new(world, [])
	check("runway" in access.segment_reason(Vector2.ZERO, Vector2(16, 0)))
	world.airfields = []
	var graph := RoadGraph.new([])
	graph.nodes = [Vector2.ZERO, Vector2(16, 0)]
	graph.adj = [[], []]
	graph.road_nodes = 2
	var route := access.checked_vehicle_route(graph, Vector2.ZERO, Vector2(16, 0))
	check(not route.reachable and route.points.is_empty(), "disconnected short network never becomes a straight trip")

func test_costa_brava_and_generated_validation_is_deterministic() -> void:
	for seed in [MapCity.SEED, 82]:
		World.use_map(seed)
		var world := World.new()
		var records := world.site_records()
		var access := SiteAccess.new(world, records)
		check_eq(access.verified_records(), access.verified_records())
		check(records.all(func(site): return not site.connection_verified), "authoring candidates remain unchanged")

func test_visibility_route_is_deterministic_and_blocked_water_stays_failed() -> void:
	var world := _world()
	var obstacle := SiteLayout.record(world, "middle", "stash", SiteLayout.frame(Vector2(8, 0), 0), Vector3(4, 3, 4))
	var access := SiteAccess.new(world, [obstacle])
	var route := access.path(Vector2.ZERO, Vector2(16, 0))
	check(route.reachable and route.points.size() > 2)
	check_eq(route, access.path(Vector2.ZERO, Vector2(16, 0)))
	check(RoadGraph.length(route.points) > 16, "detour does not cut through the obstacle")
	world.water = true
	access = SiteAccess.new(world, [])
	check(not access.path(Vector2.ZERO, Vector2(16, 0)).reachable, "no water fallback")
