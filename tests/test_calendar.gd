extends TestCase
## Loop idea 4: the island's week, posted ahead (Calendar).


func after_each() -> void:
	Calendar.ENABLED = true
	World.use_map(0)


func _story() -> Session:
	var s := Session.new({"seed": 6, "location": "HAR", "career": true})
	Story.new(0).attach(s)
	return s


func _force(s: Session, kind: String) -> void:
	for k in Calendar.KINDS:
		if k[0] == kind:
			s.calendar.upcoming[0] = {"kind": k[0], "good": k[1], "mult": k[2], "minutes": k[3], "text": k[4], "start": s.calendar.upcoming[0].start}


func test_the_week_is_posted_ahead_and_an_event_starts_on_time() -> void:
	var s := _story()
	s.calendar.update(1.0)
	check_eq(s.calendar.upcoming.size(), Calendar.LEAD, "three events posted")
	check_near(float(s.calendar.upcoming[0].start), s.time + Calendar.FIRST_S, 60.0, "the first one half an hour in")
	check(s.calendar.upcoming[1].start > s.calendar.upcoming[0].start, "in order")
	check(s.econ.news.any(func(n): return str(n[1]).begins_with("Coming up")), "in the paper")
	_force(s, "carnival")
	var start := float(s.calendar.upcoming[0].start)
	s.time = start - Calendar.WARN_S + 1.0
	s.calendar.update(1.0)
	check(s.messages.any(func(m): return str(m[1]).begins_with("In 10 minutes")), "the radio's reminder")
	var before := s.econ.mult("cocaine", "town")
	s.time = start + 1.0
	s.calendar.update(1.0)
	check(s.econ.events.any(func(e): return e.good == "cocaine" and e.mult > 1.0), "the carnival is an Economy event")
	check(s.econ.mult("cocaine", "town") > before, "cocaine pays more")
	check_eq(s.calendar.upcoming.size(), Calendar.LEAD, "the next one posted")
	check(s.calendar.lines().size() >= Calendar.LEAD, "the phone's Coming up lines")
	s.dispose()


func test_a_customs_operation_searches_more_loads_then_ends() -> void:
	var s := _story()
	s.calendar.update(1.0)
	_force(s, "customs")
	s.time = float(s.calendar.upcoming[0].start) + 1.0
	s.calendar.update(1.0)
	check_near(s.police.crackdown, Calendar.CRACKDOWN, 1e-6, "customs on")
	var data := StrategicSave.capture(s)
	var t := _story()
	StrategicSave.restore(t, data)
	check_near(t.police.crackdown, Calendar.CRACKDOWN, 1e-6, "still on after a load")
	check_eq(t.calendar.upcoming.size(), s.calendar.upcoming.size(), "the posted week survives a save")
	s.time = s.calendar.crackdown_until + 1.0
	s.calendar.update(1.0)
	check_near(s.police.crackdown, 0.0, 1e-6, "over")
	s.dispose()
	t.dispose()


func test_off_without_a_story_or_the_switch() -> void:
	var p := Session.new({"seed": 6, "location": "HAR"})
	p.calendar.update(1.0)
	check(p.calendar.upcoming.is_empty(), "no story, no calendar")
	p.dispose()
	Calendar.ENABLED = false
	var s := _story()
	s.calendar.update(1.0)
	check(s.calendar.upcoming.is_empty(), "switched off")
	s.dispose()
