extends TestCase
## The undercover agent: a beacon on the parked aircraft that keeps it on the task force's picture for a while.

var _sess: Session


class FixedRng extends PyRandom:
	var v := 0.5

	func _init(v_ := 0.5) -> void:
		v = v_

	func random() -> float:
		return v


func after_each() -> void:
	Undercover.ENABLED = true
	if _sess != null:
		_sess.dispose()
		_sess = null
	World.use_map(0)


func _session(opts := {}) -> Session:
	var o := {"seed": 11, "mode": Roles.SOLO, "map_seed": MapCity.SEED, "location": "HAR", "humans": {Roles.UNDERCOVER: "Ray"}}
	o.merge(opts, true)
	_sess = Session.new(o)
	_sess.update(1.0 / 30)
	return _sess


func test_a_plant_needs_the_aircraft_parked_and_the_odds_fall_with_a_spotter() -> void:
	var s := _session()
	var u: Undercover = s.undercover
	check_eq(u.why_not(), "", "parked at a strip: it can be tried")
	check_eq(u.odds(), Undercover.BASE_ODDS, "the base odds")
	s.spotters.append(Session.Spotter.new(s.location))
	check_eq(u.odds(), Undercover.BASE_ODDS - Undercover.SPOTTER_PENALTY, "a spotter on the strip makes it harder")
	s.phase = "flying"
	check(u.why_not().contains("on the ground"), "in the air: %s" % u.why_not())
	check_eq(u.odds(), 0.0, "and no odds")
	Undercover.ENABLED = false
	check(u.why_not().contains("no agent"), "off when the switch is")


func test_a_good_plant_puts_a_beacon_on_and_it_cannot_be_doubled() -> void:
	var s := _session()
	var u: Undercover = s.undercover
	u.rng = FixedRng.new(0.0)
	check_eq(u.plant(), "", "planted")
	check(u.beacon_live(), "the beacon is live")
	check_eq(s.police.beacon_until, s.time + Undercover.BEACON_S, "for its time")
	check_eq(u.beacons, 1, "counted")
	check(u.plant().contains("already"), "not twice: %s" % u.plant())
	s.time += Undercover.BEACON_S + 1.0
	check(not u.beacon_live(), "and it runs out")


func test_a_failed_plant_burns_the_agent_and_two_blow_the_cover() -> void:
	var s := _session()
	var u: Undercover = s.undercover
	u.rng = FixedRng.new(0.99)
	check_eq(u.plant(), "", "tried")
	check(not u.beacon_live(), "no beacon")
	check_eq(u.cover, 100.0 - Undercover.COVER_LOSS, "half the cover gone")
	check_eq(u.burned, 1, "counted")
	check(s.messages.any(func(m): return str(m[1]).contains("stranger was seen")), "the crew is told")
	check(u.plant().contains("lying low"), "and the agent must lie low: %s" % u.plant())
	s.time += Undercover.COOLDOWN_S + 1.0
	u.update(0.0)
	check_eq(u.plant(), "", "then tries again")
	check_eq(u.cover, 0.0, "and is blown")
	check(u.busy_until - s.time > Undercover.COOLDOWN_S, "for longer")
	u.cover = 0.0
	s.time += 500.0
	u.update(500.0)
	check(u.cover > 10.0 and u.cover < 20.0, "cover comes back slowly: %.1f" % u.cover)


func test_the_runners_bug_sweep_may_find_the_beacon() -> void:
	var s := _session()
	var u: Undercover = s.undercover
	s.upgrades["runner"]["bug_sweep"] = true
	u.rng = FixedRng.new(0.0)  # a good plant, and the sweep's roll is under 0.5 too
	check_eq(u.plant(), "", "tried")
	check(not u.beacon_live(), "found at once: no beacon")
	check_eq(u.found, 1, "counted")
	check(s.messages.any(func(m): return str(m[1]).contains("bug sweep finds a beacon")), "the runner is told")


func test_a_live_beacon_keeps_the_aircraft_on_the_picture_outside_radar() -> void:
	var s := _session()
	var u: Undercover = s.undercover
	u.rng = FixedRng.new(0.0)
	check_eq(u.plant(), "", "planted while parked")
	s.spawn_airborne(-World.HALF + 2000.0, -World.HALF + 2000.0, 45.0, 600.0, 90.0)  # a corner of the map no radar reaches
	for i in 120:
		s.update(0.5)
	var tr = s.police.sensors.tracks.get("runner")
	check(tr != null, "the picture has the aircraft")
	if tr != null:
		check_eq(tr.source, "BCN", "from the beacon")
		check(PyMath.hypot(tr.x - s.state.x, tr.y - s.state.y) < 150.0, "within a hundred metres or so")
	# without a beacon, nothing carries it out there
	var t := _session({"seed": 12})
	t.spawn_airborne(-World.HALF + 2000.0, -World.HALF + 2000.0, 45.0, 600.0, 90.0)
	for i in 120:
		t.update(0.5)
	var tr2 = t.police.sensors.tracks.get("runner")
	check(tr2 == null or tr2.source != "BCN", "no beacon, no beacon track")


func test_the_command_the_seat_and_the_snapshot() -> void:
	var s := _session({"humans": {}})
	check(not s.undercover.held, "no one at the desk")
	s.seat_driver(Roles.UNDERCOVER, true)
	check(s.undercover.held, "a player sits down")
	s.undercover.rng = FixedRng.new(0.0)
	check(s.command(Roles.UNDERCOVER, "plant_beacon", {})[0], "the command plants")
	check(not s.command(Roles.CONTROLLER, "plant_beacon", {})[0], "the controller cannot")
	var snap := Snapshot.build(s, Roles.UNDERCOVER)
	check(snap.has("undercover"), "the agent's snapshot")
	check(int(snap.undercover.beacon_s) > 0 and snap.undercover.at == "HAR", "with the beacon and where the aircraft is")
	check(not Snapshot.build(s, Roles.CONTROLLER).has("undercover"), "the controller does not get it")


func test_the_desk_draws_and_p_plants() -> void:
	var s := _session()
	s.undercover.rng = FixedRng.new(0.0)
	var link := LocalLink.new(s, Roles.UNDERCOVER)
	var app := StationApp.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	app.setup(link, Roles.UNDERCOVER, s.world)
	app._process(0.016)
	check_eq(app.title.text, "UNDERCOVER", "the desk's title")
	check(app.info.text.contains("parked at"), "it says where the aircraft is: %s" % app.info.text)
	app._key("p")
	check(s.undercover.beacon_live(), "P plants it")
	app._process(0.016)
	check(app.info.text.contains("BEACON IS LIVE"), "and the desk says so")
	app.queue_free()
