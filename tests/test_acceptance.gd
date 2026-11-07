extends TestCase
## The Living District's acceptance suite (L-7; docs/EMPIRE_SIMULATION_SPEC.md section 10). A1-A9 and P1. The ones whose natural
## home is a system's own file live there and are named here:
##   A1 buy a business and read its books ............ tests/test_phone_books.gd (test_a1_buy_a_business_and_read_its_books)
##   A2 staff get budget, shift and orders ........... tests/test_businesses.gd (test_a2_staff_get_a_shift_a_budget_and_orders)
##   A3 a supply chain flows without duplication ..... tests/test_businesses.gd (test_seven_days_flow_without_duplication)
##   A5 a flown and a delegated delivery are equal ... tests/test_delegation.gd (test_a_flown_and_a_delegated_delivery_change_the_same_things)
##   A8 the district settles with the player away ... tests/test_businesses.gd (test_the_books_settle_with_the_player_away)
## and A4, A6, A7, A9 and P1 are here. G1, the owner's playtest, is a human gate.

const DAY := Books.DAY_S


func after_each() -> void:
	World.use_map(0)


func _city(seed_ := 5, war := false) -> Session:
	var o := {"seed": seed_, "map_seed": MapCity.SEED, "location": "HAR", "payroll": true, "features": Session.SANDBOX_FEATURES}
	if war:
		o.merge({"ground_war": true, "trade": true, "logistics": true})
	var s := Session.new(o)
	s.police.frozen = true
	s.update(1.0 / 30)
	s.money = 60000
	return s


## The district on its own: the shoppers hour by hour and the books at each 06:00, without the rest of the island (fast, and the
## same for a session and its reload, which is what A9 compares).
func _days(s: Session, days: float) -> void:
	var end: float = s.time + days * DAY
	while s.time < end:
		var next_close := Books.next_close(s.time)
		var step := minf(600.0, minf(end, next_close) - s.time)
		if step <= 0.0:
			step = 1.0
		s.time += step
		s.businesses.tick_full(step)
		if s.time >= next_close:
			s.businesses._on_books(null)


## A game with every chain running: our warehouse and a shop of ours, funded.
func _running(s: Session) -> void:
	s.businesses.buy("biz-9")
	s.businesses.fund("biz-9", 4000)
	s.businesses.owner["biz-6"] = "org"  # the bodega, as if taken over
	s.businesses.fund("biz-6", 1500)
	s.businesses.fund("biz-4", 2000)


func test_a4_the_ai_orgs_run_their_businesses_on_our_rules() -> void:
	var s := _city(5, true)
	s.ground.commanders.rival.move_cash(20000.0 - s.ground.commanders.rival.cash, "outside:street", "sales")
	_days(s, 3.0)
	var theirs := s.businesses.catalog.filter(func(b): return str(s.businesses.owner[b.id]) in OrgAI.ORGS).map(func(b): return Businesses.till(b.id))
	check(not theirs.is_empty(), "they own businesses")
	var rows: Array = s.ledger.log.filter(func(r): return r.from in theirs or r.to in theirs or r.from == "moretti:safe" or r.to == "moretti:safe")
	check(not rows.is_empty(), "and their money moved")
	var actors := {}
	for r in rows:
		actors[str(r.actor)] = true
	check(actors.keys().all(func(a): return a in ["system:books", "moretti", "rival", "system"]), "A4: settlements by the books, moves by the org itself: %s" % [actors.keys()])
	var moves: int = s.businesses.ai.log.filter(func(x): return x.ok).size()
	var by_org := rows.filter(func(r): return r.actor in ["moretti", "rival"] and str(r.reason) != "open").size()
	check(by_org <= moves * 2, "every discretionary transfer is a logged command_as (%d transfers, %d moves)" % [by_org, moves])
	var boundary := {}
	for r in rows:
		for side in [r.from, r.to]:
			if str(side).begins_with("outside:"):
				boundary[side] = true
	check(not boundary.is_empty(), "their outside boundary is reported: %s" % [boundary.keys()])
	s.dispose()


func test_a6_fourteen_days_of_wages_costs_revenue_and_losses_conserve() -> void:
	var s := _city()
	_running(s)
	var held0: float = s.inventory.held(Businesses.GOOD)
	_days(s, 14.0)
	check(absf(s.ledger.total()) < 0.01, "A6: the ledger sums to zero after 14 days (%.4f)" % s.ledger.total())
	check(s.ledger.overdrawn().is_empty(), "no till overdrawn: %s" % [s.ledger.overdrawn()])
	check(s.inventory.violations().is_empty(), "no lot broken: %s" % [s.inventory.violations()])
	check_near(s.inventory.held(Businesses.GOOD), s.inventory.net_inflow(Businesses.GOOD), 0.01, "what's held is what came in less what left")
	check(s.inventory.held(Businesses.GOOD) >= held0, "and the shelves are stocked")
	check(s.ledger.balance("outside:shoppers") < 0.0 and s.ledger.balance(Businesses.LANDLORD) > 0.0, "revenue came in and the rent went out")
	s.dispose()


func test_a7_what_was_won_and_lost_persists() -> void:
	var s := _city(5, true)
	s.ground.commanders.rival.move_cash(20000.0 - s.ground.commanders.rival.cash, "outside:street", "sales")
	_days(s, 1.0)
	check_eq(s.businesses.owner["biz-2"], "rival", "Los Cuervos took the free corner")
	var k := Territories.key(World.layout, Businesses.DISTRICT)
	s.ground.territory_control[k] = {"org": 0.6, "rival": 0.3, "police": 0.1}
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	var r := _city(5, true)
	StrategicSave.restore(r, d)
	check_eq(r.businesses.owner, s.businesses.owner, "A7: who owns what comes back")
	check_eq(r.businesses.arrears, s.businesses.arrears, "and what they owe")
	var dc: Dictionary = r.businesses.district(Businesses.DISTRICT)
	check_near(float(dc.control.get("org", 0.0)), 0.6, 0.001, "and who holds the district")
	s.dispose()
	r.dispose()


func _economy(s: Session) -> Dictionary:
	var tills := {}
	for b in s.businesses.catalog:
		tills[b.id] = snappedf(s.ledger.balance(Businesses.till(b.id)), 0.01)
		tills[b.id + ":shelf"] = snappedf(s.businesses.shelf(b.id), 0.01)
	return {"tills": tills, "safe": int(s.money), "moretti": snappedf(s.ledger.balance("moretti:safe"), 0.01),
		"owner": s.businesses.owner.duplicate(), "arrears": s.businesses.arrears.duplicate(), "orders": s.businesses.orders.duplicate(true),
		"moves": s.businesses.ai.log.map(func(x): return [x.org, x.cmd, x.args, x.ok]), "rng": s.businesses.ai.capture().rng}


## Compare two projections key by key (and a till at a time), so a failure names what differs.
func _same(got: Dictionary, want: Dictionary, what: String) -> void:
	for key in want:
		if want[key] is Dictionary and got.get(key) is Dictionary and key == "tills":
			for k in want[key]:
				check_eq(got[key].get(k), want[key][k], "%s: %s" % [what, k])
		else:
			check_eq(got.get(key), want[key], "%s: %s" % [what, key])


func test_a9_a_game_saved_mid_day_ends_where_one_played_straight_does() -> void:
	var a := _city()
	var b := _city()
	_running(a)
	_running(b)
	_days(a, 2.5)
	_days(b, 0.5)  # saved at midday
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(b)))
	var r := _city()
	StrategicSave.restore(r, d)
	r.time = b.time
	r.money = b.money  # the safe is the session save's (Session.save), not the strategic block's
	_same(_economy(r), _economy(b), "A9: the round trip reproduces the district")
	_days(r, 2.0)
	_same(_economy(r), _economy(a), "A9: two more days after the load end identical")
	a.dispose()
	b.dispose()
	r.dispose()


## P1: performance. Thresholds are initial (the spec recalibrates them once, here, from the first CI measurement in the PR body).
func test_p1_the_district_scales_and_fits_a_frame() -> void:
	var one := _city()
	_running(one)
	var four := _city()
	_running(four)
	four.businesses.scale_up(4)
	var t1 := _ms(func(): _days(one, 3.0)) / 3.0
	var t4 := _ms(func(): _days(four, 3.0)) / 3.0
	print("P1: the district's sim day %.1f ms at 1x, %.1f ms at 4x (%d businesses)" % [t1, t4, four.businesses.catalog.size()])
	check(t4 <= 5.0 * maxf(t1, 1.0), "P1a: 4x the businesses costs at most 5x a day (%.1f against %.1f ms)" % [t4, t1])
	# P1b: at x60 the desk runs a game minute a frame: the district's share of that frame's work
	var frames := 600
	var t := _ms(func():
		for i in frames:
			one.time += 60.0
			one.businesses.tick_full(60.0)
			if fmod(one.time, DAY) < 60.0:
				one.businesses._on_books(null)) / float(frames)
	print("P1: %.3f ms of district work per frame at x60" % t)
	check(t < 8.0, "P1b: under 8 ms a frame at x60 (%.3f ms)" % t)
	one.dispose()
	four.dispose()


func _ms(fn: Callable) -> float:
	var t0 := Time.get_ticks_usec()
	fn.call()
	return float(Time.get_ticks_usec() - t0) / 1000.0
