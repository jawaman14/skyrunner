class_name CasinoCrowd
extends Node3D
## The people of the Hotel Cielo: the dealers, the cashiers, the bartender, the bandsmen (staff: standing at their posts, swaying,
## their arms working) and a crowd of patrons who stroll the aisles, stand at the tables, the slot banks, the bar and the cage, and
## drift out to the cabaret courtyard. They are scenery: no colliders, no sim state; the walker passes through them like the
## shadows of a good night. Positions are in the hotel's own frame (CasinoBuilding), the patrons' paths a graph of open aisles so
## that none of them walks through a table.
##
## The crowd's own random numbers are a RandomNumberGenerator seeded from the casino's number, never the game's streams.

const PATRONS := 16
const FLOOR_Y := 0.15
const PATIO_Y := 0.17
const COATS := ["red", "blue", "white", "black", "green", "orange", "stucco_pink", "metal"]
const SKINS := [Color(0.96, 0.78, 0.62), Color(0.78, 0.58, 0.4), Color(0.55, 0.38, 0.26), Color(0.9, 0.7, 0.55)]

## The aisle nodes (x, z in the hotel's frame): the lobby, the gate to the floor, the lanes between the tables, the slot banks,
## the salon, the cage, the way out to the courtyard and the lanes of its tables.
const NODES := {
	"lobby_w": Vector2(-14, 4), "lobby_c": Vector2(0, 4.5), "lobby_e": Vector2(14, 4), "bar": Vector2(19.5, 6.0),
	"gate": Vector2(0, 10.6), "fc": Vector2(0, 12.8), "fw": Vector2(-14, 12.8), "fe": Vector2(19, 12.8),
	"w1": Vector2(-14, 19.8), "w2": Vector2(-14, 28.5), "e1": Vector2(19, 19.8), "e2": Vector2(19, 28.0),
	"sw0": Vector2(-30, 12.5), "sw1": Vector2(-30, 21.5), "sw2": Vector2(-30, 30.5), "sw3": Vector2(-30, 38.0),
	"sea": Vector2(30, 12.8), "se1": Vector2(30, 19.8), "se_b": Vector2(31, 16.5), "se_c": Vector2(31, 25.5),
	"rn1": Vector2(-7.5, 12.8), "r1": Vector2(-7.5, 18.6), "rn2": Vector2(7.5, 12.8), "r2": Vector2(7.5, 18.6),
	"rl_a": Vector2(-4, 12.8), "rl_b": Vector2(-4, 30.8), "r3": Vector2(0, 30.8), "rl_c": Vector2(-4, 36.5), "cage": Vector2(-1.5, 37.6),
	"bac_door": Vector2(24.5, 28.2), "bac_in": Vector2(24.5, 30.7),
	"door": Vector2(-26, 42.5), "p0": Vector2(-26, 49.0), "pa": Vector2(-26, 56.0), "pb": Vector2(-16, 56.0), "pc": Vector2(-3, 56.0),
	"pd": Vector2(12, 56.0), "pf": Vector2(12, 61.5), "pc2": Vector2(-3, 61.5), "dn": Vector2(-8, 63.5),
	"st1": Vector2(20, 61.5), "st2": Vector2(26, 61.5), "st3": Vector2(31, 61.5),
}
const EDGES := [
	["lobby_w", "lobby_c"], ["lobby_c", "lobby_e"], ["lobby_e", "bar"], ["lobby_c", "gate"], ["gate", "fc"],
	["fc", "fw"], ["fc", "fe"], ["fw", "w1"], ["w1", "w2"], ["fe", "e1"], ["e1", "e2"],
	["fw", "sw0"], ["sw0", "sw1"], ["sw1", "sw2"], ["sw2", "sw3"], ["sw3", "door"], ["door", "p0"], ["p0", "pa"],
	["fe", "sea"], ["e1", "se1"], ["se1", "se_b"], ["se1", "se_c"], ["e2", "bac_door"], ["bac_door", "bac_in"],
	["fc", "rn1"], ["rn1", "r1"], ["fc", "rn2"], ["rn2", "r2"], ["fc", "rl_a"], ["rl_a", "rl_b"], ["rl_b", "r3"], ["rl_b", "rl_c"], ["rl_c", "cage"],
	["pa", "pb"], ["pb", "pc"], ["pc", "pd"], ["pd", "pf"], ["pc", "pc2"], ["pc2", "dn"], ["pf", "st1"], ["st1", "st2"], ["st2", "st3"], ["pc2", "pf"],
]
## Where a patron standing at a node looks.
const LOOK := {
	"r1": Vector2(-7.5, 21), "r2": Vector2(7.5, 21), "r3": Vector2(0, 33), "w1": Vector2(-22, 18), "w2": Vector2(-22, 30),
	"e1": Vector2(14, 16), "e2": Vector2(24, 24), "sw1": Vector2(-33.4, 21.5), "sw2": Vector2(-33.4, 30.5), "se_b": Vector2(33.4, 16.5),
	"se_c": Vector2(33.4, 25.5), "bar": Vector2(24, 5.5), "cage": Vector2(0, 40), "bac_in": Vector2(24.5, 34.6), "st1": Vector2(26, 69),
	"st2": Vector2(26, 69), "st3": Vector2(26, 69), "dn": Vector2(26, 69), "lobby_w": Vector2(-24, 2),
}

var staff: Array = []  ## [{root, arm_l, arm_r, phase, busy}]
var patrons: Array = []
var _rng := RandomNumberGenerator.new()
var _adj := {}
static var _meshes := {}
static var _mats := {}


## `people`: [[x, y, z, coat], ...] from CasinoBuilding (the staff's posts).
static func make(people: Array, seed_ := 1959) -> CasinoCrowd:
	var c := CasinoCrowd.new()
	c.name = "crowd"
	c._setup(people, seed_)
	return c


func _setup(people: Array, seed_: int) -> void:
	_rng.seed = seed_
	for e in EDGES:
		for pair in [[e[0], e[1]], [e[1], e[0]]]:
			if not _adj.has(pair[0]):
				_adj[pair[0]] = []
			_adj[pair[0]].append(pair[1])
	for p in people:
		var f := _figure(str(p[3]), SKINS[_rng.randi() % SKINS.size()])
		f.root.position = Vector3(p[0], p[1], p[2])
		f.root.rotation.y = PI  # facing the guests, which is toward -z
		add_child(f.root)
		f["phase"] = _rng.randf() * TAU
		f["busy"] = true
		staff.append(f)
	var names := NODES.keys()
	for i in PATRONS:
		var f := _figure(COATS[_rng.randi() % COATS.size()], SKINS[_rng.randi() % SKINS.size()])
		var start: String = names[_rng.randi() % names.size()]
		f["node"] = start
		f["pos"] = NODES[start]
		f["path"] = []
		f["wait"] = _rng.randf_range(1.0, 10.0)
		f["speed"] = _rng.randf_range(0.8, 1.25)
		f["phase"] = _rng.randf() * TAU
		f["look"] = Vector2.ZERO
		_place(f)
		add_child(f.root)
		patrons.append(f)


static func _mat(key: String) -> Material:
	if not _mats.has(key):
		_mats[key] = Buildings.mat(key)
	return _mats[key]


static func _skin(c: Color) -> StandardMaterial3D:
	var k := "skin%s" % c.to_html()
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.8
		_mats[k] = m
	return _mats[k]


static func _box(size: Vector3) -> BoxMesh:
	var k := "b%s" % size
	if not _meshes.has(k):
		var b := BoxMesh.new()
		b.size = size
		_meshes[k] = b
	return _meshes[k]


## One person, feet at the origin, facing +z at yaw 0: legs, a coat, a head, two arms hanging from the shoulders.
static func _figure(coat: String, skin: Color) -> Dictionary:
	var root := Node3D.new()
	var part := func(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = pos
		parent.add_child(mi)
		return mi
	part.call(root, _box(Vector3(0.26, 0.78, 0.2)), _mat("black"), Vector3(0, 0.39, 0))
	part.call(root, _box(Vector3(0.44, 0.62, 0.26)), _mat(coat), Vector3(0, 1.08, 0))
	if not _meshes.has("head"):
		var sp := SphereMesh.new()
		sp.radius = 0.12
		sp.height = 0.24
		_meshes["head"] = sp
	part.call(root, _meshes["head"], _skin(skin), Vector3(0, 1.52, 0))
	var arms := []
	for sx in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(sx * 0.28, 1.34, 0)
		root.add_child(pivot)
		part.call(pivot, _box(Vector3(0.09, 0.5, 0.09)), _mat(coat), Vector3(0, -0.25, 0))
		arms.append(pivot)
	return {"root": root, "arm_l": arms[0], "arm_r": arms[1]}


func _place(f: Dictionary) -> void:
	var p: Vector2 = f.pos
	f.root.position = Vector3(p.x, PATIO_Y if p.y > 46.0 else FLOOR_Y, p.y)


func _route(from: String, to: String) -> Array:
	var prev := {from: ""}
	var queue := [from]
	while not queue.is_empty():
		var n: String = queue.pop_front()
		if n == to:
			break
		for m in _adj.get(n, []):
			if not prev.has(m):
				prev[m] = n
				queue.append(m)
	var out := []
	if not prev.has(to):
		return out
	var cur := to
	while cur != from:
		out.push_front(cur)
		cur = prev[cur]
	return out


func _process(dt: float) -> void:
	for f in staff:
		f.phase += dt * (1.6 if f.busy else 0.6)
		var sway: float = sin(f.phase) * 0.04
		f.root.rotation.z = sway * 0.3
		# arms at work: the dealer's hands moving across the felt, the bandsman's on his instrument
		f.arm_r.rotation.x = -0.9 + sin(f.phase * 1.7) * 0.5
		f.arm_l.rotation.x = -0.5 + sin(f.phase * 1.3 + 1.0) * 0.3
	for f in patrons:
		_walk(f, dt)


func _walk(f: Dictionary, dt: float) -> void:
	var path: Array = f.path
	if path.is_empty():
		f.wait -= dt
		f.arm_l.rotation.x = lerpf(f.arm_l.rotation.x, 0.0, dt * 4.0)
		f.arm_r.rotation.x = lerpf(f.arm_r.rotation.x, 0.0, dt * 4.0)
		if f.look != Vector2.ZERO:
			var d: Vector2 = f.look - f.pos
			f.root.rotation.y = lerp_angle(f.root.rotation.y, atan2(d.x, d.y), dt * 3.0)
		if f.wait <= 0.0:
			var names := NODES.keys()
			var to: String = names[_rng.randi() % names.size()]
			if to != f.node:
				f.path = _route(f.node, to)
			f.wait = _rng.randf_range(0.5, 2.0)
		return
	var target: Vector2 = NODES[path[0]]
	var to_t: Vector2 = target - f.pos
	var step: float = f.speed * dt
	f.look = Vector2.ZERO
	if to_t.length() <= step:
		f.pos = target
		f.node = path.pop_front()
		if path.is_empty():
			f.wait = _rng.randf_range(4.0, 14.0)
			f.look = LOOK.get(f.node, Vector2.ZERO)
	else:
		f.pos += to_t.normalized() * step
		f.root.rotation.y = lerp_angle(f.root.rotation.y, atan2(to_t.x, to_t.y), dt * 6.0)
		f.phase += dt * f.speed * 5.0
		f.arm_l.rotation.x = sin(f.phase) * 0.5
		f.arm_r.rotation.x = -sin(f.phase) * 0.5
	_place(f)
