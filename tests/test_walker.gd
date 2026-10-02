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
