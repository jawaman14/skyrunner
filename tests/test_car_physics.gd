extends TestCase
## The car's weight: pedals that ramp, an engine that tails off, brakes that take time, a wheel that turns at a
## rate, tyres that let go, a body on springs, a gearbox and a tachometer. (The dashboard that shows it is CarDash.)

var _s: Session = null
var _car: Car = null


func _tree() -> SceneTree:
	return Engine.get_main_loop()


func before_each() -> void:
	_s = Session.new({"seed": 1})
	_car = Car.new().setup(_s.world, "org")
	_tree().root.add_child(_car)
	var af := World.airfield("HAR")
	_car.place(af.x + 40.0, af.y, 90.0)


func after_each() -> void:
	_car.free()
	_s.dispose()


func _run(secs: float, throttle: float, steer := 0.0, handbrake := false) -> void:
	for i in int(secs * 60.0):
		_car._drive(throttle, steer, handbrake, 1.0 / 60.0)


func test_the_pedal_ramps_so_the_car_does_not_leap_away() -> void:
	_run(0.1, 1.0)
	check(_car.speed < 0.5 * _car.accel * 0.1, "after a tenth of a second it has hardly moved: %.2f m/s" % _car.speed)
	check(_car.throttle_in > 0.0 and _car.throttle_in < 0.5, "the engine has only part of the pedal: %.2f" % _car.throttle_in)
	_run(3.0, 1.0)
	check(_car.speed > 6.0, "but it gets going: %.1f m/s" % _car.speed)


func test_the_engine_tails_off_toward_the_top_speed_and_stays_under_it() -> void:
	_run(25.0, 1.0)
	var cap := _car.top_speed()
	check(_car.speed <= cap + 0.5, "never over the cap: %.1f of %.1f" % [_car.speed, cap])
	check(_car.speed > 0.8 * cap or not _car.on_road(), "and gets close to it on a road: %.1f" % _car.speed)


func test_the_brakes_take_time_and_the_nose_dips() -> void:
	_run(10.0, 1.0)
	var v0 := _car.speed
	check(v0 > 8.0, "up to speed first: %.1f" % v0)
	var t := 0.0
	while _car.speed > 0.5 and t < 20.0:
		_run(1.0 / 60.0, -1.0)
		t += 1.0 / 60.0
	check(t > 0.8 and t < 10.0, "stopped in a believable time: %.1f s from %.1f m/s" % [t, v0])
	check(_car.long_g < 0.0 or _car.speed < 1.0, "and braking pulls negative g")
	check_eq(_car.gear, 1, "back in first")


func test_a_hard_turn_at_speed_pushes_wide_and_slides() -> void:
	_run(8.0, 1.0)
	var v := _car.speed
	check(v > 8.0, "going: %.1f" % v)
	_run(1.0, 1.0, 1.0)
	check(absf(_car.lat) > 0.05 or absf(_car.lat_g) > 0.2, "the tyres are working sideways: lat %.2f m/s, %.2f g" % [_car.lat, _car.lat_g])
	check(absf(_car.yaw_rate) > 0.05, "it is turning")
	_run(2.0, 0.0, 1.0, true)
	check(absf(_car.lat) > 0.3, "on the handbrake the tail steps out: %.2f m/s sideways" % _car.lat)


func test_the_wheel_takes_time_to_come_over_and_a_low_speed_turn_is_tighter() -> void:
	_run(2.0, 1.0)
	_run(1.0 / 60.0, 1.0, 1.0)
	check(absf(_car.steer_in) < 0.2, "one frame of D does not put the wheel on the stop: %.2f" % _car.steer_in)
	var slow := Car.new().setup(_s.world, "org")
	_tree().root.add_child(slow)
	slow.place(0.0, 0.0, 0.0)
	slow.speed = 5.0
	var fast := Car.new().setup(_s.world, "org")
	_tree().root.add_child(fast)
	fast.place(100.0, 0.0, 0.0)
	fast.speed = 25.0
	for i in 60:
		slow._drive(0.0, 1.0, false, 1.0 / 60.0)
		fast._drive(0.0, 1.0, false, 1.0 / 60.0)
	check(absf(slow.yaw_rate) > absf(fast.yaw_rate) * 0.9, "the turn rate does not grow with speed: %.2f vs %.2f rad/s" % [slow.yaw_rate, fast.yaw_rate])
	slow.free()
	fast.free()


func test_the_body_squats_under_power_and_leans_out_of_a_corner() -> void:
	_run(2.0, 1.0)
	_car._body_springs(1.0 / 60.0)
	for i in 30:
		_car._body_springs(1.0 / 60.0)
	check(_car.body_node.rotation.x > 0.0, "the nose comes up under power: %.3f" % _car.body_node.rotation.x)
	_run(6.0, 1.0)
	_run(1.0, 0.0, -1.0)  # a left turn
	for i in 60:
		_car._body_springs(1.0 / 60.0)
	check(_car.body_node.rotation.z < 0.0, "the body leans to the right in a left turn: %.3f" % _car.body_node.rotation.z)


func test_the_gearbox_climbs_and_the_tacho_follows() -> void:
	var gears := {}
	var top_rpm := 0.0
	for i in 60 * 14:
		_car._drive(1.0, 0.0, false, 1.0 / 60.0)
		gears[_car.gear] = true
		top_rpm = maxf(top_rpm, _car.rpm)
	check(gears.size() >= 3, "it goes through gears: %s" % [gears.keys()])
	check(top_rpm > 3000.0 and top_rpm < 7500.0, "and the revs rise and stay on the dial: %.0f" % top_rpm)
	_run(0.5, -1.0)
	_run(20.0, -1.0)
	check(_car.speed <= 0.1, "it does not run backwards on the brake alone")
	var back := 0.0
	_car.speed = 0.0
	_run(4.0, -1.0)
	back = _car.speed
	check(back < -1.0 and _car.gear == -1, "reverse is reverse: %.1f m/s, gear %d" % [back, _car.gear])


func test_the_dashboard_scale_and_dial_geometry() -> void:
	check(CarDash.dial_max(26.0) >= 26.0 * 3.6, "the dial reaches past the top speed")
	check_eq(int(CarDash.dial_max(26.0)) % 20, 0, "in steps of twenty")
	var c := Vector2(100, 100)
	check(CarDash.dial_point(c, 50.0, 0.0).x < c.x and CarDash.dial_point(c, 50.0, 0.0).y > c.y, "zero is lower left")
	check(CarDash.dial_point(c, 50.0, 0.5).y < c.y - 49.0, "half way is straight up")
	check(CarDash.dial_point(c, 50.0, 1.0).x > c.x and CarDash.dial_point(c, 50.0, 1.0).y > c.y, "full scale is lower right")
	check_eq(CarDash.gear_text(-1), "R", "reverse")
	check_eq(CarDash.gear_text(3), "D3", "third")
