class_name PlayableMaps
extends RefCounted
## Player entry-point policy. The classic geography remains a frozen internal
## parity/balance reference, never a selectable new game or a silently moved save.

const CLASSIC_REMOVED := "The classic island is no longer playable. Start a new Costa Brava game. Your old save has not been changed."


static func error(requested: int, saved: Dictionary = {}) -> String:
	if requested == 0:
		return CLASSIC_REMOVED
	if not saved.is_empty() and int(saved.get("map_seed", 0)) == 0:
		return CLASSIC_REMOVED
	return ""
