extends TestCase
## The weekly black market and the week's hot job (D-95): one-off offers that turn over with the island week, and one strip's
## best job marked for more pay and renown.


func _sess() -> Session:
	var s := Session.new({"seed": 31, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES,
		"trade": true, "logistics": true, "dealership": true, "renown": true, "ground_war": true, "money": 200000})
	s.police.frozen = true
	if s.ground != null:
		s.ground._started = true
		for f in s.ground.commanders:
			s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	return s


func _week(s: Session) -> void:
	s.weekly.update(0.0)
	s.black_market.update()


func test_a_week_posts_three_offers_from_what_is_open() -> void:
	var s := _sess()
	_week(s)
	check(s.weekly.week >= 1, "a week is on")
	check_eq(s.black_market.offers.size(), BlackMarket.OFFERS, "three offers")
	var kinds := s.black_market.offers.map(func(o): return str(o.kind))
	for k in kinds:
		check(k in ["arms", "vehicle", "fuel", "file"], k)
	var seen := {}
	for k in kinds:
		check(not seen.has(k), "each kind once: %s" % [kinds])
		seen[k] = true
	s.dispose()


func _offer(s: Session, kind: String) -> int:
	for i in s.black_market.offers.size():
		if s.black_market.offers[i].kind == kind:
			return i
	# not dealt this week: deal it by hand from the pool
	for o in s.black_market._pool():
		if o.kind == kind:
			o["sold"] = false
			s.black_market.offers.append(o)
			return s.black_market.offers.size() - 1
	return -1


func test_each_offer_delivers_what_it_says_once() -> void:
	var s := _sess()
	_week(s)
	var bm := s.black_market
	var i := _offer(s, "arms")
	var ars = s.arsenals.get("org")
	var tier: String = bm.offers[i].tier
	var had: int = int(ars.stock.get(tier, 0))
	var m: int = s.money
	check_eq(s.command(Roles.PILOT, "black_market_buy", {"i": i})[0], true, "bought the crate")
	check_eq(int(ars.stock.get(tier, 0)), had + int(bm.offers[i].n), "into the armoury")
	check_eq(s.money, m - int(bm.offers[i].price), "for its price")
	check(int(bm.offers[i].price) < int(Arsenal.TIERS[tier].price) * int(bm.offers[i].n), "below the street")
	check(not s.command(Roles.PILOT, "black_market_buy", {"i": i})[0], "once")
	var v := _offer(s, "vehicle")
	var n0: int = s.dealer.owned.size()
	check_eq(bm.buy(v), "", "the truck")
	check_eq(s.dealer.owned.size(), n0 + 1, "in the fleet")
	check(int(bm.offers[v].price) < int(Dealership.spec(str(bm.offers[v].id)).price), "under the lot's price")
	var f := _offer(s, "fuel")
	var code: String = bm.offers[f].code
	var c0: float = float(s.fuel_caches.get(code, 0.0))
	check_eq(bm.buy(f), "", "the fuel")
	check_near(float(s.fuel_caches.get(code, 0.0)), c0 + BlackMarket.FUEL_LB, 0.01, "left at the strip")
	var k := _offer(s, "file")
	var c = s.police.case("runner")
	c.suspicion = 50.0
	check_eq(bm.buy(k), "", "the clerk")
	check_near(c.suspicion, 50.0 - BlackMarket.FILE_HEAT, 0.01, "the heat down")
	check(s.ledger.log.slice(-6).any(func(r): return str(r.get("from", "")) == "outside:black-market" or str(r.get("to", "")) == "outside:black-market"), "booked to the black market")
	s.dispose()


func test_no_money_no_deal() -> void:
	var s := _sess()
	_week(s)
	s.money = 10
	check(s.black_market.buy(0).begins_with("He wants"), "he wants paying")
	s.dispose()


func test_the_week_turns_the_stock_over() -> void:
	var s := _sess()
	_week(s)
	s.black_market.buy(0)
	s.time = s.weekly.ends + 1.0
	_week(s)
	check_eq(s.black_market.week, s.weekly.week, "the next week")
	check(s.black_market.offers.all(func(o): return not bool(o.sold)), "fresh stock")
	s.dispose()


func test_the_hot_job_pays_more_and_renown_and_lapses_with_the_week() -> void:
	var s := _sess()
	for code in ["HAR", "FRM", "QRY"]:
		if not s.boards.has(code):
			s.refresh_board(code)
	_week(s)
	var hot: Dictionary = s.black_market.hot
	check(not hot.is_empty(), "one is marked")
	var j = s.black_market._find(int(hot.job_id))
	check(j != null and str(j.title).begins_with(BlackMarket.HOT_TAG), "in its title")
	check_eq(int(j.payout), int(round(float(hot.base) * BlackMarket.HOT_PAY)), "half as much again")
	check(s.black_market.rows()[0][0].begins_with("The hot job"), "on the Week page")
	var r0: float = s.renown.score
	s.bus.emit("job_delivered", s.time, "", ["runner"], {"job_id": j.id, "dest": j.dest})
	check(s.renown.score >= r0 + BlackMarket.HOT_RENOWN - 0.01, "the hot job's renown on delivery (on top of the delivery's own): %.1f" % (s.renown.score - r0))
	check(s.black_market.hot.is_empty(), "done")
	s.dispose()


func test_an_untaken_hot_job_goes_back_to_ordinary() -> void:
	var s := _sess()
	for code in ["HAR", "FRM", "QRY"]:
		if not s.boards.has(code):
			s.refresh_board(code)
	_week(s)
	var hot: Dictionary = s.black_market.hot.duplicate()
	var j = s.black_market._find(int(hot.job_id))
	s.time = s.weekly.ends + 1.0
	_week(s)
	check_eq(int(j.payout), int(hot.base), "its own pay again")
	check(not str(j.title).begins_with(BlackMarket.HOT_TAG), "and its own title")
	s.dispose()


func test_the_week_page_buys() -> void:
	var s := _sess()
	_week(s)
	var rows := s.black_market.rows()
	var buyable := rows.filter(func(r): return int(r[1]) >= 0)
	check_eq(buyable.size(), BlackMarket.OFFERS, "every offer can be bought")
	s.dispose()


func test_saved_with_the_game() -> void:
	var s := _sess()
	for code in ["HAR", "FRM"]:
		if not s.boards.has(code):
			s.refresh_board(code)
	_week(s)
	s.black_market.buy(0)
	var d: Dictionary = SaveVars.through_json(StrategicSave.capture(s))
	var next: int = s.black_market.rng.randint(1, 1000)
	var t := _sess()
	StrategicSave.restore(t, d)
	check_eq(t.black_market.week, s.black_market.week, "the week")
	check(t.black_market.offers[0].sold, "what was sold")
	check_eq(t.black_market.offers.size(), s.black_market.offers.size(), "the stock")
	check_eq(int(t.black_market.hot.get("job_id", 0)), int(s.black_market.hot.get("job_id", 0)), "the hot job")
	check_eq(t.black_market.rng.randint(1, 1000), next, "the stream carries on")
	s.dispose()
	t.dispose()


func test_off_means_none() -> void:
	BlackMarket.ENABLED = false
	var s := _sess()
	check(s.black_market == null, "not built")
	check(s.command(Roles.PILOT, "black_market_buy", {"i": 0})[1].contains("no black market"), "and the command says so")
	s.dispose()
	BlackMarket.ENABLED = true


func test_a_hot_job_lost_with_its_board_is_replaced() -> void:
	var s := _sess()
	for code in ["HAR", "FRM", "QRY"]:
		if not s.boards.has(code):
			s.refresh_board(code)
	_week(s)
	var hot: Dictionary = s.black_market.hot.duplicate()
	s.refresh_board(str(hot.code))  # the board went stale and was dealt afresh
	s.time += BlackMarket.CHECK_S + 1.0
	s.black_market.update()
	check(not s.black_market.hot.is_empty(), "another hot job")
	check(s.black_market._find(int(s.black_market.hot.job_id)) != null, "on a board")
	s.dispose()
