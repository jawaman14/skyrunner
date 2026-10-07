extends TestCase
class Peer extends RefCounted:
	var role := Roles.BOSS
	var capabilities := ["action_previews"]
	var previews := {}
	var acks := {}
	var requested := 0
	var sent := 0
	var connected := true
	var cancelled := []
	func alive() -> bool: return connected
	func request_preview(_name, _args) -> int:
		requested += 1
		return requested
	func cancel_preview(sequence: int) -> void:
		cancelled.append(sequence)
		previews.erase(sequence)
	func send_command(_name, _args) -> int:
		sent += 1
		return sent

func _descriptor(price := 10) -> Dictionary:
	return {"enabled": true, "label": "Buy", "preview": "Charge $%d" % price, "args": {"id": "van"}}

func _review(peer: Peer) -> ActionReview:
	var review := ActionReview.new().setup(peer, "buy_vehicle", {"id": "van"})
	review.finished.connect(func(approved, _message):
		if approved: peer.send_command("buy_vehicle", {"id": "van"}))
	Engine.get_main_loop().root.add_child(review)
	return review

func _arm() -> void:
	for i in 3: await Engine.get_main_loop().process_frame

func test_delayed_and_changed_previews_require_explicit_fresh_review() -> void:
	var peer := Peer.new()
	var review := _review(peer)
	await _arm()
	review.box.key("right")
	review.box.key("enter")
	check_eq(peer.requested, 1, "disabled confirmation does not re-request or send")
	check_eq(peer.sent, 0)
	peer.previews[1] = _descriptor()
	review.poll(0)
	check(not review.box.selected_yes, "ready preview starts on Cancel")
	await _arm()
	review.box.key("right")
	review.box.key("enter")
	check_eq(peer.requested, 2, "approval only asks for a fresh read-only preview")
	check_eq(peer.sent, 0)
	peer.previews[2] = _descriptor(11)
	review.poll(0)
	check("State changed" in review.box.msg.text and not review.box.selected_yes)
	await _arm()
	review.box.key("right")
	review.box.key("enter")
	peer.previews[3] = _descriptor(11)
	review.poll(0)
	review.poll(0)
	check_eq(peer.sent, 1, "matching recheck sends exactly once")
	await Engine.get_main_loop().process_frame

func test_cancel_removal_seat_disconnect_and_timeout_never_send_mutations() -> void:
	for cause in ["cancel", "remove", "seat", "disconnect", "timeout"]:
		var peer := Peer.new()
		var review := _review(peer)
		match cause:
			"cancel": review.box.key("esc")
			"remove": Engine.get_main_loop().root.remove_child(review)
			"seat": peer.role = Roles.CHIEF
			"disconnect": peer.connected = false
		review.poll(11.0 if cause == "timeout" else 0.0)
		peer.previews[1] = _descriptor()
		review.poll(0.0)
		check_eq(peer.sent, 0, cause + " fences delayed preview")
		if cause == "remove":
			check(peer.cancelled.has(1), "removed query is cancelled locally")
			review.free()
		await Engine.get_main_loop().process_frame

func test_unsupported_preview_is_explicit_and_keeps_confirmed_legacy_command() -> void:
	var peer := Peer.new()
	peer.capabilities = []
	var review := _review(peer)
	check("Preview unavailable" in review.box.msg.text)
	check(not review.box.selected_yes)
	await _arm()
	review.box.key("right")
	review.box.key("enter")
	check_eq(peer.requested, 0)
	check_eq(peer.sent, 1, "explicitly confirmed legacy command remains usable")
	await Engine.get_main_loop().process_frame

func test_disallowed_preview_remains_visible_without_a_command() -> void:
	var peer := Peer.new()
	var review := _review(peer)
	peer.previews[1] = {"enabled": false, "disabled_reason": "Not enough money."}
	review.poll(0)
	check_eq(review.box.msg.text, "Not enough money.")
	await _arm()
	review.box.key("right")
	review.box.key("enter")
	check_eq(peer.sent, 0)
	review.box.key("esc")
	await Engine.get_main_loop().process_frame

func test_confirmation_controller_back_and_disabled_approval() -> void:
	var peer := Peer.new()
	var review := _review(peer)
	await _arm()
	var right := InputEventJoypadButton.new()
	right.button_index = JOY_BUTTON_DPAD_RIGHT
	right.pressed = true
	review.box._input(right)
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	review.box._input(accept)
	check_eq(peer.sent, 0)
	check_eq(peer.requested, 1)
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	review.box._input(back)
	check_eq(review.state, "closed")
	await Engine.get_main_loop().process_frame

func test_local_logistics_review_cancel_and_capped_commit() -> void:
	var session := Session.new({"seed": 9, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "trade": true, "logistics": true})
	var source: String = session.logistics.stock.keys()[0]
	var dest: String = session.logistics.stock.keys()[1]
	session.logistics.stock[source].marijuana = 25.0
	var menu := LogisticsMenu.new()
	menu.view_fn = session.logistics.view
	menu.cmd_fn = func(name, args): return session.command(Roles.PILOT, name, args)
	menu.review_link = LocalLink.new(session, Roles.PILOT, false)
	Engine.get_main_loop().root.add_child(menu)
	var args := {"from": source, "to": dest, "good": "marijuana", "lb": 100.0}
	var result := menu._command("move_goods", args)
	check(not result[0] and menu.review != null)
	check_near(session.logistics.stock[source].marijuana, 25, 0.001)
	menu.review.box.key("esc")
	check_near(session.logistics.stock[source].marijuana, 25, 0.001, "Cancel changes nothing")
	menu._command("move_goods", args)
	args.lb = 1.0
	await _arm()
	menu.review.box.key("right")
	menu.review.box.key("enter")
	check_near(session.logistics.stock[source].marijuana, 0, 0.001)
	check("25" in menu.status.text and "marijuana" in menu.status.text, "reviewed quantity survives caller argument mutation; actual capped outcome is visible")
	menu.free()
	session.dispose()
	World.use_map(0)

func test_station_disband_review_feeds_sequence_outcomes_after_approval() -> void:
	var session := Session.new({"seed": 9, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	var squad = session.ground.recruit("org", "foot", null, false)
	var app := StationApp.new()
	Engine.get_main_loop().root.add_child(app)
	app.setup(LocalLink.new(session, Roles.BOSS, false), Roles.BOSS, session.world)
	app._cmd("disband_squad", {"id": squad.id})
	check(app.review != null and app.outcomes.records.is_empty(), "preview is not a command acknowledgement")
	check(session.ground.get_squad(squad.id) != null)
	app.review.box.key("esc")
	check(app.outcomes.records.is_empty())
	app._cmd("disband_squad", {"id": squad.id})
	await _arm()
	app.review.box.key("right")
	app.review.box.key("enter")
	check(session.ground.get_squad(squad.id) == null)
	check_eq(app.outcomes.records.size(), 1)
	check_eq(app.outcomes.records[0].state, "refreshed", "local authoritative outcome flows through presentation")
	app.free()
	session.dispose()
	World.use_map(0)
