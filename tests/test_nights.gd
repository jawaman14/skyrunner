extends TestCase
## NightDirector: the bridge between the HQ season and the live session. HQ plans while the crew is on
## the ground, the night begins when the pilot takes off with something hot, and the night is scored
## and the next one planned once the flights are over.

var _sess: Session


func after_each() -> void:
	if _sess != null:
		_sess.dispose()
		_sess = null
	World.use_map(0)


func _session(opts := {}) -> Session:
	var o := {"seed": 33, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES + ["hq"], "ground_war": false}
	o.merge(opts, true)
	_sess = Session.new(o)
	_sess.police.frozen = true
	_sess.update(1.0 / 30)
	return _sess


func _hot_job(s: Session) -> Jobs.Job:
	var jid := Jobs.new_id()
	var j := Jobs.Job.new(jid, "a load", "contraband", "HAR", "FRM", [Jobs.item("Unmarked crate", "cargo", 200.0, jid, {"hot": true})], 5000)
	s.active_jobs.append(j)
	return j


func test_the_season_starts_in_planning_and_the_bots_plan_once() -> void:
	var s := _session()
	var n: NightDirector = s.nights
	check(n != null, "the Organisation layer is on")
	check_eq(n.phase, "planning", "HQ is planning")
	check_eq(n.season.night, 1, "night one")
	check(not n._ai_planned or n.runner_ai == null, "the plan is drawn on the first tick")
	n.tick(1.0)
	if n.law_ai != null:
		check(n._ai_planned, "the AI chief has planned")
	var before: int = n.season.law.actions
	n.tick(1.0)
	check_eq(n.season.law.actions, before, "and does not plan again")


func test_orders_wait_for_the_crew_to_be_back_on_the_ground() -> void:
	var s := _session()
	var n: NightDirector = s.nights
	var ok = n.order("runner", "ready")
	check(ok == null or ok is String and not str(ok).begins_with("HQ orders wait"), "an order in planning is taken or refused on its merits: %s" % [ok])
	n.phase = "operation"
	var r = n.order("runner", "ready")
	check(r is String and str(r).begins_with("HQ orders wait"), "in operation: %s" % [r])
	n.phase = "planning"
	n.season.phase = "over"
	n.season.winner = "law"
	n.season.reason = "test"
	var over = n.order("law", "ready")
	check(over is String and str(over).contains("season is over"), "and once the season is over: %s" % [over])


func test_the_zone_of_a_job_follows_its_destination() -> void:
	var s := _session()
	var j := _hot_job(s)
	var z := NightDirector.zone_of(j)
	check(HQ.ZONES.has(z), "a zone the HQ knows: %s" % z)
	var found := ""
	for zone in HQ.ZONE_FIELDS:
		if not HQ.ZONE_FIELDS[zone].is_empty():
			found = zone
			var dest: String = HQ.ZONE_FIELDS[zone][0]
			var j2 := Jobs.Job.new(Jobs.new_id(), "x", "contraband", "HAR", dest, [], 100)
			check_eq(NightDirector.zone_of(j2), zone, "a drop at %s is in the %s" % [dest, zone])
			break
	check(found != "", "the map has fields in zones")


func test_a_night_begins_with_a_hot_load_and_is_scored_when_it_ends() -> void:
	var s := _session()
	var n: NightDirector = s.nights
	n.tick(1.0)
	var j := _hot_job(s)
	var night: int = n.season.night
	n._begin()
	check_eq(n.phase, "operation", "the operation is under way")
	check(n.main != null and n.main.kind == "main", "the pilot's run is the main one")
	check_eq(n.main.zone, NightDirector.zone_of(j), "in the zone of the load")
	check_eq(n.season.phase, "operation", "the season agrees")
	n.ended_at = s.time
	n._close_main()
	var hist: int = n.season.history.size()
	n._finish()
	check_eq(n.phase, "planning", "back to planning")
	check_eq(n.season.history.size(), hist + 1, "the night went in the books")
	if n.season.phase != "over":
		check_eq(n.season.night, night + 1, "and it is the next night")
		check(not n._ai_planned, "to be planned afresh")
	check(n.crews.is_empty(), "no flights carried over")


func test_the_view_says_which_phase_the_director_is_in() -> void:
	var s := _session()
	var v: Dictionary = s.nights.view("runner")
	check_eq(v["director_phase"], "planning", "in the runner's view")
	check(v.has("night"), "with the season's own numbers")
