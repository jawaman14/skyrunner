class_name SavePaths
extends RefCounted
## Where a game is kept (owner, 12 Oct, question 10a): one folder, one file per mode. They used to sit loose in the user data folder under four
## different names (save.json, story.json, campaign.json and the dedicated server's dedicated.json); `migrate` moves an old player's files once.
##
##   user://saves/open.json       an open game
##   user://saves/story.json      the employed story
##   user://saves/campaign.json   the campaign
##   user://saves/police.json     a task-force table
##   user://saves/dedicated.json  the dedicated server's game

const DIR := "user://saves/"
const SLOTS := 5  ## save slots per mode (owner, 18 Oct: pick which save to use); slot 1 is the file every older game already has
const OLD_DIR := "user://"
## Old name -> new name. save.json was the open game; the rest keep their names.
const MOVES := {"save.json": "open.json", "story.json": "story.json", "campaign.json": "campaign.json", "police.json": "police.json", "dedicated.json": "dedicated.json"}


## The file for a mode ("story" is the employed story: a solo or co-op game with the story's chapters) and a slot (1..SLOTS):
## slot 1 is "story.json", slot 2 "story-2.json".
static func file_name(mode: String, story := false, slot := 1) -> String:
	var base := "campaign" if mode == Roles.CAMPAIGN else ("police" if mode == Roles.POLICE else ("story" if story else "open"))
	return base + (".json" if slot <= 1 else "-%d.json" % clampi(slot, 1, SLOTS))


## One line for a save slot, for the lobby: "Slot 2: empty" or "Slot 1: $12,340, chapter 3 (Blotter), saved 17 Oct 21:04".
static func describe(path: String, slot: int) -> String:
	var d := Session.read_save(path)
	if d.is_empty():
		return "Slot %d: empty" % slot
	var parts := ["$" + Py.money(int(d.get("money", 0)))]
	var st = d.get("story")
	if st is Dictionary:
		var i := int(st.get("index", 0))
		if i >= 0 and i < Story.CHAPTERS.size():
			parts.append("chapter %d (%s)" % [i + 1, Story.CHAPTERS[i][1]])
	var at := FileAccess.get_modified_time(path)
	if at > 0:
		parts.append("saved " + Time.get_datetime_string_from_unix_time(at + Time.get_time_zone_from_system().bias * 60, true).substr(0, 16))
	return "Slot %d: %s" % [slot, ", ".join(parts)]


## Move files saved the old way into the folder. Never overwrites: a file already in the folder wins, the old one stays where it was.
## Returns the names moved.
static func migrate(from_dir := OLD_DIR, to_dir := DIR) -> Array:
	var moved := []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(to_dir))
	for old_name in MOVES:
		var old_path := from_dir.path_join(old_name)
		var new_path := to_dir.path_join(MOVES[old_name])
		if FileAccess.file_exists(old_path) and not FileAccess.file_exists(new_path):
			if DirAccess.rename_absolute(ProjectSettings.globalize_path(old_path), ProjectSettings.globalize_path(new_path)) == OK:
				moved.append(old_name)
	return moved
