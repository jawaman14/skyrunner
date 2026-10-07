extends SceneTree
## Reproducible visual review, not a gameplay/access acceptance test.
## godot --path . --script res://tools/costa_review.gd -- [absolute output directory]
func _initialize() -> void:
	call_deferred("_review")

func _review() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Supply an output directory.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(args[0])
	root.size = Vector2i(1280, 720)
	World.use_map(MapCity.SEED)
	var world := World.new()
	var scene := WorldScene.new().setup(world, Quality.get_preset("high"))
	root.add_child(scene)
	scene.hour = 14
	scene.time_scale = 0
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	var shots := [
		["old-town", Vector3(-2100, 35, 10000), Vector3(-1950, 7, 10100)],
		["port", Vector3(-2050, 45, 11260), Vector3(-1700, 5, 11000)],
		["city-overview", Vector3(-1200, 3200, 11900), Vector3(-1200, 0, 9950)],
	]
	for shot in shots:
		camera.position = shot[1]
		camera.look_at(shot[2])
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png(args[0].path_join(shot[0] + ".png"))
		if result != OK:
			printerr("Cannot save visual review: ", result)
			quit(1)
			return
	var districts := {}
	for b in world.map.buildings: districts[b.district] = districts.get(b.district, 0) + 1
	print(JSON.stringify({"revision": CostaBravaPlan.VERSION, "buildings": world.map.buildings.size(), "roads": world.map.roads.size(), "trunk_roads": world.map.settlement_trunk_count, "districts": districts}))
	quit()
