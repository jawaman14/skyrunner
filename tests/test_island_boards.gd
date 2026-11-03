extends TestCase
## The island boards' two loose ends after #383: a remote desk sees the other strips' jobs, and the boards survive a save.


func after_each() -> void:
	World.use_map(0)


func _session(seed := 4) -> Session:
	var s := Session.new({"seed": seed, "location": "HAR", "features": Session.SANDBOX_FEATURES})
	s.police.frozen = true
	s.update(1.0 / 30)
	return s


func _ids(s: Session) -> Dictionary:
	var out := {}
	for code in s.boards:
		out[code] = s.boards[code].map(func(j): return j.id)
	return out


func test_a_remote_desk_gets_the_other_strips_nearest_first() -> void:
	var s := _session()
	var snap := Snapshot.build(s, Roles.COPILOT)
	var rows: Array = snap.get("island_board", [])
	check(not rows.is_empty(), "the other strips' jobs reach the desk")
	check(rows.size() <= Snapshot.ISLAND_ROWS, "capped")
	check(rows.all(func(r): return str(r.origin) != s.location), "the parked strip's own jobs stay in 'board'")
	for k in range(1, rows.size()):
		check(float(rows[k - 1].origin_km) <= float(rows[k].origin_km), "nearest origin first")
	var one: Dictionary = rows[0]
	check(s.boards[str(one.origin)].any(func(j): return j.id == int(one.id)), "a row is a real job on that strip's board")
	var saved := Switches.parity_off()
	var off := _session()
	check(Snapshot.build(off, Roles.COPILOT).get("island_board", []).is_empty(), "switch off: no island rows")
	off.dispose()
	Switches.restore(saved)
	s.dispose()


func test_boards_survive_a_save_and_draw_nothing_on_load() -> void:
	var s := _session()
	s.time += 600.0
	s.stock_island_boards()
	var before := _ids(s)
	var titles := {}
	for code in s.boards:
		for j in s.boards[code]:
			titles[j.id] = [j.title, j.payout, j.dest, j.items.size(), j.weight_lb()]
	var data: Dictionary = SaveVars.through_json(StrategicSave.capture(s))
	check(data.has("boards"), "the boards are in the save")
	var t := _session(9)  # another seed: its own boards differ
	var stream: Array = t.rng.get_state()
	var board_stream: Array = t.brng.get_state()
	StrategicSave.restore(t, data)
	check_eq(_ids(t), before, "every strip's jobs come back")
	for code in t.boards:
		for j in t.boards[code]:
			check_eq([j.title, j.payout, j.dest, j.items.size(), j.weight_lb()], titles[j.id], "job %d intact" % j.id)
			check(j.items.all(func(it): return it.job_id == j.id), "its items still point at it")
	check_eq(t.rng.get_state(), stream, "restoring draws nothing")
	check_eq(t.brng.get_state(), board_stream, "nor on the board stream")
	var code: String = before.keys()[0]
	check(t.board_is_fresh(code), "a board saved fresh is still fresh")
	t.stock_island_boards()
	check_eq(_ids(t)[code], before[code], "so it is not redealt on load")
	var top := 0
	for c in t.boards:
		top = maxi(top, Jobs.max_id(t.boards[c]))
	check(Jobs.new_id() > top, "new ids never collide with restored ones")
	t.time += Jobs.BOARD_TTL_S + 1.0
	t.stock_island_boards()
	check(_ids(t)[code] != before[code], "and it ages out as before")
	s.dispose()
	t.dispose()


func test_an_older_save_without_boards_still_loads() -> void:
	var s := _session()
	var data: Dictionary = SaveVars.through_json(StrategicSave.capture(s))
	data.erase("boards")
	var t := _session(9)
	var before := _ids(t)
	StrategicSave.restore(t, data)
	check_eq(_ids(t), before, "no boards in the save: the session's own boards stand")
	s.dispose()
	t.dispose()


func test_a_gun_run_and_a_gig_round_trip() -> void:
	var it := Loadout.Item.new(555001, "Rifle crate", "cargo", 60.0, 555000, {"hot": true})
	var j := Jobs.Job.new(555000, "Rifles", "contraband", "HAR", "FRM", [it], 4000,
		{"weapons": {"rifle": 3}, "checkpoints": [[100.0, 200.0, 300.0, 150.0]], "deadline_s": 900.0, "drop_point": [1.0, 2.0]})
	var back := Jobs.job_from_save(SaveVars.through_json(Jobs.job_to_save(j)))
	check_eq(back.weapons, {"rifle": 3})
	check(back.weapons.rifle is int, "weapon counts are ints again")
	check_eq(back.checkpoints.size(), 1)
	check_near(float(back.deadline_s), 900.0, 0.001)
	check(back.items[0].hot, "the hot flag survives")
	check(back.hot(), "so does the job's heat")
	check(back.accepted_at == null, "a board job is not taken")


## Codex's review of #495: main.gd and the dedicated server restore the save, then attach the story, whose chapters deal every
## board afresh; the saved boards go back on top after the attach.
func test_a_story_save_keeps_its_boards_through_the_attach() -> void:
	var s := Session.new({"seed": 4, "location": "HAR", "career": true, "features": Session.SANDBOX_FEATURES})
	Story.new(1).attach(s)
	s.police.frozen = true
	s.update(1.0 / 30)
	s.time += 300.0
	s.stock_island_boards()
	check(not s._first_missions(), "past the employed opening")
	var before := _ids(s)
	var data: Dictionary = SaveVars.through_json(StrategicSave.capture(s))
	var story_d: Dictionary = SaveVars.through_json(s.story.to_dict())
	var t := Session.new({"seed": 9, "location": "HAR", "career": true, "features": Session.SANDBOX_FEATURES})
	StrategicSave.restore(t, data)  # the load order main.gd and the dedicated server use
	Story.from_dict(story_d).attach(t)
	check_eq(_ids(t), before, "the saved boards, not the ones the chapters dealt")
	check(t.pending_boards.is_empty(), "applied once")
	s.dispose()
	t.dispose()
