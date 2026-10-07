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


func test_stale_menu_selection_cannot_accept_an_unavailable_job() -> void:
	var s := _session()
	var job := _job(s)
	var menu := JobMenu.new()
	Engine.get_main_loop().root.add_child(menu)
	menu.setup(s)
	menu.open()
	menu.list.select(1)
	s.boards["HAR"].erase(job)
	menu.key("enter")
	check(s.active_jobs.is_empty() and s.money == 1000, "stale action cannot mutate the session")
	check("no longer available" in menu.feedback.text, "stale selection is explained")
	menu.free()
	s.dispose()
