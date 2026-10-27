class_name PeriodArchitecture
extends RefCounted
## Original modular geometry: plaster, terracotta, shutters and corrugated sheds.
## One cached mesh/material per archetype, instanced by CityDress. Unit bounds
## exactly match the authoritative parcel; roof peaks stay below its height.
static var _meshes := {}
static var _material: ShaderMaterial

static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://shaders/period_architecture.gdshader")
	return _material

static func model(style: String) -> Dictionary:
	if not _meshes.has(style):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var industrial := style == "warehouse"
		var wall := Color(0.72, 0.69, 0.57) if industrial else Color(0.88, 0.83, 0.70)
		_box(st, Vector3(0, 0.41, 0), Vector3(1, 0.82, 1), wall)
		# Roof: two slopes and closed gable ends, all inside the parcel envelope.
		var roof := Color(0.40, 0.39, 0.34) if industrial else Color(0.55, 0.28, 0.18)
		for side in [-1.0, 1.0]:
			var slope := [Vector3(side * 0.5, 0.82, -0.5), Vector3(0, 1, -0.5), Vector3(0, 1, 0.5), Vector3(side * 0.5, 0.82, 0.5)]
			if side < 0: slope.reverse()
			_quad(st, slope, roof)
		for end in [-0.5, 0.5]:
			_triangle(st, Vector3(-end, 0.82, end), Vector3(0, 1, end), Vector3(end, 0.82, end), wall)
		# Front is +Z, matching the existing lots convention. Doors are decorative
		# on scenery buildings; functional sites use their enterable builders.
		_box(st, Vector3(0, 0.19, 0.496), Vector3(0.16 if not industrial else 0.42, 0.38, 0.008), Color(0.23, 0.27, 0.23))
		for floor in (1 if industrial else 2):
			for side in [-0.3, 0.3]:
				var y := 0.3 + floor * 0.32
				_box(st, Vector3(side, y, 0.496), Vector3(0.12, 0.16, 0.008), Color(0.18, 0.24, 0.25))
				if not industrial:
					for shutter in [-0.095, 0.095]:
						_box(st, Vector3(side + shutter, y, 0.496), Vector3(0.055, 0.17, 0.008), Color(0.29, 0.36, 0.27))
		if style == "shop":
			_box(st, Vector3(0, 0.47, 0.485), Vector3(0.7, 0.07, 0.03), Color(0.55, 0.43, 0.28))
		if industrial:
			for rib in 12:
				_box(st, Vector3(-0.46 + rib * 0.083, 0.41, 0.494), Vector3(0.009, 0.80, 0.012), Color(0.51, 0.50, 0.43))
		st.generate_normals()
		var mesh := st.commit()
		_meshes[style] = {"mesh": mesh, "dim": Vector3.ONE, "centre": Vector3.ZERO, "kit": "period"}
	return _meshes[style]

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	st.set_color(colour)
	for p in [a, b, c]: st.add_vertex(p)

static func _quad(st: SurfaceTool, p: Array, colour: Color) -> void:
	_triangle(st, p[0], p[1], p[2], colour)
	_triangle(st, p[0], p[2], p[3], colour)

static func _box(st: SurfaceTool, at: Vector3, size: Vector3, colour: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in indices:
		st.set_color(colour)
		st.add_vertex(vertices[i] + at)
