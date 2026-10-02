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
const GRAVITY := 9.81
const ROAD_M := 7.0  ## within this of a road centre line is the road

var world: World
var driven := false
var headlights: Array = []  ## the two lamps (on at night, while it is driven)
var speed := 0.0  ## m/s along the heading (negative: reversing)
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
	add_child(SquadRender.vehicle(faction, "car"))
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


## Put the car down at a game-frame point (x east, y north), facing `heading_deg`.
func place(x: float, y: float, heading_deg: float) -> void:
	global_position = Vector3(x, world.ground(x, y) + 0.4, -y)
	rotation = Vector3(0, -deg_to_rad(heading_deg), 0)
	velocity = Vector3.ZERO
	speed = 0.0
	_last_dry = global_position


func game_xy() -> Vector2:
	return Vector2(global_position.x, -global_position.z)


func heading_deg() -> float:
	return rad_to_deg(-rotation.y)


func on_road() -> bool:
	return road != null and road.dist(game_xy()) < ROAD_M


## What the surface under it lets it do.
func top_speed() -> float:
	return ROAD_MS if on_road() else OFFROAD_MS


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


## One step of the arcade model (also what the tests call).
func _drive(throttle: float, steer: float, handbrake: bool, dt: float) -> void:
	var cap := top_speed()
	if throttle > 0.0:
		speed += (BRAKE if speed < 0.0 else ACCEL) * throttle * dt
	elif throttle < 0.0:
		speed -= (BRAKE if speed > 0.0 else ACCEL * 0.7) * -throttle * dt
	else:
		speed = move_toward(speed, 0.0, DRAG * dt)
	if handbrake:
		speed = move_toward(speed, 0.0, BRAKE * 1.5 * dt)
	# off the road you are held to a crawl however hard you push
	if speed > cap:
		speed = move_toward(speed, cap, BRAKE * dt)
	speed = maxf(speed, -REVERSE_MS)
	# the wheel bites with speed, and bites less the faster you go
	var grip := clampf(absf(speed) / 5.0, 0.0, 1.0) / (1.0 + absf(speed) / 28.0)
	rotate_y(-steer * 1.7 * grip * signf(speed) * dt)
	var fwd := -global_transform.basis.z
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * dt
	move_and_slide()
	if get_slide_collision_count() > 0 and is_on_wall():
		speed *= 0.5  # it hit something
	# no swimming
	var gz := world.height(global_position.x, -global_position.z)
	if gz < -1.2 and global_position.y < 0.2:
		global_position = _last_dry
		velocity = Vector3.ZERO
		speed = 0.0
	elif is_on_floor():
		_last_dry = global_position
	if global_position.y < world.ground(global_position.x, -global_position.z) - 5.0:
		global_position.y = world.ground(global_position.x, -global_position.z) + 0.6
		velocity = Vector3.ZERO
