extends TestCase
## D-12: the pilot app on a fixed 30 Hz step, the aircraft drawn between its last two steps (PilotApp.FIXED_STEP).


func after_each() -> void:
	PilotApp.FIXED_STEP = false


func _app() -> Array:
	var s := Session.new({"seed": 1, "location": "FRM"})
	var app := PilotApp.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	app.setup(s, "low")
	return [s, app]


func _done(pair: Array) -> void:
	pair[1].queue_free()
	pair[1].free()
	pair[0].dispose()


func test_the_sim_takes_only_whole_thirtieths_whatever_the_frame() -> void:
	PilotApp.FIXED_STEP = true
	var pair := _app()
	var s: Session = pair[0]
	var app: PilotApp = pair[1]
	app._process(1.0 / 30)  # settle the first frame
	var t0 := s.time
	for dt in [0.007, 0.011, 0.016, 0.050, 0.003, 0.021]:
		app._process(dt)
	var ran := s.time - t0
	check_near(fmod(ran + 1e-6, HostLoop.DT), 0.0, 1e-4, "the clock moved by whole steps only (%.4f s)" % ran)
	check(absf(ran - 0.108) <= HostLoop.DT + 1e-4, "and kept up with the frames, within one step (%.4f of 0.108 s)" % ran)
	_done(pair)


func test_the_drawn_pose_is_between_the_last_two_steps() -> void:
	PilotApp.FIXED_STEP = true
	var pair := _app()
	var app: PilotApp = pair[1]
	app._pose_a = Transform3D(Basis(), Vector3(0, 0, 0))
	app._pose_b = Transform3D(Basis(), Vector3(10, 0, 0))
	app._posed = true
	app._loop._acc = HostLoop.DT * 0.25
	check_near(app.render_pose().origin.x, 2.5, 1e-4, "a quarter into the next step: a quarter of the way")
	app._loop._acc = 0.0
	check_near(app.render_pose().origin.x, 0.0, 1e-4, "never ahead of the sim")
	PilotApp.FIXED_STEP = false
	check_eq(app.render_pose(), app._pose_now(), "off: the sim's own pose, as before")
	_done(pair)


## Codex on #512: the chase camera aimed along the latest step's heading, so its aim jumped at 30 Hz; it now turns with the pose.
func test_the_camera_heading_is_between_the_last_two_steps_the_short_way() -> void:
	PilotApp.FIXED_STEP = true
	var pair := _app()
	var app: PilotApp = pair[1]
	app._hdg_a = 350.0
	app._hdg_b = 10.0
	app._posed = true
	app._loop._acc = HostLoop.DT * 0.5
	check_near(fposmod(app.render_heading(), 360.0), 0.0, 1e-3, "halfway from 350 to 10 is north, not 180")
	app._loop._acc = 0.0
	check_near(fposmod(app.render_heading(), 360.0), 350.0, 1e-3, "never ahead of the sim")
	PilotApp.FIXED_STEP = false
	check_near(app.render_heading(), (pair[0] as Session).state.heading, 1e-6, "off: the sim's heading")
	_done(pair)


func test_the_switch_is_registered() -> void:
	check(Switches.OPT_IN.has("PilotApp.FIXED_STEP"), "PilotApp.FIXED_STEP is in Switches.OPT_IN")


func test_a_key_press_on_a_frame_with_no_step_is_not_lost() -> void:
	PilotApp.FIXED_STEP = true
	var pair := _app()
	var app: PilotApp = pair[1]
	var inp := ControlMapper.InputFrame.new()
	inp.pressed = {"gear": true}
	app._loop._acc = 0.0
	check_eq(app._fixed_steps(0.004, inp, false), 0, "a 4 ms frame runs no step")
	check(app._carry_pressed.has("gear"), "the press waits")
	var next := ControlMapper.InputFrame.new()
	check(app._fixed_steps(HostLoop.DT, next, false) >= 1, "the next frame steps")
	check(not app._carry_pressed.has("gear") and next.pressed.has("gear"), "and the step saw the press")
	_done(pair)
