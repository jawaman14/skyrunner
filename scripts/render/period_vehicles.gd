class_name PeriodVehicles
extends RefCounted
## Original late-1970s/1980s road vehicles. Existing model keys are retained so
## the dealer, squads and saved vehicle IDs need no migration. Metres, -Z front,
## tyres at y=0; appearance only, with collision/handling owned by callers.
## References inform proportions and detail, not copied meshes or textures.

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
static var _meshes := {}


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
	var scale_ := length / mi.mesh.get_aabb().size.z
	var commercial: bool = TYPES[file] in ["van", "pickup", "delivery", "ambulance", "armoured"]
	var max_width := 2.4 if commercial else 2.2
	mi.scale = Vector3(minf(scale_, max_width / mi.mesh.get_aabb().size.x), scale_, scale_)
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
		tool(key).append_from(mesh, 0, Transform3D(Basis.IDENTITY, at))

	func cylinder(at: Vector3, radius: float, width: float, key: String) -> void:
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = width
		mesh.radial_segments = 12
		mesh.rings = 1
		tool(key).append_from(mesh, 0, Transform3D(Basis(Vector3.FORWARD, PI / 2), at))

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, key: String) -> void:
		var normal := (b - a).cross(c - a).normalized()
		var st := tool(key)
		for p in [a, b, c, a, c, d]:
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
		tool(key).append_from(mesh, 0, xf)

	func finish() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for key in tools:
			(tools[key] as SurfaceTool).commit(mesh)
		return mesh


static func _author(style: String) -> ArrayMesh:
	var k := Builder.new(PAINT[style])
	var commercial := style in ["van", "pickup", "delivery", "ambulance", "armoured"]
	var utility := style == "utility"
	var sport := style == "sport"
	var width := 0.94 if not commercial else 1.0
	var belt := 0.96 if not commercial else 1.1
	if utility:
		belt = 1.15
	if sport:
		belt = 0.82
	# Chamfered nose, broad flat hood, slab-sided quarters and short rear bevel.
	k.loft([[-2.22, 0.42, belt - 0.17, width - 0.10, width - 0.12],
		[-1.85, 0.40, belt, width, width - 0.03],
		[1.85, 0.40, belt, width, width - 0.03],
		[2.22, 0.42, belt - 0.08, width - 0.09, width - 0.06]], "paint")
	if style in ["van", "delivery", "ambulance", "armoured"]:
		_cabin(k, -1.82, -1.46, -0.75, -0.55, belt, 1.91, width)
		var tall := 2.03 if style == "van" else 2.32
		k.box(Vector3(0, (belt + tall) / 2, 0.83), Vector3(1.94, tall - belt, 2.63), "paint")
		for side in [-1, 1]:
			# Panel ribs, hinges and the side cargo-door handle.
			for z in [0.1, 1.55]:
				k.box(Vector3(side * 0.976, 1.53, z), Vector3(0.012, 0.96, 0.022), "bed")
			k.box(Vector3(side * 0.99, 1.44, 0.25), Vector3(0.035, 0.04, 0.18), "chrome")
			if style == "ambulance":
				k.box(Vector3(side * 0.981, 1.25, 0.8), Vector3(0.02, 0.18, 2.6), "red")
				k.box(Vector3(side * 0.983, 1.78, 0.8), Vector3(0.02, 0.34, 0.1), "red")
				k.box(Vector3(side * 0.984, 1.78, 0.8), Vector3(0.02, 0.1, 0.34), "red")
			if style == "armoured":
				k.box(Vector3(side * 0.985, 1.82, 0.9), Vector3(0.035, 0.18, 0.42), "glass")
				for z in [0.6, 1.2]:
					k.box(Vector3(side * 1.005, 1.82, z), Vector3(0.02, 0.28, 0.025), "chrome")
		k.box(Vector3(0, 1.56, 2.155), Vector3(0.025, 1.25, 0.02), "bed")
		for x in [-0.7, 0.7]:
			k.box(Vector3(x, 1.56, 2.17), Vector3(0.04, 1.08, 0.04), "chrome")
		if style == "ambulance":
			_lightbar(k, 2.04, -0.6)
	elif style == "pickup":
		_cabin(k, -1.08, -0.78, -0.12, 0.05, belt, 1.82, width)
		# Open bed: distinct floor, side rails, tailgate and pressed ribs.
		k.box(Vector3(0, 1.13, 1.14), Vector3(1.72, 0.025, 1.88), "bed")
		for side in [-1, 1]:
			k.box(Vector3(side * 0.94, 1.24, 1.14), Vector3(0.12, 0.31, 2.02), "paint")
		k.box(Vector3(0, 1.24, 2.14), Vector3(1.84, 0.31, 0.09), "paint")
		for x in [-0.6, -0.3, 0.0, 0.3, 0.6]:
			k.box(Vector3(x, 1.153, 1.14), Vector3(0.025, 0.02, 1.76), "chrome")
	else:
		var roof := 1.53 if not utility else 1.95
		var front := -0.83
		var rear := 1.25
		var roof_front := -0.44
		var roof_rear := 0.75
		if sport:
			roof = 1.30
			front = -0.5
			roof_front = -0.13
			roof_rear = 0.55
			rear = 1.63
		if style == "hatch" or utility:
			rear = 1.92
			roof_rear = 1.60
		_cabin(k, front, roof_front, roof_rear, rear, belt, roof, width)
		if utility:
			# Two-tone hardtop and a rear spare: utility shape rather than a modern crossover.
			k.box(Vector3(0, roof + 0.025, 0.58), Vector3(1.59, 0.05, 2.08), "cream")
			k.box(Vector3(0, 1.28, 2.16), Vector3(0.58, 0.63, 0.15), "rubber")
		if style == "luxury":
			k.box(Vector3(0, roof + 0.012, 0.35), Vector3(1.52, 0.03, 0.76), "rubber")
			k.box(Vector3(0, belt + 0.025, -1.5), Vector3(0.025, 0.025, 1.0), "chrome")
		if sport:
			k.box(Vector3(0, 0.87, 1.92), Vector3(1.77, 0.06, 0.23), "rubber")
			for x in [-0.59, 0.59]:
				k.box(Vector3(x, 0.82, -1.8), Vector3(0.44, 0.025, 0.48), "rubber")
		if style in ["patrol", "taxi"]:
			for side in [-1, 1]:
				k.box(Vector3(side * 0.944, 0.81, 0.08), Vector3(0.02, 0.27, 1.75), "cream")
			if style == "patrol":
				_lightbar(k, roof + 0.12, 0.15)
			else:
				k.box(Vector3(0, roof + 0.14, 0.15), Vector3(0.56, 0.22, 0.24), "cream")
	# Four circular tyres with steel hubcaps, tread bands and optional whitewalls.
	for side in [-1, 1]:
		for z in [-1.48, 1.48]:
			k.cylinder(Vector3(side * width, 0.37, z), 0.37, 0.22, "rubber")
			if style == "luxury":
				k.cylinder(Vector3(side * (width + 0.116), 0.37, z), 0.29, 0.014, "cream")
			k.cylinder(Vector3(side * (width + 0.128), 0.37, z), 0.23, 0.022, "chrome")
			k.cylinder(Vector3(side * (width + 0.141), 0.37, z), 0.10, 0.025, "bed")
			k.box(Vector3(side * width, 0.34, z + 0.42), Vector3(0.19, 0.36, 0.045), "rubber")
		# Rocker moulding, handles and mirrors, below the existing body width.
		k.box(Vector3(side * (width + 0.008), 0.61, 0), Vector3(0.028, 0.055, 2.05), "chrome")
		for z in ([-0.2, 0.68] if style in ["luxury", "patrol", "taxi"] else [-0.1]):
			k.box(Vector3(side * (width + 0.009), belt - 0.065, z), Vector3(0.035, 0.045, 0.18), "chrome")
		var mirror_z := -1.35 if commercial else -0.7
		k.box(Vector3(side * (width + 0.05), belt + 0.18, mirror_z), Vector3(0.14, 0.035, 0.035), "chrome")
		k.box(Vector3(side * (width + 0.11), belt + 0.24, mirror_z), Vector3(0.12, 0.12, 0.18), "paint")
	# Separate bumper, grille bars and paired rectangular sealed-beam lamps.
	for z in [-2.25, 2.25]:
		k.box(Vector3(0, 0.55, z), Vector3(width * 1.95, 0.14, 0.1), "chrome")
		k.box(Vector3(0, 0.57, z + (-0.056 if z < 0 else 0.056)), Vector3(1.38, 0.055, 0.012), "rubber")
		k.box(Vector3(0, 0.56, z + (-0.066 if z < 0 else 0.066)), Vector3(0.30, 0.12, 0.015), "cream")
	k.box(Vector3(0, belt - 0.25, -2.228), Vector3(0.9, 0.23, 0.035), "rubber")
	for i in 9:
		k.box(Vector3(-0.4 + i * 0.1, belt - 0.25, -2.254), Vector3(0.021, 0.20, 0.02), "chrome")
	for side in [-1, 1]:
		for x in [0.58, 0.78]:
			k.box(Vector3(side * x, belt - 0.24, -2.24), Vector3(0.17, 0.16, 0.03), "cream")
		k.box(Vector3(side * 0.75, belt - 0.08, 2.222), Vector3(0.28, 0.14, 0.035), "red")
		k.box(Vector3(side * 0.87, belt - 0.4, -2.16), Vector3(0.1, 0.06, 0.04), "amber")
	return k.finish()


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
