extends TestCase
## The ledger (docs/EMPIRE_SIMULATION_SPEC.md section 3) and the F-2 wrap: the old money fields keep their values, and every change is booked.


func test_a_transfer_is_one_debit_and_one_credit() -> void:
	var l := Ledger.new()
	check(l.transfer("org:safe", "biz-1:till", 50.0, "wages", "org"), "booked")
	check_eq(l.balance("org:safe"), -50.0)
	check_eq(l.balance("biz-1:till"), 50.0)
	check(not l.transfer("a", "a", 5.0, "fee"), "the same account both sides is refused")
	check(not l.transfer("a", "b", 0.0, "fee"), "a zero amount is refused")
	check(not l.transfer("a", "b", 5.0, ""), "no reason is refused")
	check(not l.transfer("a", "b", 5.0, "wagse"), "a reason off the closed list is refused")
	check_eq(l.log.size(), 1, "refusals leave no row")
	check(absf(l.total()) < 0.001, "conservation")


func test_track_opens_at_the_old_value_then_books_the_difference() -> void:
	var l := Ledger.new()
	l.track("org:safe", 3000.0, 3500.0)
	check_eq(l.balance("org:safe"), 3500.0)
	l.track("org:safe", 3500.0, 3200.0)
	check_eq(l.balance("org:safe"), 3200.0)
	check_eq(l.boundary().get(Ledger.UNATTRIBUTED), 200.0, "net +500 in, -300 out")
	check_eq(l.rebuild().get("org:safe"), l.balance("org:safe"), "the cache equals the log")
	check(absf(l.total()) < 0.001, "conservation")


func test_trimming_the_log_keeps_rebuild_exact() -> void:
	var l := Ledger.new()
	for i in Ledger.LOG_MAX + Ledger.TRIM + 50:
		l.transfer("a", "b", 1.0 + (i % 7), "fee")
	check(l.log.size() <= Ledger.LOG_MAX + Ledger.TRIM and l.log.size() >= Ledger.LOG_MAX, "the log stays near its cap")
	var got := l.rebuild()
	for acct in l.balances:
		check(absf(float(got.get(acct, 0.0)) - l.balance(acct)) < 0.001, "%s rebuilds to the cache" % acct)


func test_a_named_move_books_its_counterparty_not_the_unattributed() -> void:
	var s := Session.new({"seed": 1})
	s.money += 0
	var u0: float = s.ledger.boundary().get(Ledger.UNATTRIBUTED, 0.0)
	var m0: int = s.money
	s.move_money(-300, "outside:market", "fuel")
	s.move_money(120, "outside:market", "resale")
	check_eq(s.money, m0 - 180, "the value is the same as money += delta")
	var row: Dictionary = s.ledger.log[-1]
	check(row.from == "outside:market" and row.to == "org:safe" and row.reason == "resale" and row.actor == "org", "the last row names it: %s" % [row])
	check_eq(float(s.ledger.boundary().get(Ledger.UNATTRIBUTED, 0.0)), u0, "nothing went to unattributed")
	check_eq(float(s.ledger.boundary().get("outside:market")), -180.0, "net 180 left the safe for the market")
	s.money += 5
	check_eq(s.ledger.log[-1].from, Ledger.UNATTRIBUTED, "a plain change is still unattributed")
	s.dispose()


func test_the_budget_accrual_is_one_named_row_a_minute() -> void:
	var s := Session.new({"seed": 1})
	var rows0: int = s.ledger.log.size()
	var f0: float = s.law_funds
	for i in 120:
		s.time += 0.5
		s._update_upgrades(0.5)
	check_eq(s.ledger.log.size() - rows0, 1, "60 s of frames is one row (merged), not 120")
	s.time += 60.0
	s._update_upgrades(0.5)
	check_eq(s.ledger.log.size() - rows0, 2, "the next minute opens a new row")
	var row: Dictionary = s.ledger.log[rows0]
	check(row.from == "outside:state" and row.to == "police:budget" and row.reason == "budget", "named: %s" % [row])
	check_eq(s.ledger.balance("police:budget"), s.law_funds, "the ledger agrees")
	var got := s.ledger.rebuild()
	check(absf(float(got.get("police:budget", 0.0)) - s.law_funds) < 0.01, "and rebuilds")
func test_a_loaded_session_opens_at_its_saved_money_with_no_phantom_inflow() -> void:
	var s := Session.new({"seed": 1, "money": 10000})
	check_eq(s.ledger.balance("org:safe"), 10000.0, "opened at the saved value")
	check_eq(float(s.ledger.boundary().get(Ledger.UNATTRIBUTED, 0.0)), 0.0, "nothing booked as an unattributed inflow")
	var got := s.ledger.rebuild()
	for acct in s.ledger.balances:
		check(got.has(acct), "%s is listed by rebuild" % acct)
	s.dispose()


func test_a_restate_is_an_opening_not_an_inflow() -> void:
	var l := Ledger.new()
	l.track("rival:war-chest", 20000.0, 20000.0)
	l.restate("rival:war-chest", 12000.0)
	check_eq(l.balance("rival:war-chest"), 12000.0)
	check_eq(float(l.boundary().get(Ledger.UNATTRIBUTED, 0.0)), 0.0, "no unattributed flow")
	check(absf(l.total()) < 0.001, "conservation")
	l.transfer("rival:war-chest", "outside:market", 99999.0, "fuel")
	check_eq(l.overdrawn(), [], "a war chest may owe, as the unconditional upkeep needs")


func test_the_rival_war_chest_opens_at_its_starting_cash() -> void:
	var s := Session.new({"seed": 1})
	s.enable_system("ground_war")
	if s.ground == null:
		s.dispose()
		return
	check_eq(s.ledger.balance("rival:war-chest"), 20000.0, "opened at the starting cash")
	check_eq(float(s.ledger.boundary().get(Ledger.UNATTRIBUTED, 0.0)), 0.0, "no phantom inflow")
	s.dispose()


func test_the_session_wrap_keeps_values_and_books_every_change() -> void:
	var s := Session.new({"seed": 1})
	check_eq(s.ledger.balance("police:budget"), s.law_funds, "the budget is open from construction")
	s.money += 0  # opens the account at what the session started with
	var u0: float = s.ledger.boundary().get(Ledger.UNATTRIBUTED, 0.0)
	var m0: int = s.money
	s.money += 700
	s.money -= 250
	s.law_funds += 1000.0
	check_eq(s.money, m0 + 450, "the value is unchanged by the wrap")
	check_eq(s.ledger.balance("org:safe"), float(m0 + 450), "and the ledger agrees")
	check_eq(s.ledger.balance("police:budget"), s.law_funds)
	check(absf(s.ledger.total()) < 0.001, "conservation")
	check_eq(s.ledger.overdrawn(), [], "no stash or till is overdrawn")
	var net: Dictionary = s.ledger.boundary()
	check_eq(float(net.get(Ledger.UNATTRIBUTED)) - u0, 450.0 + 1000.0, "the unattributed flow is the to-do list for F-3")
	s.dispose()
