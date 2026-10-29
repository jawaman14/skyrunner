extends TestCase

func test_costa_brava_frontages_preserve_physical_access() -> void:
	var k := Buildings.Kit.new("terminal-frontage-test")
	var center := Vector3(0, 0, 18)
	Buildings.terminal(k, center, 36, 14)
	var collisions := k.body.get_child_count()
	var actions := []
	for child in k.root.get_children():
		if child is Area3D:
			actions.append([child.get_meta("action"), child.position])
	Buildings.san_telmo_frontage(k, center, 36, 14)
	check_eq(k.body.get_child_count(), collisions, "terminal dressing adds no physical obstruction")
	var dressed_actions := []
	for child in k.root.get_children():
		if child is Area3D:
			dressed_actions.append([child.get_meta("action"), child.position])
	check_eq(dressed_actions, actions, "freight and aircraft desk access stays unchanged")
	var terminal := k.finish()
	var sign := terminal.get_node("san-telmo-name") as Label3D
	check(not sign.no_depth_test and sign.billboard == BaseMaterial3D.BILLBOARD_DISABLED, "terminal name respects walls and facade orientation")
	check(sign.basis.z.dot(Vector3.FORWARD) > 0.99, "lettering faces the terminal approach")
	terminal.free()
	var warehouse := Buildings.Kit.new("warehouse-frontage-test")
	StashInterior.warehouse_frontage(warehouse, Vector3(30, 10, 18))
	check_eq(warehouse.body.get_child_count(), 0, "warehouse doorway gains no collider")
	var storage := warehouse.finish()
	for child in storage.get_children():
		check(not (child is Area3D), "painted cargo dressing implies no new inventory action")
	storage.free()


func test_rural_dressing_keeps_storage_aisles_and_footprints_clear() -> void:
	for pair in [["barn", "barn"], ["quarry", "shed"], ["camp", "camp"]]:
		var stash := {"id": pair[0], "kind": pair[1]}
		var dimensions: Vector3 = SiteLayout.stash_spec(stash).dimensions
		var k := Buildings.Kit.new("rural-access-test")
		StashInterior.rural_dressing(k, stash, dimensions)
		check(k.body.get_child_count() > 0, str(pair[0]) + " has physical furnishings")
		for child in k.body.get_children():
			var collision := child as CollisionShape3D
			var box := collision.shape as BoxShape3D
			check(box != null, "simple box colliders bound the rural props")
			if box == null:
				continue
			var half := box.size / 2
			check(absf(collision.position.x) + half.x <= dimensions.x / 2 - 0.2, "solid prop stays inside the side walls")
			check(absf(collision.position.z) + half.z <= dimensions.z / 2 - 0.2, "solid prop stays inside the front/back walls")
			check(absf(collision.position.x) - half.x >= 1.1, "2.2m central entrance-to-desk aisle stays clear")
		var node := k.finish()
		for child in node.get_children():
			check(not (child is Area3D), "rural supplies add no misleading stock action")
		node.free()
	# Reusing a rural kind elsewhere does not give it a Costa Brava landmark name.
	var other := Buildings.Kit.new("other-stash-test")
	StashInterior.rural_dressing(other, {"id": "other", "kind": "barn"}, Vector3(12, 6, 18))
	check_eq(other.body.get_child_count(), 0, "unrelated stashes keep their existing layout")
	other.finish().free()
	for code in ["FRM", "QRY", "PNR"]:
		var shed := Buildings.Kit.new("rural-shed-test")
		Buildings.shed(shed, Vector3.ZERO)
		var collisions := shed.body.get_child_count()
		var job_position: Vector3 = shed.root.get_node("use_jobs").position
		Buildings.rural_airfield_frontage(shed, code, Vector3.ZERO, 7, 5)
		check_eq(shed.body.get_child_count(), collisions, "strip facade adds no obstruction")
		check_eq(shed.root.get_node("use_jobs").position, job_position, "strip job-board access is preserved")
		var site := shed.finish()
		check(site.get_node("rural-strip-name") is Label3D, "rural strip has fixed identifying lettering")
		site.free()


func test_hq_and_casino_redesign_preserves_access_and_prop_budget() -> void:
	for style in ["nightclub", "customs", "hacienda"]:
		var k := Buildings.Kit.new("hq-redesign-test")
		match style:
			"nightclub": Buildings._nightclub(k)
			"customs":
				Buildings._task_force(k)
				Buildings._customs(k)
			"hacienda":
				Buildings._compound(k)
				Buildings._hacienda(k)
		var collisions := k.body.get_child_count()
		var actions := []
		for child in k.root.get_children():
			if child is Area3D:
				actions.append([child.get_meta("action"), child.position])
		Buildings.hq_identity(k, style)
		check_eq(k.body.get_child_count(), collisions + (2 if style == "nightclub" else 0), "only the club's two raised beds add collision")
		if style == "nightclub":
			for i in range(collisions, k.body.get_child_count()):
				var bed := k.body.get_child(i) as CollisionShape3D
				var shape := bed.shape as BoxShape3D
				check(absf(bed.position.x) - shape.size.x / 2 >= 5.5, "planting leaves the central entrance approach clear")
				check(bed.position.z - shape.size.z / 2 >= -15, "planting remains on the existing club pavement")
				check(bed.position.z + shape.size.z / 2 < -8.2, "planting cannot obstruct the side door or stairwell")
				check(bed.position.z - shape.size.z / 2 > -11.5, "planting clears the original parked car's front edge")
		var dressed_actions := []
		for child in k.root.get_children():
			if child is Area3D:
				dressed_actions.append([child.get_meta("action"), child.position])
		check_eq(dressed_actions, actions, "HQ desks keep their original positions")
		k.finish().free()
	var casino := Buildings.Kit.new("casino-redesign-test")
	CasinoBuilding._deco_identity(casino)
	check_eq(casino.body.get_child_count(), 0, "casino portals and inlays add no physical barriers")
	var node := casino.finish()
	var triangles := 0
	for child in node.get_children():
		check(not (child is Area3D) and not (child is Light3D), "casino dressings add no actions or lighting cost")
		if child is MeshInstance3D:
			triangles += child.mesh.get_faces().size() / 3
	check(triangles < 1500, "casino redesign stays within a small batched geometry budget")
	node.free()
	var court := Buildings.Kit.new("arrival-court-test")
	CasinoBuilding._forecourt(court)
	for i in range(1, 5):
		var bed := court.body.get_child(i) as CollisionShape3D
		var shape := bed.shape as BoxShape3D
		check(absf(bed.position.x) - shape.size.x / 2 > 36, "casino beds clear the drive, fountain and existing palms")
		check(absf(bed.position.x) + shape.size.x / 2 < 52, "casino planting remains inside the paved court")
		check(bed.position.z - shape.size.z / 2 > -36, "casino beds stay inside the front pavement edge")
	court.finish().free()
	var bed_kit := Buildings.Kit.new("planting-budget-test")
	Buildings.forecourt_planter(bed_kit, Vector3.ZERO, Vector2(5, 2), true)
	check_eq(bed_kit.body.get_child_count(), 1, "foliage and palm remain inside one solid raised-bed footprint")
	var bed_node := bed_kit.finish()
	var bed_triangles := 0
	for child in bed_node.get_children():
		if child is MeshInstance3D:
			bed_triangles += child.mesh.get_faces().size() / 3
		check(not (child is Area3D) and not (child is Light3D), "planting adds no gameplay action or light")
	check(bed_triangles < 400, "each planted court stays below 400 batched triangles")
	bed_node.free()


func test_city_district_colours_preserve_transforms_and_window_flags() -> void:
	var boxes := []
	for pair in [["warehouse", MapCity.COAST_Y], ["shop", MapCity.COAST_Y], ["shop", MapCity.CITY_C.y + 1400]]:
		boxes.append({"style": pair[0], "x": -1200.0, "y": pair[1], "z": 3.0, "w": 20.0, "d": 18.0, "h": 12.0})
	var before := boxes.duplicate(true)
	var collision := CityDress.colliders(boxes)
	check_eq(boxes, before, "district colours do not mutate map geometry")
	check_near(CityRender.district_colour(boxes[0], Color(0.5, 0.5, 0.5, 0)).a, 0, 0.001, "warehouse window flag stays off")
	check_near(CityRender.district_colour(boxes[1], Color(0.8, 0.8, 0.8, 1)).a, 1, 0.001, "shop window flag stays on")
	for i in boxes.size():
		var b: Dictionary = boxes[i]
		var shape := collision.get_child(i) as CollisionShape3D
		check_near(shape.position.x, b.x, 0.001)
		check_near(shape.position.z, -float(b.y), 0.001)
	var base := Color(0.8, 0.8, 0.8, 1)
	check(CityRender.district_colour(boxes[1], base) != CityRender.district_colour(boxes[2], base), "waterfront and inland have distinct colour treatment")
	collision.free()


func test_sidewalk_pockets_keep_roads_and_authored_access_clear() -> void:
	World.use_map(MapCity.SEED)
	var world := World.new()
	var sites := CityRender.sidewalk_sites(world, world.map.roads)
	check(sites.size() > 0 and sites.size() <= CityRender.SIDEWALK_POCKETS, "bounded street scenery exists")
	var kinds := {}
	for site in sites:
		kinds[site.kind] = true
	for kind in ["planter", "shade", "notice", "coffee", "domino"]:
		check(kinds.has(kind), "street scenery includes " + kind)
	check_eq(sites, CityRender.sidewalk_sites(world, world.map.roads), "placements are deterministic")
	var records := SiteLayout.records(world)
	var reserved := CityRender.sidewalk_reservations(world.map.roads)
	for site in sites:
		var p: Vector2 = site.at
		check(not reserved.any(func(at): return p.distance_to(at) < 3.6), "existing street furniture stays clear")
		check(MapCity.road_dist(world.map.roads, p.x, p.y) >= 6.05, "furniture clears every carriageway")
		check(world.airfield_at(p.x, p.y, 250) == null, "furniture stays away from the strips")
		for record in records:
			for key in ["entrance", "loading"]:
				var at: Vector3 = record[key]
				check(p.distance_to(Vector2(at.x, -at.z)) >= 14, "authored entry/loading area stays clear")
			if record.connector is Vector2:
				for at in [record.approach[0], record.loading]:
					var point: Vector3 = at
					var closest := Geometry2D.get_closest_point_to_segment(p, record.connector, Vector2(point.x, -point.z))
					check(p.distance_to(closest) >= 4.5, "candidate walking and loading legs stay clear")
	var details := CityRender._road_details(world, world.map.roads)
	var pavement := details.get_node("pavements") as MeshInstance3D
	var pavement_body := pavement.get_node("sidewalk-collision") as StaticBody3D
	var pavement_shape := (pavement_body.get_child(0) as CollisionShape3D).shape as ConcavePolygonShape3D
	check_eq(pavement_shape.get_faces(), pavement.mesh.get_faces(), "physical paving matches visible sidewalk and kerbs")
	Engine.get_main_loop().root.add_child(details)
	for frame in 3:
		await Engine.get_main_loop().physics_frame
	if not sites.is_empty():
		var site: Dictionary = sites[0]
		var at := Vector3(site.at.x, site.height, -site.at.y)
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3, at - Vector3.UP, 1)
		var hit := details.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty(), "visible sidewalk supports physics at a furnished spot")
		if not hit.is_empty():
			check_near(hit.position.y, float(site.height), 0.03, "standing surface matches the scenery base height")
	details.free()
	World.use_map(0)
	for kind in ["planter", "shade", "notice", "coffee", "domino"]:
		var k := Buildings.Kit.new("sidewalk-width-test")
		CityRender.sidewalk_furniture(k, kind)
		for child in k.body.get_children():
			var cs := child as CollisionShape3D
			var half_width := 0.0
			if cs.shape is BoxShape3D:
				half_width = (cs.shape as BoxShape3D).size.z / 2
			elif cs.shape is CylinderShape3D:
				half_width = (cs.shape as CylinderShape3D).radius
			check(absf(cs.position.z) + half_width <= 0.35, "solid furniture fits the outer 0.7m sidewalk strip")
		var node := k.finish()
		for child in node.get_children():
			check(not (child is Area3D), "street scenery adds no misleading interactions")
		node.free()


func test_fuel_dressing_preserves_interaction_and_collision() -> void:
	var k := Buildings.Kit.new("fuel-test")
	Buildings.fuel_pump(k, Vector3.ZERO)
	var site := k.finish()
	check_eq(k.body.get_child_count(), 2, "only original pad and dispenser collide")
	var actions := []
	var plates := 0
	for child in site.get_children():
		if child is Area3D:
			actions.append(child.get_meta("action"))
			check_eq(child.position, Vector3(0, 1, -1.4), "interaction stays in front of pump")
		if child is MeshInstance3D and child.mesh is QuadMesh:
			plates += 1
			check(child.material_override.albedo_texture != null, "authored face texture imported")
	check_eq(actions, ["load"], "single original fuel action")
	check_eq(plates, 1, "single decorative meter")
	check(Buildings.plate_material("res://assets/props/analogue_fuel_face.svg") == Buildings.plate_material("res://assets/props/analogue_fuel_face.svg"), "plate material shared between sites")
	site.free()


func test_notice_dressing_preserves_optional_board_and_jobs() -> void:
	for board in [true, false]:
		var k := Buildings.Kit.new("hangar-test")
		Buildings.hangar(k, Vector3.ZERO, 18, 20, board)
		var site := k.finish()
		var jobs := 0
		var notices := 0
		for child in site.get_children():
			if child is Area3D and child.get_meta("action") == "jobs":
				jobs += 1
			if child is MeshInstance3D and child.mesh is QuadMesh:
				notices += 1
		check_eq(jobs, 1 if board else 0, "board keeps optional interaction")
		check_eq(notices, jobs, "paper dressing only exists with the job board")
		site.free()


func test_drum_stack_keeps_fuel_access_and_small_prop_budget() -> void:
	var single := Buildings.Kit.new("single-drum")
	Buildings.fuel_drum(single, Vector3.ZERO)
	var drum := single.finish()
	var triangles := 0
	for child in drum.get_children():
		if child is MeshInstance3D:
			triangles += child.mesh.get_faces().size() / 3
	check(triangles <= 500, "drum stays within small-prop triangle budget")
	check_eq(single.body.get_child_count(), 1, "hoops and bung add no collision")
	drum.free()
	var k := Buildings.Kit.new("drum-stack")
	Buildings.drums(k, Vector3.ZERO, 5)
	var site := k.finish()
	check_eq(k.body.get_child_count(), 7, "five drums plus simple pallet and crate colliders")
	var actions := 0
	for child in site.get_children():
		if child is Area3D:
			actions += 1
			check_eq(child.get_meta("action"), "load", "original fuel action")
			check_eq(child.position, Vector3(0.7, 1, -1.4), "original approach position")
	check_eq(actions, 1, "dressing adds no misleading inventory actions")
	site.free()
