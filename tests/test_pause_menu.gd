extends TestCase
## ESC is a pause menu, not a quit: it stops the game, offers save / load /
## settings / quit, and resumes cleanly.

var _settings_backup := ""


func before_each() -> void:
	_settings_backup = FileAccess.get_file_as_string(ControlsConfig.SETTINGS_PATH) if FileAccess.file_exists(ControlsConfig.SETTINGS_PATH) else ""


func after_each() -> void:
	if _settings_backup == "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ControlsConfig.SETTINGS_PATH))
	else:
		var f := FileAccess.open(ControlsConfig.SETTINGS_PATH, FileAccess.WRITE)
		f.store_string(_settings_backup)
	PauseMenu.apply_volume(1.0)


func _esc() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	return ev


func _app(save_path := "") -> Array:
	var s := Session.new({"seed": 1, "location": "FRM", "save_path": save_path})
	var app := PilotApp.new()
	Engine.get_main_loop().root.add_child(app)
	app.setup(s, "low")
	for i in 3:
		app._process(1.0 / 30)
	return [app, s]


func _free(app: PilotApp, s: Session) -> void:
	app.queue_free()
	app.free()
	s.dispose()


func test_esc_pauses_and_resumes_instead_of_quitting() -> void:
	var r := _app()
	var app: PilotApp = r[0]
	var s: Session = r[1]
	app._unhandled_input(_esc())
	check(app.pause_menu != null, "ESC opens the pause menu")
	check(app.paused, "the game is paused under it")
	var t: float = s.time
	app._process(1.0 / 30)
	check_eq(s.time, t, "no sim time passes while paused")
	app._unhandled_input(_esc())  # a second ESC while open must not stack another
	check(app.pause_menu != null, "still one menu")
	app.pause_menu._input(_esc())  # ESC inside the menu resumes
	check(app.pause_menu == null and not app.paused, "ESC in the menu resumes")
	app._process(1.0 / 30)
	check(s.time > t, "time runs again")
	_free(app, s)


func test_pause_keeps_a_manual_pause() -> void:
	var r := _app()
	var app: PilotApp = r[0]
	app.paused = true  # P
	app.open_pause()
	app.close_pause()
	check(app.paused, "P's pause survives the menu")
	_free(app, r[1])


func test_hosting_does_not_stop_the_game() -> void:
	var r := _app()
	var app: PilotApp = r[0]
	app.server = HostServer.new()
	app.open_pause()
	check(not app.paused, "friends are flying: the game runs on")
	app.close_pause()
	app.server.free()
	app.server = null
	_free(app, r[1])


func test_menu_offers_match_the_session() -> void:
	var r := _app()
	var app: PilotApp = r[0]
	app.open_pause()
	var texts: Array = app.pause_menu.buttons.map(func(b: Button) -> String: return b.text)
	check(not texts.any(func(t: String) -> bool: return t.begins_with("Save")), "no save without a save file: %s" % [texts])
	check(texts.any(func(t: String) -> bool: return t.begins_with("Quit to lobby")), "quit to lobby offered")
	check(texts.any(func(t: String) -> bool: return t.begins_with("Quit to desktop")), "quit to desktop offered")
	app.close_pause()
	_free(app, r[1])
	var path := "user://test_pause_save.json"
	var r2 := _app(path)
	r2[0].open_pause()
	var t2: Array = r2[0].pause_menu.buttons.map(func(b: Button) -> String: return b.text)
	check(t2.any(func(t: String) -> bool: return t.begins_with("Save")), "save offered with a save file")
	check(t2.any(func(t: String) -> bool: return t.begins_with("Load")), "load offered with a save file")
	r2[0].close_pause()
	_free(r2[0], r2[1])


func test_save_writes_and_lobby_asks_first() -> void:
	var path := "user://test_pause_save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var r := _app(path)
	var app: PilotApp = r[0]
	app.open_pause()
	app._on_pause_choice("save")
	check(FileAccess.file_exists(path), "Save wrote the save")
	# quit to lobby is confirmed first, and No changes nothing
	var went: Array = []
	app.leave.connect(func(to: String): went.append(to))
	app.pause_menu.buttons.filter(func(b: Button) -> bool: return b.text.begins_with("Quit to lobby"))[0].pressed.emit()
	check(app.pause_menu.confirm.visible, "asks before leaving")
	app.pause_menu.confirm.key("esc")
	check(went.is_empty() and app.pause_menu != null, "No stays put")
	app.pause_menu.buttons.filter(func(b: Button) -> bool: return b.text.begins_with("Quit to lobby"))[0].pressed.emit()
	app.pause_menu.confirm.key("enter")
	check_eq(went, ["lobby"], "Yes leaves to the lobby")
	check(app.pause_menu == null and not app.paused, "the menu is gone")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_free(app, r[1])


func test_volume_and_graphics_settings_persist() -> void:
	var r := _app()
	var app: PilotApp = r[0]
	app.open_pause()
	var pm: PauseMenu = app.pause_menu
	pm._step_volume(1)
	check_near(float(ControlsConfig.settings().volume), 0.75, 0.001, "volume steps down from full")
	check(not AudioServer.is_bus_mute(0), "not muted at 75%")
	for i in 4:
		pm._step_volume(1)
	check_near(float(ControlsConfig.settings().volume), 1.0, 0.001, "and wraps back to full after 0%")
	pm._step_volume(-1)
	check_near(float(ControlsConfig.settings().volume), 0.0, 0.001, "left goes to 0%")
	check(AudioServer.is_bus_mute(0), "0% mutes")
	pm._step_graphics(1)
	check_eq(str(ControlsConfig.settings().graphics), "medium", "graphics steps high -> medium")
	app.close_pause()
	_free(app, r[1])
