extends TestCase
## One saves folder, one file per mode (owner, 12 Oct, #97): the file names, and the one-time move of an old player's loose files.

func _dir() -> String:
	var d := "user://save-paths-test-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	return d


func _put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _clean(dir: String) -> void:
	var abs_dir := ProjectSettings.globalize_path(dir)
	for sub in DirAccess.get_directories_at(abs_dir):
		for file in DirAccess.get_files_at(abs_dir.path_join(sub)):
			DirAccess.remove_absolute(abs_dir.path_join(sub).path_join(file))
		DirAccess.remove_absolute(abs_dir.path_join(sub))
	for file in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(file))
	DirAccess.remove_absolute(abs_dir)


## Owner, 18 Oct: save slots. Slot 1 keeps the old name, so an older game is slot 1.
func test_save_slots_keep_slot_one_on_the_old_name() -> void:
	check_eq(SavePaths.file_name(Roles.SOLO, true, 1), "story.json", "slot 1 is the save a player already has")
	check_eq(SavePaths.file_name(Roles.SOLO, true, 2), "story-2.json")
	check_eq(SavePaths.file_name(Roles.CAMPAIGN, false, 5), "campaign-5.json")
	check_eq(SavePaths.file_name(Roles.SOLO, false, 99), "open-%d.json" % SavePaths.SLOTS, "a slot past the last is the last")


func test_a_slot_describes_itself() -> void:
	var dir := _dir()
	check_eq(SavePaths.describe(dir + "story-2.json", 2), "Slot 2: empty")
	_put(dir + "story.json", JSON.stringify({"money": 12340, "story": {"index": 2}}))
	var line := SavePaths.describe(dir + "story.json", 1)
	check(line.begins_with("Slot 1: $12,340, chapter 3 (Blotter), saved "), "money, chapter and when: %s" % line)
	_clean(dir)


func test_each_mode_has_its_own_file() -> void:
	check_eq(SavePaths.file_name(Roles.SOLO, false), "open.json")
	check_eq(SavePaths.file_name(Roles.COOP, false), "open.json")
	check_eq(SavePaths.file_name(Roles.SOLO, true), "story.json", "the employed story")
	check_eq(SavePaths.file_name(Roles.CAMPAIGN, false), "campaign.json")
	check_eq(SavePaths.file_name(Roles.CAMPAIGN, true), "campaign.json", "the campaign wins over a story flag")
	check_eq(SavePaths.file_name(Roles.POLICE, false), "police.json")
	check_eq(SavePaths.DIR, "user://saves/", "one folder")


func test_old_loose_saves_move_into_the_folder_once() -> void:
	var base := _dir()
	var dest := base + "saves/"
	_put(base + "save.json", "{\"money\": 1}")
	_put(base + "story.json", "{\"money\": 2}")
	_put(base + "dedicated.json", "{\"money\": 3}")
	var moved := SavePaths.migrate(base, dest)
	moved.sort()
	check_eq(moved, ["dedicated.json", "save.json", "story.json"], "the three old files moved")
	check(FileAccess.file_exists(dest + "open.json"), "save.json became open.json")
	check(FileAccess.file_exists(dest + "story.json") and FileAccess.file_exists(dest + "dedicated.json"))
	check(not FileAccess.file_exists(base + "save.json") and not FileAccess.file_exists(base + "story.json"), "and are gone from the old place")
	check_eq(Session.read_save(dest + "open.json").get("money"), 1.0, "the content came with it")
	check_eq(SavePaths.migrate(base, dest), [], "a second run moves nothing")
	_clean(base)


func test_migration_never_overwrites_a_file_already_in_the_folder() -> void:
	var base := _dir()
	var dest := base + "saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest))
	_put(dest + "open.json", "{\"money\": 9}")
	_put(base + "save.json", "{\"money\": 1}")
	check_eq(SavePaths.migrate(base, dest), [], "nothing moved")
	check(FileAccess.file_exists(base + "save.json"), "the old file stays where it was")
	check_eq(Session.read_save(dest + "open.json").get("money"), 9.0, "the new one is untouched")
	_clean(base)


func test_an_empty_install_just_gets_the_folder() -> void:
	var base := _dir()
	check_eq(SavePaths.migrate(base, base + "saves/"), [])
	check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(base + "saves/")), "the folder exists")
	_clean(base)
