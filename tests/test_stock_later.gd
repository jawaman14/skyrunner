extends TestCase
## The stock rework's later parts (DESIGN 81): the bulk buyers pay for the grade and age of what the truck brought; the gun dealer
## is on the pickup flow (crates paid upfront, brought to a stash, into the armoury there); and Los Cuervos can take a lot on its
## way to a stash, likelier where they hold the district and half as likely with one of ours at the door.


class FixedRng extends PyRandom:
	var v := 0.5

	func _init(v_ := 0.5) -> void:
		v = v_

	func random() -> float:
		return v


func after_each() -> void:
	World.use_map(0)
	Grades.BULK = true
	Pickups.INTERCEPTS = true
	Crates.ENABLED = true


func _sess(opts := {}) -> Session:
	var o := {"seed": 21, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES,
		"trade": true, "payroll": true, "logistics": true, "family": true, "money": 80000}
	o.merge(opts, true)
	var s := Session.new(o)
	s.police.frozen = true
	s.payroll.ai["org"] = false
	s.payroll.ai["rival"] = false
	if s.ground != null:
		s.ground._started = true
		for f in s.ground.commanders:
			s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	s.money = 80000
	s.family.respect = 60.0
	return s


func _drive(s: Session) -> void:
	for i in 1500:
		for t in s.stash_net.trucks:
			t.stop_at = -1.0
		s.time += 5.0
		s._update_stashes(5.0)
		if s.stash_net.trucks.is_empty():
			return


func _lookout_at(s: Session, stash: String) -> void:
	var w: Dictionary = s.payroll._person("org", "lookout")
	w.status = "assigned"
	w.assigned = "stash-" + stash
	s.payroll.workers.append(w)


func _stash(s: Session) -> String:
	return str(s.stash_net.live()[0].id)


## What the Morettis pay for ten pounds of cocaine of the source's grade.
func _bulk(source: String) -> int:
	var s := _sess()
	var id := _stash(s)
	s.inventory.reconcile("stash:" + id, "cocaine", 0.0, s.time)
	s.logistics.stock[id]["cocaine"] = 0.0
	s.logistics.add(id, "cocaine", 10.0, source)
	var before: int = s.trade.earned
	check_eq(s.trade.sell("family", "cocaine", 10.0, "rifle", id), "", "on the truck to the Morettis")
	_drive(s)
	var paid: int = s.trade.earned - before
	s.dispose()
	return paid


func test_the_bulk_buyers_pay_for_the_grade() -> void:
	var par := _bulk("farm")  # a source with no grade of its own: 0.5
	var island := _bulk("island")
	check(par > 0, "a par lot sells: $%d" % par)
	check_near(float(island) / float(par), 0.5 + Grades.ISLAND, 0.02, "the island's cocaine fetches (0.5 + grade) of the quote: $%d against $%d" % [island, par])
	Grades.BULK = false
	check_eq(_bulk("island"), par, "off: every lot at the quote, as before")


func test_the_sale_says_the_grade() -> void:
	var s := _sess()
	s.trade.settle("family", "cocaine", 5.0, "rifle", 1.1)
	check(s.trade.last.contains("good grade: +10%"), "a good lot: %s" % s.trade.last)
	s.trade.settle("family", "cocaine", 5.0, "rifle", 1.0)
	check(not s.trade.last.contains("grade"), "a par lot says nothing")
	s.dispose()


func test_the_gun_dealer_brings_crates_to_a_stash() -> void:
	var s := _sess()
	var st := _stash(s)
	var rifles: int = int(s.arsenals.org.stock.rifle)
	var street: int = s.crates.available("rifle")
	var each := s.weapon_price("rifle", true)
	var r: Array = s.command(Roles.PILOT, "stock_order", {"good": "guns", "tier": "rifle", "crates": 2, "stash": st})
	check(r[0], "ordered: %s" % str(r[1]))
	check_eq(s.money, 80000 - int(ceil(each * 16 * Pickups.CRATE_PRICE)), "sixteen rifles at nine tenths of the dealer's price, up front")
	check_eq(s.crates.available("rifle"), street - 16, "spoken for: off the street")
	check_eq(int(s.arsenals.org.stock.rifle), rifles, "not ours yet")
	check_eq(str(s.logistics.pickups.view()[0].what), "16 rifles", "the phone says what is coming")
	_lookout_at(s, st)
	s.time += Pickups.OPENS_S + 1.0
	s.logistics.pickups.update()
	check_eq(int(s.arsenals.org.stock.rifle), rifles + 16, "taken in: in the armoury")
	check_eq(str(s.arsenals.org.cache), st, "which is at that stash now")
	check(s.logistics.pickups.orders.is_empty(), "and the order is done")
	s.dispose()


func test_crates_missed_or_called_off_go_back_on_the_street() -> void:
	var s := _sess()
	var street: int = s.crates.available("mg")
	check(s.command(Roles.PILOT, "stock_order", {"good": "guns", "tier": "mg", "crates": 1})[0], "a crate of machine guns")
	check_eq(s.crates.available("mg"), street - 2, "off the street")
	var id: int = int(s.logistics.pickups.orders[0].id)
	check(s.command(Roles.PILOT, "pickup_cancel", {"id": id})[0], "called off")
	check_eq(s.crates.available("mg"), street, "back on it")
	check(not s.command(Roles.PILOT, "stock_order", {"good": "guns", "tier": "mg", "crates": 9})[0], "one to four crates")
	check(not s.command(Roles.PILOT, "stock_order", {"good": "guns", "tier": "rpg", "crates": 4})[0], "no more than the dealers hold")
	check(not s.command(Roles.PILOT, "stock_order", {"good": "guns", "tier": "cannon", "crates": 1})[0], "a type there is")
	s.dispose()


func test_los_cuervos_take_a_lot_where_they_hold_the_district() -> void:
	var s := _sess({"ground_war": true})
	var st := _stash(s)
	var zone := str(s.stash_net.get_stash(st).zone)
	s.ground.control[zone] = {"rival": 4.0, "org": 4.0}  # half the district is theirs
	var share: float = maxf(0.0, s.ground.rival_share(zone))
	check_near(share, 0.5, 1e-6, "half theirs")
	var p: float = minf(Pickups.INTERCEPT_MAX, Pickups.INTERCEPT_SHARE * share)
	check(s.logistics.pickups.rng != null, "its own stream")
	var heard := []
	s.bus.subscribe("pickup_intercepted", func(e): heard.append(e))
	var before := float(s.logistics.stock[st]["marijuana"])
	s.logistics.pickups.rng = FixedRng.new(p + 0.01)
	check(s.command(Roles.PILOT, "stock_order", {"contact": "family", "good": "marijuana", "lb": 50, "stash": st})[0], "ordered")
	_lookout_at(s, st)
	s.time += Pickups.OPENS_S + 1.0
	s.logistics.pickups.update()
	check_eq(float(s.logistics.stock[st]["marijuana"]), before + 50.0, "a draw over their chance: it arrives")
	if p > 0.0:
		s.logistics.pickups.rng = FixedRng.new(p * Pickups.INTERCEPT_WATCHED - 0.001)
		var money := s.money
		check(s.command(Roles.PILOT, "stock_order", {"contact": "family", "good": "marijuana", "lb": 50, "stash": st})[0], "ordered again")
		var cost := money - s.money
		s.time += Pickups.OPENS_S + 1.0
		s.logistics.pickups.update()
		check_eq(float(s.logistics.stock[st]["marijuana"]), before + 50.0, "a draw under it: nothing arrives")
		check_eq(str(s.logistics.pickups.done[-1].result), PickupOrder.INTERCEPTED, "intercepted")
		check_eq(s.money, money - cost, "and the money paid is gone")
		check(heard.size() == 1 and str(heard[0].text).contains("Los Cuervos"), "we hear who")
	else:
		check(true, "Los Cuervos hold nothing in the %s: no chance" % zone)
	s.dispose()


func test_a_watched_door_halves_the_chance_and_no_war_means_none() -> void:
	var s := _sess({"ground_war": true})
	var st := _stash(s)
	var zone := str(s.stash_net.get_stash(st).zone)
	for m in s.ground.control:
		if m == zone:
			s.ground.control[m] = {"rival": 10.0}
	var share: float = s.ground.rival_share(zone)
	check(share >= 0.8, "Los Cuervos hold the district (%.2f)" % share)
	if share >= 0.8:
		var p := Pickups.INTERCEPT_MAX
		# between the watched and the unwatched chance: taken only with nobody at the door
		s.logistics.pickups.rng = FixedRng.new(p * 0.75)
		s.command(Roles.PILOT, "stock_order", {"contact": "family", "good": "marijuana", "lb": 20, "stash": st})
		s.time += Pickups.OPENS_S + 1.0
		s.logistics.pickups.update()
		check_eq(str(s.logistics.pickups.done[-1].result), PickupOrder.INTERCEPTED, "nobody there: taken")
		_lookout_at(s, st)
		var r2: Array = s.command(Roles.PILOT, "stock_order", {"contact": "family", "good": "marijuana", "lb": 20, "stash": st})
		check(r2[0], "ordered again: %s" % str(r2[1]))
		s.time += Pickups.OPENS_S + 1.0
		s.logistics.pickups.update()
		check_eq(str(s.logistics.pickups.done[-1].result), PickupOrder.COLLECTED, "a lookout there: it gets through")
	s.dispose()
	var q := _sess()
	check(q.ground == null, "no street war")
	q.logistics.pickups.rng = FixedRng.new(0.0)
	var id := _stash(q)
	q.command(Roles.PILOT, "stock_order", {"contact": "family", "good": "marijuana", "lb": 20, "stash": id})
	_lookout_at(q, id)
	q.time += Pickups.OPENS_S + 1.0
	q.logistics.pickups.update()
	check_eq(str(q.logistics.pickups.done[-1].result), PickupOrder.COLLECTED, "nobody to take it")
	q.dispose()


func test_intercepted_crates_arm_los_cuervos() -> void:
	var s := _sess({"ground_war": true})
	var st := _stash(s)
	var zone := str(s.stash_net.get_stash(st).zone)
	for m in s.ground.control:
		if m == zone:
			s.ground.control[m] = {"rival": 10.0}
	check(s.ground.rival_share(zone) >= 0.8, "Los Cuervos hold the district")
	if s.ground.rival_share(zone) >= 0.8:
		var theirs: int = int(s.arsenals.rival.stock.rifle)
		s.logistics.pickups.rng = FixedRng.new(0.0)
		check(s.command(Roles.PILOT, "stock_order", {"good": "guns", "tier": "rifle", "crates": 1, "stash": st})[0], "a crate of rifles")
		s.time += Pickups.OPENS_S + 1.0
		s.logistics.pickups.update()
		check_eq(int(s.arsenals.rival.stock.rifle), theirs + 8, "theirs now")
	s.dispose()


func test_a_crate_order_survives_a_save_and_off_nothing_is_taken() -> void:
	var s := _sess()
	s.command(Roles.PILOT, "stock_order", {"good": "guns", "tier": "pistol", "crates": 1})
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	s.dispose()
	var r := _sess()
	StrategicSave.restore(r, d)
	check_eq(r.logistics.pickups.orders.size(), 1, "the order")
	check_eq([str(r.logistics.pickups.orders[0].good), str(r.logistics.pickups.orders[0].tier), int(r.logistics.pickups.orders[0].lb)], ["guns", "pistol", 12], "a crate of twelve pistols")
	r.dispose()
	Pickups.INTERCEPTS = false
	var o := _sess({"ground_war": true})
	check(o.logistics.pickups.rng == null, "off: no stream, and nothing is ever taken")
	o.dispose()
