extends TestCase
## Cursed jobs (D-95): a board job can offer an optional condition with a stated premium; kept, the premium is paid on delivery;
## broken, only the premium is lost.


func _sess() -> Session:
	var s := Session.new({"seed": 12, "location": "HAR"})
	s.police.frozen = true
	s.update(1.0 / 30)
	return s


func _job(s: Session, curse: String, pay := 4000) -> Jobs.Job:
	var jid := Jobs.new_id()
	var j := Jobs.Job.new(jid, "Machine parts -> Farm strip", "cargo", "HAR", "FRM", [Loadout.Item.new(Jobs.new_id(), "Crate", "cargo", 100.0, jid)], pay)
	j.curse = curse
	s.boards["HAR"].append(j)
	return j


func _take(s: Session, j: Jobs.Job) -> void:
	Curses.toggle(j)
	check(s.accept_job(j) == null, "accepted")


func _fly(s: Session) -> void:
	s.log.airborne = true
	s.state.on_ground = false


func _deliver(s: Session, j: Jobs.Job, fpm := 100.0) -> void:
	var flown := Session.FlightLog.new()
	flown.last_touchdown_fpm = fpm
	s.curses.arrived("FRM", flown)  # the landing judges the conditions
	s.bus.emit("job_delivered", s.time, "", ["runner"], {"job_id": j.id, "dest": "FRM"})


func test_about_one_job_in_four_offers_a_condition() -> void:
	var s := _sess()
	var board := []
	for i in 800:
		var jid := Jobs.new_id()
		board.append(Jobs.Job.new(jid, "x", "cargo", "HAR", "FRM", [], 1000))
	s.curses.offer(board)
	var n := board.filter(func(j): return j.curse != "").size()
	check_near(n / 800.0, 1.0 / Curses.OFFER_IN, 0.05, "about one in four: %d" % n)
	var kinds := {}
	for j in board:
		kinds[j.curse] = true
	for c in Curses.ORDER:
		check(kinds.has(c), "%s is dealt" % c)
	s.dispose()


func test_airdrops_gigs_and_the_employers_work_get_none() -> void:
	var s := _sess()
	var jid := Jobs.new_id()
	var gig := Jobs.Job.new(jid, "Photos", "cargo", "HAR", "FRM", [], 1000)
	gig.checkpoints = [[0.0, 0.0, 100.0, 300.0]]
	check(not Curses.eligible(gig), "a side gig")
	var emp := Jobs.Job.new(Jobs.new_id(), "Charter", "passenger", "HAR", "FRM", [], 1000)
	emp.employer_serial = 3
	check(not Curses.eligible(emp), "the employer's work")
	check(not Curses.eligible(Jobs.Job.new(Jobs.new_id(), "Windfall: parts", "cargo", "HAR", "FRM", [], 1000)), "a windfall")
	s.dispose()


func test_a_kept_condition_pays_the_premium_on_delivery() -> void:
	var s := _sess()
	var j := _job(s, "squawk")
	_take(s, j)
	_fly(s)
	s.transponder = true
	s.curses.update(false)
	var m: int = s.money
	_deliver(s, j)
	check_eq(s.money, m + Curses.premium(j), "the premium: $%d" % Curses.premium(j))
	check_eq(Curses.premium(j), 1400, "35% of $4,000")
	check(s.bus.log.any(func(e): return e.kind == "curse_kept"), "on the bus")
	s.dispose()


func test_a_broken_condition_loses_only_the_premium() -> void:
	var s := _sess()
	var j := _job(s, "squawk")
	_take(s, j)
	_fly(s)
	s.transponder = false
	s.curses.update(false)
	check(s.bus.log.any(func(e): return e.kind == "curse_broken"), "broken, and told so")
	var m: int = s.money
	_deliver(s, j)
	check_eq(s.money, m, "no premium (the job's own pay is the delivery's business, untouched)")
	s.dispose()


func test_a_job_taken_without_the_condition_is_an_ordinary_job() -> void:
	var s := _sess()
	var j := _job(s, "squawk")
	check(s.accept_job(j) == null, "accepted, condition left")
	_fly(s)
	s.transponder = false
	s.curses.update(false)
	var m: int = s.money
	_deliver(s, j)
	check_eq(s.money, m, "nothing extra, nothing broken")
	check(not s.bus.log.any(func(e): return e.kind == "curse_broken"), "no condition to break")
	s.dispose()


func test_under_the_radar() -> void:
	var s := _sess()
	var j := _job(s, "low")
	_take(s, j)
	_fly(s)
	s.state.agl = Curses.LOW_AGL_M - 10.0
	s.curses.update(false)
	check(not s.curses.taken[j.id].broken, "low is fine")
	s.state.agl = Curses.LOW_AGL_M + 10.0
	s.curses.update(false)
	check(s.curses.taken[j.id].broken, "climbing breaks it")
	s.dispose()


func test_hands_on_counts_the_autopilot_and_the_ai_pilot() -> void:
	var s := _sess()
	var a := _job(s, "hands")
	_take(s, a)
	_fly(s)
	s.curses.update(true)
	check(s.curses.taken[a.id].broken, "the AI pilot flew it")
	s.dispose()


func test_the_clock_starts_at_take_off() -> void:
	var s := _sess()
	var j := _job(s, "clock")
	_take(s, j)
	s.time += 10000.0  # on the ground: no clock yet
	s.curses.update(false)
	check(not s.curses.taken[j.id].broken, "waiting on the ground costs nothing")
	_fly(s)
	s.curses.update(false)
	s.time += Curses.clock_s(j) + 1.0
	s.curses.update(false)
	check(s.curses.taken[j.id].broken, "out of time")
	s.dispose()


func test_fragile_is_judged_by_the_touchdown() -> void:
	var s := _sess()
	var j := _job(s, "gentle")
	_take(s, j)
	var m: int = s.money
	_deliver(s, j, Curses.GENTLE_FPM + 100.0)
	check_eq(s.money, m, "a hard landing: no premium")
	var k := _job(s, "gentle")
	_take(s, k)
	_deliver(s, k, Curses.GENTLE_FPM - 50.0)
	check_eq(s.money, m + Curses.premium(k), "a gentle one: paid")
	s.dispose()


func test_the_board_shows_the_condition_and_its_price() -> void:
	var s := _sess()
	var j := _job(s, "clock")
	var text := Curses.line(j)
	check("minutes of take-off" in text and "+30%" in text and "$1,200" in text, text)
	check(Curses.toggle(j).begins_with("Taken"), "X takes it")
	check(Curses.toggle(j).begins_with("Left"), "X again leaves it")
	s.dispose()


func test_a_board_offer_survives_a_save() -> void:
	var s := _sess()
	var j := _job(s, "low")
	j.cursed = true
	var back := Jobs.job_from_save(SaveVars.through_json(Jobs.job_to_save(j)))
	check(back.curse == "low" and back.cursed, "the offer and the choice")
	var d: Dictionary = SaveVars.through_json(StrategicSave.capture(s))
	var next: int = s.curses.rng.randint(1, 1000)
	var t := Session.new({"seed": 13, "location": "HAR"})
	StrategicSave.restore(t, d)
	check_eq(t.curses.rng.randint(1, 1000), next, "the stream carries on")
	s.dispose()
	t.dispose()


func test_off_means_no_offers() -> void:
	Curses.ENABLED = false
	var s := Session.new({"seed": 12, "location": "HAR"})
	check(s.curses == null, "not built")
	s.dispose()
	Curses.ENABLED = true


## Codex on #522: a hot load's 60 s count or a stash run's truck pays after the landing; the landing is what is judged.
func test_the_landing_is_judged_not_the_payout() -> void:
	var s := _sess()
	var j := _job(s, "clock")
	_take(s, j)
	_fly(s)
	s.curses.update(false)
	var flown := Session.FlightLog.new()
	flown.last_touchdown_fpm = 500.0
	s.curses.arrived("FRM", flown)  # in time
	s.time += Curses.clock_s(j) * 3.0  # the count (or the truck) takes its time
	s.curses.update(false)
	check(not s.curses.taken[j.id].broken, "the clock stopped at the landing")
	s.active_jobs.erase(j)  # a stash run: the job leaves the aircraft with the truck
	s.curses.update(false)
	check(s.curses.taken.has(j.id), "and the premium waits for the truck")
	var m: int = s.money
	s.bus.emit("job_delivered", s.time, "", ["runner"], {"job_id": j.id, "dest": "FRM"})
	check_eq(s.money, m + Curses.premium(j), "paid when the truck arrives")
	s.dispose()


func test_a_gentle_landing_is_read_off_the_flight_not_the_next_log() -> void:
	var s := _sess()
	var j := _job(s, "gentle")
	_take(s, j)
	var flown := Session.FlightLog.new()
	flown.last_touchdown_fpm = Curses.GENTLE_FPM + 200.0
	s.curses.arrived("FRM", flown)
	s.log = Session.FlightLog.new()  # the session renews its log at the landing: 0 fpm
	var m: int = s.money
	s.bus.emit("job_delivered", s.time, "", ["runner"], {"job_id": j.id, "dest": "FRM"})
	check_eq(s.money, m, "the hard landing still counts")
	s.dispose()
