extends TestCase
## Front-end smoke tests (the Godot counterpart of tests/test_render.py): build
## every screen headless (Godot's dummy renderer still builds all the nodes,
## meshes and materials) and drive a few frames and keys through it. Real
## pixels are checked by `tools/screenshots.sh` under Xvfb.

func _tree() -> SceneTree:
	return Engine.get_main_loop()


func test_world_scene_builds_at_every_preset() -> void:
	var w := World.new()
	for q in ["low", "medium", "high"]:
		var ws := WorldScene.new().setup(w, Quality.get_preset(q))
		check(ws.get_node("terrain") != null, q + " terrain")
		var n := 0
		for mm in ws.get_node("trees").get_children():
			n += mm.multimesh.instance_count
		check(n > 1000, "%s trees %d" % [q, n])
		ws.set_hour(21.0)
		check(ws.night > 0.9, "night at 21:00")
		check(ws.field_lights[0].visible, "runway lights on at night")
		ws.set_hour(12.0)
		check(ws.night < 0.05 and not ws.field_lights[0].visible, "day")
		ws.free()


func test_pilot_app_flies_a_frame_and_opens_menus() -> void:
	var s := Session.new({"seed": 1, "location": "FRM"})
	var app := PilotApp.new()
	_tree().root.add_child(app)
	app.setup(s, "low")
	for i in 5:
		app._process(1.0 / 30)
	check(app.player != null and app.player.position.y > 0, "aircraft placed")
	for k in ["j", "l", "h"]:
		app._toggle_menu(k)
		check(app._active_menu() == app.menus[k], k + " menu open")
		for key in ["down", "up", "right", "left", "+", "-"]:
			app.menus[k].key(key)
		app._process(1.0 / 30)
		app.menus[k].close()
	# accept a job from the board through the menu, then place its cargo by hand
	app._toggle_menu("j")
	var jm: JobMenu = app.menus["j"]
	jm.list.select(1)
	jm.key("enter")
	check(not s.active_jobs.is_empty(), "job accepted from the menu")
	jm.close()
	app._toggle_menu("l")
	var lm: LoadMenu = app.menus["l"]
	var item: Loadout.Item = s.loadout.items.values()[0]
	var st: int = s.loadout.valid_stations(item)[-1]
	lm._picked(item.id, st)
	check_eq(s.loadout.assignment.get(item.id), st, "placed at the chosen station")
	lm._set_fuel(s.loadout.mass.fuel_capacity_lb() * 0.5)
	check_near(s.fm.fuel_lb(), s.loadout.mass.fuel_capacity_lb() * 0.5, 1.0, "fuel preset")
	lm.close()
	app.queue_free()
	app.free()
	s.dispose()


func test_station_screens_for_every_seat() -> void:
	var s := Session.new({"seed": 9, "location": "FRM", "mode": Roles.VERSUS, "features": Session.SANDBOX_FEATURES + ["hq"]})
	s.update(1.0 / 30)
	for role in [Roles.COPILOT, Roles.SPOTTER, Roles.BOAT, Roles.CONTROLLER, Roles.BOSS, Roles.CHIEF]:
		var st := StationApp.new()
		_tree().root.add_child(st)
		st.setup(LocalLink.new(s, role), role, s.world)
		for i in 3:
			st._process(1.0 / 30)
		check(st.title.text != "" and not st.title.text.begins_with("Connecting"), role + ": " + st.title.text)
		for key in ["down", "right", "left", "up"]:
			st._key(key)
		st.free()
	s.dispose()


func test_boss_and_chief_order_menus_issue_orders() -> void:
	for role in [Roles.BOSS, Roles.CHIEF]:
		var s := Session.new({"seed": 9, "location": "FRM", "mode": Roles.VERSUS, "features": Session.SANDBOX_FEATURES + ["hq"]})
		s.nights.runner_ai = null  # humans hold both HQ seats (what HostServer.pump does on join)
		s.nights.law_ai = null
		s.update(1.0 / 30)
		var st := StationApp.new()
		_tree().root.add_child(st)
		st.setup(LocalLink.new(s, role), role, s.world)
		st._process(1.0 / 30)
		var key := "route" if role == Roles.BOSS else "fund_heli"
		var i := st.order_rows.map(func(r): return r.key).find(key)
		st.list.select(i)
		st._key("right")  # route west -> north / heli 0 -> 1
		st._process(1.0 / 30)
		st._key("enter")
		check(st.status == "", role + ": " + st.status)
		var ss: HQ.Season = s.nights.season
		if role == Roles.BOSS:
			check_eq(ss.org.route, "north", "route changed through the menu")
		else:
			check_eq(ss.law.funded["heli"], 1, "heli funded through the menu")
		st.free()
		s.dispose()


func test_remote_seat_interpolates_snapshots() -> void:
	var s := Session.new({"seed": 4, "mode": Roles.VERSUS})
	var seat := RemoteSeat.new()
	_tree().root.add_child(seat)
	seat.setup(LocalLink.new(s, Roles.COPILOT), Roles.COPILOT, "low", s.world)
	for i in 3:
		seat._process(1.0 / 30)
	check(seat.nodes.size() >= 1, "own aircraft drawn")
	check("CO-PILOT" in seat.hud.text, seat.hud.text)
	var a := {"x": 0.0, "y": 0.0, "z": 0.0, "heading": 350.0}
	var b := {"x": 10.0, "y": 0.0, "z": 0.0, "heading": 10.0}
	seat.buf = [[0.0, {"seq": 1, "p": a}], [1e9, {"seq": 2, "p": b}]]
	var p = seat.pose(func(snap): return snap.p)
	check(p != null and p.x >= 0 and p.x < 1e-3, "interpolated between snapshots")
	check_near(RemoteSeat._lerp_angle(350, 10, 0.5), 360.0, 1e-9, "angles wrap the short way")
	seat.free()
	s.dispose()


func test_data_table_keyboard_skips_sections() -> void:
	var t := DataTable.new().setup([{"title": "A", "expand": true}, {"title": "B", "align": "right", "mono": true}])
	_tree().root.add_child(t)
	t.section("group one")
	t.add_row(["x", "1"])
	t.add_row(["y", "2"])
	t.section("group two")
	t.add_row(["z", "3"])
	t.select_near(0)
	check_eq(t.selected_row(), 1, "first selectable row")
	t.move(1)
	t.move(1)
	check_eq(t.selected_row(), 4, "skips the section heading")
	t.move(1)
	check_eq(t.selected_row(), 1, "wraps round, skipping the top heading")
	var hit := [-1]
	t.row_activated.connect(func(i): hit[0] = i)
	t.item_activated.emit()
	check_eq(hit[0], 1, "activation reports the row")
	t.free()


func test_hud_regions_never_overlap_at_any_size() -> void:
	var s := Session.new({"seed": 4, "airframe": true})
	s.update(1.0 / 30)
	var hud := Hud.new()
	_tree().root.add_child(hud)
	hud.setup(s)
	s.state.stall_warning = true
	s.state.on_ground = false
	s.state.fuel_lb = 10
	s.state.ias_kts = 200
	s.fm.controls.flaps = 1
	s.police.case().bust_meter = 20
	s.police.case().rival_meter = 20
	s.autopilot.engaged = true
	s.copilot = "ai"
	s.pumping = true
	s.weather = {"sky": "storm", "wind_dir": 123, "wind_kt": 18, "moon": 0.5}
	if s.airframe != null:
		s.airframe.fail_until = s.time + 100
	hud.pulse = 140
	hud.refresh()
	for sz in [Vector2(1024, 768), Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1080)]:
		hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
		hud.size = sz
		await _tree().process_frame
		await _tree().process_frame
		var names: Array = hud.zones.keys()
		for i in names.size():
			var a: Rect2 = hud.zones[names[i]].get_rect()
			check(a.position.x >= 0 and a.end.x <= sz.x + 0.5 and a.position.y >= 0 and a.end.y <= sz.y + 0.5,
				"%s on screen at %s: %s" % [names[i], sz, a])
			for j in range(i + 1, names.size()):
				var b: Rect2 = hud.zones[names[j]].get_rect()
				check(not a.intersects(b), "%s and %s overlap at %s" % [names[i], names[j], sz])
	hud.free()
	s.dispose()


func test_hud_prioritises_active_operations_and_explains_load_limits() -> void:
	var s := Session.new({"seed": 4})
	s.update(1.0 / 30)
	s.auto_kick = false
	s.copilot = ""
	var hud := Hud.new()
	_tree().root.add_child(hud)
	hud.setup(s)
	hud.refresh()
	check(not hud.chips.ap.visible and not hud.chips.crew.visible, "inactive AP and crew do not compete with aircraft state")
	check(not hud.chip_groups.OPERATIONS.visible, "empty operation group disappears")
	check(hud.chips.xpdr.visible and hud.chips.cam.visible, "aircraft state stays available")
	s.autopilot.engaged = true
	s.pumping = true
	hud.pulse = 140
	hud.refresh()
	check(hud.chips.ap.visible and hud.chips.pump.visible and hud.chip_groups.OPERATIONS.visible, "active operations appear")
	check(hud.chips.pulse.visible and hud.chip_groups.ALERTS.visible, "shaking is an alert")
	s.state.on_ground = false
	hud.refresh()
	check(hud.tiles.fuel.sub.text.begins_with("Est."), "endurance is labelled as an estimate")
	var item := Loadout.Item.new(99999, "Test load", "cargo", s.spec.mtow_lb * 2, 0)
	s.loadout.add(item)
	s.loadout.assignment[item.id] = 0
	hud.refresh()
	check("OVERWEIGHT" in hud.tiles.wb.text, "authoritative load limits are explained")
	s.scanner_log.append([s.time - 12, "Patrol reported near the docks"])
	hud.refresh()
	check("12s ago" in hud.intel.text and "NOT CONFIRMED" in hud.intel.text, "scanner reports show age and uncertainty")
	hud.free()
	s.dispose()


func test_map_reports_do_not_reveal_live_or_delayed_positions() -> void:
	var s := Session.new({"seed": 4})
	s.update(1.0 / 30)
	s.time = 100
	s.intel["reported-only"] = [80.0, 123.0, 456.0, "scanner"]
	s.intel["delayed-only"] = [110.0, 999.0, 999.0, "spotter@HAR"]
	var map := Minimap.new()
	map.s = s
	var contacts := map.known_contacts()
	check_eq(contacts["reported-only"].x, 123.0, "reported position retained")
	check_eq(contacts["reported-only"].age, 20.0, "report age retained")
	check_eq(contacts["reported-only"].source, "scanner", "report source retained")
	check(not contacts.has("delayed-only"), "delayed intel remains hidden")
	map.free()
	s.dispose()


func test_f1_help_scrolls_instead_of_being_cropped() -> void:
	var s := Session.new({"seed": 1, "location": "FRM"})
	var app := PilotApp.new()
	_tree().root.add_child(app)
	app.setup(s, "low")
	for i in 3:
		app._process(1.0 / 30)
	check(app.help is PanelContainer, "the F1 panel is a bordered box, not a bare label")
	var scroll := app.help.get_child(0)
	check(scroll is ScrollContainer, "its content sits in a ScrollContainer")
	check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "the help text is taller than the box: it needs to scroll")
	check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "no sideways scroll")
	app._unhandled_input(T.key(KEY_F1))
	check(app.help.visible, "F1 opens it")
	app._unhandled_input(T.key(KEY_F1))
	check(not app.help.visible, "F1 again closes it")
	app.queue_free()
	app.free()
	s.dispose()


func test_attitude_ball_leans_toward_the_low_wing() -> void:
	check_near(Attitude.down_vector(0.0).x, 0.0, 0.001, "wings level: the ground is straight down")
	check(Attitude.down_vector(30.0).x > 0.4, "banked right: the ground leans to the right")
	check(Attitude.down_vector(-30.0).x < -0.4, "banked left: to the left")
	var a := Attitude.new()
	a.set_data(200.0, 10.0)
	check_near(a.pitch, 90.0, 0.001, "pitch is clamped so the ball cannot run off its scale")
	a.free()


func test_the_radar_turns_with_the_nose_and_the_chart_holds_north() -> void:
	var s := Session.new({"seed": 7})
	s.update(1.0 / 30)
	var m := Minimap.new()
	_tree().root.add_child(m)
	m.setup(s)
	m._frame()
	var st: FlightModel.FlightState = s.state
	check(m.to_screen(st.x, st.y).distance_to(m._c) < 0.01, "you are at the centre of the radar")
	var ahead := deg_to_rad(st.heading)
	var p := m.to_screen(st.x + sin(ahead) * 1000.0, st.y + cos(ahead) * 1000.0)
	check(absf(p.x - m._c.x) < 0.01 and p.y < m._c.y, "a point dead ahead is straight up the scope, whatever the heading")
	m.north_up = true
	m._frame()
	var n := m.to_screen(st.x, st.y + 1000.0)
	check(absf(n.x - m._c.x) < 0.01 and n.y < m._c.y, "north-up: north is up")
	var z := m.range_km()
	m.zoom(1)
	check(m.range_km() > z, "zoom steps outward")
	m.zoom(-9)
	m.zoom(-1)
	check_eq(m.zoom_i, 0, "and stops at the closest range")
	m.toggle()
	m._frame()
	check(m.big and m._h == 0.0, "the chart is north-up")
	check(m.to_screen(0.0, 0.0).distance_to(Vector2(m._chart_px(), m._chart_px()) / 2.0) < 0.5, "centred on the island")
	m.free()
	s.dispose()


func test_a_click_on_the_open_chart_sets_a_waypoint_and_right_click_clears_it() -> void:
	var s := Session.new({"seed": 7})
	s.update(1.0 / 30)
	var m := Minimap.new()
	_tree().root.add_child(m)
	m.setup(s)
	var got := []
	m.waypoint_picked.connect(func(p): got.append(p))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(10, 10)
	m._gui_input(click)
	check(m.waypoint == null and got.is_empty(), "the small radar does not take clicks")
	m.toggle()
	check_eq(m.mouse_filter, Control.MOUSE_FILTER_STOP, "the open chart does")
	click.position = Vector2(m._chart_px(), m._chart_px()) / 2.0
	m._gui_input(click)
	check(m.waypoint != null and got.size() == 1, "a click on the open chart picks a place")
	var w: Vector2 = m.waypoint
	check(w.length() < 400.0, "the middle of the chart is the middle of the island: %s" % w)
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	m._gui_input(right)
	check(m.waypoint == null and got.size() == 2 and got[1] == Vector2.INF, "right-click clears it")
	m.free()
	s.dispose()


func test_the_places_panel_lists_what_is_yours_and_what_is_locked() -> void:
	var s := Session.new({"seed": 7, "map_seed": MapCity.SEED, "features": Session.SANDBOX_FEATURES, "trade": true, "logistics": true})
	s.update(1.0 / 30)
	var all := Places.list(s)
	var names := all.map(func(p): return str(p.name))
	check(names.any(func(n): return "boss's desk" in n), "the boss's desk is on the list: %s" % [names.slice(0, 4)])
	check(all.any(func(p): return p.kind == "casino" and p.state == "locked" and "opens in" in str(p.note)), "a place not yet open says what opens it")
	check(all.any(func(p): return p.kind == "stash") or s.stash_net == null, "stash houses are listed when there are any")
	var ord := Places.ordered(all)
	check(ord[0].state == "mine", "yours come first")
	check(ord[ord.size() - 1].state in ["locked", "open"], "and what is not open comes last")
	var mk := Places.markers(all)
	check(mk.all(func(p): return p.state != "locked"), "a locked place gets no marker on the chart")
	var m := Minimap.new()
	_tree().root.add_child(m)
	m.setup(s)
	m.toggle()
	m._process(0.1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(m._chart_px() + 40.0, 34.0 * m._scale() + 4.0)  # the first row
	var got := []
	m.waypoint_picked.connect(func(p): got.append(p))
	m._gui_input(click)
	check(got.size() == 1 and m.waypoint != null, "a click on a place in the panel sets the waypoint")
	m.free()
	s.dispose()
