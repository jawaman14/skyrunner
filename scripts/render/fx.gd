class_name FX
extends Node3D
## Fire, smoke, explosions and splashes: billboarded Kenney Particle Pack
## sprites (CC0, assets/fx/kenney_particles) on CPUParticles3D, which every
## renderer draws the same (the compatibility renderer included) and which cost
## nothing on the GPU for the few dozen particles each effect uses.
##
## The node is the pilot seat's effects layer:
##   burn(key, pos)   a lasting fire and its smoke column, kept alive while the
##                    caller keeps naming it (sweep() puts out the rest)
##   smoke(key, pos)  a lasting smoke column alone (a burned-out stash house)
##   blast(pos)       a one-shot explosion: flash, fireball, sparks, smoke puff
##   splash(pos)      a one-shot splash: spray and a ring on the water
##   puff(pos)        a one-shot dust puff
## A blast also throws debris: a few rigid bodies (Jolt) that tumble, bounce on
## the ground and the buildings, and go after DEBRIS_S; at most MAX_DEBRIS.
## Smoke leans downwind with `wind` (m/s, Godot axes).
##
## Fires are layered (an outer flame, a white-hot core, rising embers), flicker their light, and char the
## ground under them; smoke is lit orange from below by the fire and fades to soot-grey above; a blast is
## a flash, a two-stage fireball, a shock ring and a dust ring, a mushroom of smoke, sparks and debris,
## and leaves a scorch mark. impact(pos, normal) is a bullet's hit: a spark burst and a puff of dust.

const TEX := "res://assets/fx/kenney_particles/%s.png"
const FIRE := Color(1.0, 0.55, 0.15)
const SCORCH_S := 45.0  ## how long a blast's scorch mark stays
const MAX_DEBRIS := 36
const DEBRIS_S := 8.0
var debris: Array = []
var wind := Vector3.ZERO
var lasting := {}  ## key -> Node3D
var flicker := {}  ## key -> [light, base energy, phase]: the fires' lights, moved by _process
var blasts: Array = []  ## [pos, size, time] of the last few seconds' blasts, for the camera shake
var _seen := {}
var _t := 0.0
static var _mats := {}


## A billboard material for one of the sprites; `add` blends additively (fire, sparks).
static func mat(sprite: String, add: bool, boost := 1.0) -> StandardMaterial3D:
	var k := "%s:%s:%.1f" % [sprite, add, boost]
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color(boost, boost, boost)  # above 1: HDR, so the fire blooms
		m.albedo_texture = load(TEX % sprite) if ResourceLoader.exists(TEX % sprite) else null
		m.no_depth_test = false
		m.disable_receive_shadows = true
		_mats[k] = m
	return _mats[k]


static func _emitter(sprite: String, add: bool, amount: int, life: float, size: float, boost := 1.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat(sprite, add, boost)
	p.mesh = q
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.angle_min = 0.0
	p.angle_max = 360.0
	return p


static func _ramp(cols: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(range(cols.size()).map(func(i): return float(i) / (cols.size() - 1)))
	g.colors = PackedColorArray(cols)
	return g


static func _grow(a: float, b: float) -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, a))
	c.add_point(Vector2(1, b))
	return c


## Flames licking up from a burning wreck, `size` metres across: the outer flame (this node), a white-hot core and
## embers that drift up with the heat as children.
static func flames(size := 3.0) -> CPUParticles3D:
	var p := _emitter("fire_01", true, 30, 0.9, size * 1.15, 1.7)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size * 0.35
	p.direction = Vector3.UP
	p.spread = 14.0
	p.gravity = Vector3(0, size * 1.4, 0)
	p.initial_velocity_min = size * 0.4
	p.initial_velocity_max = size * 1.0
	p.scale_amount_curve = _grow(1.0, 0.2)
	p.color_ramp = _ramp([Color(1, 0.8, 0.35, 0.0), Color(1.0, 0.5, 0.1, 0.95), Color(0.85, 0.2, 0.04, 0.55), Color(0.25, 0.08, 0.04, 0.0)])
	p.name = "flames"
	var core := _emitter("flame_04", true, 14, 0.55, size * 0.7, 2.4)
	core.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	core.emission_sphere_radius = size * 0.18
	core.direction = Vector3.UP
	core.spread = 6.0
	core.gravity = Vector3(0, size * 1.6, 0)
	core.initial_velocity_min = size * 0.3
	core.initial_velocity_max = size * 0.7
	core.scale_amount_curve = _grow(1.0, 0.1)
	core.color_ramp = _ramp([Color(1, 1, 0.85, 0.0), Color(1, 0.95, 0.65, 1.0), Color(1, 0.6, 0.2, 0.5), Color(0.6, 0.2, 0.05, 0.0)])
	core.name = "core"
	p.add_child(core)
	var em := _emitter("spark_01", true, 10, 2.4, size * 0.12, 2.0)
	em.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	em.emission_sphere_radius = size * 0.4
	em.direction = Vector3.UP
	em.spread = 35.0
	em.initial_velocity_min = size * 0.8
	em.initial_velocity_max = size * 1.8
	em.gravity = Vector3(0.6, size * 0.5, 0.3)
	em.damping_min = 0.4
	em.damping_max = 0.9
	em.color_ramp = _ramp([Color(1, 0.8, 0.4, 0.0), Color(1, 0.6, 0.2, 1.0), Color(1, 0.3, 0.05, 0.7), Color(0.4, 0.1, 0.0, 0.0)])
	em.name = "embers"
	p.add_child(em)
	return p


## A column of smoke, black from burning fuel or grey from a smouldering house: orange where the fire lights its
## foot, then soot, then a thin grey veil. Soft (never solid black), so the flames show through it.
static func column(size := 4.0, dark := true, wind := Vector3.ZERO) -> CPUParticles3D:
	var p := _emitter("smoke_04", false, 48, 8.0, size)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size * 0.3
	p.direction = Vector3.UP
	p.spread = 10.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 3.8
	p.gravity = Vector3(0, 0.7, 0) + wind * 0.35
	p.damping_min = 0.3
	p.damping_max = 0.6
	p.scale_amount_curve = _grow(0.5, 3.6)
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -12.0
	p.angular_velocity_max = 12.0
	var c := Color(0.11, 0.11, 0.12) if dark else Color(0.5, 0.5, 0.52)
	var lit := Color(0.55, 0.26, 0.1) if dark else Color(0.62, 0.5, 0.4)
	p.color_ramp = _ramp([Color(lit, 0.0), Color(lit, 0.55), Color(c, 0.5), Color(c.lightened(0.2), 0.28), Color(c.lightened(0.45), 0.0)])
	p.name = "smoke"
	return p


## One-shot pieces: they emit once and free themselves.
static func _once(p: CPUParticles3D) -> CPUParticles3D:
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


func burn(key: String, pos: Vector3, size := 3.0) -> Node3D:
	_seen[key] = true
	if not lasting.has(key):
		var n := Node3D.new()
		n.name = key.validate_node_name()
		n.add_child(flames(size))
		n.add_child(column(size * 1.4, true, wind))
		var l := OmniLight3D.new()
		l.name = "glow"
		l.light_color = FIRE
		l.omni_range = size * 8.0
		l.light_energy = 2.4
		l.shadow_enabled = false
		l.position.y = size * 0.6
		n.add_child(l)
		n.add_child(scorch(size * 2.4))
		add_child(n)
		flicker[key] = [l, 2.4, float(hash(key) % 1000)]
		lasting[key] = n
	lasting[key].position = pos
	return lasting[key]


func smoke(key: String, pos: Vector3, size := 5.0) -> Node3D:
	_seen[key] = true
	if not lasting.has(key):
		var n := Node3D.new()
		n.name = key.validate_node_name()
		n.add_child(column(size, false, wind))
		add_child(n)
		lasting[key] = n
	lasting[key].position = pos
	return lasting[key]


## Put out every lasting effect not named since the last sweep.
func sweep() -> void:
	for k in lasting.keys():
		if not _seen.has(k):
			lasting[k].queue_free()
			lasting.erase(k)
			flicker.erase(k)
	_seen.clear()


func blast(pos: Vector3, size := 4.0) -> Node3D:
	var n := Node3D.new()
	n.name = "blast"
	add_child(n)
	n.position = pos
	# the flash: one huge white sprite for a moment
	var flash := _once(_emitter("circle_05", true, 1, 0.16, size * 7.0, 3.0))
	flash.explosiveness = 1.0
	flash.spread = 0.0
	flash.initial_velocity_min = 0.0
	flash.initial_velocity_max = 0.0
	flash.gravity = Vector3.ZERO
	flash.color_ramp = _ramp([Color(1, 1, 0.9, 1), Color(1, 0.8, 0.5, 0.6), Color(1, 0.5, 0.2, 0)])
	flash.name = "flash"
	n.add_child(flash)
	# the fireball: a fast white-orange burst, then a slower rolling orange one
	var fb := _once(_emitter("fire_02", true, 20, 0.55, size * 1.3, 2.0))
	fb.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fb.emission_sphere_radius = size * 0.3
	fb.spread = 180.0
	fb.initial_velocity_min = size * 1.5
	fb.initial_velocity_max = size * 3.2
	fb.gravity = Vector3.ZERO
	fb.damping_min = size * 3.0
	fb.damping_max = size * 4.0
	fb.scale_amount_curve = _grow(0.6, 1.7)
	fb.color_ramp = _ramp([Color(1, 0.97, 0.75, 1), Color(1, 0.55, 0.12, 0.9), Color(0.35, 0.1, 0.04, 0.0)])
	fb.name = "fireball"
	n.add_child(fb)
	var roll := _once(_emitter("flame_02", true, 14, 1.4, size * 1.6, 1.6))
	roll.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	roll.emission_sphere_radius = size * 0.45
	roll.direction = Vector3.UP
	roll.spread = 55.0
	roll.initial_velocity_min = size * 0.6
	roll.initial_velocity_max = size * 1.5
	roll.gravity = Vector3(0, size * 0.9, 0)
	roll.damping_min = 1.0
	roll.damping_max = 2.0
	roll.explosiveness = 0.5
	roll.scale_amount_curve = _grow(0.9, 1.4)
	roll.color_ramp = _ramp([Color(1, 0.7, 0.25, 0.9), Color(0.9, 0.3, 0.06, 0.7), Color(0.2, 0.06, 0.03, 0)])
	roll.name = "roll"
	n.add_child(roll)
	# sparks and a dust ring flung out along the ground
	var sp := _once(_emitter("spark_01", true, 40, 1.0, size * 0.25, 2.2))
	sp.spread = 180.0
	sp.initial_velocity_min = 12.0
	sp.initial_velocity_max = 30.0
	sp.gravity = Vector3(0, -9.8, 0)
	sp.color_ramp = _ramp([Color(1, 0.9, 0.55, 1), Color(1, 0.5, 0.15, 0.8), Color(0.5, 0.15, 0.05, 0)])
	n.add_child(sp)
	var dust := _once(_emitter("dirt_02", false, 18, 2.2, size * 1.2))
	dust.direction = Vector3(1, 0.05, 0)
	dust.spread = 180.0
	dust.flatness = 1.0
	dust.initial_velocity_min = size * 2.5
	dust.initial_velocity_max = size * 4.0
	dust.gravity = Vector3(0, 0.3, 0) + wind * 0.2
	dust.damping_min = size * 1.2
	dust.damping_max = size * 1.8
	dust.scale_amount_curve = _grow(0.7, 2.2)
	dust.color_ramp = _ramp([Color(0.62, 0.52, 0.4, 0.55), Color(0.5, 0.45, 0.4, 0.3), Color(0.45, 0.42, 0.4, 0.0)])
	dust.name = "dust"
	n.add_child(dust)
	# the mushroom: dark smoke thrown up, and a broader grey cap rising slowly behind it
	var sm := _once(column(size * 1.3, true, wind))
	sm.amount = 18
	sm.lifetime = 5.0
	sm.explosiveness = 0.6
	n.add_child(sm)
	var cap := _once(_emitter("smoke_07", false, 10, 7.0, size * 2.6))
	cap.direction = Vector3.UP
	cap.spread = 25.0
	cap.initial_velocity_min = size * 0.7
	cap.initial_velocity_max = size * 1.3
	cap.gravity = Vector3(0, 0.5, 0) + wind * 0.3
	cap.damping_min = 0.4
	cap.damping_max = 0.7
	cap.explosiveness = 0.35
	cap.scale_amount_curve = _grow(0.8, 2.6)
	cap.color_ramp = _ramp([Color(0.35, 0.2, 0.12, 0.0), Color(0.28, 0.22, 0.2, 0.5), Color(0.22, 0.21, 0.21, 0.35), Color(0.3, 0.3, 0.32, 0.0)])
	cap.name = "cap"
	n.add_child(cap)
	# the shock ring races out over the ground
	var ring := MeshInstance3D.new()
	ring.name = "shock"
	var rq := QuadMesh.new()
	rq.size = Vector2(size * 2.0, size * 2.0)
	rq.orientation = PlaneMesh.FACE_Y
	var rm: StandardMaterial3D = mat("circle_05", true, 1.6).duplicate()
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	rm.vertex_color_use_as_albedo = false
	rm.albedo_color = Color(1.4, 1.1, 0.8, 0.55)
	rq.material = rm
	ring.mesh = rq
	ring.position.y = 0.2
	n.add_child(ring)
	n.add_child(scorch(size * 3.0))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.4)
	l.omni_range = size * 12.0
	l.light_energy = 12.0
	n.add_child(l)
	throw_debris(pos, 6, size)
	blasts.append([pos, size, _t])
	var tw := n.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "light_energy", 1.6, 0.12)
	tw.tween_property(ring, "scale", Vector3.ONE * 5.0, 0.7)
	tw.tween_property(rm, "albedo_color:a", 0.0, 0.7)
	tw.chain().tween_property(l, "light_energy", 0.0, 1.6)  # the afterglow
	tw.chain().tween_interval(SCORCH_S)
	tw.chain().tween_callback(n.queue_free)
	return n


## A flat charred patch on the ground, `diameter` metres across (the node that holds it decides how long it stays).
static func scorch(diameter: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "scorch"
	var q := QuadMesh.new()
	q.size = Vector2(diameter, diameter)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = load(TEX % "scorch_02") if ResourceLoader.exists(TEX % "scorch_02") else null
	m.albedo_color = Color(0.03, 0.025, 0.02, 0.8)
	m.render_priority = -1
	m.disable_receive_shadows = true
	q.material = m
	mi.mesh = q
	mi.position.y = 0.06
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A bullet's hit: a few sparks, a puff of dust and a flicker of light.
func impact(pos: Vector3, normal := Vector3.UP) -> Node3D:
	var n := Node3D.new()
	n.name = "impact"
	add_child(n)
	n.position = pos
	var sp := _once(_emitter("spark_01", true, 10, 0.5, 0.18, 2.2))
	sp.direction = normal
	sp.spread = 40.0
	sp.initial_velocity_min = 3.0
	sp.initial_velocity_max = 9.0
	sp.gravity = Vector3(0, -9.8, 0)
	sp.color_ramp = _ramp([Color(1, 0.9, 0.6, 1), Color(1, 0.5, 0.15, 0.8), Color(0.4, 0.1, 0.0, 0)])
	n.add_child(sp)
	var d := _once(_emitter("dirt_02", false, 5, 0.9, 0.9))
	d.direction = normal
	d.spread = 50.0
	d.initial_velocity_min = 0.6
	d.initial_velocity_max = 1.8
	d.gravity = Vector3(0, 0.2, 0) + wind * 0.2
	d.scale_amount_curve = _grow(0.6, 1.6)
	d.color_ramp = _ramp([Color(0.6, 0.55, 0.45, 0.5), Color(0.55, 0.5, 0.45, 0.0)])
	n.add_child(d)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.45)
	l.omni_range = 5.0
	l.light_energy = 2.0
	n.add_child(l)
	var tw := n.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.12)
	tw.tween_interval(1.0)
	tw.tween_callback(n.queue_free)
	return n


## How hard the ground shakes at `at` from the blasts of the last few seconds (0 to 1): the seat shakes its camera by it.
func shake_at(at: Vector3) -> float:
	var s := 0.0
	for b in blasts:
		var age: float = _t - float(b[2])
		if age > 1.6:
			continue
		var d: float = at.distance_to(b[0])
		s += float(b[1]) / 4.0 * clampf(1.0 - d / 140.0, 0.0, 1.0) * clampf(1.0 - age / 1.6, 0.0, 1.0)
	return clampf(s, 0.0, 1.0)


func _process(dt: float) -> void:
	_t += dt
	blasts = blasts.filter(func(b): return _t - float(b[2]) < 1.6)
	for k in flicker:
		var e: Array = flicker[k]
		var l: OmniLight3D = e[0]
		if not is_instance_valid(l):
			continue
		var ph: float = float(e[2])
		# two beating sines and a fast one: a flame's irregular breathing
		var f: float = 0.78 + 0.22 * sin(_t * 9.0 + ph) + 0.12 * sin(_t * 23.0 + ph * 1.7) + 0.08 * sin(_t * 41.0 + ph * 0.3)
		l.light_energy = float(e[1]) * f
		l.light_color = FIRE.lerp(Color(1.0, 0.75, 0.3), clampf(f - 0.8, 0.0, 0.4))


## Chunks flung out of a blast: small boxes on the physics engine, scorched dark.
func throw_debris(pos: Vector3, n: int, size := 4.0) -> int:
	debris = debris.filter(func(b): return is_instance_valid(b))
	# only where there's ground to land on (the island's collider exists once you've walked)
	if not is_inside_tree():
		return 0
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 2, 0), pos - Vector3(0, 60, 0))
	if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pos)
	for i in n:
		if debris.size() >= MAX_DEBRIS:
			var old = debris.pop_front()
			old.queue_free()
		var b := RigidBody3D.new()
		b.name = "debris"
		var s := Vector3(rng.randf_range(0.15, 0.5), rng.randf_range(0.08, 0.25), rng.randf_range(0.15, 0.6))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = s
		cs.shape = bs
		b.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = s
		bm.material = _debris_mat()
		mi.mesh = bm
		b.add_child(mi)
		b.mass = s.x * s.y * s.z * 800.0
		add_child(b)
		b.global_position = pos + Vector3(rng.randf_range(-0.5, 0.5), 0.6, rng.randf_range(-0.5, 0.5))
		var out := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.8, 1.6), rng.randf_range(-1, 1)).normalized()
		b.linear_velocity = out * rng.randf_range(6.0, 14.0) * size / 4.0
		b.angular_velocity = Vector3(rng.randf_range(-9, 9), rng.randf_range(-9, 9), rng.randf_range(-9, 9))
		debris.append(b)
		get_tree().create_timer(DEBRIS_S).timeout.connect(func(): if is_instance_valid(b): b.queue_free())
	return n


static var _dmat: StandardMaterial3D
static func _debris_mat() -> StandardMaterial3D:
	if _dmat == null:
		_dmat = StandardMaterial3D.new()
		_dmat.albedo_color = Color(0.12, 0.1, 0.09)
		_dmat.roughness = 0.9
	return _dmat


func splash(pos: Vector3, size := 2.0) -> Node3D:
	var n := Node3D.new()
	n.name = "splash"
	add_child(n)
	n.position = pos
	var spray := _once(_emitter("circle_05", false, 22, 1.1, size * 0.6))
	spray.direction = Vector3.UP
	spray.spread = 25.0
	spray.initial_velocity_min = size * 2.5
	spray.initial_velocity_max = size * 4.5
	spray.gravity = Vector3(0, -9.8, 0)
	spray.scale_amount_curve = _grow(1.0, 0.4)
	spray.color_ramp = _ramp([Color(1, 1, 1, 0.9), Color(0.85, 0.93, 1, 0.0)])
	n.add_child(spray)
	var ring := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size * 3.0, size * 3.0)
	q.orientation = PlaneMesh.FACE_Y
	var rm: StandardMaterial3D = mat("circle_05", false).duplicate()
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	rm.vertex_color_use_as_albedo = false
	rm.albedo_color = Color(1, 1, 1, 0.8)
	q.material = rm
	ring.mesh = q
	ring.position.y = 0.15
	n.add_child(ring)
	var tw := n.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * 2.5, 1.6)
	tw.tween_property(rm, "albedo_color:a", 0.0, 1.6)
	tw.chain().tween_callback(n.queue_free)
	return n


func puff(pos: Vector3, size := 2.0) -> CPUParticles3D:
	var p := _once(_emitter("dirt_02", false, 12, 1.6, size))
	p.spread = 70.0
	p.direction = Vector3.UP
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -1.0, 0) + wind * 0.3
	p.scale_amount_curve = _grow(0.6, 1.8)
	p.color_ramp = _ramp([Color(0.6, 0.52, 0.4, 0.7), Color(0.6, 0.55, 0.45, 0.0)])
	p.name = "puff"
	add_child(p)
	p.position = pos
	return p
