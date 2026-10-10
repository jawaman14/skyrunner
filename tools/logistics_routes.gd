extends SceneTree
## Read-only Costa Brava migration baseline. No dispatch, stock or balance changes.
## godot --headless --path . --script res://tools/logistics_routes.gd -- [output.json]
func _initialize() -> void:
	var session := Session.new({"seed": 12, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "ground_war": true, "trade": true, "payroll": true, "logistics": true})
	var access := SiteAccess.new(session.world, session.world.site_records())
	var sites: Array = [Logistics.HQ]
	for stash in session.stash_net.live(): sites.append(stash.id)
	for meet in Logistics.MEETS: sites.append(meet)
	sites.sort()
	var rows := []
	var failed := 0
	var loading_failed := 0
	for from in sites:
		for to in sites:
			if from == to or Logistics.MEETS.has(from): continue
			var a: Vector2 = session.logistics.pos(from)
			var b: Vector2 = session.logistics.meet_pos(to, from)
			var legacy := session.ground.route("org", a, b)
			var checked := access.checked_vehicle_route(session.ground.graph, a, b, session.ground._penalty("org") if GroundWar.SMART_ROUTES else Callable())
			if not checked.reachable: failed += 1
			var start: Dictionary = session.logistics.loading_endpoint(from, "", access)
			var finish: Dictionary = session.logistics.loading_endpoint(to, from, access)
			var loading := {"reachable": false, "points": PackedVector2Array(), "reason": start.reason if not start.available else finish.reason}
			if start.available and finish.available:
				loading = access.checked_vehicle_route(session.ground.graph, start.point, finish.point, session.ground._penalty("org") if GroundWar.SMART_ROUTES else Callable())
			if not loading.reachable: loading_failed += 1
			rows.append({"from": from, "to": to, "legacy_metres": RoadGraph.length(legacy), "checked_reachable": checked.reachable, "checked_metres": RoadGraph.length(checked.points), "reason": checked.reason,
				"loading_reachable": loading.reachable, "loading_metres": RoadGraph.length(loading.points), "loading_reason": loading.reason, "source_site": start.site_id, "destination_site": finish.site_id})
	var result := {"map": "Costa Brava", "seed": 12, "pairs": rows.size(), "unreachable": failed, "loading_unreachable": loading_failed, "routes": rows}
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		if file == null:
			printerr("Cannot write route report: ", args[0])
			session.dispose()
			quit(1)
			return
		file.store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify(result))
	session.dispose()
	quit()
