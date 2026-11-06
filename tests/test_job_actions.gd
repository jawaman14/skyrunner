extends TestCase
## Job previews are read-only, execution revalidates them, and dropping requires deliberate confirmation.

func after_each() -> void:
	World.use_map(0)


func _session(logistics := false) -> Session:
	var s := Session.new({"seed": 4, "location": "HAR", "features": Session.SANDBOX_FEATURES,
		"map_seed": MapCity.SEED if logistics else 0, "logistics": logistics, "trade": logistics, "payroll": logistics})
	s.police.frozen = true
	s.update(1.0 / 30)
	s.money = 1000
	return s


func _job(s: Session, cost := 50) -> Jobs.Job:
	var item := Loadout.Item.new(987655, "Test cargo", "cargo", 20, 987654)
	var job := Jobs.Job.new(987654, "Test delivery", "cargo", "HAR", "FRM", [item], 500,
		{"cost": cost, "deadline_s": 600})
	s.boards["HAR"] = [job]
	return job


func test_preview_does_not_spend_cash_and_commands_revalidate() -> void:
	var s := _session(true)
	var job := _job(s, 200)
	s.logistics.aboard = 50
	var blocked := s.job_action(Roles.PILOT, "accept_job", job.id)
	check(not blocked.enabled and "cash" in blocked.disabled_reason, "physical cash requirement explained")
	check_eq(s.logistics.aboard, 50, "preview spends no cash")
	check(job.accepted_at == null and s.active_jobs.is_empty(), "preview accepts no job")
	s.logistics.aboard = 300
	var ready := s.job_action(Roles.PILOT, "accept_job", job.id)
	check(ready.enabled and "$200" in ready.preview and "10 min" in ready.preview, "cost and deadline previewed")
	check_eq(s.logistics.aboard, 300, "available preview still spends nothing")
	s.logistics.aboard = 0
	check(not s.command(Roles.PILOT, ready.command, ready.args)[0], "execution rejects changed cash")
	check(s.active_jobs.is_empty(), "failed command changes no job")
	s.logistics.aboard = 300
	check(s.command(Roles.PILOT, ready.command, ready.args)[0], "valid command accepted")
	check_eq(s.logistics.aboard, 100, "paid once")
	check(not s.command(Roles.PILOT, ready.command, ready.args)[0], "duplicate acceptance rejected")
	check_eq(s.logistics.aboard, 100, "duplicate does not charge again")
	s.phase = "enroute"
	check(not s.command(Roles.PILOT, "drop_job", {"job_id": job.id})[0], "airborne drop is an error, not a false acknowledgement")
	check(s.active_jobs.has(job), "job retained")
	var forbidden := s.job_action(Roles.CONTROLLER, "accept_job", job.id)
	check(not forbidden.enabled and forbidden.preview == "", "opposing role gets no job preview")
	s.dispose()


func test_job_menu_confirms_cancels_and_reports_actions() -> void:
	var saved := Switches.parity_off()  # no boards from other strips between the board and the active job: this test is the drop flow
	var s := _session()
	var job := _job(s)
	var menu := JobMenu.new()
	Engine.get_main_loop().root.add_child(menu)
	menu.setup(s)
	menu.open()
	menu.list.select(1)
	check(not menu.action_button.disabled and "$50" in menu.action_preview.text, "visible acceptance action and up-front price")
	menu.action_button.emit_signal("pressed")
	check(s.active_jobs.has(job) and menu.feedback.visible and "Accepted" in menu.feedback.text, "acceptance acknowledged beside the action")
	menu.action_button.emit_signal("pressed")
	check(s.active_jobs.has(job) and menu.cancel_button.visible, "first drop request only asks for confirmation")
	check("not refunded" in menu.action_preview.text, "drop consequences shown")
	menu.cancel_button.emit_signal("pressed")
	check(s.active_jobs.has(job) and menu.pending_drop == -1, "cancel keeps the job")
	menu.key("enter")
	menu.key("right")
	menu.key("left")
	check_eq(menu.pending_drop, -1, "page changes cancel confirmation")
	menu.key("enter")
	s.phase = "enroute"
	menu.key("enter")
	check(s.active_jobs.has(job) and "Not completed:" in menu.feedback.text, "confirmation revalidates parking and explains failure")
	s.phase = "parked"
	menu.key("enter")
	menu.key("enter")
	check(not s.active_jobs.has(job) and "Dropped" in menu.feedback.text, "deliberate confirmed drop succeeds")
	check_eq(s.money, 950, "dropping does not refund the purchase")
	menu.close()
	menu.open()
	check(not menu.feedback.visible and menu.pending_drop == -1, "reopening clears old feedback and confirmation")
	menu.free()
	s.dispose()
	Switches.restore(saved)


## Owner, 14 Oct: the board shows every job on the island, not only this strip's. A job elsewhere can be read but not taken from here.
func test_job_menu_lists_jobs_from_other_strips_and_says_where_to_fly() -> void:
	var s := _session()
	var near := _job(s)
	var item := Loadout.Item.new(987657, "Far cargo", "cargo", 20, 987656)
	var far := Jobs.Job.new(987656, "Far delivery", "cargo", "FRM", "HAR", [item], 300, {})
	s.boards["FRM"] = [far]
	var menu := JobMenu.new()
	Engine.get_main_loop().root.add_child(menu)
	menu.setup(s)
	menu.open()
	var kinds := menu.rows.filter(func(r): return r != null).map(func(r): return r[0])
	check(kinds.has("board") and kinds.has("far"), "the board lists this strip's job and the other strip's job")
	var row := menu.rows.find_custom(func(r): return r != null and r[1] == far)
	check(row >= 0, "the far job has a row")
	menu.list.select(row)
	menu._show_detail()
	check(menu.action_button.disabled, "it cannot be accepted from here")
	var reason := str(s.job_action(Roles.PILOT, "accept_job", far.id).disabled_reason)
	check(("Fly to " + World.airfield("FRM").name) in reason, "and the reason names the strip to fly to: %s" % reason)
	check(not s.active_jobs.has(far) and s.active_jobs.is_empty(), "nothing was accepted")
	check(s.job_action(Roles.PILOT, "accept_job", near.id).enabled, "this strip's own job is still takeable")
	menu.free()
	s.dispose()


## Owner, 16 Oct: persistent island boards. The sim deals every other strip's board, keeps it while it is fresh and deals it afresh once it is stale; with the switch off nothing is dealt for strips you have not visited.
func test_the_sim_keeps_a_board_at_every_strip_and_deals_it_afresh_after_a_while() -> void:
	var s := _session()
	var others := s.world.airfields.filter(func(a): return a.code != s.location and a.kind != "foreign")
	check(others.size() > 1, "the map has other strips")
	check(others.all(func(a): return s.boards.has(a.code)), "every other strip has a board after the first update")
	var code: String = others[0].code
	var before: Array = s.boards[code].map(func(j): return j.id)
	s.stock_island_boards()
	check_eq(s.boards[code].map(func(j): return j.id), before, "a fresh board is not dealt again")
	s.time += Jobs.BOARD_TTL_S + 1.0
	s.stock_island_boards()
	check(s.boards[code].map(func(j): return j.id) != before, "a stale board is dealt afresh")
	check(s.board_is_fresh(code), "and is fresh again")
	s.dispose()
	var saved := Switches.parity_off()
	var off := _session()
	check(not others.any(func(a): return off.boards.has(a.code)), "with the switch off, strips you have not visited have no board")
	check(not off.board_is_fresh(off.location), "and no board counts as fresh")
	off.dispose()
	Switches.restore(saved)


## Codex's review of #383: the strip you are parked at is dealt afresh once its board passes the TTL, on the board stream.
func test_a_pilot_parked_at_a_strip_finds_a_new_board_after_the_ttl() -> void:
	var s := _session()
	check(s.parked, "parked at the start strip")
	var here: String = s.location
	var before: Array = s.boards[here].map(func(j): return j.id)
	s.stock_island_boards()
	check_eq(s.boards[here].map(func(j): return j.id), before, "a fresh board stays")
	var stream: Array = s.rng.get_state()
	s.time += Jobs.BOARD_TTL_S + 1.0
	s.stock_island_boards()
	check(s.boards[here].map(func(j): return j.id) != before, "a stale board at the strip you are parked at is dealt afresh")
	check(s.board_is_fresh(here), "and is fresh again")
	check_eq(s.rng.get_state(), stream, "without touching the main random stream")
	s.phase = "flying"
	var in_air: Array = s.boards[here].map(func(j): return j.id)
	s.time += Jobs.BOARD_TTL_S + 1.0
	s.stock_island_boards()
	check_eq(s.boards[here].map(func(j): return j.id), in_air, "in the air the board of the strip you left is not dealt under you")
	s.dispose()


func test_stale_menu_selection_cannot_accept_an_unavailable_job() -> void:
	var s := _session()
	var job := _job(s)
	var menu := JobMenu.new()
	Engine.get_main_loop().root.add_child(menu)
	menu.setup(s)
	menu.open()
	menu.list.select(menu.rows.find_custom(func(r): return r != null and r[1] == job))  # its row: "Picked for you" may put another strip's job first
	s.boards["HAR"].erase(job)
	menu.key("enter")
	check(s.active_jobs.is_empty() and s.money == 1000, "stale action cannot mutate the session")
	check("no longer available" in menu.feedback.text, "stale selection is explained")
	menu.free()
	s.dispose()


## D-94 (the WoW study): a few clear choices first. "Picked for you" holds at most three jobs, best pay per km of the whole trip
## first, a load the destination strip is too short for is never picked, a picked job is not listed twice, and the far list shows
## the nearest few until A shows all.
func test_the_board_picks_a_few_jobs_first_and_shortens_the_far_list() -> void:
	var saved := Switches.parity_off()
	var s := _session()
	var mk := func(id: int, origin: String, dest: String, pay: int) -> Jobs.Job:
		return Jobs.Job.new(id, "Job %d" % id, "cargo", origin, dest, [Loadout.Item.new(id + 1, "Crate", "cargo", 20, id)], pay, {})
	var cheap: Jobs.Job = mk.call(900001, "HAR", "FRM", 50)
	var rich: Jobs.Job = mk.call(900003, "HAR", "FRM", 5000)
	s.boards["HAR"] = [cheap, rich]
	var others := s.world.airfields.filter(func(a): return a.code != "HAR" and a.code != "FRM" and a.kind != "foreign")
	var far := []
	for a in others:
		s.boards[a.code] = []
	for i in 9:
		var code: String = others[i % others.size()].code
		var j: Jobs.Job = mk.call(900100 + i * 2, code, "HAR", 10)
		far.append(j)
		s.boards[code].append(j)
	s.boards["FRM"] = []
	var picked := JobMenu.picks(s, s.boards["HAR"], far, float(s.loadout.compute().weight_lb))
	check(picked.size() <= JobMenu.PICKS, "at most three picked")
	check(not picked.is_empty() and picked[0] == rich, "the best-paying job here leads")
	check(not picked.has(cheap) or picked.find(cheap) > picked.find(rich), "the poor one does not lead")
	var menu := JobMenu.new()
	Engine.get_main_loop().root.add_child(menu)
	menu.setup(s)
	menu.open()
	var listed := menu.rows.filter(func(r): return r != null).map(func(r): return r[1])
	check_eq(listed.count(rich), 1, "a picked job is listed once")
	var far_rows := menu.rows.filter(func(r): return r != null and r[0] == "far" and not picked.has(r[1])).size()
	check(far_rows <= JobMenu.FAR_SHOWN, "the far list shows the nearest few (%d)" % far_rows)
	menu.key("a")
	var all_far := menu.rows.filter(func(r): return r != null and r[0] == "far").size()
	check(all_far >= far.size(), "A shows every job elsewhere (%d of %d)" % [all_far, far.size()])
	menu.free()
	s.dispose()
	Switches.restore(saved)
