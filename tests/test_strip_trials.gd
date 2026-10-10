extends TestCase
const Departure = StripTrials.Departure
## The per-runway-end strip trials of #88 (scripts/balance/strip_trials.gd): a takeoff stops when it has its
## answer, the forced end is the one flown, and an end with no clear final is reported, not dropped.


func after_each() -> void:
	StripTrials.use_map(0, false)  # the suite's default island and terrain, for whatever runs next


func test_takeoff_stops_when_it_has_an_answer_instead_of_gliding_on() -> void:
	StripTrials.use_map(MapCity.SEED, false)
	var r := StripTrials.takeoff("c172p", "HAR", "light", 0)
	# Feasibility.takeoff_trial runs on to 400 s and scores a later crash as a pass; this one stops at its verdict
	check(r.seconds < StripTrials.TAKEOFF_MAX_S * 0.5, "stopped at %.0f s" % r.seconds)
	var af := World.airfield("HAR")
	check_eq(r.heading, af.heading)
	check(r.liftoff_m != null and r.liftoff_m > 50.0 and r.liftoff_m < af.length, "lifted off at %s m" % r.liftoff_m)
	check(r.to_15m_m != null and r.to_15m_m > r.liftoff_m, "15 m reached after liftoff")
	check(r.min_clear_m != null and r.min_clear_m > 15.0, "climb-out clears the ground: %s m" % r.min_clear_m)
	# the verdict matches the track: a pass is 3 km along the line inside the corridor, an inconclusive one left it
	# first (on 2026-10-11 the bot's terrain-avoidance heading takes it ~40 degrees left at 60-80 m here, over flat ground)
	check(r.status in ["pass", "inconclusive"], "%s: %s" % [r.status, r.outcome])
	if r.status == "pass":
		check(r.along_m >= StripTrials.TAKEOFF_GOAL_M, "3 km along the runway line: %.0f m" % r.along_m)
		check(r.max_cross_m <= StripTrials.corridor_m(r.along_m), "inside the corridor: %.0f m off the line" % r.max_cross_m)
	else:
		check(r.along_m < StripTrials.TAKEOFF_GOAL_M, "stopped short of the goal: %.0f m" % r.along_m)
		check(r.max_cross_m > StripTrials.corridor_m(r.along_m), "off the line by more than the corridor allows")


## A path that covers 3 km from the start but bends away from the runway line is not a straight departure:
## it must not pass (the radial-distance test it replaces would have passed it), and it is not a failure of
## the aircraft either.
func test_an_off_axis_3km_path_is_inconclusive_not_a_pass() -> void:
	var hdg := 100.0
	var u := Vector2(sin(deg_to_rad(hdg)), cos(deg_to_rad(hdg)))
	var right := Vector2(u.y, -u.x)
	# 600 m down the line, then a 40 degree turn to the right, flown on until it is 3 km from the start
	var off := Departure.new(0.0, 0.0, hdg)
	var bent := u.rotated(-deg_to_rad(40.0))  # clockwise with x east, y north: a right turn
	var verdict := ""
	var radial_3km := false
	var flown := 0.0
	while not radial_3km:
		var p: Vector2 = u * minf(flown, 600.0) + bent * maxf(0.0, flown - 600.0)
		radial_3km = p.length() >= StripTrials.TAKEOFF_GOAL_M
		var v := off.sample(p.x, p.y)
		if verdict == "":
			verdict = v
		flown += 10.0
	check(radial_3km, "the old test, 3 km from the start, would have passed this path")
	check_eq(verdict, "left corridor", "a turn away is caught, and before any 3 km verdict")
	check(off.along < StripTrials.TAKEOFF_GOAL_M, "never 3 km along the line: %.0f m" % off.along)
	check(off.cross > 0.0, "the turn was to the right, and the sign says so")
	# drift inside the corridor still passes, and the goal is the distance along the line, not from the start
	var drift := Departure.new(0.0, 0.0, hdg)
	verdict = ""
	for k in range(0, 3101, 10):
		var p: Vector2 = u * k + right * (0.1 * k)
		verdict = drift.sample(p.x, p.y)
		if verdict != "":
			break
	check_eq(verdict, "3km")
	check_near(drift.along, StripTrials.TAKEOFF_GOAL_M, 10.0)
	check_near(drift.max_cross, 300.0, 2.0, "300 m right at 3 km is inside the 465 m corridor")
	check_eq(StripTrials.corridor_m(3000.0), 465.0)


func test_landing_is_flown_to_the_forced_end() -> void:
	StripTrials.use_map(MapCity.SEED, false)
	var af := World.airfield("HAR")
	var r := StripTrials.landing("c172p", "HAR", "light", 1)
	check_eq(r.status, "pass", str(r.outcome))
	check_eq(r.heading, fposmod(af.heading + 180.0, 360.0), "end 1 lands the other way")
	check(r.touchdown_from_threshold_m != null and r.touchdown_from_threshold_m > 0.0
		and r.touchdown_from_threshold_m < af.length, "touched down on the runway from end 1: %s m" % r.touchdown_from_threshold_m)
	check(r.roll_m != null and r.roll_m > 0.0)


func test_an_end_without_a_clear_final_is_reported_obstructed() -> void:
	StripTrials.use_map(MapCity.SEED, false)
	var w := World.new()
	# a field in a pit: raise the ground under the whole final by planning against a strip moved below it
	var af := World.airfield("HAR")
	var sunk := Airfield.new("ZZZ", "Test pit", af.x, af.y, af.heading, af.length, af.width, -400.0, af.surface, af.kind)
	w.field_elev["ZZZ"] = -400.0
	var plan := StripTrials.approach_for_end(w, sunk, 0, 1.0, 300.0)
	check(not plan.clear, "a final 400 m below the surrounding ground is blocked")
	check(plan.ap.clear_m < 0.0)
	check(plan.worst_what in ["terrain", "trees"])
	var open := StripTrials.approach_for_end(w, af, 0, 1.0, 300.0)
	check(open.clear, "the hub's final is clear")


func test_jobs_respect_every_filter() -> void:
	var js := StripTrials.jobs(["c182"], ["QRY"], ["half"], [1], ["landing"])
	check_eq(js, [["landing", "c182", "QRY", "half", 1]])
	check_eq(StripTrials.jobs().size(), StripTrials.AIRCRAFT.size() * StripTrials.FIELDS.size() * Feasibility.LOADS.size() * 2 * 2)
