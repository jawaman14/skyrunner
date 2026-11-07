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
	check(not c.businesses.arrears.has("biz-3"), "the Morettis' laundromat is theirs to run, from L-3")
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
	check_near(c.ledger.balance(Businesses.LANDLORD), 300.0, 0.01, "the rent went to the landlord")
	check_near(c.ledger.balance(Businesses.UTILITIES), 90.0, 0.01, "and the bills")
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
