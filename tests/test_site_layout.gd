extends TestCase

func test_family_meeting_has_clear_authored_access_and_matching_collision() -> void:
	World.use_map(MapCity.SEED)
	var world := World.new()
	var site := SiteLayout.family_site(world)
	var records := world.site_records()
	var access := SiteAccess.new(world, records)
	check(access.verify(site).connection_verified, "walk and loading legs reach the existing road")
	check(SiteLayout.diagnostics(world, records).filter(func(issue): return issue.id == site.id).is_empty(), "threshold, overlaps and runway clearance")
	var root := Node3D.new()
	Engine.get_main_loop().root.add_child(root)
	root.add_child(Buildings.family_meeting(site))
	for i in 3: await Engine.get_main_loop().physics_frame
	var outside: Vector3 = site.approach[0] + Vector3(0, 1.2, 0)
	var inside: Vector3 = site.transform * Vector3(0, 1.3, 0)
	var query := PhysicsRayQueryParameters3D.create(outside, inside, 1)
	check(root.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "real collision leaves doorway and interior route open")
	query = PhysicsRayQueryParameters3D.create(site.transform * Vector3(4,1.3,-8), site.transform * Vector3(4,1.3,0), 1)
	check(not root.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "wall beside the doorway is solid")
	var loading: Vector3 = site.loading
	query = PhysicsRayQueryParameters3D.create(loading + Vector3(0, 8, 0), loading + Vector3(0, 0.2, 0), 1)
	check(root.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "loading space has no decorative obstacle")
	root.free()
	World.use_map(0)
	check(SiteLayout.family_site(World.new()).is_empty(), "classic regression geometry remains unchanged")

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

func test_costa_brava_nightclub_is_set_back_from_its_strategic_road_anchor() -> void:
	World.use_map(MapCity.SEED)
	var world := World.new()
	var spec: Dictionary = world.map.hqs.org
	var before := spec.duplicate(true)
	var road_anchor := Vector2(spec.x, spec.y)
	var record: Dictionary = SiteLayout.records(world).filter(func(site): return site.id == "hq/org")[0]
	check(not Geometry2D.is_point_in_polygon(road_anchor, record.footprint), "road anchor no longer lies inside the building")
	var access := SiteAccess.new(world, [record])
	check_eq(access.segment_reason(road_anchor, road_anchor, true), "", "vehicle clearance at the road anchor")
	check_eq(access.segment_reason(road_anchor - Vector2(0, 50), road_anchor + Vector2(0, 100), true), "", "whole adjacent north/south road stays outside the building")
	check_eq(spec, before, "strategic coordinates and balance geometry stay unchanged")
	var node := Buildings.hq(world, spec)
	check_eq(node.transform, record.transform)
	node.free()


func test_functional_setbacks_clear_full_roads_and_keep_strategic_anchors() -> void:
	World.use_map(MapCity.SEED)
	var world := World.new()
	var before_hqs := world.map.hqs.duplicate(true)
	var before_stashes := world.map.stashes.duplicate(true)
	var sites := world.site_records()
	var access := SiteAccess.new(world, sites)
	for id in ["hq/law", "stash/barn", "stash/lockup"]:
		var site: Dictionary = sites.filter(func(item): return item.id == id)[0]
		for road in world.map.roads:
			for i in road.size() - 1:
				for polygon in Geometry2D.offset_polygon(site.footprint, RoadSurface.HALF_WIDTH + 0.6):
					check(not SiteAccess._crosses(Vector2(road[i][0], road[i][1]), Vector2(road[i+1][0], road[i+1][1]), polygon), id + " clears road width and roof overhang")
		check(access.verify(site).connection_verified, id + " has checked walking/loading access")
		check(absf(site.entrance.y - world.ground(site.entrance.x, -site.entrance.z)) < 0.55, id + " threshold remains usable")
		var node: Node3D
		if id == "hq/law":
			node = Buildings.hq(world, world.map.hqs.law)
		else:
			var stash: Dictionary = world.map.stashes.filter(func(item): return "stash/" + str(item.id) == id)[0]
			node = StashInterior.build(world, stash)
		check_eq(node.transform, site.transform, id + " builder and diagnostics share placement")
		node.free()
	check_eq(world.map.hqs, before_hqs, "HQ strategic positions are unchanged")
	check_eq(world.map.stashes, before_stashes, "stash strategic positions are unchanged")
	var moved: Dictionary = before_stashes.filter(func(item): return item.id == "barn")[0].duplicate(true)
	moved.x += 100
	check_eq(SiteLayout.stash_frame(world, moved).origin.x, moved.x, "alternate authoring is not silently offset")


class CurvedLand extends World:
	# Curvature makes a translated plot's foundation depth differ. A plane's
	# uniform height shift would cancel out and miss the old-anchor regression.
	func ground(x: float, y: float) -> float: return 0.0002 * x * x + 0.2 * y


func test_hq_foundation_samples_the_actual_transformed_plot() -> void:
	World.use_map(MapCity.SEED)
	var world := CurvedLand.new()
	var spec := {"kind":"law", "style":"customs", "heading":180.0, "x":MapCity.LAW_AT.x, "y":MapCity.LAW_AT.y}
	var node := Buildings.hq(world, spec)
	var low: float = node.transform.origin.y
	for corner in [Vector3(-14,0,-14), Vector3(14,0,-14), Vector3(14,0,14), Vector3(-14,0,14)]:
		var at: Vector3 = node.transform * corner
		low = minf(low, world.ground(at.x, -at.z))
	var foundation := node.get_node("foundation/collision") as StaticBody3D
	var shape := foundation.get_child(0) as CollisionShape3D
	check_near(shape.position.y + (shape.shape as BoxShape3D).size.y / 2, 0.0, 0.001, "foundation reaches the rendered base")
	check_near(shape.position.y - (shape.shape as BoxShape3D).size.y / 2, low - node.transform.origin.y - 0.5, 0.001, "foundation follows the moved/rotated plot's low corner")
	node.free()


func test_set_back_rendered_colliders_leave_the_former_road_crossings_clear() -> void:
	World.use_map(MapCity.SEED)
	var world := World.new()
	var root := Node3D.new()
	Engine.get_main_loop().root.add_child(root)
	root.add_child(Buildings.hq(world, world.map.hqs.law))
	for id in ["barn", "lockup"]:
		var stash: Dictionary = world.map.stashes.filter(func(item): return item.id == id)[0]
		root.add_child(StashInterior.build(world, stash))
	for i in 3: await Engine.get_main_loop().physics_frame
	for ends in [[Vector2(937.5,-11187.5),Vector2(937.5,-11145.5)], [Vector2(1511.7,-9511.7),Vector2(1480.5,-9480.5)], [Vector2(-691.4,-3365.2),Vector2(-722.7,-3339.8)]]:
		var across: Vector2 = (ends[1] - ends[0]).orthogonal().normalized()
		for t in range(9):
			for lateral in [-RoadSurface.HALF_WIDTH, 0.0, RoadSurface.HALF_WIDTH]:
				var p: Vector2 = ends[0].lerp(ends[1], float(t)/8.0) + across * lateral
				var ground := world.ground(p.x, p.y)
				var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,ground+20,-p.y),Vector3(p.x,ground+0.2,-p.y),1)
				check(root.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "rendered walls, roof and foundation clear the full road ribbon")
	root.free()
