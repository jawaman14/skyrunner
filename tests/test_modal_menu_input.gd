extends TestCase
var session: Session
var _files := {}
func before_each() -> void:
	_files = {}
	for path in [ControlsConfig.PATH, ControlsConfig.SETTINGS_PATH]:
		_files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
func after_each() -> void:
	for path in _files:
		if _files[path] == null:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(_files[path])
			file.close()
	UIStyle.set_palette("neon")
	if session != null: session.dispose()
	World.use_map(0)

func _viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 768)
	Engine.get_main_loop().root.add_child(viewport)
	return viewport

func _enter(viewport: SubViewport, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = true
	event.echo = echo
	viewport.push_input(event)
	if not echo:
		event = event.duplicate()
		event.pressed = false
		viewport.push_input(event)

func test_pack_native_activation_keeps_selection_and_blocks_repeat() -> void:
	session = Session.new({"seed": 21, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	session.money = 5000
	var viewport := _viewport()
	var opener := Button.new()
	viewport.add_child(opener)
	opener.grab_focus()
	var pack := PackMenu.new()
	pack.foot = session.foot
	viewport.add_child(pack)
	for i in 3: await Engine.get_main_loop().process_frame
	check(viewport.gui_get_focus_owner() is Button, "task focus exists")
	var plus: Button
	for row in pack.rows.get_children():
		for child in row.get_children():
			if child is Button and child.get_meta("pack_action", "") == "medkit/take": plus = child
	plus.grab_focus()
	var before: float = session.money
	_enter(viewport)
	check_eq(session.money, before - FootCombat.MEDKIT_COST, "native Enter activates one purchase")
	check_eq(viewport.gui_get_focus_owner().get_meta("pack_action", ""), "medkit/take", "refresh preserves action focus")
	_enter(viewport, true)
	check_eq(session.money, before - FootCombat.MEDKIT_COST, "echo does not repeat a transaction")
	pack.close()
	check(opener.has_focus(), "close restores invoking focus")
	await Engine.get_main_loop().process_frame
	viewport.free()

func test_controls_keyboard_palette_activation_and_focus_restore() -> void:
	var viewport := _viewport()
	var opener := Button.new()
	viewport.add_child(opener)
	opener.grab_focus()
	var menu := ControlsMenu.new()
	viewport.add_child(menu)
	for i in 3: await Engine.get_main_loop().process_frame
	check(menu.palette_btn.has_focus())
	var before := UIStyle.palette
	_enter(viewport)
	check(UIStyle.palette != before, "native Enter reaches Controls button")
	for i in 2: await Engine.get_main_loop().process_frame
	check_eq(menu.get_child(0).theme, UIStyle.theme(), "open root theme refreshes")
	_enter(viewport, true)
	check(UIStyle.palette != before, "held Enter does not toggle twice")
	var cancel := InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	cancel.pressed = true
	viewport.push_input(cancel)
	check(opener.has_focus(), "controller Back closes and restores focus")
	await Engine.get_main_loop().process_frame
	viewport.free()

func test_single_remote_cash_order_retains_pending_and_refusal_messages() -> void:
	var menu := LogisticsMenu.new()
	var viewport := _viewport()
	menu.view_fn = func(): return {"sites": [{"id": "a", "name": "A", "market": "town", "burned": false, "cash": 50, "cocaine": 0, "marijuana": 0}], "hq": "Club", "aboard": 0, "trucks": [], "last": ""}
	menu.send_fn = func(_name, _args): return 7
	viewport.add_child(menu)
	menu._all_home()
	check("awaiting" in menu.status.text, "pending order never says No cash or completed")
	menu.send_fn = Callable()
	menu.cmd_fn = func(_name, _args): return [false, "No available truck."]
	menu._all_home()
	check_eq(menu.status.text, "No available truck.", "authoritative refusal is retained")
	viewport.free()

func test_controls_tabs_fit_small_window_and_axis_decrement_is_keyboard_accessible() -> void:
	var viewport := _viewport()
	var menu := ControlsMenu.new()
	viewport.add_child(menu)
	for i in 3: await Engine.get_main_loop().process_frame
	var tabs: TabContainer = menu.panel.get_child(0).get_child(2)
	check_eq(tabs.get_tab_count(), 3, "flight, hardware and context reference")
	check_eq(tabs.current_tab, 0, "everyday bindings first")
	tabs.current_tab = 1
	for i in 2: await Engine.get_main_loop().process_frame
	var scroll: ScrollContainer = tabs.get_child(1)
	check(scroll.follow_focus, "keyboard focus scrolls into view")
	check(scroll.get_child(0).size.x <= scroll.size.x + 1, "hardware fits 1024px window")
	var actions: HBoxContainer = scroll.get_child(0).get_child(1).get_child(3)
	var less: Button = actions.get_child(2)
	var binding: FlightAxes.Binding = ControlsConfig.axes.bindings[FlightAxes.CONTROLS.keys()[0]]
	var before := binding.deadzone
	less.grab_focus()
	_enter(viewport)
	check_near(binding.deadzone, maxf(0.0, before - 0.02), 0.0001, "Enter decreases deadzone once")
	binding.deadzone = before
	viewport.free()
