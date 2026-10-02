extends TestCase
## On foot: getting out, walking on the island's collision, using the job
## board and the boss's desk, climbing back in. These wait on real physics
## frames (the runner awaits each test).


func _tree() -> SceneTree:
	return Engine.get_main_loop()


func _frames(n: int) -> void:
	for i in n:
		await _tree().physics_frame


func _app(opts: Dictionary) -> PilotApp:
	var s := Session.new(opts)
	s.update(1.0 / 30)
	var app := PilotApp.new()
	_tree().root.add_child(app)
	app.setup(s, "low")
	return app


func _areas(node: Node, action: String, out: Array) -> Array:
	if node is Area3D and node.get_meta("action", "") == action:
		out.append(node)
	for c in node.get_children():
		_areas(c, action, out)
	return out


func _key(k: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = down
	Input.parse_input_event(ev)


func _stand_before(w: Walker, area: Area3D) -> void:
	var p := area.global_position
	var back: Vector3 = area.get_parent().global_transform.basis.z.normalized()  # buildings face local -z
	var spot: Vector3 = p - back * 1.2
	w.place(spot.x, -spot.z, 0.0)
	w.look_at(Vector3(p.x, w.global_position.y, p.z), Vector3.UP)


func test_get_out_walk_and_get_back_in() -> void:
	var app := _app({"seed": 1, "location": "HAR"})
	var s := app.s
	app._toggle_on_foot()
	check(app.on_foot and app.walker != null, "on foot")
	var w := app.walker
	check(w.global_position.distance_to(app.player.global_position) < 12.0, "beside the aircraft")
	await _frames(10)
	var g := s.world.ground(w.global_position.x, -w.global_position.z)
	check(absf(w.global_position.y - g) < 0.6, "standing on the ground (%.2f vs %.2f)" % [w.global_position.y, g])
	var start := w.global_position
	_key(KEY_W, true)
	await _frames(60)
	_key(KEY_W, false)
	var walked := Vector2(w.global_position.x - start.x, w.global_position.z - start.z).length()
	check(walked > 1.0, "walked %.1f m in a second" % walked)
	g = s.world.ground(w.global_position.x, -w.global_position.z)
	check(absf(w.global_position.y - g) < 0.8, "still on the ground after walking")
	check(s.parked, "the aircraft stayed put")
	# too far to climb in
	w.place(w.global_position.x + 60, -w.global_position.z, 0)
	app._toggle_on_foot()
	check(app.on_foot, "can't board from 60 m")
	w.place(app.player.global_position.x + 3, -app.player.global_position.z, 0)
	app._toggle_on_foot()
	check(not app.on_foot, "back in the aircraft")
	app.free()
	s.dispose()


func test_job_board_at_the_hub() -> void:
	var app := _app({"seed": 1, "location": "HAR"})
	app._toggle_on_foot()
	var boards := _areas(app.scene, "jobs", []).filter(func(a): return a.get_meta("field", "") == "HAR")
	check(not boards.is_empty(), "HAR has a job board")
	if boards.is_empty():
		app.free()
		return
	_stand_before(app.walker, boards[0])
	await _frames(6)
	check(app.walker.focus != null, "facing something usable")
	if app.walker.focus != null:
		check_eq(app.walker.focus.get_meta("action"), "jobs")
		app.walker.use()
		check(app.menus["j"].visible, "E opened the job board")
	app.free()


func test_the_boss_desk_gives_orders() -> void:
	var app := _app({"seed": 9, "location": "COV", "features": Session.SANDBOX_FEATURES + ["hq"]})
	var s := app.s
	s.nights.runner_ai = null
	app._toggle_on_foot()
	var desks := _areas(app.scene, "hq_org", [])
	check_eq(desks.size(), 1, "one boss's desk")
	if desks.is_empty():
		app.free()
		return
	_stand_before(app.walker, desks[0])
	await _frames(6)
	check(app.walker.focus != null and app.walker.focus.get_meta("action") == "hq_org", "at the desk")
	app.walker.use()
	var m: HQMenu = app.menus["hq"]
	check(m.visible, "the orders are open")
	var i := m.rows.map(func(r): return r.key).find("route")
	m.list.select(i)
	var before: String = s.nights.season.org.route
	m.key("right")
	m.key("enter")
	check(s.nights.season.org.route != before, "route changed from the desk: %s -> %s" % [before, s.nights.season.org.route])
	app.free()


## Q at the villa desk swaps the orders board for the same squad command a
## human boss's seat gives in co-op (StationApp.squad_mode) - and claims the
## seat for as long as that lasts, same as it already does for a human
## lieutenant, so the AI stands aside.
func test_the_boss_desk_commands_squads() -> void:
	var app := _app({"seed": 9, "location": "COV", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	var s := app.s
	s.money = 20000
	app._toggle_on_foot()
	var desks := _areas(app.scene, "hq_org", [])
	check_eq(desks.size(), 1, "one boss's desk")
	if desks.is_empty():
		app.free()
		return
	_stand_before(app.walker, desks[0])
	await _frames(6)
	app.walker.use()
	var m: HQMenu = app.menus["hq"]
	check(m.visible, "the desk is open")
	check(m.squad_mode, "no season to run, so it opens straight on the squads")
	check_eq(s.seats.who(Roles.BOSS), "human", "claimed for as long as this lasts")
	check(not s.ground.commanders.org.ai, "the AI stands aside while the boss runs the squads")
	m.key("raise_car")
	var q: GroundWar.Squad = s.ground.of("org").back()
	check(q != null and q.kind == "car", "raised a car crew")
	m._on_map_click(MOUSE_BUTTON_LEFT, q.pos() + Vector2(100, 0))
	check_eq(m.sel_squad, q.id, "clicked: selected")
	m._on_map_click(MOUSE_BUTTON_RIGHT, Vector2(q.x + 3000, q.y + 3000))
	check(q.human, "right-click gave it a human's order")
	check(str(q.order.get("type", "")) != "", "some order went through: %s" % q.order.get("type"))
	m.key("melt")
	check_eq(q.tactic, "melt", "the melt button")
	m.key("q")
	check(not m.squad_mode, "Q again: back to the desk")
	check_eq(s.seats.who(Roles.BOSS), "ai", "and handed back")
	check(s.ground.commanders.org.ai, "the AI runs them again")
	m.key("q")
	check_eq(s.seats.who(Roles.BOSS), "human", "back on the squads")
	m.close()
	check_eq(s.seats.who(Roles.BOSS), "ai", "walking away from the desk hands them back too")
	check(s.ground.commanders.org.ai, "to the AI")
	app.free()

## T on foot is the phone: the people who otherwise need a walk to the desk or a landing at the
## right strip, and the desk's orders and dispatch, from wherever you are standing.
func test_the_phone_reaches_the_desk_and_the_crew_from_anywhere() -> void:
	var app := _app({"seed": 9, "location": "COV", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	var s := app.s
	app._toggle_on_foot()
	await _frames(4)
	var m: PhoneMenu = app.menus["phone"]
	check(not m.visible, "phone is in the pocket")
	_key(KEY_T, true)
	await _frames(3)
	_key(KEY_T, false)
	check(m.visible, "T takes the phone out")
	var acts: Array = m.rows.map(func(r): return r[0])
	check("desk" in acts, "the desk is in the phone book: %s" % [acts])
	if s.payroll != null:
		check("crew" in acts, "Manny's hiring hall too")
	m.list.select(acts.find("desk"))
	m.key("enter")
	check(not m.visible, "hung up")
	check(app.menus["hq"].visible, "the desk's orders opened without the walk")
	app.menus["hq"].close()
	# a system that is off is not in the book
	s.payroll = null
	m.open()
	check(not (m.rows.map(func(r): return r[0])).has("crew"), "nobody to call about crew with no payroll")
	m.close()
	app.free()
	s.dispose()

## The phone's taxi: pick somewhere, pay the fare, and the world runs ahead while you ride; you are
## put down at the other end.
func test_a_taxi_takes_you_to_the_desk() -> void:
	var app := _app({"seed": 9, "location": "COV", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	var s := app.s
	s.money = 5000
	app._toggle_on_foot()
	await _frames(4)
	var stops: Array = app.taxi_stops()
	var names: Array = stops.map(func(r): return r.name)
	check(names.size() >= 2, "somewhere to go: %s" % [names])
	var i := names.find("The boss's desk")
	check(i >= 0, "the desk is on the list")
	if i < 0:
		app.free()
		return
	var stop: Dictionary = stops[i]
	var t0 := s.time
	var m0 := s.money
	app._phone_call("taxi")
	check(app.menus["taxi"].visible, "the phone opened the taxi list")
	app.menus["taxi"].close()
	app._taxi_go(i)
	check(app.taxi_left > 0.0, "the ride is on (%d s)" % int(app.taxi_left))
	check_eq(s.money, m0 - int(stop.fare), "the fare is paid up front")
	await _frames(200)
	check_eq(app.taxi_left, 0.0, "the ride is over")
	check(s.time - t0 >= float(stop.secs) - 2.0, "the world ran ahead by the ride: %.0f s of %.0f s" % [s.time - t0, float(stop.secs)])
	var at: Vector2 = stop.at
	var here := Vector2(app.walker.global_position.x, -app.walker.global_position.z)
	check(here.distance_to(at) < 3.0, "put down at the desk (%.1f m)" % here.distance_to(at))
	# broke: no ride
	s.money = 0
	app._taxi_go(i)
	check_eq(app.taxi_left, 0.0, "no fare, no ride")
	app.free()
	s.dispose()

## The starter car: parked beside the aircraft, E at it to get in, WASD to drive, E to get out once it has all but stopped.
func test_the_starter_car_can_be_driven() -> void:
	var app := _app({"seed": 9, "location": "COV", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	var sess := app.s
	app._toggle_on_foot()
	await _frames(30)
	var car: Car = app.car
	check(car != null, "a starter car is parked")
	if car == null:
		app.free()
		return
	check(car.global_position.distance_to(app.player.global_position) < 40.0, "beside the aircraft (%.0f m)" % car.global_position.distance_to(app.player.global_position))
	var w: Walker = app.walker
	w.place(car.global_position.x + 60.0, -car.global_position.z, 0.0)
	app._enter_car()
	check(app.driving == null, "not from 60 m away")
	w.place(car.global_position.x + 3.0, -car.global_position.z, 0.0)
	app._enter_car()
	check(app.driving == car and car.driven, "in the driver's seat")
	var start := car.global_position
	_key(KEY_W, true)
	await _frames(120)
	check(car.speed > 5.0, "under way (%.1f m/s)" % car.speed)
	check(car.global_position.distance_to(start) > 15.0, "and gone somewhere (%.0f m)" % car.global_position.distance_to(start))
	check(car.speed <= car.top_speed() + 0.5, "never faster than the ground allows (%.1f of %.1f)" % [car.speed, car.top_speed()])
	app._exit_car()
	check(app.driving == car, "it will not let you out at speed")
	var h0 := car.heading_deg()
	_key(KEY_D, true)
	await _frames(60)
	_key(KEY_D, false)
	check(absf(angle_difference(deg_to_rad(h0), deg_to_rad(car.heading_deg()))) > deg_to_rad(15.0), "D turns it (%.0f -> %.0f degrees)" % [h0, car.heading_deg()])
	_key(KEY_W, false)
	_key(KEY_S, true)
	var n := 0
	while car.speed > 1.0 and n < 400:
		await _frames(1)
		n += 1
	_key(KEY_S, false)
	check(car.speed < 1.5, "S brings it to a stop (%d frames)" % n)
	car.speed = 0.0
	app._exit_car()
	check(app.driving == null and not car.driven, "out of the car")
	check(w.visible, "and walking again")
	check(Vector2(w.global_position.x - car.global_position.x, w.global_position.z - car.global_position.z).length() < 5.0, "beside it")
	app.free()
	sess.dispose()

## Driving through a police checkpoint at speed is noticed; slowing down is a wave-through.
func test_running_a_police_checkpoint_costs_suspicion() -> void:
	var app := _app({"seed": 9, "location": "COV", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	var sess := app.s
	app._toggle_on_foot()
	await _frames(20)
	var car: Car = app.car
	app.walker.place(car.global_position.x + 3.0, -car.global_position.z, 0.0)
	app._enter_car()
	check(app.driving == car, "driving")
	var at := car.game_xy()
	var cp: GroundWar.Squad = sess.ground.recruit("police", "car", at + Vector2(20, 0), false)
	cp.tactic = "checkpoint"
	cp.state = "holding"
	var c = sess.police.case("runner")
	var before: float = c.suspicion
	car.speed = 3.0
	app._car_checkpoints()
	check_eq(c.suspicion, before, "creeping through is a wave-through")
	car.speed = 12.0
	app._car_checkpoints()
	check_eq(c.suspicion, before + app.CHECKPOINT_HEAT, "running it at speed costs suspicion")
	app._car_checkpoints()
	check_eq(c.suspicion, before + app.CHECKPOINT_HEAT, "once, not every frame")
	sess.time += app.CHECKPOINT_AGAIN_S + 1.0
	app._car_checkpoints()
	check_eq(c.suspicion, before + 2.0 * app.CHECKPOINT_HEAT, "and again after a while")
	app.free()
	sess.dispose()


## On foot with a ground war, Z / X / C / V order the nearest squad of ours: hold, come to me, charge, fall back.
func test_the_field_order_keys_command_the_nearest_squad() -> void:
	var app := _app({"seed": 9, "location": "COV", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	var sess := app.s
	app._toggle_on_foot()
	await _frames(10)
	var p := app.walker.global_position
	var me := Vector2(p.x, -p.z)
	var q: GroundWar.Squad = sess.ground.recruit("org", "foot", me + Vector2(40, 0), false)
	q.state = "holding"
	_key(KEY_X, true)
	await _frames(3)
	_key(KEY_X, false)
	check_eq(q.order.get("type", ""), "move", "X: it comes to me")
	_key(KEY_Z, true)
	await _frames(3)
	_key(KEY_Z, false)
	check_eq(q.order.get("type", ""), "hold", "Z: it holds")
	_key(KEY_V, true)
	await _frames(3)
	_key(KEY_V, false)
	check_eq(q.order.get("type", ""), "melt", "V: it falls back")
	_key(KEY_C, true)
	await _frames(3)
	_key(KEY_C, false)
	check(sess.messages.any(func(m): return str(m[1]).contains("Nothing in sight")), "C with nobody to charge says so")
	app.free()
	sess.dispose()


func test_walks_up_a_step() -> void:
	var app := _app({"seed": 1, "location": "HAR"})
	app._toggle_on_foot()
	var w := app.walker
	# a 30 cm kerb in front of us
	var kerb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(8, 0.3, 8)
	cs.shape = bs
	kerb.add_child(cs)
	app.add_child(kerb)
	await _frames(40)  # land first
	var fwd := -w.global_transform.basis.z
	kerb.global_position = w.global_position + fwd * 6.5 + Vector3(0, 0.15, 0)
	await _frames(2)
	_key(KEY_W, true)
	_key(KEY_SHIFT, true)
	await _frames(90)
	_key(KEY_W, false)
	_key(KEY_SHIFT, false)
	var top := kerb.global_position.y + 0.15
	check(w.global_position.y > top - 0.1, "climbed the kerb (%.2f vs top %.2f)" % [w.global_position.y, top])
	app.free()
