extends SceneTree
## Render-only paired legacy/period fleet; identical camera, roster and lighting.
var camera: Camera3D
var samples: Array[float] = []
var frame := 0
var previous := 0
var mode := "period"
func _initialize() -> void: call_deferred("_setup")
func _setup() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): mode = args[0]
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scene := Node3D.new()
	root.add_child(scene)
	var files := PeriodVehicles.TYPES.keys()
	for i in 60:
		var file: String = files[i%files.size()]
		var model: Node3D = ModelLib.wrapped("cars/"+file,ModelLib.fit_scale("cars/"+file,4.6)) if mode == "legacy" else ModelLib.vehicle(file,4.6)
		scene.add_child(model)
		model.position = Vector3((i%10-5)*7,0,(i/10-3)*9)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-30,0)
	sun.shadow_enabled = true
	scene.add_child(sun)
	camera = Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	previous = Time.get_ticks_usec()
	process_frame.connect(_frame)
func _frame() -> void:
	var now := Time.get_ticks_usec()
	if frame >= 180: samples.append((now-previous)/1000.0)
	previous = now
	var t := float(frame%360)/360.0
	var distance := 35.0+200.0*(.5+.5*cos(t*TAU))
	camera.position = Vector3(sin(t*TAU)*distance,distance*.4,cos(t*TAU)*distance)
	camera.look_at(Vector3.ZERO)
	frame += 1
	if frame < 540: return
	samples.sort()
	var total := 0.0
	for sample in samples: total += sample
	var result := {"mode":mode,"vehicles":60,"resolution":"1280x720","warmup_frames":180,"sample_frames":samples.size(),"mean_ms":total/samples.size(),"p95_ms":samples[int(samples.size()*.95)],"static_memory_bytes":OS.get_static_memory_usage(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		var output := FileAccess.open(args[1],FileAccess.WRITE)
		output.store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result))
	quit()
