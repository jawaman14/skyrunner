extends TestCase
## Agent: a body on the map with a position, a route and a queue of tasks -
## step 1 of the physical-NPC design rule (docs/ROADMAP.md). Nothing in the
## sim creates one yet, so these tests exercise the class on its own.


func after_each() -> void:
	World.use_map(0)
	Agent.ENABLED = true


func test_a_foot_agent_walks_straight_and_finishes_the_task() -> void:
	var a := Agent.new("A1", "foot", 0.0, 0.0)
	check(a.idle(), "nothing queued yet")
	a.queue(Agent.Task.new("walk", Vector2(100.0, 0.0)))
	check(not a.idle(), "a task to do")
	var finished := ""
	for i in 200:
		finished = a.update(1.0)
		if finished != "":
			break
	check_eq(finished, "walk", "the walk finished")
	check_near(a.x, 100.0, 0.5, "arrived at x=100")
	check_near(a.y, 0.0, 0.5, "and stayed on the line")
	check(a.idle(), "queue empty again")


func test_it_waits_out_the_task_duration_before_finishing() -> void:
	var a := Agent.new("A2", "foot", 0.0, 0.0)
	a.queue(Agent.Task.new("guard", Vector2(10.0, 0.0), 30.0))
	for i in 20:  # enough ticks to arrive (10 m at 1.4 m/s), not enough to also finish 30 s of guarding
		check_eq(a.update(1.0), "", "still walking or still guarding")
	check_near(a.x, 10.0, 0.1, "arrived already")
	var finished := ""
	for i in 20:
		finished = a.update(1.0)
		if finished != "":
			break
	check_eq(finished, "guard", "guarding finished once dur was spent")


func test_tasks_run_in_order() -> void:
	var a := Agent.new("A3", "foot", 0.0, 0.0)
	a.queue(Agent.Task.new("walk", Vector2(10.0, 0.0)))
	a.queue(Agent.Task.new("walk", Vector2(10.0, 10.0)))
	var order := []
	for i in 60:
		var f := a.update(1.0)
		if f != "":
			order.append(f)
	check_eq(order.size(), 2, "both legs finished: %s" % [order])
	check_near(a.x, 10.0, 0.5, "finished at the second leg's x")
	check_near(a.y, 10.0, 0.5, "and its y")


func test_idle_with_an_empty_queue_does_nothing() -> void:
	var a := Agent.new("A4", "foot", 5.0, 5.0)
	check_eq(a.update(10.0), "", "nothing to do")
	check_eq(a.x, 5.0, "didn't move")
	check_eq(a.y, 5.0, "didn't move")


func test_clear_cancels_everything() -> void:
	var a := Agent.new("A5", "foot", 0.0, 0.0)
	a.queue(Agent.Task.new("walk", Vector2(100.0, 0.0)))
	a.update(1.0)
	a.clear()
	check(a.idle(), "the queue is gone")
	check_eq(a.update(1.0), "", "and nothing finishes")
	check_near(a.x, 1.4, 0.1, "stays wherever it got to, not reset")


func test_a_car_agent_follows_the_road_graph() -> void:
	World.use_map(MapCity.SEED)
	var w := World.new()
	var g := RoadGraph.new(w.map.roads)
	var har := World.airfield("HAR")
	var far := World.airfield("VAL")
	var a := Agent.new("A6", "car", har.x, har.y)
	a.queue(Agent.Task.new("drive", Vector2(far.x, far.y)))
	check(a.route.size() >= 2, "routed, not teleported")
	var straight: float = Vector2(har.x, har.y).distance_to(Vector2(far.x, far.y))
	check(RoadGraph.length(a.route) >= straight - 1.0, "a routed path is never shorter than the crow flies")
	var finished := ""
	for i in 36000:  # city blocks, not a straight shot: give it plenty of simulated time
		finished = a.update(5.0)
		if finished != "":
			break
	check_eq(finished, "drive", "got there in the end")
	check_near(a.x, far.x, 2.0, "at the destination")
	check_near(a.y, far.y, 2.0, "at the destination")


# ------------------------------------------------------------------ step 2: a driver in every truck
## A stash truck on a bent road (or straight, when the war has no road graph), loaded and
## driven the way Logistics does it: with the driver's Agent in charge or with the old timer.
## Returns the time it was delivered. `hold_at` pulls it over for 30 s at that time.
func _truck_arrival(enabled: bool, road: bool, hold_at := -1.0) -> float:
	Agent.ENABLED = enabled
	var net := StashNet.new([{"id": "s", "name": "S", "x": 4000.0, "y": 3000.0, "strip": "HAR"}], PyRandom.new())
	var t := StashNet.Truck.new()
	t.job_id = 1
	t.stash = "s"
	t.x0 = 0.0
	t.y0 = 0.0
	t.x1 = 4000.0
	t.y1 = 3000.0
	t.t0 = 0.0
	if road:
		t.route = PackedVector2Array([Vector2(0, 0), Vector2(2500, 0), Vector2(2500, 2000), Vector2(4000, 3000)])
		t.dur = StashNet.TRUCK_LOAD_S + RoadGraph.length(t.route) / StashNet.TRUCK_MS
	else:
		t.dur = StashNet.TRUCK_LOAD_S + 5000.0 * 1.3 / StashNet.TRUCK_MS
	if Agent.ENABLED:
		t.start_agent()
	net.trucks.append(t)
	var now := 0.0
	var held := false
	while now < 3000.0:
		now += 1.0 / 30.0
		if hold_at >= 0.0 and not held and now >= hold_at:
			held = true
			t.hold(30.0)
		for r in net.update(1.0 / 30.0, now, []):
			if r[1] == "delivered":
				return now
	return -1.0


func test_an_agent_driven_truck_arrives_when_its_timer_would_have() -> void:
	for road in [true, false]:
		var old := _truck_arrival(false, road)
		var now := _truck_arrival(true, road)
		check(old > 0.0 and now > 0.0, "both delivered (road %s): %.1f s, %.1f s" % [road, old, now])
		check_near(now, old, 0.1, "the same minute either way (road %s): %.2f vs %.2f" % [road, now, old])


func test_a_pulled_over_truck_loses_exactly_the_time_it_was_held() -> void:
	for road in [true, false]:
		var free := _truck_arrival(true, road)
		var held := _truck_arrival(true, road, 100.0)
		check_near(held - free, 30.0, 0.1, "30 s parked is 30 s late (road %s): %.2f" % [road, held - free])
		var old := _truck_arrival(false, road, 100.0)
		check_near(held, old, 0.1, "and the timer model agrees (road %s): %.2f vs %.2f" % [road, held, old])


func test_the_trucks_fields_stay_readable_for_the_war() -> void:
	Agent.ENABLED = true
	var t := StashNet.Truck.new()
	t.job_id = 2
	t.x1 = 3000.0
	t.dur = StashNet.TRUCK_LOAD_S + 3000.0 / StashNet.TRUCK_MS
	t.start_agent()
	var net := StashNet.new([{"id": "", "name": "S", "x": 3000.0, "y": 0.0, "strip": "HAR"}], PyRandom.new())
	net.trucks.append(t)
	var now := 0.0
	for i in 30 * 60:  # a minute: 45 s loading, then 15 s on the road
		now += 1.0 / 30.0
		net.update(1.0 / 30.0, now, [])
	check(now - t.t0 > StashNet.TRUCK_LOAD_S, "t0 says it left the yard (%.1f s in)" % (now - t.t0))
	check_near(t.frac(now), (now - t.t0) / t.dur, 1e-6, "frac() is the timer's view of the agent's")
	var p: Array = t.pos(now)
	check_near(p[0], 11.0 * (now - 45.0), 12.0, "and it's where 15 s at 11 m/s puts it: %.0f m" % p[0])
	check(t.left_m() > 2500.0, "most of the road still ahead: %.0f m" % t.left_m())
