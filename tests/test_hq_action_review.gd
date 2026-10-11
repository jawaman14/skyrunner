extends TestCase
var session: Session
func after_each() -> void:
	if session != null: session.dispose()
	World.use_map(0)

func _session() -> Session:
	session = Session.new({"seed": 9, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "ground_war": true, "payroll": true, "logistics": true, "trade": true, "rackets": true})
	session.money = 100000
	return session

func test_district_overview_real_input_and_supported_layouts() -> void:
	var s := _session()
	var palette := UIStyle.palette
	for size in [Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		for colours in ["neon", "safe"]:
			UIStyle.set_palette(colours)
			var viewport := SubViewport.new()
			viewport.size = size
			Engine.get_main_loop().root.add_child(viewport)
			var menu := HQMenu.new()
			viewport.add_child(menu)
			menu.setup(s)
			menu.open()
			for i in 3: await Engine.get_main_loop().process_frame
			var at := menu.districts_button.get_global_rect().get_center()
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = at
			click.pressed = true
			viewport.push_input(click)
			click.pressed = false
			viewport.push_input(click)
			for i in 3: await Engine.get_main_loop().process_frame
			check(menu.districts_open, "real mouse opens district view %s/%s" % [size, colours])
			var bounds := menu.get_global_rect()
			var scroll_bounds := menu.district_scroll.get_global_rect()
			check(scroll_bounds.end.x <= bounds.end.x + 1 and scroll_bounds.end.y <= bounds.end.y + 1, "scroll surface fits the menu")
			check(menu.close_button.get_global_rect().end.y <= bounds.end.y, "exit remains in bounds")
			var cancel := InputEventJoypadButton.new()
			cancel.button_index = JOY_BUTTON_B
			cancel.pressed = true
			viewport.push_input(cancel)
			check(not menu.visible, "controller Back exits overview")
			viewport.free()
	UIStyle.set_palette(palette)


func test_district_overview_toggle_preserves_selection_and_blocks_hidden_map() -> void:
	var s := _session()
	var menu := HQMenu.new()
	Engine.get_main_loop().root.add_child(menu)
	menu.setup(s)
	menu.open()
	var squad = s.ground.recruit("org", "foot", null, false)
	menu.sel_squad = squad.id
	var before: Dictionary = squad.order.duplicate(true)
	menu.districts_button.emit_signal("pressed")
	check(menu.district_scroll.visible and not menu.map.visible, "overview replaces map instead of overflowing it")
	check("DISTRICTS" in menu.district_text.text, "shows district summary")
	menu._on_map_click(MOUSE_BUTTON_RIGHT, squad.pos() + Vector2(100, 0))
	check_eq(squad.order, before, "hidden map cannot issue an order")
	menu.key("d")
	check(menu.map.visible and not menu.district_scroll.visible, "keyboard returns to map")
	check_eq(menu.sel_squad, squad.id, "selection survives view switch")
	menu.close()
	menu.free()

func test_native_q_returns_from_districts_and_held_key_does_not_reclaim_seat() -> void:
	var s := _session()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024,768)
	Engine.get_main_loop().root.add_child(viewport)
	var app := PilotApp.new()
	app.s = s
	viewport.add_child(app)
	app.set_process(false)
	var menu := HQMenu.new()
	viewport.add_child(menu)
	menu.setup(s)
	app.menus["hq"] = menu
	menu.open()
	menu.key("d")
	for i in 3: await Engine.get_main_loop().process_frame
	check(menu.squad_mode and menu.districts_open and menu._claimed_boss)
	var press := InputEventKey.new()
	press.keycode = KEY_Q
	press.physical_keycode = KEY_Q
	press.pressed = true
	viewport.push_input(press)
	check(not menu.squad_mode and not menu.districts_open, "native Q returns to orders from the overview")
	check(not menu._claimed_boss, "return hands the boss seat back")
	press.echo = true
	viewport.push_input(press)
	check(not menu.squad_mode and not menu._claimed_boss, "held Q cannot reclaim the seat")
	press.echo = false
	press.pressed = false
	viewport.push_input(press)
	menu.close()
	viewport.free()


func test_hq_right_click_cannot_target_a_hidden_squad() -> void:
	var s := _session()
	var menu := HQMenu.new()
	Engine.get_main_loop().root.add_child(menu)
	menu.setup(s)
	menu.open()
	var own = s.ground.recruit("org", "foot", s.ground.hq("org"), false)
	var at: Vector2 = own.pos() + Vector2(12000, 12000)
	var enemy = s.ground.recruit("rival", "foot", at, false)
	enemy.hidden = true
	menu.sel_squad = own.id
	menu._on_map_click(MOUSE_BUTTON_RIGHT, at)
	check(own.order.get("squad", "") != enemy.id, "hidden enemy cannot be found by a click")
	check(own.order.type != "attack", "unobserved map position produces a positional order")
	own.x = at.x - 100
	own.y = at.y
	menu._on_map_click(MOUSE_BUTTON_RIGHT, at)
	check_eq(own.order.get("squad", ""), enemy.id, "observed enemy remains targetable")
	menu.close()
	menu.free()


func test_local_hq_shows_shared_squad_command_detail() -> void:
	var s := _session()
	var menu := HQMenu.new()
	Engine.get_main_loop().root.add_child(menu)
	menu.setup(s)
	menu.open()
	var squad = s.ground.recruit("org", "foot", null, false)
	squad.morale = 0.65
	squad.ammo = 123
	menu.sel_squad = squad.id
	menu._squad_detail()
	check("123 rounds" in menu.squad_label.text, "HQ displays ammunition")
	check("65%" in menu.squad_label.text, "HQ displays morale")
	check("Upkeep:" in menu.squad_label.text, "HQ displays authoritative upkeep")
	check(menu.squad_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "command detail wraps")
	menu.close()
	menu.free()


func test_disband_review_cancel_commit_and_close_restore_seat_and_focus() -> void:
	var s := _session()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	Engine.get_main_loop().root.add_child(viewport)
	var opener := Button.new()
	viewport.add_child(opener)
	opener.grab_focus()
	var menu := HQMenu.new()
	viewport.add_child(menu)
	menu.setup(s)
	menu.open()
	var squad = s.ground.recruit("org", "foot", null, false)
	menu.sel_squad = squad.id
	menu.key("disband")
	check(menu.confirmation != null and menu.confirmation.visible)
	check(not menu.confirmation.selected_yes, "Cancel initially selected")
	check(s.ground.get_squad(squad.id) != null, "opening review keeps squad")
	menu.key("esc")
	check(s.ground.get_squad(squad.id) != null, "Cancel leaves squad intact")
	menu.key("disband")
	for i in 3: await Engine.get_main_loop().process_frame
	menu.key("right")
	menu.key("enter")
	check(s.ground.get_squad(squad.id) == null, "explicit approval uses boss permission")
	check(menu.feedback.visible and "Disband" in menu.feedback.text)
	var next = s.ground.recruit("org", "foot", null, false)
	menu.sel_squad = next.id
	menu.key("disband")
	menu.close()
	check(s.ground.get_squad(next.id) != null, "closing pending review changes nothing")
	check(menu._pending_action.is_empty())
	check(not menu._claimed_boss and opener.has_focus(), "desk hands seat and focus back")
	viewport.free()

func test_partial_stock_dispatch_returns_actual_authoritative_outcome() -> void:
	var s := _session()
	var source: String = s.logistics.stock.keys()[0]
	var dest: String = s.logistics.stock.keys()[1]
	s.logistics.stock[source].marijuana = 25.0
	var result := s.command(Roles.PILOT, "move_goods", {"from": source, "to": dest, "good": "marijuana", "lb": 100.0})
	check(result[0])
	check("25" in result[1] and "marijuana" in result[1], "message describes the actual capped load")
	check_near(s.logistics.stock[source].marijuana, 0.0, 0.001)
	check("Sold" not in result[1], "dispatch is not reported as delivered")

func test_sale_outcome_survives_a_connection_news_update() -> void:
	session = Session.new({"seed": 9, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "family": true, "trade": true})
	session.family.respect = 50.0
	session.trade.stock.marijuana = 25.0
	session.trade.sold.marijuana = Trade.CONNECT_LB - 1.0
	var before := session.money
	var result := session.command(Roles.PILOT, "sell_product", {"buyer": "family", "good": "marijuana", "qty": 100.0})
	check(result[0])
	check("Sold 25.0 marijuana" in result[1], "transaction outcome survives follow-on news")
	check(Py.money(session.money - before) in result[1], "actual credited payment")
	check(session.trade.connected)

func test_ransom_ack_reports_actual_credit_without_enemy_balance() -> void:
	var s := _session()
	s.rackets.held = 3
	s.ground.commanders.rival.cash = 100.0
	var before := s.money
	var result := s.command(Roles.PILOT, "rackets", {"what": "ransom"})
	check(result[0])
	check("3 prisoners" in result[1] and "$100" in result[1])
	check("rival" not in result[1] and "balance" not in result[1], "only observed transaction result")
	check_eq(s.money - before, 100)
	check_eq(s.rackets.held, 0)
