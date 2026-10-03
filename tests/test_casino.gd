extends TestCase
## The Hotel Cielo: the Family's casino on Isla Soberana. A stake in the house, its take, the cage that washes street cash, the
## General and the rival, the task force's file, and the revolution that ends it; plus the story chapter built on it.

var _sess: Session


class FixedRng extends PyRandom:
	var v := 0.5

	func _init(v_ := 0.5) -> void:
		v = v_

	func random() -> float:
		return v


func after_each() -> void:
	Casino.ENABLED = true
	Casino.REVOLUTION = true
	if _sess != null:
		_sess.dispose()
		_sess = null
	World.use_map(0)


func _session(opts := {}) -> Session:
	var o := {"seed": 41, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "family": true, "island": true, "trade": true,
		"logistics": true, "payroll": true, "casino": true, "money": 100000, "career": false}
	o.merge(opts, true)
	_sess = Session.new(o)
	_sess.police.frozen = true
	_sess.update(1.0 / 30)
	return _sess


func _stash(s: Session) -> String:
	var id: String = s.stash_net.stashes[0].id
	s.logistics.cash[id] = 20000
	return id


func test_it_needs_the_family_and_the_island() -> void:
	var s := _session()
	check(s.casino != null and s.casino.active(), "there with both")
	s.dispose()
	_sess = null
	var t := _session({"family": false})
	check(t.casino == null, "no Family, no house")
	t.dispose()
	_sess = null
	var u := _session({"casino": false})
	check(u.casino == null, "and not unless asked")


func test_a_stake_is_bought_in_tenths_up_to_forty_per_cent() -> void:
	var s := _session()
	var c: Casino = s.casino
	var m: int = s.money
	var r: float = s.family.respect
	check_eq(c.buy_stake(), "", "a tenth")
	check_eq(s.money, m - Casino.STAKE_PRICE, "paid for")
	check(is_equal_approx(c.stake, 0.1) and s.family.respect > r, "10%, and the Family approves")
	for i in 3:
		c.buy_stake()
	check(is_equal_approx(c.stake, Casino.STAKE_MAX), "four tenths at most")
	check(c.buy_stake().contains("as much"), "then no more: %s" % c.buy_stake())
	s.money = 100
	c.stake = 0.0
	check(c.buy_stake().contains("$"), "and it must be paid for")


func test_the_house_pays_the_owners_and_the_generals_skim_follows_his_regard() -> void:
	var s := _session()
	var c: Casino = s.casino
	c.rng = FixedRng.new(0.99)  # no headliners or high rollers tonight
	s.island.relations = 100.0
	check(is_equal_approx(c.skim(), Casino.SKIM_BEST), "a friend of the General pays the least skim")
	s.island.relations = 0.0
	check(is_equal_approx(c.skim(), Casino.SKIM_WORST), "an enemy the most")
	s.island.relations = 50.0
	c.stake = 0.4
	var per_hour := c.share_per_hour()
	var expect := Casino.HOUSE_PER_HOUR * (1.0 - c.skim() - Casino.FAMILY_CUT) * 0.4
	check(absf(per_hour - expect) < 1.0, "our share an hour: $%.0f" % per_hour)
	for i in 360:
		c.update(10.0)  # an hour
		s.time += 10.0
	check(absf(float(c.owed) - per_hour) < per_hour * 0.15, "an hour later about that is owed: $%d" % c.owed)
	var m: int = s.money
	var owed: int = c.owed
	check_eq(c.collect(), "", "collected")
	check_eq(s.money, m + owed, "into the safe")
	check(c.collect().contains("Nothing"), "and then nothing")
	s.island.status = "hurricane"
	check(c.tourism() < 0.5, "a hurricane empties the hotel")


func test_the_cage_washes_street_cash_for_a_fee_up_to_an_hourly_cap() -> void:
	var s := _session()
	var c: Casino = s.casino
	var id := _stash(s)
	var m: int = s.money
	s.island.relations = 50.0
	s.police.case("runner").suspicion = 40.0
	check_eq(c.launder(id, 5000), "", "chips in")
	check(is_equal_approx(s.police.case("runner").suspicion, 40.0 - Casino.CAGE_RELIEF * 5.0), "and the money trail is cleaner: the case cools")
	var cut := int(round(5000.0 * (Casino.CAGE_FAMILY_CUT + c.skim())))
	check_eq(s.money, m + 5000 - cut, "a cheque for the rest")
	check_eq(int(s.logistics.cash[id]), 15000, "out of the stash")
	check_eq(c.laundered, 5000, "counted")
	check(c.heat > 3.0, "the house warms (%.1f)" % c.heat)
	check_eq(c.cage_left(), Casino.CAGE_CAP - 5000, "the cage has less room")
	check_eq(c.launder(id, 20000), "", "more than the room left")
	check_eq(c.cage_left(), 0, "takes only what fits: the cap")
	check(c.launder(id, 1000).contains("full"), "the cage is full for the hour")
	s.time += 3601.0
	check_eq(c.cage_left(), Casino.CAGE_CAP, "and opens again after an hour")
	check(c.launder("nowhere", 1000).contains("no cash"), "no cash there")


func test_the_general_and_the_rival() -> void:
	var s := _session()
	var c: Casino = s.casino
	c.unrest = 50.0
	c.heat = 40.0
	var rel: float = s.island.relations
	check_eq(c.pay_general(), "", "an envelope")
	check(s.island.relations > rel and c.unrest < 50.0 and c.heat < 40.0, "his regard up, the unrest and the heat down")
	c.rival = 80.0
	check_eq(c.buy_out_rival(), "", "bought out")
	check_eq(c.rival, 0.0, "the pressure off")
	check(c.bought_out_until > s.time and c.buy_out_rival().contains("already"), "for six hours")
	c.bought_out_until = -1.0
	c.rival = 100.0
	c._evt_t = 400.0
	c.owed = 10000
	c._events(0.0)
	check(c.closed_until > s.time and c.owed == 9000 and c.rival < 100.0, "an unbought rival burns the kitchens: the house is dark and 10% lighter")
	check(not c.trading(), "dark")


func test_the_task_force_works_the_house() -> void:
	var s := _session()
	var c: Casino = s.casino
	s.law_funds = 20000.0
	check(c.case_action("raid").contains("only"), "no raid without a case: %s" % c.case_action("raid"))
	check_eq(c.case_action("wiretap"), "", "a microphone")
	check(c.case_ == 20.0 and s.law_funds == 20000.0 - Casino.WIRETAP, "the case grows by 20 and costs funds")
	c.case_ = 60.0
	var id := _stash(s)
	check_eq(c.case_action("audit"), "", "an audit")
	check(c.launder(id, 1000).contains("commission"), "the cage is shut: %s" % c.launder(id, 1000))
	c.owed = 10000
	var funds: float = s.law_funds
	check_eq(c.case_action("raid"), "", "and a raid")
	check_eq(c.owed, 6000, "40% of the owners' money forfeited")
	check(s.law_funds > funds - Casino.RAID + 3999, "and it goes to the task force")
	check(c.closed_until > s.time and not c.trading() and c.case_ == 0.0, "the house is dark and the case spent")
	check(c.case_action("sabotage") != "", "only wiretap, audit or raid")
	s.law_funds = 0.0
	check(c.case_action("wiretap").contains("funds"), "and it costs money")


func test_the_ai_chief_works_a_hot_house_by_itself() -> void:
	var s := _session()
	var c: Casino = s.casino
	s.law_funds = 50000.0
	c.heat = 80.0
	c.case_ = 80.0
	var done := false
	for i in 20:
		c._law_t = 1300.0
		c._law_ai(0.0)
		if c.closed_until > s.time or c.audit_until > s.time or c.case_ > 80.0:
			done = true
			break
	check(done, "with the heat up it audits, taps or raids")
	var cold := _session({"seed": 42})
	cold.casino.heat = 5.0
	cold.law_funds = 50000.0
	cold.casino._law_t = 1300.0
	cold.casino._law_ai(0.0)
	check(cold.casino.audit_until < 0.0 and cold.law_funds == 50000.0, "a quiet house is left alone")


func test_unrest_brings_the_revolution_and_you_can_get_out() -> void:
	var s := _session()
	var c: Casino = s.casino
	c.stake = 0.3
	c.owed = 10000
	c.unrest = 100.0
	c.update(10.0)
	check_eq(c.status, "uprising", "the government falls")
	check(s.island.status == "purge" and not s.island.open(), "and the island is closed")
	check(c.buy_stake().contains("shuttered") and c.collect().contains("shuttered"), "the house does no business")
	var m: int = s.money
	var want: int = int(10000.0 * Casino.EVAC_OWED) + int(round(0.3 / Casino.STAKE_STEP * float(Casino.STAKE_PRICE) * Casino.EVAC_STAKE))
	check_eq(c.evacuate(), "", "out on the launch")
	check(absi(s.money - (m + want)) <= 3, "with 70%% of the account and 40%% of the stake: $%d (got +%d)" % [want, s.money - m])
	check(c.status == "seized" and c.stake == 0.0 and c.owed == 0, "the house is seized")
	check_eq(s.island.relations, 25.0, "the new men are cool to us")
	check(c.evacuate().contains("nothing"), "once")


func test_staying_through_the_uprising_loses_everything() -> void:
	var s := _session()
	var c: Casino = s.casino
	c.stake = 0.4
	c.owed = 8000
	c.unrest = 100.0
	c.update(10.0)
	var m: int = s.money
	var respect: float = s.family.respect
	s.time += Casino.UPRISING_S + 1.0
	c.update(10.0)
	check_eq(c.status, "seized", "it falls")
	check(s.money == m and c.owed == 0 and c.stake == 0.0, "with your share inside it")
	check(s.family.respect <= respect - 19.0, "and the Family is not pleased")
	Casino.REVOLUTION = false
	var t := _session({"seed": 43})
	t.casino.unrest = 100.0
	t.casino.update(10.0)
	check_eq(t.casino.status, "open", "with the switch off there is no revolution")


func test_the_story_chapter_runs_from_the_stake_to_the_getaway() -> void:
	var s := _session({"story": false})
	var st := Story.new(6)  # 'The House'
	st.attach(s)
	check_eq(st.chapter.title, "The House", "the chapter")
	check(s.casino != null, "the house opens with it")
	var c: Casino = s.casino
	check_eq(c.buy_stake(), "", "a stake")
	var id := _stash(s)
	s.logistics.cash[id] = 60000
	for i in 3:
		c.launder(id, 8000)
		s.time += 3601.0
	st.tick(s)
	check(st.progress.get("casino_laundered", 0.0) >= 15000.0, "$%d through the cage" % int(st.progress.get("casino_laundered", 0.0)))
	check(c.force_uprising_at > s.time, "the colonels meet: the uprising is set")
	check_eq(st.chapter.title, "The House", "not done yet")
	s.time = c.force_uprising_at + 1.0
	c.update(10.0)
	check_eq(c.status, "uprising", "the revolution")
	c.evacuate()
	st.tick(s)
	check_eq(st.chapter.title, "The Company", "out alive: on to the Company")


func test_the_chapter_does_not_strand_the_story() -> void:
	var s := _session()
	var st := Story.new(6)
	st.attach(s)
	s.family.gone = true
	st.tick(s)
	check_eq(st.chapter.title, "The Company", "the Family gone: the story moves on")
	var old := Story.from_dict({"index": 6, "progress": {}, "done": false})
	check_eq(old.chapter.title, "The Company", "an older save's chapter 7 is still the Company")
	check_eq(Story.from_dict(old.to_dict()).chapter.title, "The Company", "and it round-trips")


func test_the_views_and_permissions() -> void:
	var s := _session()
	var r := s.casino.view("runner")
	for k in ["stake", "owed", "heat", "unrest", "rival", "cage_left", "skim", "stashes", "evac_cash"]:
		check(r.has(k), "the owners see %s" % k)
	var l := s.casino.view("law")
	check(l.has("case") and not l.has("owed") and not l.has("stake"), "the law sees the case and not the owners' books")
	check(Snapshot.build(s, Roles.PILOT).has("casino") and Snapshot.build(s, Roles.CONTROLLER).has("casino"), "both snapshots carry it")
	check(not Snapshot.build(s, Roles.CONTROLLER).casino.has("owed"), "the controller's is the law's view")
	for role in [Roles.PILOT, Roles.FIXER, Roles.BOSS, Roles.LIEUTENANT, Roles.COPILOT]:
		check(Roles.allowed(role, "casino"), "%s can deal with the house" % role)
	for role in [Roles.CONTROLLER, Roles.CHIEF]:
		check(Roles.allowed(role, "casino_case") and not Roles.allowed(role, "casino"), "%s can only work the case" % role)
	check(not s.command(Roles.PILOT, "casino", {"do": "dance"})[0], "an unknown order is refused")
	check(s.command(Roles.PILOT, "casino", {"do": "stake"})[0], "a stake through the command")
	s.law_funds = 9000.0
	check(s.command(Roles.CONTROLLER, "casino_case", {"do": "wiretap"})[0], "a wiretap through the command")


func test_following_the_money_finds_the_cage() -> void:
	var s := _session()
	var id := _stash(s)
	s.casino.launder(id, 8000)
	s.law_funds = 10000.0
	var before: float = s.police.case("runner").suspicion
	check_eq(s.trade.trace(), "", "following the money")
	check(s.police.case("runner").suspicion > before, "the cage's traffic shows in the case")
	check(s.law_log.any(func(m): return str(m[1]).contains("cage")), "and the log says so")


func test_the_phone_and_the_dialogues() -> void:
	var s := _session()
	var phone := PhoneMenu.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(phone)
	phone.setup(s)
	check(phone.contacts().any(func(r): return r[0] == "casino"), "the Hotel Cielo is in the phone book")
	phone.queue_free()
	check(Talk.resource("casino") != null, "Lenny Vance's script compiles")
	check(Talk.resource("casino_file") != null, "and so does the task force's file")
	var link := LocalLink.new(s, Roles.PILOT)
	var st := Talk.State.new(func(): return link.snapshot(), func(n: String, a: Dictionary) -> Array:
		link.send_command(n, a)
		return link.last_result)
	check(st.casino and st.cs_can_buy and st.cs_stake_price == Casino.STAKE_PRICE, "the state reads the house")
	check(st.buy_stake() and st.cs_stake_pct == 10, "and buys through the command: %d%%" % st.cs_stake_pct)
	_stash(s)
	st.refresh()
	check(st.cs_has_cash and st.cs_launder_n == Casino.CAGE_CAP, "the richest stash, up to the cage's room: $%d" % st.cs_launder_n)
	check(st.launder() and s.casino.laundered == Casino.CAGE_CAP, "chips in")


func test_the_fixers_x_rings_the_cielo() -> void:
	var s := _session()
	var app := StationApp.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	app.setup(LocalLink.new(s, Roles.FIXER), Roles.FIXER, s.world)
	app._process(0.016)
	app._key("x")
	check(app.talk != null, "X on the fixer's desk rings the Cielo")
	if app.talk != null:
		app.talk.free()
	app.free()


func test_the_controllers_f_opens_the_casino_file() -> void:
	var s := _session()
	var law := StationApp.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(law)
	law.setup(LocalLink.new(s, Roles.CONTROLLER), Roles.CONTROLLER, s.world)
	law._process(0.016)
	law._key("f")
	check(law.talk != null, "F on the controller's desk opens the casino file")
	if law.talk != null:
		law.talk.free()
	law.free()


func test_a_save_keeps_the_house() -> void:
	var path := "user://test_casino_save.json"
	var s := _session({"save_path": path})
	var c: Casino = s.casino
	c.stake = 0.2
	c.owed = 1234
	c.heat = 33.0
	c.case_ = 41.0
	c.unrest = 55.0
	c.laundered = 9000
	c.cage_log = [[100.0, 5000]]
	s.time = 500.0
	s.save()
	s.dispose()
	_sess = null
	var t := Session.load_or_new(path, {"seed": 41, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "family": true, "island": true,
		"trade": true, "logistics": true, "payroll": true, "casino": true})
	_sess = t
	check(is_equal_approx(t.casino.stake, 0.2) and t.casino.owed == 1234, "the stake and the account")
	check(t.casino.heat == 33.0 and t.casino.case_ == 41.0 and t.casino.unrest == 55.0, "the heat, the case and the unrest")
	check_eq(t.casino.laundered, 9000, "what went through the cage")
	check_eq(typeof(t.casino.owed), TYPE_INT, "in whole dollars")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
