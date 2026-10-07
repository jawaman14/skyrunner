extends TestCase
var session: Session
func after_each() -> void:
	if session != null: session.dispose()
	World.use_map(0)

func _session() -> Session:
	session = Session.new({"seed": 9, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "ground_war": true, "payroll": true, "logistics": true, "trade": true, "rackets": true})
	session.money = 100000
	return session

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
