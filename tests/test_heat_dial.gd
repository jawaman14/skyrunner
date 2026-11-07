extends TestCase
## The heat dial (D-95): turn the danger up for more pay, or down for a breather. Steady is the game as it was.


func _sess() -> Session:
	var s := Session.new({"seed": 14, "location": "HAR"})
	s.police.frozen = true
	s.update(1.0 / 30)
	return s


func test_steady_is_the_game_as_it_was() -> void:
	var s := _sess()
	check_eq(s.heat_dial.level, HeatDial.STEADY, "the default")
	check_eq(s.police.dial_mult, 1.0, "no extra heat")
	check_eq(s.heat_dial.pay_mult(), 1.0, "no extra pay")
	s.dispose()


func test_hotter_pays_more_and_is_noticed_more() -> void:
	var s := _sess()
	s.phase = "parked"
	check_eq(s.command(Roles.PILOT, "heat_dial", {"level": 3})[0], true, "Burning")
	check_near(s.police.dial_mult, 1.6, 0.001, "every sighting counts for more")
	check_near(s.police.dial_customs, 1.6, 0.001, "customs looks more often")
	check(s.bus.log.any(func(e): return e.kind == "heat_dial"), "on the bus")
	check_near(s.heat_dial.pay_mult(), 1.45, 0.001, "the pay")
	s.dispose()


func test_the_pay_lands_on_boards_dealt_from_then_on() -> void:
	var s := _sess()
	s.phase = "parked"
	var a := Session.new({"seed": 14, "location": "HAR"})
	a.police.frozen = true
	a.update(1.0 / 30)
	a.phase = "parked"
	a.heat_dial.set_level(2)
	s.refresh_board("FRM")
	a.refresh_board("FRM")
	var p0: Array = s.boards["FRM"].map(func(j): return int(j.payout))
	var p1: Array = a.boards["FRM"].map(func(j): return int(j.payout))
	check_eq(p0.size(), p1.size(), "the same board")
	for i in p0.size():
		check_near(float(p1[i]), float(p0[i]) * 1.2, 1.0, "x1.2: %d against %d" % [p1[i], p0[i]])
	s.dispose()
	a.dispose()


func test_a_sighting_counts_by_the_dial() -> void:
	var s := _sess()
	var c = s.police.case("runner")
	var base: float = s.police._scale(c)
	s.phase = "parked"
	s.heat_dial.set_level(0)
	check_near(s.police._scale(c), base * 0.75, 0.001, "Quiet")
	s.dispose()


func test_only_on_the_ground() -> void:
	var s := _sess()
	s.phase = "flying"
	check(s.heat_dial.set_level(0).contains("park first"), "no turning it down in a chase")
	check_eq(s.heat_dial.level, HeatDial.STEADY, "unchanged")
	check(s.heat_dial.set_level(9).contains("Quiet to Burning"), "four settings")
	s.dispose()


func test_saved_with_the_game() -> void:
	var s := _sess()
	s.phase = "parked"
	s.heat_dial.set_level(2)
	var d: Dictionary = SaveVars.through_json(StrategicSave.capture(s))
	var t := _sess()
	StrategicSave.restore(t, d)
	check_eq(t.heat_dial.level, 2, "Hot")
	check_near(t.police.dial_mult, 1.3, 0.001, "and handed to the police")
	var u := _sess()
	StrategicSave.restore(u, SaveVars.through_json(StrategicSave.capture(u)))
	check_eq(u.heat_dial.level, HeatDial.STEADY, "a Steady game saves nothing and comes back Steady")
	s.dispose()
	t.dispose()
	u.dispose()


func test_off_means_steady() -> void:
	HeatDial.ENABLED = false
	var s := _sess()
	check(s.heat_dial == null, "not built")
	check_eq(s.police.dial_mult, 1.0, "the police as they were")
	s.dispose()
	HeatDial.ENABLED = true
