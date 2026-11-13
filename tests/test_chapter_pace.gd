extends TestCase
## Chapter deadlines (DESIGN 90, section 51 slice 7): a chapter's required goals done within its minutes pay renown; late, the
## chapter goes on with nothing lost; chapter 1 has none; the card shows the clock; the clock is saved; off, no deadline.


func after_each() -> void:
	Story.PACE = true


func _story(index := 1) -> Session:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "FRM", "features": Session.SANDBOX_FEATURES,
		"trade": true, "payroll": true, "renown": true})
	var st := Story.new(index)
	st.attach(s)
	s.update(1.0 / 30)
	return s


func _meet(s: Session) -> void:
	for o in s.story.chapter.objectives:
		if not o.optional:
			s.story.progress[o.key] = float(o.target)


func test_done_in_time_the_name_grows() -> void:
	var s := _story(1)
	check(s.renown != null, "renown on")
	check_eq(s.story.pace_min(), Story.PACE_MIN[1], "chapter 2: %d minutes" % Story.PACE_MIN[1])
	check(s.story.objective_lines().any(func(l): return str(l).contains("Done within %d min" % Story.PACE_MIN[1])), "the card shows it")
	var r0: float = s.renown.score
	s.time += 30.0 * 60.0
	_meet(s)
	s.story.advance()
	check_near(s.renown.score - r0, Story.PACE_RENOWN + Story.PACE_RENOWN_STEP * 1, 1e-6, "renown for a chapter done in good time")
	check_eq(int(s.story.history[-1].get("pace", -1)), 30, "and the chapter's row says how long")
	check_eq(s.story.index, 2, "on to the next")
	s.dispose()


func test_late_it_goes_on_with_nothing_lost() -> void:
	var s := _story(1)
	var r0: float = s.renown.score
	var m0 := s.money
	s.time += float(Story.PACE_MIN[1] + 1) * 60.0
	check(s.story.pace_line().contains("time's up"), "the card says so: %s" % s.story.pace_line())
	_meet(s)
	s.story.advance()
	check_eq(s.renown.score, r0, "no bonus")
	check_eq(s.money, m0, "and nothing taken")
	check_eq(s.story.index, 2, "the chapter still finishes")
	s.dispose()


func test_chapter_one_has_no_clock_and_the_next_starts_its_own() -> void:
	var s := _story(0)
	check_eq(s.story.pace_min(), 0, "chapter 1: none (forgiving early, D-06)")
	check(not s.story.objective_lines().any(func(l): return str(l).contains("Done within")), "and no line")
	s.time += 500.0
	_meet(s)
	s.story.advance()
	check_near(s.story.opened_at, s.time, 1e-6, "chapter 2's clock starts now")
	s.dispose()


func test_the_clock_is_saved() -> void:
	var s := _story(1)
	s.time += 600.0
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.story.to_dict()))
	var t0: float = s.story.opened_at
	s.dispose()
	var st := Story.from_dict(d)
	check_near(st.opened_at, t0, 1e-6, "kept")
	var r := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "FRM", "features": Session.SANDBOX_FEATURES, "trade": true, "renown": true})
	r.time = 99999.0
	st.attach(r)
	check_near(st.opened_at, t0, 1e-6, "loading doesn't restart it")
	r.dispose()
	d.erase("opened_at")
	var old := Story.from_dict(d)
	var o := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "FRM", "features": Session.SANDBOX_FEATURES, "trade": true, "renown": true})
	o.time = 5000.0
	old.attach(o)
	check_near(old.opened_at, 5000.0, 1e-6, "an older save: from when it is loaded")
	o.dispose()


func test_off_no_clock() -> void:
	Story.PACE = false
	var s := _story(1)
	var r0: float = s.renown.score
	check_eq(s.story.pace_line(), "", "no line")
	_meet(s)
	s.story.advance()
	check_eq(s.renown.score, r0, "no bonus")
	s.dispose()
