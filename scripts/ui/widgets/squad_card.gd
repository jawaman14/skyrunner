extends RefCounted
## Shared command detail for the local HQ and snapshot-driven seats.
static func describe(row: Dictionary) -> String:
	var rank := clampi(int(row.get("rank", 0)), 0, GroundWar.RANKS.size() - 1)
	var doing: String = str(row.get("tactic", ""))
	if doing == "": doing = str(row.get("order", "hold"))
	var lines := ["%s · %s · %d/%d people · %s" % [row.get("id", ""), row.get("kind", "unit"), int(row.get("men", 0)), int(row.get("men0", 0)), GroundWar.RANKS[rank]],
		"%s · %d rounds · morale %.0f%%" % [Arsenal.describe(row.get("loadout", {})), int(row.get("ammo", 0)), 100.0 * float(row.get("morale", 0.0))],
		"Order: %s · %s" % [doing, row.get("state", "unknown")]]
	var destination: Array = row.get("destination", [])
	if destination.size() == 2:
		lines.append("Destination: %.0f, %.0f m" % [float(destination[0]), float(destination[1])])
	elif row.has("destination"):
		lines.append("No active travel route")
	else:
		lines.append("Destination detail unavailable from this peer")
	if row.has("upkeep_per_minute"):
		lines.append("Upkeep: $%.2f/min · %s" % [float(row.upkeep_per_minute), "Player order" if row.get("player_order", false) else "Standing/AI order"])
	else:
		lines.append("Upkeep/ownership detail unavailable from this peer")
	return "\n".join(lines)
