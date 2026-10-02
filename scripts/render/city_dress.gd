class_name CityDress
extends RefCounted
## The city's boxes dressed as buildings. Each box MapCity lays out (a footprint, a height and a style) is
## cut into 1-9 lots, and every lot gets a real model from Kenney's City Kits (assets/models/kenney):
## skyscrapers for the towers, commercial blocks for the shops and flats, the suburban houses where it is
## low, industrial sheds for the warehouses - scaled to the lot and to the box's height, turned to face the
## nearest street, tinted the box's pastel and lit at night by shaders/city_lot.gdshader.
##
## The models are ~1,700 triangles each, so they are drawn only near the camera: in 300 m chunks, one
## MultiMesh per model per chunk, with a visibility range (700 m on high, 450 m medium; none on low, which
## keeps the boxes). Beyond it the box layer, in the same chunks, takes over (a fade margin dithers the
## swap). The boxes' footprints and heights are unchanged, so the sim's obstacle list and the aircraft's
## crash model are what they were; there is no collision on the city's buildings either way.
##
## Behind ENABLED (the render tests turn it off for the box layer) and a missing kit falls back to the boxes.

static var ENABLED := true

const KITS := {
	"commercial": "res://assets/models/kenney/city_commercial/",
	"suburban": "res://assets/models/kenney/city_suburban/",
	"industrial": "res://assets/models/kenney/city_industrial/",
}
## model names by the part they play (the kits' building-* pieces; chimneys and details are not buildings)
const ROLES := {
	"tower": [["commercial", "building-skyscraper-a"], ["commercial", "building-skyscraper-b"], ["commercial", "building-skyscraper-c"],
		["commercial", "building-skyscraper-d"], ["commercial", "building-skyscraper-e"]],
	"mid": [["commercial", "building-a"], ["commercial", "building-b"], ["commercial", "building-c"], ["commercial", "building-d"],
		["commercial", "building-e"], ["commercial", "building-f"], ["commercial", "building-g"], ["commercial", "building-h"],
		["commercial", "building-i"], ["commercial", "building-j"], ["commercial", "building-k"], ["commercial", "building-l"],
		["commercial", "building-m"], ["commercial", "building-n"]],
	"low": [["suburban", "building-type-a"], ["suburban", "building-type-b"], ["suburban", "building-type-c"], ["suburban", "building-type-d"],
		["suburban", "building-type-e"], ["suburban", "building-type-f"], ["suburban", "building-type-g"], ["suburban", "building-type-h"],
		["suburban", "building-type-i"], ["suburban", "building-type-j"], ["suburban", "building-type-k"], ["suburban", "building-type-l"],
		["suburban", "building-type-m"], ["suburban", "building-type-n"], ["suburban", "building-type-o"], ["suburban", "building-type-p"],
		["suburban", "building-type-q"], ["suburban", "building-type-r"], ["suburban", "building-type-s"], ["suburban", "building-type-t"],
		["suburban", "building-type-u"]],
	"ware": [["industrial", "building-a"], ["industrial", "building-b"], ["industrial", "building-c"], ["industrial", "building-d"],
		["industrial", "building-e"], ["industrial", "building-f"], ["industrial", "building-g"], ["industrial", "building-h"],
		["industrial", "building-i"], ["industrial", "building-j"], ["industrial", "building-k"], ["industrial", "building-l"],
		["industrial", "building-m"], ["industrial", "building-n"], ["industrial", "building-o"], ["industrial", "building-p"],
		["industrial", "building-q"], ["industrial", "building-r"], ["industrial", "building-s"], ["industrial", "building-t"]],
}
const CHUNK_M := 300.0
const LOT_M := 16.0  ## the lot a building is cut into, about
const FILL := 0.94  ## how much of its lot a model fills (the rest is the gap between neighbours)
const SINK := 0.4  ## metres into the ground: on a slope no lot shows a gap under its wall
const RANGE_M := {"low": 0.0, "medium": 450.0, "high": 700.0}
const FADE_M := 60.0

static var _models := {}  ## "kit/name" -> {mesh, dim: Vector3, centre: Vector3 (x, base y, z of its AABB), kit}
static var _mats := {}  ## kit -> ShaderMaterial
static var _night := 0.0


## The distance the models are drawn to at quality `q`; 0 when they are off or the kit is not there.
static func draw_range(q: Quality) -> float:
	if not ENABLED or not ModelLib.ENABLED:
		return 0.0
	var r: float = RANGE_M.get(q.name, 450.0)
	if r > 0.0 and model("tower") == null:
		return 0.0
	return r


## A model of `role` by index (null if the kit is absent): see _load.
static func model(role: String, i := 0) -> Variant:
	var list: Array = ROLES[role]
	return _load(list[posmod(i, list.size())])


static func _load(spec: Array) -> Variant:
	var key: String = spec[0] + "/" + spec[1]
	if _models.has(key):
		return _models[key]
	var path: String = KITS[spec[0]] + spec[1] + ".glb"
	var out = null
	if ResourceLoader.exists(path):
		var m: Node3D = (load(path) as PackedScene).instantiate()
		var mis := m.find_children("*", "MeshInstance3D", true, false)
		if not mis.is_empty():
			var mi: MeshInstance3D = mis[0]
			var b := ModelLib.bounds(m)
			var mesh: Mesh = mi.mesh
			# the mesh as drawn: its node's transform inside the scene, baked in if it is not the identity
			var xf := Transform3D.IDENTITY
			var n: Node = mi
			while n != null and n != m.get_parent():
				if n is Node3D:
					xf = (n as Node3D).transform * xf
				n = n.get_parent()
			if not xf.is_equal_approx(Transform3D.IDENTITY):
				var st := SurfaceTool.new()
				for s in mesh.get_surface_count():
					st.append_from(mesh, s, xf)
				mesh = st.commit()
			out = {"mesh": mesh, "dim": b.size, "centre": Vector3(b.get_center().x, b.position.y, b.get_center().z), "kit": spec[0]}
		m.free()
	_models[key] = out
	return out


static func material(kit: String) -> ShaderMaterial:
	if not _mats.has(kit):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/city_lot.gdshader")
		mat.set_shader_parameter("albedo_tex", load(KITS[kit] + "Textures/colormap.png"))
		mat.set_shader_parameter("night", _night)
		_mats[kit] = mat
	return _mats[kit]


static func set_night(n: float) -> void:
	_night = clampf((n - 0.25) / 0.5, 0.0, 1.0)
	for k in _mats:
		(_mats[k] as ShaderMaterial).set_shader_parameter("night", _night)


## Which side of the nearest street a point at (x, y) faces, as a yaw about Y (the kits' fronts are +Z): the town's
## street grid is 110 m blocks from the city's corner (the same grid CityRender places its street furniture on).
static func street_yaw(x: float, y: float) -> float:
	var go: Vector2 = MapCity.CITY_C - MapCity.CITY_R
	var u := fposmod(x - go.x, CityRender.GRID_BLOCK)
	var v := fposmod(y - go.y, CityRender.GRID_BLOCK)
	var du := minf(u, CityRender.GRID_BLOCK - u)
	var dv := minf(v, CityRender.GRID_BLOCK - v)
	var dir := Vector2.ZERO  # in the game's frame (x east, y north)
	if du < dv:
		dir = Vector2(-1.0 if u < CityRender.GRID_BLOCK * 0.5 else 1.0, 0.0)
	else:
		dir = Vector2(0.0, -1.0 if v < CityRender.GRID_BLOCK * 0.5 else 1.0)
	return atan2(dir.x, -dir.y)  # Godot z is -y


## The lots of building `b` (index `i`, which seeds the choices): [{kit, name, xf, colour, roof}], deterministic.
## `roof` is the world y of the top of the model, for the shader's neon strip.
static func lots(b: Dictionary, i: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4177 + i * 7919
	var style: String = b.style
	var nx := clampi(roundi(float(b.w) / LOT_M), 1, 3)
	var nz := clampi(roundi(float(b.d) / LOT_M), 1, 3)
	if style == "warehouse":
		nx = clampi(roundi(float(b.w) / 26.0), 1, 2)
		nz = 1
	var cw: float = float(b.w) / nx
	var cd: float = float(b.d) / nz
	var base_colour: Color = CityRender.PALETTE[rng.randi() % CityRender.PALETTE.size()]
	var out := []
	for ix in nx:
		for iz in nz:
			var role := _role(style, float(b.h), rng)
			var target_h: float = float(b.h) * (rng.randf_range(0.85, 1.1) if style == "tower" else rng.randf_range(0.7, 1.15))
			var spec = _pick(role, cw, cd, target_h, rng)
			if spec == null:
				continue
			var m: Dictionary = spec
			var s := minf(cw * FILL / maxf(0.01, m.dim.x), cd * FILL / maxf(0.01, m.dim.z))
			var sx := minf(cw * FILL / maxf(0.01, m.dim.x), s * 1.3)
			var sz := minf(cd * FILL / maxf(0.01, m.dim.z), s * 1.3)
			var sy := clampf(target_h / maxf(0.01, m.dim.y), 0.8 * s, 1.35 * s)
			var cx: float = float(b.x) + (ix + 0.5 - nx * 0.5) * cw
			var cy: float = float(b.y) + (iz + 0.5 - nz * 0.5) * cd
			var yaw := street_yaw(cx, cy)
			var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sx, sy, sz))
			var ground: float = float(b.z) - SINK
			# the model's origin is wherever its kit put it: stand its base centre on the lot's centre
			var origin := Vector3(cx, ground, -cy) - basis * Vector3(m.centre.x, m.centre.y, m.centre.z)
			var colour := base_colour.lerp(CityRender.PALETTE[rng.randi() % CityRender.PALETTE.size()], 0.2)
			colour.a = 1.0
			out.append({"kit": m.kit, "name": m.name, "xf": Transform3D(basis, origin), "colour": colour, "roof": ground + sy * m.dim.y})
	return out


static func _role(style: String, h: float, rng: RandomNumberGenerator) -> String:
	match style:
		"warehouse":
			return "ware"
		"tower":
			return "tower" if h > 30.0 or rng.randf() < 0.6 else "mid"
		"shop":
			return "low" if h < 9.0 and rng.randf() < 0.5 else "mid"
		_:
			return "low" if h < 11.0 and rng.randf() < 0.6 else "mid"


## The model of `role` that best fits a cw x cd lot and the height wanted, by a pick among the best few (so a street varies).
static func _pick(role: String, cw: float, cd: float, target_h: float, rng: RandomNumberGenerator) -> Variant:
	var list: Array = ROLES[role]
	var scored := []
	for k in list.size():
		var m = _load(list[k])
		if m == null:
			continue
		var s := minf(cw * FILL / maxf(0.01, m.dim.x), cd * FILL / maxf(0.01, m.dim.z))
		var squash := absf(log(maxf(0.05, target_h / maxf(0.01, s * m.dim.y))))
		scored.append([squash + rng.randf() * 0.25, k])
	if scored.is_empty():
		return null
	scored.sort_custom(func(a, b): return a[0] < b[0])
	var top: Array = scored[rng.randi() % mini(3, scored.size())]
	var spec: Array = list[top[1]]
	var m: Dictionary = (_load(spec) as Dictionary).duplicate()
	m["name"] = spec[1]
	return m


## The chunk a building is in.
static func chunk_of(b: Dictionary) -> Vector2i:
	return Vector2i(floori(float(b.x) / CHUNK_M), floori(float(b.y) / CHUNK_M))


## The buildings as a node: per chunk, the shader boxes (drawn beyond the models' range) and the dressed lots (within it).
static func build(boxes: Array, q: Quality) -> Node3D:
	var root := Node3D.new()
	root.name = "buildings"
	var reach := draw_range(q)
	var by_chunk := {}
	for i in boxes.size():
		var c := chunk_of(boxes[i])
		if not by_chunk.has(c):
			by_chunk[c] = []
		by_chunk[c].append(i)
	var shadows := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if q.shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in by_chunk:
		var idx: Array = by_chunk[c]
		var node := Node3D.new()
		node.name = "chunk-%d-%d" % [c.x, c.y]
		root.add_child(node)
		# the boxes: far away, or everywhere when the models are off
		var far := CityRender.box_layer(idx.map(func(i): return boxes[i]), q, idx)
		if reach > 0.0:
			far.visibility_range_begin = reach
			far.visibility_range_begin_margin = FADE_M
			far.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.add_child(far)
		if reach <= 0.0:
			continue
		var groups := {}  # "kit/name" -> [xfs, colours, roofs]
		for i in idx:
			for lot in lots(boxes[i], i):
				var key: String = lot.kit + "/" + lot.name
				if not groups.has(key):
					groups[key] = [lot.kit, lot.name, [], [], []]
				groups[key][2].append(lot.xf)
				groups[key][3].append(lot.colour)
				groups[key][4].append(lot.roof)
		for key in groups:
			var g: Array = groups[key]
			var m: Dictionary = _load([g[0], g[1]])
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = m.mesh
			mm.instance_count = g[2].size()
			for k in g[2].size():
				mm.set_instance_transform(k, g[2][k])
				mm.set_instance_color(k, g[3][k])
				mm.set_instance_custom_data(k, Color(g[4][k], 0.0, 0.0, 0.0))
			var mmi := MultiMeshInstance3D.new()
			mmi.name = g[1]
			mmi.multimesh = mm
			mmi.material_override = material(g[0])
			mmi.cast_shadow = shadows
			mmi.visibility_range_end = reach + FADE_M
			mmi.visibility_range_end_margin = FADE_M
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			node.add_child(mmi)
	return root
