extends TestCase
## Fuel for the hired fleet: the price (the economy's fuel multiplier), the cost of a truck run, a driver's tank and
## the stop at the pump that delays the truck, a contract pilot's tank and refuelling, a boat's fuel.


func after_each() -> void:
	Fuel.ENABLED = true
	Agent.ENABLED = true
	World.use_map(0)


func _sess(opts := {}) -> Session:
	var o := {"seed": 21, "map_seed": MapCity.SEED, "location": "FRM", "features": Session.SANDBOX_FEATURES,
		"trade": true, "payroll": true, "logistics": true}
	o.merge(opts, true)
	var s := Session.new(o)
	s.police.frozen = true
	s.payroll.ai["org"] = false
	s.payroll.ai["rival"] = false
	s.update(1.0 / 30)
	return s


func _driver(s: Session) -> Dictionary:
	var w: Dictionary = s.payroll._person("org", "driver")
	w.skill = 0.9
	s.payroll.candidates["org"].append(w)
	s.money += 5000
	check_eq(s.payroll.hire("org", w.id), "", "a driver hired")
	return s.payroll.get_worker(w.id)


func test_the_price_follows_the_economy() -> void:
	var s := _sess()
	var base: float = Session.FUEL_PRICE_PER_LB * Fuel.LB_PER_GAL
	check_near(Fuel.price(s, "avgas"), base * s.econ.fuel_mult(), 0.001, "avgas at the day's price")
	check_near(Fuel.price(s, "ground"), base * Fuel.GROUND_SHARE * s.econ.fuel_mult(), 0.001, "mogas at 55% of it")
	var before := Fuel.price(s, "avgas")
	s.econ.fuel_walk = 1.5
	check(Fuel.price(s, "avgas") > before * 1.4, "a refinery strike: %.2f -> %.2f a gallon" % [before, Fuel.price(s, "avgas")])
	check(Fuel.trend(s) > 0.4, "and the trend says so (%+.0f%%)" % (Fuel.trend(s) * 100.0))
	s.dispose()


func test_a_truck_with_a_full_tank_drives_on_and_one_that_is_low_stops_to_fill_up() -> void:
	var s := _sess()
	var w := _driver(s)
	var t := StashNet.Truck.new()
	t.driver = w.id
	t.dur = 600.0
	var money0 := s.money
	check_eq(Fuel.truck(s, t, 10.0), "", "a short run on a full tank: no stop")
	check_near(float(w.tank), 25.0 - 10.0 * Fuel.TRUCK_GAL_PER_KM, 0.001, "the tank is down by what it burned")
	check_eq(s.money, money0, "and nothing paid yet (it was filled before)")
	check_eq(t.refuel_s, 0.0, "no time lost")
	# 21.5 gal left; 60 km needs 21 gal: not enough over the reserve -> fills up first
	var note := Fuel.truck(s, t, 60.0)
	check(note.begins_with("filled up first"), "a long run: %s" % note)
	check(t.refuel_s >= Fuel.TRUCK_FILL_S, "the stop takes time (%.0f s)" % t.refuel_s)
	check_eq(t.dur, 600.0 + t.refuel_s, "and it is part of the trip")
	check(s.money < money0, "and costs money ($%d)" % (money0 - s.money))
	check_near(float(w.tank), 25.0 - 60.0 * Fuel.TRUCK_GAL_PER_KM, 0.01, "the tank after the run")
	check(float(s.fuel_spent.org) > 0.0, "the fleet's fuel bill is tracked")
	s.dispose()


func test_a_run_longer_than_a_tank_stops_more_than_once() -> void:
	var s := _sess()
	var w := _driver(s)
	var t := StashNet.Truck.new()
	t.driver = w.id
	t.dur = 100.0
	Fuel.truck(s, t, 200.0)  # 70 gal: three tanks
	check(t.refuel_s >= 2.0 * Fuel.TRUCK_FILL_S, "more than one fill (%.0f s)" % t.refuel_s)
	check(float(w.tank) >= 0.0 and float(w.tank) <= Fuel.TRUCK_TANK_GAL, "and the tank ends sensible (%.1f)" % float(w.tank))
	s.dispose()


func test_a_truck_with_no_driver_on_the_payroll_pays_at_the_pump() -> void:
	var s := _sess()
	var t := StashNet.Truck.new()
	t.dur = 100.0
	var money0 := s.money
	check_eq(Fuel.truck(s, t, 20.0), "", "no stop to talk about")
	var cost := 20.0 * Fuel.TRUCK_GAL_PER_KM * Fuel.price(s, "ground")
	check(absi((money0 - s.money) - int(round(cost))) <= 1, "the run's fuel is paid ($%d of $%.0f)" % [money0 - s.money, cost])
	s.dispose()


func test_a_dispatched_truck_fills_up_first_and_arrives_late_by_the_stop() -> void:
	var s := _sess()
	var w := _driver(s)
	w["tank"] = 4.0  # nearly empty
	s.logistics.cash["camp"] = 12000.0
	var money0 := s.money
	check_eq(s.command(Roles.BOSS, "move_cash", {"from": "camp", "to": "hq"})[0], true, "the order goes")
	var t: StashNet.Truck = s.stash_net.trucks[0]
	check(t.refuel_s > 0.0, "he fills up first (%.0f s)" % t.refuel_s)
	check(s.money < money0 - 5, "at the organisation's expense")
	check("filled up first" in str(s.logistics.last), "and the message says so: %s" % s.logistics.last)
	check(t.agent != null and t.agent.tasks.size() >= 3, "his body queues load, refuel, drive")
	var due := t.t0 + t.dur
	var t_in := -1.0
	for i in 6000:
		s.time += 1.0
		s._update_stashes(1.0)
		if s.stash_net.trucks.is_empty():
			t_in = s.time
			break
	check(t_in > 0.0, "the truck got there")
	check(absf(t_in - due) < 3.0, "when the trip said, the stop included (%.0f vs %.0f)" % [t_in, due])
	s.dispose()


func test_a_contract_pilot_flies_until_his_tank_is_low_then_refuels() -> void:
	var s := _sess()
	var w: Dictionary = s.payroll._person("org", "pilot")
	var delay := []
	var money0 := s.money
	check(Fuel.pilot_ready(s, "org", w, delay), "a full tank: off he goes")
	check(Fuel.pilot_ready(s, "org", w, delay), "and again")
	check_near(float(w.tank), 40.0 - 2.0 * Fuel.PLANE_RUN_GAL, 0.001, "two runs down the tank")
	check(not Fuel.pilot_ready(s, "org", w, delay), "the third would not be covered: he refuels instead")
	check_eq(delay, [Fuel.PLANE_FILL_S], "which takes a while")
	check_eq(float(w.tank), Fuel.PLANE_TANK_GAL, "and he is full again")
	check(s.money < money0, "paid at avgas ($%d)" % (money0 - s.money))
	s.dispose()


func test_the_payroll_sends_a_pilot_to_the_pump_between_runs() -> void:
	var s := _sess()
	s.money = 100000
	var w: Dictionary = s.payroll._person("org", "pilot")
	w.skill = 0.9
	w.loyalty = 0.9
	s.payroll.candidates["org"].append(w)
	check_eq(s.payroll.hire("org", w.id), "", "a pilot hired")
	var p: Dictionary = s.payroll.get_worker(w.id)
	p["tank"] = 5.0  # not enough for a run
	s.payroll._run_t[w.id] = 0.0
	var spent0 := float(s.fuel_spent.org)
	s.time = 10.0
	s.payroll._pilot_runs()
	check(float(s.fuel_spent.org) > spent0, "he filled up")
	check_eq(float(p.tank), Fuel.PLANE_TANK_GAL, "to the top")
	check(float(s.payroll._run_t[w.id]) >= s.time + Fuel.PLANE_FILL_S, "and the run waits for him")
	s.dispose()


func test_a_boat_going_out_costs_fuel() -> void:
	var s := _sess()
	var money0 := s.money
	var cost := Fuel.boat(s, 25.0)
	check_near(cost, 25.0 * Fuel.BOAT_GAL_PER_KM * Fuel.price(s, "ground"), 0.001, "gallons by distance at the pump price")
	check(absi((money0 - s.money) - int(round(cost))) <= 1, "taken from the money")
	s.dispose()


func test_switched_off_nothing_is_burned() -> void:
	Fuel.ENABLED = false
	var s := _sess()
	var w := _driver(s)
	var t := StashNet.Truck.new()
	t.driver = w.id
	t.dur = 100.0
	var money0 := s.money
	check_eq(Fuel.truck(s, t, 100.0), "", "no stop")
	check_eq(Fuel.boat(s, 100.0), 0.0, "no boat fuel")
	check(Fuel.pilot_ready(s, "org", w, []), "no tank to watch")
	check_eq(s.money, money0, "no bill")
	s.dispose()


func test_the_view_and_the_save_carry_the_fuel_bill() -> void:
	var s := _sess()
	var v: Dictionary = s.logistics.view()
	check(v.has("fuel") and float(v.fuel.ground) > 0.0 and float(v.fuel.avgas) > float(v.fuel.ground), "the view has the prices: %s" % [v.fuel])
	s.fuel_spent["org"] = 1234.0
	var d := StrategicSave.capture(s)
	check_eq(float(d.fuel_spent.org), 1234.0, "the bill is in the save")
	var t := _sess()
	StrategicSave.restore(t, JSON.parse_string(JSON.stringify(d)))
	check_eq(float(t.fuel_spent.org), 1234.0, "and comes back")
	s.dispose()
	t.dispose()
