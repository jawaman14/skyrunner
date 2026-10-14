extends SceneTree
## Real ModelLib vehicle instances staged for visual review in WorldScene.
## No gameplay simulation; the review pad and lineup are capture-only nodes.

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else ProjectSettings.globalize_path("user://vehicle-screenshots")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	World.use_map(MapCity.SEED)
	Terrain.natural = true
	var world := World.new()
	var scene := WorldScene.new().setup(world, Quality.get_preset("medium"))
	root.add_child(scene)
	scene.set_hour(14)
	var af := World.airfield("HAR")
	var frame := SiteLayout.airfield_frame(world, af)
	var stage := Node3D.new()
	stage.name = "capture-only-review-pad"
	stage.transform = frame.translated_local(Vector3(64, 0.1, -16))
	scene.add_child(stage)
	var pad := MeshInstance3D.new()
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(8, 0.1, 9)
	pad.mesh = pad_mesh
	pad.position.y = -0.05
	pad.material_override = Buildings.mat("concrete")
	stage.add_child(pad)
	var camera := Camera3D.new()
	camera.fov = 48
	camera.far = 60000
	camera.near = 0.1
	scene.add_child(camera)
	camera.current = true
	var index := 0
	for file in PeriodVehicles.TYPES:
		var length := 4.6
		for spec in Dealership.CATALOGUE:
			if spec.model == file:
				length = float(spec.len)
		var model := ModelLib.vehicle(file, length)
		stage.add_child(model)
		var size := ModelLib.bounds(model).size
		var distance := maxf(8.0, size.z * 1.65)
		camera.global_position = stage.transform * Vector3(-distance * 0.65, size.y + 1.8, -distance * 0.85)
		camera.look_at(stage.transform * Vector3(0, size.y * 0.48, 0), Vector3.UP)
		index += 1
		if not await _save(output.path_join("%02d-%s-front.png" % [index, file])):
			return
		if file in ["truck-flat", "suv-luxury", "delivery"]:
			camera.global_position = stage.transform * Vector3(distance * 0.65, size.y + 1.8, distance * 0.85)
			camera.look_at(stage.transform * Vector3(0, size.y * 0.48, 0), Vector3.UP)
			if not await _save(output.path_join("%02d-%s-rear.png" % [index, file])):
				return
		model.free()
	stage.free()
	# The existing dealership is rebuilt through ModelLib, without staging nodes.
	camera.global_position = frame * Vector3(82, 7.5, -12)
	camera.look_at(frame * Vector3(64, 1.8, 7), Vector3.UP)
	if not await _save(output.path_join("13-existing-dealership.png")):
		return
	quit()

func _save(path: String) -> bool:
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(path)
	print("VEHICLE CAPTURE ", path, " result=", result)
	if result != OK:
		quit(1)
		return false
	return true
