extends TestCase
## D-38: flight skill gives optional bonus goals that never block a chapter, paid in renown (Story.FLIGHT).


func after_each() -> void:
	Story.FLIGHT_GOALS = true


func _story(index := 0) -> Session:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "FRM", "features": Session.SANDBOX_FEATURES,
		"trade": true, "payroll": true, "renown": true})
	var st := Story.new(index)
	st.attach(s)
	s.update(1.0 / 30)
	return s


func _land(s: Session, code: String, fpm: float, bank := 5.0) -> void:
	s.bus.emit("landed", s.time, "", ["runner"], {"code": code, "touchdown_fpm": fpm, "max_bank": bank, "seconds": 600.0})


func test_each_early_chapter_offers_one_optional_flying_goal() -> void:
	for i in 3:
		var s := _story(i)
		var flying: Array = s.story.chapter.objectives.filter(func(o): return Story._is_flight(str(o.key)))
		check_eq(flying.size(), 1, "chapter %d has one" % (i + 1))
		if not flying.is_empty():
			check(flying[0].optional, "and it is optional: it never blocks the chapter")
		check(s.story.objective_lines().any(func(l): return str(l).contains("renown for flying well")), "the card says what it pays")
		s.dispose()


func test_a_greased_landing_pays_renown_not_money() -> void:
	var s := _story(0)
	var money0 := s.money
	var renown0: float = s.renown.score
	_land(s, "FRM", 300.0)
	s.update(1.0)
	check_eq(float(s.story.progress.get("greaser", 0.0)), 0.0, "a firm one doesn't count")
	_land(s, "FRM", 90.0)
	s.update(1.0)
	check_eq(float(s.story.progress.get("greaser", 0.0)), 1.0, "a greaser does")
	check_near(s.renown.score - renown0, Story.FLIGHT_RENOWN, 0.01, "paid in renown")
	check_eq(s.money, money0, "and no money from nowhere (D-65)")
	_land(s, "FRM", 80.0)
	s.update(1.0)
	check_near(s.renown.score - renown0, Story.FLIGHT_RENOWN, 0.01, "once")
	s.dispose()


func test_short_strips_and_steady_landings_in_a_row() -> void:
	var s := _story(2)
	var short := World.AIRFIELDS.filter(func(a): return float(a.length) < Story.SHORT_M)
	var long := World.AIRFIELDS.filter(func(a): return float(a.length) >= 1000.0)
	_land(s, long[0].code, 200.0)
	_land(s, long[0].code, 250.0)
	_land(s, long[0].code, 500.0)  # a hard one breaks the run
	check_eq(float(s.story.progress.get("steady_landings", 0.0)), 0.0, "three in a row means in a row")
	for i in 3:
		_land(s, long[0].code, 200.0)
	check_eq(float(s.story.progress.get("steady_landings", 0.0)), 3.0, "three steady ones")
	_land(s, long[0].code, 700.0)
	check_eq(float(s.story.progress.get("steady_landings", 0.0)), 3.0, "and once made, it stays made")
	s.dispose()
	if not short.is_empty():
		var t := _story(1)
		_land(t, short[0].code, 250.0)
		check_eq(float(t.story.progress.get("short_strip", 0.0)), 1.0, "a strip under 650 m counts")
		t.dispose()


func test_off_for_the_replays() -> void:
	Story.FLIGHT_GOALS = false
	var s := _story(0)
	check(not s.story.chapter.objectives.any(func(o): return Story._is_flight(str(o.key))), "no flying goals with the switch off")
	s.dispose()
