extends TestCase
## The autopilot (U): plain heading/altitude hold, and the routed leg a second U asks for - a
## straight shot at cruise altitude for a legal load, a winding, low RoutePlanner route with the
## transponder off for a hot one (scripts/sim/autopilot.gd, Session._autopilot_navigate).


func after_each() -> void:
	World.use_map(0)


func _sess(opts := {}) -> Session:
	var o := {"seed": 9, "map_seed": MapCity.SEED, "location": "HAR", "ground_war": false}
	o.merge(opts, true)
	var s := Session.new(o)
	s.police.frozen = true
	return s


## Airborne, clear of HAR, as if partway through a climb-out (not spawned on top of the strip,
## which would make "the nearest airfield" degenerate to the one just left).
func _airborne(s: Session, hdg := 70.0) -> void:
	var af := World.airfield("HAR")
	s.spawn_airborne(af.x + 3000.0, af.y - 1000.0, hdg, 450.0, 95.0)
	s.log.departed_from = "HAR"  # what a real takeoff sets; spawn_airborne alone doesn't


func _fly(s: Session, secs: float, throttle := 0.8) -> void:
	for i in int(secs * 30):
		var inp := ControlMapper.InputFrame.new()
		inp.throttle_axis = throttle
		s.update(1.0 / 30, inp, null)


func test_plain_hold_is_unchanged_by_on_true() -> void:
	var s := _sess()
	_airborne(s)
	var r: Array = s.command(Roles.PILOT, "autopilot", {"on": true})
	check(r[0], "engaged")
	check(s.autopilot.waypoints.is_empty(), "a plain {on:true} never routes, even with a second call")
	r = s.command(Roles.PILOT, "autopilot", {"on": true})
	check(s.autopilot.waypoints.is_empty(), "still plain: {on:true} doesn't cycle")
	r = s.command(Roles.PILOT, "autopilot", {"on": false})
	check(r[0] and not s.autopilot.engaged, "and {on:false} always just turns it off")


func test_u_cycles_off_hold_navigate_off() -> void:
	var s := _sess()
	_airborne(s)
	check(not s.autopilot.engaged, "starts off")
	s.command(Roles.PILOT, "autopilot", {})
	check(s.autopilot.engaged and s.autopilot.waypoints.is_empty(), "U: on, holding course")
	s.command(Roles.PILOT, "autopilot", {})
	check(s.autopilot.engaged and not s.autopilot.waypoints.is_empty(), "U again: routing")
	s.command(Roles.PILOT, "autopilot", {})
	check(not s.autopilot.engaged, "U again: off")


func test_hot_cargo_flies_low_but_still_squawks_without_heat() -> void:
	var s := _sess({"trade": true})
	_airborne(s)
	s.command(Roles.PILOT, "autopilot", {})
	s.command(Roles.PILOT, "autopilot", {})
	check(s.transponder, "nothing hot aboard: squawking")
	var legal_alt := s.autopilot.alt_target
	s.command(Roles.PILOT, "autopilot", {})  # off

	var item := Loadout.Item.new(Jobs.new_id(), "Grass bales", "cargo", 100, 0)
	item.hot = true
	s.loadout.add(item)
	check(s.carrying_hot(), "now carrying something hot")
	s.command(Roles.PILOT, "autopilot", {})
	s.command(Roles.PILOT, "autopilot", {})
	check(s.transponder, "hot aboard but no heat on you yet: still squawking - a clean squawk draws no suspicion at all, so it's the safer default even hot")
	check(s.autopilot.waypoints.size() > 1, "a winding valley route, not a straight shot: %d waypoints" % s.autopilot.waypoints.size())
	check(s.autopilot.alt_target < legal_alt, "and well under the legal cruise altitude (%.0f < %.0f)" % [s.autopilot.alt_target, legal_alt])
	s.dispose()


func test_known_radar_zones_are_the_fixed_airfield_radars_only() -> void:
	var s := _sess({"trade": true})
	var zones: Array = s.known_radar_zones()
	var fixed := 0
	for a in s.world.airfields:
		if a.radar_km > 0:
			fixed += 1
	check(fixed > 0 and zones.size() == fixed, "one zone per airfield radar (%d of %d)" % [zones.size(), fixed])
	for z in zones:
		check(float(z.radius) > 0.0, "each zone has the radar's reach")
	# what the law keeps secret must not move the runner's route: raise the aerostat, buy a coastal radar
	var before: Array = zones.duplicate(true)
	s.police.sensors.site("AER").active = true
	s.police.sensors.add_site(SensorNet.RadarSite.new("XTRA", "Coastal radar", 500.0, 500.0, 100.0, 30000.0))
	check_eq(s.known_radar_zones(), before, "the aerostat and law-side sites are not in the runner's picture")
	s.dispose()


func test_a_hot_leg_is_planned_around_known_radar_and_a_legal_one_is_not() -> void:
	var s := _sess({"trade": true})
	_airborne(s)
	var item := Loadout.Item.new(Jobs.new_id(), "Grass bales", "cargo", 100, 0)
	item.hot = true
	s.loadout.add(item)
	s.command(Roles.PILOT, "autopilot", {})
	s.command(Roles.PILOT, "autopilot", {})
	var af: Airfield = s._autopilot_target()
	var with_zones: Array = RoutePlanner.plan_route(s.world, [s.state.x, s.state.y], [af.x, af.y], 6.0, 1.5, 1500.0, s.known_radar_zones())
	var n: int = mini(s.autopilot.waypoints.size(), with_zones.size())
	check(n > 1, "a routed hot leg")
	for i in n - 1:  # the last leg's altitude is overwritten by the autopilot, so compare the first x/y pairs
		check_eq([s.autopilot.waypoints[i][0], s.autopilot.waypoints[i][1]], [with_zones[i][0], with_zones[i][1]], "hot waypoint %d is the radar-aware route" % i)
	s.dispose()


func test_hot_cargo_goes_dark_once_there_is_heat_on_you() -> void:
	var s := _sess({"trade": true})
	_airborne(s)
	var item := Loadout.Item.new(Jobs.new_id(), "Grass bales", "cargo", 100, 0)
	item.hot = true
	s.loadout.add(item)
	s.police.case("runner").suspicion = 60.0
	s.command(Roles.PILOT, "autopilot", {})
	s.command(Roles.PILOT, "autopilot", {})
	check(not s.transponder, "suspicion already up: goes dark rather than keep squawking a track that's being watched")
	s.dispose()


func test_hot_cargo_goes_dark_once_wanted() -> void:
	var s := _sess({"trade": true})
	_airborne(s)
	var item := Loadout.Item.new(Jobs.new_id(), "Grass bales", "cargo", 100, 0)
	item.hot = true
	s.loadout.add(item)
	s.police.wanted = 1
	s.command(Roles.PILOT, "autopilot", {})
	s.command(Roles.PILOT, "autopilot", {})
	check(not s.transponder, "already wanted: goes dark")
	s.dispose()


func test_hot_cargo_goes_dark_once_tipped() -> void:
	var s := _sess({"trade": true})
	_airborne(s)
	var item := Loadout.Item.new(Jobs.new_id(), "Grass bales", "cargo", 100, 0)
	item.hot = true
	s.loadout.add(item)
	s.police.case("runner").tipped = true
	s.command(Roles.PILOT, "autopilot", {})
	s.command(Roles.PILOT, "autopilot", {})
	check(not s.transponder, "an informant's named this squawk: goes dark even with suspicion still low")
	s.dispose()


func test_a_legal_leg_joins_the_approach_instead_of_a_straight_shot() -> void:
	var s := _sess()
	_airborne(s)
	s.command(Roles.PILOT, "autopilot", {})
	s.command(Roles.PILOT, "autopilot", {})
	var w: Array = s.autopilot.waypoints
	check_eq(w.size(), 3, "a join, a final fix and the runway end")
	var af := s._autopilot_target()
	var last: Array = w[w.size() - 1]
	var th0: Array = af.threshold(0)
	var th1: Array = af.threshold(1)
	check(PyMath.hypot(last[0] - th0[0], last[1] - th0[1]) < 1.0 or PyMath.hypot(last[0] - th1[0], last[1] - th1[1]) < 1.0, "it ends at a runway end, not the field's middle")
	check(float(w[1][2]) < float(w[0][2]) and float(w[2][2]) < float(w[1][2]), "and comes down: each leg lower than the one before")
	var local: Array = af.to_local(w[1][0], w[1][1])
	check(absf(float(local[1])) < 1.0, "the final fix is on the runway's centreline")
	s.dispose()


## The old bug: aiming straight at a point and re-aiming every frame (pure pursuit) can settle into
## a stable orbit around it instead of ever arriving, especially from a steep initial heading error.
## This flies from almost the worst angle (nearly the reverse of the course) and checks it actually
## gets there instead of circling for ten simulated minutes.
func test_it_does_not_circle_a_distant_target() -> void:
	var s := _sess({"trade": true})
	var val := World.airfield("VAL")
	s.active_jobs.append(Jobs.Job.new(Jobs.new_id(), "test", "cargo", "HAR", "VAL", [], 100, {}))  # VAL is the destination, not whatever is nearest
	# aimed almost exactly away from VAL to begin with
	var away := Py.wrap180(PilotBot.bearing(val.x, val.y, val.x + 15000.0, val.y - 15000.0) + 180.0)
	s.spawn_airborne(val.x + 15000.0, val.y - 15000.0, away, 500.0, 95.0)
	s.log.departed_from = "FRM"  # anywhere but near here, so VAL isn't excluded as "just left"
	s.command(Roles.PILOT, "autopilot", {})
	s.command(Roles.PILOT, "autopilot", {})
	var d0 := PyMath.hypot(s.state.x - val.x, s.state.y - val.y)
	var closest := d0
	var arrived := false
	for i in 25 * 60 * 30:
		var inp := ControlMapper.InputFrame.new()
		inp.throttle_axis = 0.8
		s.update(1.0 / 30, inp, null)
		check(s.phase != "crashed", "didn't crash en route")
		if s.phase == "crashed":
			break
		var d := PyMath.hypot(s.state.x - val.x, s.state.y - val.y)
		closest = minf(closest, d)
		if d < 1500.0:
			arrived = true
			break
	check(arrived, "got within 1.5 km of VAL (closest approach was %.0f m of %.0f m start)" % [closest, d0])
	s.dispose()


func test_it_hands_back_control_once_it_arrives() -> void:
	var s := _sess()
	_airborne(s)
	s.command(Roles.PILOT, "autopilot", {})
	s.command(Roles.PILOT, "autopilot", {})
	var saw_arrival := false
	for i in 8 * 60 * 30:
		var inp := ControlMapper.InputFrame.new()
		inp.throttle_axis = 0.8
		s.update(1.0 / 30, inp, null)
		check(s.phase != "crashed", "didn't crash")
		if s.phase == "crashed":
			break
		for m in s.messages:
			if m[0] >= s.time - 0.04 and "your controls" in str(m[1]):
				saw_arrival = true
		if saw_arrival:
			break
	check(saw_arrival, "said so once, on arrival")
	check(s.autopilot.engaged and s.autopilot.waypoints.is_empty(), "still flying - holding the course it arrived on, not vanishing")
	s.dispose()


func test_target_prefers_the_active_job_over_the_nearest_field() -> void:
	var s := _sess({"trade": true})
	_airborne(s)
	var far := World.airfield("PNR")  # not the nearest field from HAR, but the job says go there
	var job := Jobs.Job.new(Jobs.new_id(), "test", "cargo", "HAR", far.code, [], 100, {})
	s.active_jobs.append(job)
	var picked := s._autopilot_target()
	check_eq(picked.code, far.code, "the active job's destination wins over whatever's merely nearest")
	s.dispose()


func test_target_skips_the_field_just_left() -> void:
	var s := _sess()
	_airborne(s)  # sets departed_from = HAR, and HAR is the nearest field from here
	var picked := s._autopilot_target()
	check(picked.code != "HAR", "not the one just departed: %s" % picked.code)
	s.dispose()


func test_too_close_falls_back_to_a_plain_hold() -> void:
	var s := _sess({"trade": true})
	var har := World.airfield("HAR")
	s.spawn_airborne(har.x + 200.0, har.y, 90.0, 300.0, 90.0)  # a few hundred metres up, nowhere to route to
	var job := Jobs.Job.new(Jobs.new_id(), "test", "cargo", "HAR", "HAR", [], 100, {})
	s.active_jobs.append(job)
	var h0 := s.state.heading
	s.command(Roles.PILOT, "autopilot", {})
	s.command(Roles.PILOT, "autopilot", {})
	check(s.autopilot.waypoints.is_empty(), "nothing close enough is worth routing to")
	check_near(s.autopilot.hdg_target, h0, 1.0, "just holds the heading it was on")
	s.dispose()


## Engaged just after lift-off (a few metres up, still climbing) the hold used to freeze that height and fly into the ground ahead.
func test_engaged_just_after_lift_off_climbs_to_clear_the_ground_ahead() -> void:
	var s := _sess({"features": []})
	var ar := AutoRunner.new(s, false)
	var dt := 1.0 / 30
	while s.time < 300.0:
		var c = ar.step(dt)
		if ar.bot != null and ar.bot.phase == "climb":
			break
		s.update(dt, null, c)
	check(not s.state.on_ground and s.state.agl < 30.0, "just airborne: %s m up" % s.state.agl)
	var r: Array = s.command(Roles.PILOT, "autopilot", {})
	check(r[0] and s.autopilot.engaged, "engaged")
	check(s.autopilot.alt_target > s.state.alt + 50.0, "it targets a safe height, not the %s m it is at: %s" % [s.state.alt, s.autopilot.alt_target])
	_fly(s, 30.0, 1.0)
	check(s.phase != "crashed" and not s.state.on_ground, "still flying 30 s later")
	check(s.state.alt > 60.0, "and has climbed: %s" % s.state.alt)
	s.dispose()


## A far fix behind used to be flown away from for 1.2-3.5 km before the turn back; now it is a plain bank-limited 180.
func test_a_far_fix_behind_is_turned_to_directly() -> void:
	var s := _sess({"features": []})
	_airborne(s, 70.0)
	var x0: float = s.state.x
	var y0: float = s.state.y
	var hdg: float = deg_to_rad(250.0)
	var far := [x0 + sin(hdg) * 15000.0, y0 + cos(hdg) * 15000.0]
	s.autopilot.engage_route(s.state, [far], s.state.alt, s.fm.controls.elevator)
	var ahead_max := 0.0
	for i in 150 * 30:
		var inp := ControlMapper.InputFrame.new()
		inp.throttle_axis = 0.8
		s.update(1.0 / 30, inp, null)
		ahead_max = maxf(ahead_max, (s.state.x - x0) * sin(deg_to_rad(70.0)) + (s.state.y - y0) * cos(deg_to_rad(70.0)))
	var bearing_now: float = PilotBot.bearing(s.state.x, s.state.y, far[0], far[1])
	check(absf(Py.wrap180(bearing_now - s.state.heading)) < 25.0, "after the turn it points at the fix: heading %s, bearing %s" % [s.state.heading, bearing_now])
	check(ahead_max < 2600.0, "it never flew on away from it for long: max %s m ahead" % ahead_max)
	check(PyMath.hypot(far[0] - s.state.x, far[1] - s.state.y) < 15000.0 - 3000.0, "and is closing on it")
	s.dispose()


## With a waypoint set, U flies there (it used to hold course and ignore it); U again is off.
func test_u_with_a_waypoint_flies_to_it_and_then_holds() -> void:
	var s := _sess({"features": []})
	_airborne(s, 70.0)
	var wp := [s.state.x + 6000.0, s.state.y + 2500.0]
	var r: Array = s.command(Roles.PILOT, "autopilot", {"waypoint": wp})
	check(r[0] and s.autopilot.engaged, "engaged")
	check(not s.autopilot.waypoints.is_empty() and s.autopilot.to_point, "routing to the waypoint, not holding course")
	var arrived_msg := false
	for i in 220 * 30:
		var inp := ControlMapper.InputFrame.new()
		inp.throttle_axis = 0.8
		s.update(1.0 / 30, inp, null)
		if not arrived_msg and not s.messages.is_empty() and "over your waypoint" in str(s.messages.back()[1]):
			arrived_msg = true
	check(arrived_msg, "it announced the arrival over the waypoint")
	check(s.autopilot.engaged and s.autopilot.waypoints.is_empty(), "and then holds course and altitude")
	check(PyMath.hypot(wp[0] - s.state.x, wp[1] - s.state.y) < 9000.0 and s.phase != "crashed", "still flying near it")
	s.dispose()


func test_u_again_while_routing_to_a_waypoint_switches_it_off() -> void:
	var s := _sess({"features": []})
	_airborne(s, 70.0)
	var wp := [s.state.x + 6000.0, s.state.y + 2500.0]
	s.command(Roles.PILOT, "autopilot", {"waypoint": wp})
	_fly(s, 5.0)
	check(s.autopilot.engaged and not s.autopilot.waypoints.is_empty(), "still routing")
	s.command(Roles.PILOT, "autopilot", {"waypoint": wp})
	check(not s.autopilot.engaged, "U again switches it off")
	s.dispose()


func test_u_without_a_waypoint_still_holds_course() -> void:
	var s := _sess({"features": []})
	_airborne(s, 70.0)
	s.command(Roles.PILOT, "autopilot", {})
	check(s.autopilot.engaged and s.autopilot.waypoints.is_empty() and not s.autopilot.to_point, "no waypoint: the plain hold, as before")
	s.dispose()


## Engaged slow (a pull-up that bled the speed away) with the pilot's throttle low: the autopilot adds power and gets the speed back
## instead of holding the height into a stall.
func test_engaged_slow_it_adds_power_and_recovers_speed() -> void:
	var s := _sess({"features": []})
	var af := World.airfield("HAR")
	s.spawn_airborne(af.x + 3000.0, af.y - 1000.0, 70.0, 700.0, 52.0)
	s.log.departed_from = "HAR"
	s.command(Roles.PILOT, "autopilot", {})
	var slow_min: float = s.autopilot.min_ias_kts
	check(s.state.ias_kts < slow_min + 8.0, "starts slow: %s kt against a minimum of %s" % [s.state.ias_kts, slow_min])
	_fly(s, 60.0, 0.2)
	check(s.phase != "crashed" and not s.state.on_ground, "still flying a minute later")
	check(s.state.ias_kts > slow_min, "and back above the minimum speed: %s kt" % s.state.ias_kts)
	s.dispose()


## Low over rising ground the hold may climb harder than the cruise rate.
func test_a_hold_far_below_its_target_climbs_faster_than_cruise_rate() -> void:
	var s := _sess({"features": []})
	_airborne(s)
	s.command(Roles.PILOT, "autopilot", {})
	s.autopilot.alt_target = s.state.alt + 400.0
	var best := 0.0
	for i in 20 * 30:
		var inp := ControlMapper.InputFrame.new()
		inp.throttle_axis = 1.0
		s.update(1.0 / 30, inp, null)
		best = maxf(best, s.state.vs_fpm)
	check(best > 650.0, "it climbed at more than 600 fpm: best %s" % best)
	s.dispose()


## Routed and low (just off the ground): it climbs straight ahead and does not turn towards the next fix until it is higher.
func test_a_routed_climb_out_does_not_turn_while_low() -> void:
	var s := _sess({"features": []})
	var af := World.airfield("HAR")
	var ground: float = s.world.ground(af.x, af.y)
	s.spawn_airborne(af.x, af.y, 70.0, ground + 25.0, 85.0)
	s.log.departed_from = "HAR"
	var hdg0: float = s.state.heading
	var behind := [af.x - sin(deg_to_rad(hdg0)) * 15000.0, af.y - cos(deg_to_rad(hdg0)) * 15000.0]  # the fix is straight behind: a turn would start at once
	s.autopilot.engage_route(s.state, [behind], ground + 600.0, s.fm.controls.elevator)
	var turned_while_low := false
	for i in 12 * 30:
		var inp := ControlMapper.InputFrame.new()
		inp.throttle_axis = 1.0
		s.update(1.0 / 30, inp, null)
		if s.state.agl < 140.0 and absf(Py.wrap180(s.state.heading - hdg0)) > 12.0:
			turned_while_low = true
	check(not turned_while_low, "no turn below 140 m above the ground")
	check(s.phase != "crashed", "and it did not crash")
	s.dispose()


## Pine Ridge sits on a plateau: leaving it for Harbor the ground ahead rises faster than a gentle climb. The old autopilot flew into it 32 s out.
func test_leaving_pine_ridge_for_the_hub_clears_the_rising_ground() -> void:
	var s := _sess({"trade": true})
	var from := World.airfield("PNR")
	s.active_jobs.append(Jobs.Job.new(Jobs.new_id(), "test", "cargo", "PNR", "HAR", [], 100, {}))
	var hdg: float = from.heading if (s.approach_end_clear(from, 1) or not s.approach_end_clear(from, 0)) else Py.wrap180(from.heading + 180.0)
	s.spawn_airborne(from.x, from.y, hdg, 312.0, 80.0)  # 312 m up over the strip, as the sweep starts it
	s.log.departed_from = "PNR"
	s.command(Roles.PILOT, "autopilot", {})
	s.command(Roles.PILOT, "autopilot", {})
	_fly(s, 90.0, 0.8)
	check(s.phase != "crashed" and not s.state.on_ground, "still flying 90 s after leaving Pine Ridge for Harbor")
	s.dispose()

