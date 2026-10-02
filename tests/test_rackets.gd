extends TestCase
## The rackets: tribute from the streets we hold (with a squeeze), and the prisoners our squads take.


func after_each() -> void:
	Rackets.ENABLED = true
	World.use_map(0)


func _war(opts := {}) -> Session:
	var o := {"seed": 3, "map_seed": MapCity.SEED, "location": "QRY", "features": Session.SANDBOX_FEATURES,
		"ground_war": true, "rackets": true, "payroll": true, "renown": true}
	o.merge(opts, true)
	var s := Session.new(o)
	s.police.frozen = true
	s.ground._started = true
	for f in s.ground.commanders:
		s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	return s


func _hold(s: Session, m: String, org: float, rival := 0.0) -> void:
	s.ground.control[m] = {"org": org, "rival": rival, "police": 0.0}


func _squad(s: Session, f: String, men: int) -> GroundWar.Squad:
	var q = s.ground.recruit(f, "foot", Vector2(100, 100), false)
	s.ground.arsenal(f).give_back(q.loadout)
	q.loadout = {"rifle": men}
	q.men = men
	q.men0 = men
	q.ammo = men * 90
	q.morale = 0.8
	q.state = "holding"
	return q


func test_only_with_a_ground_war_and_when_asked() -> void:
	var s := _war()
	check(s.rackets != null, "there when asked")
	s.dispose()
	s = _war({"rackets": false})
	check(s.rackets == null, "not unless asked")
	s.dispose()
	s = Session.new({"seed": 3, "map_seed": MapCity.SEED, "location": "QRY", "features": Session.SANDBOX_FEATURES, "rackets": true})
	check(s.rackets == null, "and not without a ground war")
	s.dispose()


func test_a_street_we_hold_pays_and_one_we_do_not_does_not() -> void:
	var s := _war()
	var r: Rackets = s.rackets
	_hold(s, "town", 100.0)  # all ours
	_hold(s, "west", 60.0, 40.0)  # 60%
	_hold(s, "north", 40.0, 60.0)  # 40%: theirs
	check_eq(r.expected("town"), int(Rackets.TRIBUTE_BASE), "full control: the base")
	check_eq(r.expected("west"), int(Rackets.TRIBUTE_BASE * 0.2), "60 percent: a fifth of it")
	check_eq(r.expected("north"), 0, "under half: nothing")
	check_eq(r.expected("sea"), 0, "no presence: nothing")
	var m0 := s.money
	var got := r.collect()
	check_eq(got, int(Rackets.TRIBUTE_BASE) + int(Rackets.TRIBUTE_BASE * 0.2), "the round")
	check_eq(s.money, m0 + got, "in the safe")
	check_eq(r.collected, got, "and counted")
	check(s.messages.any(func(m): return str(m[1]).contains("TRIBUTE")), "and said")
	s.dispose()


func test_squeezing_pays_more_and_the_street_resents_it() -> void:
	var s := _war()
	var r: Rackets = s.rackets
	_hold(s, "town", 100.0)
	var fair := r.expected("town")
	check_eq(r.set_policy("town", "squeeze"), "", "squeeze it")
	check_eq(r.expected("town"), int(Rackets.TRIBUTE_BASE * Rackets.SQUEEZE_MULT), "2.2x (%d vs %d)" % [r.expected("town"), fair])
	var c = s.police.case("runner")
	var heat: float = c.suspicion
	r.collect()
	check_near(s.ground.control["town"]["org"], 85.0, 0.001, "our hold drops by 15%")
	check_near(c.suspicion, heat + Rackets.SQUEEZE_HEAT, 0.001, "and the case warms")
	r.set_policy("town", "off")
	check_eq(r.expected("town"), 0, "off pays nothing")
	check(r.set_policy("nowhere", "fair") != "", "no such market")
	check(r.set_policy("town", "gentle") != "", "no such policy")
	s.dispose()


func test_the_collectors_come_every_ten_minutes_and_a_name_pays_more() -> void:
	var s := _war()
	var r: Rackets = s.rackets
	_hold(s, "town", 100.0)
	var m0 := s.money
	r.update(Rackets.TRIBUTE_EVERY_S - 1.0)
	check_eq(s.money, m0, "not yet")
	r.update(2.0)
	check_eq(s.money, m0 + int(Rackets.TRIBUTE_BASE), "the round came")
	s.renown.score = 650.0
	s.renown.apply()
	check_eq(r.expected("town"), int(roundf(Rackets.TRIBUTE_BASE * 1.06)), "a legend is paid 6 percent more")
	s.dispose()


func test_a_third_of_a_beaten_squad_is_taken() -> void:
	var s := _war()
	var r: Rackets = s.rackets
	var foe := _squad(s, "rival", 10)
	foe.men = 7
	check_eq(r.capture(foe), 2, "7 left: 2 taken")
	check_eq(foe.men, 5, "and gone from the squad")
	check_eq(r.held, 2, "held")
	var tiny := _squad(s, "rival", 3)
	check_eq(r.capture(tiny), 0, "three men: nobody is taken")
	s.dispose()


func test_winning_a_fight_takes_prisoners() -> void:
	var s := _war()
	var g: GroundWar = s.ground
	var a := _squad(s, "org", 14)
	var b := _squad(s, "rival", 14)
	b.loadout = {"pistol": 14}
	b.x = 130.0
	b.y = 100.0
	g._open(a, b)
	for i in 120:
		g._rounds(GroundWar.ROUND_S)
		if a.fight == null or b.fight == null:
			break
	check(b.state in ["routed", "gone"] or b.men <= 0, "the rival lost (%s, %d men)" % [b.state, b.men])
	check(s.rackets.taken > 0, "and some of them were taken (%d)" % s.rackets.taken)
	s.dispose()


func test_ransom_pays_what_the_cartel_has() -> void:
	var s := _war()
	var r: Rackets = s.rackets
	r.held = 4
	s.ground.commanders.rival.cash = 10000.0
	var m0 := s.money
	check_eq(r.ransom(), "", "ransomed")
	check_eq(s.money, m0 + 4 * Rackets.RANSOM_EACH, "$350 a head")
	check_eq(r.held, 0, "none left")
	check_near(s.ground.commanders.rival.cash, 10000.0 - 4 * Rackets.RANSOM_EACH, 0.01, "and they paid for it")
	check(r.ransom() != "", "nothing to ransom now")
	r.held = 4
	s.ground.commanders.rival.cash = 500.0
	m0 = s.money
	r.ransom()
	check_eq(s.money, m0 + 500, "a broke cartel pays what it has")
	s.dispose()


func test_turned_prisoners_join_the_payroll_and_released_ones_make_a_name() -> void:
	var s := _war()
	var r: Rackets = s.rackets
	var soldiers := s.payroll.of("org", "soldier").size()
	r.held = 3
	check_eq(r.turn(), "", "turned")
	var now: Array = s.payroll.of("org", "soldier")
	check_eq(now.size(), soldiers + 3, "three more soldiers")
	var ids := {}
	for w in now:
		ids[w.id] = true
	check_eq(ids.size(), now.size(), "with their own ids")
	var w = now[now.size() - 1]
	check(float(w.loyalty) < 0.35 and w.status == "free" and int(w.wage) > 0, "disloyal, free, paid: %s" % [w])
	r.held = 4
	var before: float = s.renown.score
	check_eq(r.release(), "", "let go")
	check_near(s.renown.score, before + 2.0, 0.001, "half a point of name a man")
	check_eq(r.held, 0, "none held")
	s.dispose()


func test_a_few_get_away_in_the_night() -> void:
	var s := _war()
	var r: Rackets = s.rackets
	r.held = 17
	r.update(Rackets.ESCAPE_EVERY_S + 1.0)
	check_eq(r.held, 15, "17 // 8 = 2 got away")
	check_eq(r.escaped, 2, "counted")
	r.held = 7
	r.update(Rackets.ESCAPE_EVERY_S + 1.0)
	check_eq(r.held, 7, "a small group is guarded")
	s.dispose()


func test_the_boss_orders_it_and_it_survives_a_save() -> void:
	var s := _war()
	check(Roles.allowed(Roles.BOSS, "rackets") and Roles.allowed(Roles.PILOT, "rackets"), "boss and pilot may")
	var r: Array = s.command(Roles.BOSS, "rackets", {"what": "policy", "market": "west", "mode": "squeeze"})
	check(r[0], "policy by command: %s" % [r])
	check_eq(s.rackets.policy.west, "squeeze", "set")
	check(not s.command(Roles.BOSS, "rackets", {"what": "dance"})[0], "an unknown order")
	check(not s.command(Roles.BOSS, "rackets", {"what": "ransom"})[0], "and no prisoners to ransom")
	s.rackets.held = 5
	var d := StrategicSave.capture(s)
	var t := _war()
	StrategicSave.restore(t, JSON.parse_string(JSON.stringify(d)))
	check_eq(t.rackets.policy.west, "squeeze", "the policy survives")
	check_eq(t.rackets.held, 5, "and so do the prisoners")
	s.dispose()
	t.dispose()
