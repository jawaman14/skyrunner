extends TestCase
func after_each() -> void:
	World.use_map(0)

func test_site_records_are_deterministic_and_cover_functional_sites() -> void:
	World.use_map(MapCity.SEED)
	var world := World.new()
	var first := SiteLayout.records(world)
	var second := SiteLayout.records(world)
	check_eq(first, second)
	var ids: Array = first.map(func(site): return site.id)
	var unique := {}
	for id in ids: unique[id] = true
	check_eq(ids.size(), unique.size(), "stable IDs are unique")
	for stash in world.map.stashes:
		check(ids.has("stash/" + str(stash.id)))
	for kind in world.map.hqs:
		check(ids.has("hq/" + str(kind)))
	check(ids.has("hotel/cielo"))
	check(first.any(func(site): return site.kind == "dock"))
	for site in first:
		check_eq(site.footprint.size(), 4)
		check(site.entrance.is_finite() and site.loading.is_finite())
		check(not site.connection_verified, "candidate connectors are not falsely advertised as checked")

func test_airfield_builder_consumes_shared_parts_and_frame() -> void:
	for seed in [MapCity.SEED, 82]:
		World.use_map(seed)
		var world := World.new()
		for af in world.airfields:
			var node := Buildings.airfield_site(world, af)
			check_eq(node.transform, SiteLayout.airfield_frame(world, af))
			var records: Array = node.get_meta("site_records")
			check_eq(records.size(), SiteLayout.airfield_parts(af).size())
			check(records.all(func(site): return str(site.id).begins_with("airfield/" + af.code + "/")))
			node.free()

func test_diagnostics_report_thresholds_and_runway_intrusions() -> void:
	World.use_map(MapCity.SEED)
	var world := World.new()
	var af: Airfield = world.airfields[0]
	var blocked := SiteLayout.record(world, "test", "stash", SiteLayout.frame(Vector2(af.x, af.y), world.airfield_elev(af) + 2), Vector3(10, 3, 10))
	var issues := SiteLayout.diagnostics(world, [blocked])
	check(issues.any(func(issue): return "runway" in issue.reason))
	check(issues.any(func(issue): return "Threshold" in issue.reason))
	var overlay := AccessOverlay.make(world)
	check(overlay.get_child_count() > 0)
	overlay.free()

func test_runway_clearance_detects_crossings_without_interior_corners() -> void:
	World.use_map(MapCity.SEED)
	var world := World.new()
	var af: Airfield = world.airfields[0]
	var center := Vector2(af.x, af.y)
	var along := Vector2(af.ux, af.uy) * 5.0
	var across := Vector2(af.uy, -af.ux) * (af.width + 30.0)
	var polygon := PackedVector2Array([center - along - across, center + along - across, center + along + across, center - along + across])
	for point in polygon:
		check(not af.contains(point.x, point.y, 8.0), "old corner-only diagnostic misses this crossing")
	var site := SiteLayout.record(world, "crossing", "stash", SiteLayout.frame(center, world.airfield_elev(af)), Vector3(10, 3, 10))
	site.footprint = polygon
	check(SiteLayout.diagnostics(world, [site]).any(func(issue): return "runway" in issue.reason))
	site.footprint = PackedVector2Array([center - Vector2(af.length, af.length), center + Vector2(af.length, -af.length), center + Vector2(af.length, af.length), center + Vector2(-af.length, af.length)])
	check(SiteLayout.diagnostics(world, [site]).any(func(issue): return "runway" in issue.reason), "fully enclosed runway is detected")
