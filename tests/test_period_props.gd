extends TestCase

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
