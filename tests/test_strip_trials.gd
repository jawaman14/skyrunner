extends TestCase
## The per-runway-end strip trials of #88 (scripts/balance/strip_trials.gd): a takeoff stops when it has its
## answer, the forced end is the one flown, and an end with no clear final is reported, not dropped.


func after_each() -> void:
	StripTrials.use_map(0, false)  # the suite's default island and terrain, for whatever runs next


func test_takeoff_stops_at_the_3km_mark_instead_of_gliding_on() -> void:
	StripTrials.use_map(MapCity.SEED, false)
	var r := StripTrials.takeoff("c172p", "HAR", "light", 0)
	check_eq(r.status, "pass", str(r.outcome))
	check_eq(r.stop, "3km")
	# Feasibility.takeoff_trial runs on to 400 s and scores a later crash as a pass; this one stops
	check(r.seconds < StripTrials.TAKEOFF_MAX_S * 0.5, "stopped at %.0f s" % r.seconds)
	var af := World.airfield("HAR")
	check(r.liftoff_m != null and r.liftoff_m > 50.0 and r.liftoff_m < af.length, "lifted off at %s m" % r.liftoff_m)
	check(r.to_15m_m != null and r.to_15m_m > r.liftoff_m, "15 m reached after liftoff")
	check(r.min_clear_m != null and r.min_clear_m > 15.0, "climb-out clears the ground: %s m" % r.min_clear_m)
	check_eq(r.heading, af.heading)


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
