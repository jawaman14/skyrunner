extends TestCase
## The keyboard is all-or-nothing, so the mapper ramps the throttle and brake, softens the rudder on
## the ground, and (with the assist on) levels the wings and holds the pitch when no key is down.

const DT := 1.0 / 30.0


func after_each() -> void:
	World.use_map(0)  # the suite's default island, for whatever runs next


func _state(over := {}) -> FlightModel.FlightState:
	var st := FlightModel.FlightState.new()
	st.valid = true
	st.on_ground = false
	for k in over:
		st.set(k, over[k])
	return st


func _run(m: ControlMapper, seconds: float, held := [], pressed := [], st: FlightModel.FlightState = null) -> FlightModel.Controls:
	var c: FlightModel.Controls = null
	for i in int(seconds / DT):
		c = m.update(DT, T.inp(held, pressed if i == 0 else []), st)
	return c


func test_z_and_x_ramp_instead_of_jumping() -> void:
	var m := ControlMapper.new()
	m.reset(0.0)
	var c := _run(m, DT, [], ["throttle_full"])
	check(c.throttle > 0.0 and c.throttle < 0.1, "Z starts a ramp: %.3f" % c.throttle)
	c = _run(m, 0.5)
	check_between(c.throttle, 0.25, 0.5, "half a second in")
	c = _run(m, 1.5)
	check_near(c.throttle, 1.0, 0.001, "and reaches full")
	c = _run(m, DT, [], ["throttle_cut"])
	check(c.throttle > 0.9, "X does not chop at once: %.3f" % c.throttle)
	c = _run(m, 1.0)
	check_near(c.throttle, 0.0, 0.001, "X ramps to idle inside a second")


func test_the_same_key_twice_is_the_instant_chop() -> void:
	var m := ControlMapper.new()
	m.reset(0.8)
	_run(m, DT, [], ["throttle_cut"])
	var c := _run(m, DT, [], ["throttle_cut"])
	check_near(c.throttle, 0.0, 0.001, "X X cuts at once")
	m.reset(0.2)
	_run(m, DT, [], ["throttle_full"])
	c = _run(m, DT, [], ["throttle_full"])
	check_near(c.throttle, 1.0, 0.001, "Z Z is the go-around slam")


func test_a_tap_of_the_lever_keys_is_a_few_percent_and_cancels_a_ramp() -> void:
	var m := ControlMapper.new()
	m.reset(0.5)
	var c := _run(m, 0.1, ["throttle_up"])
	check_between(c.throttle, 0.52, 0.56, "a 0.1 s tap: %.3f" % c.throttle)
	m.reset(0.0)
	_run(m, DT, [], ["throttle_full"])
	_run(m, 0.3)
	c = _run(m, 0.1, ["throttle_down"])
	check(m.throttle_target == null, "the lever by hand cancels the ramp")
	c = _run(m, 1.0)
	check(c.throttle < 0.5, "and it stays where the hand left it, not on to full: %.3f" % c.throttle)


func test_the_brake_comes_on_over_a_moment_and_lets_go_fast() -> void:
	var m := ControlMapper.new()
	m.reset(0.0)
	var c := _run(m, DT, ["brake"])
	check(c.brake < 0.1, "not a lock-up: %.3f" % c.brake)
	c = _run(m, 1.0, ["brake"])
	check_near(c.brake, 1.0, 0.001, "full after a second")
	c = _run(m, 0.3)
	check_near(c.brake, 0.0, 0.001, "released")


func test_brake_key_is_limited_at_speed_on_the_ground() -> void:
	var m := ControlMapper.new()
	m.reset(0.0)
	var fast := _state({"on_ground": true, "gs_kts": 50.0})
	var c := _run(m, 2.0, ["brake"], [], fast)
	check_near(c.brake, ControlMapper.BRAKE_FAST_AUTH, 0.01, "half the brake at 50 kt")
	m.reset(0.0)
	c = _run(m, 2.0, ["brake"], [], _state({"on_ground": true, "gs_kts": 15.0}))
	check_near(c.brake, 1.0, 0.001, "all of it when slow")


func test_the_rudder_key_softens_with_ground_speed() -> void:
	var m := ControlMapper.new()
	m.reset(0.0)
	var c := _run(m, 1.0, ["yaw_right"], [], _state({"on_ground": true, "gs_kts": 4.0}))
	check_near(c.rudder, 1.0, 0.001, "full pedal when taxiing")
	m = ControlMapper.new()
	c = _run(m, 1.0, ["yaw_right"], [], _state({"on_ground": true, "gs_kts": 40.0}))
	check_near(c.rudder, ControlMapper.RUDDER_KEY_FAST_AUTH, 0.001, "a nudge on the rollout")
	m = ControlMapper.new()
	c = _run(m, 1.0, ["yaw_right"], [], _state({"on_ground": false, "gs_kts": 60.0}))
	check_near(c.rudder, 1.0, 0.001, "airborne is untouched")
	m = ControlMapper.new()
	c = _run(m, 1.0, ["yaw_right"])
	check_near(c.rudder, 1.0, 0.001, "and with no state (bots, tests) it's as before")


func test_assist_levels_the_wings_and_holds_pitch() -> void:
	var m := ControlMapper.new()
	m.assist = true
	# banked right and pitched 4 deg down of where it was: hands off
	var c := _run(m, DT, [], [], _state({"roll": 10.0, "pitch": 3.0}))  # captures pitch 3
	check(c.aileron < -0.3, "banked right: roll left, got %.2f" % c.aileron)
	c = _run(m, DT, [], [], _state({"roll": -10.0, "pitch": 3.0}))
	check(c.aileron > 0.3, "banked left: roll right, got %.2f" % c.aileron)
	c = _run(m, DT, [], [], _state({"roll": 0.0, "pitch": -1.0}))  # nose 4 below the held pitch
	check(c.elevator < -0.2, "nose low: pull (negative is up), got %.2f" % c.elevator)
	c = _run(m, DT, [], [], _state({"roll": 0.0, "pitch": 3.0, "q_dps": 8.0}))
	check(c.elevator > 0.3, "pitching up fast: damp it (clamped at the assist limit), got %.2f" % c.elevator)
	check(absf(m.controls.aileron) < 0.01 and absf(m.controls.elevator) < 0.01, "the pilot's own state is untouched")


func test_assist_gives_way_to_keys_a_stick_the_ground_and_being_off() -> void:
	var m := ControlMapper.new()
	m.assist = true
	var c := _run(m, 0.5, ["roll_right"], [], _state({"roll": 10.0}))
	check(c.aileron > 0.2, "a roll key beats the leveller: %.2f" % c.aileron)
	c = _run(m, DT, [], [], _state({"roll": 10.0, "on_ground": true}))
	check(absf(c.aileron) < 0.3 and c.aileron > -0.1, "no levelling on the ground: %.2f" % c.aileron)
	var inp := ControlMapper.InputFrame.new()
	inp.stick = [0.0, 0.0]
	c = m.update(DT, inp, _state({"roll": 20.0}))
	check_near(c.aileron, 0.0, 0.001, "a stick or yoke is proportional and unassisted")
	var off := ControlMapper.new()
	c = _run(off, DT, [], [], _state({"roll": 20.0}))
	check_near(c.aileron, 0.0, 0.001, "assist off: nothing added")


func test_assist_makes_the_aircraft_fly_hands_off() -> void:
	World.use_map(MapCity.SEED)
	var s := Session.new({"seed": 1, "location": "HAR"})
	s.keyboard_assist = true
	var af := World.airfield("HAR")
	s.spawn_airborne(af.x, af.y, af.heading, 600.0, 65.0)
	for i in 40 * 30:
		var inp := ControlMapper.InputFrame.new()
		inp.throttle_axis = 0.45
		s.update(DT, inp, null)
	check(absf(s.state.roll) < 3.0, "wings near level after 40 s hands-off: %.1f" % s.state.roll)
	check(absf(s.state.vs_fpm) < 600.0 and s.state.pitch > -5.0 and s.state.pitch < 8.0, "no spiral or dive: pitch %.1f vs %.0f" % [s.state.pitch, s.state.vs_fpm])
	s.dispose()


func test_touchdown_and_rollout_rules() -> void:
	World.use_map(MapCity.SEED)
	var s := Session.new({"seed": 1, "location": "HAR"})
	var af := World.airfield("FRM")
	# the graded shoulder beside a strip is not "rough ground"; beyond it is
	var side_x: float = af.x + af.uy * (af.width / 2.0 + 15.0)
	var side_y: float = af.y - af.ux * (af.width / 2.0 + 15.0)
	check(s._on_shoulder(side_x, side_y), "15 m beside a grass strip is graded ground")
	var far_x: float = af.x + af.uy * (af.width / 2.0 + 90.0)
	var far_y: float = af.y - af.ux * (af.width / 2.0 + 90.0)
	check(not s._on_shoulder(far_x, far_y), "90 m beside it is not")
	check(Session.WINGTIP_STRIKE_ROLL_DEG > 15.0, "a Cessna's wingtip clears more than 15 degrees of bank")
	check(Session.GEAR_MARGIN > 1.0, "the gear holds a little past its rated sink rate")
	s.dispose()
