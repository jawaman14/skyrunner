extends TestCase
## The two-axis autopilot: it holds a heading and an altitude, flies a list of waypoints along a fixed
## course line, says when it has arrived, and leaves the controls alone on the ground or when off.

func _state(opts := {}) -> FlightModel.FlightState:
	var s := FlightModel.FlightState.new()
	s.x = 0.0
	s.y = 0.0
	s.alt = 1000.0
	s.agl = 400.0
	s.heading = 90.0
	s.pitch = 3.0
	s.roll = 0.0
	s.ias_kts = 110.0
	s.gs_kts = 110.0
	s.vs_fpm = 0.0
	s.on_ground = false
	for k in opts:
		s.set(k, opts[k])
	return s


func test_it_does_nothing_until_engaged_or_while_on_the_ground() -> void:
	var ap := Autopilot.new()
	var c := FlightModel.Controls.make({"aileron": 0.3, "elevator": -0.2})
	ap.update(0.1, _state(), c)
	check(c.aileron == 0.3 and c.elevator == -0.2, "off: the pilot's controls pass through")
	ap.engage(_state())
	var g := FlightModel.Controls.make({"aileron": 0.3})
	ap.update(0.1, _state({"on_ground": true}), g)
	check_eq(g.aileron, 0.3, "on the ground: untouched")
	ap.disengage()
	check(not ap.engaged, "disengaged")


func test_engage_holds_the_heading_and_altitude_it_was_switched_on_at() -> void:
	var ap := Autopilot.new()
	var s := _state({"heading": 120.0, "alt": 1500.0})
	ap.engage(s)
	check(ap.engaged and ap.hdg_target == 120.0 and ap.alt_target == 1500.0, "the targets are where it is")
	check(ap.waypoints.is_empty(), "no waypoints: a plain hold")
	var c := ap.update(0.1, s, FlightModel.Controls.new())
	check(absf(c.aileron) < 0.05, "on heading: wings level (%.3f)" % c.aileron)


func test_it_banks_toward_the_heading_and_pitches_toward_the_altitude() -> void:
	var ap := Autopilot.new()
	ap.engage(_state({"heading": 90.0, "alt": 1000.0}))
	ap.hdg_target = 130.0  # 40 degrees to the right
	ap.alt_target = 1300.0  # 300 m up
	var c := ap.update(0.1, _state(), FlightModel.Controls.new())
	check(c.aileron > 0.2, "right of the heading: aileron to bank right (%.2f)" % c.aileron)
	check(c.aileron <= 0.6, "limited to 0.6")
	check(c.elevator < -0.02, "below the altitude: elevator back (negative is nose up) (%.3f)" % c.elevator)
	ap.hdg_target = 50.0
	ap.alt_target = 700.0
	var d := ap.update(0.1, _state(), FlightModel.Controls.new())
	check(d.aileron < -0.2, "left of the heading: bank left (%.2f)" % d.aileron)
	check(d.elevator > 0.0, "above the altitude: nose down")


func test_it_gives_up_altitude_to_keep_flying_speed() -> void:
	var ap := Autopilot.new()
	ap.engage(_state())
	ap.alt_target = 2000.0
	ap.min_ias_kts = 80.0
	var fast := ap.update(0.1, _state({"ias_kts": 110.0}), FlightModel.Controls.new())
	var ap2 := Autopilot.new()
	ap2.engage(_state())
	ap2.alt_target = 2000.0
	ap2.min_ias_kts = 80.0
	var slow := ap2.update(0.1, _state({"ias_kts": 60.0}), FlightModel.Controls.new())
	check(slow.elevator > fast.elevator, "below the floor speed the nose comes down (%.3f vs %.3f)" % [slow.elevator, fast.elevator])


func test_a_route_is_flown_leg_by_leg_and_arrival_is_announced_once() -> void:
	var ap := Autopilot.new()
	var s := _state({"x": 0.0, "y": 0.0, "heading": 0.0})
	ap.engage_route(s, [[0.0, 5000.0], [5000.0, 5000.0]], 1200.0)
	check_eq(ap.alt_target, 1200.0, "one altitude for the whole leg")
	check_eq(ap.wp_i, 0, "starting on the first leg")
	# abeam of the first waypoint: on to the second
	s.x = 0.0
	s.y = 4500.0
	ap.update(0.1, s, FlightModel.Controls.new())
	check_eq(ap.wp_i, 1, "within 800 m of the first: the second leg")
	check(not ap.arrived, "not there yet")
	# at the last waypoint
	s.x = 4800.0
	s.y = 5000.0
	s.heading = 90.0
	ap.update(0.1, s, FlightModel.Controls.new())
	check(ap.arrived, "the last one: arrived")
	check(ap.waypoints.is_empty(), "and the list is emptied so it holds the arrival course")
	ap.arrived = false
	ap.update(0.1, s, FlightModel.Controls.new())
	check(not ap.arrived, "it is not announced again")


func test_off_the_course_line_it_steers_back_onto_it() -> void:
	var ap := Autopilot.new()
	var s := _state({"x": 0.0, "y": 0.0, "heading": 0.0})
	ap.engage_route(s, [[0.0, 20000.0]], 1200.0)
	s.x = 600.0  # 600 m east of the line to a point due north
	s.y = 1000.0
	ap.update(0.1, s, FlightModel.Controls.new())
	check(ap.hdg_target < 0.0 or ap.hdg_target > 180.0, "east of the line: aim west of north (%.1f)" % ap.hdg_target)
	s.x = -600.0
	ap.update(0.1, s, FlightModel.Controls.new())
	check(ap.hdg_target > 0.0 and ap.hdg_target < 90.0, "west of the line: aim east of north (%.1f)" % ap.hdg_target)

func test_waypoint_behind_aircraft_gets_a_temporary_forward_intercept() -> void:
	var ap := Autopilot.new()
	var state := FlightModel.FlightState.new()
	state.x = 1000.0
	state.heading = 90.0
	state.gs_kts = 120.0
	state.ias_kts = 120.0
	state.alt = 1000.0
	state.pitch = 2.0
	ap.engage_route(state, [[0.0, 0.0], [100.0, 0.0]], 1000.0)
	ap.update(1.0 / 30.0, state, FlightModel.Controls.new())
	check(ap._intercept != null and float(ap._intercept[0]) > state.x + 1000.0, "a point ahead is flown first")
	check_eq(ap.waypoints, [[0.0, 0.0], [100.0, 0.0]], "the route itself is untouched: the real fix is still there")
	check_eq(ap.wp_i, 0, "still bound for the first real waypoint")
	check_eq(ap._leg_from, [state.x, state.y])


## Fly the autopilot's own commands with a bank-limited kinematic aircraft (3 degrees a second, the C172 at 18 degrees
## of bank), and return [arrived, seconds, final x, final y, highest waypoint index reached, route intact].
func _fly_route(route: Array, heading: float) -> Array:
	var ap := Autopilot.new()
	var s := FlightModel.FlightState.new()
	s.heading = heading
	s.gs_kts = 100.0
	s.ias_kts = 100.0
	s.alt = 1000.0
	s.pitch = 2.0
	ap.engage_route(s, route.duplicate(true), 1000.0)
	var dt := 0.1
	var t := 0.0
	var top := 0
	var intact := true
	while not ap.arrived and t < 1800.0:
		ap.update(dt, s, FlightModel.Controls.new())
		if ap.arrived:
			break
		top = maxi(top, ap.wp_i)
		intact = intact and ap.waypoints == route
		s.heading = fposmod(s.heading + clampf(Py.wrap180(ap.hdg_target - s.heading), -3.0 * dt, 3.0 * dt), 360.0)
		var v := s.gs_kts * 0.514444 * dt
		s.x += sin(deg_to_rad(s.heading)) * v
		s.y += cos(deg_to_rad(s.heading)) * v
		t += dt
	return [ap.arrived, t, s.x, s.y, top, intact]


func test_a_route_behind_the_aircraft_is_still_flown_to_its_last_waypoint() -> void:
	# Engaged heading north, every waypoint south of us: the first fix needs a turn of nearly 180 degrees.
	var route := [[0.0, -5000.0], [3000.0, -9000.0], [6000.0, -9000.0]]
	var r := _fly_route(route, 0.0)
	check(r[0], "it arrives within 30 minutes (%.0f s)" % r[1])
	var end := Vector2(r[2], r[3])
	check(end.distance_to(Vector2(6000.0, -9000.0)) < 1600.0, "and arrives at the last waypoint, not somewhere on the way (%.0f m off)" % end.distance_to(Vector2(6000.0, -9000.0)))
	check_eq(r[4], 2, "every waypoint was flown in order")
	check(r[5], "the route list was never edited")


func test_a_waypoint_straight_behind_is_turned_back_to_not_postponed_for_ever() -> void:
	var r := _fly_route([[0.0, -6000.0]], 0.0)
	check(r[0], "a single fix dead astern is reached (%.0f s)" % r[1])
	check(Vector2(r[2], r[3]).distance_to(Vector2(0.0, -6000.0)) < 1600.0, "at the fix")


func test_a_route_ahead_is_not_given_an_intercept() -> void:
	var ap := Autopilot.new()
	var s := FlightModel.FlightState.new()
	s.heading = 0.0
	s.gs_kts = 100.0
	s.ias_kts = 100.0
	s.alt = 1000.0
	ap.engage_route(s, [[0.0, 8000.0]], 1000.0)
	ap.update(0.1, s, FlightModel.Controls.new())
	check(ap._intercept == null, "a fix ahead is simply flown to")
