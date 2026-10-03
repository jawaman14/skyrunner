extends TestCase
## What a save keeps of the organisation (StrategicSave): the stash houses, the stock in them, the
## crew and their posts, the runner's case file, the court case, the organisation's squads, and the clock.

const PATH := "user://test_strategic_save.json"


func after_each() -> void:
	World.use_map(0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _opts() -> Dictionary:
	return {"seed": 12, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "payroll": true,
		"court": true, "ground_war": true, "trade": true, "logistics": true}


func _quiet(s: Session) -> void:
	s.police.frozen = true
	s.payroll.ai["org"] = false
	s.payroll.ai["rival"] = false
	if s.family != null:
		s.family.ai = false
	s.court.prosecutor_ai = false
	s.ground._started = true  # no opening deployment: only the squads a test raises
	for f in s.ground.commanders:
		s.ground.commanders[f].ai = false


func _hire(s: Session, role: String, n: int) -> Array:
	var ids := []
	for i in n:
		var w: Dictionary = s.payroll._person("org", role)
		w.loyalty = 0.8
		s.payroll.candidates.org.append(w)
		check_eq(s.payroll.hire("org", w.id), "", "hired a %s" % role)
		ids.append(w.id)
	return ids


func test_a_save_keeps_the_organisation() -> void:
	var o := _opts()
	o["save_path"] = PATH
	var s := Session.new(o)
	_quiet(s)
	s.update(1.0 / 30)
	s.money = 100000
	_hire(s, "soldier", 4)
	var lk: String = _hire(s, "lookout", 1)[0]
	var driver: String = _hire(s, "driver", 1)[0]
	var stash_a: Dictionary = s.stash_net.stashes[0]
	var stash_b: Dictionary = s.stash_net.stashes[1]
	check_eq(s.payroll.post_lookout(lk, stash_a.id), "", "a lookout posted")
	s.payroll.get_worker(driver).status = "assigned"
	s.payroll.get_worker(driver).assigned = "truck-9"  # a job that will not survive the save
	var q: GroundWar.Squad = s.ground.recruit("org", "foot", null)
	check(q is GroundWar.Squad, "a squad raised: %s" % [q])
	stash_a.heat = 33.0
	stash_a.intel = 12.5
	stash_b.burned = true
	s.logistics.stock[stash_a.id] = {"grass": 120.0}
	s.logistics.cash[stash_a.id] = 5000
	s.police.case("runner").suspicion = 41.0
	s.time = 1234.0
	var workers_before: int = s.payroll.workers.size()
	var squad_id: String = q.id
	var men: int = q.men
	s.save()
	s.dispose()
	var d := Session.read_save(PATH)
	check(d.get("sim") is Dictionary, "the save has a sim section")
	var t := Session.load_or_new(PATH, _opts())
	_quiet(t)
	check_eq(t.time, 1234.0, "the clock carries on")
	var ta: Dictionary = t.stash_net.get_stash(stash_a.id)
	check_eq(ta.heat, 33.0, "the stash is as warm")
	check_eq(ta.intel, 12.5, "and as watched")
	check(t.stash_net.get_stash(stash_b.id).burned, "a burned stash stays burned")
	check_eq(t.logistics.stock[stash_a.id].grass, 120.0, "the product is still in the stash")
	check_eq(t.logistics.cash[stash_a.id], 5000, "and the cash")
	check_eq(t.payroll.workers.size(), workers_before, "the same crew")
	var lw: Dictionary = t.payroll.get_worker(lk)
	check(lw.status == "assigned" and lw.assigned == "stash-" + stash_a.id, "the lookout still watches his stash")
	var dw: Dictionary = t.payroll.get_worker(driver)
	check(dw.status == "free" and dw.assigned == "", "the driver's truck is gone: he is free")
	check_eq(t.police.case("runner").suspicion, 41.0, "the task force's file")
	var orgs := t.ground.of("org")
	check_eq(orgs.size(), 1, "one organisation squad, not two")
	var tq: GroundWar.Squad = orgs[0]
	check(tq.id == squad_id and tq.men == men, "the same squad: %s with %d men" % [tq.id, tq.men])
	check(t.payroll.squads.has(squad_id), "and its men are still on the payroll")
	check_eq(t.ground.of("rival").size(), 0, "no rival squad was out when it was saved, so none is raised on the load")
	check_eq(t.ground.of("police").size(), 0, "and none of the task force's")
	# and the game goes on: ten minutes with no script error
	for i in 600:
		t.update(1.0)
	check(t.payroll.workers.size() > 0, "ten minutes later the crew is still there")
	t.dispose()


func test_a_court_case_survives_a_save() -> void:
	var o := _opts()
	o["save_path"] = PATH
	var s := Session.new(o)
	_quiet(s)
	s.update(1.0 / 30)
	s.money = 30000
	var jid := Jobs.new_id()
	s.active_jobs.append(Jobs.Job.new(jid, "a load", "contraband", "HAR", "FRM", [Jobs.item("Unmarked crate", "cargo", 200.0, jid, {"hot": true})], 5000))
	s._bust("forced down by police")
	check(s.court.case_ != null, "a case is open")
	var id: String = str(s.court.case_.id)
	var charges: Array = s.court.case_.charges.duplicate()
	s.save()
	s.dispose()
	var t := Session.load_or_new(PATH, _opts())
	check(t.court.case_ != null, "the case is still open")
	check_eq(str(t.court.case_.id), id, "the same case")
	check_eq(t.court.case_.charges, charges, "the same charges")
	check_eq(t.court.stage(), "bail", "waiting on bail")
	t.dispose()


func test_an_older_save_with_no_sim_section_loads_as_before() -> void:
	var o := _opts()
	o["save_path"] = PATH
	var s := Session.new(o)
	s.save()
	s.dispose()
	var d := Session.read_save(PATH)
	d.erase("sim")
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	var t := Session.load_or_new(PATH, _opts())
	check_eq(t.time, 0.0, "a fresh clock")
	check(t.payroll != null and t.ground != null, "the systems are there, as at a new game")
	t.dispose()


func _world_opts() -> Dictionary:
	var o := _opts()
	o.merge({"family": true, "island": true, "agency": true, "chronicle": true, "rackets": true, "renown": true, "races": true}, true)
	return o


func test_the_rest_of_the_world_survives_a_save() -> void:
	var o := _world_opts()
	o["save_path"] = PATH
	var s := Session.new(o)
	_quiet(s)
	s.update(1.0 / 30)
	s.time = 5000.0
	s.family.respect = 71.0
	s.family.loans_taken = 2
	s.family.loan = {"amount": 5000, "owed": 6000, "due": 9000.0, "honest": true}
	s.family.offers.append({"id": "o1", "kind": "loan", "text": "A friend", "cost": 300, "amount": 5000, "read": "", "honest": true, "expires": 6000.0})
	s.family.knows["HAR-1"] = true
	s.trade.stock["cocaine"] = 55.5
	s.trade.earned = 1234
	s.trade.bulk_log.append([4000.0, "marina", "cocaine", 10.0])
	s.econ.scarcity["cocaine"] = 0.4
	s.econ.law_kit = 3
	s.econ.events.append({"good": "cocaine", "mult": 1.5, "until": 8000.0, "text": "A shortage"})
	s.econ.market.supply["cocaine"] = s.econ.market.supply.get("cocaine", {})
	s.island.relations = 33.0
	s.island.delivered = 7
	s.island.shipments.append({"id": "M1", "method": "mules", "n": 4, "lb": 40, "cost": 2000, "value": 8000, "eta": 7000.0, "p": 0.8, "mules": 4})
	s.agency.trust = 55.0
	s.agency.quashed = 2
	s.chronicle.fired["opening"] = 100.0
	s.arsenals["org"].stock["rifle"] = 6
	s.arsenals["org"].ammo = 777
	s.rackets.rounds = 4
	s.rackets.ransomed = 2
	s.rackets.ransom_cash = 9000
	s.rackets.held = 3
	var rq = s.ground.recruit("rival", "car", Vector2(1200.0, -800.0), false)
	check(rq is GroundWar.Squad, "a rival squad out on the road")
	var rid: String = rq.id
	var pq = s.ground.recruit("police", "car", Vector2(-300.0, 450.0), false)
	check(pq is GroundWar.Squad, "and a task-force car")
	s.ground.commanders["rival"].cash = 1234.0
	s.ground.lost_men["org"] = 3
	s.ground.fights_total = 9
	s.ground.control["town"]["org"] = 2.5
	s.save()
	s.dispose()
	var t := Session.load_or_new(PATH, _world_opts())
	_quiet(t)
	check_eq(t.time, 5000.0, "the clock")
	check_eq(t.family.respect, 71.0, "the Family's regard")
	check_eq(t.family.loans_taken, 2, "and its count of loans")
	check_eq(t.family.loan.owed, 6000, "the loan we owe")
	check_eq(typeof(t.family.loan.owed), TYPE_INT, "as a whole number")
	check_eq(typeof(t.family.offers[0].cost), TYPE_INT, "an offer's price too")
	check(t.family.knows.has("HAR-1"), "what the Family has learned")
	check_eq(t.trade.stock["cocaine"], 55.5, "the product stock")
	check_eq(t.trade.earned, 1234, "what the trade has made")
	check_eq(typeof(t.trade.earned), TYPE_INT, "a whole number")
	check_eq(t.trade.bulk_log.size(), 1, "the bulk buyers' log")
	check_eq(t.econ.scarcity["cocaine"], 0.4, "the economy's scarcity")
	check_eq(t.econ.law_kit, 3, "the task force's kit")
	check_eq(t.econ.events.size(), 1, "the price events")
	check_eq(t.island.relations, 33.0, "the General's regard")
	check_eq(t.island.delivered, 7, "the island's deliveries")
	check_eq(typeof(t.island.shipments[0].n), TYPE_INT, "a shipment's mules are a count")
	check_eq(t.agency.trust, 55.0, "the Company's trust")
	check_eq(t.agency.quashed, 2, "and what it has quashed")
	check(t.chronicle.fired.has("opening"), "the news the chronicle has already run")
	check_eq(t.arsenals["org"].stock["rifle"], 6, "the armoury")
	check_eq(typeof(t.arsenals["org"].stock["rifle"]), TYPE_INT, "in whole guns")
	check_eq(t.arsenals["org"].ammo, 777, "and its rounds")
	check_eq(t.rackets.rounds, 4, "the rackets' rounds")
	check_eq(t.rackets.ransomed, 2, "the ransoms")
	check_eq(t.rackets.ransom_cash, 9000, "and what they paid")
	check_eq(t.rackets.held, 3, "the prisoners still held")
	var rivals := t.ground.of("rival")
	check_eq(rivals.size(), 1, "the one rival squad, not a fresh deployment")
	check(rivals[0].id == rid and absf(rivals[0].x - 1200.0) < 0.01 and absf(rivals[0].y + 800.0) < 0.01, "where it was: %s at (%.0f, %.0f)" % [rivals[0].id, rivals[0].x, rivals[0].y])
	check_eq(t.ground.of("police").size(), 1, "and the task-force car")
	check_eq(t.ground.commanders["rival"].cash, 1234.0, "Los Cuervos' war chest")
	check_eq(t.ground.lost_men["org"], 3, "the war's cost")
	check_eq(typeof(t.ground.lost_men["org"]), TYPE_INT, "in whole men")
	check_eq(t.ground.fights_total, 9, "the fights fought")
	check_eq(t.ground.control["town"]["org"], 2.5, "who holds the streets")
	t.dispose()


func test_a_loaded_world_plays_on_without_errors() -> void:
	var o := _world_opts()
	o["save_path"] = PATH
	var s := Session.new(o)
	s.update(1.0 / 30)
	for i in 900:
		s.update(1.0)
	s.save()
	s.dispose()
	var t := Session.load_or_new(PATH, _world_opts())
	for i in 1800:
		t.update(1.0)
	check(t.time > 2600.0, "half an hour on after the load: t=%.0f" % t.time)
	check(t.family != null and t.island != null and t.trade != null, "every system still there")
	t.dispose()


func _hq_opts() -> Dictionary:
	var o := _world_opts()
	o["features"] = Session.SANDBOX_FEATURES + ["hq"]
	return o


func test_the_hq_season_survives_a_save() -> void:
	var o := _hq_opts()
	o["save_path"] = PATH
	var s := Session.new(o)
	_quiet(s)
	s.update(1.0 / 30)
	check(s.nights != null, "the Organisation layer is on")
	var ss: HQ.Season = s.nights.season
	ss.night = 4
	ss.org.heat = 33.5
	ss.org.fronts.append(HQ.FRONTS.keys()[1])
	ss.org.bribes["sheriff"] = true
	ss.org.crews = 2
	ss.law.support = 61.0
	ss.law.informants = 3
	ss.history.append({"night": 3, "dirty": 12000})
	ss.sightings.append("west")
	ss.runner_log.append("a line")
	check(ss.rival != null, "the rival cartel is in")
	ss.rival.strength = 77.0
	ss.rival.grudge = 2
	for i in 5:
		ss.rng.random()
		ss.rrng.random()
	var rng_state: Array = ss.rng.get_state()
	var rrng_state: Array = ss.rrng.get_state()
	var f_sky: String = ss.forecast.get("sky", "")
	s.save()
	s.dispose()
	var t := Session.load_or_new(PATH, _hq_opts())
	_quiet(t)
	var ts: HQ.Season = t.nights.season
	check_eq(ts.night, 4, "the night")
	check_eq(ts.org.heat, 33.5, "the organisation's heat")
	check(ts.org.bribes.has("sheriff"), "the bribes")
	check_eq(ts.org.crews, 2, "tonight's crews")
	check_eq(typeof(ts.org.crews), TYPE_INT, "a whole number")
	check_eq(ts.law.support, 61.0, "the task force's support")
	check_eq(ts.law.informants, 3, "and its informants")
	check_eq(ts.history.size(), 1, "the season so far")
	check_eq(ts.sightings, ["west"], "the sightings")
	check_eq(ts.runner_log, ["a line"], "the log")
	check_eq(ts.rival.strength, 77.0, "Los Cuervos' strength")
	check_eq(ts.rival.grudge, 2, "and their grudge")
	check_eq(typeof(ts.rival.grudge), TYPE_INT, "in whole nights")
	check_eq(ts.rng.get_state(), rng_state, "the season's dice carry on where they were")
	check_eq(ts.rrng.get_state(), rrng_state, "and the rival's")
	check_eq(ts.forecast.get("sky", ""), f_sky, "tonight's forecast")
	check_eq(t.nights.phase, "planning", "back at planning")
	for i in 300:
		t.update(1.0)
	check(t.nights.season.phase != "", "five minutes on, no errors")
	t.dispose()


func test_save_vars_round_trips_through_json() -> void:
	var holder := Squad2.new()
	holder.n = 5
	holder.f = 2.5
	holder.b = true
	holder.s = "x"
	holder.v = Vector2(3.0, -4.0)
	holder.d = {"cost": 7, "when": 1.5, "inner": [{"cost": 9, "keep": 2.0}]}
	var keys := ["n", "f", "b", "s", "v", "d"]
	var saved: Dictionary = SaveVars.through_json(SaveVars.capture(holder, keys))
	var back := Squad2.new()
	SaveVars.restore(back, saved, keys, ["cost"])
	check_eq(back.n, 5, "an int")
	check_eq(typeof(back.n), TYPE_INT, "stays an int")
	check_eq(back.f, 2.5, "a float")
	check(back.b, "a bool")
	check_eq(back.s, "x", "a string")
	check_eq(back.v, Vector2(3.0, -4.0), "a Vector2 comes back as one")
	check_eq(typeof(back.d.cost), TYPE_INT, "a key named in ints is an int")
	check_eq(typeof(back.d.inner[0].cost), TYPE_INT, "even when nested in an array")
	check_eq(typeof(back.d.when), TYPE_FLOAT, "and the others are left alone")
	var half := Squad2.new()
	half.n = 99
	SaveVars.restore(half, {"f": 1.0}, keys)
	check_eq(half.n, 99, "a property missing from the save keeps its value")


class Squad2:
	var n := 0
	var f := 0.0
	var b := false
	var s := ""
	var v := Vector2.ZERO
	var d := {}
