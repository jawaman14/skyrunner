extends TestCase
## Standing orders (DESIGN 95): the boss leaves instructions and the crew carry them out. "Keep" tops a stash up from a named stash
## or the one with most to spare (never below that one's own floor); "cash" brings a stash's cash home over a sum; one truck per
## order at a time; at most six; saved; the AI never adds one; off, none.


func after_each() -> void:
	World.use_map(0)
	StandingOrders.ENABLED = true
	Payroll.BONDS = true


func _sess() -> Session:
	var s := Session.new({"seed": 21, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES,
		"trade": true, "logistics": true, "payroll": true})
	s.police.frozen = true
	s.payroll.ai["org"] = false
	s.update(1.0 / 30)
	s.money = 80000
	s.logistics.auto_supply = false
	for site in s.logistics.stock:
		for g in s.logistics.stock[site]:
			s.logistics.stock[site][g] = 0.0
	return s


func _tick(s: Session) -> void:
	s.logistics.standing.update(StandingOrders.CHECK_S)


func test_keep_tops_a_stash_up_from_the_one_named() -> void:
	var s := _sess()
	var lg: Logistics = s.logistics
	lg.add("docks", "marijuana", 1000.0, "farm")
	check(s.command(Roles.BOSS, "standing_order", {"kind": "keep", "stash": "shack", "good": "marijuana", "below": 100, "fill_to": 300, "from": "docks"})[0], "given")
	_tick(s)
	var c: Array = lg.convoys.values()
	check_eq(c.size(), 1, "a van out")
	if not c.is_empty():
		check_eq([str(c[0].from), str(c[0].to), float(c[0].lb)], ["docks", "shack", 300.0], "from the docks, up to 300")
	_tick(s)
	check_eq(lg.convoys.size(), 1, "one truck an order at a time")
	s.dispose()


func test_keep_without_a_source_takes_the_spare_not_anothers_floor() -> void:
	var s := _sess()
	var lg: Logistics = s.logistics
	lg.add("docks", "marijuana", 350.0, "farm")
	lg.add("barn", "marijuana", 900.0, "farm")
	s.command(Roles.BOSS, "standing_order", {"kind": "keep", "stash": "barn", "good": "marijuana", "below": 600, "fill_to": 800})
	s.command(Roles.BOSS, "standing_order", {"kind": "keep", "stash": "shack", "good": "marijuana", "below": 100, "fill_to": 300})
	_tick(s)
	var to_shack: Array = lg.convoys.values().filter(func(c): return str(c.to) == "shack")
	check_eq(to_shack.size(), 1, "a van to the shack")
	if not to_shack.is_empty():
		check_eq(str(to_shack[0].from), "docks", "from the docks (350 spare), not the barn (900 but kept at 800: 100 spare)")
	s.dispose()


func test_cash_comes_home_over_the_sum() -> void:
	var s := _sess()
	var lg: Logistics = s.logistics
	s.command(Roles.BOSS, "standing_order", {"kind": "cash", "stash": "barn", "over": 2000})
	lg.add_cash("barn", 1500.0, "outside:street", "sales")
	_tick(s)
	check(lg.convoys.is_empty(), "under the sum: it stays")
	lg.add_cash("barn", 1000.0, "outside:street", "sales")
	_tick(s)
	var c: Array = lg.convoys.values()
	check(c.size() == 1 and str(c[0].to) == Logistics.HQ, "over it: home to the club")
	s.dispose()


func test_limits_refusals_and_cancel() -> void:
	var s := _sess()
	check(not s.command(Roles.BOSS, "standing_order", {"kind": "keep", "stash": "shack", "good": "marijuana", "below": 300, "fill_to": 100})[0], "fill to more than the floor")
	check(not s.command(Roles.BOSS, "standing_order", {"kind": "keep", "stash": "nowhere", "good": "marijuana", "below": 1, "fill_to": 2})[0], "a stash there is")
	check(not s.command(Roles.BOSS, "standing_order", {"kind": "launder", "stash": "shack"})[0], "keep or cash")
	for i in StandingOrders.MAX:
		check(s.command(Roles.BOSS, "standing_order", {"kind": "cash", "stash": "shack", "over": 500 + i})[0], "order %d" % (i + 1))
	check(not s.command(Roles.BOSS, "standing_order", {"kind": "cash", "stash": "shack", "over": 900})[0], "six at most")
	check(s.command(Roles.BOSS, "standing_order", {"action": "cancel", "id": 1})[0], "cancelled")
	check_eq(s.logistics.standing.orders.size(), StandingOrders.MAX - 1, "one fewer")
	check(not s.command(Roles.CONTROLLER, "standing_order", {"kind": "cash", "stash": "shack", "over": 900})[0], "not the task force's")
	s.dispose()


func test_saved_and_off_nothing() -> void:
	var s := _sess()
	s.command(Roles.BOSS, "standing_order", {"kind": "keep", "stash": "shack", "good": "marijuana", "below": 100, "fill_to": 300, "from": "docks"})
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	s.dispose()
	var r := _sess()
	StrategicSave.restore(r, d)
	check_eq(r.logistics.standing.orders.size(), 1, "kept")
	check(r.logistics.standing.describe(r.logistics.standing.orders[0]).contains("filled to 300 from Warehouse 7"), "in words: %s" % r.logistics.standing.describe(r.logistics.standing.orders[0]))
	r.dispose()
	StandingOrders.ENABLED = false
	var o := _sess()
	check(not o.command(Roles.BOSS, "standing_order", {"kind": "cash", "stash": "shack", "over": 900})[0], "off: none")
	o.dispose()


func test_the_logistics_view_lists_them() -> void:
	var s := _sess()
	s.command(Roles.BOSS, "standing_order", {"kind": "cash", "stash": "barn", "over": 2000})
	var v: Dictionary = s.logistics.view()
	check_eq(v.standing.size(), 1, "one order listed")
	check(str(v.standing[0].text).contains("bring Finca Morales barn's cash home when it passes $2,000"), "in words: %s" % str(v.standing[0].text))
	s.dispose()


## Task sequences (DESIGN 96): steps in order, the next when the last van is in; a wait holds the route; once and it goes.
func test_a_route_runs_its_steps_in_order() -> void:
	var s := _sess()
	var lg: Logistics = s.logistics
	lg.add("docks", "marijuana", 500.0, "farm")
	check(s.command(Roles.BOSS, "standing_order", {"kind": "route", "steps": [
		{"from": "docks", "to": "shack", "good": "marijuana", "lb": 200},
		{"wait_min": 5},
		{"from": "shack", "to": Logistics.HQ, "good": "cash", "lb": 0}]})[0], "given")
	var so: StandingOrders = lg.standing
	_tick(s)
	var c: Array = lg.convoys.values()
	check(c.size() == 1 and str(c[0].to) == "shack" and float(c[0].lb) == 200.0, "step one: 200 lb to the shack")
	_tick(s)
	check_eq(lg.convoys.size(), 1, "it waits for the van")
	lg.convoys.clear()  # the van is in
	_tick(s)
	check_eq(int(so.orders[0].at), 1, "on to the wait")
	_tick(s)
	_tick(s)
	check_eq(int(so.orders[0].at), 1, "still waiting")
	s.time += 300.0
	lg.add_cash("shack", 900.0, "outside:street", "sales")
	_tick(s)
	_tick(s)
	c = lg.convoys.values()
	check(c.size() == 1 and str(c[0].to) == Logistics.HQ and float(c[0].cash) == 900.0, "step three: all the cash home")
	lg.convoys.clear()
	_tick(s)
	check(so.orders.is_empty(), "done once: the order goes")
	s.dispose()


func test_a_repeating_route_starts_over_and_is_saved() -> void:
	var s := _sess()
	var lg: Logistics = s.logistics
	lg.add("docks", "marijuana", 500.0, "farm")
	s.command(Roles.BOSS, "standing_order", {"kind": "route", "repeat": true, "steps": [
		{"from": "docks", "to": "shack", "good": "marijuana", "lb": 100}, {"wait_min": 10}]})
	var so: StandingOrders = lg.standing
	_tick(s)
	lg.convoys.clear()
	_tick(s)
	_tick(s)
	s.time += 600.0
	_tick(s)
	check_eq(int(so.orders[0].at), 0, "back to the start")
	check(so.describe(so.orders[0]).contains("> 100 lb of marijuana from Warehouse 7, the docks to Mangrove shack, then wait 10 min (again and again)"), "in words: %s" % so.describe(so.orders[0]))
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	s.dispose()
	var r := _sess()
	StrategicSave.restore(r, d)
	var o: Dictionary = r.logistics.standing.orders[0]
	check(str(o.kind) == "route" and bool(o.repeat) and o.steps.size() == 2, "kept")
	r.dispose()


func test_route_refusals() -> void:
	var s := _sess()
	for bad in [[], [{"wait_min": 0}], [{"from": "docks", "to": "docks", "good": "marijuana"}], [{"from": "nowhere", "to": "shack", "good": "marijuana"}],
			[{"from": "docks", "to": "shack", "good": "gold"}]]:
		check(not s.command(Roles.BOSS, "standing_order", {"kind": "route", "steps": bad})[0], "refused: %s" % [bad])
	var seven: Array = []
	for i in 7:
		seven.append({"wait_min": 1})
	check(not s.command(Roles.BOSS, "standing_order", {"kind": "route", "steps": seven})[0], "six steps at most")
	s.dispose()


## Giving them from the logistics page: the pickers make the order, the listed ones cancel.
func test_the_logistics_page_gives_and_cancels_them() -> void:
	var s := _sess()
	var menu := LogisticsMenu.new()
	menu.view_fn = func(): return s.logistics.view()
	menu.cmd_fn = func(n: String, a: Dictionary) -> Array: return s.command(Roles.BOSS, n, a)
	Engine.get_main_loop().root.add_child(menu)
	menu.what_ob.select(LogisticsMenu.WHAT.find("marijuana"))
	menu.from_ob.select(menu._sites.find("docks"))
	menu.to_ob.select(menu._dests.find("shack"))
	menu.amount.value = 300
	check_eq(menu.keep_args(), {"kind": "keep", "stash": "shack", "good": "marijuana", "fill_to": 300.0, "below": 150.0, "from": "docks"}, "keep from the pickers")
	menu._order_keep()
	check_eq(s.logistics.standing.orders.size(), 1, "given")
	menu._route_add_run()
	menu.amount.value = 20  # the box steps by 10
	menu._route_add_wait()
	check_eq(menu.route_steps.size(), 2, "two steps planned")
	menu._route_give(true)
	check_eq(s.logistics.standing.orders.size(), 2, "the route given")
	check(menu.route_steps.is_empty(), "and the plan cleared")
	var o: Dictionary = s.logistics.standing.orders[1]
	check(bool(o.repeat) and o.steps[1].wait_min == 20.0, "looping, with its wait")
	menu.what_ob.select(LogisticsMenu.WHAT.find("the armoury"))
	check(menu.keep_args().has("why"), "the armoury isn't kept stocked")
	menu._act(menu._command("standing_order", {"action": "cancel", "id": 1}))
	check_eq(s.logistics.standing.orders.size(), 1, "cancelled")
	menu.free()
	s.dispose()


## A lookout follows the heat (DESIGN 97): to the hottest house nobody watches, once it is clearly hotter than his; gone with him.
func test_a_lookout_follows_the_heat() -> void:
	var s := _sess()
	Payroll.BONDS = false
	var w: Dictionary = s.payroll._person("org", "lookout")
	s.payroll.candidates.org.append(w)
	check_eq(s.payroll.hire("org", w.id), "", "hired")
	for st in s.stash_net.live():
		st.heat = 0.0
	var a: Dictionary = s.stash_net.get_stash("docks")
	var b: Dictionary = s.stash_net.get_stash("shack")
	a.heat = 30.0
	check(s.command(Roles.BOSS, "standing_order", {"kind": "watch", "lookout": w.id})[0], "given")
	check(not s.command(Roles.BOSS, "standing_order", {"kind": "watch", "lookout": w.id})[0], "one order a lookout")
	_tick(s)
	check_eq(str(s.payroll.get_worker(w.id).assigned), "stash-docks", "to the hottest house")
	b.heat = 35.0
	_tick(s)
	check_eq(str(s.payroll.get_worker(w.id).assigned), "stash-docks", "not for a little more")
	b.heat = 45.0
	_tick(s)
	check_eq(str(s.payroll.get_worker(w.id).assigned), "stash-shack", "for clearly more")
	check(s.logistics.standing.describe(s.logistics.standing.orders[0]).contains("watches whichever house is hottest"), "in words")
	s.payroll.get_worker(w.id).status = "free"
	s.payroll.fire("org", w.id)
	_tick(s)
	check(s.logistics.standing.orders.is_empty(), "the order goes with him")
	check(not s.command(Roles.BOSS, "standing_order", {"kind": "watch", "lookout": "nobody"})[0], "a lookout of ours")
	s.dispose()
	Payroll.BONDS = true
