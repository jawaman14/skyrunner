class_name AccessOverlay
extends Node3D
## Developer-only geometry; never contributes intelligence to player snapshots.
static func make(world: World) -> AccessOverlay:
	var root := AccessOverlay.new()
	root.name = "access-diagnostics"
	var sites := SiteAccess.new(world, world.site_records()).verified_records()
	var issues := SiteLayout.diagnostics(world, sites)
	var bad := {}
	for site in sites:
		if not site.connection_verified: bad[site.id] = str(site.connection_reason) + " "
	for issue in issues:
		bad[issue.id] = str(bad.get(issue.id, "")) + str(issue.reason) + " "
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for site in sites:
		var color := Color(1, 0.25, 0.15) if bad.has(site.id) else Color(0.2, 1, 0.7)
		var footprint: PackedVector2Array = site.footprint
		for i in footprint.size():
			var a := Vector3(footprint[i].x, site.transform.origin.y + 0.2, -footprint[i].y)
			var b := Vector3(footprint[(i + 1) % footprint.size()].x, a.y, -footprint[(i + 1) % footprint.size()].y)
			_line(mesh, a, b, color)
		var entrance: Vector3 = site.entrance + Vector3.UP * 0.1
		_line(mesh, entrance, entrance + Vector3.UP * 2, color)
		_line(mesh, site.approach[0] + Vector3.UP * 0.1, entrance, Color.CYAN)
		var loading: Vector3 = site.loading
		_line(mesh, loading - Vector3(2, 0, 0), loading + Vector3(2, 0, 0), Color.YELLOW)
		_line(mesh, loading - Vector3(0, 0, 3), loading + Vector3(0, 0, 3), Color.YELLOW)
		if site.connector is Vector2:
			var connector: Vector2 = site.connector
			if site.connection_verified:
				for key in ["walking_connector", "loading_connector"]:
					var points: PackedVector2Array = site[key]
					for i in points.size() - 1:
						var a := Vector3(points[i].x, world.travel_surface(points[i].x, points[i].y) + 0.1, -points[i].y)
						var b := Vector3(points[i + 1].x, world.travel_surface(points[i + 1].x, points[i + 1].y) + 0.1, -points[i + 1].y)
						_line(mesh, a, b, Color.CYAN if key == "walking_connector" else Color.YELLOW)
			else:
				_line(mesh, site.approach[0], Vector3(connector.x, world.travel_surface(connector.x, connector.y) + 0.1, -connector.y), Color(1, 0.65, 0.15))
		var label := Label3D.new()
		label.text = str(site.id) + "\n" + str(bad.get(site.id, "Access legs checked; road network/end-to-end route unverified"))
		label.font_size = 20
		label.pixel_size = 0.02
		label.modulate = color
		label.position = entrance + Vector3.UP * 2.2
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.visibility_range_end = 200
		root.add_child(label)
	mesh.surface_end()
	var drawing := MeshInstance3D.new()
	drawing.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	drawing.material_override = material
	root.add_child(drawing)
	return root

static func _line(mesh: ImmediateMesh, a: Vector3, b: Vector3, color: Color) -> void:
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
