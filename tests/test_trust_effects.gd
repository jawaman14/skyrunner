extends TestCase
## What Los Cuervos' and the dealers' trust change (DESIGN 84): from 40 a truce grows, to a full one at 80, that cuts the odds of
## their ambushes, stash raids and pickup interceptions to a quarter on the same draws; the hall sends better or worse men with
## the dealers' trust; a payday met raises it, a short one drops it, a lawyer paid for a jailed man raises it; off, nothing.


class FixedRng extends PyRandom:
	var v := 0.5

	func _init(v_ := 0.5) -> void:
		v = v_

	func random() -> float:
		return v


func after_each() -> void:
	World.use_map(0)
	Trust.EFFECTS = true


func _sess(opts := {}) -> Session:
	var o := {"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "trade": true,
		"logistics": true, "payroll": true, "family": true}
	o.merge(opts, true)
	var s := Session.new(o)
	s.police.frozen = true
	if s.ground != null:
		s.ground._started = true
		for f in s.ground.commanders:
			s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	return s


func test_a_truce_grows_with_los_cuervos_trust() -> void:
	var s := _sess()
	var t: Trust = s.trade.trust
	check_eq(t.of("rival"), Trust.START.rival, "they start wary")
	check_eq([t.restraint(), t.rival_odds()], [0.0, 1.0], "no truce at the start: nothing changes")
	t.own.rival = 40.0
	check_eq(t.rival_odds(), 1.0, "nor at 40")
	t.own.rival = 60.0
	check_near(t.rival_odds(), 1.0 - Trust.RESTRAINT * 0.5, 1e-9, "halfway to a truce")
	t.own.rival = 95.0
	check_near(t.rival_odds(), 0.25, 1e-9, "a full truce: a quarter as often")
	check(str(t.view().filter(func(r): return r.crew == "rival")[0].note).contains("75%"), "the phone says so")
	Trust.EFFECTS = false
	check_eq(t.rival_odds(), 1.0, "off: no truce")
	s.dispose()


func test_a_truce_saves_a_pickup_on_the_same_draw() -> void:
	var s := _sess({"ground_war": true})
	var st := str(s.stash_net.live()[0].id)
	var zone := str(s.stash_net.get_stash(st).zone)
	for m in s.ground.control:
		if m == zone:
			s.ground.control[m] = {"rival": 10.0}
	var p := Pickups.INTERCEPT_MAX  # they hold the district: the full chance, nobody at the door
	s.money = 80000
	s.logistics.pickups.rng = FixedRng.new(p * 0.5)  # a draw a war would lose
	s.command(Roles.PILOT, "stock_order", {"contact": "family", "good": "marijuana", "lb": 20, "stash": st})
	s.time += Pickups.OPENS_S + 1.0
	s.logistics.pickups.update()
	check_eq(str(s.logistics.pickups.done[-1].result), PickupOrder.INTERCEPTED, "no truce: taken")
	s.trade.trust.own.rival = 90.0
	var taken: int = s.logistics.pickups.done.size()
	s.command(Roles.PILOT, "stock_order", {"contact": "family", "good": "marijuana", "lb": 20, "stash": st})
	s.time += Pickups.OPENS_S + 1.0
	s.logistics.pickups.update()
	check_eq(s.logistics.pickups.done.size(), taken, "a truce: the same draw, and they let it pass (it waits at the door)")
	check_eq(s.logistics.pickups.orders.size(), 1, "still ours to collect")
	s.dispose()


func test_the_hall_sends_men_as_good_as_its_trust() -> void:
	var seen := {}
	for d in [0.0, 50.0, 100.0]:
		var s := _sess()
		s.trade.trust.own.dealers = d
		s.payroll.rng.seed(77)
		var w: Dictionary = s.payroll._person("org", "dealer")
		seen[d] = [float(w.skill), float(w.loyalty)]
		s.dispose()
	check(seen[100.0][0] > seen[50.0][0] and seen[50.0][0] > seen[0.0][0], "skill follows trust: %s" % str(seen))
	check(seen[100.0][1] > seen[50.0][1] and seen[50.0][1] > seen[0.0][1], "and loyalty")
	check_near(seen[100.0][0] - seen[50.0][0], Trust.HALL, 0.011, "by up to a tenth")


func test_how_we_pay_moves_the_dealers_trust() -> void:
	var s := _sess()
	var t: Trust = s.trade.trust
	var w: Dictionary = s.payroll._person("org", "dealer")
	s.payroll.candidates["org"].append(w)
	s.money = 80000
	check(s.command(Roles.BOSS, "hire_worker", {"id": w.id})[0], "a man of ours")
	var d0 := t.of("dealers")
	s.payroll._payday()
	check_near(t.of("dealers"), d0 + Trust.PAID, 1e-6, "paid in full")
	s.money = 0
	var d1 := t.of("dealers")
	s.payroll._payday()
	check_near(t.of("dealers"), d1 + Trust.SHORT, 1e-6, "short: the hall hears")
	s.dispose()


func test_off_nothing_changes() -> void:
	Trust.EFFECTS = false
	var s := _sess()
	var t: Trust = s.trade.trust
	t.own.dealers = 100.0
	s.payroll.rng.seed(77)
	var a: Dictionary = s.payroll._person("org", "dealer")
	t.own.dealers = 0.0
	s.payroll.rng.seed(77)
	var b: Dictionary = s.payroll._person("org", "dealer")
	check_eq([a.skill, a.loyalty], [b.skill, b.loyalty], "the hall's men as before")
	var d0 := t.of("dealers")
	var w: Dictionary = s.payroll._person("org", "dealer")
	s.payroll.candidates["org"].append(w)
	s.money = 80000
	s.command(Roles.BOSS, "hire_worker", {"id": w.id})
	s.payroll._payday()
	check_eq(t.of("dealers"), d0, "a payday moves nothing")
	s.dispose()
