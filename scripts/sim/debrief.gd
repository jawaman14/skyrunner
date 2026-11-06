class_name Debrief
extends RefCounted
## The day's debrief (F-6b, docs/EMPIRE_SIMULATION_SPEC.md section 5): what replaces the HQ nights' report. Built by the books at
## each 06:00 close from the organisation's day in the ledger and a tally of the day's events, which the books keep as they happen
## (the event log is capped and not saved, so it can't be the source) and save with the day under way. Read-only: no draws, no money.

## The events counted, and how a debrief names them (one, many). Only the organisation's side of the island.
const TALLY := {
	"job_delivered": ["load delivered", "loads delivered"],
	"bales_delivered": ["bale drop", "bale drops"],
	"bulk_sale": ["bulk sale", "bulk sales"],
	"cash_home": ["cash run home", "cash runs home"],
	"order_filled": ["order filled", "orders filled"],
	"order_missed": ["order missed", "orders missed"],
	"raid_foiled": ["raid foiled", "raids foiled"],
	"busted": ["bust", "busts"],
	"truck_seized": ["truck seized", "trucks seized"],
	"truck_hijacked": ["truck hijacked", "trucks hijacked"],
	"stash_raided": ["stash raided", "stashes raided"],
	"boat_seized": ["boat seized", "boats seized"],
	"weapons_seized": ["weapons seizure", "weapons seizures"],
	"worker_arrested": ["worker arrested", "workers arrested"],
	"worker_flipped": ["worker flipped", "workers flipped"],
	"crashed": ["crash", "crashes"],
}
## The order they are read out in: what went right, then what went wrong.
const ORDER := ["job_delivered", "bales_delivered", "bulk_sale", "cash_home", "order_filled", "raid_foiled", "order_missed",
	"busted", "truck_seized", "truck_hijacked", "stash_raided", "boat_seized", "weapons_seized", "worker_arrested",
	"worker_flipped", "crashed"]


## The heat on the organisation now: the runner's case suspicion (0 to 100), or -1 with no police.
static func heat_of(sess) -> float:
	if sess.police == null:
		return -1.0
	return float(sess.police.case("runner").suspicion)


## Cash sitting in the stashes, not yet home in the safe (the street's money; 0 without the logistics layer).
static func street_cash_of(sess) -> float:
	var sum := 0.0
	if sess.logistics != null:
		for id in sess.logistics.cash:
			sum += float(sess.logistics.cash[id])
	return sum


## One debrief: the organisation's money row (or none), the day's counts, the heat and how it moved since the last close.
static func build(day: int, t: float, row: Dictionary, counts: Dictionary, heat: float, heat_before: float, street: float) -> Dictionary:
	return {"day": day, "t": t, "in": float(_sum(row.get("in", {}))), "out": float(_sum(row.get("out", {}))),
		"net": float(row.get("net", 0.0)), "ends": float(row.get("ends", 0.0)), "counts": counts.duplicate(),
		"heat": heat, "heat_change": (heat - heat_before) if heat >= 0.0 and heat_before >= 0.0 else 0.0, "street_cash": street}


## The debrief read out in one line, for the message log and the radio.
static func line(d: Dictionary) -> String:
	var parts := ["Day %d's books: $%s in, $%s out (%s$%s)" % [int(d.day), Py.money(int(d["in"])), Py.money(int(d.out)),
		"+" if float(d.net) >= 0.0 else "-", Py.money(int(absf(float(d.net))))]]
	var said := []
	for k in ORDER:
		var n := int(d.counts.get(k, 0))
		if n > 0:
			said.append("%d %s" % [n, TALLY[k][0] if n == 1 else TALLY[k][1]])
	if not said.is_empty():
		parts.append(", ".join(said))
	if float(d.street_cash) >= 1.0:
		parts.append("$%s still in the stashes" % Py.money(int(d.street_cash)))
	if float(d.heat) >= 0.0:
		var ch := roundi(float(d.heat_change))
		parts.append("heat %d%s" % [roundi(float(d.heat)), "" if ch == 0 else " (%s%d)" % ["+" if ch > 0 else "", ch]])
	return ". ".join(parts) + "."


static func _sum(d: Dictionary) -> float:
	var s := 0.0
	for k in d:
		s += float(d[k])
	return s
