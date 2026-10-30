extends TestCase
## The flight debrief (owner, 30 Oct): a landing reports the flight, the route's records and Benny's time.


func before_each() -> void:
	RouteBests.path = "user://zz_test_route_bests.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RouteBests.path))


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RouteBests.path))
	RouteBests.path = RouteBests.PATH
	World.use_map(0)


func test_records_keep_the_fastest_and_the_softest() -> void:
	var r := RouteBests.record("HAR", "VAL", 600.0, 300.0)
	check(r.new_time and r.new_soft, "the first flight sets both")
	r = RouteBests.record("HAR", "VAL", 650.0, 120.0)
	check(not r.new_time and r.new_soft and r.best_seconds == 600.0 and r.softest_fpm == 120.0, "slower but softer")
	r = RouteBests.record("VAL", "HAR", 900.0, 500.0)
	check(r.new_time, "each direction is its own route")
	World.use_map(MapCity.SEED)
	r = RouteBests.record("HAR", "VAL", 900.0, 500.0)
	check(r.new_time, "the same codes on another island are another route")
	World.use_map(0)


func test_benny_is_quicker_on_the_faster_aircraft() -> void:
	var c172 := RouteBests.benny_seconds("HAR", "VAL", "c172p")
	var c310 := RouteBests.benny_seconds("HAR", "VAL", "c310")
	check(c172 > c310 and c310 > 180.0, "%.0f s against %.0f s" % [c172, c310])


func test_a_landing_reports_the_flight() -> void:
	var s := Session.new({"seed": 3, "location": "HAR"})
	s.time = 2000.0  # a take-off 420 s earlier must be a real time, not before the game began
	var got := []
	s.bus.subscribe("landed", func(ev): got.append(ev.data))
	s.log.airborne = true
	s.log.departed_from = "HAR"
	s.log.t_off = s.time - 420.0
	s.log.fuel_off = s.state.fuel_lb + 35.0
	s.log.money_off = s.money - 500
	s.log.last_touchdown_fpm = 140.0
	s._arrive(World.airfield("VAL"), s.state)
	check_eq(got.size(), 1, "one landing event")
	check(got.size() == 1 and got[0].has("from"), "the landing carries the flight")
	if got.size() == 1 and got[0].has("from"):
		check_eq(str(got[0].from), "HAR", "from")
		check_near(float(got[0].seconds), 420.0, 0.01, "seven minutes")
		check_near(float(got[0].fuel_used_lb), 35.0, 0.5, "fuel used")
		check(int(got[0].pay) >= 500, "the pay since take-off")
	s.dispose()
