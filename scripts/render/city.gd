class_name CityRender
extends RefCounted
## What MapCity puts on the ground: the city's buildings (one MultiMesh of unit
## boxes with the window shader, so thousands stay cheap), cranes on the docks,
## roads as ribbons draped on the terrain, street lamps through town and the
## stash houses. The buildings drawn here are the obstacles in the physics
## tree list (MapCity.post), so what you see is what you hit.

## Pastel deco: flamingo, mint, lilac, peach, cream, sea-foam, lemon (the shader adds trim and neon).
const PALETTE := [Color(0.96, 0.7, 0.76), Color(0.68, 0.9, 0.8), Color(0.8, 0.72, 0.93), Color(0.99, 0.8, 0.64),
	Color(0.97, 0.94, 0.88), Color(0.6, 0.86, 0.88), Color(0.97, 0.91, 0.66), Color(0.93, 0.87, 0.8)]

static var _mat: ShaderMaterial
static var _lamp_mat: StandardMaterial3D
static var _road_mat: StandardMaterial3D


static func city_material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/city.gdshader")
		_mat.set_shader_parameter("noise_pack", TexGen.noise_pack())
	return _mat


## Wet asphalt after rain: darker, and it shines.
static func set_wet(w: float) -> void:
	if _road_mat != null:
		_road_mat.albedo_color = Color(0.2, 0.2, 0.21).darkened(0.35 * w)
		_road_mat.roughness = lerpf(0.95, 0.25, w)


static func set_night(n: float) -> void:
	CityDress.set_night(n)
	if _mat != null:
		_mat.set_shader_parameter("night", clampf((n - 0.25) / 0.5, 0.0, 1.0))
	if _lamp_mat != null:
		_lamp_mat.emission_energy_multiplier = 4.0 * clampf((n - 0.3) / 0.4, 0.0, 1.0)


static func build(world: World, q: Quality) -> Node3D:
	var root := Node3D.new()
	root.name = "city"
	var l := world.map
	if l.buildings.is_empty() and l.roads.is_empty():
		return root
	root.add_child(CityDress.build(l.buildings.filter(func(b): return b.style != "crane"), q))  # the boxes, and the models near the camera
	for b in l.buildings:
		if b.style == "crane":
			root.add_child(_crane(b))
	root.add_child(_roads(world, l.roads))
	root.add_child(_road_details(world, l.roads))
	root.add_child(_bridges(world, l.roads, l.bridges))
	root.add_child(_lamps(world, l.roads))
	root.add_child(_props(world, l.roads))
	root.add_child(_palms(world, l.roads, q))
	for st in l.stashes:
		root.add_child(stash_house(world, st))
	return root


## The shader boxes for `boxes` (the city's buildings, or one chunk of them). `idx` is each box's number in the whole
## list, which seeds its colour, so a box is the same colour whichever chunk it is drawn in.
static func box_layer(boxes: Array, q: Quality, idx := []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	mm.mesh = bm
	mm.instance_count = boxes.size()
	var rng := RandomNumberGenerator.new()
	for i in boxes.size():
		rng.seed = 77 + (idx[i] if not idx.is_empty() else i) * 104729
		var b: Dictionary = boxes[i]
		var h: float = b.h + 1.5  # sunk 1.5 m: sloping lots never show a gap under the wall
		var basis := Basis.IDENTITY.scaled(Vector3(b.w, h, b.d))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(b.x, b.z - 1.5 + h / 2, -b.y)))
		var col: Color
		match b.style:
			"warehouse":
				col = Color(0.56, 0.50, 0.44).lerp(Color(0.45, 0.52, 0.58), rng.randf())
				col.a = 0.0
			"tower":
				col = Color(0.60, 0.64, 0.68).lerp(Color(0.80, 0.78, 0.72), rng.randf())
				col.a = 1.0
			_:
				col = PALETTE[rng.randi() % PALETTE.size()]
				col.a = 1.0
		mm.set_instance_color(i, col)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "buildings"
	mmi.multimesh = mm
	mmi.material_override = city_material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if q.shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


static func _crane(b: Dictionary) -> Node3D:
	var k := Buildings.Kit.new("crane")
	var h: float = b.h
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			k.box(Vector3(sx * 4.0, 4.0, sz * 4.0), Vector3(0.8, 8.0, 0.8), "orange", false)  # portal legs
	k.box(Vector3(0, 8.4, 0), Vector3(9.5, 0.8, 9.5), "orange", false)
	k.box(Vector3(0, 8.8 + (h - 8.8) / 2, 0), Vector3(2.2, h - 8.8, 2.2), "orange", false)
	k.box(Vector3(0, h, -14.0), Vector3(1.6, 1.4, 40.0), "orange", false)  # boom out over the water
	k.box(Vector3(0, h + 1.8, 2.0), Vector3(3.0, 2.2, 4.0), "white", false)  # cab
	k.box(Vector3(0, h - 0.5, 9.0), Vector3(3.0, 2.0, 5.0), "concrete_dark", false)  # counterweight
	var n := k.finish()
	n.position = Vector3(b.x, b.z, -b.y)
	return n


## Roads: a 9 m ribbon a little above the ground, a deck over water (bridges).
static func _roads(world: World, roads: Array) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in roads:
		var pts := PackedVector2Array()
		for k in r.size() - 1:
			var a := Vector2(r[k][0], r[k][1])
			var b := Vector2(r[k + 1][0], r[k + 1][1])
			var n := int(a.distance_to(b) / 12.0) + 1
			for q in n:
				pts.append(a.lerp(b, float(q) / n))
		pts.append(Vector2(r[r.size() - 1][0], r[r.size() - 1][1]))
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for k in pts.size():
			var dir := (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
			var side := Vector2(-dir.y, dir.x) * 4.5
			var zs := []
			for p in [pts[k] + side, pts[k] - side, pts[k]]:
				zs.append(world.ground(p.x, p.y))
			var z := maxf(maxf(zs[0], zs[1]), maxf(zs[2], 2.2)) + 0.45
			var lp := Vector3(pts[k].x + side.x, z, -(pts[k].y + side.y))
			var rp := Vector3(pts[k].x - side.x, z, -(pts[k].y - side.y))
			if k > 0:
				for v in [prev_l, lp, rp, prev_l, rp, prev_r]:
					st.set_normal(Vector3.UP)
					st.add_vertex(v)
			prev_l = lp
			prev_r = rp
	var mi := MeshInstance3D.new()
	mi.name = "roads"
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.2, 0.21)
	m.roughness = 0.95
	_road_mat = m
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The samples of one road, every ~12 m (the same ones _roads() drapes its ribbon on): [position, along-road
## direction, the ribbon's height there].
static func _samples(world: World, r: Array) -> Array:
	var pts := PackedVector2Array()
	for k in r.size() - 1:
		var a := Vector2(r[k][0], r[k][1])
		var b := Vector2(r[k + 1][0], r[k + 1][1])
		var n := int(a.distance_to(b) / 12.0) + 1
		for q in n:
			pts.append(a.lerp(b, float(q) / n))
	pts.append(Vector2(r[r.size() - 1][0], r[r.size() - 1][1]))
	var out := []
	for k in pts.size():
		var dir := (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
		var side := Vector2(-dir.y, dir.x) * 4.5
		var zs := []
		for p in [pts[k] + side, pts[k] - side, pts[k]]:
			zs.append(world.ground(p.x, p.y))
		out.append([pts[k], dir, maxf(maxf(zs[0], zs[1]), maxf(zs[2], 2.2)) + 0.45])
	return out


## A flat strip from lateral offset `lo` to `hi` (metres from the centre line) between samples k-1 and k, `up` above the ribbon.
static func _strip(st: SurfaceTool, s0: Array, s1: Array, lo: float, hi: float, up: float, col: Color) -> void:
	var corners := []
	for s in [s0, s1]:
		var dir: Vector2 = s[1]
		var side := Vector2(-dir.y, dir.x)
		var p: Vector2 = s[0]
		var z: float = s[2] + up
		corners.append([Vector3(p.x + side.x * lo, z, -(p.y + side.y * lo)), Vector3(p.x + side.x * hi, z, -(p.y + side.y * hi))])
	for v in [corners[0][0], corners[1][0], corners[1][1], corners[0][0], corners[1][1], corners[0][1]]:
		st.set_normal(Vector3.UP)
		st.set_color(col)
		st.add_vertex(v)


## Lane markings and sidewalks. The markings are painted on the ribbon: a dashed yellow centre line and
## continuous white edge lines, a hair above the asphalt. In town (and the port) a pale concrete pavement runs
## along both sides, a kerb's height up, from the road's edge to 6.9 m - where the lamps, hydrants, benches
## and palms already stand.
static func _road_details(world: World, roads: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "road-details"
	var paint := SurfaceTool.new()
	paint.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pave := SurfaceTool.new()
	pave.begin(Mesh.PRIMITIVE_TRIANGLES)
	var yellow := Color(0.95, 0.78, 0.18)
	var white := Color(0.9, 0.9, 0.88)
	var concrete := Color(0.66, 0.65, 0.62)
	var kerb := Color(0.5, 0.5, 0.48)
	for r in roads:
		var smp := _samples(world, r)
		for k in range(1, smp.size()):
			var s0: Array = smp[k - 1]
			var s1: Array = smp[k]
			var p0: Vector2 = s0[0]
			var p1: Vector2 = s1[0]
			var seg_len := p0.distance_to(p1)
			if seg_len < 0.5:
				continue
			# edge lines, continuous
			_strip(paint, s0, s1, 3.7, 3.98, 0.03, white)
			_strip(paint, s0, s1, -3.98, -3.7, 0.03, white)
			# the centre line: a 3.6 m dash in each 12 m
			var dash0 := _lerp_sample(s0, s1, 0.15)
			var dash1 := _lerp_sample(s0, s1, minf(1.0, 0.15 + 4.2 / seg_len))
			_strip(paint, dash0, dash1, -0.17, 0.17, 0.03, yellow)
			# the pavement, where the street is a street
			var mid := (p0 + p1) * 0.5
			var cls := MapCity.at(world.map.land_use, mid.x, mid.y)
			if cls in [MapCity.URBAN, MapCity.PORT]:
				for sgn in [-1.0, 1.0]:
					var lo: float = 4.5 if sgn > 0.0 else -6.9
					var hi: float = 6.9 if sgn > 0.0 else -4.5
					_strip(pave, s0, s1, lo, hi, 0.14, concrete)
					# the kerb face, a thin strip standing on the road's edge
					var edge: float = 4.5 * sgn
					var a0 := _edge_pt(s0, edge, 0.0)
					var a1 := _edge_pt(s1, edge, 0.0)
					var b0 := _edge_pt(s0, edge, 0.14)
					var b1 := _edge_pt(s1, edge, 0.14)
					var face := [a0, a1, b1, a0, b1, b0] if sgn > 0.0 else [a0, b1, a1, a0, b0, b1]
					var d0: Vector2 = s0[1]
					var nrm := Vector3(-d0.y, 0.0, -d0.x) * (1.0 if sgn > 0.0 else -1.0)
					for v in face:
						pave.set_normal(nrm.normalized())
						pave.set_color(kerb)
						pave.add_vertex(v)
	for pair in [[paint, "markings", 0.7], [pave, "pavements", 0.9]]:
		var mi := MeshInstance3D.new()
		mi.name = pair[1]
		mi.mesh = (pair[0] as SurfaceTool).commit()
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = pair[2]
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 2500.0
		root.add_child(mi)
	return root


static func _lerp_sample(a: Array, b: Array, t: float) -> Array:
	return [(a[0] as Vector2).lerp(b[0], t), a[1], lerpf(a[2], b[2], t)]


static func _edge_pt(s: Array, lateral: float, up: float) -> Vector3:
	var dir: Vector2 = s[1]
	var side := Vector2(-dir.y, dir.x)
	var p: Vector2 = s[0]
	return Vector3(p.x + side.x * lateral, s[2] + up, -(p.y + side.y * lateral))


## The deck height at a road point: over the highest of the ground under the ribbon, and 2.2 m over the sea.
static func deck_z(world: World, p: Vector2, side: Vector2) -> float:
	return maxf(maxf(world.ground(p.x + side.x, p.y + side.y), world.ground(p.x - side.x, p.y - side.y)),
		maxf(world.ground(p.x, p.y), 2.2)) + 0.45


## Bridges where a road crosses water (RoadPlanner found them): piers down to the bed every 30 m, and
## railings along both edges of the deck. `bridges`: [{road, from, to}] in metres along the road.
static func _bridges(world: World, roads: Array, bridges: Array) -> MeshInstance3D:
	var mb := MeshBuilder.new()
	var concrete := [0.56, 0.56, 0.54]
	var steel := [0.78, 0.78, 0.76]
	for b in bridges:
		var r: Array = roads[int(b.road)]
		var route := PackedVector2Array()
		for p in r:
			route.append(Vector2(p[0], p[1]))
		var total := RoadGraph.length(route)
		var s0 := clampf(float(b["from"]), 0.0, total)
		var s1 := clampf(float(b["to"]), 0.0, total)
		var prev_l := []
		var prev_r := []
		var have_prev := false
		var s := s0
		var next_pier := s0
		while s <= s1 + 0.01:
			var p := RoadGraph.along(route, s)
			var ahead := RoadGraph.along(route, minf(s + 3.0, total))
			var behind := RoadGraph.along(route, maxf(s - 3.0, 0.0))
			var dir := (ahead - behind).normalized()
			var side := Vector2(-dir.y, dir.x) * 4.6
			var z := deck_z(world, p, side * (4.5 / 4.6))
			var lp := [p.x + side.x, p.y + side.y]
			var rp := [p.x - side.x, p.y - side.y]
			if have_prev:
				for e in [[prev_l, lp], [prev_r, rp]]:
					mb.quad([e[0][0], e[0][1], e[0][2] + 0.45], [e[1][0], e[1][1], z + 0.45], [e[1][0], e[1][1], z + 1.5], [e[0][0], e[0][1], e[0][2] + 1.5], steel)
			if s >= next_pier:
				var bed := world.terrain.height(p.x, p.y)
				if bed < z - 2.0:
					mb.box(p.x, p.y, (bed + z - 0.3) / 2.0, 2.4, 2.4, z - 0.3 - bed, concrete)
				next_pier += 30.0
			prev_l = [lp[0], lp[1], z]
			prev_r = [rp[0], rp[1], z]
			have_prev = true
			s += 6.0
	var node := mb.node("bridges")
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## KayKit's City Builder Bits (CC0, assets/models/kaykit/city): each part's
## scale to real metres (the kit is about a road tile to the unit).
const KIT := "res://assets/models/kaykit/city/%s.gltf"
const KIT_SCALE := {"streetlight": 7.5, "trafficlight_A": 6.5, "firehydrant": 4.0, "bench": 4.5, "dumpster": 5.0, "trash_A": 5.0}
const LAMP_ARM := Vector3(-0.21, 0.93, 0.0)
const GRID_BLOCK := 110.0  ## the town's street grid (terrain_splat.gdshader's `block`)  ## the lamp head on the kit's pole, in kit units


## The first mesh in a KayKit part (null when the kit isn't there).
static func kit_mesh(part: String) -> Mesh:
	if not ResourceLoader.exists(KIT % part):
		return null
	var scn := (load(KIT % part) as PackedScene).instantiate()
	var found: Mesh = null
	var stack := [scn]
	while not stack.is_empty() and found == null:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			found = n.mesh
		stack.append_array(n.get_children())
	scn.free()
	return found


static func _mm_of(mesh: Mesh, xfs: Array, name_: String, range_end: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name_
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = range_end
	return mmi


## Street lamps along the roads in town, every 45 m on alternate sides: KayKit's
## pole with its arm over the road, and a glowing head that lights up at night.
static func _lamps(world: World, roads: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "lamps"
	var poles := []
	var heads := []
	var k: float = KIT_SCALE.streetlight
	for r in roads:
		var run := 0.0
		for i in r.size() - 1:
			var a := Vector2(r[i][0], r[i][1])
			var b := Vector2(r[i + 1][0], r[i + 1][1])
			var dir := (b - a).normalized()
			var side := Vector2(-dir.y, dir.x)
			var d := 0.0
			while d < a.distance_to(b):
				var s := 1.0 if int(run / 45.0) % 2 == 0 else -1.0
				var p := a + dir * d + side * 5.3 * s  # the kerb: the road is 9 m wide, palms at 6.2 m, buildings from 7 m
				var cls := MapCity.at(world.map.land_use, p.x, p.y)
				if cls in [MapCity.URBAN, MapCity.PORT] or world.airfield_at(p.x, p.y, 200.0) != null:
					var g := world.ground(p.x, p.y)
					# the kit's arm reaches along -x: turn it to point back over the road
					var toward := Vector3(-side.x * s, 0, side.y * s)
					var basis := Basis(Vector3.UP, atan2(toward.z, -toward.x)).scaled(Vector3.ONE * k)
					var base := Vector3(p.x, g, -p.y)
					poles.append(Transform3D(basis, base))
					heads.append(Transform3D(Basis.IDENTITY, base + basis * LAMP_ARM + Vector3(0, -0.25, 0)))
				d += 45.0
				run += 45.0
	var pole := kit_mesh("streetlight")
	if pole != null:
		root.add_child(_mm_of(pole, poles, "poles", 3500.0))
	var sm := SphereMesh.new()
	sm.radius = 0.4
	sm.height = 0.5
	sm.radial_segments = 6
	sm.rings = 3
	if pole == null:  # no kit: the old floating heads at the top of an invisible pole
		heads = poles.map(func(x): return Transform3D(Basis.IDENTITY, x.origin + Vector3(0, 7.0, 0)))
	var mmi := _mm_of(sm, heads, "heads", 6000.0)
	var at := PackedVector3Array()
	for h in heads:
		at.append((h as Transform3D).origin)
	root.set_meta("heads", at)  # where StreetLights puts its real lights
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color(1.0, 0.8, 0.5)
	_lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1.0, 0.75, 0.45)
	_lamp_mat.emission_energy_multiplier = 0.0
	mmi.material_override = _lamp_mat
	root.add_child(mmi)
	return root


## Street furniture (KayKit): traffic lights at the town's junctions, and along
## its streets fire hydrants, benches, dumpsters and bins, spaced out.
static func _props(world: World, roads: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "street-props"
	var xfs := {"trafficlight_A": [], "firehydrant": [], "bench": [], "dumpster": [], "trash_A": []}
	# junctions: the ground war's road graph merges crossings; three or more ways in town
	var g := RoadGraph.new(roads)
	for i in g.road_nodes:
		if g.adj[i].size() < 3:
			continue
		var c: Vector2 = g.nodes[i]
		if MapCity.at(world.map.land_use, c.x, c.y) != MapCity.URBAN:
			continue
		for corner in [Vector2(7, 7), Vector2(-7, -7)]:
			var p: Vector2 = c + corner
			xfs.trafficlight_A.append(_prop_xf(world, p, atan2(corner.x, corner.y), KIT_SCALE.trafficlight_A))
	# and where the town's painted street grid (terrain_splat.gdshader: 110 m blocks
	# from the city's corner) crosses the arterials - every third crossing
	var go: Vector2 = MapCity.CITY_C - MapCity.CITY_R
	var k := 0
	for r in roads:
		for i in r.size() - 1:
			var a := Vector2(r[i][0], r[i][1])
			var b := Vector2(r[i + 1][0], r[i + 1][1])
			for axis in [0, 1]:
				var lo := minf(a[axis], b[axis])
				var hi := maxf(a[axis], b[axis])
				if hi - lo < 1.0:
					continue
				var line := ceilf((lo - go[axis]) / GRID_BLOCK) * GRID_BLOCK + go[axis]
				while line <= hi:
					var t := (line - a[axis]) / (b[axis] - a[axis])
					var p := a.lerp(b, t)
					if MapCity.at(world.map.land_use, p.x, p.y) == MapCity.URBAN:
						k += 1
						if k % 3 == 0:
							var dir := (b - a).normalized()
							var side := Vector2(-dir.y, dir.x) * (5.3 if k % 2 == 0 else -5.3)
							xfs.trafficlight_A.append(_prop_xf(world, p + side + dir * 7.0, atan2(-dir.x, -dir.y), KIT_SCALE.trafficlight_A))
					line += GRID_BLOCK
	var order := ["firehydrant", "bench", "trash_A", "dumpster"]
	var n := 0
	for r in roads:
		var run := 0.0
		for i in r.size() - 1:
			var a := Vector2(r[i][0], r[i][1])
			var b := Vector2(r[i + 1][0], r[i + 1][1])
			var dir := (b - a).normalized()
			var side := Vector2(-dir.y, dir.x)
			var d := 22.0
			while d < a.distance_to(b):
				var s := -1.0 if int(run / 90.0) % 2 == 0 else 1.0
				var p := a + dir * d + side * 5.6 * s
				if MapCity.at(world.map.land_use, p.x, p.y) == MapCity.URBAN:
					var part: String = order[n % order.size()]
					n += 1
					xfs[part].append(_prop_xf(world, p, atan2(-side.x * s, -side.y * s), KIT_SCALE[part]))
				d += 90.0
				run += 90.0
	for part in xfs:
		var m := kit_mesh(part)
		if m != null and not xfs[part].is_empty():
			root.add_child(_mm_of(m, xfs[part], part, 1500.0))
	return root


static func _prop_xf(world: World, p: Vector2, yaw: float, k: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * k), Vector3(p.x, world.ground(p.x, p.y), -p.y))


## Palms down both sides of the town's streets and along the waterfront, every 28 m.
static func _palms(world: World, roads: Array, q: Quality) -> MultiMeshInstance3D:
	var spots := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for r in roads:
		for k in r.size() - 1:
			var a := Vector2(r[k][0], r[k][1])
			var b := Vector2(r[k + 1][0], r[k + 1][1])
			var dir := (b - a).normalized()
			var side := Vector2(-dir.y, dir.x)
			var d := 14.0
			while d < a.distance_to(b):
				for sgn in [-1.0, 1.0]:
					var p: Vector2 = a + dir * d + side * sgn * 6.2  # on the kerb (the buildings keep 7 m off the centreline)
					# the cells beside the carriageway are ROAD: judge the neighbourhood a little further out
					var nb: Vector2 = p + side * sgn * 18.0
					var cls := MapCity.at(world.map.land_use, nb.x, nb.y)
					if cls in [MapCity.URBAN, MapCity.PORT, MapCity.BEACH] and world.ground(p.x, p.y) > 0.5:
						spots.append(Vector3(p.x, world.ground(p.x, p.y), -p.y))
				d += 28.0
	# the Nature Kit's palms (tall and bent, alternating), else the procedural one
	var kit := [ModelLib.palm_mesh(0, 1.0), ModelLib.palm_mesh(1, 1.0)]
	var groups := [[], []]
	for i in spots.size():
		groups[i % 2 if not kit[1].is_empty() else 0].append(spots[i])
	var out: MultiMeshInstance3D = null
	for g in 2:
		if g == 1 and (kit[0].is_empty() or groups[1].is_empty()):
			break
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = kit[g][0] if not kit[0].is_empty() else Vegetation._palm(5 if q.name == "low" else 6)
		var unit: float = kit[g][1] if not kit[0].is_empty() else 1.0  # model units per metre of height
		mm.instance_count = groups[g].size()
		for i in groups[g].size():
			var s := rng.randf_range(9.0, 13.0) * unit
			var bs := Basis.from_euler(Vector3(rng.randf_range(-0.05, 0.05), rng.randf() * TAU, rng.randf_range(-0.05, 0.05))).scaled(Vector3(s, s, s))
			mm.set_instance_transform(i, Transform3D(bs, groups[g][i]))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "street-palms" if g == 0 else "street-palms-bent"
		mmi.multimesh = mm
		if kit[0].is_empty():
			# the procedural palm is built for the (double-sided) foliage shader: draw both faces
			var pm := StandardMaterial3D.new()
			pm.vertex_color_use_as_albedo = true
			pm.roughness = 0.85
			pm.cull_mode = BaseMaterial3D.CULL_DISABLED
			mmi.material_override = pm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if q.shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# no visibility range: it's measured to the batch's AABB centre, and the
		# palms line roads across the whole island (it culled every one of them)
		if out == null:
			out = mmi
		else:
			out.add_child(mmi)
			mmi.transform = Transform3D.IDENTITY
	return out


## A stash house by its kind: a barn, a shack on stilts, a dockside warehouse,
## a lock-up, tents under the canopy, a quarry shed, a boathouse, a villa.
static func stash_house(world: World, st: Dictionary) -> Node3D:
	var k := Buildings.Kit.new("stash-" + st.id)
	match st.kind:
		"barn":
			k.box(Vector3(0, 3.0, 0), Vector3(12, 6, 18), "red")
			k.gable(Vector3(0, 6.0, 0), 12, 18, 3.5, "metal_rust")
		"shack":
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					k.box(Vector3(sx * 2.6, 0.9, sz * 2.0), Vector3(0.25, 1.8, 0.25), "wood")
			k.box(Vector3(0, 3.0, 0), Vector3(6, 2.4, 5), "wood")
			k.gable(Vector3(0, 4.2, 0), 6, 5, 1.4, "metal_rust")
		"warehouse":
			k.box(Vector3(0, 5.0, 0), Vector3(30, 10, 18), "metal")
			k.box(Vector3(0, 2.2, -9.05), Vector3(6, 4.4, 0.1), "black", false)
			k.box(Vector3(9, 8.5, -9.1), Vector3(5, 1.2, 0.1), "white", false)  # "7"
		"lockup":
			for i in 4:
				k.box(Vector3(-6 + i * 4.0, 1.4, 0), Vector3(3.8, 2.8, 6), "concrete")
				k.box(Vector3(-6 + i * 4.0, 1.2, -3.05), Vector3(3.2, 2.4, 0.08), "metal_rust", false)
		"camp":
			for p in [[0, 0], [7, 3], [-6, 4]]:
				k.gable(Vector3(p[0], 0.2, p[1]), 5, 7, 2.6, "green", 0.2)
			k.box(Vector3(2, 0.5, -6), Vector3(3, 1.0, 2), "wood")
		"shed":
			Buildings.shed(k, Vector3(0, 0, 0), 9, 6, "metal_rust")
		"boathouse":
			k.box(Vector3(0, 2.5, 0), Vector3(8, 5, 14), "wood")
			k.gable(Vector3(0, 5.0, 0), 8, 14, 2.0, "metal_rust")
			k.box(Vector3(0, 0.3, -12), Vector3(3, 0.6, 10), "wood")  # the jetty
		_:
			k.box(Vector3(0, 2.0, 0), Vector3(14, 4, 10), "stucco_pink")
			k.gable(Vector3(0, 4.0, 0), 14, 10, 2.4, "terracotta", 0.8)
			k.box(Vector3(0, -0.2, -9), Vector3(8, 0.4, 4), "concrete", false)
	var n := k.finish()
	var z := world.ground(st.x, st.y)
	n.position = Vector3(st.x, z, -st.y)
	n.set_meta("stash", st.id)
	return n
