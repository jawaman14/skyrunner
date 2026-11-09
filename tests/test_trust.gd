extends TestCase
## Trust with each crew (D-11): the five crews' standing, and the owner's table of who resents whom; only a rise spreads; off, a nudge
## moves only the crew named; Los Cuervos' and the dealers' standing saved.


func after_each() -> void:
	World.use_map(0)


func _sess() -> Session:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "trade": true,
		"logistics": true, "family": true, "agency": true, "psychedelics": true})
	s.police.frozen = true
	s.update(1.0 / 30)
	return s


func test_the_table() -> void:
	var s := _sess()
	var t: Trust = s.trade.trust
	s.family.respect = 50.0
	t.own.rival = 40.0
	t.own.dealers = 40.0
	t.nudge("family", 4.0)
	check_eq(s.family.respect, 54.0, "the Morettis up")
	check_eq(t.of("rival"), 38.0, "Los Cuervos down, by half")
	t.nudge("rival", 4.0)
	check_eq(t.of("family"), 52.0, "Los Cuervos up: the Morettis down")
	check_eq(t.of("dealers"), 38.0, "and the dealers")
	if s.agency != null and s.psych != null:
		s.psych.trust = 40.0
		var a := s.agency.trust
		t.nudge("agency", 4.0)
		check_eq(s.agency.trust, a + 4.0, "the Company up")
		check_eq(s.psych.trust, 39.0, "the Collective a little down")
	s.dispose()


func test_only_a_rise_spreads() -> void:
	var s := _sess()
	var t: Trust = s.trade.trust
	s.family.respect = 50.0
	var r := t.of("rival")
	t.nudge("family", -5.0)
	check_eq(s.family.respect, 45.0, "the Morettis down")
	check_eq(t.of("rival"), r, "no favour to Los Cuervos")
	s.dispose()


func test_a_filled_family_sale_costs_los_cuervos() -> void:
	var s := _sess()
	var r := s.trade.trust.of("rival")
	s.trade._effects("family", "marijuana", 10.0, 100)
	check(s.trade.trust.of("rival") < r, "selling to the Morettis cools Los Cuervos (%.1f -> %.1f)" % [r, s.trade.trust.of("rival")])
	s.dispose()


func test_off_only_the_named_crew() -> void:
	var saved := Switches.snapshot()
	Trust.ENABLED = false
	var s := _sess()
	var r := s.trade.trust.of("rival")
	s.trade.trust.nudge("family", 5.0)
	check_eq(s.trade.trust.of("rival"), r, "off: nothing spreads")
	s.dispose()
	Switches.restore(saved)


func test_saved() -> void:
	var s := _sess()
	s.trade.trust.own.rival = 7.0
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.trade.trust.capture()))
	s.dispose()
	var s2 := _sess()
	s2.trade.trust.restore(d)
	check_eq(s2.trade.trust.of("rival"), 7.0, "Los Cuervos' standing comes back")
	s2.trade.trust.restore({})
	check_eq(s2.trade.trust.of("rival"), Trust.START.rival, "an older save: they start wary")
	s2.dispose()


func test_the_phone_lists_the_crews() -> void:
	var s := _sess()
	var m := PhoneMenu.new()
	Engine.get_main_loop().root.add_child(m)
	m.setup(s)
	var parts: Array = m._empire_parts()
	var crews: Array = parts.filter(func(p): return p[0] == "The crews")
	check(not crews.is_empty(), "Empire has the crews")
	check(crews[0][1].any(func(r): return str(r[0]).begins_with("Los Cuervos: trust 20")), "with their trust: %s" % [crews])
	m.queue_free()
	s.dispose()
