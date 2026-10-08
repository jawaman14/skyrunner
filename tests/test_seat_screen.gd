extends TestCase

class Link extends NetClient:
	var sent: Array = []
	var connected := true
	func alive() -> bool: return connected
	func claim(value: String) -> void: sent.append(["game", value])
	func room_claim(value: String) -> void: sent.append(["room", value])
	func close() -> void: connected = false

var _nodes: Array = []
var _palette := ""

func before_each() -> void:
	_palette = UIStyle.palette

func after_each() -> void:
	for node in _nodes:
		if is_instance_valid(node): node.free()
	_nodes.clear()
	UIStyle.set_palette(_palette)

func _link() -> Link:
	var link := Link.new()
	_nodes.append(link)
	for role in Roles.ALL:
		link.seats.append({"role": role, "side": Roles.side(role), "who": "ai", "name": ""})
	return link

func _picker(link: Link) -> SeatPicker:
	var picker := SeatPicker.new()
	Engine.get_main_loop().root.add_child(picker)
	_nodes.append(picker)
	picker.setup(link)
	return picker

func test_refresh_preserves_role_instead_of_row_number() -> void:
	var link := _link()
	var picker := _picker(link)
	picker.table.select(picker._keys.find(Roles.COPILOT))
	link.seats.reverse()
	picker._process(0)
	check_eq(picker._keys[picker.table.selected_row()], Roles.COPILOT)
	picker.key("enter")
	check_eq(link.sent, [["game", Roles.COPILOT]])
	picker.key("enter")
	picker.claim_selected()
	check_eq(link.sent.size(), 1, "repeat activation waits for the host")
	check(picker.status.text.contains("Waiting"))
	link.claim_error = "Seat already taken."
	picker._process(0)
	check_eq(picker.status.text, "Seat already taken.")
	picker.key("enter")
	check_eq(link.sent.size(), 2, "explicit retry after a refusal is possible")

func test_closed_picker_ignores_delayed_claim_and_never_resends() -> void:
	var link := _link()
	var picker := _picker(link)
	var outcomes := []
	picker.seated.connect(func(role): outcomes.append(role))
	var cancelled := []
	picker.cancelled.connect(func(): cancelled.append(true))
	picker.key("enter")
	picker.screen._pending_at -= 16000
	picker._process(0)
	check(picker.status.text.contains("unknown"))
	picker.key("enter")
	check_eq(link.sent.size(), 1, "no automatic or duplicate resend")
	picker.key("leave")
	picker.key("leave")
	check_eq(cancelled.size(), 1)
	check(not link.connected)
	link.role_changed.emit(Roles.PILOT)
	check(outcomes.is_empty(), "closed view cannot enter a late-confirmed seat")

func test_stale_taken_seat_and_disconnect_do_not_send() -> void:
	var link := _link()
	var picker := _picker(link)
	picker.table.select(picker._keys.find(Roles.PILOT))
	for seat in link.seats:
		if seat.role == Roles.PILOT: seat.who = "human"
	picker.claim_selected()
	check(link.sent.is_empty())
	check(picker.status.text.contains("unavailable"))
	link.connected = false
	picker.table.select(picker._keys.find(Roles.COPILOT))
	picker.claim_selected()
	check(link.sent.is_empty())
	check(picker.status.text.contains("Disconnected"))

func test_waiting_room_claims_use_the_waiting_protocol() -> void:
	var link := _link()
	link.room_state = {"mode": "coop", "players": [], "seats": []}
	var screen := RoomScreen.new()
	Engine.get_main_loop().root.add_child(screen)
	_nodes.append(screen)
	screen.setup(null, link)
	screen._take(Roles.COPILOT)
	screen._take(Roles.COPILOT)
	check_eq(link.sent, [["room", Roles.COPILOT]])

func _press(viewport: Viewport, event: InputEvent) -> void:
	event.pressed = true
	viewport.push_input(event)
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event)

func test_real_keyboard_controller_and_layout_in_both_palettes() -> void:
	var tree: SceneTree = Engine.get_main_loop()
	for dimensions in [Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		var viewport := SubViewport.new()
		viewport.size = dimensions
		tree.root.add_child(viewport)
		var link := _link()
		for i in 16:
			link.players.append({"name": "Player %d" % i, "role": Roles.COPILOT})
		var picker := SeatPicker.new()
		viewport.add_child(picker)
		picker.setup(link)
		for palette in ["neon", "safe"]:
			UIStyle.set_palette(palette)
			picker._process(0)
			await tree.process_frame
			await tree.process_frame
			check(picker.table.size.y > 100, "roster keeps a scrollable height")
			check(picker.table.get_global_rect().end.x <= dimensions.x, "roster fits width")
			check(picker.chat.get_global_rect().end.x <= dimensions.x, "chat fits width")
			check(picker.chat.get_global_rect().end.y <= dimensions.y, "chat fits height")
			check_eq(picker.screen.title_lbl.get_theme_color("font_color"), UIStyle.ACCENT, "open screen follows palette")
			picker.table.grab_focus()
			picker.table.select(picker._keys.find(Roles.PILOT))
			var down := InputEventJoypadButton.new()
			down.button_index = JOY_BUTTON_DPAD_DOWN
			_press(viewport, down)
			check_eq(picker._keys[picker.table.selected_row()], Roles.COPILOT, "controller selects next role")
			var enter := InputEventKey.new()
			enter.keycode = KEY_ENTER
			_press(viewport, enter)
			check_eq(link.sent[-1], ["game", Roles.COPILOT], "real keyboard activation")
			var count := link.sent.size()
			enter.echo = true
			_press(viewport, enter)
			check_eq(link.sent.size(), count, "held key cannot duplicate a pending claim")
			link.claim_error = "Refused for test"
			picker._process(0)
			var accept := InputEventJoypadButton.new()
			accept.button_index = JOY_BUTTON_A
			_press(viewport, accept)
			check_eq(link.sent.size(), count + 1, "controller activation reaches the shared claim path")
			link.claim_error = "Refused for mouse test"
			picker._process(0)
			var row := picker.table.selected_row()
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.double_click = true
			click.position = picker.table.global_position + picker.table.get_item_area_rect(picker.table._items[row]).get_center()
			_press(viewport, click)
			check_eq(link.sent.size(), count + 2, "mouse activation reaches the same claim path")
			link.claim_error = "Refused after mouse test"
			picker._process(0)
		viewport.free()
