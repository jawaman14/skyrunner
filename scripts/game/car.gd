class_name Car
extends CharacterBody3D
## The starter car: a parked car you can get into (E) and drive, arcade-style. WASD drives (W / S
## throttle and brake-then-reverse, A / D steer, Space the handbrake), a chase camera follows. It is a
## real body on the island's collision: it stops against buildings and the parked aircraft, climbs
## what a car can, and will not drive into deep water. A road is fast (about 95 km/h), anything
## else is a track across country (about 40 km/h).
##
## Arcade, not a simulation: one speed along the heading, a yaw rate that falls off with speed, no
## suspension. PilotApp owns getting in and out (`driven`); the car only drives when it is set.

const ROAD_MS := 26.0  ## top speed on a road
const OFFROAD_MS := 11.0  ## ... and anywhere else
const REVERSE_MS := 6.0
const ACCEL := 9.0
const BRAKE := 20.0
const DRAG := 2.5  ## what coasting costs, m/s per second
const MASS := 1300.0  ## kg: a Dealership car can differ
const WHEELBASE := 2.7  ## m
const TRACK := 1.6  ## m
const MU_ROAD := 1.0  ## tyre grip as a multiple of g: a road holds about 1 g, a track or a field much less
const MU_OFF := 0.55
const BRAKE_G := 0.9  ## the brakes at their best: this fraction of what the tyres can hold
const HANDBRAKE_DECEL := 5.0
const HANDBRAKE_GRIP := 0.3  ## the rear tyres on the handbrake hold a third of what they do rolling
const COAST_ROLL := 0.5  ## m/s per second just from rolling...
const COAST_AIR := 0.0028  ## ... and from the air, rising with the square of the speed
const GEAR_RATIOS := [3.6, 2.2, 1.5, 1.1, 0.85]  ## so the engine note climbs and drops with the gears
const GRAVITY := 9.81
const ROAD_M := 7.0  ## within this of a road centre line is the road

var world: World
var road_ms := ROAD_MS  ## this car's top speed on a road (Dealership cars differ)
var off_ms := OFFROAD_MS
var accel := ACCEL
var body_node: Node3D = null  ## the model
var driven := false
var headlights: Array = []  ## the two lamps (on at night, while it is driven)
var speed := 0.0  ## m/s along the heading (negative: reversing)
var lat := 0.0  ## m/s sideways, to the right of the heading: a slide
var yaw_rate := 0.0  ## rad/s about the vertical, positive turning left
var throttle_in := 0.0  ## the accelerator pedal as the engine sees it (0..1), not as the key is
var brake_in := 0.0
var steer_in := 0.0  ## the wheel, -1 (left) .. 1 (right)
var gear := 1
var rpm := 900.0
var odo_m := 0.0  ## distance driven since this car was set down
var long_g := 0.0  ## for the dashboard and the body: how hard it is accelerating (+) or braking (-), in g
var lat_g := 0.0  ## cornering, in g (+ is a left turn: it pushes you to the right)
var mass := MASS
var _pitch := 0.0
var _pitch_v := 0.0
var _roll := 0.0
var _roll_v := 0.0
var _cam_yaw := 0.0
var _cam_pos := Vector3.ZERO
var cam: Camera3D
var board: Area3D  ## the point you press E at to get in
var road: MapCity.RoadIndex = null
var _last_dry := Vector3.ZERO


func setup(w: World, faction := "org") -> Car:
	world = w
	name = "Car"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 1.1, 4.4)
	cs.shape = box
	cs.position = Vector3(0, 0.75, 0)
	add_child(cs)
	body_node = SquadRender.vehicle(faction, "car")
	add_child(body_node)
	for sx in [-0.7, 0.7]:
		var hl := SpotLight3D.new()
		hl.name = "headlight"
		hl.position = Vector3(sx, 0.85, -2.1)
		hl.spot_range = 55.0
		hl.spot_angle = 32.0
		hl.spot_angle_attenuation = 0.8
		hl.light_energy = 4.0
		hl.light_color = Color(1.0, 0.95, 0.8)
		hl.rotation_degrees.x = -3.0
		hl.visible = false
		add_child(hl)
		headlights.append(hl)
	cam = Camera3D.new()
	cam.position = Vector3(0, 3.4, 7.8)
	cam.rotation = Vector3(deg_to_rad(-14.0), 0, 0)
	cam.near = 0.1
	cam.far = 30000.0
	cam.fov = 72
	cam.top_level = true  # it follows with a lag (_camera), it is not bolted to the roof
	add_child(cam)
	board = Area3D.new()
	board.collision_layer = 4
	board.collision_mask = 0
	board.set_meta("action", "car")
	board.set_meta("label", "Get in the car")
	var bs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 2.6
	bs.shape = sp
	board.add_child(bs)
	board.position = Vector3(0, 1.0, 0)
	add_child(board)
	if not w.map.roads.is_empty():
		road = MapCity.RoadIndex.new(w.map.roads, 400.0)
	floor_snap_length = 0.8
	floor_max_angle = deg_to_rad(55)
	return self


## Become a Dealership car: its numbers and its body. An empty spec leaves the starter car.
func apply_spec(sp: Dictionary) -> void:
	if sp.is_empty():
		return
	road_ms = float(sp.road)
	off_ms = float(sp.off)
	accel = float(sp.accel)
	mass = float(sp.get("mass", MASS))
	var m := ModelLib.vehicle(str(sp.model), float(sp.len))
	if m != null:
		if body_node != null:
			body_node.queue_free()
		body_node = m
		add_child(body_node)


## Put the car down at a game-frame point (x east, y north), facing `heading_deg`.
func place(x: float, y: float, heading_deg: float) -> void:
	global_position = Vector3(x, world.travel_surface(x, y) + 0.4, -y)
	rotation = Vector3(0, -deg_to_rad(heading_deg), 0)
	velocity = Vector3.ZERO
	speed = 0.0
	lat = 0.0
	yaw_rate = 0.0
	throttle_in = 0.0
	brake_in = 0.0
	steer_in = 0.0
	_cam_yaw = rotation.y
	_cam_pos = Vector3.ZERO
	_last_dry = global_position


func game_xy() -> Vector2:
	return Vector2(global_position.x, -global_position.z)


func heading_deg() -> float:
	return rad_to_deg(-rotation.y)


func on_road() -> bool:
	return road != null and road.dist(game_xy()) < ROAD_M


## What the surface under it lets it do.
func top_speed() -> float:
	return road_ms if on_road() else off_ms


func _physics_process(dt: float) -> void:
	var throttle := 0.0
	var steer := 0.0
	var handbrake := false
	if driven:
		throttle = float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)) \
			- float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
		steer = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) \
			- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		handbrake = Input.is_physical_key_pressed(KEY_SPACE)
	_drive(throttle, steer, handbrake, dt)


## One step of the model (also what the tests call). It has weight now: the pedals ramp rather than snap, the
## engine pulls hard from a standstill and tails off toward its top speed, the brakes take a moment to bite, the
## wheel turns at a steady rate and the car follows it with inertia, the tyres hold only so much sideways before it
## slides (a hard turn at speed pushes wide, the handbrake kicks the tail out), and the body pitches and rolls on
## the springs while the chassis follows the ground under all four wheels.
func _drive(throttle: float, steer: float, handbrake: bool, dt: float) -> void:
	var cap := top_speed()
	var on_rd := on_road()
	var mu := MU_ROAD if on_rd else MU_OFF
	# pedals and wheel: they move at a rate, they do not teleport
	var want_t := maxf(throttle, 0.0)
	var reversing := throttle < 0.0 and speed <= 0.5
	var want_b := maxf(-throttle, 0.0) if not reversing else 0.0
	throttle_in = move_toward(throttle_in, want_t, dt / 0.35)
	brake_in = move_toward(brake_in, want_b, dt / 0.12)
	steer_in = move_toward(steer_in, steer, dt * (3.2 if absf(steer) > absf(steer_in) else 5.0))
	# along the car
	var a := 0.0
	if reversing:
		a = -accel * 0.55 * -throttle * (1.0 - pow(absf(speed) / REVERSE_MS, 2.0))
	else:
		var r := clampf(speed / cap, 0.0, 1.0)
		a = minf(accel * throttle_in * (1.0 - pow(r, 2.4)), mu * GRAVITY)  # the tyres bound what the engine can put down
	if speed > 0.0:
		a -= COAST_ROLL + COAST_AIR * speed * speed
	elif speed < 0.0:
		a += COAST_ROLL + COAST_AIR * speed * speed
	if brake_in > 0.0 and absf(speed) > 0.05:
		a -= signf(speed) * brake_in * BRAKE_G * mu * GRAVITY * pow(MASS / mass, 0.3)
	if handbrake and absf(speed) > 0.05:
		a -= signf(speed) * HANDBRAKE_DECEL
	var sp0 := speed
	speed += a * dt
	if (sp0 > 0.0 and speed < 0.0 and (brake_in > 0.0 or handbrake)) or (sp0 < 0.0 and speed > 0.0 and not reversing):
		speed = 0.0  # a brake stops the car, it does not reverse it
	# off the road you are held to a crawl however hard you push
	if speed > cap:
		speed = move_toward(speed, cap, 8.0 * dt)
	speed = maxf(speed, -REVERSE_MS)
	long_g = a / GRAVITY
	# steering: a bicycle model with a limit on what the tyres can hold, then inertia in the turn
	var max_steer := deg_to_rad(34.0) / (1.0 + pow(absf(speed) / 9.0, 1.4))
	var target_yaw := -speed * tan(steer_in * max_steer) / WHEELBASE
	var grip := mu * GRAVITY * (HANDBRAKE_GRIP if handbrake else 1.0)
	var need := absf(speed * target_yaw)
	if need > grip * 0.9:
		target_yaw *= grip * 0.9 / need  # understeer: it will not turn tighter than the tyres allow
	if handbrake and absf(speed) > 6.0:
		target_yaw += -steer_in * 0.9 * clampf(absf(speed) / 15.0, 0.0, 1.0)  # the tail steps out
	yaw_rate = lerpf(yaw_rate, target_yaw, minf(1.0, dt * (6.0 if absf(speed) > 1.0 else 12.0)))
	var dpsi := yaw_rate * dt
	rotate_y(dpsi)
	# the velocity does not turn with the body: part of it is now sideways, and the tyres have to take it back
	var f1 := speed * cos(dpsi) - lat * sin(dpsi)
	lat = speed * sin(dpsi) + lat * cos(dpsi)
	speed = f1
	lat = move_toward(lat, 0.0, grip * dt * 1.0)
	lat_g = speed * yaw_rate / GRAVITY
	var fwd := -global_transform.basis.z
	var right := global_transform.basis.x
	velocity.x = fwd.x * speed + right.x * lat
	velocity.z = fwd.z * speed + right.z * lat
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * dt
	move_and_slide()
	if get_slide_collision_count() > 0 and is_on_wall():
		speed *= 0.5  # it hit something
		lat *= 0.5
	odo_m += absf(speed) * dt
	_gearbox(cap, throttle_in)
	_body_springs(dt)
	# no swimming
	var gz := world.height(global_position.x, -global_position.z)
	if gz < -1.2 and global_position.y < 0.2:
		global_position = _last_dry
		velocity = Vector3.ZERO
		speed = 0.0
	elif is_on_floor():
		_last_dry = global_position
	if global_position.y < world.travel_surface(global_position.x, -global_position.z) - 5.0:
		global_position.y = world.travel_surface(global_position.x, -global_position.z) + 0.6
		velocity = Vector3.ZERO


## A five-speed automatic: the gear follows the speed, the revs follow the gear and the pedal, so the dashboard's tachometer
## (and the engine's note) climbs, drops on a change and dips with the throttle off.
func _gearbox(cap: float, pedal: float) -> void:
	var v := absf(speed)
	if speed < -0.1:
		gear = -1
		rpm = lerpf(rpm, 900.0 + v / REVERSE_MS * 3200.0, 0.2)
		return
	var top := maxf(cap, 8.0)
	var share := clampf(v / (top * 1.02), 0.0, 1.0)
	var want := clampi(1 + int(share * float(GEAR_RATIOS.size())), 1, GEAR_RATIOS.size())
	if want > gear or want < gear - 1:
		gear = want
	var lo := float(gear - 1) / float(GEAR_RATIOS.size()) * top
	var hi := float(gear) / float(GEAR_RATIOS.size()) * top
	var within := clampf((v - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)
	var target := 900.0 + (within * 0.8 + 0.2) * 5200.0 * (0.4 + 0.6 * clampf(v / 4.0, 0.0, 1.0)) if v > 0.3 else 900.0 + pedal * 2400.0
	rpm = lerpf(rpm, target + pedal * 400.0, 0.25)


## The body is a visual on springs: it squats under power, dives under the brakes, leans out of a corner, and follows the
## slope the wheels are on. (The collision body stays level: only the model moves.)
func _body_springs(dt: float) -> void:
	if body_node == null or not is_inside_tree():
		return
	var h := rotation.y
	var fwd := Vector2(-sin(h), -cos(h))  # in the game's ground plane, x east, z south
	var rgt := Vector2(cos(h), -sin(h))
	var p := Vector2(global_position.x, global_position.z)
	var zf := world.travel_surface(p.x + fwd.x * WHEELBASE * 0.5, -(p.y + fwd.y * WHEELBASE * 0.5))
	var zb := world.travel_surface(p.x - fwd.x * WHEELBASE * 0.5, -(p.y - fwd.y * WHEELBASE * 0.5))
	var zr := world.travel_surface(p.x + rgt.x * TRACK * 0.5, -(p.y + rgt.y * TRACK * 0.5))
	var zl := world.travel_surface(p.x - rgt.x * TRACK * 0.5, -(p.y - rgt.y * TRACK * 0.5))
	var pitch_t := atan2(zf - zb, WHEELBASE) + long_g * 0.075
	var roll_t := atan2(zr - zl, TRACK) - lat_g * 0.06  # a left turn leans the body out, to the right
	var k := 70.0
	var c := 9.0
	_pitch_v += ((pitch_t - _pitch) * k - _pitch_v * c) * dt
	_pitch += _pitch_v * dt
	_roll_v += ((roll_t - _roll) * k - _roll_v * c) * dt
	_roll += _roll_v * dt
	body_node.rotation.x = clampf(_pitch, -0.35, 0.35)
	body_node.rotation.z = clampf(_roll, -0.35, 0.35)


func _process(dt: float) -> void:
	_camera(dt)


## The chase camera has weight too: it swings round behind the car a beat late, pulls back and widens with speed, and looks a
## little ahead of the bonnet.
func _camera(dt: float) -> void:
	if cam == null or not cam.current:
		return
	var swing := 1.0 - exp(-dt * 3.2)
	_cam_yaw = lerp_angle(_cam_yaw, rotation.y, swing)
	var behind := Vector3(sin(_cam_yaw), 0.0, cos(_cam_yaw))
	var sp := clampf(absf(speed) / maxf(road_ms, 1.0), 0.0, 1.3)
	var want := global_position + behind * (7.2 + 2.2 * sp) + Vector3(0, 3.1 + 0.5 * sp, 0)
	if _cam_pos == Vector3.ZERO:
		_cam_pos = want
	_cam_pos = _cam_pos.lerp(want, 1.0 - exp(-dt * 9.0))
	cam.global_position = _cam_pos
	var fwd := -global_transform.basis.z
	cam.look_at(global_position + Vector3(0, 1.3, 0) + fwd * (2.0 + speed * 0.12), Vector3.UP)
	cam.fov = lerpf(cam.fov, 70.0 + 14.0 * sp, 1.0 - exp(-dt * 3.0))
