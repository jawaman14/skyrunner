extends TestCase
## The civilian economy, slice 1 (DESIGN 86): each district's prosperity moves at the day's close: back towards 0.5, down with the
## firefights there and while the collectors squeeze its market, up with the businesses open and paid up; what the shoppers spend
## and pay follows it; the phone shows it with its reasons; it is saved; no random draws; off, it stays where it is.


func after_each() -> void:
	World.use_map(0)
	Businesses.CIVIC = true


func _city(opts := {}) -> Session:
	var o := {"seed": 5, "map_seed": MapCity.SEED, "location": "HAR"}
	o.merge(opts, true)
	var s := Session.new(o)
	s.police.frozen = true
	s.update(1.0 / 30)
	return s


func _p(s: Session, d := Businesses.DISTRICT) -> float:
	return float(s.businesses.districts[d].prosperity)


func test_it_comes_back_towards_the_middle() -> void:
	var s := _city()
	var b: Businesses = s.businesses
	b.districts[Businesses.DISTRICT].prosperity = 0.8
	b._civic_day()
	check(_p(s) < 0.8, "a rich street settles: %.3f" % _p(s))
	b.districts["the-docks"].prosperity = 0.2
	b._civic_day()
	check(_p(s, "the-docks") > 0.2, "a poor one recovers: %.3f" % _p(s, "the-docks"))
	s.dispose()


func test_shooting_hurts_it_and_counts_once() -> void:
	var s := _city({"features": Session.SANDBOX_FEATURES, "ground_war": true})
	var b: Businesses = s.businesses
	for d in b.districts:
		b.districts[d].prosperity = 0.5
	var key := Territories.key(World.layout, Businesses.DISTRICT)
	b._civic_day()
	var calm := _p(s)
	b.districts[Businesses.DISTRICT].prosperity = 0.5
	s.ground.shots_in[key] = 3
	b._civic_day()
	check_near(_p(s), calm - 3 * Businesses.PROSPER_SHOTS, 0.0011, "three firefights: %.3f against %.3f" % [_p(s), calm])
	check(str(b.districts[Businesses.DISTRICT].why).contains("3 firefights"), "and the reason: %s" % b.districts[Businesses.DISTRICT].why)
	check(s.ground.shots_in.is_empty(), "counted, then the day starts over")
	b.districts[Businesses.DISTRICT].prosperity = 0.5
	s.ground.shots_in[key] = 40
	b._civic_day()
	check_near(_p(s), calm - Businesses.PROSPER_SHOTS_CAP * Businesses.PROSPER_SHOTS, 0.0011, "at most five count")
	for i in 200:
		s.ground.shots_in[key] = 5
		b._civic_day()
	check_eq(_p(s), Businesses.PROSPER_MIN, "never under the floor")
	s.dispose()


func test_a_firefight_is_counted_where_it_starts() -> void:
	var s := _city({"features": Session.SANDBOX_FEATURES, "ground_war": true})
	var g := s.ground
	g._started = true
	for f in g.commanders:
		g.commanders[f].ai = false
	var at := Vector2(-600.0, -10600.0)  # by the club, in San Telmo Centro
	var a = g.recruit("org", "foot", at, false)
	var r = g.recruit("rival", "foot", at + Vector2(30, 0), false)
	g._open(a, r)
	check_eq(int(g.shots_in.get(g.territory_key_at(at), 0)), 1, "one firefight in %s" % g.territory_key_at(at))
	s.dispose()


func test_the_shoppers_follow_it() -> void:
	var s := _city()
	var b: Businesses = s.businesses
	var shop = null
	for x in b.catalog:
		if b.is_retail(x) and str(x.district) == Businesses.DISTRICT:
			shop = x
			break
	check(shop != null, "a shop in the district")
	b.districts[Businesses.DISTRICT].prosperity = 0.3
	var poor := [b.daily_want(shop), b.price(Businesses.DISTRICT)]
	b.districts[Businesses.DISTRICT].prosperity = 0.7
	var rich := [b.daily_want(shop), b.price(Businesses.DISTRICT)]
	check(rich[0] > poor[0] and rich[1] > poor[1], "more bought, at more, in a richer street: %s against %s" % [str(rich), str(poor)])
	s.dispose()


func test_the_phone_says_it_and_a_save_keeps_it() -> void:
	var s := _city()
	var b: Businesses = s.businesses
	b.districts[Businesses.DISTRICT].prosperity = 0.37
	b.districts[Businesses.DISTRICT]["why"] = "2 firefights"
	check_eq(b.prosperity_line(Businesses.DISTRICT), "San Telmo Centro: prosperity 37% (2 firefights)", "the line")
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	s.dispose()
	var r := _city()
	StrategicSave.restore(r, d)
	check_near(_p(r), 0.37, 1e-6, "saved")
	r.dispose()


func test_off_it_stays() -> void:
	Businesses.CIVIC = false
	var s := _city()
	s.businesses.districts[Businesses.DISTRICT].prosperity = 0.8
	s.businesses._civic_day()
	check_eq(_p(s), 0.8, "off: unchanged")
	s.dispose()
