extends SceneTree
## Source inventory, not evidence that tests or human acceptance have passed.
## Run after import: godot --headless --script res://tools/project_status.gd -- --write
const PATH := "res://docs/PROJECT_STATUS.md"
const BEGIN := "<!-- BEGIN GENERATED PROJECT STATUS -->"
const END := "<!-- END GENERATED PROJECT STATUS -->"

func _initialize() -> void:
	var text := FileAccess.get_file_as_string(PATH).replace("\r\n", "\n")
	var start := text.find(BEGIN)
	var finish := text.find(END)
	if start < 0 or finish <= start:
		printerr("FAIL project status: generated markers missing or invalid")
		quit(1)
		return
	var generated := _inventory()
	if generated == "":
		quit(1)
		return
	var expected := text.substr(0, start + BEGIN.length()) + "\n" + generated + text.substr(finish)
	if "--write" in OS.get_cmdline_user_args():
		var file := FileAccess.open(PATH, FileAccess.WRITE)
		if file == null:
			printerr("FAIL project status: cannot write evidence record")
			quit(1)
			return
		file.store_string(expected)
		print("PROJECT STATUS UPDATED")
		quit(0)
	elif text != expected:
		printerr("FAIL project status: source inventory is stale; run tools/project_status.gd -- --write")
		quit(1)
	else:
		print("PROJECT STATUS CURRENT")
		quit(0)

func _inventory() -> String:
	var files := 0
	var tests := 0
	for name in DirAccess.get_files_at("res://tests"):
		if not name.begins_with("test_") or not name.ends_with(".gd") or name == "test_case.gd": continue
		var script: GDScript = load("res://tests/" + name)
		if script == null or not script.can_instantiate():
			printerr("FAIL project status: cannot inspect " + name)
			return ""
		files += 1
		var methods := {}
		for method in script.get_script_method_list():
			if str(method.name).begins_with("test_"): methods[method.name] = true
		tests += methods.size()
	var config := ConfigFile.new()
	if config.load("res://export_presets.cfg") != OK:
		printerr("FAIL project status: export configuration unavailable")
		return ""
	var targets: Array[String] = []
	var preset := RegEx.new()
	preset.compile("^preset\\.[0-9]+$")
	for section in config.get_sections():
		if preset.search(section) != null: targets.append(str(config.get_value(section, "name")))
	var rows := [
		["Version", str(ProjectSettings.get_setting("application/config/version")), "project.godot"],
		["Declared automated tests", "%d methods in %d test files" % [tests, files], "Compiled source inventory; this is not a test result"],
		["Flying tutorial", "%d Costa Brava chapters" % Campaign.CHAPTERS.size(), "Campaign.CHAPTERS"],
		["Main story", "%d chapters" % Story.CHAPTERS.size(), "Story.CHAPTERS; distinct from the tutorial"],
		["Configured exports", ", ".join(targets), "Export presets; build/manual acceptance is recorded below"],
		["Multiplayer protocol", str(Snapshot.PROTOCOL_VERSION), "Implemented wire version; real two-machine verification remains pending"],
	]
	var result := "## Generated source inventory\n\n"
	result += "This section describes **this checkout**. Run `godot --headless --script res://tools/project_status.gd -- --write` after source changes. CI checks it after import. Passing test runs, shipped builds and human verification are separate evidence below.\n\n"
	result += "| Field | Source value | Meaning / source |\n|---|---|---|\n"
	for row in rows: result += "| %s | %s | %s |\n" % row
	return result + "\n"
