extends RefCounted
static func describe(rows: Array) -> String:
	if rows.is_empty(): return "District detail unavailable from this peer."
	var lines := ["DISTRICTS · modeled street influence, not exact enemy deployment"]
	for row in rows:
		var share := float(row.get("share", -1.0))
		lines.append("\n%s · %s · %s" % [str(row.get("market", "")).to_upper(), "hold unestablished" if share < 0 else "%.0f%% hold" % (share * 100.0), row.get("trend", "direction unavailable")])
		lines.append("%d own people / %d squads · $%.2f/min upkeep · %s" % [int(row.get("own_people", 0)), int(row.get("own_squads", 0)), float(row.get("upkeep_per_minute", 0.0)), "%d observed enemy squads" % int(row.observed_enemies) if int(row.get("observed_enemies", 0)) > 0 else "no enemy squads currently reported"])
		if row.has("expected_collection"):
			lines.append("Policy: %s · expected $%d · last $%d · next round %.0f min" % [row.get("policy", "fair"), int(row.expected_collection), int(row.get("last_collection", 0)), ceil(float(row.get("next_collection", 0)) / 60.0)])
	lines.append("\nPresence builds influence and decays over time. Collection requires more than half the street; exactly half pays $0. Squeeze raises collections, reduces your hold and increases suspicion. These are current estimates, not guaranteed income.")
	return "\n".join(lines)
