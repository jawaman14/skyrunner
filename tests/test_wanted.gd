extends TestCase
## Wanted names (D-95): one squad in three Los Cuervos or the task force raises is led by a name; beating him is a take-down with
## a stated 1 in ODDS chance of his one prize; until it drops he gets away and leads again.


func _war() -> Session:
	var s := Session.new({"seed": 3, "map_seed": MapCity.SEED, "location": "QRY",
		"features": Session.SANDBOX_FEATURES, "ground_war": true})
	s.police.frozen = true
	s.ground._started = true
	for f in s.ground.commanders:
		s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	return s


func _raise(g: GroundWar, f: String):
	return g.recruit(f, "foot", g.hq(f), false)


func test_one_in_three_is_led_by_a_name() -> void:
	var s := _war()
	var field := []  # the squads in the field, as assign() sees them
	var leaders := []
	for i in Wanted.EVERY * 2:
		var q := GroundWar.Squad.new()
		q.state = "holding"
		q.leader = s.wanted.assign("rival", field)
		field.append(q)
		leaders.append(q.leader)
	check_eq(leaders.filter(func(l): return l != "").size(), 2, "two names in six squads: %s" % [leaders])
	check(leaders[Wanted.EVERY - 1] != "", "the third")
	check(leaders[Wanted.EVERY - 1] != leaders[Wanted.EVERY * 2 - 1], "two different men: one is already in the field")
	check(Wanted.entry(leaders[Wanted.EVERY - 1]).outfit == "rival", "a Los Cuervos name for a Los Cuervos squad")
	check_eq(s.wanted.assign("org", field), "", "the organisation's squads have none")
	s.dispose()


func test_a_real_raise_carries_the_name() -> void:
	var s := _war()
	var q = null
	for i in Wanted.EVERY:
		q = _raise(s.ground, "rival")
	check(q is GroundWar.Squad and q.leader != "", "the third squad raised is led by a name: %s" % [q])
	s.dispose()


func test_first_contact_shows_his_card_once() -> void:
	var s := _war()
	s.wanted.contact("tuerto")
	s.wanted.contact("tuerto")
	var cards := s.bus.log.filter(func(e): return e.kind == "wanted_seen")
	check_eq(cards.size(), 1, "one card")
	check("Salcedo" in cards[0].text, cards[0].text)
	s.dispose()


func test_a_takedown_rolls_for_the_prize_and_he_comes_back_until_it_drops() -> void:
	var s := _war()
	var got := false
	for i in 30:
		s.wanted.taken_down("flaca")
		if s.wanted.done.has("flaca"):
			got = true
			break
	check(got, "1 in 3 lands within 30 tries")
	var escapes := s.bus.log.filter(func(e): return e.kind == "wanted_escaped").size()
	check_eq(int(s.wanted.takedowns.flaca), escapes + 1, "every miss is an escape, then the prize")
	check(s.bus.log.any(func(e): return e.kind == "wanted_prize" and e.data.id == "flaca"), "the prize, on the bus")
	var before := s.bus.log.size()
	s.wanted.taken_down("flaca")
	check_eq(s.bus.log.size(), before, "finished: nothing more")
	s.dispose()


func test_the_odds_are_as_stated() -> void:
	var s := _war()
	var hits := 0
	for i in 600:
		if s.wanted.rng.randint(1, Wanted.ODDS) == 1:
			hits += 1
	check_near(hits / 600.0, 1.0 / Wanted.ODDS, 0.06, "about 1 in %d" % Wanted.ODDS)
	s.dispose()


func test_the_prizes_land() -> void:
	var s := _war()
	var org = s.arsenals.get("org")
	var rifles: int = org.stock.get("rifle", 0) if org != null else 0
	s.wanted._grant(Wanted.entry("tuerto").prize)
	if org != null:
		check_eq(int(org.stock.get("rifle", 0)), rifles + 8, "eight rifles to the armoury")
	s.ground.commanders.rival.cash = 20000.0
	var m0 = s.money
	s.wanted._grant(Wanted.entry("flaca").prize)
	check_eq(s.money, m0 + 9000, "the take to the safe")
	check_near(s.ground.commanders.rival.cash, 11000.0, 0.01, "out of Los Cuervos' chest")
	var c = s.police.case("runner")
	c.suspicion = 60.0
	s.wanted._grant(Wanted.entry("rook").prize)
	check_near(c.suspicion, 35.0, 0.01, "his file takes the heat down")
	s.dispose()


func test_a_finished_man_is_not_assigned_again() -> void:
	var s := _war()
	for e in Wanted.ROSTER:
		if e.outfit == "rival":
			s.wanted.done[e.id] = true
	for i in Wanted.EVERY * 2:
		check_eq(s.wanted.assign("rival", []), "", "no names left")
	s.dispose()


func test_routing_a_named_squad_is_a_takedown() -> void:
	var s := _war()
	var g := s.ground
	var them = null
	for i in Wanted.EVERY:
		them = _raise(g, "rival")
	check(them.leader != "", "a named squad")
	var us = _raise(g, "org")
	g._open(us, them)
	check(s.wanted.seen.has(them.leader), "his card at first contact")
	g._rout(them, them.fight)
	check_eq(int(s.wanted.takedowns.get(them.leader, 0)), 1, "a take-down")
	s.dispose()


func test_saved_with_the_game() -> void:
	var s := _war()
	var g := s.ground
	var them = null
	for i in Wanted.EVERY:
		them = _raise(g, "rival")
	s.wanted.done["padrino"] = true
	s.wanted.seen["tuerto"] = true
	var d: Dictionary = SaveVars.through_json(StrategicSave.capture(s))
	var t := Session.new({"seed": 4, "map_seed": MapCity.SEED, "location": "QRY", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	StrategicSave.restore(t, d)
	check(t.wanted.done.has("padrino") and t.wanted.seen.has("tuerto"), "the roster's state")
	check_eq(int(t.wanted.raised.rival), int(s.wanted.raised.rival), "and the count")
	check(t.ground.squads.any(func(q): return q.leader == them.leader), "the squad keeps its leader")
	s.dispose()
	t.dispose()


func test_off_means_no_names() -> void:
	Wanted.ENABLED = false
	var s := _war()
	check(s.wanted == null, "not built")
	for i in Wanted.EVERY:
		check(_raise(s.ground, "rival").leader == "", "nobody named")
	s.dispose()
	Wanted.ENABLED = true


func test_the_prize_rolls_carry_on_after_a_reload() -> void:
	var s := _war()
	s.wanted.taken_down("flaca")
	var d: Dictionary = SaveVars.through_json(StrategicSave.capture(s))
	var next: float = s.wanted.rng.random()
	var t := Session.new({"seed": 3, "map_seed": MapCity.SEED, "location": "QRY", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	StrategicSave.restore(t, d)
	check_eq(t.wanted.rng.random(), next, "the next roll is the one after, not the first again")
	s.dispose()
	t.dispose()


func test_captured_by_the_task_force_is_off_the_roster() -> void:
	var s := _war()
	var g := s.ground
	var them = null
	for i in Wanted.EVERY:
		them = _raise(g, "rival")
	var cop = _raise(g, "police")
	var who: String = them.leader
	g._surrender(them, cop)
	check(s.wanted.done.has(who), "in custody: finished")
	check(not s.wanted.takedowns.has(who), "no take-down, no prize")
	check(s.bus.log.any(func(e): return e.kind == "wanted_captured"), "on the bus")
	s.dispose()


func test_a_save_waits_for_the_war_to_open() -> void:
	var s := _war()
	s.wanted.done["padrino"] = true
	var d: Dictionary = SaveVars.through_json(StrategicSave.capture(s))
	var t := Session.new({"seed": 4, "map_seed": MapCity.SEED, "location": "QRY", "features": Session.SANDBOX_FEATURES})
	check(t.wanted == null, "no war yet (a story opens it after the restore)")
	StrategicSave.restore(t, d)
	t.enable_system("ground_war")
	check(t.wanted != null and t.wanted.done.has("padrino"), "the roster comes back once it opens")
	s.dispose()
	t.dispose()
