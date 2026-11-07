extends TestCase
## The last run (D-95): one life, two game hours, money counts once banked at home; a bust or a crash ends it.


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LastRun.BEST_PATH))


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LastRun.BEST_PATH))


func _run() -> Session:
	var o := GameSetup.last_run(17)
	o["location"] = "HAR"
	o["map_seed"] = MapCity.SEED
	var s := Session.new(o)
	s.police.frozen = true
	s.update(1.0 / 30)
	return s


func test_the_setup_is_open_and_short_of_money() -> void:
	var o := GameSetup.last_run(17)
	check(o.last_run and int(o.money) == LastRun.START, "the last run's start")
	check(o.has("logistics") and o.has("ground_war"), "everything open")
	var s := _run()
	check(s.last_run != null, "built")
	check_eq(s.last_run.home, "HAR", "home is where it starts")
	check_eq(s.last_run.banked, LastRun.START, "the start is banked")
	check("THE LAST RUN" in s.last_run.hud_line(), s.last_run.hud_line())
	s.dispose()


func test_a_normal_game_has_none() -> void:
	var s := Session.new({"seed": 3, "location": "HAR"})
	check(s.last_run == null, "only when asked")
	check(s.command(Roles.PILOT, "last_run_out", {})[1].contains("not a last run"), "and the command says so")
	s.dispose()


func test_landing_at_home_banks_and_a_bust_ends_it_on_the_bank() -> void:
	var s := _run()
	s.money = 12000
	s.bus.emit("landed", s.time, "", ["runner"], {"code": "HAR"})
	check_eq(s.last_run.banked, 12000, "banked at home")
	s.money = 30000
	s.bus.emit("landed", s.time, "", ["runner"], {"code": "FRM"})
	check_eq(s.last_run.banked, 12000, "elsewhere it is only in hand")
	s.bus.emit("busted", s.time, "", ["runner"], {"how": "test"})
	check(s.last_run.over and s.last_run.reason == "busted", "one life")
	check_eq(s.last_run.score, 12000, "the bank, not what was in hand")
	check(s.bus.log.any(func(e): return e.kind == "run_over"), "on the bus")
	s.bus.emit("landed", s.time, "", ["runner"], {"code": "HAR"})
	check_eq(s.last_run.score, 12000, "over is over")
	s.dispose()


func test_a_crash_ends_it_too() -> void:
	var s := _run()
	s.bus.emit("crashed", s.time, "", ["runner"], {"reason": "test"})
	check(s.last_run.over and s.last_run.reason == "crashed", "crashed")
	s.dispose()


func test_cashing_out_at_home_counts_everything() -> void:
	var s := _run()
	s.money = 25000
	s.phase = "parked"
	s.location = "FRM"
	check(s.last_run.cash_out().contains("Cash out at"), "only at home")
	s.location = "HAR"
	check_eq(s.command(Roles.PILOT, "last_run_out", {})[0], true, "cashed out")
	check_eq(s.last_run.score, 25000, "everything")
	s.dispose()


func test_the_clock_runs_out() -> void:
	var s := _run()
	s.money = 9000
	s.phase = "flying"
	s.time += LastRun.RUN_S + 1.0
	s.last_run.update()
	check(s.last_run.over and s.last_run.reason == "time", "out of time")
	check_eq(s.last_run.score, LastRun.START, "away from home: the bank")
	s.dispose()


func test_the_best_runs_are_kept() -> void:
	for money in [7000, 15000, 3000]:
		var s := _run()
		s.money = money
		s.phase = "parked"
		s.location = "HAR"
		s.last_run.cash_out()
		s.dispose()
	var best := LastRun.best()
	check_eq(best.size(), 3, "three runs")
	check_eq(int(best[0].score), 15000, "best first")
	check_eq(str(best[0].reason), "out", "with how it ended")


func test_off_means_none() -> void:
	LastRun.ENABLED = false
	var s := _run()
	check(s.last_run == null, "not built")
	s.dispose()
	LastRun.ENABLED = true
