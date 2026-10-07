extends TestCase
## Physical NPCs, step 6: the payroll's people are bodies (People): a lookout at his stash, the rest round
## the base, a new hire driving out to his post, the soldiers and drivers being bodies somewhere else.


func after_each() -> void:
	Agent.ENABLED = true
	World.use_map(0)
	Terrain.natural = false


func _sess(seed := 12) -> Session:
	Terrain.natural = true  # Physical Costa Brava routes use the game terrain, not the legacy parity surface.
	var s := Session.new({"seed": seed, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES,
		"payroll": true, "ground_war": true, "trade": true, "logistics": true})
	s.police.frozen = true
	s.payroll.ai["org"] = false
	s.payroll.ai["rival"] = false
	s.ground._started = true
	for f in s.ground.commanders:
		s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	s.money = 100000
	return s


func _hire(s: Session, role: String, hired_at := -1.0) -> String:
	var w: Dictionary = s.payroll._person("org", role)
	w.loyalty = 0.8
	s.payroll.candidates.org.append(w)
	check_eq(s.payroll.hire("org", w.id), "", "hired a %s" % role)
	if hired_at != -1.0:
		s.payroll.get_worker(w.id).hired_at = hired_at
	return w.id


func _run(s: Session, seconds: int) -> void:
	for i in seconds:
		s.payroll.update(1.0)


func test_a_new_lookout_drives_out_to_his_stash() -> void:
	var s := _sess()
	s.time = 100000.0
	var lk := _hire(s, "lookout", s.time)
	var st: Dictionary = s.stash_net.stashes[0]
	check_eq(s.payroll.post_lookout(lk, st.id), "", "posted")
	_run(s, 2)
	var body: Agent = s.payroll.people.bodies.get(lk)
	check(body != null, "he has a body")
	var base: Vector2 = s.payroll.people._base("org")
	check(body.pos().distance_to(base) < 400.0, "he starts at the base (%.0f m)" % body.pos().distance_to(base))
	var far: float = Vector2(st.x, st.y).distance_to(base)
	check(far > GroundWar.AVOID_M, "the stash is a drive away (%.0f m)" % far)
	check_eq(body.kind, "car", "a long way: he drives")
	check(s.payroll.doing(s.payroll.get_worker(lk)).begins_with("heading out to "), "the roster says so: %s" % s.payroll.doing(s.payroll.get_worker(lk)))
	var ticks := 0
	while not body.idle() and ticks < 6000:
		_run(s, 1)
		ticks += 1
	check(body.idle(), "he got there (%d s)" % ticks)
	check(body.pos().distance_to(Vector2(st.x, st.y)) < 25.0, "and stands in the street by the stash (%.1f m)" % body.pos().distance_to(Vector2(st.x, st.y)))
	check(s.payroll.doing(s.payroll.get_worker(lk)).begins_with("watching "), "now he watches it: %s" % s.payroll.doing(s.payroll.get_worker(lk)))
	s.dispose()


func test_an_old_hand_is_already_at_his_post() -> void:
	var s := _sess()
	s.time = 100000.0
	var lk := _hire(s, "lookout", 0.0)  # hired long ago: a game that was just loaded
	var st: Dictionary = s.stash_net.stashes[0]
	s.payroll.post_lookout(lk, st.id)
	_run(s, 2)
	var body: Agent = s.payroll.people.bodies[lk]
	check(body.pos().distance_to(Vector2(st.x, st.y)) < 25.0, "already there")
	check(body.idle(), "and not going anywhere")
	s.dispose()


func test_free_hands_stand_round_the_base_and_soldiers_are_their_squads_men() -> void:
	var s := _sess()
	s.time = 100000.0
	var acct := _hire(s, "accountant", 0.0)
	var soldiers := []
	for i in 4:
		soldiers.append(_hire(s, "soldier", 0.0))
	var q = s.ground.recruit("org", "foot", null)
	check(q is GroundWar.Squad, "a squad raised")
	_run(s, 3)
	var base: Vector2 = s.payroll.people._base("org")
	check(s.payroll.people.bodies[acct].pos().distance_to(base) < 20.0, "the accountant is at the base")
	for id in soldiers:
		check(not s.payroll.people.bodies.has(id), "%s is one of the squad's men, not a second body" % id)
	check_eq(s.payroll.people.draw_list().size(), 1, "one person to draw")
	s.dispose()


func test_no_bodies_with_agents_off() -> void:
	Agent.ENABLED = false
	var s := _sess()
	_hire(s, "lookout", 0.0)
	_run(s, 3)
	check(s.payroll.people.bodies.is_empty(), "nobody has a body")
	check(s.payroll.people.draw_list().is_empty(), "nothing to draw")
	s.dispose()


func test_the_3d_world_draws_the_people() -> void:
	var s := _sess()
	var r := SquadRender.new()
	r.setup(s.world, "medium")
	Engine.get_main_loop().root.add_child(r)
	var at: Vector2 = s.payroll.people._base("org")
	var cam := Vector3(at.x - 15.0, 20.0, -at.y)
	var rows := [
		{"id": "W1", "x": at.x, "y": at.y, "faction": "org", "moving": false, "car": false},
		{"id": "W2", "x": at.x + 5.0, "y": at.y, "faction": "org", "moving": true, "car": false},
		{"id": "W3", "x": at.x + 9.0, "y": at.y, "faction": "rival", "moving": true, "car": true},
	]
	r.sync([], [], cam, 0.0, 0.1, rows)
	check_eq(r.drawn(), 2, "two men on foot; the third is in a car")
	check(r.vehicles.has("p:W3") and not r.vehicles.has("p:W1"), "a car for the one being driven")
	r.sync([], [], cam, 0.0, 0.1, [])
	check(not r.vehicles.has("p:W3"), "and it goes when he does")
	r.free()
	s.dispose()


func test_the_bodies_change_no_outcome() -> void:
	for seed in [12, 61, 99]:
		var ran := []
		for on in [true, false]:
			Agent.ENABLED = on
			var s := _sess(seed)
			var lk := _hire(s, "lookout", s.time)
			_hire(s, "dealer", s.time)
			s.payroll.post_lookout(lk, s.stash_net.stashes[0].id)
			for i in 900: s.update(1.0)
			var rows := []
			for w in s.payroll.workers:
				rows.append([w.id, w.status, w.assigned, snappedf(float(w.heat), 0.001), snappedf(float(w.loyalty), 0.001)])
			ran.append(JSON.stringify([rows, s.money, s.payroll.unpaid, s.payroll.paid_total]))
			s.dispose()
		check_eq(ran[0], ran[1], "paired seed %d: same payroll and money, bodies or not" % seed)

class FlatAccess extends World:
	func ground(_x: float, _y: float) -> float: return 0.0
	func travel_surface(_x: float, _y: float) -> float: return 0.0
	func is_water(_x: float, _y: float) -> bool: return false

func test_failed_reassignment_retains_the_last_valid_task() -> void:
	var s := _sess()
	var world := FlatAccess.new()
	world.airfields = []
	var wall := SiteLayout.record(world, "wall", "stash", SiteLayout.frame(Vector2(50, 0), 0), Vector3(8, 3, 8))
	s.payroll.people._access = SiteAccess.new(world, [wall])
	var body := Agent.new("test", "foot", 0, 0)
	body.queue(Agent.Task.new("go", Vector2(10, 0)))
	var task: Agent.Task = body.tasks[0]
	var route := body.route.duplicate()
	var reason := s.payroll.people._send(body, Vector2(50, 0), s.ground.graph)
	check(reason != "")
	check_eq(body.tasks[0], task)
	check_eq(body.route, route)
	check_eq(body.pos(), Vector2.ZERO)
	s.dispose()

func test_live_route_obstruction_stops_without_teleporting_or_duplicate_bodies() -> void:
	var s := _sess()
	var id := _hire(s, "accountant", s.time)
	var people: People = s.payroll.people
	var world := FlatAccess.new()
	world.airfields = []
	var wall := SiteLayout.record(world, "wall", "stash", SiteLayout.frame(Vector2(12, 0), 0), Vector3(8, 3, 8))
	people._access = SiteAccess.new(world, [wall])
	var body := Agent.new(id, "foot", 0, 0)
	body.speed = 10
	body.queue(Agent.Task.new("go", Vector2(50, 0)))
	people.bodies[id] = body
	people._requested[id] = "hq"
	people._post[id] = "hq"
	people.update(1.0)
	check_eq(body.pos(), Vector2.ZERO, "obstruction leaves last valid position")
	check(people.halted.has(id) and "wall" in people.blocked[id])
	check("travel blocked" in s.payroll.doing(s.payroll.get_worker(id)))
	people.update(5.0)
	check_eq(body.pos(), Vector2.ZERO)
	var worker: Dictionary = s.payroll.get_worker(id)
	worker.status = "assigned"
	worker.assigned = "truck-test"
	people.update(1.0)
	check(not people.bodies.has(id) and not people.blocked.has(id), "truck ownership removes duplicate foot body")
	worker.status = "free"
	worker.assigned = ""
	people.update(1.0)
	check(people.bodies.has(id))
	worker.status = "jailed"
	people.update(1.0)
	check(not people.bodies.has(id), "incarceration removes physical worker")
	worker.status = "dead"
	people.update(1.0)
	check(not people.bodies.has(id), "death cannot create another body")
	s.dispose()

func test_in_transit_save_load_keeps_position_route_and_owned_identity() -> void:
	var s := _sess()
	var id := _hire(s, "lookout", s.time)
	s.payroll.post_lookout(id, s.stash_net.stashes[0].id)
	_run(s, 10)
	var body: Agent = s.payroll.people.bodies[id]
	check(not body.idle())
	var before := body.pos()
	var route := body.route.duplicate()
	var progress := body.s
	var data: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	var loaded := _sess()
	StrategicSave.restore(loaded, data)
	var restored: Agent = loaded.payroll.people.bodies[id]
	check_near(restored.pos().distance_to(before), 0, 0.001)
	check_eq(restored.route, route)
	check_near(restored.s, progress, 0.001)
	check(not restored.idle() and not loaded.payroll.people.halted.has(id))
	var row: Dictionary = loaded.payroll.people.draw_list().filter(func(item): return item.id == id)[0]
	check(row.has("name") and row.role == "lookout" and row.travel == "travelling")
	for item in loaded.payroll.people.draw_list():
		if item.faction != "org": check(not item.has("name") and not item.has("assignment"), "rival identity is not exposed")
	loaded.payroll.people.update(1.0)
	check(restored.pos().distance_to(before) > 0, "loaded worker continues, rather than appearing settled")
	loaded.dispose()
	s.dispose()
