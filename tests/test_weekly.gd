extends TestCase
## The week's work (D-93): three goals a week, counted off the bus, renown for each, a bonus and a run for all three.


func after_each() -> void:
	World.use_map(0)


func _story(seed := 4) -> Session:
	var s := Session.new({"seed": seed, "location": "HAR", "career": true, "renown": true, "features": Session.SANDBOX_FEATURES})
	Story.new(1).attach(s)
	s.police.frozen = true
	return s


func _goals(s: Session, kinds: Array) -> void:
	s.weekly.goals = []
	for k in kinds:
		var at_end: bool = k in ["clean", "turf"]
		s.weekly.goals.append({"kind": k, "text": "Goal " + k, "target": 2 if k == "loads" else 1, "progress": 0, "done": false, "at_end": at_end})


func test_a_week_posts_three_goals_on_its_own_stream() -> void:
	var s := _story()
	var main_rng: Array = s.rng.get_state()
	s.update(1.0 / 30)
	check_eq(s.weekly.week, 1, "the first week is posted")
	check_eq(s.weekly.goals.size(), Weekly.PICK)
	var kinds := s.weekly.goals.map(func(g): return g.kind)
	for k in kinds:
		check_eq(kinds.count(k), 1, "no goal twice")
	check_eq(s.rng.get_state(), main_rng, "the main stream is untouched")
	check_near(s.weekly.ends, s.time + Weekly.WEEK_S, 1.0)
	s.dispose()


func test_goals_count_off_the_bus_and_pay_renown() -> void:
	var s := _story()
	s.update(1.0 / 30)
	_goals(s, ["loads", "hot", "clean"])
	var r0: float = s.renown.score
	s.bus.emit("job_delivered", s.time, "", ["runner"], {"hot": false})
	check_eq(int(s.weekly.goals[0].progress), 1)
	check(not s.weekly.goals[1].done, "a cold load is not a hot one")
	s.bus.emit("job_delivered", s.time, "", ["runner"], {"hot": true})
	check(s.weekly.goals[0].done, "two loads")
	check(s.weekly.goals[1].done, "one hot load")
	check(s.renown.score >= r0 + 2.0 * Weekly.POINTS - 0.01, "renown for each goal (plus the loads' own)")
	s.dispose()


func test_a_clean_week_clears_and_runs_on() -> void:
	var s := _story()
	s.update(1.0 / 30)
	_goals(s, ["loads", "clean"])
	s.bus.emit("job_delivered", s.time, "", ["runner"], {})
	s.bus.emit("job_delivered", s.time, "", ["runner"], {})
	var r0: float = s.renown.score
	s.time = s.weekly.ends + 1.0
	s.weekly.update(1.0)
	check_eq(s.weekly.run, 1, "every goal met: the run starts")
	check(s.renown.score >= r0 + Weekly.POINTS + Weekly.CLEAR_BONUS - 0.01, "the clean week and the sweep pay")
	check_eq(s.weekly.week, 2, "the next week is posted")
	check_eq(s.weekly.history.back().met, 2)
	_goals(s, ["clean"])
	s.bus.emit("busted", s.time, "", ["runner"], {})
	s.time = s.weekly.ends + 1.0
	s.weekly.update(1.0)
	check_eq(s.weekly.run, 0, "a bust spoils the clean week and breaks the run")
	check_eq(s.weekly.best, 1, "the best run is kept")
	s.dispose()


func test_not_in_the_employed_opening_or_a_replay() -> void:
	var e := Session.new({"seed": 4, "location": "HAR", "career": true, "renown": true, "features": Session.SANDBOX_FEATURES})
	Story.new_employed().attach(e)
	e.update(1.0 / 30)
	check_eq(e.weekly.week, 0, "the opening has its own goals")
	e.dispose()
	var p := Session.new({"seed": 4, "location": "HAR"})
	p.update(1.0 / 30)
	check_eq(p.weekly.week, 0, "no story and no renown: nothing posted")
	p.dispose()
	var was := Weekly.ENABLED
	Weekly.ENABLED = false
	var off := _story()
	off.update(1.0 / 30)
	check_eq(off.weekly.week, 0, "switched off")
	off.dispose()
	Weekly.ENABLED = was


func test_a_save_keeps_the_week_and_draws_nothing() -> void:
	var s := _story()
	s.update(1.0 / 30)
	s.bus.emit("job_delivered", s.time, "", ["runner"], {"hot": true})
	var data: Dictionary = SaveVars.through_json(StrategicSave.capture(s))
	var t := _story(9)
	StrategicSave.restore(t, data)
	check_eq(t.weekly.week, s.weekly.week)
	check_eq(JSON.stringify(t.weekly.goals), JSON.stringify(s.weekly.goals), "the same goals and progress")
	t.update(1.0 / 30)
	check_eq(t.weekly.week, s.weekly.week, "not reposted on load")
	check_eq(t.weekly.rng.get_state(), s.weekly.rng.get_state(), "the stream carries on where the save left it, so next week's picks are not the first week's again")
	var lines := t.weekly.lines()
	check(str(lines[0]).begins_with("# Week"), "the phone's Week app has the week")
	check(lines.any(func(l): return str(l).begins_with("Weeks cleared")), "and the run")
	s.dispose()
	t.dispose()


## Codex review (#499): a goal no buyer can meet is not posted. With every bulk buyer closed, no sale or order goal.
func test_no_buyer_goals_when_no_buyer_is_open() -> void:
	var s := _story()
	s.update(1.0 / 30)
	var open_buyers := Trade.BUYERS.keys().filter(func(b): return s.trade != null and s.trade.available(b) == "")
	var kinds: Array = s.weekly._pool().map(func(g): return g[0])
	if open_buyers.is_empty():
		check(not kinds.has("bulk") and not kinds.has("order"), "no buyer open: no sale or order goal (%s)" % [kinds])
	else:
		check(kinds.has("bulk"), "a buyer open: the sale goal can be posted")
	if s.family != null:
		s.family.respect = 0.0  # the Morettis won't deal
	if s.agency != null:
		s.agency.hung_out = true
	var still := Trade.BUYERS.keys().filter(func(b): return s.trade != null and s.trade.available(b) == "")
	if still.is_empty():
		kinds = s.weekly._pool().map(func(g): return g[0])
		check(not kinds.has("bulk") and not kinds.has("order"), "every buyer closed: neither goal (%s)" % [kinds])
	s.dispose()
