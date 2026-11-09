extends TestCase
## StockLedger: builds valued lot rows sorted by worth and sums them for a manifest.
## Static helpers only; checks fields, ageing, stable sort and zero for unpriced goods.


func test_rows_carry_the_lot_fields() -> void:
	var lot := StockLot.make("Salt", 10.0, 0.7, 90.0, "Haven", true, 12.0)
	var rows := StockLedger.rows([lot], 100.0, {"Salt": 2.0}, {"Salt": 600.0})
	check_eq(rows.size(), 1, "one lot gives one row")
	var row: Dictionary = rows[0]
	check_eq(row["good"], "Salt", "good is carried")
	check_eq(row["units"], 12.0, "units are carried")
	check_eq(row["lb"], 10.0, "lb is carried")
	check_eq(row["grade"], 0.7, "grade is carried")
	check(absf(float(row["age_s"]) - 10.0) < 0.0001, "age_s is now minus born_at")
	check_eq(row["hot"], true, "hot is carried")
	check_eq(row["origin"], "Haven", "origin is carried")
	check(absf(float(row["value"]) - StockValue.value(2.0, 10.0, 0.7, 10.0, 600.0)) < 0.0001, "value matches StockValue")


func test_one_half_life_is_worth_half_of_a_fresh_identical_lot() -> void:
	var fresh := StockLot.make("Grain", 10.0, 0.8, 1200.0, "Haven", false)
	var aged := StockLot.make("Grain", 10.0, 0.8, 600.0, "Haven", false)
	var rows := StockLedger.rows([fresh, aged], 1200.0, {"Grain": 100.0}, {"Grain": 600.0})
	check_eq(rows.size(), 2, "both lots produce rows")
	var fresh_v: float = float(rows[0]["value"])
	var aged_v: float = float(rows[1]["value"])
	check(absf(fresh_v - 1300.0) < 0.0001, "fresh lot is price * lb * (0.5 + grade)")
	check(absf(aged_v - fresh_v * 0.5) < 0.0001, "one half-life halves the value")


func test_rows_sorted_by_value_and_equal_values_keep_input_order() -> void:
	var low := StockLot.make("Salt", 10.0, 0.5, 0.0, "A", false)
	var tie_a := StockLot.make("Grain", 10.0, 0.5, 0.0, "B", false)
	var tie_b := StockLot.make("Ore", 10.0, 0.5, 0.0, "C", false)
	var high := StockLot.make("Gold", 10.0, 0.9, 0.0, "D", false)
	var prices := {"Salt": 1.0, "Grain": 5.0, "Ore": 5.0, "Gold": 20.0}
	var rows := StockLedger.rows([low, tie_a, tie_b, high], 0.0, prices, {})
	check_eq(rows[0]["good"], "Gold", "highest value comes first")
	check_eq(rows[1]["good"], "Grain", "a tie follows in input order")
	check_eq(rows[2]["good"], "Ore", "the second tie also follows in input order")
	check_eq(rows[3]["good"], "Salt", "lowest value comes last")


func test_a_good_with_no_price_is_worth_zero() -> void:
	var lot := StockLot.make("Mystery", 10.0, 1.0, 0.0, "Haven", false)
	var rows := StockLedger.rows([lot], 100.0, {"Salt": 5.0}, {"Mystery": 300.0})
	check_eq(rows.size(), 1, "an unpriced good still gets a row")
	check_eq(rows[0]["value"], 0.0, "no price means zero value")


func test_totals_sums_lb_value_and_hot_lb() -> void:
	var a := StockLot.make("Salt", 10.0, 1.0, 0.0, "A", false)
	var b := StockLot.make("Grain", 30.0, 1.0, 0.0, "B", true)
	var rows := StockLedger.rows([a, b], 0.0, {"Salt": 2.0, "Grain": 4.0}, {})
	var totals := StockLedger.totals(rows)
	check(absf(float(totals["lb"]) - 40.0) < 0.0001, "lb sums every row")
	check(absf(float(totals["value"]) - 210.0) < 0.0001, "value sums every row")
	check(absf(float(totals["hot_lb"]) - 30.0) < 0.0001, "hot_lb sums only flagged lots")


func _city_trade() -> Session:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "trade": true, "logistics": true})
	s.police.frozen = true
	s.update(1.0 / 30)
	return s


func test_the_session_ledger_lists_our_lots_with_a_named_buyer() -> void:
	var s := _city_trade()
	var st: String = s.logistics.stock.keys()[0]
	s.logistics.book("outside:growers", "stash:" + st, "marijuana", 40.0, "arrive")
	s.logistics.stock[st]["marijuana"] = float(s.logistics.stock[st].get("marijuana", 0.0)) + 40.0
	s.inventory.add("groceries", 50.0, "biz-9", "market", "", 0.5, 0.0, s.time)
	var book: Dictionary = StockLedger.of_session(s)
	var mine: Array = book.rows.filter(func(r): return r.good == "marijuana")
	check(not mine.is_empty(), "our grass is on the ledger: %s" % [book.rows])
	check(book.rows.all(func(r): return r.good in Trade.GOODS), "a business's shelf isn't the organisation's stock")
	var r: Dictionary = mine[0]
	check_eq(str(r.place), s.logistics.name_of(st), "by the stash's name")
	check(str(r.buyer) != "" and str(r.market) != "", "valued at a named buyer and market: %s at %s" % [r.buyer, r.market])
	var q: Dictionary = StockLedger.best_quote(s, "marijuana")
	check(absf(float(r.value) - float(q.price) * float(r.lb) * (0.5 + float(r.grade))) < 0.01, "at the best open quote, by grade")
	check(float(book.totals.lb) >= 40.0, "and the header sums it")
	s.dispose()
	World.use_map(0)


func test_no_trade_no_rows() -> void:
	var s := Session.new({"seed": 5, "location": "HAR"})
	check(StockLedger.of_session(s).rows.is_empty(), "nothing held, nothing listed")
	s.dispose()
