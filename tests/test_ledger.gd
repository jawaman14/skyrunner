extends TestCase
## The ledger (docs/EMPIRE_SIMULATION_SPEC.md section 3) and the F-2 wrap: the old money fields keep their values, and every change is booked.


func test_a_transfer_is_one_debit_and_one_credit() -> void:
	var l := Ledger.new()
	check(l.transfer("org:safe", "biz-1:till", 50.0, "wages", "org"), "booked")
	check_eq(l.balance("org:safe"), -50.0)
	check_eq(l.balance("biz-1:till"), 50.0)
	check(not l.transfer("a", "a", 5.0, "x"), "the same account both sides is refused")
	check(not l.transfer("a", "b", 0.0, "x"), "a zero amount is refused")
	check(not l.transfer("a", "b", 5.0, ""), "no reason is refused")
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


func test_the_session_wrap_keeps_values_and_books_every_change() -> void:
	var s := Session.new({"seed": 1})
	s.money += 0  # opens the account at what the session started with
	s.law_funds += 0.0
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
