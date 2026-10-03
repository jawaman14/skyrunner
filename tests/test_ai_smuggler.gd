extends TestCase
## The AI runner flight the task force hunts (AISmuggler): it comes in low, circles at the drop point
## kicking bales, runs for the edge, dives away from police, and its Director paces the flights.

var world: World


func before_each() -> void:
	World.use_map(0)
	world = World.new()


func after_each() -> void:
	World.use_map(0)


## A spot of open sea well away from the island, as far south-west as the water goes.
func _sea() -> Array:
	var h := World.HALF
	for f in [0.9, 0.8, 0.7, 0.6]:
		if world.is_water(-h * f, -h * f):
			return [-h * f, -h * f]
	return [-h * 0.9, -h * 0.9]


func _flight(from: Array, drop: Array, exit_: Array, opts := {}) -> AISmuggler:
	var heading := Py.fmod(Py.degrees(atan2(drop[0] - from[0], drop[1] - from[1])), 360.0)
	var z := world.ground(from[0], from[1]) + 70.0
	return AISmuggler.new("AI-1", from[0], from[1], z, heading, drop, exit_, 7, opts)


func _drop_log() -> Array:
	return []


func test_it_flies_to_the_drop_point_and_starts_circling() -> void:
	var sea := _sea()
	var from := [sea[0] + 3000.0, sea[1]]
	var a := _flight(from, sea, [sea[0], sea[1] - 4000.0])
	check(a.active() and a.state == "inbound", "a flight in the air, inbound")
	var seen := ""
	for i in 600:
		var r := a.update(0.5, world, [], func(_j, _x, _y, _z, _vx, _vy): pass)
		if r != "":
			seen = r
			break
	check_eq(seen, "dropping", "it reaches the drop point and begins the drop")
	check(PyMath.hypot(sea[0] - a.x, sea[1] - a.y) < 600.0, "within 600 m of the point: %.0f m" % PyMath.hypot(sea[0] - a.x, sea[1] - a.y))


func test_it_kicks_bales_over_water_then_runs_for_the_exit() -> void:
	var sea := _sea()
	var a := _flight([sea[0] + 200.0, sea[1]], sea, [sea[0] - 20000.0, sea[1] - 20000.0], {"bales_left": 3})
	a.state = "dropping"
	var drops := []
	var out := ""
	for i in 1200:
		var r := a.update(0.5, world, [], func(j, x, y, z, vx, vy): drops.append([j, x, y, z, vx, vy]))
		if r == "outbound":
			out = r
			break
	check_eq(drops.size(), 3, "every bale kicked out: %d" % drops.size())
	check_eq(drops[0][0], 7, "tagged with its job")
	check_eq(a.bales_left, 0, "none left aboard")
	check_eq(out, "outbound", "and it turns for home")


func test_it_dives_and_breaks_away_from_a_police_unit() -> void:
	var sea := _sea()
	var a := _flight([sea[0] + 3000.0, sea[1]], sea, [sea[0], sea[1] - 4000.0])
	a.update(0.5, world, [[a.x - 2000.0, a.y]], func(_j, _x, _y, _z, _vx, _vy): pass)
	check(a.evade_t > 0.0, "a unit inside 4 km starts the evasion")
	check_eq(a.agl_target, 35.0, "and it drops to 35 m")
	var calm := _flight([sea[0] + 3000.0, sea[1]], sea, [sea[0], sea[1] - 4000.0])
	calm.update(0.5, world, [[calm.x - 9000.0, calm.y]], func(_j, _x, _y, _z, _vx, _vy): pass)
	check_eq(calm.evade_t, 0.0, "a unit 9 km away is ignored")


func test_it_escapes_past_the_map_edge_and_a_dead_flight_stays_put() -> void:
	var h := World.HALF
	var a := _flight([h + 300.0, -h * 0.5], [h * 2.0, -h * 0.5], [h + 800.0, -h * 0.5])
	a.state = "outbound"
	var r := ""
	for i in 40:
		r = a.update(1.0, world, [], func(_j, _x, _y, _z, _vx, _vy): pass)
		if r != "":
			break
	check_eq(r, "escaped", "past the edge it is gone")
	check(not a.active(), "no longer active")
	var x := a.x
	check_eq(a.update(1.0, world, [], func(_j, _x, _y, _z, _vx, _vy): pass), "", "an escaped flight does nothing")
	check_eq(a.x, x, "and does not move")


func test_a_flight_into_a_hillside_crashes() -> void:
	var a := _flight([0.0, 0.0], [0.0, 20000.0], [0.0, 30000.0])
	a.z = world.ground(0.0, 0.0) - 5.0
	check_eq(a.update(0.1, world, [], func(_j, _x, _y, _z, _vx, _vy): pass), "crashed", "below the ground it is a wreck")
	check_eq(a.state, "crashed", "and stays one")


func test_the_signature_is_an_air_track_at_its_position() -> void:
	var a := _flight([100.0, 200.0], [5000.0, 5000.0], [9000.0, 9000.0])
	var sig := a.signature(world)
	check(sig.x == 100.0 and sig.y == 200.0, "where it is")


func test_entry_and_exit_are_seeded_and_outside_the_map() -> void:
	var r1 := PyRandom.new()
	r1.seed(5)
	var r2 := PyRandom.new()
	r2.seed(5)
	var a := AISmuggler.entry_and_exit(r1)
	var b := AISmuggler.entry_and_exit(r2)
	check_eq(a, b, "the same seed gives the same run")
	var h := World.HALF
	check(absf(a[0][0]) >= h * 0.6 or absf(a[0][1]) >= h, "it enters from outside the map")
	check(absf(a[1][0]) > h or absf(a[1][1]) > h, "and leaves by the edge")


func test_the_director_paces_the_flights() -> void:
	var r := PyRandom.new()
	r.seed(3)
	var d := AISmuggler.Director.new(r)
	check(not d.due(5.0, 0), "nothing before the first one is due")
	check(d.due(25.0, 0), "the first at 20 s")
	check(not d.due(25.0, 2), "but never more than two at once")
	d.schedule_next(25.0)
	check(d.next_t >= 25.0 + 150.0 * 0.7 and d.next_t <= 25.0 + 150.0 * 1.3, "the next one 105 to 195 s later: %.0f" % d.next_t)
