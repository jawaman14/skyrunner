class_name StrategicSave
extends RefCounted
## What a save keeps of the organisation beyond the player's wallet and hangar: the strategic state.
## A save is written parked at an airfield, so nothing is in flight - no trucks, boats or jobs - and a
## load starts the same way (docs/ROADMAP.md, "Saves"). Kept: the stash houses (heat, what the task
## force knows, burned), the product and cash sitting in them, the payroll (crew, candidates, jail,
## wages owed), the runner's case file (suspicion, the bust meter), the court case and its history, the
## organisation's squads (at their base, as they stood) and the session clock - so every timestamp in
## the above, a trial date or a hiring day, still means what it did.
##
## Lives under the save's "sim" key; a save without one (older, or a game with none of these systems)
## loads as before. JSON turns whole numbers into floats, so the ones the sim treats as counts are
## put back with int() on the way in.

const VERSION := 1


static func capture(s: Session) -> Dictionary:
	var d := {"v": VERSION, "time": s.time}
	if s.stash_net != null:
		var st := {}
		for x in s.stash_net.stashes:
			st[x.id] = {"heat": x.heat, "intel": x.intel, "burned": x.burned, "works": x.get("works", {}).duplicate()}
		d["stashes"] = st
	if s.logistics != null:
		var l: Logistics = s.logistics
		d["logistics"] = {"stock": l.stock.duplicate(true), "cash": l.cash.duplicate(true), "cash_since": l.cash_since.duplicate(true),
			"aboard": l.aboard, "lost": l.lost.duplicate(true), "lost_by": l.lost_by.duplicate(true)}
	if s.payroll != null:
		d["payroll"] = _payroll(s)
	if s.rackets != null:
		d["rackets"] = {"policy": s.rackets.policy.duplicate(), "held": s.rackets.held, "collected": s.rackets.collected}
	if s.renown != null:
		d["renown"] = {"score": s.renown.score, "recent": s.renown.recent.duplicate(true)}
	var c = s.police.case("runner")
	d["case"] = {"suspicion": c.suspicion, "bust_meter": c.bust_meter, "rival_meter": c.rival_meter}
	if s.court != null:
		d["court"] = {"case": s.court.case_, "history": s.court.history.duplicate(true), "mandatory": s.court.mandatory,
			"serial": s.court._serial}
	if s.ground != null:
		var squads := []
		for q: GroundWar.Squad in s.ground.of("org"):
			squads.append({"id": q.id, "kind": q.kind, "men": q.men, "men0": q.men0, "loadout": q.loadout.duplicate(), "ammo": q.ammo,
				"morale": q.morale, "tag": q.tag, "xp": q.xp})
		d["squads"] = {"list": squads, "serial": s.ground._serial}
	return d


## The workers who are on a job that ends with the save (a truck, a cash run, a squad that is not
## coming back) are free again; those on a post that outlasts it (a lookout at a stash, a dealer on
## a corner, a man in a squad that is) keep it.
static func _payroll(s: Session) -> Dictionary:
	var p: Payroll = s.payroll
	var keep := {}
	if s.ground != null:
		for q: GroundWar.Squad in s.ground.of("org"):
			keep[q.id] = true
	var workers := []
	for w in p.workers:
		var x: Dictionary = w.duplicate(true)
		var a := str(x.get("assigned", ""))
		if x.get("status", "") == "assigned" and not (a.begins_with("stash-") or a.begins_with("corner-") or keep.has(a)):
			x["status"] = "free"
			x["assigned"] = ""
		workers.append(x)
	var squads := {}
	for id in p.squads:
		if keep.has(id):
			squads[id] = p.squads[id].duplicate()
	return {"workers": workers, "candidates": p.candidates.duplicate(true), "jail": p.jail.duplicate(true), "ai": p.ai.duplicate(),
		"unpaid": p.unpaid.duplicate(), "paid_total": p.paid_total.duplicate(), "flips": p.flips.duplicate(), "lost": p.lost.duplicate(),
		"last": p.last.duplicate(), "squads": squads, "serial": p._serial}


static func restore(s: Session, d: Dictionary) -> void:
	if d.is_empty() or int(d.get("v", 0)) != VERSION:
		return
	s.time = float(d.get("time", 0.0))
	if s.stash_net != null and d.get("stashes") is Dictionary:
		for id in d.stashes:
			var st = s.stash_net.get_stash(str(id))
			if st != null:
				st.heat = float(d.stashes[id].get("heat", 0.0))
				st.intel = float(d.stashes[id].get("intel", 0.0))
				st.burned = bool(d.stashes[id].get("burned", false))
				var w: Dictionary = d.stashes[id].get("works", {})
				if not w.is_empty():
					st["works"] = {}
					for k in w:
						st.works[str(k)] = int(w[k])
	if s.logistics != null and d.get("logistics") is Dictionary:
		var l: Logistics = s.logistics
		var ld: Dictionary = d.logistics
		l.stock = ld.get("stock", {})
		l.cash = _ints(ld.get("cash", {}))
		l.cash_since = ld.get("cash_since", {})
		l.aboard = int(ld.get("aboard", 0))
		l.lost = {"product": float(ld.get("lost", {}).get("product", 0.0)), "cash": int(ld.get("lost", {}).get("cash", 0))}
		l.lost_by = _ints(ld.get("lost_by", l.lost_by))
	if s.payroll != null and d.get("payroll") is Dictionary:
		_restore_payroll(s.payroll, d.payroll)
	if s.rackets != null and d.get("rackets") is Dictionary:
		for m in d.rackets.get("policy", {}):
			s.rackets.set_policy(str(m), str(d.rackets.policy[m]))
		s.rackets.held = int(d.rackets.get("held", 0))
		s.rackets.collected = int(d.rackets.get("collected", 0))
	if s.renown != null and d.get("renown") is Dictionary:
		s.renown.score = float(d.renown.get("score", 0.0))
		s.renown.recent = d.renown.get("recent", [])
		s.renown.apply()
	if d.get("case") is Dictionary:
		var c = s.police.case("runner")
		c.suspicion = float(d.case.get("suspicion", 0.0))
		c.bust_meter = float(d.case.get("bust_meter", 0.0))
		c.rival_meter = float(d.case.get("rival_meter", 0.0))
	if s.court != null and d.get("court") is Dictionary:
		s.court.case_ = d.court.get("case")
		s.court.history = d.court.get("history", [])
		s.court.mandatory = bool(d.court.get("mandatory", false))
		s.court._serial = int(d.court.get("serial", 0))
	if s.ground != null and d.get("squads") is Dictionary:
		_restore_squads(s, d.squads)


static func _restore_payroll(p: Payroll, d: Dictionary) -> void:
	p.workers = []
	for w in d.get("workers", []):
		w["wage"] = int(w.get("wage", 0))
		p.workers.append(w)
	var cands: Dictionary = d.get("candidates", {})
	for o in ["org", "rival"]:
		p.candidates[o] = []
		for w in cands.get(o, []):
			w["wage"] = int(w.get("wage", 0))
			p.candidates[o].append(w)
	p.jail = d.get("jail", [])
	p.ai = d.get("ai", p.ai)
	p.unpaid = _ints(d.get("unpaid", p.unpaid))
	p.paid_total = _ints(d.get("paid_total", p.paid_total))
	p.flips = _ints(d.get("flips", p.flips))
	p.lost = _ints(d.get("lost", p.lost))
	p.last = d.get("last", p.last)
	p.squads = d.get("squads", {})
	p._serial = int(d.get("serial", p._serial))


## The organisation's squads back at their base, as they stood: no recruiting fee, no payroll
## enlistment (the men are already on it, in Payroll.squads) and no arsenal draw (what they carry
## was never put back). The opening deployment is for the other two sides only.
static func _restore_squads(s: Session, d: Dictionary) -> void:
	var g: GroundWar = s.ground
	g._started = true
	g._serial = int(d.get("serial", 0))
	for sd in d.get("list", []):
		var q := GroundWar.Squad.new()
		q.id = str(sd.id)
		q.faction = "org"
		q.kind = str(sd.kind)
		q.men = int(sd.men)
		q.men0 = int(sd.men0)
		q.loadout = _ints(sd.get("loadout", {}))
		q.ammo = int(sd.get("ammo", 0))
		q.morale = float(sd.get("morale", GroundWar.MORALE0.org))
		q.tag = str(sd.get("tag", ""))
		q.xp = float(sd.get("xp", 0.0))
		var base: Vector2 = g.hq("org")
		q.x = base.x
		q.y = base.y
		q.home = base
		q.state = "holding"
		g.squads.append(q)
	for k in 2:  # keep in step with GroundWar._deploy
		g.recruit("rival", "foot" if k == 0 else "car", null, false)
	for k in 3:
		g.recruit("police", "car", null, false)


static func _ints(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = int(d[k])
	return out
