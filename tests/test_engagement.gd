extends TestCase
## The turf war's engagement geometry (GroundWar.ENGAGEMENT): every weapon has a range, squads in a
## fight close on each other to the distance their weapons like, and each man's fire is what his
## weapon does at his own distance to the nearest enemy man.


func after_each() -> void:
	GroundWar.ENGAGEMENT = true
	World.use_map(0)


func _war() -> Session:
	var s := Session.new({"seed": 3, "map_seed": MapCity.SEED, "location": "QRY",
		"features": Session.SANDBOX_FEATURES, "ground_war": true})
	s.police.frozen = true
	s.ground._started = true
	for f in s.ground.commanders:
		s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	return s


func _squad(g: GroundWar, f: String, at: Vector2, loadout: Dictionary, kind := "foot") -> GroundWar.Squad:
	var q: GroundWar.Squad = g.recruit(f, kind, at, false)
	var n := 0
	for t in loadout:
		n += int(loadout[t])
	g.arsenal(f).give_back(q.loadout)
	q.loadout = loadout.duplicate()
	q.men = n
	q.men0 = n
	q.ammo = n * 90
	q.morale = 1.0
	q.state = "holding"
	return q


func test_a_weapon_loses_its_bite_with_range() -> void:
	check_eq(GroundWar.eff(10.0, 100.0), 1.0, "all of it inside half the range")
	check_eq(GroundWar.eff(50.0, 100.0), 1.0, "... up to exactly half")
	check(absf(GroundWar.eff(100.0, 100.0) - 0.15) < 0.001, "15% at the range itself")
	check(GroundWar.eff(75.0, 100.0) < 1.0 and GroundWar.eff(75.0, 100.0) > 0.15, "in between, in between")
	check(absf(GroundWar.eff(130.0, 100.0)) < 0.001, "nothing 30% past it")
	check_eq(GroundWar.eff(500.0, 100.0), 0.0, "and nothing at all far out")


func test_squads_want_the_distance_their_weapons_like() -> void:
	var s := _war()
	var g := s.ground
	var at := g.hq("org")
	var pistols := _squad(g, "org", at, {"pistol": 4})
	var rifles := _squad(g, "org", at, {"rifle": 4})
	var mixed := _squad(g, "org", at, {"pistol": 3, "mg": 1})
	var k := GroundWar.RANGE_SCALE
	check(absf(GroundWar.want_m(pistols) - clampf(0.6 * 50.0 * k, 25.0, 500.0)) < 0.01, "pistols want %.0f m" % GroundWar.want_m(pistols))
	check(absf(GroundWar.want_m(rifles) - clampf(0.6 * 300.0 * k, 25.0, 500.0)) < 0.01, "rifles want %.0f m" % GroundWar.want_m(rifles))
	check(GroundWar.want_m(mixed) >= GroundWar.want_m(rifles), "a machine gun in the squad sets the distance: %.0f" % GroundWar.want_m(mixed))
	check(GroundWar.want_m(rifles) > GroundWar.want_m(pistols), "long guns stand off, short ones come in")
	s.dispose()


func test_fire_depends_on_the_distance() -> void:
	var s := _war()
	var g := s.ground
	var at := g.hq("org")
	var a := _squad(g, "org", at, {"pistol": 4})
	var b := _squad(g, "rival", at + Vector2(1000, 0), {"pistol": 4})
	var far := g.fire_at(a, b)
	check(far < 0.001, "pistols do nothing at 1 km (%.3f)" % far)
	b.x = at.x + 240.0
	var mid := g.fire_at(a, b)
	check(mid > far and mid < 0.5 * g.fire(a), "and little at 240 m (%.3f of %.3f)" % [mid, g.fire(a)])
	b.x = at.x + 20.0
	b.y = at.y
	var near := g.fire_at(a, b)
	check(absf(near - g.fire(a)) < 0.001, "at 20 m they do all they ever did (%.3f vs %.3f)" % [near, g.fire(a)])
	var r := _squad(g, "org", at, {"rifle": 4})
	b.x = at.x + 240.0
	check(g.fire_at(r, b) > 0.9 * g.fire(r), "rifles reach at 240 m (%.2f of %.2f)" % [g.fire_at(r, b), g.fire(r)])
	GroundWar.ENGAGEMENT = false
	check_eq(g.fire_at(a, b), g.fire(a), "switched off: the old flat fire")
	s.dispose()


func test_a_squad_strung_out_loses_the_fire_of_the_men_who_cannot_reach() -> void:
	var s := _war()
	var g := s.ground
	var at := g.hq("org")
	var a := _squad(g, "org", at, {"pistol": 4})
	var b := _squad(g, "rival", at + Vector2(20, 0), {"pistol": 4})
	for q in [a, b]:
		q.members = []
		for i in 4:
			q.members.append(Agent.new("%s.%d" % [q.id, i], "foot", q.x, q.y))
	var together := g.fire_at(a, b)
	check(absf(together - g.fire(a)) < 0.001, "all four in reach: full fire (%.3f)" % together)
	for i in [1, 2, 3]:
		(a.members[i] as Agent).x = at.x - 500.0  # three men a long way back
	var split := g.fire_at(a, b)
	check(absf(split - g.fire(a) * 0.25) < 0.001, "one man in reach of four: a quarter of the fire (%.3f vs %.3f)" % [split, g.fire(a) * 0.25])
	s.dispose()


func test_squads_close_in_to_their_distance_and_vehicles_stay_put() -> void:
	var s := _war()
	var g := s.ground
	var at := g.hq("org")
	var pistols := _squad(g, "org", at, {"pistol": 4})
	var rifles := _squad(g, "rival", at + Vector2(240, 0), {"rifle": 4})
	g._open(pistols, rifles)
	var gap0 := pistols.pos().distance_to(rifles.pos())
	g._close_in(1.0)
	var gap1 := pistols.pos().distance_to(rifles.pos())
	check(absf((gap0 - gap1) - GroundWar.CLOSE_MS) < 0.01, "the pistol squad comes on at 3 m a second; the rifles hold (%.1f -> %.1f)" % [gap0, gap1])
	for i in 100:
		g._close_in(1.0)
	var gap := pistols.pos().distance_to(rifles.pos())
	check(absf(gap - GroundWar.want_m(pistols)) < 0.5, "pistols end up at the distance they like, %.0f m (%.1f)" % [GroundWar.want_m(pistols), gap])
	# a car does not move
	var car := _squad(g, "police", at + Vector2(0, 600), {"rifle": 4}, "car")
	var foe := _squad(g, "rival", at + Vector2(0, 850), {"pistol": 4})
	g._open(car, foe)
	var c0 := car.pos()
	g._close_in(1.0)
	check_eq(car.pos(), c0, "the car stays where it is")
	check(foe.pos().distance_to(c0) < 250.0, "while the men on foot come to it")
	s.dispose()


func test_a_long_gun_has_the_first_say() -> void:
	# rifles against pistols at 240 m: over the closing minute the rifles hurt the pistols and not the reverse
	var s := _war()
	var g := s.ground
	var at := g.hq("org")
	var rifles := _squad(g, "org", at, {"rifle": 4})
	var pistols := _squad(g, "rival", at + Vector2(240, 0), {"pistol": 4})
	var hit_rifles := 0.0
	var hit_pistols := 0.0
	for i in 5:
		hit_rifles += g.fire_at(pistols, rifles)
		hit_pistols += g.fire_at(rifles, pistols)
	check(hit_pistols > 5.0 * hit_rifles, "at 240 m the rifles' fire dwarfs the pistols' (%.2f vs %.2f)" % [hit_pistols, hit_rifles])
	s.dispose()
