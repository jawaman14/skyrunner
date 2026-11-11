extends TestCase
## The takeover (D-09, D-78, D-35; DESIGN 80): in Cocaine Cowboys Los Cuervos kill Rafa, at their first incident or fifteen minutes
## in; half the stashes (the least known), half the crew, the parked trucks and a quarter of the street cash survive; the desk is
## the player's from then; the pilot's safe is untouched; its own stream; saved; an older game past the chapter loses nothing.


func after_each() -> void:
	World.use_map(0)
	Takeover.ENABLED = true


func _story(index := 3, seed_ := 5) -> Session:
	var s := Session.new({"seed": seed_, "map_seed": MapCity.SEED, "fog": true, "career": true})
	Story.new(index).attach(s)
	s.police.frozen = true
	if s.ground != null:
		s.ground._started = true
		for f in s.ground.commanders:
			s.ground.commanders[f].ai = false
	return s


func _hire(s: Session, role: String, n: int) -> void:
	for i in n:
		var w: Dictionary = s.payroll._person("org", role)
		s.payroll.candidates["org"].append(w)
		s.payroll.hire("org", w.id)


## An empire to lose: heat on the stashes in order, cash and product in each, six people on the payroll.
func _empire(s: Session) -> Array:
	var live: Array = s.stash_net.live()
	for i in live.size():
		live[i].heat = float(i) * 5.0  # the first is the least known
		s.logistics.cash[str(live[i].id)] = 1000.0
		s.logistics.add(str(live[i].id), "marijuana", 100.0, "farm")
	if s.payroll != null:
		s.payroll.ai["org"] = false
		_hire(s, "dealer", 4)
		_hire(s, "driver", 2)
	return live


func test_it_waits_for_the_chapter() -> void:
	var s := _story(2)
	check(s.takeover != null and not s.takeover.done and not s.takeover.pending(), "Blotter: Rafa is alive, and the chapter is not open")
	s.time += Takeover.GRACE_S * 3.0
	s.takeover.update(1.0)
	check(not s.takeover.done, "nothing happens before Cocaine Cowboys")
	s.dispose()
	var o := Session.new({"seed": 5, "map_seed": MapCity.SEED, "features": Session.SANDBOX_FEATURES, "ground_war": true})
	o.time += Takeover.GRACE_S * 3.0
	o.takeover.update(1.0)
	check(not o.takeover.done and not o.takeover.pending(), "and never in a game without the story")
	o.dispose()


func test_fifteen_quiet_minutes_or_their_first_incident() -> void:
	var s := _story()
	check(s.takeover.pending(), "Cocaine Cowboys: the desk is still Rafa's")
	s.takeover.update(1.0)
	s.time += Takeover.GRACE_S - 5.0
	s.takeover.update(1.0)
	check(not s.takeover.done, "not yet")
	s.time += 10.0
	s.takeover.update(1.0)
	check(s.takeover.done and not s.takeover.pending(), "fifteen quiet minutes in: it comes")
	check_near(s.takeover.at, s.time, 1e-6, "and it knows when")
	s.dispose()
	var h := _story()
	h.takeover.update(1.0)
	h.bus.emit("truck_hijacked", h.time, "", ["runner"], {"stash": ""})
	h.takeover.update(1.0)
	check(h.takeover.done, "a hijack of ours brings it at once")
	h.dispose()


func test_half_the_empire_survives() -> void:
	var s := _story()
	var live := _empire(s)
	var n: int = live.size()
	check(n >= 4, "an empire of %d houses" % n)
	var crew0: int = s.payroll.of("org").size()
	var money0 := s.money
	var heard := []
	s.bus.subscribe("takeover", func(e): heard.append(e))
	s.takeover.fire()
	var kept: Array = s.stash_net.live()
	check_eq(kept.size(), n - n / 2, "half the houses are left")
	var least: Array = live.slice(0, n - n / 2).map(func(st): return st.id)
	check_eq(kept.map(func(st): return st.id), least, "the least known ones")
	check_eq(s.payroll.of("org").size(), crew0 - crew0 / 2, "half the crew stayed (%d of %d)" % [s.payroll.of("org").size(), crew0])
	var cash := 0.0
	for site in s.logistics.cash:
		cash += float(s.logistics.cash[site])
	check_near(cash, 1000.0 * n * Takeover.CASH_KEPT, 1.0, "a quarter of the street cash")
	for st in live.slice(n - n / 2):
		check_eq(float(s.logistics.stock[str(st.id)].marijuana), 0.0, "what was in a lost house went with it")
	check_eq(float(s.logistics.stock[str(kept[0].id)].marijuana), 100.0, "what was in a kept one is still there")
	check_eq(s.money, money0, "the pilot's own safe is not touched")
	check_eq(s.trade.trust.of("rival"), 0.0, "and Los Cuervos stand at nothing with us")
	var sm: Dictionary = s.takeover.summary
	check_eq([sm.stashes_lost.size(), sm.stashes_kept, sm.crew_left, sm.crew_stayed], [n / 2, n - n / 2, crew0 / 2, crew0 - crew0 / 2], "the summary counts it")
	check_eq(int(sm.cash_lost) + int(sm.cash_kept), 1000 * n, "to the dollar")
	check_eq(heard.size(), 1, "the player hears of it, once")
	check(str(heard[0].text).contains("Rafa") and str(heard[0].text).contains("His desk is yours"), "in words: %s" % heard[0].text)
	s.takeover.fire()
	check_eq(s.stash_net.live().size(), kept.size(), "it happens once")
	s.dispose()


func test_the_books_balance_through_it() -> void:
	var s := _story()
	_empire(s)
	s.logistics.sync()
	var before: float = s.ledger.balance(Logistics.STREET) if s.ledger.balances.has(Logistics.STREET) else -1.0
	s.takeover.fire()
	s.logistics._sync_street()
	check(before < 0.0 or absf(float(s.ledger.balance(Logistics.STREET)) - float(s.logistics.cash_out())) < 1.0, "the street account is what the street holds")
	s.dispose()


func test_trucks_on_the_road_are_lost_and_the_parked_ones_are_not() -> void:
	var s := _story()
	var live := _empire(s)
	var from := str(live[0].id)
	var to := str(live[1].id)
	check(s.command(Roles.PILOT, "move_goods", {"from": from, "to": to, "good": "marijuana", "lb": 50.0})[0], "a truck on the road")
	check_eq(s.stash_net.trucks.size(), 1, "one out")
	s.takeover.fire()
	check_eq(s.stash_net.trucks.size(), 0, "taken with its load")
	check_eq(int(s.takeover.summary.trucks_lost), 1, "and counted")
	check(s.logistics.convoys.is_empty(), "nothing left in transit on the books")
	s.dispose()


func test_the_desk_is_rafas_until_then() -> void:
	var s := _story()
	check(s.takeover.pending(), "pending")
	s.takeover.fire()
	check(not s.takeover.pending(), "the desk is the player's")
	check_eq(s.takeover.view().done, true, "and the view says so")
	s.dispose()


func test_the_same_seed_loses_the_same_half() -> void:
	var seen := []
	for k in 2:
		var s := _story(3, 9)
		_empire(s)
		for st in s.stash_net.live():
			st.heat = 10.0  # all equally known: the draw decides
		s.takeover.fire()
		seen.append([s.stash_net.live().map(func(st): return st.id), s.payroll.of("org").map(func(w): return w.name)])
		s.dispose()
	check_eq(seen[0], seen[1], "the same houses and the same people")


func test_it_survives_a_save_and_an_older_game_loses_nothing() -> void:
	var s := _story()
	_empire(s)
	s.takeover.fire()
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	var sm: Dictionary = s.takeover.summary.duplicate(true)
	s.dispose()
	var r := _story()
	StrategicSave.restore(r, d)
	check(r.takeover.done, "done stays done")
	check_eq(r.takeover.summary.stashes_lost, sm.stashes_lost, "with what it cost")
	check_eq(r.takeover.summary.crew_left, sm.crew_left, "its counts ints again")
	r.dispose()
	var o := _story(5)  # a game from before the takeover existed, already in The Task Force
	var houses: int = o.stash_net.live().size()
	o.takeover.update(1.0)
	check(o.takeover.done and o.takeover.at < 0.0, "taken as done")
	check_eq(o.stash_net.live().size(), houses, "and nothing is lost")
	o.dispose()


func test_off_rafa_lives() -> void:
	Takeover.ENABLED = false
	var s := _story()
	check(s.takeover == null, "none")
	s.time += Takeover.GRACE_S * 2.0
	s.update(1.0 / 30)
	check(not StrategicSave.capture(s).has("takeover"), "nothing in the save")
	s.dispose()
