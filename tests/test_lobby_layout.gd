extends TestCase
## Exercise real container layout and keyboard focus at the screenshot sizes.


func test_lobby_footer_and_fields_fit_the_viewport() -> void:
	var tree: SceneTree = Engine.get_main_loop()
	for dimensions in [Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		var viewport := SubViewport.new()
		viewport.size = dimensions
		tree.root.add_child(viewport)
		var lobby := Lobby.new()
		viewport.add_child(lobby)
		for frame in 6:
			await tree.process_frame
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		check(bounds.encloses(lobby.hints.get_global_rect()), "%s: shortcut hints stay on screen" % dimensions)
		check(bounds.encloses(lobby.scroll.get_global_rect()), "%s: scroll area fits the screen" % dimensions)
		if dimensions.y < 800:
			check(lobby.scroll.get_v_scroll_bar().max_value > lobby.scroll.size.y, "%s: tall card can scroll" % dimensions)
		for field in [lobby.mode_ob, lobby.name_le, lobby.go_btn]:
			field.grab_focus()
			for frame in 4:
				await tree.process_frame
			check(lobby.scroll.get_global_rect().encloses(field.get_global_rect()), "%s: focused %s is fully visible" % [dimensions, field.get_class()])
		viewport.free()
