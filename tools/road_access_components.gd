extends SceneTree
## Read-only checked-road connectivity diagnostic; no orders or stock mutations.
## godot --headless --path . --script res://tools/road_access_components.gd -- [output.json]
func _initialize() -> void:
	var session := Session.new({"seed": 12, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "ground_war": true, "trade": true, "payroll": true, "logistics": true})
	var access := SiteAccess.new(session.world, session.world.site_records())
	var graph := session.ground.graph.checked_network()
	var components := {}
	var reasons := {}
	var blocked := []
	var grade_categories := {}
	var allowed := {}
	for i in graph.nodes.size():
		for edge in graph.adj[i]:
			var j := int(edge[0])
			if j <= i: continue
			var reason := access.segment_reason(graph.nodes[i], graph.nodes[j], true)
			allowed[Vector2i(i,j)] = reason == ""
			allowed[Vector2i(j,i)] = reason == ""
			if reason != "":
				reasons[reason] = int(reasons.get(reason,0)) + 1
				var a: Vector2 = graph.nodes[i]
				var b: Vector2 = graph.nodes[j]
				var row := {"from":[a.x,a.y],"to":[b.x,b.y],"metres":a.distance_to(b),"reason":reason}
				if "grade" in reason:
					var count := maxi(1, int(ceil(a.distance_to(b) / SiteAccess.SAMPLE_M)))
					var terrain_grade := 0.0
					var surface_grade := 0.0
					var previous := a
					for sample in range(1, count + 1):
						var point := a.lerp(b, float(sample) / count)
						var metres := previous.distance_to(point)
						if metres > 0.01:
							terrain_grade = maxf(terrain_grade, absf(session.world.ground(point.x,point.y)-session.world.ground(previous.x,previous.y))/metres)
							surface_grade = maxf(surface_grade, absf(session.world.travel_surface(point.x,point.y)-session.world.travel_surface(previous.x,previous.y))/metres)
						previous = point
					var category := "terrain_already_steep" if terrain_grade > 0.18 else "surface_adds_steepness"
					row["terrain_grade"] = terrain_grade
					row["surface_grade"] = surface_grade
					row["grade_category"] = category
					grade_categories[category] = int(grade_categories.get(category,0)) + 1
				blocked.append(row)
	var sizes := []
	for i in graph.nodes.size():
		if components.has(i): continue
		var id := sizes.size()
		var queue := [i]
		components[i] = id
		var count := 0
		while count < queue.size():
			var at: int = queue[count]
			count += 1
			for edge in graph.adj[at]:
				var j := int(edge[0])
				if components.has(j) or not allowed.get(Vector2i(at,j),false): continue
				components[j] = id
				queue.append(j)
		sizes.append(count)
	var endpoints := []
	for site in ["hq", "barn", "docks", "lockup", "camp", "villa", "quarry", "shack", "agency"]:
		var endpoint: Dictionary = session.logistics.loading_endpoint(site,"hq",access)
		if not endpoint.available: continue
		var connector := access._vehicle_connector(graph,endpoint.point)
		endpoints.append({"site":site,"reason":connector.reason,"component":components.get(connector.index,-1),"index":connector.index})
	var report := {"map":"Costa Brava","seed":12,"nodes":graph.nodes.size(),"components":sizes,"blocked_edges":reasons,"grade_categories":grade_categories,"blocked_segments":blocked,"endpoints":endpoints}
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://sim-results/road-access-components.json"
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null:
		printerr("Cannot write connectivity report: ", output)
		session.dispose()
		quit(1)
		return
	file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	session.dispose()
	quit()
