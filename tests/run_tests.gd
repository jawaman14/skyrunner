extends SceneTree
## godot --headless --script res://tests/run_tests.gd [-- filter]
## Runs every tests/test_*.gd; exit code is the number of failed tests. SHARD=i/n runs one slice of the files.

var _started := false


func _process(_dt: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var files: Array[String] = []
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			files.append(f)
	files.sort()
	# SHARD="i/n" (1-based) runs every n-th file starting at the i-th: CI runs the suite as parallel jobs
	var shard := OS.get_environment("SHARD")
	if shard.contains("/"):
		var parts := shard.split("/")
		var si := int(parts[0]) - 1
		var sn := maxi(1, int(parts[1]))
		var mine: Array[String] = []
		for k in files.size():
			if k % sn == si:
				mine.append(files[k])
		files = mine
	var passed := 0
	var failed := 0
	var t0 := Time.get_ticks_msec()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			printerr("FAIL %s: script failed to load (parse error above)" % f)
			failed += 1
			continue
		Terrain.natural = false  # main.gd turns it on for the game; a test that loads main must not leak it into the next file
		var inst = script.new()
		var names: Array[String] = []
		for m in script.get_script_method_list():
			if m.name.begins_with("test_") and (filter == "" or filter in f or filter in m.name):
				if not names.has(m.name):
					names.append(m.name)
		for n in names:
			inst.current = "%s::%s" % [f.get_basename(), n]
			inst.failures.clear()
			inst.before_each()
			await inst.call(n)
			inst.after_each()
			if inst.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for msg in inst.failures:
					printerr("FAIL ", msg)
	print("%d passed, %d failed in %.1f s" % [passed, failed, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(failed)
