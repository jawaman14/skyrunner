extends SceneTree
## Reproducible asset turntable/contact sheet; no simulation state or player saves.
func _initialize() -> void: call_deferred("_render")

func _render() -> void:
	root.size = Vector2i(1600,1000)
	var scene := Node3D.new()
	root.add_child(scene)
	var files := ["sedan","sedan-sports","suv-luxury","suv","van","truck-flat","police","delivery","ambulance"]
	for i in files.size():
		var faction: String = "police" if files[i] == "police" else ("rival" if files[i] == "truck-flat" else ["civilian","org","family"][i%3])
		var model := ModelLib._period_vehicle(files[i],4.8 if i < 4 else 5.4,faction)
		scene.add_child(model)
		model.position = Vector3((i%3-1)*7.0,0,(i/3-1)*7.0)
		model.rotation.y = -.25
		var label := Label3D.new()
		label.text = files[i].replace("-"," ")
		label.position = model.position + Vector3(0,2.9,0)
		label.font_size = 42
		label.pixel_size = .009
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		scene.add_child(label)
	var floor := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(32,.1,32)
	floor.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.36,.35,.31)
	mat.roughness = 1
	floor.material_override = mat
	floor.position.y = -.06
	scene.add_child(floor)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(19,21,-27)
	camera.look_at(Vector3(0,.6,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 29
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-30,0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	scene.add_child(sun)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(.16,.18,.18)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(.76,.80,.84)
	settings.ambient_light_energy = .6
	environment.environment = settings
	scene.add_child(environment)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "user://period-vehicles.png"
	var error := root.get_texture().get_image().save_png(output)
	print("Vehicle preview: ",output," result=",error)
	quit(0 if error == OK else 1)
