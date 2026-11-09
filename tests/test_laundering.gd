extends TestCase
## Fronts wash street cash (DESIGN 51.5): a nightly allowance, a soft ceiling with heat, the front's fee in its till, the clean money
## after a delay, equal rules for the Morettis' fronts, and the night's state in the save.


func after_each() -> void:
	World.use_map(0)


func _city(war := false) -> Session:
	var o := {"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "trade": true, "logistics": true}
	if war:
		o["ground_war"] = true
	var s := Session.new(o)
	s.police.frozen = true
	s.update(1.0 / 30)
	return s


## Put `amount` of street cash at a stash, booked as street money.
func _street(s: Session, amount: int) -> String:
	var st := "stash:test"
	s.logistics.cash[st] = int(s.logistics.cash.get(st, 0)) + amount
	s.logistics.book_cash("outside:street", Logistics.STREET, float(amount), "sales")
	return st


func test_a_deposit_pays_the_fee_and_the_rest_after_the_delay() -> void:
	var s := _city()
	var st := _street(s, 3000)
	var safe := int(s.money)
	var r: Array = s.command(Roles.PILOT, "business_launder", {"id": "biz-4", "amount": 2000, "stash": st})
	check(r[0], "the club takes it: %s" % str(r[1]))
	check_eq(int(s.logistics.cash[st]), 1000, "out of the stash")
	check_eq(s.businesses.balance("biz-4"), 300, "the club keeps 15% as takings")
	check_eq(int(s.money), safe, "nothing clean yet")
	check_eq(s.businesses.wash.waiting("biz-4"), 1700, "the rest waits in the wash")
	s.time += 11.0 * 3600.0
	s.businesses.wash.mature()
	check_eq(int(s.money), safe, "the club's delay is 12 hours")
	s.time += 3600.0
	s.businesses.wash.mature()
	check_eq(int(s.money), safe + 1700, "clean and in the safe")
	check_eq(s.businesses.wash.waiting("biz-4"), 0, "the wash is empty")
	check(absf(s.ledger.total()) < 0.01, "the ledger balances")
	s.dispose()


func test_the_allowance_is_soft_up_to_the_ceiling() -> void:
	var s := _city()
	var st := _street(s, 10000)
	var c = s.police.case("runner")
	c.suspicion = 0.0
	check(s.command(Roles.PILOT, "business_launder", {"id": "biz-4", "amount": 2500, "stash": st})[0], "up to the allowance")
	check_eq(snappedf(c.suspicion, 0.01), 0.0, "no heat within the night's $2,500")
	check(s.command(Roles.PILOT, "business_launder", {"id": "biz-4", "amount": 5000, "stash": st})[0], "over it, to the ceiling")
	check_eq(int(s.businesses.wash.washed["biz-4"]), 3750, "clamped at 1.5 times the allowance")
	check_eq(snappedf(c.suspicion, 0.01), 7.5, "$1,250 over at 6 a thousand")
	var r: Array = s.command(Roles.PILOT, "business_launder", {"id": "biz-4", "amount": 500, "stash": st})
	check(not r[0], "above the ceiling it's refused")
	s.businesses._on_books(null)
	check_eq(s.businesses.wash.room("biz-4")[0], 2500, "the books close and the night starts over")
	s.dispose()


func test_only_our_fronts() -> void:
	var s := _city()
	var st := _street(s, 5000)
	check(not s.command(Roles.PILOT, "business_launder", {"id": "biz-1", "amount": 1000, "stash": st})[0], "a corner isn't a front")
	check(not s.command(Roles.PILOT, "business_launder", {"id": "biz-3", "amount": 1000, "stash": st})[0], "the Morettis' laundromat isn't ours")
	check(s.command(Roles.PILOT, "business_launder", {"id": "biz-4", "amount": 1000})[0], "no stash named: the richest")
	check_eq(int(s.logistics.cash[st]), 4000, "from it")
	s.dispose()


func test_a_big_pile_of_street_cash_is_heat() -> void:
	var s := _city()
	_street(s, 30000)
	var c = s.police.case("runner")
	var before: float = c.suspicion
	s.businesses._on_books(null)
	check(c.suspicion > before, "street cash over $25,000 draws the case file")
	s.dispose()


func test_the_morettis_wash_their_rackets() -> void:
	var s := _city()
	var b := s.businesses
	var safe := s.ledger.balance("moretti:safe")
	for d in 3:
		s.time = Books.next_close(s.time)
		b.tick_full(0.0)
		b._on_books(null)
	check(s.ledger.balance("moretti:safe") > safe, "their fronts make the family money now: %d -> %d" % [int(safe), int(s.ledger.balance("moretti:safe"))])
	var launders: Array = b.ai.log.filter(func(m): return m.cmd == "business_launder")
	check(not launders.is_empty() and launders.all(func(m): return m.ok), "through command_as, like any boss")
	check_eq(int(b.wash.washed.get("biz-3", 0)), 1500, "the laundromat to its allowance, no more")
	check(absf(s.ledger.total()) < 0.01, "the ledger balances")
	s.dispose()


func test_the_wash_survives_a_save() -> void:
	var s := _city()
	var st := _street(s, 3000)
	s.command(Roles.PILOT, "business_launder", {"id": "biz-4", "amount": 2000, "stash": st})
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.businesses.capture()))
	var t := s.time
	s.dispose()
	var s2 := _city()
	s2.time = t
	s2.businesses.restore(d)
	check_eq(int(s2.businesses.wash.washed["biz-4"]), 2000, "tonight's deposits")
	check_eq(s2.businesses.wash.waiting("biz-4"), 1700, "the money in the wash")
	check_eq(int(s2.ledger.balance(Laundering.wash_account("biz-4"))), 1700, "and its account")
	var safe := int(s2.money)
	s2.time += 12.0 * 3600.0
	s2.businesses.wash.mature()
	check_eq(int(s2.money), safe + 1700, "it still arrives")
	s2.dispose()


func test_off_it_is_refused() -> void:
	var saved := Switches.snapshot()
	Laundering.ENABLED = false
	var s := _city()
	var st := _street(s, 3000)
	check(not s.command(Roles.PILOT, "business_launder", {"id": "biz-4", "amount": 1000, "stash": st})[0], "off: no laundering")
	s.dispose()
	Switches.restore(saved)
