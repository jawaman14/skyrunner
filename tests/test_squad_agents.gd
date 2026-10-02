extends TestCase
## Physical NPCs, step 3: a squad is its men - one Agent each, standing where the squad's
## bookkeeping says. Nothing here may change an outcome (the last test runs the same war with
## the bodies off).


func after_each() -> void:
	Agent.ENABLED = true
	World.use_map(0)


func _war(seed := 3, ai := false) -> Session:
	var s := Session.new({"seed": seed, "map_seed": MapCity.SEED, "location": "QRY",
		"features": Session.SANDBOX_FEATURES, "ground_war": true})
	s.police.frozen = true
	if not ai:
		s.ground._started = true
		for f in s.ground.commanders:
			s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	return s


func _squad(g: GroundWar, f: String, at: Vector2, n: int, kind := "foot") -> GroundWar.Squad:
	var q: GroundWar.Squad = g.recruit(f, kind, at, false)
	q.men = n
	q.men0 = n
	q.state = "holding"
	return q


func _ticks(g: GroundWar, n: int) -> void:
	for i in n:
		g.update(1.0)


func test_a_squad_has_one_body_per_man_around_its_spot() -> void:
	var s := _war()
	var g := s.ground
	var q := _squad(g, "org", g.hq("org"), 4)
	_ticks(g, 2)
	check_eq(q.members.size(), 4, "four men, four bodies")
	for m: Agent in q.members:
		var d := m.pos().distance_to(q.pos())
		check(absf(d - GroundWar.RING_R) < 0.01, "%s stands %.1f m from the squad's spot" % [m.id, d])
	check_eq((q.members[2] as Agent).id, "%s.3" % q.id, "named after the squad")
	s.dispose()


func test_men_on_foot_walk_in_file_along_the_road() -> void:
	var s := _war()
	var g := s.ground
	var q := _squad(g, "org", g.hq("org"), 4)
	g.go(q, g.hq("rival"))
	_ticks(g, 60)
	check(q.state == "moving" and q.s > 4.0 * GroundWar.FILE_GAP, "on the road (%.0f m)" % q.s)
	var lead: Agent = q.members[0]
	var tail: Agent = q.members[3]
	check(lead.pos().distance_to(q.pos()) < 0.01, "the point man is the squad's position")
	var behind := tail.pos().distance_to(lead.pos())
	check(behind > 5.0 and behind <= 3.0 * GroundWar.FILE_GAP + 0.01, "the last man is %.1f m behind along the road" % behind)
	check_eq((tail.current() as Agent.Task).kind, "march", "marching")
	s.dispose()


func test_a_car_crew_rides_together() -> void:
	var s := _war()
	var g := s.ground
	var q := _squad(g, "org", g.hq("org"), 4, "car")
	g.go(q, g.hq("rival"))
	_ticks(g, 30)
	for m: Agent in q.members:
		check(m.pos().distance_to(q.pos()) < 0.01, "%s is in the car" % m.id)
		check_eq(m.kind, "car", "driving kind")
	s.dispose()


func test_the_men_who_fall_come_off_the_back_of_the_file() -> void:
	var s := _war()
	var g := s.ground
	var q := _squad(g, "org", g.hq("org"), 4)
	_ticks(g, 2)
	var first: Agent = q.members[0]
	q.men = 2
	_ticks(g, 1)
	check_eq(q.members.size(), 2, "two left standing")
	check(q.members[0] == first, "the same men, the last ones gone")
	q.men = 0
	_ticks(g, 1)
	check(q.members.is_empty(), "nobody left")
	s.dispose()


func test_a_firefight_spreads_the_men_across_the_line_of_fire() -> void:
	var s := _war()
	var g := s.ground
	var a := _squad(g, "org", g.hq("org"), 4)
	var b := _squad(g, "rival", g.hq("org") + Vector2(0, 120), 4)
	var f := GroundWar.Fight.new()
	f.a = a
	f.b = b
	a.fight = f
	b.fight = f
	a.state = "fighting"
	b.state = "fighting"
	_ticks(g, 1)
	var first: Agent = a.members[0]
	var last: Agent = a.members[3]
	check_eq((first.current() as Agent.Task).kind, "fight", "in the fight")
	check(absf(first.pos().distance_to(last.pos()) - 3.0 * GroundWar.LINE_GAP) < 0.01, "a firing line %.1f m wide" % first.pos().distance_to(last.pos()))
	check(absf(first.y - last.y) < 0.01, "square to the enemy, who is straight along y")
	a.fight = null
	b.fight = null
	s.dispose()

func test_the_3d_world_draws_the_men_where_the_agents_are() -> void:
	var s := _war()
	var g := s.ground
	var q := _squad(g, "org", Vector2(-1640, -10690), 4)
	_ticks(g, 2)
	var r := SquadRender.new()
	r.setup(s.world, "medium")
	Engine.get_main_loop().root.add_child(r)
	var d := q.dict()
	check_eq((d.at as Array).size(), 4, "the squad's dict carries where its men are")
	r.sync([d], [], Vector3(-1660, 20, 10720), s.time, 0.1)
	check_eq(r.men_pts.size(), 4, "four men drawn")
	for i in 4:
		var m: Agent = q.members[i]
		var drawn: Vector3 = r.men_pts[i][1]
		check(absf(drawn.x - m.x) < 0.2 and absf(-drawn.z - m.y) < 0.2, "man %d is drawn at his agent (%.1f,%.1f vs %.1f,%.1f)" % [i, drawn.x, -drawn.z, m.x, m.y])
	# without the bodies the old layout still draws everybody
	Agent.ENABLED = false
	q.members.clear()
	r.sync([q.dict()], [], Vector3(-1660, 20, 10720), s.time, 0.1)
	check_eq(r.men_pts.size(), 4, "four men drawn with no agents")
	r.free()
	s.dispose()


func test_the_bodies_change_no_outcome() -> void:
	var ran := []
	for on in [true, false]:
		Agent.ENABLED = on
		var s := _war(5, true)
		for i in 600:
			s.update(1.0)
		var rows := []
		for q: GroundWar.Squad in s.ground.squads:
			var d := q.dict()
			rows.append([d.id, d.men, d.x, d.y, d.state, d.morale])
		ran.append(JSON.stringify([rows, s.ground.lost_men, snappedf(s.money, 0.01)]))
		if not on:
			for q: GroundWar.Squad in s.ground.squads:
				check(q.members.is_empty(), "no bodies with Agent off")
		s.dispose()
	check_eq(ran[0], ran[1], "the same war, bodies or not")
