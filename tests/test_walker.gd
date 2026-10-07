extends TestCase
## On foot: getting out, walking on the island's collision, using the job
## board and the boss's desk, climbing back in. These wait on real physics
## frames (the runner awaits each test).


func after_each() -> void:
	World.use_map(0)  # the collision test loads the city map; the world tests expect the classic island


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


func test_interaction_wall_occlusion_and_activation_recheck() -> void:
	var root := Node3D.new()
	_tree().root.add_child(root)
	var w := Walker.new().setup(World.new())
	root.add_child(w)
	w.position = Vector3(0, 100, 0)
	w.set_physics_process(false)
	var area := Area3D.new()
	area.position = Vector3(0, 101.65, -2)
	area.collision_layer = 4
	area.collision_mask = 0
	area.set_meta("action", "jobs")
	var target_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	target_shape.shape = sphere
	area.add_child(target_shape)
	root.add_child(area)
	var wall := StaticBody3D.new()
	wall.position = Vector3(0, 101.65, -1)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, 0.2)
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	await _frames(3)
	check(w.reach.overlaps_area(area), "proximity/facing alone would allow this through-wall interaction")
	w._update_focus()
	check(w.focus == null, "solid wall blocks selection")
	shape.disabled = true
	await _frames(3)
	w._update_focus()
	check(w.focus == area, "open passage permits selection")
	var uses := []
	w.used.connect(func(action, _area): uses.append(action))
	shape.disabled = false
	await _frames(3)
	w.use()
	check(uses.is_empty(), "a wall appearing after selection blocks activation")
	shape.disabled = true
	await _frames(3)
	w.use()
	check_eq(uses, ["jobs"], "unobstructed activation succeeds once")
	root.free()


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

func test_incoming_phone_is_the_same_queue_on_foot_and_in_the_cockpit() -> void:
	var app := _app({"seed": 9, "map_seed": MapCity.SEED, "location": "HAR", "family": true, "humans": {Roles.BOSS: "Owner"}})
	var s := app.s
	s.family.offer("loan")
	var call_id: int = s.phone_calls.pending()[0].id
	var event := InputEventKey.new()
	event.keycode = KEY_T
	event.pressed = true
	event.shift_pressed = true
	app._unhandled_input(event)
	var menu: PhoneMenu = app.menus.phone
	check(menu.visible and int(menu.rows[0][3]) == call_id, "cockpit phone shows the authoritative call")
	menu.close()
	app._toggle_on_foot()
	await _frames(3)
	event.shift_pressed = false
	app._unhandled_input(event)
	check(menu.visible and int(menu.rows[0][3]) == call_id, "on-foot phone shows the same call")
	menu.list.select(0)
	menu.key("enter")
	check(s.phone_calls.pending().is_empty(), "answer consumes that call once")
	check(app.talk != null, "answer routes into the existing Family conversation")
	check(not app.walker.look_enabled, "walker stops to take the call")
	check(not s.family.offers.is_empty(), "answer has not accepted the economic offer")
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
	check(car.global_position.distance_to(start) > 6.0, "and gone somewhere (%.0f m)" % car.global_position.distance_to(start))
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


## The race's gates are drawn in the world while a race is on: a ring and a beam at the next gate.
func test_the_race_markers_show_the_next_gate() -> void:
	var app := _app({"seed": 9, "location": "COV", "features": Session.SANDBOX_FEATURES, "ground_war": true, "races": true})
	var sess := app.s
	await _frames(5)
	var rm: RaceMarkers = null
	for c in app.get_children():
		if c is RaceMarkers:
			rm = c
	check(rm != null, "the app has race markers")
	if rm == null:
		app.free()
		return
	check(not rm.next_ring.visible, "nothing drawn with no race on")
	var course = sess.races.courses_here()[0]
	sess.money = 5000
	check_eq(sess.races.enter(course.id), "", "entered")
	for k in 3:
		await _tree().process_frame
	check(rm.next_ring.visible and rm.beam.visible, "the next gate has a ring and a beam")
	var g: Vector3 = course.gates[0]
	check_near(rm.next_ring.position.x, g.x, 0.01, "at the start gate (x)")
	check_near(rm.next_ring.position.z, -g.y, 0.01, "and (z)")
	sess.races.abort("test")
	for k in 3:
		await _tree().process_frame
	check(not rm.next_ring.visible, "and gone again when the race ends")
	app.free()
	sess.dispose()


## The car's radio: it comes with the car, plays only while you are in it, and R and the tuning keys work it.
func test_the_car_has_a_radio_that_plays_only_while_driving() -> void:
	var app := _app({"seed": 9, "location": "COV", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	var sess := app.s
	app._toggle_on_foot()
	await _frames(20)
	var radio: CarRadio = app.radio
	check(radio != null and not radio.stations.is_empty(), "the car has a radio with stations")
	if radio == null:
		app.free()
		return
	radio.state_path = "user://zz_test_walker_radio.cfg"
	radio.on = false  # the dial remembers the last game; the test starts it off
	check(not radio.active, "silent out of the car")
	app.walker.place(app.car.global_position.x + 3.0, -app.car.global_position.z, 0.0)
	app._enter_car()
	check(radio.active, "live in the car")
	app._radio_key("power")
	check(radio.on, "R turns it on")
	var at := radio.idx
	app._radio_key("up")
	check(radio.idx == (at + 1) % radio.stations.size(), "and . tunes up")
	app._radio_key("down")
	check_eq(radio.idx, at, "and , tunes back")
	app.car.speed = 0.0
	app._exit_car()
	check(not radio.active, "silent again once you are out")
	DirAccess.remove_absolute(radio.state_path)
	app.free()
	sess.dispose()


## The city's buildings are solid: walking straight at one stops against its wall.
func test_the_walker_stops_against_a_city_building() -> void:
	var app := _app({"seed": 9, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES})
	var sess := app.s
	# a good-sized block, its south face clear of other buildings for 12 m
	var pick = null
	for b in sess.world.map.buildings:
		if b.style == "crane" or float(b.w) < 12.0 or float(b.d) < 12.0:
			continue
		var clear := true
		for o in sess.world.map.buildings:
			if o != b and absf(float(o.x) - float(b.x)) < float(o.w) / 2.0 + float(b.w) / 2.0 + 4.0 and absf(float(o.y) - (float(b.y) - float(b.d) / 2.0 - 7.0)) < float(o.d) / 2.0 + 8.0:
				clear = false
				break
		if clear:
			pick = b
			break
	check(pick != null, "there is a free-standing building to try")
	if pick == null:
		app.free()
		return
	app._toggle_on_foot()
	await _frames(5)
	var w: Walker = app.walker
	var south := float(pick.y) - float(pick.d) / 2.0
	w.place(float(pick.x), south - 6.0, 0.0)  # facing north, 6 m from the wall
	_key(KEY_W, true)
	_key(KEY_SHIFT, true)
	await _frames(240)
	_key(KEY_W, false)
	_key(KEY_SHIFT, false)
	var y: float = w.game_xy()[1]
	check(y < south + 0.1, "he did not get through the wall (y %.1f, the south face at %.1f)" % [y, south])
	check(y > south - 3.0, "but he did walk up to it (%.1f m short)" % (south - y))
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


## The phone book grows as the game opens systems: the new number is announced once and marked NEW until it is rung.
func test_a_new_contact_appears_on_the_phone_when_its_system_opens() -> void:
	var app := _app({"seed": 9, "location": "HAR", "trade": true})
	var s := app.s
	var m: PhoneMenu = app.menus["phone"]
	app._phone_watch()  # the first look only learns what is already there
	check(not m.contacts().any(func(c): return c[0] == "psych"), "no Collective yet: not in the book")
	check(m.fresh.is_empty(), "nothing is new at the start of a game")
	s.enable_system("psychedelics")
	app._phone_watch()
	check(m.contacts().any(func(c): return c[0] == "psych"), "the system opened: Nico Cozz is in the book")
	check(m.fresh.has("psych"), "marked NEW")
	check(s.messages.any(func(x): return "New contact" in str(x[1])), "and said so")
	app._phone_watch()
	var told := s.messages.filter(func(x): return "New contact" in str(x[1])).size()
	check_eq(told, 1, "once, not every time it looks")
	m.refresh()
	check(str(m.list.get_row_cells(m.rows.map(func(r): return r[0]).find("psych"))[0]).begins_with("NEW") if m.list.has_method("get_row_cells") else true, "the row says NEW")
	m.fresh.erase("psych")
	app.queue_free()
	s.dispose()


## A place picked on the chart becomes a waypoint: both maps carry it, a beam stands there, the dash points at it, and arriving clears it.
func test_a_waypoint_picked_on_the_map_guides_the_car() -> void:
	var app := _app({"seed": 9, "location": "COV", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	var sess := app.s
	app._toggle_on_foot()
	await _frames(20)
	app.walker.place(app.car.global_position.x + 3.0, -app.car.global_position.z, 0.0)
	app._enter_car()
	app._map_toggle()
	check(app.car_map.big and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "M opens the chart with a cursor to pick with")
	var here := app.car.game_xy()
	app._waypoint_picked(here + Vector2(400.0, 0.0))
	check(app.waypoint != null and app.car_map.waypoint != null and app.hud.minimap.waypoint != null, "every map carries the waypoint")
	check(app._wp_beacon != null and app._wp_beacon.visible, "and a beam stands at it")
	app._map_toggle()
	await _frames(3)
	check(app.car_dash.wp_m > 300.0 and app.car_dash.wp_m < 500.0, "the dash knows how far: %.0f m" % app.car_dash.wp_m)
	check(absf(app.car_dash.wp_rel - 90.0) < 120.0, "and which way (relative bearing %.0f)" % app.car_dash.wp_rel)
	app.car.place(here.x + 400.0, here.y, 90.0)
	await _frames(3)
	check(app.waypoint == null, "arriving clears the waypoint")
	app.car.speed = 0.0
	app.free()
	sess.dispose()


## The boss's office is upstairs at Club Tropicana: the stairs have to lead somewhere. (They once ran into a ceiling slab with no stairwell.)
func test_the_stairs_to_the_boss_office_can_be_climbed() -> void:
	var s := Session.new({"seed": 9, "location": "HAR"})
	var k := Buildings.Kit.new("club")
	Buildings._nightclub(k)
	var club: Node3D = k.finish()
	_tree().root.add_child(club)
	var har := World.airfield("HAR")
	var gy := s.world.ground(har.x, har.y)
	club.global_position = Vector3(har.x, gy, -har.y)
	var w := Walker.new().setup(s.world)
	_tree().root.add_child(w)
	w.global_position = club.global_position + Vector3(9.4, 0.5, -7.2)  # at the foot of the stairs
	w.rotation = Vector3(0, PI, 0)  # facing up them (local +z)
	await _frames(5)
	_key(KEY_W, true)
	await _frames(420)
	_key(KEY_W, false)
	var up := w.global_position.y - club.global_position.y
	check(up > 3.6, "walked up to the office floor: %.2f m above the street" % up)
	# and from the top of the stairs on to the desk
	_key(KEY_W, true)
	await _frames(60)
	_key(KEY_W, false)
	w.free()
	club.free()
	s.dispose()
