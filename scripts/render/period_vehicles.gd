class_name PeriodVehicles
extends RefCounted
## Original late-1970s/1980s road vehicles. Existing model keys are retained so
## the dealer, squads and saved vehicle IDs need no migration. Metres, -Z front,
## tyres at y=0; appearance only, with collision/handling owned by callers.
##
## Each body is authored at the published dimensions of a real car of its class
## (SPEC, owner's ask 24 Nov 2026: "the manufacturing details of cars of that era"):
## overall length, width and height, wheelbase, front overhang, tyre size and where
## the glasshouse sits along the body. The game's cars are fictional (no makes or
## badges); the reference car only sets the proportions. The caller's length then
## scales the whole body uniformly, so a 4.6 m request of a 4.9 m sedan keeps the
## sedan's shape. Sources and which figures are estimates: docs/DESIGN.md section 102.

const TYPES := {
	"sedan": "coupe", "sedan-sports": "sport", "hatchback-sports": "hatch",
	"suv": "utility", "suv-luxury": "luxury", "police": "patrol", "taxi": "taxi",
	"van": "van", "truck-flat": "pickup", "delivery": "delivery",
	"ambulance": "ambulance", "truck": "armoured"
}
const PAINT := {
	"coupe": Color(0.23, 0.47, 0.46), "sport": Color(0.88, 0.84, 0.72),
	"hatch": Color(0.67, 0.27, 0.17), "utility": Color(0.56, 0.22, 0.14),
	"luxury": Color(0.22, 0.29, 0.34), "patrol": Color(0.13, 0.18, 0.23),
	"taxi": Color(0.83, 0.62, 0.12), "van": Color(0.72, 0.70, 0.60),
	"pickup": Color(0.39, 0.43, 0.28), "delivery": Color(0.66, 0.61, 0.48),
	"ambulance": Color(0.82, 0.79, 0.66), "armoured": Color(0.30, 0.37, 0.36)
}
## The reference dimensions, metres. len/wid/hgt overall; wb wheelbase; fo front overhang; tyre radius; belt the waistline
## height; glass = where the glasshouse starts, its roof begins and ends, and where it closes, as fractions of the length from the
## nose. `ref` names the class of real car the figures come from (published spec unless marked est.).
const SPEC := {
	"coupe": {"len": 4.90, "wid": 1.82, "hgt": 1.35, "wb": 2.75, "fo": 0.95, "tyre": 0.33, "belt": 0.80, "glass": [0.34, 0.45, 0.66, 0.77], "body": "three_box", "ref": "1978 GM A-body mid-size sedan: 4,895 x 1,816 x 1,354 mm, wb 2,745"},
	"sport": {"len": 4.23, "wid": 1.72, "hgt": 1.12, "wb": 2.34, "fo": 0.98, "tyre": 0.31, "belt": 0.70, "glass": [0.34, 0.45, 0.57, 0.80], "body": "mid_engine", "ref": "1979 Italian mid-engine V8 berlinetta: 4,230 x 1,720 x 1,120 mm, wb 2,340"},
	"hatch": {"len": 3.71, "wid": 1.61, "hgt": 1.41, "wb": 2.40, "fo": 0.72, "tyre": 0.29, "belt": 0.86, "glass": [0.30, 0.41, 0.82, 0.97], "body": "two_box", "ref": "1979 European C-segment hatchback: 3,705 x 1,610 x 1,410 mm, wb 2,400"},
	"utility": {"len": 4.58, "wid": 2.01, "hgt": 1.92, "wb": 2.64, "fo": 0.86, "tyre": 0.39, "belt": 1.17, "glass": [0.31, 0.39, 0.95, 0.985], "body": "two_box", "ref": "1979 US full-size 4x4 utility: 4,580 x 2,014 x 1,918 mm, wb 2,642"},
	"luxury": {"len": 5.61, "wid": 1.94, "hgt": 1.41, "wb": 3.08, "fo": 1.05, "tyre": 0.36, "belt": 0.86, "glass": [0.37, 0.47, 0.68, 0.77], "body": "three_box", "ref": "1980 US luxury sedan: 5,613 x 1,941 x 1,412 mm, wb 3,084"},
	"patrol": {"len": 5.36, "wid": 1.97, "hgt": 1.41, "wb": 2.90, "fo": 1.06, "tyre": 0.35, "belt": 0.85, "glass": [0.36, 0.46, 0.67, 0.77], "body": "three_box", "ref": "1983 US full-size sedan (police package): 5,359 x 1,968 x 1,412 mm, wb 2,903"},
	"taxi": {"len": 5.20, "wid": 1.93, "hgt": 1.59, "wb": 3.05, "fo": 0.93, "tyre": 0.36, "belt": 0.95, "glass": [0.33, 0.40, 0.74, 0.80], "body": "three_box", "ref": "1981 US purpose-built cab: 5,202 x 1,930 x 1,595 mm, wb 3,048"},
	"van": {"len": 4.72, "wid": 2.01, "hgt": 2.03, "wb": 3.15, "fo": 0.62, "tyre": 0.37, "belt": 1.10, "glass": [0.04, 0.15, 0.22, 0.22], "body": "van", "ref": "1983 US full-size van, short body: 4,724 x 2,007 x 2,032 mm, wb 3,150"},
	"pickup": {"len": 5.29, "wid": 2.01, "hgt": 1.86, "wb": 3.38, "fo": 0.85, "tyre": 0.38, "belt": 1.12, "glass": [0.28, 0.34, 0.46, 0.48], "body": "pickup", "ref": "1980 US half-ton pickup, long bed: 5,291 x 2,007 x 1,857 mm, wb 3,378"},
	"delivery": {"len": 5.80, "wid": 2.20, "hgt": 2.75, "wb": 3.56, "fo": 0.55, "tyre": 0.42, "belt": 1.25, "glass": [0.0, 0.06, 0.15, 0.17], "body": "step", "ref": "est.: 1980 US one-ton walk-in step van, 140 in wheelbase"},
	"ambulance": {"len": 5.74, "wid": 2.29, "hgt": 2.62, "wb": 3.51, "fo": 0.82, "tyre": 0.38, "belt": 1.15, "glass": [0.05, 0.16, 0.24, 0.26], "body": "box", "ref": "est.: 1980s Type III modular ambulance on a one-ton van cutaway, 138 in wb, 226 in long"},
	"armoured": {"len": 6.40, "wid": 2.40, "hgt": 2.75, "wb": 3.80, "fo": 1.05, "tyre": 0.48, "belt": 1.30, "glass": [0.16, 0.22, 0.30, 0.31], "body": "box", "ref": "est.: 1980 US medium-duty cash-in-transit truck"},
}
static var _meshes := {}


## A model key's reference length (0 for a kit name this file doesn't draw).
static func length_of(file: String) -> float:
	return float(SPEC[TYPES[file]].len) if TYPES.has(file) else 0.0


## Cache authored geometry, but return a fresh transform node for every vehicle.
static func build(file: String, length: float) -> Node3D:
	if not TYPES.has(file) or length <= 0:
		return null
	if not _meshes.has(file):
		_meshes[file] = _author(str(TYPES[file]))
	var node := Node3D.new()
	node.name = file
	node.set_meta("period_style", TYPES[file])
	var mi := MeshInstance3D.new()
	mi.name = "body"
	mi.mesh = _meshes[file]
	var aabb := mi.mesh.get_aabb()
	var scale_ := length / aabb.size.z
	var commercial: bool = TYPES[file] in ["van", "pickup", "delivery", "ambulance", "armoured"]
	var max_width := 2.4 if commercial else 2.2
	mi.scale = Vector3(minf(scale_, max_width / aabb.size.x), scale_, scale_)
	mi.position.z = -(aabb.position.z + aabb.size.z / 2.0) * scale_  # bumper to bumper centred on the origin
	node.add_child(mi)
	return node


## Material batches keep the complete vehicle to one mesh and a few surfaces.
class Builder:
	var tools := {}
	var materials := {}

	func _init(paint: Color) -> void:
		var colours := {"paint": paint, "chrome": Color(0.64, 0.67, 0.65),
			"rubber": Color(0.045, 0.05, 0.048), "glass": Color(0.12, 0.22, 0.26),
			"cream": Color(0.83, 0.80, 0.69), "red": Color(0.60, 0.075, 0.04),
			"amber": Color(0.93, 0.45, 0.09), "blue": Color(0.09, 0.25, 0.67),
			"bed": Color(0.19, 0.23, 0.20)}
		for key in colours:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = colours[key]
			mat.roughness = 0.36 if key == "paint" else (0.18 if key == "glass" else 0.8)
			mat.metallic = 0.75 if key == "chrome" else (0.25 if key == "paint" else 0.0)
			# Opaque dark glazing keeps a silhouette without sorting artifacts.
			materials[key] = mat

	func tool(key: String) -> SurfaceTool:
		if not tools.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_material(materials[key])
			tools[key] = st
		return tools[key]

	func box(at: Vector3, size: Vector3, key: String) -> void:
		var mesh := BoxMesh.new()
		mesh.size = size
		append(mesh, Transform3D(Basis.IDENTITY, at), key)

	func cylinder(at: Vector3, radius: float, width: float, key: String) -> void:
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = width
		mesh.radial_segments = 12
		mesh.rings = 1
		append(mesh, Transform3D(Basis(Vector3.FORWARD, PI / 2), at), key)

	## Expand primitive indices before combining them with authored quads.
	## Mixing indexed append_from with direct vertices drops the earlier quads.
	func append(mesh: Mesh, xf: Transform3D, key: String) -> void:
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if order.is_empty():
			order.resize(vertices.size())
			for i in vertices.size():
				order[i] = i
		var st := tool(key)
		for i in order:
			st.set_normal((xf.basis * normals[i]).normalized())
			st.add_vertex(xf * vertices[i])

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, key: String) -> void:
		var st := tool(key)
		# Each triangle gets its own outward normal on tapered, non-planar panels.
		# Godot front faces are clockwise; emit the opposite of the normal's cross.
		for points in [[a, b, c], [a, c, d]]:
			var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
			for p in [points[0], points[2], points[1]]:
				st.set_normal(normal)
				st.add_vertex(p)

	## Rows: z, bottom y, top y, half-width below, half-width above.
	## Sloping windscreens and tapered bonnets are actual geometry, not boxes.
	func loft(rows: Array, key: String) -> void:
		var rings := []
		for row in rows:
			rings.append([Vector3(-row[3], row[1], row[0]), Vector3(row[3], row[1], row[0]),
				Vector3(row[4], row[2], row[0]), Vector3(-row[4], row[2], row[0])])
		var front: Array = rings[0]
		quad(front[3], front[2], front[1], front[0], key)
		for i in range(rings.size() - 1):
			for j in 4:
				var next := (j + 1) % 4
				quad(rings[i][j], rings[i][next], rings[i + 1][next], rings[i + 1][j], key)
		var rear: Array = rings[-1]
		quad(rear[0], rear[1], rear[2], rear[3], key)

	func beam(a: Vector3, b: Vector3, width: float, key: String) -> void:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, width, a.distance_to(b))
		var xf := Transform3D(Basis.IDENTITY, (a + b) / 2)
		xf = xf.looking_at(b, Vector3.UP)
		append(mesh, xf, key)

	func finish() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for key in tools:
			(tools[key] as SurfaceTool).commit(mesh)
		return mesh


static func _author(style: String) -> ArrayMesh:
	var sp: Dictionary = SPEC[style]
	var k := Builder.new(PAINT[style])
	var L: float = sp.len
	var hl := L / 2.0
	var hw: float = float(sp.wid) / 2.0 - 0.05  # the body sides; mirrors stand proud of the published width
	var H: float = sp.hgt
	var r: float = sp.tyre
	var belt: float = sp.belt
	var sill := maxf(0.2, r * 0.62)
	var zf: float = -hl + float(sp.fo)
	var zr: float = zf + float(sp.wb)
	var g: Array = sp.glass
	var at := func(f: float) -> float: return -hl + f * L
	var body := str(sp.body)
	# The lower hull: a chamfered nose, flat flanks to the belt, a short rear bevel.
	var nose_drop := 0.12 if body in ["mid_engine"] else 0.16
	k.loft([[-hl, sill + 0.05, belt - nose_drop, hw - 0.10, hw - 0.12],
		[-hl + 0.28, sill, belt, hw, hw - 0.03],
		[hl - 0.28, sill, belt, hw, hw - 0.03],
		[hl, sill + 0.05, belt - 0.08, hw - 0.09, hw - 0.06]], "paint")
	match body:
		"three_box", "two_box", "mid_engine":
			_cabin(k, at.call(g[0]), at.call(g[1]), at.call(g[2]), at.call(g[3]), belt, H, hw)
		"pickup":
			_cabin(k, at.call(g[0]), at.call(g[1]), at.call(g[2]), at.call(g[3]), belt, H, hw)
			# The open bed behind the cab: floor, sides, tailgate and pressed ribs.
			var b0: float = at.call(g[3]) + 0.06
			var blen := hl - 0.06 - b0
			k.box(Vector3(0, belt + 0.01, b0 + blen / 2), Vector3(hw * 2 - 0.2, 0.025, blen), "bed")
			for side in [-1, 1]:
				k.box(Vector3(side * (hw - 0.06), belt + 0.13, b0 + blen / 2), Vector3(0.12, 0.27, blen), "paint")
			k.box(Vector3(0, belt + 0.13, hl - 0.1), Vector3(hw * 2 - 0.02, 0.27, 0.09), "paint")
			for x in [-0.6, -0.3, 0.0, 0.3, 0.6]:
				k.box(Vector3(x, belt + 0.035, b0 + blen / 2), Vector3(0.025, 0.02, blen - 0.1), "chrome")
		"van":
			# One box from a short sloped hood to the rear doors.
			var c0: float = at.call(g[0])
			var c1: float = at.call(g[2])
			_cabin(k, c0, at.call(g[1]), c1 + 0.1, c1 + 0.12, belt, H, hw)
			k.box(Vector3(0, (belt + H) / 2, (c1 + hl) / 2), Vector3(hw * 2 - 0.04, H - belt, hl - c1), "paint")
			_box_ribs(k, c1, hl, belt, H, hw)
		"step", "box":
			# A cab (or the step van's flat front) and a taller box body behind it.
			var c0: float = at.call(g[0])
			var cab_top: float = minf(H - 0.35, belt + 1.0) if body == "box" else H
			_cabin(k, c0, at.call(g[1]), at.call(g[2]), at.call(g[3]), belt, cab_top, hw)
			var b0: float = at.call(g[3]) + 0.02
			k.box(Vector3(0, (sill + H) / 2 + 0.05, (b0 + hl) / 2), Vector3(hw * 2, H - sill - 0.1, hl - b0), "paint")
			_box_ribs(k, b0, hl, belt, H, hw)
	# Style details.
	match style:
		"sport":
			k.box(Vector3(0, belt + 0.02, at.call(0.88)), Vector3(hw * 2 - 0.1, 0.04, 0.3), "rubber")  # engine-cover louvres
			for side in [-1, 1]:
				k.box(Vector3(side * hw, belt - 0.12, at.call(0.62)), Vector3(0.03, 0.18, 0.5), "rubber")  # side intake
				k.box(Vector3(side * 0.45, belt - 0.02, -hl + 0.45), Vector3(0.32, 0.02, 0.3), "rubber")  # pop-up lamp lids
		"utility":
			k.box(Vector3(0, H + 0.02, (at.call(g[1]) + at.call(g[2])) / 2), Vector3(hw * 2 - 0.36, 0.04, at.call(g[2]) - at.call(g[1])), "cream")
		"luxury":
			k.box(Vector3(0, H + 0.012, (at.call(g[1]) + at.call(g[2])) / 2 + 0.2), Vector3(hw * 2 - 0.36, 0.03, (at.call(g[2]) - at.call(g[1])) * 0.6), "rubber")  # vinyl roof
			k.box(Vector3(0, belt + 0.03, -hl + 0.9), Vector3(0.025, 0.025, 1.1), "chrome")  # bonnet strip
			k.box(Vector3(0, belt + 0.09, -hl + 0.32), Vector3(0.05, 0.1, 0.05), "chrome")  # bonnet ornament
		"patrol":
			for side in [-1, 1]:
				k.box(Vector3(side * (hw + 0.005), belt - 0.18, (zf + zr) / 2), Vector3(0.02, 0.24, float(sp.wb) * 0.7), "cream")
			_lightbar(k, H + 0.12, at.call((g[1] + g[2]) / 2.0))
		"taxi":
			for side in [-1, 1]:
				k.box(Vector3(side * (hw + 0.005), belt - 0.22, (zf + zr) / 2), Vector3(0.02, 0.1, float(sp.wb) * 0.8), "rubber")  # checker band
			k.box(Vector3(0, H + 0.14, at.call((g[1] + g[2]) / 2.0)), Vector3(0.56, 0.22, 0.24), "cream")
		"ambulance":
			for side in [-1, 1]:
				k.box(Vector3(side * (hw + 0.006), belt + 0.1, (at.call(g[3]) + hl) / 2), Vector3(0.02, 0.18, hl - at.call(g[3]) - 0.1), "red")
				k.box(Vector3(side * (hw + 0.008), H - 0.6, hl - 1.2), Vector3(0.02, 0.36, 0.1), "red")
				k.box(Vector3(side * (hw + 0.009), H - 0.6, hl - 1.2), Vector3(0.02, 0.1, 0.36), "red")
			_lightbar(k, H + 0.04, at.call(g[3]) + 0.3)
		"armoured":
			for side in [-1, 1]:
				k.box(Vector3(side * (hw + 0.005), H - 0.8, hl - 2.0), Vector3(0.035, 0.18, 0.42), "glass")  # gun port
				for z in [hl - 2.3, hl - 1.7]:
					k.box(Vector3(side * (hw + 0.02), H - 0.8, z), Vector3(0.02, 0.28, 0.025), "chrome")
	# Four tyres on the published wheelbase, steel hubcaps, wheel arches.
	var tx := hw - 0.10
	for side in [-1, 1]:
		for z in [zf, zr]:
			k.cylinder(Vector3(side * tx, r, z), r, 0.22, "rubber")
			if style == "luxury":
				k.cylinder(Vector3(side * (tx + 0.116), r, z), r * 0.78, 0.014, "cream")  # whitewalls
			k.cylinder(Vector3(side * (tx + 0.128), r, z), r * 0.62, 0.022, "chrome")
			k.cylinder(Vector3(side * (tx + 0.141), r, z), r * 0.27, 0.025, "bed")
			k.box(Vector3(side * (hw - 0.02), r * 2.0 + 0.02, z), Vector3(0.06, 0.05, r * 2.3), "rubber")  # arch lip
		# Rocker moulding, door handles and the mirrors.
		k.box(Vector3(side * (hw + 0.008), sill + 0.18, (zf + zr) / 2), Vector3(0.028, 0.055, float(sp.wb) - r * 2.4), "chrome")
		k.box(Vector3(side * (hw + 0.009), belt - 0.065, at.call(g[0]) + 0.5), Vector3(0.035, 0.045, 0.18), "chrome")
		var mz: float = at.call(g[0]) + 0.12
		k.box(Vector3(side * (hw + 0.05), belt + 0.16, mz), Vector3(0.14, 0.035, 0.035), "chrome")
		k.box(Vector3(side * (hw + 0.11), belt + 0.22, mz), Vector3(0.12, 0.12, 0.16), "paint")
	# Bumpers, grille and lamps at the two ends.
	var by := sill + 0.14
	for z in [-hl - 0.04, hl + 0.04]:
		k.box(Vector3(0, by, z), Vector3(hw * 2 + 0.04, 0.14, 0.1), "chrome")
		k.box(Vector3(0, by + 0.02, z + (-0.056 if z < 0 else 0.056)), Vector3(hw * 1.45, 0.055, 0.012), "rubber")
		k.box(Vector3(0, by + 0.01, z + (-0.066 if z < 0 else 0.066)), Vector3(0.30, 0.12, 0.015), "cream")
	var gy := maxf(by + 0.2, belt - 0.25)
	var gh := minf(0.23, belt - nose_drop - by - 0.1)
	if style != "sport":
		k.box(Vector3(0, gy, -hl - 0.008), Vector3(hw * 0.95, gh, 0.035), "rubber")
		for i in 9:
			k.box(Vector3(-hw * 0.42 + i * hw * 0.105, gy, -hl - 0.034), Vector3(0.021, gh - 0.03, 0.02), "chrome")
	var ly := maxf(by + 0.16, gy) if style != "sport" else by + 0.18
	for side in [-1, 1]:
		for x in [hw * 0.62, hw * 0.83]:
			k.box(Vector3(side * x, ly, -hl - 0.02), Vector3(0.17, 0.15, 0.03), "cream")
		k.box(Vector3(side * hw * 0.8, belt - 0.1, hl + 0.002), Vector3(0.28, 0.14, 0.035), "red")
		k.box(Vector3(side * hw * 0.93, by + 0.12, -hl + 0.06), Vector3(0.1, 0.06, 0.04), "amber")
	return k.finish()


## Panel ribs, hinges and the rear doors of a box body.
static func _box_ribs(k: Builder, z0: float, z1: float, belt: float, top: float, hw: float) -> void:
	for side in [-1, 1]:
		for f in [0.3, 0.7]:
			k.box(Vector3(side * (hw + 0.004), (belt + top) / 2, lerpf(z0, z1, f)), Vector3(0.012, (top - belt) * 0.8, 0.022), "bed")
		k.box(Vector3(side * (hw + 0.012), belt + 0.3, lerpf(z0, z1, 0.18)), Vector3(0.035, 0.04, 0.18), "chrome")
	k.box(Vector3(0, (belt + top) / 2, z1 + 0.012), Vector3(0.025, (top - belt) * 0.85, 0.02), "bed")
	for x in [-hw * 0.72, hw * 0.72]:
		k.box(Vector3(x, (belt + top) / 2, z1 + 0.02), Vector3(0.04, (top - belt) * 0.75, 0.04), "chrome")


static func _cabin(k: Builder, front: float, roof_front: float, roof_rear: float, rear: float, belt: float, roof: float, width: float) -> void:
	var low := width - 0.08
	var high := width - 0.19
	k.loft([[front, belt, belt + 0.015, low, low], [roof_front, belt, roof, low, high],
		[roof_rear, belt, roof, low, high], [rear, belt, belt + 0.015, low, low]], "glass")
	k.box(Vector3(0, roof + 0.016, (roof_front + roof_rear) / 2), Vector3(high * 2 + 0.04, 0.045, roof_rear - roof_front + 0.08), "paint")
	for side in [-1, 1]:
		k.beam(Vector3(side * low, belt, front), Vector3(side * high, roof, roof_front), 0.065, "paint")
		k.beam(Vector3(side * high, roof, roof_rear), Vector3(side * low, belt, rear), 0.10, "paint")
		k.beam(Vector3(side * low, belt, (roof_front + roof_rear) / 2), Vector3(side * high, roof, (roof_front + roof_rear) / 2), 0.06, "paint")
		k.box(Vector3(side * low, belt + 0.025, (front + rear) / 2), Vector3(0.04, 0.045, rear - front), "chrome")
	# Two wipers sit along the lower windshield; they use the same rubber batch.
	for x in [-0.42, 0.24]:
		k.beam(Vector3(x, belt + 0.025, front - 0.012), Vector3(x + 0.24, belt + 0.085, front + 0.075), 0.024, "rubber")


static func _lightbar(k: Builder, y: float, z: float) -> void:
	k.box(Vector3(0, y, z), Vector3(1.17, 0.055, 0.22), "chrome")
	for side in [-1, 1]:
		k.box(Vector3(side * 0.4, y + 0.1, z), Vector3(0.38, 0.16, 0.24), "red" if side < 0 else "blue")
