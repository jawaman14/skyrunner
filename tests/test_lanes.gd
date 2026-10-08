extends TestCase

func test_manifest_partitions_files_without_omitting_new_tests() -> void:
	var files: Array[String] = []
	for file in DirAccess.get_files_at("res://tests"):
		if file.begins_with("test_") and file.ends_with(".gd") and file != "test_case.gd": files.append(file)
	files.sort()
	var groups := TestLanes.manifest()
	check_eq(TestLanes.problems(files, groups), [])
	var assigned := 0
	for name in TestLanes.NAMES:
		for file in files:
			if TestLanes.lane(file, groups) == name: assigned += 1
	check_eq(assigned, files.size(), "every test file runs exactly once across lanes")
	check_eq(TestLanes.lane("test_new_system.gd", groups), "simulation", "new files never disappear")

func test_duplicate_stale_and_invalid_groups_fail_configuration() -> void:
	var files: Array[String] = ["test_a.gd"]
	var groups := {"logic": ["test_a.gd"], "simulation": ["test_a.gd"],
		"presentation": ["test_deleted.gd"], "socket": [], "typo": []}
	var errors := TestLanes.problems(files, groups)
	check_eq(errors.size(), 3)
	check(errors.any(func(error): return error.contains("Duplicate")))
	check(errors.any(func(error): return error.contains("Stale")))
	check(errors.any(func(error): return error.contains("Unknown")))
