extends TestCase
## Engine and airframe wear (Airframe) and the mechanic's seat: what wears, what it does, what repairs cost and who does them.

var _sess: Session


class FixedRng extends PyRandom:
	var v := 0.5

	func _init(v_ := 0.5) -> void:
		v = v_

	func random() -> float:
		return v


func after_each() -> void:
	Airframe.ENABLED = true
	if _sess != null:
		_sess.dispose()
		_sess = null
	World.use_map(0)


func _code(kind: String) -> String:
	for a in World.AIRFIELDS:
		if a.kind == kind:
			return a.code
	return "HAR"


func _session(opts := {}) -> Session:
	var o := {"seed": 23, "mode": Roles.COOP, "map_seed": MapCity.SEED, "location": _code("hub"), "features": Session.SANDBOX_FEATURES, "airframe": true, "money": 50000}
	o.merge(opts, true)
	_sess = Session.new(o)
	_sess.police.frozen = true
	_sess.update(1.0 / 30)
	return _sess


func _fly(s: Session, minutes: float) -> void:
	s.spawn_airborne(0.0, 0.0, 90.0, 600.0, 90.0)
	for i in int(minutes * 60.0 / 2.0):
		s.airframe.update(2.0, s.state)
		s.time += 2.0


func test_there_is_no_wear_unless_the_game_asks_for_it() -> void:
	var s := _session({"airframe": false})
	check(s.airframe == null, "no airframe object")
	check(not s.command(Roles.PILOT, "service", {})[0], "and nothing to service")


func test_the_engine_wears_in_the_air_and_runs_rough_then_fails() -> void:
	var s := _session()
	var a: Airframe = s.airframe
	check_eq(a.engine(), 100.0, "new")
	_fly(s, 60.0)
	check(a.engine() < 94.0 and a.engine() > 90.0, "an hour of flying costs about 7 points: %.1f" % a.engine())
	check_eq(a.power_scale(), 1.0, "full power while it is healthy")
	a.of().engine = 30.0
	check(a.rough() and a.power_scale() < 1.0 and a.power_scale() > Airframe.POWER_FLOOR, "rough: a little less power (%.2f)" % a.power_scale())
	a.of().engine = 0.0
	check_eq(a.power_scale(), Airframe.POWER_FLOOR, "at zero, the floor")
	a.rng = FixedRng.new(0.0)
	s.phase = "flying"
	a.update(60.0, s.state)
	check(a.engine_out() and a.failures == 1, "a dead-tired engine quits")
	check_eq(a.power_scale(), 0.0, "and gives no power")
	var c := FlightModel.Controls.make({"throttle": 1.0, "aileron": 0.2})
	check_eq(a.limit(c).throttle, 0.0, "the throttle is forced to idle")
	check_eq(a.limit(c).aileron, 0.2, "the rest of the controls are left alone")
	s.time += Airframe.FAIL_S + 1.0
	check(not a.engine_out(), "it catches again after %d s" % int(Airframe.FAIL_S))


func test_hard_and_rough_landings_wear_the_airframe_and_weaken_the_gear() -> void:
	var s := _session()
	var a: Airframe = s.airframe
	a.touchdown(100.0, 600.0, null)
	check_eq(a.airframe(), 100.0, "a soft landing on nothing in particular costs nothing")
	a.touchdown(100.0, 600.0, World.airfield(_code("bush")))
	var after_bush := a.airframe()
	check(after_bush < 100.0 and after_bush > 99.0, "a bush strip costs a little: %.2f" % after_bush)
	a.touchdown(600.0, 600.0, null)
	check(a.airframe() < after_bush - 13.0, "a landing at the limit costs about %d points: %.1f" % [int(Airframe.HARD_POINTS), a.airframe()])
	check_eq(a.gear_factor(), 1.0, "the gear is fine above 50")
	a.of().airframe = 25.0
	check(a.gear_factor() < 0.85 and a.gear_factor() > Airframe.GEAR_FLOOR, "weaker below it (%.2f)" % a.gear_factor())
	a.of().airframe = 0.0
	check_eq(a.gear_factor(), Airframe.GEAR_FLOOR, "to the floor")


func test_repairs_cost_points_over_time_and_the_aircraft_cannot_fly_meanwhile() -> void:
	var s := _session()
	var a: Airframe = s.airframe
	a.of().engine = 50.0
	a.of().airframe = 80.0
	check_eq(a.place(), "hangar", "a hub is a hangar")
	var m: int = s.money
	check_eq(a.repair(["engine", "airframe"]), "", "work begins")
	check(a.repair(["engine"]).contains("already"), "not twice")
	check_eq(a.limit(FlightModel.Controls.make({"throttle": 1.0})).throttle, 0.0, "the cowling is off: no throttle")
	for i in 60:
		a.update(1.0, s.state)  # a minute
	check(absf(a.engine() - 62.0) < 0.2, "a hangar does %d points a minute: engine %.1f" % [int(Airframe.HANGAR_RATE), a.engine()])
	check(a.airframe() > 91.0, "the airframe too (%.1f)" % a.airframe())
	var paid: int = m - s.money
	check(paid > 0 and paid > 12 * 30 - 20 and paid < 12 * 30 + 12 * 20 + 20, "paid for the points: $%d" % paid)
	for i in 300:
		a.update(1.0, s.state)
	check(a.work.is_empty(), "the work finishes by itself")
	check_eq(a.engine(), 100.0, "as new")
	check_eq(a.airframe(), 100.0, "both")
	check_eq(a.limit(FlightModel.Controls.make({"throttle": 1.0})).throttle, 1.0, "and the throttle is free again")


func test_a_bush_strip_is_slow_and_dear_and_a_mechanic_is_quick_and_cheap() -> void:
	var s := _session({"location": _code("bush")})
	var a: Airframe = s.airframe
	check_eq(a.place(), "field", "a bush strip has no hangar")
	var field: Array = a.terms()
	check_eq(field, [Airframe.FIELD_RATE, Airframe.FIELD_COST], "slow and dear")
	a.held = true
	var mech: Array = a.terms()
	check_eq(mech, [Airframe.MECHANIC_RATE, Airframe.MECHANIC_COST], "a mechanic works anywhere, fast and cheap")
	check(a.price("engine") < float(Airframe.COST.engine), "below the hangar price")
	a.held = false
	var s2 := _session({"location": _code("hub")})
	check_eq(s2.airframe.terms(), [Airframe.HANGAR_RATE, 1.0], "a hangar in between")


func test_work_stops_when_the_money_runs_out_or_the_aircraft_moves() -> void:
	var s := _session({"money": 100})
	var a: Airframe = s.airframe
	a.of().engine = 10.0
	check_eq(a.repair(["engine"]), "", "work begins")
	for i in 60:
		a.update(1.0, s.state)
	check(a.work.is_empty(), "stopped when the $100 ran out")
	check(a.engine() > 10.0 and a.engine() < 20.0, "some of it done: %.1f" % a.engine())
	var t := _session({"money": 5000})
	t.airframe.of().engine = 10.0
	t.airframe.repair(["engine"])
	t.location = "FRM"
	t.airframe.update(1.0, t.state)
	check(t.airframe.work.is_empty(), "the aircraft moved: the work is off")
	check(t.airframe.repair(["engine"], 5.0).contains("Nothing"), "and there is nothing to do below the target")


func test_the_ai_ground_crew_services_a_worn_aircraft() -> void:
	var s := _session()
	var a: Airframe = s.airframe
	a.of().engine = 65.0
	a.auto_service()
	check(not a.work.is_empty(), "a worn aircraft at a hangar is serviced")
	a.stop()
	a.of().engine = 85.0
	a.of().airframe = 90.0
	a.auto_service()
	check(a.work.is_empty(), "a sound one is left alone")
	var b := _session({"location": _code("bush")})
	b.airframe.of().engine = 60.0
	b.airframe.auto_service()
	check(b.airframe.work.is_empty(), "at a bush strip only an emergency gets a patch")
	b.airframe.of().engine = 30.0
	b.airframe.auto_service()
	check(not b.airframe.work.is_empty(), "and then it does")


func test_the_pilot_sees_bands_and_the_mechanic_sees_numbers() -> void:
	var s := _session({"humans": {Roles.MECHANIC: "Moe"}})
	check(s.airframe.held, "the mechanic's seat is held")
	s.airframe.of().engine = 52.0
	var pilot := Snapshot.build(s, Roles.PILOT)
	check_eq(pilot.airframe.engine, "worn", "the pilot hears 'worn'")
	check(not pilot.airframe.has("engine_pts"), "and no numbers")
	var mech := Snapshot.build(s, Roles.MECHANIC)
	check_eq(mech.airframe.engine_pts, 52.0, "the mechanic reads 52.0")
	check(mech.airframe.has("fail_pct_min") and mech.airframe.has("gear_factor"), "and the risks")
	check(Roles.allowed(Roles.MECHANIC, "service") and Roles.allowed(Roles.MECHANIC, "inspect"), "the mechanic's commands")
	check(not Roles.allowed(Roles.MECHANIC, "autopilot"), "but not the pilot's")
	check(Roles.allowed(Roles.PILOT, "service"), "the pilot may have it serviced")
	check(s.command(Roles.MECHANIC, "inspect", {})[0], "an inspection")
	check(s.messages.any(func(m): return str(m[1]).contains("INSPECTION") and str(m[1]).contains("52%")), "reports the true number")


func test_a_mechanic_haggles_for_the_farmers_fuel() -> void:
	var s := _session({"location": _code("bush")})
	var plain: float = s.fuel_source()[0]
	s.seat_driver(Roles.MECHANIC, true)
	var haggled: float = s.fuel_source()[0]
	check(haggled < plain and absf(haggled / plain - 0.6) < 0.01, "40%% off the drum price: %.2f -> %.2f" % [plain, haggled])
	s.seat_driver(Roles.MECHANIC, false)
	check_eq(s.fuel_source()[0], plain, "back to the farmer's price when he leaves")


func test_the_hud_the_hangar_and_the_desk_show_it() -> void:
	var s := _session({"humans": {Roles.MECHANIC: "Moe"}})
	var a: Airframe = s.airframe
	var hud := Hud.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	hud.setup(s)
	hud.refresh()
	check(not hud.chips["cond"].visible, "a healthy aircraft shows nothing")
	a.of().engine = 40.0
	hud.refresh()
	check(hud.chips["cond"].visible and hud.chips["cond"].text().contains("ROUGH"), "rough running: %s" % hud.chips["cond"].text())
	hud.free()
	var menu := HangarMenu.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	menu.setup(s)
	menu.open()
	check(menu.rows.any(func(r): return r[0] == "service"), "the hangar has a service row")
	var idx := -1
	for i in menu.rows.size():
		if menu.rows[i][0] == "service":
			idx = i
	menu.list.select(idx)
	menu.key("enter")
	check(a.work.is_empty(), "review does not start or charge work")
	menu.key("right")
	for frame in 3:
		await Engine.get_main_loop().process_frame
	menu.key("enter")
	check(not a.work.is_empty(), "confirmed review starts the work")
	menu.key("enter")
	check(a.work.is_empty(), "and again stops it")
	menu.queue_free()
	var link := LocalLink.new(s, Roles.MECHANIC)
	var app := StationApp.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	app.setup(link, Roles.MECHANIC, s.world)
	app._process(0.016)
	check_eq(app.title.text, "MECHANIC", "the desk")
	check_eq(app.list.row_count(), 2, "an engine row and an airframe row")
	app.list.select(0)
	app._key("enter")
	check(not a.work.is_empty() and a.work.parts == ["engine"], "ENTER repairs the engine")
	app._key("s")
	check(a.work.is_empty(), "S stops the work")
	app._key("i")
	check(s.messages.any(func(m): return str(m[1]).contains("INSPECTION")), "I inspects")
	app.queue_free()


func test_the_saved_condition_comes_back() -> void:
	var path := "user://test_airframe_save.json"
	var s := _session({"save_path": path, "humans": {}})
	s.airframe.of().engine = 41.0
	s.airframe.of("c182").airframe = 33.0
	s.airframe.failures = 2
	s.save()
	s.dispose()
	_sess = null
	var t := Session.load_or_new(path, {"seed": 23, "mode": Roles.COOP, "map_seed": MapCity.SEED, "location": _code("hub"), "features": Session.SANDBOX_FEATURES, "airframe": true})
	_sess = t
	check_eq(t.airframe.engine(), 41.0, "the engine")
	check_eq(t.airframe.of("c182").airframe, 33.0, "another aircraft's airframe")
	check_eq(t.airframe.failures, 2, "and the failures")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
