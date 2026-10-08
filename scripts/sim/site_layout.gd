class_name SiteLayout
extends RefCounted
## Deterministic authoring data shared by physical builders and access diagnostics.
## Connectors are candidates until checked routing validates their access legs.
const STASH := {
	"barn": [12.0, 6.0, 18.0, 0.0, "red"], "shack": [6.0, 2.4, 5.0, 1.8, "wood"],
	"warehouse": [30.0, 10.0, 18.0, 0.0, "metal"], "lockup": [15.8, 2.8, 6.0, 0.0, "concrete"],
	"camp": [5.0, 2.6, 7.0, 0.0, "green"], "shed": [9.0, 2.8, 6.0, 0.0, "metal_rust"],
	"boathouse": [8.0, 5.0, 14.0, 0.0, "wood"], "villa": [14.0, 4.0, 10.0, 0.0, "stucco_pink"]}

## A physical meeting yard, separate from the unchanged strategic market anchor.
const FAMILY_AT := Vector2(-7250.0, -10399.0)
static func family_site(world: World) -> Dictionary:
	if world.map.map_seed != MapCity.SEED: return {}
	return record(world, "meet/family", "meeting", frame(FAMILY_AT, world.ground(FAMILY_AT.x, FAMILY_AT.y)), Vector3(12, 3.5, 10), 0.1)

static func frame(at: Vector2, height: float, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, height, -at.y))

static func airfield_frame(world: World, af: Airfield) -> Transform3D:
	var across := af.width / 2 + 38.0
	var along := -af.length * (0.15 if af.kind in ["hub", "regional"] else 0.3)
	return frame(Vector2(af.x + af.ux * along + af.uy * across, af.y + af.uy * along - af.ux * across), world.airfield_elev(af) + 0.12, atan2(af.uy, af.ux))

static func airfield_parts(af: Airfield) -> Array:
	var parts: Array
	match af.kind:
		"hub": parts = [["terminal", Vector3(0, 0, 18), 36, 14, 6], ["tower", Vector3(34, 0, 20), 4, 4, 16],
			["hangar", Vector3(-38, 0, 14), 22, 24, 11], ["hangar", Vector3(-64, 0, 14), 22, 24, 11, false],
			["pump", Vector3(14, 0, -6), 3, 3, 2], ["showroom", Vector3(64, 0, 14), 14, 9, 4]]
		"regional": parts = [["terminal", Vector3(0, 0, 14), 20, 10, 6], ["tower", Vector3(20, 0, 14), 4, 4, 10],
			["hangar", Vector3(-26, 0, 12), 18, 20, 9], ["pump", Vector3(10, 0, -6), 3, 3, 2], ["showroom", Vector3(42, 0, 12), 14, 9, 4]]
		"bush": parts = [["shed", Vector3(0, 0, 8), 7, 5, 2.8], ["drums", Vector3(7, 0, 4), 3, 3, 2]]
		_: parts = [["shed", Vector3(0, 0, 8), 6, 4, 2.8], ["drums", Vector3(6, 0, 4), 3, 3, 2]]
	var out := []
	for i in parts.size():
		var p: Array = parts[i]
		out.append({"id": "airfield/%s/%s/%d" % [af.code, p[0], i], "kind": p[0], "center": p[1],
			"dimensions": Vector3(p[2], p[4], p[3]), "with_board": bool(p[5]) if p.size() > 5 else true})
	return out

static func stash_spec(st: Dictionary) -> Dictionary:
	var spec: Array = STASH.get(str(st.kind), STASH.villa)
	return {"dimensions": Vector3(spec[0], spec[1], spec[2]), "floor": float(spec[3]), "material": str(spec[4]),
		"entry": Vector3(-6 if st.kind == "lockup" else 0, spec[3], -float(spec[2]) / 2)}

static func hq_frame(world: World, spec: Dictionary) -> Transform3D:
	var at := Vector2(spec.x, spec.y)
	var yaw := -deg_to_rad(spec.heading)
	# Costa Brava's nightclub anchor sits on the road centre. Keep the strategic
	# anchor and roads intact; set the physical building back into its reserved plot.
	if world.map.map_seed == MapCity.SEED and spec.get("style", "") == "nightclub":
		at += Vector2(24, 0)
		yaw = -deg_to_rad(270.0)  # front door faces the existing north/south street
	if world.map.map_seed == MapCity.SEED and spec.get("style", "") == "customs" and at.distance_to(MapCity.LAW_AT) < 0.1:
		at += Vector2(24, 0)  # clear the existing north/south customs access road
	return frame(at, world.ground(at.x, at.y), yaw)

static func stash_frame(world: World, st: Dictionary) -> Transform3D:
	var at := Vector2(st.x, st.y)
	if world.map.map_seed == MapCity.SEED:
		for anchor in MapCity.STASHES:
			if anchor.id in ["barn", "lockup"] and st.id == anchor.id and at.distance_to(Vector2(anchor.x, anchor.y)) < 0.1:
				at += Vector2(24, 0)  # physical setback only; stock/strategic anchors remain intact
				break
	return frame(at, world.ground(at.x, at.y))

static func hotel_anchor() -> Dictionary:
	var af := Island.airfield()
	return {"x": af.x + af.ux * 150.0 + af.uy * 75.0, "y": af.y + af.uy * 150.0 - af.ux * 75.0, "yaw": atan2(af.uy, af.ux)}

static func dock_sites(world: World) -> Array:
	if world.map.map_seed != MapCity.SEED:
		return []
	var out := []
	var x := MapCity.HARBOUR_X.x + 260.0
	var index := 0
	while x < MapCity.HARBOUR_X.y - 200.0:
		var y := MapCity.COAST_Y + 120.0
		while y > MapCity.COAST_Y - 200.0 and world.ground(x, y) >= 0.3:
			y -= 2.0
		if world.ground(x, y + 14.0) > 0.5:
			out.append([x, y, index])
		x += 170.0
		index += 1
	return out

static func record(world: World, id: String, kind: String, transform: Transform3D, dimensions: Vector3, floor := 0.0, entry = null) -> Dictionary:
	var entrance: Vector3 = transform * (Vector3(0, floor, -dimensions.z / 2) if entry == null else entry)
	var footprint := PackedVector2Array()
	for corner in [Vector3(-dimensions.x / 2, 0, -dimensions.z / 2), Vector3(dimensions.x / 2, 0, -dimensions.z / 2),
		Vector3(dimensions.x / 2, 0, dimensions.z / 2), Vector3(-dimensions.x / 2, 0, dimensions.z / 2)]:
		var p: Vector3 = transform * corner
		footprint.append(Vector2(p.x, -p.z))
	var outside: Vector3 = entrance + transform.basis * Vector3(0, 0, -4)
	var loading: Vector3 = entrance + transform.basis * Vector3(-dimensions.x / 2 - 4, 0, -3)
	outside.y = world.ground(outside.x, -outside.z) + 0.1
	loading.y = world.ground(loading.x, -loading.z) + 0.1
	var connector = null
	var distance := INF
	var at := Vector2(outside.x, -outside.z)
	for road in world.map.roads:
		for i in road.size() - 1:
			var a := Vector2(road[i][0], road[i][1])
			var b := Vector2(road[i + 1][0], road[i + 1][1])
			var p := Geometry2D.get_closest_point_to_segment(at, a, b)
			if at.distance_to(p) < distance:
				distance = at.distance_to(p)
				connector = p
	return {"id": id, "kind": kind, "transform": transform, "dimensions": dimensions, "footprint": footprint,
		"entrance": entrance, "approach": PackedVector3Array([outside, entrance]), "loading": loading,
		"connector": connector, "connector_distance": distance, "connection_verified": false}

static func records(world: World) -> Array:
	var out := []
	var family := family_site(world)
	if not family.is_empty(): out.append(family)
	for af in world.airfields:
		for part in airfield_parts(af):
			var transform := airfield_frame(world, af).translated_local(part.center)
			out.append(record(world, part.id, part.kind, transform, part.dimensions))
	for key in world.map.hqs:
		var hq: Dictionary = world.map.hqs[key]
		var dimensions: Vector3 = Vector3(40, 10, 40) if hq.kind == "rival" else (Vector3(24, 7.4, 13) if hq.kind == "law" else (Vector3(22, 8.6, 16) if hq.get("style", "") == "nightclub" else Vector3(26, 7, 26)))
		out.append(record(world, "hq/" + str(key), "hq", hq_frame(world, hq), dimensions, 0.1))
	for stash in world.map.stashes:
		var spec := stash_spec(stash)
		out.append(record(world, "stash/" + str(stash.id), "stash", stash_frame(world, stash), spec.dimensions, spec.floor, spec.entry))
	for dock in dock_sites(world):
		out.append(record(world, "dock/%d" % dock[2], "dock", frame(Vector2(dock[0], dock[1] - 18), 0.0), Vector3(6, 1, 36), 0.0, Vector3(0, 0, -18)))
	if not world.map.foreign.is_empty():
		var at := hotel_anchor()
		var transform := frame(Vector2(at.x, at.y), world.ground(at.x, at.y), at.yaw).translated_local(Vector3(0, 0, 23))
		out.append(record(world, "hotel/cielo", "hotel", transform, Vector3(68, 45, 46), 0.15))
	return out

static func diagnostics(world: World, sites: Array) -> Array:
	var issues := []
	for site in sites:
		var entrance: Vector3 = site.entrance
		if site.kind != "dock" and absf(entrance.y - world.ground(entrance.x, -entrance.z)) > 0.55:
			issues.append({"id": site.id, "reason": "Threshold needs a ramp or steps."})
		for af in world.airfields:
			if not Geometry2D.intersect_polygons(site.footprint, runway_footprint(af, 8.0)).is_empty():
				issues.append({"id": site.id, "reason": "Footprint intersects runway clearance."})
		if site.connector == null:
			issues.append({"id": site.id, "reason": "No public road connector; remote access needs separate validation."})
	for i in sites.size():
		for j in range(i + 1, sites.size()):
			if not Geometry2D.intersect_polygons(sites[i].footprint, sites[j].footprint).is_empty():
				issues.append({"id": sites[i].id, "reason": "Footprint overlaps " + str(sites[j].id)})
				issues.append({"id": sites[j].id, "reason": "Footprint overlaps " + str(sites[i].id)})
	return issues

## Full runway rectangle: intersection catches crossings and containment as well as corners.
static func runway_footprint(af: Airfield, margin := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var along := Vector2(af.ux, af.uy) * (af.length / 2 + margin)
	var across := Vector2(af.uy, -af.ux) * (af.width / 2 + margin)
	var center := Vector2(af.x, af.y)
	for point in [center - along - across, center + along - across, center + along + across, center - along + across]:
		out.append(point)
	return out
