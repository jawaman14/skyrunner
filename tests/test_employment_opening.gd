extends TestCase
const PATH := "user://test_employment_opening.json"
var session: Session

func after_each() -> void:
	if session != null:
		session.dispose()
		session = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	World.use_map(0)

func _start() -> Session:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "career": true, "save_path": PATH})
	Story.new_employed().attach(s)
	return s

func _delivery(s) -> Jobs.Job:
	s.refresh_board(s.location)
	var job: Jobs.Job = s.boards[s.location][0]
	check(s.command(Roles.PILOT, "accept_job", {"job_id": job.id})[0], "employer load accepted")
	s.spawn_at(job.dest)
	if job.hot():
		var stage: int = s.story.employment.stage
		s._arrive(World.airfield(job.dest), s.state)
		check(not s.unloading.is_empty(), "criminal load uses actual unloading")
		check_eq(s.story.employment.stage, stage, "landing alone is not delivery")
		s._unload_tick(Session.UNLOAD_HOT_S + 1.0)
	else:
		s._complete_delivery(job, World.airfield(job.dest))
	return job

func test_employed_start_and_staged_real_delivery_events() -> void:
	session = _start()
	check_eq(session.aircraft_key, "c172p", "immediate access to company aircraft")
	check(session.owned.is_empty(), "access is not ownership")
	check(session.trade == null and session.payroll == null, "business layers wait")
	check_eq(Story.CHAPTERS.size(), 12, "existing twelve chapters retained")
	check_eq(Campaign.CHAPTERS.size(), 4, "existing lessons retained")
	var opening: EmploymentOpening = session.story.employment
	var first := _delivery(session)
	check(not first.hot(), "first legitimate delivery")
	check_eq(opening.stage, 0, "first stage requires two flights")
	session.bus.emit("job_delivered", session.time, "", ["runner"], session._delivered(first, first.payout, World.airfield(first.dest), false))
	check_eq(opening.delivered, 1, "duplicate acknowledgement cannot count twice")
	_delivery(session)
	check_eq(opening.stage, 1)
	check(not _delivery(session).hot(), "suspicious request is still legally neutral")
	check_eq(opening.stage, 2)
	check("smuggling" in session.story.chapter.briefing, "risk is disclosed")
	var criminal := _delivery(session)
	check(criminal.hot(), "final opening load is contraband")
	check_eq(Economy.good_of(criminal), "marijuana", "existing market classification is preserved")
	check(not opening.active(), "opening completed")
	check_eq(session.story.chapter.title, "Square Grouper")
	check(session.trade != null and session.payroll != null, "first story layers open")
	check_eq(session.story.history.size(), 3, "opening stages remembered")
	check(opening.loaner and session.owned.is_empty(), "completion does not grant free aircraft")

func test_stale_work_drop_and_purchase_validation() -> void:
	session = _start()
	var job: Jobs.Job = session.boards["HAR"][0]
	job.employer_stage = 2
	check(not session.command(Roles.PILOT, "accept_job", {"job_id": job.id})[0], "stale stage refused")
	check(session.active_jobs.is_empty(), "refusal does not load")
	job.employer_stage = 0
	check(session.command(Roles.PILOT, "accept_job", {"job_id": job.id})[0])
	check(session.command(Roles.PILOT, "drop_job", {"job_id": job.id})[0])
	check_eq(session.story.employment.delivered, 0, "drop never advances")
	var preview := session.describe_action(Roles.PILOT, "buy_aircraft", {"key": "c172p"})
	check(not preview.enabled, "loaner price cannot be bypassed")
	check_eq(session.aircraft_purchase_price("c172p"), EmploymentOpening.PURCHASE_PRICE)
	var before: int = session.money
	check(not session.command(Roles.PILOT, "buy_aircraft", {"key": "c172p"})[0])
	check_eq(session.money, before, "failed purchase changes no money")
	session.money = EmploymentOpening.PURCHASE_PRICE
	preview = session.describe_action(Roles.PILOT, "buy_aircraft", {"key": "c172p"})
	check(preview.enabled and "18,000" in preview.preview, "actual cost shown")
	check(session.command(Roles.PILOT, "buy_aircraft", {"key": "c172p"})[0])
	check(session.owned.has("c172p") and not session.story.employment.loaner)
	check_eq(session.money, 0)
	check_eq(session.aircraft_purchase_price("c172p"), 0, "owned switch is free")

func test_save_load_keeps_loaner_progress_without_resetting_old_story() -> void:
	session = _start()
	_delivery(session)
	session.save()
	var data := Session.read_save(PATH)
	var restored := Session.load_or_new(PATH, {"map_seed": MapCity.SEED})
	Story.from_dict(data.story).attach(restored)
	check(restored.owned.is_empty(), "reload cannot grant free Cessna")
	check_eq(restored.story.employment.delivered, 1)
	check_eq(restored.story.employment.stage, 0)
	_delivery(restored)
	check_eq(restored.story.employment.stage, 1)
	restored.dispose()
	var legacy := Story.from_dict({"index": 2, "v": 4, "progress": {"acid_lb": 12}})
	check(legacy.employment == null, "old story avoids new opening")
	check_eq(legacy.chapter.title, "Blotter")
	check_eq(legacy.progress.acid_lb, 12)

func test_completed_opening_save_retains_unowned_aircraft() -> void:
	session = _start()
	for i in 4:
		_delivery(session)
	session.save()
	var data := Session.read_save(PATH)
	var restored := Session.load_or_new(PATH, {"map_seed": MapCity.SEED})
	Story.from_dict(data.story).attach(restored)
	check(restored.owned.is_empty() and restored.story.employment.loaner)
	check_eq(restored.story.chapter.title, "Square Grouper")
	check_eq(restored.aircraft_purchase_price("c172p"), EmploymentOpening.PURCHASE_PRICE)
	restored.dispose()

func test_buying_another_aircraft_does_not_make_the_company_cessna_free() -> void:
	session = _start()
	session.money = Aircraft.ROSTER["c182"].price
	check(session.command(Roles.PILOT, "buy_aircraft", {"key": "c182"})[0])
	check(not session.story.employment.loaner and session.owned.has("c182"))
	check(not session.owned.has("c172p"), "company aircraft was returned")
	check_eq(session.aircraft_purchase_price("c172p"), EmploymentOpening.PURCHASE_PRICE)
	check(not session.command(Roles.PILOT, "buy_aircraft", {"key": "c172p"})[0], "cannot reacquire for free")

func test_first_smuggling_uses_suitable_strip_without_disabling_police() -> void:
	session = _start()
	session.story.employment.stage = 2
	session.refresh_board("HAR")
	var job: Jobs.Job = session.boards["HAR"][0]
	var field := World.airfield(job.dest)
	check(not field.police and field.kind in ["bush", "shady"])
	check(field.length >= 400, "first criminal landing avoids the shortest strips")
	check(job.hot() and "police consequences" in job.notes, "risk remains disclosed")
	check(not session.police.no_customs, "customs authority is unchanged")
	var case = session.police.case("runner")
	case.wanted = 1
	check(session.police.landing_check(session.state, World.airfield("HAR"), true), "wanted arrival at police airport is still refused")

func test_generated_maps_have_an_unpoliced_employer_destination() -> void:
	for seed in [1, 7, 42]:
		var s := Session.new({"seed": 5, "map_seed": seed, "location": "HAR"})
		Story.new_employed().attach(s)
		s.story.employment.stage = 2
		s.refresh_board("HAR")
		check(not s.boards["HAR"].is_empty(), "generated %d offers a criminal destination" % seed)
		if not s.boards["HAR"].is_empty():
			var field := World.airfield(s.boards["HAR"][0].dest)
			check(not field.police and field.length >= 400)
		s.dispose()
