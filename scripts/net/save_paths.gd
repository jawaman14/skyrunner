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
const OLD_DIR := "user://"
## Old name -> new name. save.json was the open game; the rest keep their names.
const MOVES := {"save.json": "open.json", "story.json": "story.json", "campaign.json": "campaign.json", "police.json": "police.json", "dedicated.json": "dedicated.json"}


## The file for a mode ("story" is the employed story: a solo or co-op game with the story's chapters).
static func file_name(mode: String, story := false) -> String:
	if mode == Roles.CAMPAIGN:
		return "campaign.json"
	if mode == Roles.POLICE:
		return "police.json"
	return "story.json" if story else "open.json"


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
