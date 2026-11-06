extends TestCase
## The case files on the stash houses (DESIGN §48, owner 18 Oct): lead, surveillance, warrant and the raid on timers instead
## of a hidden roll; lying low drops a case; an emptied stash is raided for nothing; a lawyer can throw out a warrant.

var _sess: Session


func after_each() -> void:
	Investigation.ENABLED = true
	if _sess != null:
		_sess.dispose()
		_sess = null


func _net() -> StashNet:
	return StashNet.new([{"id": "a", "name": "the Quarry shed", "x": 0.0, "y": 0.0, "strip": "QRY", "zone": "west"}], PyRandom.new())


func test_a_hot_stash_moves_from_lead_to_surveillance_to_warrant_to_the_raid() -> void:
	var net := _net()
	var inv := Investigation.new()
	net.get_stash("a").heat = 60.0
	check(inv.update(0.0, net).is_empty(), "no raid out of the blue")
	check_eq(inv.stage_of("a"), "lead", "a known stash is a lead")
	inv.update(Investigation.SURVEIL_AFTER_S, net)
	check_eq(inv.stage_of("a"), "surveillance", "still hot: a stakeout")
	var t := Investigation.SURVEIL_AFTER_S + Investigation.WARRANT_AFTER_S
	inv.update(t, net)
	check_eq(inv.stage_of("a"), "warrant", "then a warrant")
	check(inv.update(t + Investigation.WARRANT_S - 1.0, net).is_empty(), "the raid waits for the warrant's countdown")
	check_eq(inv.update(t + Investigation.WARRANT_S, net), ["a"], "and goes in when it runs out")


func test_lying_low_drops_the_case_under_surveillance() -> void:
	var net := _net()
	var inv := Investigation.new()
	net.get_stash("a").heat = 60.0
	inv.update(0.0, net)
	inv.update(Investigation.SURVEIL_AFTER_S, net)
	net.get_stash("a").heat = Investigation.DROP_LINE - 1.0
	inv.update(Investigation.SURVEIL_AFTER_S + 60.0, net)
	check_eq(inv.stage_of("a"), "", "the stash cooled: the case went cold")
	check(inv.events.any(func(e): return e[0] == "dropped"), "and says so")


func test_a_lawyer_can_throw_out_a_warrant() -> void:
	var net := _net()
	var inv := Investigation.new()
	net.get_stash("a").heat = 60.0
	inv.update(0.0, net)
	inv.update(Investigation.SURVEIL_AFTER_S, net)
	inv.update(Investigation.SURVEIL_AFTER_S + Investigation.WARRANT_AFTER_S, net)
	var thrown := false
	for i in 20:  # a 70% chance a try for the best lawyer: twenty tries all failing would be a broken roll
		if inv.challenge("a", 3, 1000.0):
			thrown = true
			break
	check(thrown, "the best lawyer gets a warrant thrown out")
	check_eq(inv.stage_of("a"), "surveillance", "back to surveillance, not off the hook")
	check(not inv.challenge("a", 3, 1000.0), "only a warrant can be challenged")


func test_the_case_files_survive_a_save() -> void:
	var inv := Investigation.new()
	inv.cases = {"a": {"stage": "warrant", "since": 10.0, "until": 250.0}, "b": {"stage": "nonsense", "since": 0.0, "until": 0.0}}
	var back := Investigation.new()
	back.load_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	check_eq(back.stage_of("a"), "warrant")
	check_near(float(back.cases["a"].until), 250.0, 0.001, "with its countdown")
	check_eq(back.stage_of("b"), "", "a stage it does not know is dropped")


func _game() -> Session:
	_sess = Session.new({"seed": 5, "mode": Roles.SOLO, "map_seed": MapCity.SEED, "features": Session.SANDBOX_FEATURES, "money": 50000,
		"trade": true, "logistics": true})
	_sess.police.frozen = true
	return _sess


func test_in_a_game_an_emptied_stash_is_raided_for_nothing() -> void:
	var s := _game()
	check(s.investigation != null and s.logistics != null, "a sandbox game has the case files and the logistics")
	var st: Dictionary = s.stash_net.live()[0]
	st.heat = 80.0
	for g in s.logistics.stock[st.id]:
		s.logistics.stock[st.id][g] = 0.0
	s.logistics.cash[st.id] = 0.0
	s._raid(st.id)
	check(not st.burned, "an emptied stash is not burned")
	check_eq(float(st.heat), 0.0, "and the raid cools it")


func test_in_a_game_a_hot_stash_opens_a_case_file() -> void:
	var s := _game()
	var st: Dictionary = s.stash_net.live()[0]
	st.heat = 80.0
	s._stash_ai_t = 0.0
	s._update_stashes(1.0)
	check_eq(s.investigation.stage_of(str(st.id)), "lead", "the minute's check opens a lead")


func test_with_the_switch_off_no_case_files_are_opened() -> void:
	Investigation.ENABLED = false
	var s := _game()
	var st: Dictionary = s.stash_net.live()[0]
	st.heat = 80.0
	s._stash_ai_t = 0.0
	s._update_stashes(1.0)
	check(s.investigation.cases.is_empty(), "the old roll runs instead")


func test_the_lawyer_challenges_a_warrant_from_the_game() -> void:
	var s := _game()
	var st: Dictionary = s.stash_net.live()[0]
	var id := str(st.id)
	check(not s.command(Roles.PILOT, "challenge_warrant", {"stash": id})[0], "no warrant, nothing to challenge")
	s.investigation.cases[id] = {"stage": "warrant", "since": s.time, "until": s.time + 240.0}
	var before := s.money
	var r: Array = s.command(Roles.PILOT, "challenge_warrant", {"stash": id})
	check(r[0], "the lawyer goes to the judge: %s" % [r])
	check_eq(s.money, before - Investigation.CHALLENGE_FEE, "for his fee")
	check(s.investigation.stage_of(id) in ["warrant", "surveillance"], "the warrant stands or goes back to surveillance")


func test_a_known_tail_number_heats_up_and_cools_in_a_hangar() -> void:
	var inv := Investigation.new()
	check_near(inv.tail_mult("c172p"), 1.0, 0.001, "a clean aircraft")
	var m := inv.update_tail(15 * 60.0, "c172p", true, false, false, false)
	check(m > 1.25, "fifteen minutes wanted: its sightings count for more (%.2f)" % m)
	check(inv.events.any(func(e): return e[0] == "tail_known"), "and the player hears the tail number is known")
	var parked := inv.update_tail(5 * 60.0, "c172p", false, false, true, false)
	var hangar := Investigation.new()
	hangar.tail_heat = {"c172p": inv.tail_heat["c172p"] + 5.0 * Investigation.TAIL_PARKED_MIN}
	var in_hangar := hangar.update_tail(5 * 60.0, "c172p", false, false, true, true)
	check(in_hangar < parked, "a hangar cools it faster than a ramp")
	var wanted_parked := Investigation.new()
	wanted_parked.tail_heat = {"c172p": 20.0}
	wanted_parked.update_tail(60.0, "c172p", true, false, true, true)
	check_near(wanted_parked.tail_heat["c172p"], 20.0 - Investigation.TAIL_HANGAR_MIN, 0.001,
		"a wanted aircraft still cools while parked in a hangar")
	check_near(inv.tail_mult("pa28"), 1.0, 0.001, "another aircraft is clean")


func test_in_a_game_flying_wanted_makes_the_police_count_sightings_higher() -> void:
	var s := _game()
	s.police.case("runner").wanted = 1
	s.phase = "flying"
	for i in 20:
		s._update_stashes(60.0)
	check(s.police.tail_heat_mult > 1.2, "the police know the aircraft (%.2f)" % s.police.tail_heat_mult)


func test_a_hot_district_makes_roadblocks_likelier_and_cools() -> void:
	var inv := Investigation.new()
	check_eq(inv.district_risk("west"), 0.0, "a quiet district adds nothing")
	inv.heat_district("west", Investigation.DISTRICT_RAIDED)
	inv.heat_district("west", Investigation.DISTRICT_SEIZED)
	check_near(inv.district_risk("west"), 40.0 / 400.0, 0.0001, "a raid and a seizure: +0.10 on the roadblock odds")
	check_eq(inv.district_risk("north"), 0.0, "next door is quiet")
	inv.cool_districts(20 * 60.0)
	check_near(float(inv.district_heat["west"]), 30.0, 0.001, "it cools half a point a minute")
	var back := Investigation.new()
	back.load_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	check_near(float(back.district_heat["west"]), 30.0, 0.001, "and is saved")


func test_in_a_game_a_raid_heats_its_district() -> void:
	var s := _game()
	var st: Dictionary = s.stash_net.live()[0]
	st.heat = 80.0
	s.logistics.stock[st.id]["cocaine"] = 10.0
	s._raid(st.id)
	check(st.burned, "the raid went in")
	check(s.investigation.district_risk(str(st.zone)) > 0.0, "and the district is hotter")


## Heat step 2 (DESIGN §48): with the street war on, the case files still run, and the war's police raid only a stash whose
## warrant has run out (no instant raid, no hidden 55 line); their stakeout cars go to the houses under surveillance.
func _war() -> Session:
	var s := Session.new({"seed": 3, "map_seed": MapCity.SEED, "location": "QRY", "features": Session.SANDBOX_FEATURES,
		"ground_war": true})
	s.police.frozen = true
	s.ground._started = true
	for f in s.ground.commanders:
		s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	for q in s.ground.squads.duplicate():  # nobody about but the squads the test places
		s.ground.squads.erase(q)
	return s


func _cops(g: GroundWar, at: Vector2) -> void:
	for kind in ["foot", "foot", "car"]:
		var q = g.recruit("police", kind, at, false)
		q.morale = 0.8
		q.state = "holding"


func test_in_the_street_war_the_police_raid_on_a_warrant_not_on_heat() -> void:
	_sess = _war()
	var g := _sess.ground
	var st: Dictionary = _sess.stash_net.live()[0]
	var id := str(st.id)
	st.heat = 80.0
	_cops(g, Vector2(float(st.x) + 2000.0, float(st.y)))
	g._think_police()
	check(not g.squads.any(func(q): return q.order.get("type", "") == "raid"), "a hot house with no warrant is not raided")
	g.warrants = [id]
	g._think_police()
	var raid = g.squads.filter(func(q): return q.order.get("type", "") == "raid")
	check(raid.size() == 1 and str(raid[0].order.stash) == id, "a warrant that ran out sends a raid team to that house")
	check_eq(g.warrants, [id], "the warrant stays queued while the team is on its way (Codex, #508: orders are not saved)")
	g._think_police()
	check_eq(g.squads.filter(func(q): return q.order.get("type", "") == "raid").size(), 1, "and is not sent twice")


func test_in_the_street_war_the_files_run_and_queue_the_warrant() -> void:
	_sess = _war()
	var st: Dictionary = _sess.stash_net.live()[0]
	var id := str(st.id)
	_sess.investigation.cases[id] = {"stage": "warrant", "since": 0.0, "until": _sess.time}
	_sess._stash_ai_t = 0.0
	_sess.update(1.0)
	check_eq(_sess.ground.warrants, [id], "the files tick with the war on, and the ran-out warrant waits for the war's police")
	check(not st.burned, "no instant raid")


func test_in_the_street_war_stakeouts_follow_the_surveillance_stage() -> void:
	_sess = _war()
	var g := _sess.ground
	var live: Array = _sess.stash_net.live()
	var watched: Dictionary = live[0]
	var warm: Dictionary = live[1]
	watched.heat = 46.0
	warm.heat = 30.0  # warm enough for the old 10-55 band, but no case file
	_sess.investigation.cases[str(watched.id)] = {"stage": "surveillance", "since": 0.0, "until": 0.0}
	_cops(g, Vector2(float(watched.x) + 1500.0, float(watched.y)))
	g._think_police()
	check(g.stakeouts.has(str(watched.id)) or g.stakeouts.has(watched.id), "the house under surveillance gets the stakeout car")
	check(not g.stakeouts.has(str(warm.id)) and not g.stakeouts.has(warm.id), "a warm house without a case does not")


func test_the_queued_warrants_survive_a_save() -> void:
	_sess = _war()
	_sess.ground.warrants = [str(_sess.stash_net.live()[0].id)]
	var d: Dictionary = SaveVars.through_json(StrategicSave.capture(_sess))
	var t := _war()
	StrategicSave.restore(t, d)
	check_eq(t.ground.warrants, _sess.ground.warrants, "the queue comes back")
	t.dispose()



## Codex review (#508): a save while the raid team is on its way keeps the warrant, and the reload sends a team again.
func test_a_save_mid_approach_keeps_the_warrant() -> void:
	_sess = _war()
	var g := _sess.ground
	var st: Dictionary = _sess.stash_net.live()[0]
	var id := str(st.id)
	_cops(g, Vector2(float(st.x) + 2000.0, float(st.y)))
	g.warrants = [id]
	g._think_police()
	check(g.squads.any(func(q): return q.order.get("type", "") == "raid"), "the team set out")
	var d: Dictionary = SaveVars.through_json(StrategicSave.capture(_sess))
	var t := _war()
	StrategicSave.restore(t, d)
	check_eq(t.ground.warrants, [id], "the reloaded game still has the warrant")
	t.dispose()
