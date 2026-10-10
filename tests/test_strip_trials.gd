extends TestCase
const Departure = StripTrials.Departure
## The per-runway-end strip trials of #88 (scripts/balance/strip_trials.gd): a takeoff stops when it has its
## answer, the forced end is the one flown, and an end with no clear final is reported, not dropped.


func after_each() -> void:
	StripTrials.use_map(0, false)  # the suite's default island and terrain, for whatever runs next


## The HAR control on both terrains: a flat sea-level departure, held on the runway line, reaches 3 km along it
## inside the corridor and stops there (Feasibility.takeoff_trial runs on to 400 s and scores a later crash as a pass).
func test_takeoff_holds_the_line_and_stops_at_3km_on_both_terrains() -> void:
	for natural in [false, true]:
		StripTrials.use_map(MapCity.SEED, natural)
		var af := World.airfield("HAR")
		var r := StripTrials.takeoff("c172p", "HAR", "light", 0)
		var tag := "natural" if natural else "classic"
		check_eq(r.status, "pass", "%s: %s" % [tag, r.outcome])
		check_eq(r.stop, "3km", tag)
		check(r.seconds < StripTrials.TAKEOFF_MAX_S * 0.5, "%s stopped at %.0f s" % [tag, r.seconds])
		check(r.along_m >= StripTrials.TAKEOFF_GOAL_M and r.along_m < StripTrials.TAKEOFF_GOAL_M + 100.0, "%s: %.0f m along the line" % [tag, r.along_m])
		check(r.max_cross_m < 60.0, "%s: held within %.0f m of the line" % [tag, r.max_cross_m])
		check(r.liftoff_m != null and r.liftoff_m > 50.0 and r.liftoff_m < af.length, "%s lifted off at %s m" % [tag, r.liftoff_m])
		check(r.to_15m_m != null and r.to_15m_m > r.liftoff_m, tag)
		check(r.min_clear_m != null and r.min_clear_m > 15.0, "%s climb-out clearance %s m" % [tag, r.min_clear_m])
		check_eq(r.lateral, StripTrials.LATERAL_MODE)
		check_eq(r.invalid_reason, "", tag)
		check_eq(r.usable_m, af.length - 25.0)
		check(r.liftoff_m <= r.usable_m, "%s lifted off inside the usable strip" % tag)


## Reaching 3 km is not enough: the run has to lift off inside the strip, get 15 m up and never put the CG under an
## obstacle top. Each failure is named, and the measured distances stay in the result.
func test_a_takeoff_that_reaches_3km_still_needs_a_valid_run() -> void:
	var usable := 1775.0
	check_eq(StripTrials.takeoff_verdict(223.0, 422.0, 136.0, usable), {"valid": true, "reason": ""})
	var late := StripTrials.takeoff_verdict(2100.0, 2300.0, 40.0, usable)
	check(not late.valid, "lifting off after the strip is over is not a takeoff from it")
	check("past the 1775 m of strip" in late.reason, late.reason)
	var none := StripTrials.takeoff_verdict(null, null, 40.0, usable)
	check(not none.valid and "never lifted off" in none.reason and "never reached 15 m" in none.reason, none.reason)
	var low := StripTrials.takeoff_verdict(300.0, 400.0, -2.5, usable)
	check(not low.valid and "2.5 m below an obstacle top" in low.reason, low.reason)
	var blind := StripTrials.takeoff_verdict(300.0, 400.0, null, usable)
	check(not blind.valid and "no airborne obstacle clearance" in blind.reason, blind.reason)
	var both := StripTrials.takeoff_verdict(2100.0, null, -1.0, usable)
	check_eq(both.reason.count(";"), 2, "every failed condition is listed: " + both.reason)
	check(StripTrials.takeoff_verdict(usable, 500.0, StripTrials.MIN_CLEARANCE_M, usable).valid, "the limits themselves are valid")


## A bounce, or a go-around that touches first, must not be reported as the final touchdown.
func test_touchdown_log_keeps_the_first_and_the_final_touchdown() -> void:
	var tdlog := StripTrials.TouchdownLog.new()
	check(tdlog.first_event().is_empty() and tdlog.last_event().is_empty())
	tdlog.sample(false, 0.0, 0.0, 0.0)
	tdlog.sample(true, 100.0, 5.0, -300.0)  # first touchdown, a firm one
	tdlog.sample(true, 120.0, 5.0, -300.0)  # rolling: not a new touchdown
	tdlog.sample(false, 150.0, 5.0, -300.0)  # bounced
	tdlog.sample(true, 220.0, 6.0, -90.0)  # final touchdown
	check_eq(tdlog.events.size(), 2)
	check_eq(tdlog.first_event(), [100.0, 5.0, 300.0])
	check_eq(tdlog.last_event(), [220.0, 6.0, 90.0], "final one, sink rate positive down")


## The hold uses PilotBot's own bank law: back toward the runway heading, back toward the line, and nothing to do on it.
func test_line_hold_banks_toward_the_forced_heading_and_back_to_the_line() -> void:
	StripTrials.use_map(MapCity.SEED, false)
	var s := Feasibility._session("c172p", "HAR")
	var bot := PilotBot.new(s, [])
	var st: FlightModel.FlightState = s.fm.state()
	var hdg := 100.0
	st.roll = 0.0
	st.p_dps = 0.0
	st.agl = 50.0
	st.heading = hdg
	check_near(StripTrials.hold_line_aileron(bot, st, hdg, 0.0), 0.0, 1e-6, "on the line, on the heading, wings level")
	st.heading = hdg - 20.0
	check(StripTrials.hold_line_aileron(bot, st, hdg, 0.0) > 0.0, "pointing left of the runway heading: bank right")
	st.heading = hdg
	check(StripTrials.hold_line_aileron(bot, st, hdg, 50.0) < 0.0, "50 m right of the line: bank left")
	check(StripTrials.hold_line_aileron(bot, st, hdg, -50.0) > 0.0, "50 m left of the line: bank right")
	st.heading = hdg - 90.0
	check_near(StripTrials.hold_line_aileron(bot, st, hdg, 0.0), 0.04 * 15.0, 1e-6, "low: PilotBot's 15 degree bank limit")
	st.agl = 200.0
	check_near(StripTrials.hold_line_aileron(bot, st, hdg, 0.0), 0.7, 1e-6, "higher: the full bank limit, aileron capped")
	s.dispose()


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
