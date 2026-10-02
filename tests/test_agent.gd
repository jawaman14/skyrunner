extends TestCase
## Agent: a body on the map with a position, a route and a queue of tasks -
## step 1 of the physical-NPC design rule (docs/ROADMAP.md). Nothing in the
## sim creates one yet, so these tests exercise the class on its own.


func after_each() -> void:
	World.use_map(0)


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
