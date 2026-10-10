extends SceneTree
## Fixed, render-only HAR/warehouse/harbour camera route. Run identical settings
## before/after a batch; rendered frame times are machine-specific, not CI gates.
## godot --path . --script res://tools/coastal_benchmark.gd -- [quality] [output.json]
var world_scene: WorldScene
var camera: Camera3D
var points: Array[Vector3] = []
var samples: Array[float] = []
var frame := 0
var previous := 0
var quality := "low"

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): quality = args[0]
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	World.use_map(MapCity.SEED)
	var world := World.new()
	world_scene = WorldScene.new().setup(world, Quality.get_preset(quality))
	root.add_child(world_scene)
	world_scene.hour = 14
	world_scene.time_scale = 0
	var har = world.airfields.filter(func(af): return af.code == "HAR")[0]
	var origin: Vector3 = SiteLayout.airfield_frame(world, har).origin
	points.append(origin + Vector3(0, 6, -40))
	points.append(origin + Vector3(45, 8, -18))
	var warehouse = world.map.stashes.filter(func(st): return st.id == "docks")[0]
	points.append(Vector3(warehouse.x, world.ground(warehouse.x, warehouse.y) + 8, -warehouse.y + 40))
	var pier: Array = SiteLayout.dock_sites(world)[0]
	points.append(Vector3(pier[0], 9, -pier[1] - 25))
	camera = Camera3D.new()
	world_scene.add_child(camera)
	camera.current = true
	previous = Time.get_ticks_usec()
	process_frame.connect(_frame)

func _frame() -> void:
	var now := Time.get_ticks_usec()
	if frame >= 360: samples.append((now - previous) / 1000.0)
	previous = now
	var route_frame := frame % 360
	var leg := mini(route_frame / 120, points.size() - 2)
	var weight := float(route_frame % 120) / 120.0
	camera.global_position = points[leg].lerp(points[leg + 1], weight)
	camera.look_at(camera.global_position + Vector3(0, -2, -10))
	frame += 1
	if frame < 720: return
	samples.sort()
	var total := 0.0
	for sample in samples: total += sample
	var result := {"map": "Costa Brava", "quality": quality, "resolution": "1280x720", "hour": 14, "warmup_frames": 360, "sample_frames": samples.size(), "mean_ms": total / samples.size(), "p95_ms": samples[int(samples.size() * 0.95)], "static_memory_bytes": OS.get_static_memory_usage(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		var file := FileAccess.open(args[1], FileAccess.WRITE)
		if file == null:
			printerr("Cannot write benchmark report.")
			quit(1)
			return
		file.store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify(result))
	quit()
