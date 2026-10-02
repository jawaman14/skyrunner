extends TestCase
## Veteran squads (a squad that survives fights learns: Green, Blooded, Veteran, Elite) and the orders the man on the
## ground can give them (Z hold, X come, C charge, V fall back).


func after_each() -> void:
	GroundWar.VETERANS = true
	World.use_map(0)


func _war(seed := 3) -> Session:
	var s := Session.new({"seed": seed, "map_seed": MapCity.SEED, "location": "QRY",
		"features": Session.SANDBOX_FEATURES, "ground_war": true})
	s.police.frozen = true
	s.ground._started = true
	for f in s.ground.commanders:
		s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	return s


func _squad(g: GroundWar, f: String, at: Vector2, guns := {"rifle": 4}) -> GroundWar.Squad:
	var q = g.recruit(f, "foot", at, false)
	var n := 0
	for t in guns:
		n += int(guns[t])
	g.arsenal(f).give_back(q.loadout)
	q.loadout = guns.duplicate()
	q.men = n
	q.men0 = n
	q.ammo = n * 90
	q.morale = 0.8
	q.state = "holding"
	return q


func test_experience_makes_ranks() -> void:
	var s := _war()
	var q := _squad(s.ground, "org", Vector2(100, 100))
	check_eq(q.rank(), 0, "green")
	check_eq(q.rank_name(), "Green", "named")
	for x in [[3.9, 0], [4.0, 1], [9.9, 1], [10.0, 2], [20.0, 3], [500.0, 3]]:
		q.xp = x[0]
		check_eq(q.rank(), x[1], "%.1f xp is rank %d" % [x[0], x[1]])
	GroundWar.VETERANS = false
	check_eq(q.rank(), 0, "off: everyone is green")
	check_near(q.vet(), 1.0, 0.0001, "and no better")
	s.dispose()


func test_a_fight_survived_teaches_and_a_win_teaches_more() -> void:
	var s := _war()
	var g: GroundWar = s.ground
	var a := _squad(g, "org", Vector2(100, 100))
	var b := _squad(g, "rival", Vector2(140, 100))
	g._learn(a, 2.0)
	g._learn(b, 1.0)
	check_eq(a.xp, 2.0, "the winner")
	check_eq(b.xp, 1.0, "the one that ran")
	a.xp = 3.5
	g._learn(a, 1.0)
	check_eq(a.rank(), 1, "4.5 xp: blooded")
	check(g.events.any(func(e): return e[0] == "runner" and str(e[1]).contains("blooded")), "and our side is told: %s" % [g.events])
	a.men = 1  # a squad of 4 with one man left
	a.xp = 12.0
	g._learn(a, 1.0)
	check_near(a.xp, 7.0, 0.001, "half dead: the experience halves (12 -> 6, +1)")
	var dead := _squad(g, "org", Vector2(300, 100))
	dead.men = 0
	g._learn(dead, 5.0)
	check_eq(dead.xp, 0.0, "the dead learn nothing")
	s.dispose()


func test_veterans_shoot_better_hold_longer_and_cost_more() -> void:
	var s := _war()
	var g: GroundWar = s.ground
	var q := _squad(g, "org", Vector2(100, 100))
	var base := g.fire(q)
	q.xp = 20.0
	check_near(g.fire(q), base * 1.21, base * 0.001, "an elite squad: +21%% fire (%.2f vs %.2f)" % [g.fire(q), base])
	check_near(0.3 - GroundWar.VET_NERVE * q.rank(), 0.18, 0.0001, "and breaks at 0.18 morale, not 0.3")
	var d := q.dict()
	check_eq(d.rank, 3, "the wire has the rank")
	check_near(d.xp, 20.0, 0.01, "and the experience")
	s.dispose()


func test_a_real_fight_teaches_both_sides() -> void:
	var s := _war()
	var g: GroundWar = s.ground
	var a := _squad(g, "org", Vector2(100, 100), {"rifle": 8})
	var b := _squad(g, "rival", Vector2(130, 100), {"pistol": 3})
	g._open(a, b)
	for i in 120:
		g._rounds(GroundWar.ROUND_S)
		if a.fight == null or b.fight == null:
			break
	check(a.xp > 0.0, "the winner learned (%.1f xp)" % a.xp)
	check(b.xp > 0.0 or b.men <= 0, "the loser learned too, if any of it survived (%.1f xp, %d men)" % [b.xp, b.men])
	s.dispose()


func test_the_order_the_man_on_the_ground_gives() -> void:
	var s := _war()
	var g: GroundWar = s.ground
	var me := Vector2(500, 500)
	var near := _squad(g, "org", me + Vector2(60, 0))
	var far := _squad(g, "org", me + Vector2(900, 0))
	var r: Array = g.field_order("org", me, "come")
	check_eq(r[0], "", "ordered: %s" % [r])
	check_eq(near.order.type, "move", "the near squad comes")
	check_eq(far.order.type, "hold", "the far one does not hear")
	check(near.human, "it is under a human's orders now")
	r = g.field_order("org", me, "hold")
	check_eq(near.order.type, "hold", "and holds")
	r = g.field_order("org", me, "charge")
	check(r[0] != "", "nothing to charge: %s" % r[0])
	var foe := _squad(g, "rival", me + Vector2(200, 0))
	r = g.field_order("org", me, "charge")
	check_eq(r[0], "", "charge with a rival squad in sight: %s" % [r])
	check_eq(near.order.type, "attack", "it attacks")
	check_near(near.order.x, foe.x, 0.01, "at the rival")
	foe.hidden = true
	near.order = {"type": "hold"}
	r = g.field_order("org", me, "charge")
	check(r[0] != "", "a hidden squad cannot be charged")
	r = g.field_order("org", me, "fall_back")
	check_eq(near.order.type, "melt", "fall back is a melt")
	check(g.field_order("org", Vector2(-9000, -9000), "come")[0] != "", "nobody within earshot")
	check(g.field_order("org", me, "dance")[0] != "", "an unknown order")
	s.dispose()


func test_the_pilot_can_command_through_the_session() -> void:
	var s := _war()
	var q := _squad(s.ground, "org", Vector2(10, 10))
	var r: Array = s.command(Roles.PILOT, "field_order", {"what": "come", "x": 20.0, "y": 10.0})
	check(r[0], "the pilot may: %s" % [r])
	check_eq(q.order.type, "move", "and the squad moves")
	check(s.messages.any(func(m): return str(m[1]).contains(q.id)), "and it is said: %s" % [s.messages.map(func(m): return m[1])])
	var bad: Array = s.command(Roles.PILOT, "field_order", {"what": "come", "x": 9000.0, "y": 9000.0})
	check(not bad[0], "out of earshot: %s" % [bad])
	s.dispose()
