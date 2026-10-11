extends TestCase
## Which runway end the autopilot's approach comes in on (#80, #82). Mountain strips are one-way by design
## (docs/STRIPS.md: QRY and PNR end 0 have terrain or trees in the approach), so a route that picks the end whose final
## fix is merely nearer can send the aircraft into the pit wall or the tree line, or reverse it onto the far end.
## Every other field keeps the old rule: the end whose final fix is nearer the aircraft.


func after_each() -> void:
	Terrain.natural = false
	World.use_map(0)


## `natural` is the terrain mode the world is built with (the shipped game flies the natural pass).
func _sess(natural := false) -> Session:
	Terrain.natural = natural
	var s := Session.new({"seed": 9, "map_seed": MapCity.SEED, "location": "HAR", "ground_war": false})
	s.police.frozen = true
	return s


## Entry points all round a field, close and far.
func _entries(af: Airfield) -> Array:
	var out := []
	for bearing in range(0, 360, 45):
		for dist in [2500.0, 6000.0]:
			var b := deg_to_rad(float(bearing))
			out.append([af.x + sin(b) * dist, af.y + cos(b) * dist])
	return out


## The runway end a route finishes on (its last waypoint is that threshold).
func _end_of(route: Array, af: Airfield) -> int:
	var last: Array = route[route.size() - 1]
	var t0: Array = af.threshold(0)
	return 0 if PyMath.hypot(last[0] - t0[0], last[1] - t0[1]) < 1.0 else 1


## The old rule, written out independently: whichever end's final fix is nearer the aircraft.
func _nearest_end(af: Airfield, x: float, y: float) -> int:
	var best := 0
	var best_d := INF
	for end in [0, 1]:
		var th: Array = af.threshold(end)
		var sgn := -1.0 if end == 0 else 1.0
		var d := PyMath.hypot(th[0] + sgn * af.ux * Session.APPROACH_FINAL_M - x, th[1] + sgn * af.uy * Session.APPROACH_FINAL_M - y)
		if d < best_d:
			best_d = d
			best = end
	return best


## The clearance check uses the height the route actually flies, not only the audit's steeper line (a bot review of #318): the
## final is a straight line from 30 m at the threshold to the fix, a little under 3 degrees, so on a bush strip, where the audit
## line is 4.5 degrees, the route sits lower and an obstacle between the two must block the end.
func test_the_check_uses_the_altitude_the_route_flies() -> void:
	check_near(Session.route_height_at(0.0), 30.0, 0.001)
	check_near(Session.route_height_at(Session.APPROACH_FINAL_M), Session.APPROACH_FINAL_M * tan(deg_to_rad(3.0)) + 15.0, 0.001)
	var route := Session.route_height_at(1200.0)
	var audit := 10.0 + 1200.0 * tan(deg_to_rad(4.5))
	check(route < audit - 5.0, "the route (%.0f m) is below the bush audit line (%.0f m) at 1.2 km" % [route, audit])
	var wall := (route + audit) / 2.0
	var flat := func(d: float) -> float: return 0.0
	var wall_at_1200 := func(d: float) -> float: return wall if absf(d - 1200.0) < 1.0 else 0.0
	check(Session.way_in_clear(100.0, 4.5, flat), "open ground is clear")
	check(not Session.way_in_clear(0.0, 4.5, wall_at_1200), "a %.0f m wall at 1.2 km, under the audit line but above the route, blocks it" % wall)
	check(Session.way_in_clear(0.0, 3.0, func(d: float) -> float: return 20.0 if absf(d - 1200.0) < 1.0 else 0.0), "a 20 m obstacle at 1.2 km is under both lines")
	# the same obstacle on the classic 3-degree strip: the audit line (10 + 63 m) is above the route there, so the route is the lower line too
	check(not Session.way_in_clear(0.0, 3.0, func(d: float) -> float: return route + 3.0 if absf(d - 1200.0) < 1.0 else 0.0))


## On the classic terrain tools/strip_audit.gd and docs/STRIPS.md describe. (On the natural pass HAR end 0 is also blocked:
## its hill rises about 22 m higher 1.2 km out, which puts the 3-degree path 13 m into it; that is a terrain finding, so it is
## not pinned here.)
func test_the_selector_blocks_exactly_the_ends_the_strip_audit_flags() -> void:
	var s := _sess(false)
	for af in World.AIRFIELDS:
		var want := [true, true]
		if af.code in ["QRY", "PNR"]:
			want[0] = false  # docs/STRIPS.md: terrain 53 m up at 570 m out (QRY), trees 153 m up at 3000 m out (PNR)
		for end in [0, 1]:
			check_eq(s.approach_end_clear(af, end), want[end], "%s end %d" % [af.code, end])
	s.dispose()


func test_a_blocked_end_is_never_chosen_when_the_other_is_clear() -> void:
	var s := _sess()
	for code in ["QRY", "PNR"]:
		var af := World.airfield(code)
		for e in _entries(af):
			s.state.x = e[0]
			s.state.y = e[1]
			check_eq(_end_of(s._approach_route(af), af), 1, "%s from (%.0f, %.0f)" % [code, e[0] - af.x, e[1] - af.y])
	s.dispose()


func test_other_fields_keep_the_nearest_end_rule() -> void:
	var s := _sess()
	for af in World.AIRFIELDS:
		if af.code in ["QRY", "PNR"]:
			continue
		for e in _entries(af):
			s.state.x = e[0]
			s.state.y = e[1]
			check_eq(_end_of(s._approach_route(af), af), _nearest_end(af, e[0], e[1]), "%s from (%.0f, %.0f)" % [af.code, e[0] - af.x, e[1] - af.y])
	s.dispose()


func test_the_choice_among_ends_is_nearest_clear_else_nearest() -> void:
	check_eq(Session._choose_end([100.0, 900.0], [true, true]), 0, "both clear: the nearer")
	check_eq(Session._choose_end([900.0, 100.0], [true, true]), 1)
	check_eq(Session._choose_end([100.0, 900.0], [false, true]), 1, "the nearer is blocked: the clear one")
	check_eq(Session._choose_end([900.0, 100.0], [true, false]), 0)
	check_eq(Session._choose_end([100.0, 900.0], [false, false]), 0, "both blocked: the old rule decides")
	check_eq(Session._choose_end([900.0, 100.0], [false, false]), 1)


## Whatever the terrain, the route comes in on a clear end whenever either end is clear.
func test_on_either_terrain_the_chosen_end_is_clear_when_any_end_is() -> void:
	for natural in [false, true]:
		var s := _sess(natural)
		for af in World.AIRFIELDS:
			var clear := [s.approach_end_clear(af, 0), s.approach_end_clear(af, 1)]
			if not (clear[0] or clear[1]):
				continue
			for e in _entries(af):
				s.state.x = e[0]
				s.state.y = e[1]
				var end := _end_of(s._approach_route(af), af)
				check(clear[end], "%s from (%.0f, %.0f), natural=%s: end %d is blocked" % [af.code, e[0] - af.x, e[1] - af.y, natural, end])
		s.dispose()
