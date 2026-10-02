extends TestCase
## Multi-stop rounds (Logistics.cash_round / goods_round): ONE truck through several stashes, taking the cash at
## each as it gets there or dropping product at each in turn, with a driver, fuel and a stop of TRUCK_STOP_S at each.


func after_each() -> void:
	Agent.ENABLED = true
	Logistics.ROUNDS = true
	Fuel.ENABLED = true
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


## Three live stashes to work with.
func _three(s: Session) -> Array:
	return s.stash_net.live().slice(0, 3).map(func(st): return st.id)


## Run the road a second at a time; returns the sim time each stash's cash was taken: {id: t}.
func _run(s: Session, watch: Array, limit := 8000) -> Dictionary:
	var taken := {}
	for i in limit:
		s.time += 1.0
		s._update_stashes(1.0)
		for id in watch:
			if not taken.has(id) and float(s.logistics.cash[id]) == 0.0:
				taken[id] = s.time
		if s.stash_net.trucks.is_empty():
			break
	return taken


func test_the_order_works_its_way_home() -> void:
	var s := _sess()
	var ids: Array = s.stash_net.live().slice(0, 5).map(func(st): return st.id)
	var end: Vector2 = s.logistics.hq_pos()
	var order: Array = s.logistics.plan_order(ids, end)
	check_eq(order.size(), ids.size(), "every stop once")
	var far: String = ids[0]
	for x in ids:
		if s.logistics.pos(x).distance_to(end) > s.logistics.pos(far).distance_to(end):
			far = x
	check_eq(order[0], far, "the farthest from home first (%s)" % s.logistics.name_of(far))
	for i in range(1, order.size()):
		var prev: String = order[i - 1]
		var nearest: String = ""
		for x in ids:
			if order.slice(0, i).has(x):
				continue
			if nearest == "" or s.logistics.pos(x).distance_to(s.logistics.pos(prev)) < s.logistics.pos(nearest).distance_to(s.logistics.pos(prev)):
				nearest = x
		check_eq(order[i], nearest, "then the nearest: step %d" % i)
	s.dispose()


func test_a_cash_round_takes_the_cash_at_each_stop_as_it_gets_there() -> void:
	var s := _sess()
	var ids := _three(s)
	for k in ids.size():
		s.logistics.cash[ids[k]] = 4000.0 * (k + 1)
	var total := 4000.0 + 8000.0 + 12000.0
	var money0 := s.money
	check_eq(s.logistics.cash_round(ids, Logistics.HQ), "", "the order goes")
	check_eq(s.stash_net.trucks.size(), 1, "one truck, not three")
	var t: StashNet.Truck = s.stash_net.trucks[0]
	check_eq(t.stops.size(), 2, "two stops between the legs")
	check_eq(t.legs.size(), 3, "three legs")
	check_eq(float(s.logistics.cash[ids[0]]), 0.0, "it started at the first and took that cash")
	check_eq(float(s.logistics.cash[ids[1]]), 8000.0, "the second is still where it was")
	check_eq(float(s.logistics.cash[ids[2]]), 12000.0, "and the third")
	for i in 60:  # past the loading
		s.time += 1.0
		s._update_stashes(1.0)
	check(t.left_m() > 0.0, "the roster can say how far it has to go: %.0f m" % t.left_m())
	var due := t.t0 + t.dur
	var taken := _run(s, ids)
	check(taken.has(ids[1]) and taken.has(ids[2]), "it got to both")
	check(float(taken[ids[1]]) < float(taken[ids[2]]), "in order (%.0f s, then %.0f s)" % [taken[ids[1]], taken[ids[2]]])
	check(float(taken[ids[1]]) > s.time - 8000.0 and float(taken[ids[2]]) <= due + 2.0, "and the last before it was due")
	check(s.stash_net.trucks.is_empty(), "the truck arrived")
	check(s.money >= money0 + int(total) - 500, "all of it is in the safe (%d of %d, less the fuel)" % [s.money - money0, int(total)])
	s.dispose()


func test_a_round_that_is_stopped_early_loses_only_what_it_had_picked_up() -> void:
	var s := _sess()
	var ids := _three(s)
	for id in ids:
		s.logistics.cash[id] = 5000.0
	check_eq(s.logistics.cash_round(ids, Logistics.HQ), "", "out")
	var t: StashNet.Truck = s.stash_net.trucks[0]
	t.stop_at = 0.02  # a roadblock almost at once
	_run(s, ids, 2000)
	check_eq(s.logistics.lost.cash, 5000, "only the first stop's cash was aboard")
	check_eq(float(s.logistics.cash[ids[1]]), 5000.0, "the others are still in their stashes")
	check_eq(float(s.logistics.cash[ids[2]]), 5000.0, "")
	s.dispose()


func test_a_delivery_round_drops_the_load_stop_by_stop() -> void:
	var s := _sess()
	var ids := _three(s)
	s.logistics.stock[ids[0]]["cocaine"] = 300.0
	s.logistics.sync()
	var before_b: float = s.logistics.stock[ids[1]]["cocaine"]
	var before_c: float = s.logistics.stock[ids[2]]["cocaine"]
	check_eq(s.logistics.goods_round(ids[0], [ids[1], ids[2]], "cocaine", 100.0), "", "out")
	check_near(s.logistics.stock[ids[0]]["cocaine"], 100.0, 0.01, "it took 200 lb from the first")
	var t: StashNet.Truck = s.stash_net.trucks[0]
	check_eq(t.stops.size(), 1, "one stop on the way to the last")
	_run(s, [])
	check_near(s.logistics.stock[ids[1]]["cocaine"], before_b + 100.0, 0.01, "100 lb at the first stop")
	check_near(s.logistics.stock[ids[2]]["cocaine"], before_c + 100.0, 0.01, "and the rest at the last")
	s.dispose()


func test_a_round_has_to_be_a_sensible_one() -> void:
	var s := _sess()
	var ids := _three(s)
	check(s.logistics.cash_round([ids[0]], Logistics.HQ) != "", "one stop is not a round")
	check(s.logistics.cash_round([ids[0], ids[0]], Logistics.HQ) != "", "nor the same one twice")
	check(s.logistics.cash_round([ids[0], "nowhere"], Logistics.HQ) != "", "nor a stop that is not there")
	check(s.logistics.cash_round([ids[0], ids[1]], ids[1]) != "", "nor ending where it stops")
	s.stash_net.get_stash(ids[1]).burned = true
	check(s.logistics.cash_round([ids[0], ids[1]], Logistics.HQ) != "", "nor through a burned stash")
	check(s.logistics.goods_round(ids[0], [ids[0]], "cocaine", 10.0) != "", "a delivery round does not stop where it loaded")
	check(s.logistics.goods_round(ids[0], [ids[2]], "water", 10.0) != "", "or carry what is not a good")
	check(s.stash_net.trucks.is_empty(), "nothing went out")
	s.dispose()


func test_without_bodies_a_round_is_just_a_truck_from_each_stop() -> void:
	Agent.ENABLED = false
	var s := _sess()
	var ids := _three(s)
	for id in ids:
		s.logistics.cash[id] = 3000.0
	check_eq(s.logistics.cash_round(ids, Logistics.HQ), "", "still goes")
	check_eq(s.stash_net.trucks.size(), 3, "as three trucks")
	s.dispose()


func test_the_boss_the_lieutenant_and_the_pilot_can_order_rounds() -> void:
	var s := _sess()
	var ids := _three(s)
	for id in ids:
		s.logistics.cash[id] = 2000.0
	for role in [Roles.BOSS, Roles.LIEUTENANT, Roles.PILOT]:
		check(Roles.allowed(role, "cash_round") and Roles.allowed(role, "goods_round"), "%s may" % role)
	var r: Array = s.command(Roles.BOSS, "cash_round", {"stops": ids, "to": Logistics.HQ, "plan": true})
	check(r[0], "the boss's round goes: %s" % [r])
	check_eq(s.stash_net.trucks.size(), 1, "one truck")
	var t: StashNet.Truck = s.stash_net.trucks[0]
	var planned: Array = s.logistics.plan_order(ids, s.logistics.pos(Logistics.HQ))
	check_eq(s.logistics.convoys[t.job_id].from, planned[0], "planned: it starts at the one farthest from the club")
	s.dispose()


func test_the_ai_sends_one_truck_round_two_fat_stashes_and_not_when_rounds_are_off() -> void:
	for rounds in [true, false]:
		Logistics.ROUNDS = rounds
		var s := _sess()
		s.payroll.ai["org"] = true
		var ids := _three(s)
		for id in ids.slice(0, 2):
			s.logistics.cash[id] = 20000.0
			s.logistics.cash_since[id] = -5000.0
		s.logistics._t = 61.0
		s.logistics.update(1.0)
		check_eq(s.stash_net.trucks.size(), 1, "rounds %s: one truck" % rounds)
		var c: Dictionary = s.logistics.convoys[s.stash_net.trucks[0].job_id]
		check_eq(c.kind, "multi" if rounds else "move", "rounds %s: a %s" % [rounds, "round" if rounds else "single truck"])
		s.dispose()
