extends TestCase
## Breakaway (D-95): a stop on the ground opens a window to get out - run, dump the load or pay - and the window running out is
## the bust as it always was. One a day, more with renown; the task force is on alert after one.


func _sess() -> Session:
	var s := Session.new({"seed": 8, "location": "HAR"})
	s.police.frozen = true
	s.update(1.0 / 30)
	return s


func _load(s: Session, pay := 5000) -> Jobs.Job:
	var jid := Jobs.new_id()
	var j := Jobs.Job.new(jid, "a load", "contraband", "HAR", "FRM", [Jobs.item("Unmarked crate", "cargo", 200, jid, {"hot": true})], pay)
	s.active_jobs.append(j)
	return j


func _busts(s: Session) -> int:
	return s.bus.log.filter(func(e): return e.kind == "busted").size()


func test_a_stop_opens_a_window_and_running_out_of_time_is_the_bust() -> void:
	var s := _sess()
	_load(s)
	s._bust("arrested on landing at Harbor", true)
	check(s.breakaway.active(), "a window, not a bust")
	check(s.phase != "busted" and _busts(s) == 0, "nothing has happened yet")
	check(s.bus.log.any(func(e): return e.kind == "breakaway"), "the stop is on the bus")
	s.time += Breakaway.WINDOW_S + 1.0
	s.breakaway.update()
	check(not s.breakaway.active(), "the window shut")
	check_eq(s.phase, "busted", "and the bust went through")
	check_eq(_busts(s), 1, "once")
	s.dispose()


func test_taking_off_and_getting_clear_is_a_run() -> void:
	var s := _sess()
	_load(s)
	var c = s.police.case("runner")
	var heat: float = c.suspicion
	s._bust("arrested on landing at Harbor", true)
	s.state.on_ground = false
	s.state.x += Breakaway.RUN_M + 50.0
	s.breakaway.update()
	check(not s.breakaway.active() and s.phase != "busted", "free")
	check(c.wanted >= 1, "with the patrol on your tail")
	check_near(c.suspicion, minf(100.0, heat + Breakaway.HEAT_RUN), 0.01, "and the heat up")
	check_eq(s.active_jobs.size(), 1, "the load is still aboard")
	check(s.bus.log.any(func(e): return e.kind == "broke_away" and e.data.way == "run"), "a run, on the bus")
	s.dispose()


func test_a_short_hop_on_the_ground_is_not_a_run() -> void:
	var s := _sess()
	_load(s)
	s._bust("arrested on landing at Harbor", true)
	s.state.x += Breakaway.RUN_M + 50.0  # still rolling
	s.breakaway.update()
	check(s.breakaway.active(), "only clear in the air counts")
	s.dispose()


func test_dumping_the_load_seizes_it_and_frees_you() -> void:
	var s := _sess()
	var j := _load(s)
	s._bust("raided on the ground at Harbor", true)
	var r: Array = s.command(Roles.PILOT, "breakaway_dump", {})
	check(r[0], "dumped: %s" % [r])
	check(not s.active_jobs.has(j), "the load is theirs")
	check(not s.breakaway.active() and s.phase != "busted", "and you walk")
	check_eq(_busts(s), 0, "no bust")
	s.dispose()


func test_paying_him_off_costs_the_bribe() -> void:
	var s := _sess()
	_load(s, 5000)
	s.money = 20000
	s._bust("arrested on landing at Harbor", true)
	var b := s.breakaway.bribe()
	check(b >= Breakaway.BRIBE_BASE, "at least the base: $%d" % b)
	var r: Array = s.command(Roles.PILOT, "breakaway_pay", {})
	check(r[0], "paid: %s" % [r])
	check_eq(s.money, 20000 - b, "the bribe left the safe")
	check(s.ledger.log.any(func(row): return row.reason == "bribe"), "booked as a bribe")
	check_eq(s.active_jobs.size(), 1, "the load stays")
	s.dispose()


func test_no_money_no_deal() -> void:
	var s := _sess()
	_load(s)
	s.money = 100
	s._bust("arrested on landing at Harbor", true)
	var r: Array = s.command(Roles.PILOT, "breakaway_pay", {})
	check(not r[0], "refused: %s" % [r])
	check(s.breakaway.active(), "still stopped")
	s.dispose()


func test_one_a_day_then_the_next_stop_goes_through() -> void:
	var s := _sess()
	_load(s)
	s._bust("arrested on landing at Harbor", true)
	s.command(Roles.PILOT, "breakaway_dump", {})
	s.time += Breakaway.ALERT_S + 1.0  # past the alert, same day
	_load(s)
	s._bust("arrested on landing at Harbor", true)
	check(not s.breakaway.active() and s.phase == "busted", "today's is used: straight to the bust")
	s.dispose()


func test_a_new_day_brings_another() -> void:
	var s := _sess()
	_load(s)
	s._bust("arrested on landing at Harbor", true)
	s.command(Roles.PILOT, "breakaway_dump", {})
	s.time += Breakaway.DAY_S
	_load(s)
	s._bust("arrested on landing at Harbor", true)
	check(s.breakaway.active(), "tomorrow's")
	s.dispose()


func test_the_alert_after_one() -> void:
	var s := _sess()
	s.breakaway.day = int(s.time / Breakaway.DAY_S)
	s.breakaway.used = -5  # plenty left today
	s.breakaway.last_free = s.time - 10.0
	_load(s)
	s._bust("arrested on landing at Harbor", true)
	check(not s.breakaway.active() and s.phase == "busted", "on alert: no second chance so soon")
	s.dispose()


func test_more_with_a_bigger_name() -> void:
	check_eq(Breakaway.allowance(0), 1, "a nobody: one")
	check_eq(Breakaway.allowance(1), 1, "a name on the street: one")
	check_eq(Breakaway.allowance(2), 2, "known: two")
	check_eq(Breakaway.allowance(4), 3, "a legend: three")


func test_the_air_chase_and_foot_arrests_are_not_breakaways() -> void:
	var s := _sess()
	_load(s)
	s._bust("forced down by police")
	check(not s.breakaway.active() and s.phase == "busted", "forced down: the bust as before")
	s.dispose()


func test_a_second_stop_while_getting_away_ends_it() -> void:
	var s := _sess()
	_load(s)
	s._bust("arrested on landing at Harbor", true)
	s._bust("raided on the ground at Harbor", true)
	check(not s.breakaway.active() and s.phase == "busted", "no second chance inside the first")
	s.dispose()


func test_saved_with_the_game() -> void:
	var s := _sess()
	_load(s)
	s._bust("arrested on landing at Harbor", true)
	s.command(Roles.PILOT, "breakaway_dump", {})
	var d: Dictionary = SaveVars.through_json(StrategicSave.capture(s))
	var t := Session.new({"seed": 9, "location": "HAR"})
	StrategicSave.restore(t, d)
	check_eq(t.breakaway.used, 1, "today's is still used")
	check_near(t.breakaway.last_free, s.breakaway.last_free, 0.01, "and the alert stands")
	s.dispose()
	t.dispose()


func test_off_means_the_old_bust() -> void:
	Breakaway.ENABLED = false
	var s := _sess()
	_load(s)
	s._bust("arrested on landing at Harbor", true)
	check(s.breakaway == null, "not built")
	check_eq(s.phase, "busted", "the bust as it always was")
	s.dispose()
	Breakaway.ENABLED = true


# ------------------------------------------------------------------ the review's cases (#517)
func _landed_at_quarry() -> Array:
	var s := Session.new({"seed": 3, "location": "QRY", "features": Session.SANDBOX_FEATURES})
	s.update(1.0 / 30)
	var job: Jobs.Job = Py.first(s.boards["QRY"], func(j): return j.hot() and not j.is_airdrop())
	job.dest = "QRY"
	s.accept_job(job)
	s.loadout.pending.clear()
	s._arrive(s.airfield, s.state)
	return [s, job]


func test_an_arrest_on_landing_is_checked_once_and_paying_lets_the_landing_go_on() -> void:
	var s := _sess()
	var c = s.police.case("runner")
	var af: Airfield = Py.first(s.world.airfields, func(a): return a.police)
	s.police.frozen = false
	s.police.units.clear()
	c.wanted = 1  # a wanted pilot at a police field: the landing check says yes every time it is asked
	s.money = 100000
	s.phase = "parked"
	s.log.airborne = true
	s._arrive(af, s.state)
	check(s.breakaway.active(), "stopped on landing")
	check(not s.log.airborne, "this landing is handled: the next frame does not check it again")
	var r: Array = s.breakaway.pay()
	check(r[0], str(r))
	check(not s.breakaway.active() and s.phase == "parked", "paid, and still parked: the landing went on (%s)" % s.phase)
	check_eq(_busts(s), 0, "the same officer did not stop him again")
	var heat: float = s.police.case("runner").suspicion  # (the landing settling the case rebuilds it)
	check(heat >= Breakaway.HEAT_PAY - 0.01, "the bribe's heat outlives the landing settling the case: %.1f" % heat)
	s.dispose()


func test_customs_is_not_asked_twice_for_one_landing() -> void:
	var s := _sess()
	var af: Airfield = Py.first(s.world.airfields, func(a): return a.police)
	s.police.frozen = false
	s.police.units.clear()
	s.police.case("runner").wanted = 1
	s.money = 100000
	s.phase = "parked"
	s._arrive(af, s.state)
	var streak: int = s.police.customs_streak
	var draws: Array = s.police.rng.get_state()
	s.breakaway.pay()
	check_eq(s.police.customs_streak, streak, "no second inspection")
	check(s.police.rng.get_state() == draws, "and no second draw")
	s.dispose()


func test_a_stop_under_way_is_not_saved() -> void:
	var s := _sess()
	_load(s)
	s._bust("arrested on landing at Harbor", true)
	var d: Dictionary = SaveVars.through_json(StrategicSave.capture(s))
	var t := Session.new({"seed": 9, "location": "HAR"})
	StrategicSave.restore(t, d)
	check(not t.breakaway.active(), "it comes back parked, like any save mid-flight (the cargo aboard is not kept either)")
	check_eq(t.breakaway.used, 1, "but the count is")
	s.dispose()
	t.dispose()


func test_paying_off_a_raid_lets_the_count_go_on() -> void:
	var r := _landed_at_quarry()
	var s: Session = r[0]
	var job: Jobs.Job = r[1]
	s.money = 100000
	var af := World.airfield("QRY")
	s.police.units.append(PoliceSystem.Pursuer.new("heli", af.x + 800, af.y, s.state.alt + 150, 0.0, [0, 0], {"id": "Hawk-9"}))
	for i in 20:
		s.update(0.1)
	check(s.breakaway.active() and s.unloading.is_empty(), "raided: the count stopped")
	check(s.breakaway.pay()[0], "paid")
	check(s.unloading == [job], "the count goes on")
	var m: int = s.money
	for i in 62 * 10:
		s.update(0.1)
	check(s.phase != "busted" and not (job in s.active_jobs) and s.money > m, "and the load is delivered and paid, with the helicopter still there")
	s.dispose()


func test_dumping_lightens_the_aircraft() -> void:
	var r := _landed_at_quarry()
	var s: Session = r[0]
	var w0 := _stations(s)
	s._bust("raided on the ground at Quarry", true)
	check(s.breakaway.dump()[0], "dumped")
	check(_stations(s) < w0, "the flight model carries less: %.0f < %.0f lb" % [_stations(s), w0])
	s.dispose()


func _stations(s: Session) -> float:
	var t := 0.0
	for st in s.fm.fdm.stations:
		t += float(st.lb)
	return t


func test_a_crash_ends_the_window() -> void:
	var s := _sess()
	_load(s)
	s._bust("arrested on landing at Harbor", true)
	s._crash("Ran off the strip into rough ground")
	check(not s.breakaway.active(), "crashed getting away: no stop left to run out")
	s.time += Breakaway.WINDOW_S + 1.0
	s.breakaway.update()
	check_eq(_busts(s), 0, "and no arrest after the crash")
	s.dispose()


func test_a_sting_keeps_its_load_aboard_until_he_is_out() -> void:
	var s := Session.new({"seed": 6, "map_seed": MapCity.SEED, "location": "QRY", "features": Session.SANDBOX_FEATURES, "family": true, "agency": true})
	s.police.frozen = true
	s.family.ai = false
	s.update(1.0 / 30)
	var j = null
	for i in 400:
		var k = s.agency.job_from(World.airfield("QRY"), s.world.airfields)
		if k != null and s.agency.stings.has(k.id):
			j = k
			break
	s.active_jobs.append(j)
	check(not s.agency.protecting(), "no call from Washington for that one")
	s._complete_delivery(j, World.airfield(j.dest))
	check(s.breakaway.active(), "stopped")
	check(j in s.active_jobs, "the load is still aboard")
	if j.hot():
		check(s.breakaway.bribe() > Breakaway.BRIBE_BASE, "and the bribe counts it")
	s.money = 1000000
	check(s.breakaway.pay()[0], "paid")
	check(not (j in s.active_jobs), "the sting's load is gone however he gets out")
	s.dispose()
