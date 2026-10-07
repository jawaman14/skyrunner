extends TestCase

func after_each() -> void:
	World.use_map(0)

func _world() -> World:
	World.use_map(MapCity.SEED)
	return World.new()

func test_parcels_have_stable_ids_period_identity_and_clear_working_sites() -> void:
	var w := _world()
	var ids := {}
	var districts := {}
	var index := MapCity.RoadIndex.new(w.map.roads, 70)
	for b in w.map.buildings:
		check(not ids.has(b.id), "unique parcel: %s" % b.id)
		ids[b.id] = true
		districts[b.district] = true
		if b.style == "crane": continue
		check(b.period and b.h <= 12.0 and b.style != "tower", "restrained period scale")
		var p := Vector2(b.x, b.y)
		var radius := Vector2(b.w, b.d).length() / 2
		check(not CostaBravaPlan.reserved(p, radius, w.map), "functional plots remain open")
		check(index.dist(p) >= radius + 7, "footprint stays clear of physical roads")
	check(districts.has("old_town") and districts.has("port") and districts.has("barrio"), "distinct populated districts")
	var again := CostaBravaPlan.buildings(w.terrain, w.map)
	check_eq(w.map.buildings, again, "stable parcels, positions and dimensions")

func test_parcels_do_not_overlap_and_foundations_are_supported() -> void:
	var w := _world()
	var bins := {}
	for b in w.map.buildings:
		if b.style == "crane": continue
		var rect := Rect2(Vector2(b.x - b.w / 2, b.y - b.d / 2), Vector2(b.w, b.d))
		var key := Vector2i(floori(b.x / 100), floori(b.y / 100))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for prior in bins.get(key + Vector2i(dx, dy), []):
					check(not rect.intersects(prior), "no overlapping scenery footprints")
		if not bins.has(key): bins[key] = []
		bins[key].append(rect)
		for corner in [rect.position, rect.end, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y)]:
			var ground := w.height(corner.x, corner.y)
			check(ground >= 1 and b.z >= ground - 0.01 and b.z - ground <= 1.51, "dry supported foundation")

func test_local_streets_are_dry_and_keep_runways_and_functional_buildings_clear() -> void:
	var w := _world()
	check(w.map.roads.size() > w.map.settlement_trunk_count, "actual local street network")
	for road in w.map.roads.slice(w.map.settlement_trunk_count):
		for i in road.size() - 1:
			var a := Vector2(road[i][0], road[i][1])
			var b := Vector2(road[i + 1][0], road[i + 1][1])
			for step in int(ceil(a.distance_to(b) / 10)) + 1:
				var p := a.lerp(b, minf(1, step * 10.0 / maxf(1, a.distance_to(b))))
				check(w.height(p.x, p.y) > 0.3, "no unbridged water street")
				for af in w.airfields: check(not af.contains(p.x, p.y, 55), "street outside runway exclusion")
				for stash in w.map.stashes: check(p.distance_to(Vector2(stash.x, stash.y)) >= 25, "street does not run through stash")

func test_original_meshes_fit_parcels_and_asset_bible_budgets() -> void:
	for style in ["res", "shop", "warehouse"]:
		var mesh: Mesh = PeriodArchitecture.model(style).mesh
		var bounds := mesh.get_aabb()
		check(bounds.position.x >= -0.501 and bounds.end.x <= 0.501, "roof and details within width")
		check(bounds.position.z >= -0.501 and bounds.end.z <= 0.501, "details within depth")
		check(bounds.position.y >= -0.001 and bounds.end.y <= 1.001, "roof within authoritative height")
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		check(vertices.size() / 3 <= 500, "reusable building under 500 triangles")
		check(PeriodArchitecture.model(style).mesh == mesh, "cached shared geometry")

func test_rotated_period_render_and_collision_bounds_agree() -> void:
	for yaw in [0.0, PI / 2, PI, PI * 1.5]:
		var b := {"period": true, "style": "res", "x": 20.0, "y": 30.0, "z": 4.0, "w": 24.0, "d": 16.0, "h": 8.0, "yaw": yaw}
		var lot: Dictionary = CityDress.lots(b, 0)[0]
		var mesh: Mesh = PeriodArchitecture.model("res").mesh
		var bounds: AABB = lot.xf * mesh.get_aabb()
		check_near(bounds.size.x, b.w, 0.001)
		check_near(bounds.size.z, b.d, 0.001)
		check_near(bounds.end.y, b.z + b.h, 0.001)
		var collision := CityDress.colliders([b])
		check_near(collision.get_child(0).shape.size.x, bounds.size.x, 0.001)
		collision.free()

func test_rebuild_has_no_generic_skyscraper_landmarks() -> void:
	check(DowntownDress.pick(_world().map.buildings).is_empty(), "period skyline replaces modern towers")
