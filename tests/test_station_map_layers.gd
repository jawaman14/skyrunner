extends TestCase
func after_each() -> void:
	UIStyle.set_palette("neon")
	World.use_map(0)

func test_layers_only_filter_existing_snapshot_items_and_keep_report_metadata() -> void:
	var map := StationMap.new()
	map.snap = {"side": "law", "jobs": [{"id": "job"}], "trucks": [{"id": "truck"}], "tracks": [{"id": "reported", "source": "radar", "age": 12.0, "uncertainty": 200.0}]}
	var before := JSON.stringify(map.snap)
	check_eq(map.visible_items("tracks")[0].source, "radar")
	map.set_layer("intelligence", false)
	check(map.visible_items("tracks").is_empty())
	check_eq(map.visible_items("jobs").size(), 1)
	check_eq(map.visible_items("trucks").size(), 1)
	map.set_layer("people", false)
	check(map.visible_items("trucks").is_empty())
	map.set_layer("operations", false)
	check(map.visible_items("jobs").is_empty())
	map.set_layer("intelligence", true)
	check_eq(map.visible_items("tracks")[0].uncertainty, 200.0)
	check_eq(map.visible_items("tracks").size(), 1, "no additional enemy entity is synthesized")
	check_eq(JSON.stringify(map.snap), before)
	map.free()

func test_all_nonflying_seats_build_layer_controls_and_keep_map_within_small_window() -> void:
	var session := Session.new({"seed": 9, "map_seed": MapCity.SEED, "location": "HAR", "mode": Roles.VERSUS, "features": Session.SANDBOX_FEATURES + ["hq"], "ground_war": true, "payroll": true, "logistics": true, "trade": true})
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 768)
	Engine.get_main_loop().root.add_child(viewport)
	for role in Roles.ALL:
		if role == Roles.PILOT: continue
		var app := StationApp.new()
		viewport.add_child(app)
		app.setup(LocalLink.new(session, role, false), role, session.world)
		for i in 3: await Engine.get_main_loop().process_frame
		check_eq(app.layer_buttons.size(), 3, role + " layer controls")
		check(app.map.get_global_rect().end.x <= 1024.1 and app.map.get_global_rect().end.y <= 768.1, role + " map remains inside viewport")
		app.layer_buttons.operations.grab_focus()
		await Engine.get_main_loop().process_frame
		check_eq(viewport.gui_get_focus_owner(), app.layer_buttons.operations, role + " layer control owns focus")
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = true
		viewport.push_input(event)
		event = event.duplicate()
		event.pressed = false
		viewport.push_input(event)
		check(not app.map.layers.operations, role + " native keyboard toggle")
		check(app.review == null, role + " map input does not open a transaction review")
		app.free()
	viewport.free()
	session.dispose()

func test_hidden_squad_markers_cannot_change_selection_or_dispatch() -> void:
	var session := Session.new({"seed": 9, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	var app := StationApp.new()
	Engine.get_main_loop().root.add_child(app)
	app.setup(LocalLink.new(session, Roles.LIEUTENANT, false), Roles.LIEUTENANT, session.world)
	app.sel_squad = "keep"
	app.map.set_layer("people", false)
	var snap := {"ground": {"squads": [{"id": "other", "faction": "org", "x": 0.0, "y": 0.0}]}}
	app._squad_click(MOUSE_BUTTON_LEFT, Vector2.ZERO, snap)
	app._squad_click(MOUSE_BUTTON_RIGHT, Vector2.ZERO, snap)
	check_eq(app.sel_squad, "keep")
	check(app.outcomes.records.is_empty())
	app.free()
	session.dispose()

func test_layer_controls_fit_supported_sizes_and_refresh_open_palettes() -> void:
	var session := Session.new({"seed": 9, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES})
	var viewport := SubViewport.new()
	Engine.get_main_loop().root.add_child(viewport)
	var app := StationApp.new()
	viewport.add_child(app)
	app.setup(LocalLink.new(session, Roles.COPILOT, false), Roles.COPILOT, session.world)
	for palette in ["neon", "safe"]:
		UIStyle.set_palette(palette)
		for size in [Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
			viewport.size = size
			for i in 3: await Engine.get_main_loop().process_frame
			check_eq(app.theme.get_stylebox("focus", "Button").border_color, UIStyle.theme().get_stylebox("focus", "Button").border_color, "open focus palette")
			check(app.map.get_global_rect().end.x <= size.x + 0.1 and app.map.get_global_rect().end.y <= size.y + 0.1)
			for button in app.layer_buttons.values():
				check(button.get_global_rect().end.x <= size.x + 0.1 and button.get_global_rect().end.y <= size.y + 0.1, "visible layer control bounds")
	app.free()
	viewport.free()
	session.dispose()
