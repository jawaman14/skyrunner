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
	check_eq(t.ground.of("rival").size(), 2, "the other sides deployed as at the start")
	check_eq(t.ground.of("police").size(), 3, "all of them")
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
