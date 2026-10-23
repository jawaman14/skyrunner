extends SceneTree
## Capture the real WorldScene from fixed map cameras (no gameplay/HUD simulation).
## Run with a graphical renderer: godot --path . --script res://tools/capture_world_scenery.gd -- /path/to/output

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else ProjectSettings.globalize_path("user://world-screenshots")
	root.size = Vector2i(1280, 720)
	World.use_map(MapCity.SEED)
	Terrain.natural = true
	var world := World.new()
	var scene := WorldScene.new().setup(world, Quality.get_preset("medium"))
	root.add_child(scene)
	scene.set_hour(14)
	var camera := Camera3D.new()
	camera.far = 60000
	camera.near = 0.15
	camera.fov = 62
	scene.add_child(camera)
	camera.current = true
	var club: Dictionary = world.map.hqs.org
	var law: Dictionary = world.map.hqs.law
	var rival: Dictionary = world.map.hqs.rival
	var club_frame := SiteLayout.hq_frame(world, club)
	var law_frame := SiteLayout.hq_frame(world, law)
	var rival_frame := SiteLayout.hq_frame(world, rival)
	var shots := [
		["01-club-tropicana", club_frame * Vector3(25, 14, -38), club_frame * Vector3(0, 4.5, 0), 14.0],
		["01-club-evening", club_frame * Vector3(16, 7, -27), club_frame * Vector3(0, 3.5, -7), 19.0],
		["02-customs-house", law_frame * Vector3(32, 17, -36), law_frame * Vector3(0, 6, 0), 14.0],
		["03-hacienda", rival_frame * Vector3(44, 24, -50), rival_frame * Vector3(0, 4, 4), 15.0],
		["04-hotel-cielo", CasinoBuilding.world_point(world, 95, 32, -64), CasinoBuilding.world_point(world, 0, 15, 20), 15.0],
		["05-casino-lobby", CasinoBuilding.world_point(world, 4, 2.3, 2), CasinoBuilding.world_point(world, 0, 2.8, 24), 15.0]
	]
	var sites := CityRender.sidewalk_sites(world, world.map.roads)
	for kind in ["coffee", "domino"]:
		for site in sites:
			if site.kind != kind:
				continue
			var frame := Transform3D(Basis(Vector3.UP, float(site.yaw)), Vector3(site.at.x, site.height, -site.at.y))
			shots.append(["06-street-" + kind, frame * Vector3(4.5, 2.5, -7), frame * Vector3(0, 1.2, 0), 15.0])
			break
	var farm := Vector3(MapCity.FARM_C.x, world.ground(MapCity.FARM_C.x, MapCity.FARM_C.y), -MapCity.FARM_C.y)
	shots.append(["07-terrain-fields", farm + Vector3(280, 230, 340), farm + Vector3(0, 10, -170), 15.0])
	DirAccess.make_dir_recursive_absolute(output)
	for shot in shots:
		scene.set_hour(float(shot[3]))
		camera.global_position = shot[1]
		camera.look_at(shot[2], Vector3.UP)
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		var path: String = output.path_join(str(shot[0]) + ".png")
		var result := picture.save_png(path)
		print("CAPTURE ", path, " result=", result)
		if result != OK:
			quit(1)
			return
	quit()

