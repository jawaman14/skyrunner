class_name TestLanes
extends RefCounted
## Execution-only partition. Unclassified new tests run in simulation.
const NAMES := ["logic", "simulation", "presentation", "socket"]

static func manifest() -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string("res://tests/test_lanes.json"))
	return value if value is Dictionary else {}

static func lane(file: String, groups: Dictionary) -> String:
	for name in NAMES:
		if file in groups.get(name, []): return name
	return "simulation"

static func problems(files: Array[String], groups: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var seen := {}
	for name in NAMES:
		if not groups.get(name) is Array:
			errors.append("Missing lane: " + name)
			continue
		for file in groups[name]:
			if seen.has(file): errors.append("Duplicate lane assignment: " + str(file))
			if not file in files: errors.append("Stale lane assignment: " + str(file))
			seen[file] = name
	for name in groups:
		if not name in NAMES: errors.append("Unknown lane: " + str(name))
	return errors
