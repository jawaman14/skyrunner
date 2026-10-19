extends TestCase
## LocalLink and NetClient keep the one contract the desks rely on (StationLink), and the seat descriptions
## that the room, the seat picker and the menu show come from a single table (Roles.ABOUT).


func test_both_links_keep_the_contract() -> void:
	var sess := Session.new({"seed": 3, "features": Session.SANDBOX_FEATURES})
	var local := LocalLink.new(sess, Roles.PILOT)
	check_eq(StationLink.missing(local), [], "LocalLink lacks nothing")
	var net := NetClient.new()
	check_eq(StationLink.missing(net), [], "NetClient lacks nothing")
	net.free()
	sess.dispose()


func test_the_check_itself_notices_a_missing_piece() -> void:
	var plain := RefCounted.new()
	var gaps := StationLink.missing(plain)
	check(gaps.has("send_command()") and gaps.has("snapshot()") and gaps.has("role"), "a bare object lacks the methods and properties: %s" % [gaps])


func test_every_seat_has_one_description() -> void:
	for r in Roles.ALL:
		check(Roles.ABOUT.has(r) and str(Roles.ABOUT[r]) != "", "%s has a description" % r)
	var room := Room.new(Roles.COOP, "Host", Roles.PILOT)
	for s in room.seats():
		check_eq(s.about, Roles.ABOUT[s.role], "the room shows the shared text for %s" % s.role)

	# The desk chart keeps click coordinates correct at each of its three scales.
	var chart := StationMap.new()
	chart.size = Vector2(900, 600)
	Engine.get_main_loop().root.add_child(chart)
	chart.set_process(false)
	var anchor := Vector2(520, 260)
	var before := chart.m2w(anchor)
	chart.set_zoom(1, anchor)
	check(chart.zoom_level == 1 and chart.m2w(anchor).distance_to(before) < 0.1, "zoom keeps the point under the cursor")
	var target := Vector2(1500, -2000)
	for level in 3:
		chart.set_zoom(level)
		check(chart.m2w(chart.w2m(target.x, target.y)).distance_to(target) < 0.1, "map clicks round-trip at scale %d" % level)
	chart.set_zoom(0)
	check_eq(chart.view_center, Vector2.ZERO, "island view resets pan")
	var clicks := []
	chart.clicked.connect(func(button, xy): clicks.append([button, xy]))
	var wheel := InputEventMouseButton.new()
	wheel.position = chart.size / 2.0
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	chart._gui_input(wheel)
	check_eq(chart.zoom_level, 1, "wheel zooms the chart")
	check(clicks.is_empty(), "wheel never issues a destination or order")
	chart.free()
