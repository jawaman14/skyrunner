extends TestCase
## Crates of rounds on the pickup flow (DESIGN 94): ordered from the gun dealer to a stash, paid up front at nine tenths of his
## price; taken in, they join the armoury (which is there now); taken by Los Cuervos, they are theirs; they take no stash room;
## saved with the order; off, none.


class FixedRng extends PyRandom:
	var v := 0.5

	func _init(v_ := 0.5) -> void:
		v = v_

	func random() -> float:
		return v


func after_each() -> void:
	World.use_map(0)
	Arsenal.AMMO_TRADE = true


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
	return s


func _lookout_at(s: Session, stash: String) -> void:
	var w: Dictionary = s.payroll._person("org", "lookout")
	w.status = "assigned"
	w.assigned = "stash-" + stash
	s.payroll.workers.append(w)


func test_rounds_ordered_to_a_stash_join_the_armoury() -> void:
	var s := _sess()
	var st := str(s.stash_net.live()[0].id)
	var ars: Arsenal = s.arsenals["org"]
	var r0: int = int(ars.rounds.mg)
	var each := s.ammo_price("mg")
	var r: Array = s.command(Roles.PILOT, "stock_order", {"good": "ammo", "tier": "mg", "crates": 2, "stash": st})
	check(r[0], "ordered: %s" % str(r[1]))
	check_eq(s.money, 80000 - int(ceil(float(each) * 2 * Pickups.CRATE_PRICE)), "nine tenths of his price, up front")
	check_eq(str(s.logistics.pickups.view()[0].what), "800 machine-gun belts", "the phone says what is coming")
	check_near(s.logistics.storage.incoming(st), 0.0, 1e-9, "rounds take no stash room")
	_lookout_at(s, st)
	s.time += Pickups.OPENS_S + 1.0
	s.logistics.pickups.update()
	check_eq(int(ars.rounds.mg), r0 + 800, "taken in: in the armoury")
	check_eq(str(ars.cache), st, "which is at that stash now")
	s.dispose()


func test_taken_on_the_way_they_arm_los_cuervos() -> void:
	var s := _sess({"ground_war": true})
	var st := str(s.stash_net.live()[0].id)
	var zone := str(s.stash_net.get_stash(st).zone)
	for m in s.ground.control:
		if m == zone:
			s.ground.control[m] = {"rival": 10.0}
	var theirs: int = int(s.arsenals.rival.rounds.rifle)
	s.logistics.pickups.rng = FixedRng.new(0.0)
	check(s.command(Roles.PILOT, "stock_order", {"good": "ammo", "tier": "rifle", "crates": 1, "stash": st})[0], "a crate of rifle rounds")
	s.time += Pickups.OPENS_S + 1.0
	s.logistics.pickups.update()
	check_eq(int(s.arsenals.rival.rounds.rifle), theirs + 600, "theirs now")
	s.dispose()


func test_saved_with_the_order_and_off_none() -> void:
	var s := _sess()
	s.command(Roles.PILOT, "stock_order", {"good": "ammo", "tier": "pistol", "crates": 1})
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	s.dispose()
	var r := _sess()
	StrategicSave.restore(r, d)
	var o: Dictionary = r.logistics.pickups.orders[0]
	check_eq([str(o.good), str(o.tier), int(o.lb)], ["ammo", "pistol", 1000], "a crate of a thousand pistol rounds")
	r.dispose()
	Arsenal.AMMO_TRADE = false
	var off := _sess()
	check(not off.command(Roles.PILOT, "stock_order", {"good": "ammo", "tier": "rifle", "crates": 1})[0], "off: none")
	off.dispose()
