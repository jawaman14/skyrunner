extends TestCase
## The fixer's seat: the organisation's business between flights (jobs, gear, spotters, the hiring hall, the Family),
## from a desk, without touching the aircraft's controls.

var _sess: Session


func after_each() -> void:
	if _sess != null:
		_sess.dispose()
		_sess = null
	World.use_map(0)


func _session(opts := {}) -> Session:
	var o := {"seed": 17, "mode": Roles.COOP, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES,
		"humans": {Roles.FIXER: "Fran"}, "payroll": true, "family": true, "trade": true, "money": 20000}
	o.merge(opts, true)
	_sess = Session.new(o)
	_sess.police.frozen = true
	_sess.update(1.0 / 30)
	return _sess


func test_the_fixer_does_business_but_does_not_fly() -> void:
	for c in ["accept_job", "drop_job", "buy_gear", "hire_spotter", "hire_worker", "family_accept", "sell_product", "chat"]:
		check(Roles.allowed(Roles.FIXER, c), "the fixer may %s" % c)
	for c in ["kick", "pump", "autopilot", "transponder", "squawk", "turn_around", "call_boat", "launch", "squad_order", "race_enter"]:
		check(not Roles.allowed(Roles.FIXER, c), "but not %s" % c)
	check_eq(Roles.side(Roles.FIXER), "runner", "a runner-side seat")
	check(Roles.COOP in Roles.MODE_ROLES and Roles.MODE_ROLES[Roles.COOP].has(Roles.FIXER), "open at a co-op table")
	check(Roles.ABOUT.has(Roles.FIXER), "and described for the seat list")


func test_the_fixer_books_a_job_and_drops_it() -> void:
	var s := _session()
	var board: Array = s.boards.get(s.location, [])
	check(not board.is_empty(), "there is a board at %s" % s.location)
	var jid: int = board[0].id
	var before: int = s.active_jobs.size()
	check(s.command(Roles.FIXER, "accept_job", {"job_id": jid})[0], "booked")
	check_eq(s.active_jobs.size(), before + 1, "it is in hand")
	check(s.command(Roles.FIXER, "drop_job", {"job_id": jid})[0], "dropped")
	check_eq(s.active_jobs.size(), before, "and gone again")


func test_the_fixer_buys_gear_and_hires_a_spotter() -> void:
	var s := _session()
	var m: int = s.money
	check(s.command(Roles.FIXER, "buy_gear", {"name": "scanner"})[0], "a scanner")
	check(s.gear.has("scanner") and s.money < m, "fitted, and paid for")
	var m2: int = s.money
	check(s.command(Roles.FIXER, "hire_spotter", {})[0], "a spotter here")
	check(s.spotters.any(func(sp): return sp.code == s.location) and s.money == m2 - Session.SPOTTER_FEE, "watching this strip, for the fee")
	check(not s.command(Roles.FIXER, "kick", {})[0], "the aircraft's own controls are refused")


func test_the_seat_is_in_the_room_and_the_snapshot_carries_the_business() -> void:
	var room := Room.new(Roles.COOP, "Host", Roles.PILOT)
	check(room.seats().any(func(x): return x.role == Roles.FIXER), "the waiting room lists the fixer")
	var s := _session()
	var snap := Snapshot.build(s, Roles.FIXER)
	check(snap.has("board") and snap.has("payroll") and snap.has("family") and snap.has("money"), "a runner snapshot with the board, the crew and the Family")


func test_the_desk_draws_the_jobs_and_its_keys_do_the_business() -> void:
	var s := _session()
	var link := LocalLink.new(s, Roles.FIXER)
	var app := StationApp.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	app.setup(link, Roles.FIXER, s.world)
	app._process(0.016)
	check_eq(app.title.text, "FIXER", "the desk's title")
	check(app.list.row_count() >= 1, "the board's jobs are on the table")
	var taken: int = s.active_jobs.size()
	app.list.select(0)
	app._key("enter")
	check_eq(s.active_jobs.size(), taken, "preview does not book a job")
	await _confirm_review(app)
	check_eq(s.active_jobs.size(), taken + 1, "ENTER books the highlighted job")
	app._process(0.016)
	var m: int = s.money
	app._key("g")
	check(not s.gear.has("scanner"), "preview does not buy gear")
	await _confirm_review(app)
	check(s.gear.has("scanner") and s.money < m, "G buys the scanner")
	app._key("s")
	check(s.spotters.size() == 1, "S hires a spotter here")
	app._process(0.016)
	check(app.info.text.contains("THE CREW") and app.info.text.contains("SPOTTERS: " + s.location), "the desk shows the crew and the spotters: %s" % app.info.text.substr(0, 200))
	app._key("w")
	check(app.talk != null, "W opens the hiring hall")
	if app.talk != null:
		app.talk.queue_free()
	app.queue_free()


func _confirm_review(app: StationApp) -> void:
	check(app.review != null, "committing action opens a review")
	if app.review == null:
		return
	for frame in 3:
		await Engine.get_main_loop().process_frame
	app.review._answered(true)
	for frame in 3:
		await Engine.get_main_loop().process_frame
