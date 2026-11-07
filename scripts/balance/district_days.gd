class_name DistrictDays
extends RefCounted
## The "N days" balance sim (L-7; docs/EMPIRE_SIMULATION_SPEC.md section 5, the HQ nights' successor): the Living District run day
## by day for a few seeds, with the AI organisations running their businesses and the organisation's own chains funded the way a
## new owner would. It reports each day's close: every org's money, who owns what, what is owed and what the AI did, so the
## district's numbers (prices, rents, floors, reserves) can be judged over weeks rather than one close.
##
##   godot --headless --script res://scripts/balance/cli.gd -- days --n 14 --seeds 3
##
## The district on its own (the shoppers hour by hour, the books at each 06:00), as tests/test_acceptance.gd steps it: the rest of
## the island isn't flown, so a seed's run is fast and the same every time.

const START := 60000


static func run(seed_: int, days: int, war := true) -> Array:
	var o := {"seed": seed_, "map_seed": MapCity.SEED, "location": "HAR", "payroll": true, "features": Session.SANDBOX_FEATURES}
	if war:
		o.merge({"ground_war": true, "trade": true, "logistics": true})
	var s := Session.new(o)
	s.police.frozen = true
	s.update(1.0 / 30)
	s.money = START
	var b: Businesses = s.businesses
	if b == null:
		s.dispose()
		return []
	b.buy("biz-9")  # what a new owner does: the warehouse, its till funded, and the club's
	b.fund("biz-9", 4000)
	b.fund("biz-4", 2000)
	var out := []
	var moves_seen := 0
	for d in days:
		var end: float = Books.next_close(s.time)
		while s.time < end:
			var step := minf(600.0, end - s.time)
			s.time += step
			b.tick_full(step)
		b._on_books(null)
		var owned := {}
		for x in b.catalog:
			var who := str(b.owner[x.id])
			owned[who] = int(owned.get(who, 0)) + 1
		var owed := 0
		for id in b.arrears:
			owed += int(b.arrears[id])
		var moves: Array = b.ai.log.slice(moves_seen) if b.ai != null else []
		moves_seen = b.ai.log.size() if b.ai != null else 0
		var tills := 0.0
		for x in b.catalog:
			if str(b.owner[x.id]) == "org":
				tills += s.ledger.balance(Businesses.till(x.id))
		out.append({"seed": seed_, "day": d + 1, "org_safe": int(s.money), "org_tills": int(tills),
			"moretti": int(s.ledger.balance("moretti:safe")), "rival": int(b.safe_balance("rival")), "owned": owned, "owed": owed,
			"moves": moves.map(func(m): return "%s %s %s%s" % [m.org, m.layer, m.cmd, "" if m.ok else " (refused)"]),
			"conserved": absf(s.ledger.total()) < 0.01})
	s.dispose()
	World.use_map(0)
	return out


static func table(rows: Array) -> String:
	var lines := ["seed day   org safe  org tills  Morettis  Cuervos  owed  owned (org/moretti/rival/free)  AI moves"]
	for r in rows:
		var o: Dictionary = r.owned
		lines.append("%4d %3d %10d %10d %9d %8d %5d  %d/%d/%d/%d  %s" % [int(r.seed), int(r.day), int(r.org_safe), int(r.org_tills),
			int(r.moretti), int(r.rival), int(r.owed), int(o.get("org", 0)), int(o.get("moretti", 0)), int(o.get("rival", 0)),
			int(o.get("", 0)), "; ".join(r.moves.filter(func(m): return not str(m).contains("policy")))])
	return "\n".join(lines)
