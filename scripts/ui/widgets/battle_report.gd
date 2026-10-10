extends RefCounted

static func describe(rows: Array) -> String:
	var lines: Array[String] = ["RECENT OWN-UNIT BATTLE REPORTS"]
	if rows.is_empty():
		lines.append("No completed accounts available. Older peers may not support reports.")
	for row in rows:
		lines.append("%s | %s | at %.0f min\n%s; %s\nPeople %d to %d; recorded combat losses %d\nAmmo %d to %d; morale %.0f%%" % [row.get("unit", "Unknown unit"), row.get("place", "Unknown place"), float(row.get("time", 0)) / 60.0, row.get("outcome", "Unknown result"), row.get("state", "unknown"), row.get("starting_people", 0), row.get("remaining_people", 0), row.get("losses", 0), row.get("starting_ammo", 0), row.get("remaining_ammo", 0), float(row.get("morale", 0)) * 100.0])
	lines.append("Own-unit accounting only. Combat losses may include wounded; strength changes can also include custody. Enemy losses and causes are not inferred.")
	return "\n\n".join(lines)
