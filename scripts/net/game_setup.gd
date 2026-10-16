class_name GameSetup
extends RefCounted
## The one place a game's session options come from. The pilot app (scripts/main.gd), the host desk and the dedicated server (scripts/net/dedicated_server.gd)
## used to each build the same dictionary by hand; a system added to one and not the others made a hosted game differ from a solo one. They all call this now
## (the shared host service of #97, step 1; the owner chose one shared service on 12 Oct).
##
##   var o := GameSetup.options(mode, seed, story)        # everything on; story: the chapters open the systems; otherwise a start-up float
##   o["map_seed"] = GameSetup.map_seed(arg_map, has_save) # the caller decides what a map argument and an existing save mean
##   var p := GameSetup.police(seed, map_arg)              # a task-force table for remote players against AI runners

## The systems an open game has on from the first minute (and that a story game leaves to the chapters).
const OPEN_SYSTEMS := ["ground_war", "chronicle", "agency", "family", "island", "court", "payroll", "trade", "logistics", "renown", "rackets", "races",
	"airframe", "casino", "dealership", "psychedelics"]


## Session options for a normal (non-police) game. `story`: the story's chapters build the systems as they open, so only the career flag is set; otherwise
## the game is open: every system live at once, with a float of start-up money. Campaign mode never gets the float (its chapters do the setup).
static func options(mode: String, seed_: int, story: bool) -> Dictionary:
	var o := {"seed": seed_, "mode": mode, "ai_law_upgrades": true}
	for k in OPEN_SYSTEMS:
		o[k] = true
	o["fog"] = true  # sea-fog weather (not fog of war)
	if story:
		for k in Session.SYSTEMS:
			o.erase(k)
		o["career"] = true
	elif mode != Roles.CAMPAIGN:
		o["money"] = Session.OPEN_FLOAT
	return o


## A task-force table for remote players against AI runners.
static func police(seed_: int, map_arg: int) -> Dictionary:
	var o := {"mode": Roles.POLICE, "seed": seed_, "map_seed": map_arg if map_arg >= 0 else MapCity.SEED, "career": true, "fog": true, "money": Session.OPEN_FLOAT}
	for k in OPEN_SYSTEMS:
		o[k] = true
	return o


## Which map a game starts on: a map argument wins (positive seeds are generated maps); a new game with none starts on the city coast; an existing save
## with none keeps the island it was made on (-1: leave the option out).
static func map_seed(map_arg: int, has_save: bool) -> int:
	if map_arg >= 0:
		return map_arg
	return -1 if has_save else MapCity.SEED
