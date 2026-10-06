extends TestCase

func test_fuel_preview_is_read_only_and_tracks_planned_balance() -> void:
	var s := Session.new({"seed": 4, "location": "HAR"})
	var menu := LoadMenu.new()
	Engine.get_main_loop().root.add_child(menu)
	menu.setup(s)
	menu.open()
	var fuel := s.fm.fuel_lb()
	var planned := s.loadout.fuel_lb
	var funds: int = s.money
	menu._preview_fuel(100)
	check_near(s.loadout.fuel_lb, planned, 0.001, "dragging does not change simulation loadout")
	check_near(s.fm.fuel_lb(), fuel, 0.001, "dragging does not change aircraft fuel")
	check_eq(s.money, funds, "preview does not charge")
	check("PREVIEW:" in menu.fuel_lbl.text and "Release to apply" in menu.fuel_lbl.text, "preview is identified")
	menu.close()
	check_near(s.loadout.fuel_lb, planned, 0.001, "closing preview leaves loadout intact")
	menu.free()
	s.dispose()


func test_load_menu_reports_rejected_actions_and_partial_supply() -> void:
	var s := Session.new({"seed": 4, "location": "HAR"})
	var menu := LoadMenu.new()
	Engine.get_main_loop().root.add_child(menu)
	menu.setup(s)
	menu.open()
	var fuel := s.fm.fuel_lb()
	s.phase = "enroute"
	menu._set_fuel(100)
	check("Not completed:" in menu.feedback.text and "ground" in menu.feedback.text, "airborne refuel reason retained")
	check_near(s.fm.fuel_lb(), fuel, 0.001, "rejection preserves fuel")
	menu._picked(-123, 0)
	check("Loading happens" in menu.feedback.text, "placement rejection explained")
	s.phase = "parked"
	menu._route_fuel()
	check("Take a job first" in menu.feedback.text, "route requirement explained")
	menu.key("f")
	check("No ferry tank" in menu.feedback.text, "missing equipment explained")
	# A finite private cache is free and cannot satisfy a larger fill.
	s.location = "FRM"
	s.fuel_caches["FRM"] = 5.0
	s.set_fuel(10)
	menu._preview_fuel(100)
	check("$0" in menu.fuel_lbl.text and "cannot reach" in menu.fuel_lbl.text, "cache price and limit previewed")
	menu._set_fuel(100)
	check("Supply limited" in menu.feedback.text, "partial fill acknowledged")
	check_near(s.fm.fuel_lb(), 15, 0.01, "only available fuel applied")
	menu.free()
	s.dispose()
