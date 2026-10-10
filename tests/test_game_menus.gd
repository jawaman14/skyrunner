extends TestCase
## Every ground menu (GameMenu) builds against a live session, opens, takes every key the pilot app can
## send it without a script error, and closes; plus the collectors' terms cycling through the session.

const MENUS := [
	"res://scripts/ui/hangar_menu.gd", "res://scripts/ui/hq_menu.gd", "res://scripts/ui/job_menu.gd", "res://scripts/ui/load_menu.gd",
	"res://scripts/ui/phone_menu.gd", "res://scripts/ui/race_menu.gd", "res://scripts/ui/rackets_menu.gd", "res://scripts/ui/taxi_menu.gd",
]
const KEYS := ["up", "down", "left", "right", "enter", "a", "f", "+", "-", "esc"]

var _sess: Session


func after_each() -> void:
	if _sess != null:
		_sess.dispose()
		_sess = null
	World.use_map(0)


func _session() -> Session:
	var o := {"seed": 21, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES + ["hq"], "payroll": true,
		"court": true, "ground_war": true, "trade": true, "logistics": true, "family": true, "island": true, "agency": true,
		"chronicle": true, "rackets": true, "renown": true, "races": true, "dealership": true}
	_sess = Session.new(o)
	_sess.police.frozen = true
	_sess.money = 50000
	_sess.update(1.0 / 30)
	return _sess


func test_every_menu_builds_opens_takes_every_key_and_closes() -> void:
	var s := _session()
	var root: Node = Engine.get_main_loop().root
	for path in MENUS:
		var m: GameMenu = load(path).new()
		root.add_child(m)
		m.setup(s)
		var closed := [0]
		m.closed.connect(func(): closed[0] += 1)
		check(not m.visible, "%s starts hidden" % path.get_file())
		m.open()
		check(m.visible, "%s opens" % path.get_file())
		check(m.title.text != "", "%s has a title" % path.get_file())
		for k in KEYS:
			if k == "esc":
				continue
			m.key(k)
		m.refresh()
		m.close()
		check(closed[0] >= 1, "%s says it closed (some close themselves on ENTER, once a call or a race is set up)" % path.get_file())
		check(not m.visible, "%s is hidden again" % path.get_file())
		m.queue_free()


func test_race_refresh_preserves_course_identity() -> void:
	var s := _session()
	var m := RaceMenu.new()
	Engine.get_main_loop().root.add_child(m)
	m.setup(s)
	m.open()
	check(m.rows.size() > 1, "HAR has multiple courses")
	# Simulate a previous snapshot's ordering before the next refresh.
	m.rows.reverse()
	m.list.select_near(0)
	var selected_id := str(m.rows[0].id)
	m.refresh()
	check_eq(str(m.rows[m.list.selected_row()].id), selected_id, "selection follows the course ID rather than its old row")
	m.queue_free()


func test_race_refusal_remains_visible_after_refresh() -> void:
	var s := _session()
	s.money = 0
	var m := RaceMenu.new()
	Engine.get_main_loop().root.add_child(m)
	m.setup(s)
	m.open()
	check(not m.rows.is_empty(), "HAR has races to review")
	m.key("enter")
	check(m.visible, "refused entry leaves the menu open")
	check(m.feedback.visible, "refusal has persistent panel feedback")
	check(m.feedback.text.begins_with("Not completed:"), "refusal is not presented as success")
	var message := m.feedback.text
	m.refresh()
	check_eq(m.feedback.text, message, "refresh retains the refusal")
	check_eq(s.money, 0, "refused entry charges nothing")
	m.close()
	m.open()
	check(not m.feedback.visible, "reopening clears previous feedback")
	m.queue_free()


func test_ground_menu_shell_has_a_clear_exit_and_initial_focus() -> void:
	var s := _session()
	var m := HangarMenu.new()
	Engine.get_main_loop().root.add_child(m)
	m.setup(s)
	check(m.close_button != null, "shared shell has an explicit close control")
	check_eq(m.close_button.text, "Close  [Esc]", "close control teaches the keyboard path")
	check(m.close_button.custom_minimum_size.y >= UIStyle.TOUCH_MIN, "close target meets shared minimum height")
	m.open()
	check(m.list.has_focus(), "opening a menu focuses its task list")
	m.close_button.emit_signal("pressed")
	check(not m.visible, "the visible close control closes the menu")
	m.queue_free()


func test_enter_in_the_collectors_cycles_a_markets_terms() -> void:
	var s := _session()
	var root: Node = Engine.get_main_loop().root
	var m := RacketsMenu.new()
	root.add_child(m)
	m.setup(s)
	m.open()
	if m.markets.is_empty():
		check(true, "no markets to collect from on this map (nothing to cycle)")
		m.queue_free()
		return
	var market: String = m.markets[0].market
	var before: String = s.rackets.policy[market]
	m.key("enter")
	check_eq(s.rackets.policy[market], before, "policy review does not mutate")
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	m.confirmation.key("right")
	m.confirmation.key("enter")
	var after: String = s.rackets.policy[market]
	check(before != after, "ENTER changes the terms: %s -> %s" % [before, after])
	check_eq(after, Rackets.POLICIES[(Rackets.POLICIES.find(before) + 1) % Rackets.POLICIES.size()], "to the next in the cycle")
	check_eq(m.markets[0].policy, after, "and the table shows it")
	m.queue_free()


func test_menu_real_controller_navigation_cancel_focus_and_palette() -> void:
	var s := _session()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 768)
	Engine.get_main_loop().root.add_child(viewport)
	var opener := Button.new()
	viewport.add_child(opener)
	opener.grab_focus()
	var m := RacketsMenu.new()
	viewport.add_child(m)
	m.setup(s)
	m.open()
	for i in 3:
		await Engine.get_main_loop().process_frame
	var before := m.list.selected_row()
	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	viewport.push_input(down)
	check_eq(m.list.selected_row(), before + 1, "one controller press moves one row")
	var accept := InputEventKey.new()
	accept.keycode = KEY_ENTER
	accept.pressed = true
	viewport.push_input(accept)
	check(m.confirmation != null and m.confirmation.visible, "Enter opens a review rather than closing the menu")
	var money := s.money
	for i in 3:
		await Engine.get_main_loop().process_frame
	viewport.push_input(accept)
	check_eq(s.money, money, "default Cancel changes nothing")
	check(m.list.has_focus(), "review returns focus to the list")
	var palette := UIStyle.palette
	UIStyle.set_palette("safe")
	await Engine.get_main_loop().process_frame
	check_eq(m.theme, UIStyle.theme(), "open menu follows palette changes")
	UIStyle.set_palette(palette)
	var cancel := InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	cancel.pressed = true
	viewport.push_input(cancel)
	check(not m.visible, "controller Back exits")
	check(opener.has_focus(), "exit returns focus to the invoking control")
	viewport.queue_free()


func test_dealer_retains_serial_after_other_vehicle_removed() -> void:
	var s := _session()
	s.money = 200000
	for spec in Dealership.CATALOGUE.slice(5, 8):
		s.command(Roles.PILOT, "buy_vehicle", {"id": spec.id})
	var m := DealerMenu.new().setup(s)
	m.open()
	check(m.my_rows.size() >= 3)
	if m.my_rows.size() < 3:
		m.free()
		return
	m.mine.select(2)
	var serial: int = m.my_rows[2].serial
	var removed: int = m.my_rows[0].serial
	s.command(Roles.PILOT, "sell_vehicle", {"serial": removed})
	m.refresh()
	check_eq(m.my_rows[m.mine.selected_row()].serial, serial, "selection follows the vehicle, not its old row")
	m.mine.row_activated.emit(m.mine.selected_row())
	check_eq(m.focus, 1, "owned-table activation targets owned vehicles")
	m.free()

func test_hangar_spotter_hire_is_cancel_first_and_charges_once() -> void:
	var s := _session()
	s.money = 5000
	var m := HangarMenu.new()
	Engine.get_main_loop().root.add_child(m)
	m.setup(s)
	m.open()
	var row := -1
	for i in m.rows.size():
		if m.rows[i][0] == "spotter":
			row = i
	if row < 0:
		check(true, "no spotters in this game (nothing to hire)")
		m.queue_free()
		return
	m.list.select_near(row)
	m.key("enter")
	check_eq(s.money, 5000, "opening the review charges nothing")
	for i in 3: await Engine.get_main_loop().process_frame
	check(not m.confirmation.selected_yes, "review opens on Cancel")
	m.confirmation.key("enter")
	check_eq(s.money, 5000, "Cancel charges nothing")
	check(s.spotters.is_empty())
	m.key("enter")
	for i in 3: await Engine.get_main_loop().process_frame
	m.confirmation.key("right")
	m.confirmation.key("enter")
	check_eq(s.money, 5000 - Session.SPOTTER_FEE, "Confirm charges the fee once")
	check_eq(s.spotters.size(), 1)
	m.queue_free()
