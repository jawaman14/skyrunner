extends TestCase
## Infamy (DESIGN 100; the owner, 22 Nov, D-102: "renown is the same as infamy, so more heat from other factions and higher-risk
## rewards"): Los Cuervos come for a bigger name (their odds x 1.15 a tier, on the same draws); the heat dial's Infamous setting opens
## for a Feared name; the week's hot job pays more a tier; off, none of it.


class FixedRng extends PyRandom:
	var v := 0.5

	func _init(v_ := 0.5) -> void:
		v = v_

	func random() -> float:
		return v


func after_each() -> void:
	World.use_map(0)
	Renown.INFAMY = true


func _sess(opts := {}) -> Session:
	var o := {"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "trade": true,
		"logistics": true, "payroll": true, "family": true, "renown": true}
	o.merge(opts, true)
	var s := Session.new(o)
	s.police.frozen = true
	if s.ground != null:
		s.ground._started = true
		for f in s.ground.commanders:
			s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	return s


func _tier(s: Session, t: int) -> void:
	s.renown.score = Renown.TIERS[t]


func test_a_bigger_name_draws_los_cuervos() -> void:
	var s := _sess()
	check_eq(s.renown.rival_mult(), 1.0, "a nobody: as before")
	_tier(s, 2)
	check_near(s.renown.rival_mult(), 1.3, 1e-9, "known: 30% more")
	_tier(s, 4)
	check_near(Renown.rival_mult_of(s), 1.6, 1e-9, "a legend: 60% more")
	check(Renown.effects_text(4).contains("Los Cuervos come for you 60% more often"), "the panel says so: %s" % Renown.effects_text(4))
	Renown.INFAMY = false
	check_eq(s.renown.rival_mult(), 1.0, "off: none")
	s.dispose()
	var plain := Session.new({"seed": 5, "location": "HAR"})
	check_eq(Renown.rival_mult_of(plain), 1.0, "no renown in the game: none")
	plain.dispose()


func test_a_legend_loses_the_pickup_a_nobody_keeps_on_the_same_draw() -> void:
	var s := _sess({"ground_war": true})
	var st := str(s.stash_net.live()[0].id)
	var zone := str(s.stash_net.get_stash(st).zone)
	for m in s.ground.control:
		if m == zone:
			s.ground.control[m] = {"rival": 10.0}
	s.money = 80000
	s.logistics.pickups.rng = FixedRng.new(Pickups.INTERCEPT_MAX * 1.2)  # a draw a nobody survives
	s.command(Roles.PILOT, "stock_order", {"contact": "family", "good": "marijuana", "lb": 20, "stash": st})
	s.time += Pickups.OPENS_S + 1.0
	s.logistics.pickups.update()
	check(s.logistics.pickups.done.is_empty() or str(s.logistics.pickups.done[-1].result) != PickupOrder.INTERCEPTED, "a nobody: let through")
	for o in s.logistics.pickups.orders.duplicate():
		s.command(Roles.PILOT, "pickup_cancel", {"id": int(o.id)})
	_tier(s, 4)
	s.command(Roles.PILOT, "stock_order", {"contact": "family", "good": "marijuana", "lb": 20, "stash": st})
	s.time += Pickups.OPENS_S + 1.0
	s.logistics.pickups.update()
	check_eq(str(s.logistics.pickups.done[-1].result), PickupOrder.INTERCEPTED, "a legend: the same draw, taken")
	s.dispose()


func test_the_dial_goes_to_infamous_for_a_feared_name() -> void:
	var s := _sess()
	s.parked = true
	_tier(s, 2)
	check(not s.command(Roles.PILOT, "heat_dial", {"level": 4})[0], "known is not enough")
	check_eq(s.heat_dial.top(), 3, "Burning is the top")
	_tier(s, Renown.INFAMOUS_TIER)
	check(s.command(Roles.PILOT, "heat_dial", {"level": 4})[0], "feared: Infamous")
	check_near(s.heat_dial.pay_mult(), 1.75, 1e-9, "the most pay")
	check_near(float(s.police.dial_mult), 2.0, 1e-9, "the most heat")
	s.dispose()


func test_the_hot_job_pays_more_a_tier() -> void:
	var s := _sess()
	check_near(s.black_market.hot_pay(), BlackMarket.HOT_PAY, 1e-9, "a nobody: x1.5")
	_tier(s, 4)
	check_near(s.black_market.hot_pay(), BlackMarket.HOT_PAY + 1.0, 1e-9, "a legend: x2.5")
	Renown.INFAMY = false
	check_near(s.black_market.hot_pay(), BlackMarket.HOT_PAY, 1e-9, "off: x1.5")
	s.dispose()
