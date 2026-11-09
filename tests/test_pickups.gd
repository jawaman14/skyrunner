extends TestCase
## Stock bought upfront and collected (DESIGN 51.2, slice 3): ordered from a contact and paid for, brought to a stash in a window,
## collected by the pilot or a lookout there; late once it comes again an hour on (and costs standing), late twice it's gone;
## cancelled, the money is lost; saved.


func after_each() -> void:
	World.use_map(0)


func _city() -> Session:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "trade": true,
		"logistics": true, "payroll": true, "family": true, "money": 50000})
	s.police.frozen = true
	s.update(1.0 / 30)
	s.money = 50000
	return s


func _lookout_at(s: Session, stash: String) -> void:
	var w: Dictionary = s.payroll._person("org", "lookout")
	w.status = "assigned"
	w.assigned = "stash-" + stash
	s.payroll.workers.append(w)


func _stash(s: Session) -> String:
	return str(s.stash_net.live()[0].id)


func test_order_pays_upfront_and_a_lookout_collects() -> void:
	var s := _city()
	var lg: Logistics = s.logistics
	var st := _stash(s)
	var before := float(lg.stock[st]["marijuana"])
	var cost := int(ceil(50.0 * lg.pickups.price("family", "marijuana")))
	var r: Array = s.command(Roles.PILOT, "stock_order", {"contact": "family", "good": "marijuana", "lb": 50, "stash": st})
	check(r[0], "ordered: %s" % str(r[1]))
	check_eq(int(s.money), 50000 - cost, "paid upfront")
	_lookout_at(s, st)
	s.time += Pickups.OPENS_S - 1.0
	lg.pickups.update()
	check_eq(float(lg.stock[st]["marijuana"]), before, "not before the window")
	s.time += 2.0
	lg.pickups.update()
	check_eq(float(lg.stock[st]["marijuana"]), before + 50.0, "the lookout takes it in when the window opens")
	check(lg.pickups.orders.is_empty() and str(lg.pickups.done[-1].result) == PickupOrder.COLLECTED, "and the order is done")
	check(absf(s.ledger.total()) < 0.01, "the ledger balances")
	s.dispose()


func test_late_comes_again_then_is_lost() -> void:
	var s := _city()
	var lg: Logistics = s.logistics
	var st := _stash(s)
	check(s.command(Roles.PILOT, "stock_order", {"contact": "family", "good": "marijuana", "lb": 20, "stash": st})[0], "ordered")
	var respect: float = s.family.respect if s.family != null else 0.0
	s.time += Pickups.OPENS_S + Pickups.WINDOW_S + 1.0
	lg.pickups.update()
	lg.pickups.update()
	check_eq(lg.pickups.orders.size(), 1, "late once: it comes round again")
	check_eq(int(lg.pickups.orders[0].missed), 1, "counted")
	if s.family != null:
		check(s.family.respect < respect, "and the Morettis think less of us")
	s.time += Pickups.REDO_S + 1.0
	lg.pickups.update()
	lg.pickups.update()
	check(lg.pickups.orders.is_empty(), "late twice: gone")
	check_eq(str(lg.pickups.done[-1].result), PickupOrder.LATE, "as late")
	s.dispose()


func test_the_pilot_on_the_ground_collects() -> void:
	var s := _city()
	var lg: Logistics = s.logistics
	var st := _stash(s)
	check(s.command(Roles.PILOT, "stock_order", {"contact": "family", "good": "marijuana", "lb": 10, "stash": st})[0], "ordered")
	var p: Vector2 = lg.pos(st)
	s.state.x = p.x + 100.0
	s.state.y = p.y
	s.state.on_ground = true
	s.state.gs_kts = 0.0
	check_eq(lg.pickups.present(st), "pilot", "stopped on the ground by the stash")
	s.state.gs_kts = 40.0
	check_eq(lg.pickups.present(st), "", "not while rolling past")
	s.dispose()


func test_cancel_loses_the_money() -> void:
	var s := _city()
	var st := _stash(s)
	s.command(Roles.PILOT, "stock_order", {"contact": "family", "good": "marijuana", "lb": 20, "stash": st})
	var after := int(s.money)
	var id := int(s.logistics.pickups.orders[0].id)
	check(s.command(Roles.PILOT, "pickup_cancel", {"id": id})[0], "called off")
	check_eq(int(s.money), after, "no refund")
	check(s.logistics.pickups.orders.is_empty(), "the order is gone")
	s.dispose()


func test_refusals() -> void:
	var s := _city()
	check(not s.command(Roles.PILOT, "stock_order", {"contact": "rival", "good": "marijuana", "lb": 20})[0], "Los Cuervos don't sell to us")
	check(not s.command(Roles.PILOT, "stock_order", {"contact": "family", "good": "marijuana", "lb": 2})[0], "too small")
	s.money = 0
	check(not s.command(Roles.PILOT, "stock_order", {"contact": "family", "good": "marijuana", "lb": 50})[0], "can't pay")
	s.dispose()


func test_a_pickup_survives_a_save() -> void:
	var s := _city()
	var st := _stash(s)
	s.command(Roles.PILOT, "stock_order", {"contact": "family", "good": "marijuana", "lb": 30, "stash": st})
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.logistics.pickups.capture()))
	var t := s.time
	s.dispose()
	var s2 := _city()
	s2.time = t
	s2.logistics.pickups.restore(d)
	check_eq(s2.logistics.pickups.orders.size(), 1, "the order is back")
	_lookout_at(s2, st)
	var before := float(s2.logistics.stock[st]["marijuana"])
	s2.time += Pickups.OPENS_S + 1.0
	s2.logistics.pickups.update()
	check_eq(float(s2.logistics.stock[st]["marijuana"]), before + 30.0, "and is collected as before")
	s2.dispose()


func test_off_it_is_refused() -> void:
	var saved := Switches.snapshot()
	Pickups.ENABLED = false
	var s := _city()
	check(not s.command(Roles.PILOT, "stock_order", {"contact": "family", "good": "marijuana", "lb": 20})[0], "off: no orders")
	s.dispose()
	Switches.restore(saved)
