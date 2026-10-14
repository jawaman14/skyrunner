extends TestCase
## Vehicle render contracts: covers every dealer/squad key without binary kits.

func after_each() -> void:
	ModelLib.ENABLED = true


func test_dealer_and_squad_rosters_use_period_bodies() -> void:
	for spec in Dealership.CATALOGUE:
		var node := ModelLib.vehicle(str(spec.model), float(spec.len))
		check(node != null, "dealer body exists: " + str(spec.id))
		check(node.has_meta("period_style"), "dealer body has period identity")
		node.free()
	for faction in ModelLib.CARS:
		for kind in ["car", "truck"]:
			var node := ModelLib.car(faction, kind)
			check(node != null and node.name == ModelLib.CARS[faction][kind], "squad keys remain stable")
			node.free()
	check_eq(PeriodVehicles.TYPES[ModelLib.CARS.family.car], "luxury", "Family uses a period luxury saloon")


func test_exact_dimensions_and_ground_origin_across_requested_lengths() -> void:
	for file in PeriodVehicles.TYPES:
		for length in [4.0, 4.6, 5.4, 6.4]:
			var node := ModelLib.vehicle(file, length)
			var bounds := ModelLib.bounds(node)
			check_near(bounds.size.z, length, 0.001, "length matches the caller contract")
			check_near(bounds.position.y, 0.0, 0.001, "tyres touch y=0")
			check_near(bounds.get_center().x, 0.0, 0.001, "body stays laterally centred")
			check_near(bounds.get_center().z, 0.0, 0.001, "bumper extents stay centred")
			check(bounds.size.x <= 2.401, "long truck bodies do not become implausibly wide")
			node.free()


func test_period_body_geometry_budgets_and_facing() -> void:
	for file in PeriodVehicles.TYPES:
		var node := ModelLib.vehicle(file, 4.6)
		var mi := node.get_node("body") as MeshInstance3D
		check(mi.mesh.get_surface_count() <= 9, "materials batch to at most nine surfaces")
		check(mi.mesh.get_faces().size() / 3 < 3200, "vehicle stays below 3200 triangles")
		for child in node.find_children("*", "Node", true, false):
			check(not (child is CollisionObject3D) and not (child is CollisionShape3D) and not (child is Light3D), "render model adds no physics/actions/lights")
		# Cream headlamps occur at the negative-Z nose; red taillamps at +Z.
		var front := false
		var rear := false
		for surface in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(surface) as StandardMaterial3D
			var vertices: PackedVector3Array = mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				if mat.albedo_color == Color(0.83, 0.80, 0.69) and vertex.z < -2.24 and vertex.y > 0.6:
					front = true
				if mat.albedo_color == Color(0.60, 0.075, 0.04) and vertex.z > 2.21:
					rear = true
		check(front and rear, "headlamps face -Z and taillamps face +Z")
		node.free()


func test_distinct_silhouettes_and_cached_mesh_instance_independence() -> void:
	var meshes := {}
	for file in PeriodVehicles.TYPES:
		var node := ModelLib.vehicle(file, 4.6)
		var mesh: Mesh = node.get_node("body").mesh
		check(not meshes.has(mesh.get_instance_id()), "each fleet key has its own authored geometry/livery")
		meshes[mesh.get_instance_id()] = true
		node.free()
	var a := ModelLib.vehicle("police", 4.6)
	var b := ModelLib.vehicle("police", 5.4)
	check(a != b and a.get_node("body").mesh == b.get_node("body").mesh, "instances share cached geometry")
	a.position.x = 50
	check_near(b.position.x, 0, 0.001, "moving one vehicle cannot move another")
	check_near(ModelLib.bounds(a).size.z, 4.6, 0.001, "instance scaling cannot resize another body")
	a.free()
	b.free()


func test_disabled_models_keep_existing_procedural_fallback() -> void:
	ModelLib.ENABLED = false
	check(ModelLib.vehicle("sedan", 4.6) == null, "disabled vehicle models return null")
	check(ModelLib.car("police", "car") == null, "disabled squad models return null")
	var fallback := SquadRender.vehicle("org", "car")
	check(fallback != null and not fallback.has_meta("period_style"), "existing squad fallback remains available")
	fallback.free()
	check(PeriodVehicles.build("unknown-file", 4.6) == null, "unhandled kit names pass through")
	check(PeriodVehicles.build("sedan", 0) == null, "invalid length cannot produce degenerate geometry")
