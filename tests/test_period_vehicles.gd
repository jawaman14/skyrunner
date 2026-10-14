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
			var normals: PackedVector3Array = mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_NORMAL]
			check(mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] == null or mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].is_empty(), "authored and primitive geometry share an unindexed triangle batch")
			for i in range(0, vertices.size(), 3):
				var cross_ := (vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i]).normalized()
				check(cross_.dot(normals[i]) < -0.9, "clockwise front-face winding: %s surface %d triangle %d" % [file, surface, i / 3])
			if mat.albedo_color == PeriodVehicles.PAINT[PeriodVehicles.TYPES[file]]:
				check(Array(vertices).any(func(v): return v.y < 0.45 and v.z < -1.8), "authored lower hull survives primitive-detail batching")
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


func test_hq_and_casino_parked_cars_use_period_models() -> void:
	var hq := Buildings.Kit.new("period-vehicle-hq-test")
	Buildings._task_force(hq)
	var police := []
	for child in hq.root.get_children():
		if child.has_meta("period_style"):
			police.append(child)
	check_eq(police.size(), 3, "task-force HQ keeps all three parked cars")
	for car in police:
		check_eq(car.get_meta("period_style"), "patrol", "task-force patrol car uses its period model")
		check(car.has_node("body") and car.get_node("body").mesh.get_surface_count() > 0, "patrol car has a rendered body")
	var hq_scene := hq.finish()
	var hq_colliders := 0
	for child in hq_scene.get_children():
		if child is StaticBody3D:
			hq_colliders += 1
	check_eq(hq_colliders, 4, "patrol-car collision remains in addition to HQ collision")
	hq_scene.free()

	var club := Buildings.Kit.new("period-vehicle-club-test")
	Buildings._nightclub(club)
	var boss_car := club.root.get_children().filter(func(n): return n.has_meta("period_style"))
	check_eq(boss_car.size(), 1, "club keeps the boss's kerbside car")
	if not boss_car.is_empty():
		check_eq(boss_car[0].name, "suv-luxury", "club car uses a period luxury model")
		check_near(boss_car[0].rotation.y, deg_to_rad(90), 0.001, "club car retains its frontage-parallel footprint")
	club.finish().free()

	var casino := Buildings.Kit.new("period-vehicle-casino-test")
	CasinoBuilding._forecourt(casino)
	var guest_car := casino.root.get_children().filter(func(n): return n.has_meta("period_style"))
	check_eq(guest_car.size(), 1, "casino keeps a guest car by the kerb")
	if not guest_car.is_empty():
		check_eq(guest_car[0].name, "sedan-sports", "casino guest car uses a period saloon")
		check_near(guest_car[0].rotation.y, deg_to_rad(90), 0.001, "casino car retains its frontage-parallel footprint")
	casino.finish().free()


func test_disabled_models_keep_existing_procedural_fallback() -> void:
	ModelLib.ENABLED = false
	check(ModelLib.vehicle("sedan", 4.6) == null, "disabled vehicle models return null")
	check(ModelLib.car("police", "car") == null, "disabled squad models return null")
	var fallback := SquadRender.vehicle("org", "car")
	check(fallback != null and not fallback.has_meta("period_style"), "existing squad fallback remains available")
	fallback.free()
	check(PeriodVehicles.build("unknown-file", 4.6) == null, "unhandled kit names pass through")
	check(PeriodVehicles.build("sedan", 0) == null, "invalid length cannot produce degenerate geometry")
