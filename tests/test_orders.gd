extends TestCase
## Buyers' orders (Orders, owner 18 Oct): a buyer asks for a quantity by a time and pays a premium when a bulk sale settles in
## time; how long he gives follows the street's demand (a rush is 10 to 20 minutes, otherwise a night's work); a missed order
## costs the crew's trust. They ride on Trade, have their own random stream, and are saved.


func after_each() -> void:
	World.use_map(0)
	Trade.ENABLED = true
	Orders.ENABLED = true


func _sess(seed_ := 21) -> Session:
	var o := {"seed": seed_, "map_seed": MapCity.SEED, "location": "FRM", "features": Session.SANDBOX_FEATURES, "trade": true, "payroll": true,
		"family": true, "agency": true}
	var s := Session.new(o)
	s.police.frozen = true
	s.payroll.ai["org"] = false
	s.payroll.ai["rival"] = false
	s.update(1.0 / 30)
	s.trade.connected = true
	s.trade.stock.cocaine = 400.0
	s.trade.stock.marijuana = 2000.0
	s.family.respect = 60.0
	return s


## Run Trade's minute clock until an order appears (a bounded number of minutes), or fail.
func _until_posted(s: Session, minutes := 400) -> Dictionary:
	for i in minutes:
		s.time += 60.0
		s.trade.update(60.0)
		s.trade._t = 0.0
		if not s.trade.orders.open.is_empty():
			return s.trade.orders.open[0]
	return {}


func _force(s: Session, buyer: String, good: String, qty: float, premium: float, seconds: float) -> Dictionary:
	var o := {"id": 99, "buyer": buyer, "good": good, "qty": qty, "left": qty, "premium": premium, "kind": "night", "posted": s.time, "due": s.time + seconds}
	s.trade.orders.open.append(o)
	s.trade.appetite[buyer][good] = maxf(float(s.trade.appetite[buyer][good]), qty)
	return o


func test_a_session_with_trade_has_orders_and_one_without_does_not() -> void:
	var s := _sess()
	check(s.trade.orders != null, "orders ride on trade")
	s.dispose()
	Orders.ENABLED = false
	var off := _sess()
	check(off.trade.orders == null, "off with the switch")
	off.dispose()


func test_an_order_appears_with_a_deadline_that_follows_demand() -> void:
	var s := _sess()
	var o := _until_posted(s)
	check(not o.is_empty(), "an order was posted within a few hours")
	if not o.is_empty():
		var window: float = float(o.due) - float(o.posted)
		if o.kind == "rush":
			check(window >= Orders.RUSH_S[0] and window <= Orders.RUSH_S[1], "a rush gives 10 to 20 minutes (%.0f s)" % window)
			check(float(o.premium) >= Orders.PREMIUM.rush[0], "and pays more")
		else:
			check(window >= Orders.NIGHT_S[0] and window <= Orders.NIGHT_S[1], "otherwise a night's work (%.0f s)" % window)
		check(s.trade.appetite[o.buyer][o.good] >= float(o.qty), "the buyer has room for what he asked for")
	s.dispose()


func test_hungry_streets_make_rushes_and_quiet_ones_nights() -> void:
	var s := _sess()
	var mk: Market = s.econ.market
	mk.demand.cocaine.town = 2.0
	mk.supply.cocaine.town = 1.0
	check(s.trade.orders.pressure("cocaine", "town") >= Orders.RUSH_PRESSURE, "demand twice supply is a rush")
	mk.demand.cocaine.town = 1.0
	mk.supply.cocaine.town = 1.4
	check(s.trade.orders.pressure("cocaine", "town") < Orders.RUSH_PRESSURE, "a glut is not")
	s.dispose()


func test_filling_an_order_in_time_pays_the_premium_and_raises_the_crews_trust() -> void:
	var s := _sess()
	var o := _force(s, "family", "cocaine", 20.0, 1.3, 900.0)
	var q := s.trade.quote("family", "cocaine")
	var money0 := s.money
	var respect0: float = s.family.respect
	s.trade.settle("family", "cocaine", 20.0)
	var plain := int(q.price * 20.0)
	var bonus := int(q.price * 20.0 * 0.3)
	check_eq(s.trade.orders.open.size(), 0, "the order is done")
	check_eq(s.trade.earned, plain + bonus, "paid the premium on top (%d + %d)" % [plain, bonus])
	check(s.family.respect >= respect0 + Orders.DONE_TRUST, "and the Morettis trust us more")
	check_eq(str(s.trade.orders.history.back().result), "filled", "it is in the history")
	s.dispose()


func test_a_part_delivery_pays_on_the_part_and_a_missed_one_costs_trust() -> void:
	var s := _sess()
	_force(s, "family", "cocaine", 30.0, 1.25, 600.0)
	s.trade.settle("family", "cocaine", 10.0)
	check_eq(s.trade.orders.open.size(), 1, "a part leaves it open")
	check_near(float(s.trade.orders.open[0].left), 20.0, 0.01, "twenty pounds still wanted")
	var respect0: float = s.family.respect
	s.time += 601.0
	s.trade.orders.update(s.time, 60.0)
	check(s.trade.orders.open.is_empty(), "past the deadline it is gone")
	var lost := respect0 - float(s.family.respect)
	check(lost > 0.0 and lost < Orders.FAIL_TRUST, "a part delivered costs only part of the trust (%.2f)" % lost)
	check_eq(str(s.trade.orders.history.back().result), "part", "recorded as a part")
	_force(s, "agency", "cocaine", 40.0, 1.2, 100.0)
	var trust0: float = s.agency.trust
	s.time += 101.0
	s.trade.orders.update(s.time, 60.0)
	check_near(trust0 - float(s.agency.trust), Orders.FAIL_TRUST, 0.01, "nothing delivered costs the Company's trust in full")
	s.dispose()


func test_a_truck_that_settles_after_the_deadline_is_late() -> void:
	var s := _sess()
	_force(s, "family", "cocaine", 20.0, 1.3, 100.0)
	s.time += 130.0  # past the deadline, before Trade's next minute check has run
	var respect0: float = s.family.respect
	var earned0: int = s.trade.earned
	var plain := int(s.trade.quote("family", "cocaine").price * 20.0)
	s.trade.settle("family", "cocaine", 20.0)
	check_eq(s.trade.earned - earned0, plain, "paid the plain price, no premium")
	check(s.trade.orders.open.is_empty(), "the order is gone")
	check(s.family.respect < respect0 + Orders.DONE_TRUST, "and no completion trust (it was missed)")
	check_eq(str(s.trade.orders.history.back().result), "missed", "recorded as missed")
	s.dispose()


func test_the_message_says_the_premium_is_above_the_buyers_usual_price() -> void:
	var s := _sess()
	var told := []
	s.bus.subscribe("order_posted", func(e): told.append(e.text))
	_until_posted(s)
	check(not told.is_empty(), "an order was announced")
	if not told.is_empty():
		check(str(told[0]).contains("above his usual price"), "worded against the buyer's own price: %s" % told[0])
		check(not str(told[0]).contains("street price"), "not against the street price")
	s.dispose()


func test_a_sale_to_another_buyer_or_good_does_not_touch_an_order() -> void:
	var s := _sess()
	_force(s, "family", "cocaine", 20.0, 1.3, 900.0)
	var earned0: int = s.trade.earned
	var plain := int(s.trade.quote("family", "marijuana").price * 50.0)
	s.trade.settle("family", "marijuana", 50.0)
	check_eq(float(s.trade.orders.open[0].left), 20.0, "another good leaves the order alone")
	check_eq(s.trade.earned - earned0, plain, "and is paid its plain price")
	s.trade.settle("agency", "cocaine", 20.0)
	check_eq(float(s.trade.orders.open[0].left), 20.0, "another buyer leaves it alone")
	s.dispose()


func test_the_board_and_the_orders_reach_the_trade_view_and_survive_a_save() -> void:
	var s := _sess()
	_force(s, "family", "cocaine", 20.0, 1.3, 900.0)
	var v: Dictionary = s.trade.view("org")
	check(v.has("orders") and v.orders.open.size() == 1, "the open order is in the view")
	check(v.orders.board.goods.has("cocaine") and v.orders.board.goods.cocaine.has("town"), "and the market board by district")
	var row: Dictionary = v.orders.board.goods.cocaine.town
	check(row.has("price") and row.has("pressure") and row.trend in ["up", "down", "flat"], "price, pressure and a trend")
	var saved: Dictionary = SaveVars.through_json(SaveVars.capture(s.trade.orders, StrategicSave.ORDERS))
	var s2 := _sess(22)
	SaveVars.restore(s2.trade.orders, saved, StrategicSave.ORDERS, StrategicSave.ORDERS_INTS)
	check_eq(s2.trade.orders.open.size(), 1, "the order comes back")
	check_eq(int(s2.trade.orders.open[0].id), 99, "with its id an int")
	check_near(float(s2.trade.orders.open[0].left), 20.0, 0.001, "and what was left")
	s.dispose()
	s2.dispose()


func test_the_same_seed_posts_the_same_order() -> void:
	var a := _sess(33)
	var b := _sess(33)
	var oa := _until_posted(a, 300)
	var ob := _until_posted(b, 300)
	check(not oa.is_empty() and not ob.is_empty(), "both posted one")
	check(oa.buyer == ob.buyer and oa.good == ob.good and oa.qty == ob.qty and oa.premium == ob.premium, "the same buyer, good, size and premium")
	a.dispose()
	b.dispose()
