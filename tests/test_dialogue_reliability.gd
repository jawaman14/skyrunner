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
