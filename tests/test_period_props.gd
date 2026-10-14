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

