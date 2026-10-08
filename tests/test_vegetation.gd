extends TestCase
## Render thinning must retain deliberate strip obstacles and never mutate physics.

func _world() -> World:
	var world := World.new()
	world.map = MapLayout.classic()
	world.terrain = Terrain.new()
	world.terrain._h.resize(Terrain.GRID * Terrain.GRID)
	world.terrain._trees = PackedFloat32Array([100,200,0,10, 150,250,0,22, 200,300,0,10, 250,350,0,12])
	return world

func _tree_count(node: Node3D) -> int:
	var count := 0
	for child in node.get_children():
		if child.name == "bush": continue
		count += child.multimesh.instance_count
	return count

func test_low_preset_retains_strip_end_obstacles_without_mutating_terrain() -> void:
	var world := _world()
	var original := world.terrain.get_trees()
	for preset in ["low", "medium", "high"]:
		var vegetation := Vegetation.build(world, Quality.get_preset(preset))
		check_eq(_tree_count(vegetation), 3 if preset == "low" else 4)
		check_eq(world.terrain.get_trees(), original, "render preset preserves authoritative obstacles")
		vegetation.free()
	# Only indices 0/3 survive low-preset thinning; index 1 survives because it
	# is a tall strip obstacle. Lowering it must remove that exception.
	world.terrain._trees[7] = 20
	var thinned := Vegetation.build(world, Quality.get_preset("low"))
	check_eq(_tree_count(thinned), 2, "ordinary trees can be thinned; tall obstacles cannot")
	thinned.free()

func test_rebuilding_vegetation_has_identical_species_counts_and_meshes() -> void:
	var world := _world()
	for preset in ["low", "medium", "high"]:
		var first := Vegetation.build(world, Quality.get_preset(preset))
		var second := Vegetation.build(world, Quality.get_preset(preset))
		check_eq(first.get_child_count(), second.get_child_count())
		for child in first.get_children():
			var other := second.get_node(NodePath(str(child.name)))
			check_eq(child.multimesh.instance_count, other.multimesh.instance_count)
			check_eq(child.multimesh.mesh.get_surface_count(), other.multimesh.mesh.get_surface_count())
			for surface in child.multimesh.mesh.get_surface_count():
				check_eq(child.multimesh.mesh.surface_get_arrays(surface), other.multimesh.mesh.surface_get_arrays(surface))
		first.free()
		second.free()

func test_empty_tree_list_builds_no_phantom_obstacles() -> void:
	var world := _world()
	world.terrain._trees = PackedFloat32Array()
	for preset in ["low", "medium", "high"]:
		var vegetation := Vegetation.build(world, Quality.get_preset(preset))
		check_eq(vegetation.get_child_count(), 0)
		vegetation.free()
