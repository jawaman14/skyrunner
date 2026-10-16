extends TestCase
func _key(viewport: Viewport, code: int, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = echo
	viewport.push_input(event)

func test_cancel_is_default_and_held_enter_cannot_approve() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 768)
	Engine.get_main_loop().root.add_child(viewport)
	var opener := Button.new()
	viewport.add_child(opener)
	opener.grab_focus()
	var modal := ConfirmBox.new().setup("A long consequence. ".repeat(100), "Commit", "Cancel")
	viewport.add_child(modal)
	var answers := []
	modal.answered.connect(func(yes): answers.append(yes))
	modal.ask()
	check(modal.no_btn.has_focus())
	_key(viewport, KEY_RIGHT)
	_key(viewport, KEY_ENTER)
	check(answers.is_empty(), "opening frame cannot approve")
	for i in 3:
		await Engine.get_main_loop().process_frame
	_key(viewport, KEY_ENTER, true)
	check(answers.is_empty(), "held key cannot approve")
	_key(viewport, KEY_ESCAPE)
	check_eq(answers, [false])
	check(opener.has_focus(), "focus returns to opener")
	modal.ask()
	for i in 3:
		await Engine.get_main_loop().process_frame
	_key(viewport, KEY_ENTER)
	check_eq(answers, [false, false], "Enter defaults to cancellation")
	modal.ask()
	for i in 3:
		await Engine.get_main_loop().process_frame
	_key(viewport, KEY_RIGHT)
	_key(viewport, KEY_ENTER)
	check_eq(answers, [false, false, true], "explicit selection confirms")
	check(modal.panel.get_global_rect().end.x <= 1024)
	check(modal.panel.get_global_rect().end.y <= 768)
	viewport.queue_free()
