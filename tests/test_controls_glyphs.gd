extends TestCase
## Controller Icons (addons/controller_icons) behind ControlsGlyphs: a pad glyph for every control that has a pad binding,
## and a headless run (no display server, so no key-cap glyphs) builds the menus without them and without errors.


func test_the_add_on_is_running_as_an_autoload() -> void:
	check(ControlsGlyphs.available(), "the ControllerIcons autoload is there")


func test_every_control_with_a_pad_binding_has_a_pad_glyph() -> void:
	ControlsConfig.ensure()
	var with_pad := 0
	for n in ControlsConfig.names():
		var spec: Dictionary = ControlsConfig.HELD.get(n, ControlsConfig.PRESSED.get(n, {}))
		if spec.has("buttons") or spec.has("axes"):
			check(ControlsGlyphs.resolved(n, "pad") != null, "%s has a pad glyph" % n)
			with_pad += 1
	check(with_pad >= 5, "several controls have a pad binding (%d)" % with_pad)


func test_binding_text_omits_the_device_already_shown_as_a_glyph() -> void:
	ControlsConfig.ensure()
	var pad_text := ControlsGlyphs.other_device_bindings("throttle_up", "pad")
	var keyboard_text := ControlsGlyphs.other_device_bindings("throttle_up", "keyboard")
	var helper := ControlsConfig.helper()
	var key_labels: Array[String] = []
	for ev in InputMap.action_get_events(ControlsConfig.action("throttle_up")):
		if ev is InputEventKey:
			key_labels.append(helper.get_label_for_input(ev))
	check(key_labels.all(func(label): return pad_text.contains(label)), "pad glyph leaves the keyboard bindings readable")
	check(not pad_text.contains("Trigger"), "pad glyph does not repeat its trigger binding")
	check(keyboard_text.contains("Trigger"), "keyboard glyph leaves the pad binding readable")
	check(key_labels.all(func(label): return not keyboard_text.contains(label)), "keyboard glyph does not repeat its key bindings")
	var no_pad_binding := ControlsGlyphs.other_device_bindings("throttle_cut", "pad")
	check(no_pad_binding == ControlsConfig.describe("throttle_cut"), "controls without a pad glyph keep all binding text")


func test_without_a_display_server_there_are_no_key_cap_glyphs() -> void:
	check(not ControlsGlyphs.drawable(), "a headless run cannot draw them")
	check(ControlsGlyphs.texture("brake") == null, "so a control gives no glyph texture")
	check(ControlsGlyphs.resolved("brake", "keyboard") == null, "nor a keyboard glyph")
	check(ControlsGlyphs.texture("not_a_control") == null, "an unknown control never does")


func test_the_controls_menu_builds_without_glyphs_when_there_is_nothing_to_draw() -> void:
	var menu := ControlsMenu.new()
	Engine.get_main_loop().root.add_child(menu)
	check(menu.key_rows.size() == ControlsConfig.names().size(), "a row for every control (%d)" % menu.key_rows.size())
	var glyphs := menu.find_children("*", "TextureRect", true, false).filter(func(t): return t.texture is ControllerIconTexture)
	check(glyphs.is_empty(), "and no glyph rectangles headless")
	menu.free()
