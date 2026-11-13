extends TestCase
## Rackets under heat (DESIGN 88, section 51 slice 6): a racket in a district at heat 40 or more is hot, and each collectors' round
## there risks a raid (0 at 40, half at 100), on its own stream: raided, nothing is taken there, the case warms, the district gets
## hotter; closing it (policy off) avoids it; the phone says so; off, no raids.


class FixedRng extends PyRandom:
	var v := 0.0

	func _init(v_ := 0.0) -> void:
		v = v_

	func random() -> float:
		return v


func after_each() -> void:
	Rackets.UNDER_HEAT = true
	World.use_map(0)


func _war() -> Session:
	var s := Session.new({"seed": 3, "map_seed": MapCity.SEED, "location": "QRY", "features": Session.SANDBOX_FEATURES,
		"ground_war": true, "rackets": true, "payroll": true})
	s.police.frozen = true
	s.ground._started = true
	for f in s.ground.commanders:
		s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	for m in Economy.MARKETS:
		s.ground.control[m] = {"org": 0.0, "rival": 0.0, "police": 0.0}
	s.ground.control["west"] = {"org": 100.0, "rival": 0.0, "police": 0.0}  # the west is ours: it pays
	return s


func test_the_odds_rise_with_the_district_heat() -> void:
	var s := _war()
	var r: Rackets = s.rackets
	check(s.investigation != null and r.rng != null, "the case files and the racket's own stream")
	s.investigation.district_heat["west"] = 30.0
	check_eq(r.raid_odds("west"), 0.0, "under 40: not hot")
	s.investigation.district_heat["west"] = 70.0
	check_near(r.raid_odds("west"), Rackets.RAID_MAX * 0.5, 1e-9, "halfway: a quarter")
	s.investigation.district_heat["west"] = 100.0
	check_near(r.raid_odds("west"), Rackets.RAID_MAX, 1e-9, "at 100: half")
	s.dispose()


func test_a_raid_takes_nothing_there_and_warms_the_case() -> void:
	var s := _war()
	var r: Rackets = s.rackets
	s.investigation.district_heat["west"] = 100.0
	var due := r.expected("west")
	check(due > 0, "the west would pay $%d" % due)
	var case0: float = s.police.case("runner").suspicion
	var m0 := s.money
	r.rng = FixedRng.new(0.0)  # a draw under the odds
	r.collect()
	check_eq(s.money, m0, "raided: nothing taken")
	check_eq(r.raids, 1, "counted")
	check_near(s.police.case("runner").suspicion, minf(100.0, case0 + Rackets.RAID_CASE), 1e-6, "the case warms")
	r.rng = FixedRng.new(0.99)  # a draw over them
	r.collect()
	check_eq(s.money, m0 + due, "not raided: paid")
	s.dispose()


func test_closing_it_avoids_the_raid() -> void:
	var s := _war()
	var r: Rackets = s.rackets
	s.investigation.district_heat["west"] = 100.0
	check_eq(r.set_policy("west", "off"), "", "closed")
	r.rng = FixedRng.new(0.0)
	r.collect()
	check_eq(r.raids, 0, "nothing to raid")
	var row: Dictionary = r.view().markets.filter(func(m): return m.market == "west")[0]
	check_eq(float(row.raid), 0.0, "and the phone shows no risk")
	r.set_policy("west", "fair")
	row = r.view().markets.filter(func(m): return m.market == "west")[0]
	check_near(float(row.raid), Rackets.RAID_MAX, 1e-9, "open again: the risk is back on the screen")
	s.dispose()


func test_a_cool_district_draws_nothing() -> void:
	var s := _war()
	var r: Rackets = s.rackets
	s.investigation.district_heat["west"] = 10.0
	var before: Array = r.rng.get_state()
	r.collect()
	check_eq(r.rng.get_state(), before, "no draw where it isn't hot: the stream is untouched")
	s.dispose()


func test_off_no_raids() -> void:
	Rackets.UNDER_HEAT = false
	var s := _war()
	var r: Rackets = s.rackets
	s.investigation.district_heat["west"] = 100.0
	r.rng = FixedRng.new(0.0)
	var m0 := s.money
	r.collect()
	check(s.money > m0 and r.raids == 0, "off: the round pays as before")
	s.dispose()
