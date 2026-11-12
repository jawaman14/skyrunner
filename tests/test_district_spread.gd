extends TestCase
## District control's calibration (DESIGN 83): a gang's patrol goes for a district nobody holds over an empty stroll near home,
## still prefers one the enemy holds, and a faction's squads spread over the districts instead of stacking on one; the police
## are unchanged; no random draw; off, the old targeting.


func after_each() -> void:
	World.use_map(0)
	GroundWar.SPREAD = true


func _war() -> Session:
	var s := Session.new({"seed": 3, "map_seed": MapCity.SEED, "location": "HAR",
		"features": Session.SANDBOX_FEATURES, "ground_war": true})
	s.police.frozen = true
	s.ground._started = true
	for f in s.ground.commanders:
		s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	return s


## Every district empty, then `held` given to `who` with plenty of presence.
func _clear(g: GroundWar, held := {}) -> void:
	for key in g.territory_control:
		g.territory_control[key] = {"org": 0.0, "rival": 0.0, "police": 0.0}
	for id in held:
		var key := Territories.key(g.world.map, id)
		g.territory_control[key][held[id]] = 100.0


func _centre(g: GroundWar, id: String) -> Vector2:
	for area: Dictionary in Territories.records(g.world.map):
		if str(area.id) == id:
			return Territories.center_of(area)
	return Vector2.ZERO


func test_a_gang_claims_an_empty_district_rather_than_strolling_its_own() -> void:
	var s := _war()
	var g := s.ground
	_clear(g, {"san-telmo-centro": "org"})  # ours already; everything else empty
	var from := _centre(g, "san-telmo-centro")
	var pick := str(g._contested_territory("org", from).id)
	check(pick != "san-telmo-centro", "an empty district, not the one we hold (%s)" % pick)
	GroundWar.SPREAD = false
	var old := str(g._contested_territory("org", from).id)
	check_eq(g.territory_share(Territories.key(g.world.map, old), "org") < 0.0 or old == "san-telmo-centro", true, "off: the old score (%s)" % old)
	s.dispose()


func test_the_enemys_district_still_comes_first() -> void:
	var s := _war()
	var g := s.ground
	_clear(g, {"barrio-chino": "rival"})
	var pick := str(g._contested_territory("org", _centre(g, "san-telmo-centro")).id)
	check_eq(pick, "barrio-chino", "Los Cuervos' street beats an empty one")
	s.dispose()


func test_squads_spread_instead_of_stacking() -> void:
	var s := _war()
	var g := s.ground
	_clear(g, {"barrio-chino": "rival"})
	var q := []
	for k in 3:
		q.append(g.recruit("org", "foot", null, false))
		check(q[k] is GroundWar.Squad, "squad %d" % k)
	for k in 3:
		g.order(q[k], g._patrol_order("org", q[k].pos(), q[k]))
	var where: Array = q.map(func(x): return str(x.order.get("territory", "")))
	check_eq(where.slice(0, 2), ["barrio-chino", "barrio-chino"], "two go for Los Cuervos' street: enough to fight for it")
	check(where[2] != "barrio-chino", "the third claims another (%s)" % where[2])
	# re-ordering a squad does not count its own order against the district it is already in
	g.order(q[0], g._patrol_order("org", q[0].pos(), q[0]))
	check_eq(str(q[0].order.get("territory", "")), "barrio-chino", "it keeps its street")
	GroundWar.SPREAD = false
	g.order(q[2], g._patrol_order("org", q[2].pos(), q[2]))
	check_eq(str(q[2].order.get("territory", "")), "barrio-chino", "off: all three stack on the same street")
	s.dispose()


func test_the_police_do_not_claim_empty_districts() -> void:
	var s := _war()
	var g := s.ground
	_clear(g, {"valle-verde": "org"})
	var from := _centre(g, "san-telmo-centro")
	var on := str(g._contested_territory("police", from).id)
	check_eq(on, "valle-verde", "the law goes where the organisation is")
	s.dispose()


func test_no_random_draw() -> void:
	var s := _war()
	var g := s.ground
	_clear(g)
	var before: Variant = g.rng.state() if g.rng.has_method("state") else null
	var r := []
	for k in 3:
		r.append(str(g._contested_territory("rival", _centre(g, "the-docks")).id))
	check_eq(r[0], r[1], "the same answer each time")
	check_eq(r[1], r[2], "and again")
	if before != null:
		check_eq(g.rng.state(), before, "the war's stream untouched")
	s.dispose()


func test_passing_through_holds_nothing_and_staying_holds_it() -> void:
	var four_men_two_minutes := {"org": 8.0, "rival": 0.0, "police": 0.0}
	var settled := {"org": 4.0 * GroundWar.CONTROL_TAU / 60.0, "rival": 0.0, "police": 0.0}  # four men until it settles: 120
	check_eq(GroundWar.held_share(four_men_two_minutes, "org"), -1.0, "a squad passing through holds nothing")
	check_eq(GroundWar.held_share(settled, "org"), 1.0, "one that stayed holds it")
	var after := settled.duplicate()
	after.org *= exp(-25.0 * 60.0 / GroundWar.CONTROL_TAU)
	check(GroundWar.held_share(after, "org") >= 0.5, "still ours 25 minutes after it left (%.0f)" % after.org)
	after.org = settled.org * exp(-40.0 * 60.0 / GroundWar.CONTROL_TAU)
	check_eq(GroundWar.held_share(after, "org"), -1.0, "nobody's 40 minutes after (%.0f)" % after.org)
	check_eq(StationMap.turf_leader(four_men_two_minutes).leader, "", "the turf map agrees")
	check_eq(StationMap.turf_leader(settled).leader, "org", "and names the holder")
	GroundWar.SPREAD = false
	check_eq(GroundWar.held_share(four_men_two_minutes, "org"), 1.0, "off: the bare share rule")


func test_the_weeks_district_goal_wants_real_presence() -> void:
	var s := Session.new({"seed": 3, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	s.police.frozen = true
	s.update(1.0 / 30)
	if s.weekly == null:
		check(true, "no week's work in this session")
		s.dispose()
		return
	var g := s.ground
	_clear(g)
	var key: String = g.territory_control.keys()[0]
	g.territory_control[key] = {"org": 8.0, "rival": 0.0, "police": 0.0}
	check(not s.weekly._holds_a_district(), "a walk through is not a district held")
	g.territory_control[key] = {"org": 120.0, "rival": 0.0, "police": 0.0}
	check(s.weekly._holds_a_district(), "a district sat in is")
	s.dispose()
