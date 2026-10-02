class_name RaceMarkers
extends Node3D
## The race's gates in the world: the next one a bright ring (with a tall beam you can find from the road or the
## air), the one after it a dim one. Follows Races.run; nothing is drawn when no race is on. The gates stand in
## the island's frame (game x, y -> world x, -y), at the ground for the street and at their height for the circuit.

var s: Session
var next_ring: MeshInstance3D
var then_ring: MeshInstance3D
var beam: MeshInstance3D
var _shown := ""
var _gate := -1


func setup(sess: Session) -> RaceMarkers:
	s = sess
	name = "race_markers"
	next_ring = _ring(Color(1.0, 0.85, 0.15), 3.0)
	then_ring = _ring(Color(0.8, 0.9, 1.0), 1.0)
	beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.0
	cyl.bottom_radius = 2.0
	cyl.height = 600.0
	beam.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1.0, 0.85, 0.15, 0.25)
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.85, 0.15)
	bm.emission_energy_multiplier = 1.5
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for n in [next_ring, then_ring, beam]:
		n.visible = false
		add_child(n)
	return self


func _ring(c: Color, energy: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.92
	t.outer_radius = 1.0
	m.mesh = t
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## Gate i of course c: an upright ring across the line of travel (toward the next gate, or as it came in at the last).
func _place(ring: MeshInstance3D, c, i: int) -> void:
	var g: Vector3 = c.gates[i]
	var y: float = g.z if c.kind == "air" else s.world.ground(g.x, g.y) + c.radius * 0.6
	ring.position = Vector3(g.x, y, -g.y)
	ring.scale = Vector3.ONE * c.radius
	var j := i + 1 if i + 1 < c.gates.size() else i - 1
	var o: Vector3 = c.gates[maxi(j, 0)]
	var dir := Vector2(o.x - g.x, o.y - g.y)
	if i + 1 >= c.gates.size():
		dir = -dir
	var yaw := atan2(dir.x, -dir.y) if dir.length() > 0.1 else 0.0
	ring.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3.ONE * c.radius)


func _process(_dt: float) -> void:
	var r: Races = s.races
	if r == null or not r.active():
		if next_ring.visible:
			for n in [next_ring, then_ring, beam]:
				n.visible = false
			_shown = ""
			_gate = -1
		return
	var c = r.course(str(r.run.id))
	if c == null:
		return
	var i: int = int(r.run.next)
	if str(r.run.id) == _shown and i == _gate:
		return
	_shown = str(r.run.id)
	_gate = i
	_place(next_ring, c, i)
	next_ring.visible = true
	var g: Vector3 = c.gates[i]
	beam.position = Vector3(g.x, (g.z if c.kind == "air" else s.world.ground(g.x, g.y)) + 300.0, -g.y)
	beam.visible = true
	if i + 1 < c.gates.size():
		_place(then_ring, c, i + 1)
		then_ring.visible = true
	else:
		then_ring.visible = false
