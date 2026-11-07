extends TestCase
## L-2: the product chain's money on the ledger. The street's cash (the stashes', the trucks', the bags aboard) is one organisation
## account, `org:street-cash`: the corners' takings are booked into it as sales where they are made, a run home is a move inside
## the organisation, and a raid or a seizure names who took it. What no one named is booked as an adjustment, and stays small.


func after_each() -> void:
	World.use_map(0)


func _war() -> Session:
	var s := Session.new({"seed": 3, "map_seed": MapCity.SEED, "location": "QRY", "features": Session.SANDBOX_FEATURES,
		"ground_war": true, "payroll": true, "trade": true, "logistics": true})
	s.police.frozen = true
	return s


func test_the_street_account_follows_the_street() -> void:
	var s := _war()
	var lg: Logistics = s.logistics
	var home := lg.nearest_stash(lg.hq_pos())
	lg.stock[home]["marijuana"] = 2000.0
	lg.sync()
	s.money = 50000
	for k in 3:
		s.command(Roles.BOSS, "hire_worker", {"kind": "dealer"})
	for i in 3600:
		s.update(1.0)
	s.logistics._sync_street()
	var sales: Array = s.ledger.log.filter(func(r): return r.to == Logistics.STREET and r.reason == "sales")
	check(not sales.is_empty(), "the corners sold, booked as sales into the street account")
	var sold := 0.0
	for r in sales:
		sold += float(r.amount)
	var unnamed := 0.0
	for r in s.ledger.log:
		if (r.to == Logistics.STREET or r.from == Logistics.STREET) and (r.from == Ledger.UNATTRIBUTED or r.to == Ledger.UNATTRIBUTED):
			unnamed += float(r.amount)
	check(unnamed <= maxf(50.0, sold * 0.01), "what no one named is rounding: $%.0f against $%.0f sold" % [unnamed, sold])
	check_near(s.ledger.balance(Logistics.STREET), lg.cash_out(), 0.01, "the account is what the street holds")
	check(absf(s.ledger.total()) < 0.01, "conservation")
	s.dispose()


func test_a_run_home_is_inside_the_organisation() -> void:
	var s := _war()
	var lg: Logistics = s.logistics
	var site := lg.nearest_stash(lg.hq_pos())
	lg.add_cash(site, 5000.0, "outside:street", "sales")
	check_near(s.ledger.balance(Logistics.STREET), 5000.0, 0.01, "booked where it was made")
	var before := s.ledger.log.size()
	check_eq(lg.send(site, Logistics.HQ, "cash", 5000.0), "", "a cash truck home")
	var id = lg.convoys.keys()[0]
	var c: Dictionary = lg.convoys[id]
	lg.convoys.erase(id)
	var m0 := int(s.money)
	lg.add_cash(Logistics.HQ, c.cash)
	check_eq(int(s.money), m0 + 5000, "home")
	var rows: Array = s.ledger.log.slice(before).filter(func(r): return r.from == Logistics.STREET or r.to == Logistics.STREET)
	check(not rows.is_empty() and rows.all(func(r): return str(r.from).begins_with("org:") and str(r.to).begins_with("org:")), "a move inside the organisation: %s" % [rows])
	s.dispose()


func test_a_raid_names_the_state() -> void:
	var s := _war()
	var lg: Logistics = s.logistics
	var site := lg.nearest_stash(lg.hq_pos())
	lg.add_cash(site, 3000.0, "outside:street", "sales")
	var before := s.ledger.balance("outside:state")
	lg._raided(site)
	lg._sync_street()
	check_near(s.ledger.balance(Logistics.STREET), lg.cash_out(), 0.01, "the account follows")
	check(s.ledger.balance("outside:state") > before, "the seized cash went to the state, named as forfeiture")
	check(not s.ledger.log.any(func(r): return r.from == Logistics.STREET and r.to == Ledger.UNATTRIBUTED), "nothing unnamed")
	s.dispose()
