extends TestCase
## The Living District's businesses (L-1): twelve businesses with owners, tills and costs, bought, funded and drawn on, paying
## their day's rent and bills from the till at the books close, owing what the till can't cover, never touching the safe.


func after_each() -> void:
	World.use_map(0)


func _city() -> Session:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "HAR"})
	s.police.frozen = true
	s.update(1.0 / 30)
	return s


func test_only_on_the_city_coast() -> void:
	var s := Session.new({"seed": 5, "location": "HAR"})
	check(s.businesses == null, "the island has no San Telmo Centro")
	s.dispose()
	var c := _city()
	check(c.businesses != null, "the city coast has the district")
	c.dispose()


func test_the_twelve_sit_in_their_districts() -> void:
	var c := _city()
	check_eq(Businesses.DATA.size(), 12, "twelve businesses")
	var ids := {}
	for b in Businesses.DATA:
		ids[b.id] = true
		var area := Territories.get_area(World.layout, str(b.district))
		check(not area.is_empty(), "%s: its district is on the map" % b.id)
		var r: Rect2 = area.bounds
		check(r.has_point(Vector2(float(b.site[0]), float(b.site[1]))), "%s sits inside %s" % [b.id, b.district])
		check(str(b.owner) in ["org", "", "outside", "moretti", "rival"], "%s: a known owner" % b.id)
	check_eq(ids.size(), 12, "unique ids")
	check_eq(c.businesses.ours().size(), 2, "the organisation starts with a corner and the club")
	c.dispose()


func test_rent_is_paid_from_the_till_only() -> void:
	var c := _city()
	var safe := int(c.money)
	c.businesses._on_books(null)
	check_eq(int(c.money), safe, "an empty till never reaches into the safe")
	check_eq(int(c.businesses.arrears["biz-4"]), 390, "the club owes its day: rent 300 and bills 90")
	check(c.businesses.blocked.has("biz-4"), "with the reason")
	check_eq(int(c.businesses.arrears.get("biz-3", 0)), 0, "the Morettis run their laundromat and pay its rent from their own safe (L-3)")
	check_eq(int(c.businesses.arrears.get("biz-2", 0)), 0, "a free corner nobody runs owes nothing")
	c.dispose()


func test_funding_pays_the_arrears_first() -> void:
	var c := _city()
	c.money = 10000
	c.businesses._on_books(null)
	check_eq(c.command(Roles.PILOT, "business_fund", {"id": "biz-4", "amount": 1000})[0], true, "fund the club")
	check_eq(int(c.money), 9000, "from the safe")
	check_eq(c.businesses.balance("biz-4"), 610, "the arrears came out first")
	check_eq(int(c.businesses.arrears["biz-4"]), 0, "nothing owed")
	check(not c.businesses.blocked.has("biz-4"), "not blocked")
	var paid := func(to: String) -> float:
		return c.ledger.log.filter(func(r): return r.from == Businesses.till("biz-4") and r.to == to).reduce(func(a, r): return a + float(r.amount), 0.0)
	check_near(paid.call(Businesses.LANDLORD), 300.0, 0.01, "the rent went to the landlord")
	check_near(paid.call(Businesses.UTILITIES), 90.0, 0.01, "and the bills")
	c.businesses._on_books(null)
	check_eq(c.businesses.balance("biz-4"), 220, "the next day comes out of the till")
	check_eq(c.command(Roles.PILOT, "business_take", {"id": "biz-4", "amount": 500})[0], true, "draw on it")
	check_eq(int(c.money), 9220, "only what was there")
	check_eq(c.businesses.balance("biz-4"), 0, "empty")
	c.dispose()


func test_buying_a_free_business() -> void:
	var c := _city()
	c.money = 3000
	var r: Array = c.command(Roles.PILOT, "business_buy", {"id": "biz-2"})
	check_eq(r[0], false, "too dear: %s" % [r])
	c.money = 5000
	check_eq(c.command(Roles.PILOT, "business_buy", {"id": "biz-2"})[0], true, "bought")
	check_eq(int(c.money), 1000, "paid")
	check_eq(c.businesses.owner["biz-2"], "org", "ours")
	check_eq(c.command(Roles.PILOT, "business_buy", {"id": "biz-3"})[0], false, "the Morettis' isn't for sale")
	check_eq(c.command(Roles.PILOT, "business_buy", {"id": "biz-8"})[0], false, "nor the dealership")
	check_eq(c.command(Roles.PILOT, "business_fund", {"id": "biz-6", "amount": 10})[0], false, "a rival's till isn't ours")
	c.dispose()


func test_the_books_close_settles_the_day() -> void:
	var c := _city()
	c.money = 10000
	c.businesses.fund("biz-4", 2000)
	var t0 := c.time
	var close := Books.next_close(t0)
	while c.time < close + 1.0:
		c.update(30.0)
	check_eq(c.businesses.balance("biz-4"), 1610, "one day's rent and bills at 06:00")
	c.dispose()


func test_saved_and_restored() -> void:
	var c := _city()
	c.money = 20000
	check_eq(c.businesses.buy("biz-12"), "", "bought the garage")
	c.businesses._on_books(null)
	var d := StrategicSave.capture(c)
	check(d.has("businesses"), "saved")
	var json: Dictionary = JSON.parse_string(JSON.stringify(d))
	var r := _city()
	StrategicSave.restore(r, json)
	check_eq(r.businesses.owner["biz-12"], "org", "the owner")
	check_eq(int(r.businesses.arrears["biz-12"]), 160, "the arrears")
	check(r.businesses.blocked.has("biz-12"), "and the reason")
	c.dispose()
	r.dispose()


func test_the_district_reads_control_from_the_street_war() -> void:
	var c := _city()
	var d: Dictionary = c.businesses.district(Businesses.DISTRICT)
	check_eq(d.id, Businesses.DISTRICT, "the district")
	check(d.has("prosperity") and d.has("demand") and d.has("control"), "prosperity, demand and control")
	c.dispose()


# ------------------------------------------------------------------ the legit chain (L-2)
func test_the_warehouse_imports_and_sells_on() -> void:
	var c := _city()
	c.money = 40000
	check_eq(c.businesses.buy("biz-9"), "", "Costa Imports")
	c.businesses.fund("biz-9", 2000)
	c.businesses._on_books(null)
	check_near(c.businesses.shelf("biz-9"), 400.0, 0.01, "restocked from the market")
	check_eq(c.businesses.balance("biz-9"), 2000 - 800 - 270, "paid $2 a pound, then the day's rent and bills")
	c.businesses._on_books(null)
	check_near(c.ledger.balance("outside:retail"), -150.0 * Businesses.TRADE, 0.01, "the shops outside took 150 lb at the trade price")
	check_near(c.businesses.shelf("biz-9"), 400.0, 0.01, "and it restocked what it could")
	check(c.inventory.violations().is_empty(), "the inventory's invariants hold: %s" % [c.inventory.violations()])
	check(absf(c.ledger.total()) < 0.01, "conservation")
	c.dispose()


func test_a_retailer_buys_from_the_warehouse_first() -> void:
	var c := _city()
	c.money = 40000
	c.businesses.buy("biz-9")
	c.businesses.fund("biz-9", 2000)
	c.businesses.owner["biz-6"] = "org"  # the bodega, as if taken over (L-3 gives the others' their own)
	c.businesses.fund("biz-6", 1000)
	c.businesses._on_books(null)  # the warehouse has nothing on day one: the bodega buys outside, dearer
	check_near(c.businesses.shelf("biz-6"), Businesses.SHELF_LB, 0.01, "stocked")
	var w0 := c.businesses.balance("biz-9")
	c.businesses._on_books(null)
	var bought: float = c.inventory.log.filter(func(r): return r.reason == "wholesale" and r.to == "biz-6").reduce(func(a, r): return a + float(r.lb), 0.0)
	check(bought > 0.0, "the bodega restocked from the warehouse")
	check(c.businesses.balance("biz-9") > w0 - 800, "and the warehouse was paid for it")
	check(c.ledger.balance("outside:shoppers") < 0.0, "shoppers paid the bodega")
	check(c.inventory.violations().is_empty(), "no pound made or lost")
	check(absf(c.ledger.total()) < 0.01, "conservation")
	c.dispose()


func test_seven_days_flow_without_duplication() -> void:
	var c := _city()
	c.money = 40000
	c.businesses.buy("biz-9")
	c.businesses.fund("biz-9", 3000)
	c.businesses.owner["biz-10"] = "org"
	c.businesses.fund("biz-10", 1500)
	var held0: float = c.inventory.held(Businesses.GOOD)
	for d in 7:
		c.businesses._on_books(null)
	check_near(c.inventory.held(Businesses.GOOD), c.inventory.net_inflow(Businesses.GOOD), 0.01, "A3: what's held is what came in less what left")
	check_near(c.inventory.held(Businesses.GOOD) - held0, c.businesses.shelf("biz-9") + c.businesses.shelf("biz-10"), 0.01, "and it's on the two shelves")
	check(c.businesses.balance("biz-10") >= 0 and c.businesses.balance("biz-9") >= 0, "no till overdrawn")
	c.dispose()


func test_other_owners_wait_for_their_ai() -> void:
	var saved := OrgAI.ENABLED
	OrgAI.ENABLED = false
	var c := _city()
	OrgAI.ENABLED = saved
	c.businesses._on_books(null)
	check_eq(c.businesses.shelf("biz-6"), 0.0, "Los Cuervos' bodega trades from L-3")
	check_eq(c.businesses.shelf("biz-10"), 0.0, "so does the Morettis' fish market")
	c.dispose()
