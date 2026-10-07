extends TestCase

class Remote:
	extends RefCounted
	var acks := {}
	var view := {"seq": 1}
	var connected := true
	var sent := 0
	func snapshot() -> Dictionary:
		return view
	func alive() -> bool:
		return connected
	func send_command(_name: String, _args: Dictionary) -> int:
		sent += 1
		return sent

func _request(link: Remote, state: Talk.State, box: Dictionary, timeout := 1000) -> void:
	box.reply = await Talk.command_result(link, "purchase", {}, state, timeout)

func test_ack_is_correlated_and_success_waits_for_snapshot() -> void:
	var remote := Remote.new()
	var state := Talk.State.new(remote.snapshot, Callable())
	var box := {}
	_request.call_deferred(remote, state, box)
	await Engine.get_main_loop().process_frame
	remote.acks[77] = [true, "other command"]
	await Engine.get_main_loop().process_frame
	check(box.is_empty(), "another sequence cannot complete this command")
	remote.acks[1] = [true, "accepted"]
	await Engine.get_main_loop().process_frame
	check(box.is_empty(), "ack alone does not imply refreshed stock")
	remote.view = {"seq": 2}
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	check_eq(box.get("reply"), [true, "accepted"])
	check_eq(remote.sent, 1)

func test_denial_disconnect_and_close_never_resend() -> void:
	for kind in ["denial", "disconnect", "close", "timeout"]:
		var remote := Remote.new()
		var state := Talk.State.new(remote.snapshot, Callable())
		var box := {}
		_request.call_deferred(remote, state, box, 30 if kind == "timeout" else 1000)
		await Engine.get_main_loop().process_frame
		if kind == "denial":
			remote.acks[1] = [false, "Permission denied"]
		elif kind == "disconnect":
			remote.connected = false
		elif kind == "close":
			state.cancelled = true
		for frame in 30:
			if not box.is_empty():
				break
			await Engine.get_main_loop().process_frame
		check(not box.is_empty() and not bool(box.reply[0]), kind)
		check_eq(remote.sent, 1, "no automatic retry")

func test_all_nine_scripts_compile() -> void:
	for name in ["family", "general", "crew", "lawyer", "buyers", "dealer", "psych", "casino", "casino_file"]:
		check(Talk.resource(name) != null, name)

func test_eleven_choices_keyboard_and_duplicate_activation() -> void:
	var source := "~ start\nSpeaker: Choose.\n"
	for i in 11:
		source += "- Choice %d with a longer description that can wrap.\n\t=> finish\n" % i
	source += "~ finish\nSpeaker: Finished.\n=> END\n"
	var compiled: DMCompilerResult = DMCompiler.compile_string(source, "test.dialogue")
	check(compiled.errors.is_empty())
	var resource := DialogueResource.new()
	resource.lines = compiled.lines
	resource.titles = compiled.titles
	resource.first_title = compiled.first_title
	var balloon := TalkBalloon.new()
	Engine.get_main_loop().root.add_child(balloon)
	await balloon.start(resource, "start", Talk.State.new(func(): return {}, func(_n, _a): return [true, ""]))
	for i in 10:
		var event := InputEventKey.new()
		event.keycode = KEY_DOWN
		event.pressed = true
		Input.parse_input_event(event)
		await Engine.get_main_loop().process_frame
	check_eq(balloon.selected, 10, "choice beyond nine is reachable with real events")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	for i in 4:
		await Engine.get_main_loop().process_frame
	check_eq(balloon.text.text, "Finished.")
	balloon.busy = true
	await balloon.advance()
	check_eq(balloon.text.text, "Finished.", "pending activation is blocked")
	balloon._close()


func _compile(source: String) -> DialogueResource:
	var compiled: DMCompilerResult = DMCompiler.compile_string(source, "input_test.dialogue")
	check(compiled.errors.is_empty())
	var resource := DialogueResource.new()
	resource.lines = compiled.lines
	resource.titles = compiled.titles
	resource.first_title = compiled.first_title
	return resource

func _mouse(viewport: Viewport, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = at
	event.pressed = down
	viewport.push_input(event)

func test_removed_pending_conversation_cannot_update_replacement() -> void:
	var remote := Remote.new()
	var state := Talk.State.new(remote.snapshot, Callable())
	state.cmd_fn = func(name, args): return await Talk.command_result(remote, name, args, state)
	var source := _compile("~ start\nSpeaker: Buy?\n- Buy.\n\tdo buy_stake()\n\t=> finish\n~ finish\nSpeaker: Bought.\n=> END\n")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 768)
	Engine.get_main_loop().root.add_child(viewport)
	var balloon := TalkBalloon.new()
	viewport.add_child(balloon)
	await balloon.start(source, "start", state)
	for i in 3:
		await Engine.get_main_loop().process_frame
	var at: Vector2 = balloon.choices.get_child(0).get_global_rect().get_center()
	_mouse(balloon.get_viewport(), at, true)
	_mouse(balloon.get_viewport(), at, false)
	await Engine.get_main_loop().process_frame
	check_eq(remote.sent, 1)
	check(balloon.busy)
	_mouse(balloon.get_viewport(), at, true)
	_mouse(balloon.get_viewport(), at, false)
	await Engine.get_main_loop().process_frame
	check_eq(remote.sent, 1, "second activation does not send another mutation")
	balloon.queue_free()
	await Engine.get_main_loop().process_frame
	check(state.cancelled, "actual scene removal cancels presentation")
	var replacement := TalkBalloon.new()
	viewport.add_child(replacement)
	await replacement.start(_compile("~ start\nSpeaker: Replacement.\n=> END\n"), "start", Talk.State.new(func(): return {}, Callable()))
	remote.acks[1] = [true, "accepted"]
	remote.view = {"seq": 2}
	for i in 4:
		await Engine.get_main_loop().process_frame
	check_eq(replacement.text.text, "Replacement.")
	check_eq(remote.sent, 1)
	viewport.queue_free()
	state.cmd_fn = Callable()

func test_long_choices_fit_palettes_sizes_and_mouse_controller_input() -> void:
	var original_palette := UIStyle.palette
	var source := "~ start\nSpeaker: " + "Long introduction. ".repeat(40) + "\n"
	for i in 11:
		source += "- Choice %d. %s\n\t=> finish\n" % [i, "A wrapped consequence. ".repeat(8)]
	source += "~ finish\nSpeaker: Finished.\n=> END\n"
	for palette in ["neon", "safe"]:
		UIStyle.set_palette(palette)
		for dimensions in [Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
			var viewport := SubViewport.new()
			viewport.size = dimensions
			Engine.get_main_loop().root.add_child(viewport)
			var balloon := TalkBalloon.new()
			viewport.add_child(balloon)
			await balloon.start(_compile(source), "start", Talk.State.new(func(): return {}, Callable()))
			for i in 4:
				await Engine.get_main_loop().process_frame
			UIStyle.set_palette("safe" if palette == "neon" else "neon")
			await Engine.get_main_loop().process_frame
			check_eq(balloon.who.get_theme_color("font_color"), UIStyle.PINK, "open dialogue updates palette")
			UIStyle.set_palette(palette)
			check(balloon.panel.get_global_rect().end.y <= dimensions.y, "panel fits")
			check(balloon.panel.get_global_rect().end.x <= dimensions.x, "panel width fits")
			check(balloon.leave.get_global_rect().end.y <= dimensions.y, "exit remains reachable")
			for i in 10:
				var down := InputEventJoypadButton.new()
				down.button_index = JOY_BUTTON_DPAD_DOWN
				down.pressed = true
				viewport.push_input(down)
				await Engine.get_main_loop().process_frame
			check_eq(balloon.selected, 10, "controller reaches choice eleven")
			for i in 3:
				await Engine.get_main_loop().process_frame
			var at: Vector2 = balloon.choices.get_child(10).get_global_rect().get_center()
			_mouse(viewport, at, true)
			_mouse(viewport, at, false)
			_mouse(viewport, at, true)
			_mouse(viewport, at, false)
			for i in 4:
				await Engine.get_main_loop().process_frame
			check_eq(balloon.text.text, "Finished.", "actual mouse activation")
			viewport.queue_free()
			await Engine.get_main_loop().process_frame
	UIStyle.set_palette(original_palette)

func _review_request(balloon: TalkBalloon, link, state: Talk.State, args: Dictionary, reply: Dictionary) -> void:
	reply.result = await Talk.reviewed_result(balloon, link, "buy_vehicle", args, state)

func test_dialogue_purchase_review_cancel_commit_and_removal() -> void:
	for cause in ["cancel", "approve", "remove"]:
		var session := Session.new({"seed": 9, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "dealership": true, "money": 200000})
		var link := LocalLink.new(session, Roles.PILOT, false)
		var state := Talk.State.new(link.snapshot, Callable())
		var balloon := TalkBalloon.new()
		balloon.state = state
		Engine.get_main_loop().root.add_child(balloon)
		var args := {"id": "van"}
		var reply := {}
		_review_request(balloon, link, state, args, reply)
		check(balloon.review != null and session.dealer.owned.is_empty())
		args.id = "box"
		for i in 3: await Engine.get_main_loop().process_frame
		if cause == "remove":
			Engine.get_main_loop().root.remove_child(balloon)
		elif cause == "cancel":
			balloon.review.box.key("esc")
		else:
			balloon.review.box.key("right")
			balloon.review.box.key("enter")
		for i in 4: await Engine.get_main_loop().process_frame
		check(reply.has("result"), cause + " resolves the pending dialogue")
		if cause == "approve":
			check(reply.result[0])
			check_eq(session.dealer.owned.size(), 1)
			check_eq(session.dealer.owned[0].id, "van", "confirmation executes the reviewed vehicle")
		else:
			check(not reply.result[0] and session.dealer.owned.is_empty())
		balloon.free()
		session.dispose()
		World.use_map(0)
