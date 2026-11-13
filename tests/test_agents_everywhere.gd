extends TestCase
## The physical-NPC migration's evidence pass (ROADMAP "Forgotten or half done", D-99): with Agent.ENABLED, everything that moves
## on the organisation's side is a body. A truck of every kind (a landed load, a van between our places, a cash round) has a driver
## Agent and is where its driver is; every squad has one Agent per man; every worker who is not a squad's man or a truck's driver is
## a body in People. And none of them reaches its end on a bare timer: a truck whose driver is held back is still on the road when
## its timer has run out.


func after_each() -> void:
	Agent.ENABLED = true
	World.use_map(0)
	Terrain.natural = false


func _sess() -> Session:
	Terrain.natural = true
	var s := Session.new({"seed": 12, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES,
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


func _every_truck_has_a_driver(s: Session, what: String) -> void:
	check(not s.stash_net.trucks.is_empty(), "%s: a truck on the road" % what)
	for t in s.stash_net.trucks:
		check(t.agent != null, "%s: truck %d has a driver" % [what, t.job_id])
		if t.agent != null:
			var p: Array = t.pos(s.time)
			check_near(Vector2(p[0], p[1]).distance_to(Vector2(t.agent.x, t.agent.y)), 0.0, 1e-6, "%s: the truck is where its driver is" % what)


func test_every_kind_of_truck_has_a_driver() -> void:
	var s := _sess()
	var lg: Logistics = s.logistics
	var live: Array = s.stash_net.live()
	check(live.size() >= 3, "three stashes")
	var a := str(live[0].id)
	var b := str(live[1].id)
	var c := str(live[2].id)
	lg.add(a, "marijuana", 200.0, "farm")
	check_eq(lg.send(a, b, "marijuana", 100.0), "", "a van between our places")
	_every_truck_has_a_driver(s, "a van")
	lg.add_cash(a, 1000.0, "outside:street", "sales")
	lg.add_cash(b, 1000.0, "outside:street", "sales")
	check_eq(lg.cash_round([a, b], c), "", "a cash round")
	_every_truck_has_a_driver(s, "a van and a round")
	s.dispose()


func test_every_squad_is_its_men() -> void:
	var s := _sess()
	var g := s.ground
	g.recruit("org", "foot", null, false)
	g.recruit("rival", "car", null, false)
	g.update(GroundWar.TICK_S)
	check(not g.squads.is_empty(), "squads out")
	for q in g.squads:
		if q.state == "gone":
			continue
		check_eq(q.members.size(), q.men, "%s: one body a man" % q.id)
		check(q.members.all(func(m): return m is Agent), "%s: each an Agent" % q.id)
	s.dispose()


func test_every_worker_is_a_body_somewhere() -> void:
	var s := _sess()
	for role in ["lookout", "dealer", "accountant"]:
		var w: Dictionary = s.payroll._person("org", role)
		s.payroll.candidates.org.append(w)
		check_eq(s.payroll.hire("org", w.id), "", "a %s" % role)
	for i in 5:
		s.payroll.update(1.0)
	var people: People = s.payroll.people
	for w in s.payroll.of("org"):
		if w.status not in ["free", "assigned"]:
			continue
		if people.post_of(w) == null:
			continue  # a body elsewhere: a squad's man or a truck's driver
		check(people.bodies.has(w.id), "%s (%s) is a body" % [w.name, w.role])
	s.dispose()


func test_a_held_truck_is_still_on_the_road_when_its_timer_runs_out() -> void:
	var s := _sess()
	var lg: Logistics = s.logistics
	var live: Array = s.stash_net.live()
	lg.add(str(live[0].id), "marijuana", 200.0, "farm")
	check_eq(lg.send(str(live[0].id), str(live[1].id), "marijuana", 100.0), "", "a van")
	var t = s.stash_net.trucks[0]
	t.stop_at = -1.0
	var due: float = t.t0 + t.dur
	# hold the driver: time passes, he does not move
	while s.time < due + 60.0:
		s.time += 5.0
	var done: Array = s.stash_net.update(0.0, s.time, [])
	check(done.is_empty(), "a timer that has run out delivers nothing: the driver has not arrived")
	check(s.stash_net.trucks.has(t), "still on the road")
	s.dispose()
