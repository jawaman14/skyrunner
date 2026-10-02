extends TestCase
## Scenery: Kenney's rocks, bushes and beach palms scattered over the island. Deterministic, kept off the
## airfields, the town, the roads and the sea, and drawn in chunks within a range.


func after_each() -> void:
	Scenery.ENABLED = true
	World.use_map(0)


func _world(seed := MapCity.SEED) -> World:
	World.use_map(seed)
	return World.new()


func test_the_scatter_is_the_same_every_time_and_has_every_part() -> void:
	var w := _world()
	var t0 := Time.get_ticks_msec()
	var a := Scenery.scatter(w)
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	var b := Scenery.scatter(w)
	check(a.size() > 500, "a good many placements (%d, in %.1f s)" % [a.size(), secs])
	check_eq(a.size(), b.size(), "the same number")
	var parts := {}
	for i in a.size():
		parts[a[i].part] = parts.get(a[i].part, 0) + 1
		if i < 200:
			check(a[i].model == b[i].model and is_equal_approx(a[i].x, b[i].x) and is_equal_approx(a[i].h_m, b[i].h_m), "placement %d is the same" % i)
	for p in ["boulder", "crag", "rock", "bush", "palm"]:
		check(parts.get(p, 0) > 0, "some %s (%d)" % [p, parts.get(p, 0)])
	check(secs < 20.0, "and quick enough to do at load (%.1f s)" % secs)


func test_nothing_in_the_sea_on_an_airfield_in_town_or_on_a_road() -> void:
	var w := _world()
	var roads: Array = w.map.roads
	var lu: PackedByteArray = w.map.land_use
	var bad := {"water": 0, "airfield": 0, "town": 0, "road": 0}
	for p in Scenery.scatter(w):
		if w.height(p.x, p.y) < 0.3:
			bad.water += 1
		if w.airfield_at(p.x, p.y, 100.0) != null:
			bad.airfield += 1
		if MapCity.at(lu, p.x, p.y) in [MapCity.URBAN, MapCity.PORT]:
			bad.town += 1
		if not roads.is_empty() and MapCity.road_dist(roads, p.x, p.y) < 30.0:
			bad.road += 1
	check_eq(bad, {"water": 0, "airfield": 0, "town": 0, "road": 0}, "kept clear")


func test_a_map_without_land_use_still_gets_bushes() -> void:
	var w := _world(0)  # the classic island has no land-use grid
	var bushes := 0
	for p in Scenery.scatter(w):
		if p.part == "bush":
			bushes += 1
	check(bushes > 0, "bushes on open ground (%d)" % bushes)


func test_build_draws_chunks_within_a_range_and_not_on_low() -> void:
	var w := _world()
	var root := Scenery.build(w, Quality.get_preset("high"))
	check(root.get_child_count() > 5, "chunks (%d)" % root.get_child_count())
	var n := 0
	for c in root.get_children():
		for m in c.get_children():
			n += (m as MultiMeshInstance3D).multimesh.instance_count
			check((m as MultiMeshInstance3D).visibility_range_end > 0.0, "%s is drawn to a range" % m.name)
	check_eq(n, Scenery.scatter(w).size(), "every placement is an instance")
	root.free()
	var low := Scenery.build(w, Quality.get_preset("low"))
	check_eq(low.get_child_count(), 0, "nothing on low")
	low.free()
	Scenery.ENABLED = false
	var off := Scenery.build(w, Quality.get_preset("high"))
	check_eq(off.get_child_count(), 0, "nothing when switched off")
	off.free()


func test_a_model_split_over_several_meshes_comes_out_whole() -> void:
	var m: Node3D = (load("res://assets/models/kenney/nature/tree_palmDetailedTall.glb") as PackedScene).instantiate()
	var parts := m.find_children("*", "MeshInstance3D", true, false).size()
	var merged := ModelLib.merged_mesh(m)
	check(merged != null, "a mesh")
	check(merged.get_surface_count() >= 2, "trunk and fronds are both there: %d surfaces from %d meshes" % [merged.get_surface_count(), parts])
	var bounds := ModelLib.bounds(m)
	check(merged.get_aabb().size.y > 0.9 * bounds.size.y, "and as tall as the model (%.2f of %.2f)" % [merged.get_aabb().size.y, bounds.size.y])
	m.free()
	var empty := Node3D.new()
	check(ModelLib.merged_mesh(empty) == null, "no meshes, no mesh")
	empty.free()
