extends SceneTree
## Render the HAR workshop asset envelope for visual review; output path is optional.
func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	root.size = Vector2i(960, 640)
	var scene := Node3D.new()
	root.add_child(scene)
	var kit := Buildings.Kit.new("workshop-preview")
	kit.box(Vector3(0, 0.6, 0), Vector3(3, 1.2, 1.2), "wood")
	kit.box(Vector3(0, 1.8, 1.03), Vector3(4, 3.6, 0.1), "concrete_dark")
	var preview_args := OS.get_cmdline_user_args()
	if preview_args.size() > 1 and preview_args[1] == "dock":
		Buildings.mooring_set(kit, Vector3(0, 1.2, 0))
	else:
		Buildings.workshop_tools(kit, Vector3.ZERO)
	var model := kit.finish()
	var triangles := 0
	for child in model.get_children():
		if child is MeshInstance3D: triangles += child.mesh.get_faces().size() / 3
	print("Workshop preview triangles including bench/wall: ", triangles)
	scene.add_child(model)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(2.8, 2.7, -4)
	camera.look_at(Vector3(0, 1.5, 0))
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -25, 0)
	sun.light_energy = 1.5
	scene.add_child(sun)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.16, 0.19, 0.2)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.7, 0.75, 0.8)
	settings.ambient_light_energy = 0.7
	environment.environment = settings
	scene.add_child(environment)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "user://workshop-preview.png"
	var error := root.get_texture().get_image().save_png(output)
	print("Workshop preview: ", output, " result=", error)
	quit(0 if error == OK else 1)
