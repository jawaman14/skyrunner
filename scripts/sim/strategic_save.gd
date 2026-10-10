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
## Beyond that, the rest of the world is kept by name through SaveVars: the Family, the product trade, the
## economy and its market, the island, the Company, the chronicle, the three arsenals, the ground war's
## books and commanders, the rackets' counters, and the rival and task-force squads (where they stood, at
## rest). The lists of property names below are the whole contract: a new field a system wants kept goes
## in its list, and tests/test_strategic_save.gd round-trips every list through JSON.
##
## Lives under the save's "sim" key; a save without one (older, or a game with none of these systems)
## loads as before. JSON turns whole numbers into floats, so the ones the sim treats as counts are
## put back with int() on the way in.

const VERSION := 1

const FAMILY := ["respect", "greed", "rico", "rat", "gone", "offers", "loan", "docks_until", "docks_honest", "muscle", "lawyer",
	"tribute_due", "tribute_by", "taxed", "tribute_total", "_tax_next", "_stalled", "payroll_until", "knows", "loans_taken",
	"accepted", "cons", "last", "_serial", "_t", "_offer_t", "_side_t", "_rat_t"]
const FAMILY_INTS := ["cost", "amount", "owed"]
const TRADE := ["stock", "connected", "appetite", "sold", "landed", "earned", "street_sales", "last", "bulk_log", "_t", "_war_t",
	"_sales_acc"]
const ECON := ["walk", "fuel_walk", "scarcity", "glut", "busts", "events", "news", "storm", "law_kit", "_t", "_now"]
const MARKET := ["supply", "demand", "disruption", "source", "news", "why", "_last_news", "_demand_events", "_t", "_now"]
const ISLAND := ["relations", "passage_until", "status", "status_until", "price_mult", "airport_heat", "port_heat", "crackdown_until",
	"inspections_until", "shipments", "delivered", "caught", "intercepts", "next_mules", "next_ship", "rival_shipped", "rival_caught",
	"_rival_t", "last", "_serial", "_t", "_event_t", "_mig_t"]
const ISLAND_INTS := ["n", "cost", "value", "mules"]
const CASINO := ["status", "stake", "owed", "heat", "case_", "unrest", "rival", "bought_out_until", "closed_until", "audit_until", "uprising_until", "act",
	"act_until", "cage_log", "laundered", "fees", "collected", "last", "force_uprising_at", "_t", "_evt_t", "_law_t"]
const DEALER := ["owned", "active", "spent", "auto", "rev", "_serial", "_insured", "_auto_t"]
const PSYCH := ["walk", "scarcity", "_walk_t", "stock", "held", "trust", "status", "hide_until", "weed_left", "circuit_left", "scene", "scene_name", "scene_until", "bartered", "sold", "earned", "raids", "auto", "last", "_t", "_evt_t", "_raid_t", "_auto_t"]
const AGENCY := ["trust", "exposure", "protected_until", "quashed", "flights", "burned", "pay_mult", "offer_chance", "_gift_t", "_t",
	"stings", "hung_out", "withheld", "last_read", "_game_t", "war_chest", "coke_lots", "gun_lots", "pipe_last", "_pipe_t", "_pipe_pause",
	"next_market"]
const CHRONICLE := ["history_i", "_hist_t", "fired", "entries", "counts", "_next", "_t"]
const ARSENAL := ["stock", "ammo", "cache", "seized_total"]
const RACKETS := ["rounds", "taken", "escaped", "ransomed", "ransom_cash", "turned", "released", "last_round", "_tt", "_te"]
const WAR := ["spent", "fights_total", "lost_men", "arrests_total", "officers_down", "_round_t", "_informant_t", "_org_recruit_t",
	"_upkeep_acc"]
const WAR_INTS := ["recruit", "upkeep", "arms", "org", "rival", "police"]
const WAR_PLAIN := ["control", "hot_spots", "battle_reports"]
const SEASON := ["night", "phase", "winner", "reason", "history", "runner_log", "law_log", "cartel_bonus", "plan_hist", "disabled",
	"forecast", "weather", "moon0", "sightings"]
const SEASON_INTS := ["wind_kt"]
const ORG := ["dirty", "clean", "heat", "loyalty", "fronts", "bribes", "lawyer", "tier", "exposure", "gear", "opsec", "crews", "decoys",
	"route", "lie_low", "counterintel", "laundered_tonight", "actions", "ready"]
const RIVAL := ["name", "strength", "cash", "turf", "truce_nights", "grudge", "busts", "temper", "wronged", "wronged_night", "kept",
	"betrayals", "revealed", "betrayed", "zone", "runs", "tipped", "hit"]
const TASK_FORCE := ["bank_k", "support", "evidence", "informants", "encryption", "fed_arrived", "budget_k", "funded", "aerostat", "patrol",
	"wiretap", "audit", "ia_sweep", "press", "gang_unit", "canary", "canary_zone", "actions", "ready"]
const DIRECTOR := ["_ai_mem", "_paid_before", "ended_at"]


static func capture(s: Session) -> Dictionary:
	var d := {"v": VERSION, "time": s.time, "fuel_spent": s.fuel_spent.duplicate()}
	d["phone_calls"] = s.phone_calls.capture()
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
		d["people"] = s.payroll.people.capture()
	if s.airframe != null:
		d["airframe"] = {"cond": s.airframe.cond.duplicate(true), "failures": s.airframe.failures, "spent": s.airframe.spent}
	if s.races != null:
		d["races"] = {"paid_at": s.races.paid_at.duplicate(), "won": s.races.won, "betting": s.races.betting,
			"results": s.races.results.duplicate(true)}
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
		for q: GroundWar.Squad in s.ground.squads:
			squads.append({"id": q.id, "faction": q.faction, "kind": q.kind, "men": q.men, "men0": q.men0, "loadout": q.loadout.duplicate(),
				"ammo": q.ammo, "morale": q.morale, "tag": q.tag, "xp": q.xp, "x": q.x, "y": q.y, "hx": q.home.x, "hy": q.home.y})
		d["squads"] = {"list": squads, "serial": s.ground._serial, "full": true}
		d["war"] = _capture_war(s.ground)
	_capture_world(s, d)
	if s.nights != null:
		d["nights"] = _capture_nights(s.nights)
	return d


static func _capture_world(s: Session, d: Dictionary) -> void:
	if s.family != null:
		d["family"] = SaveVars.capture(s.family, FAMILY)
	if s.trade != null:
		d["trade"] = SaveVars.capture(s.trade, TRADE)
	if s.econ != null:
		d["econ"] = SaveVars.capture(s.econ, ECON)
		if s.econ.market != null:
			d["market"] = SaveVars.capture(s.econ.market, MARKET)
	if s.island != null:
		d["island"] = SaveVars.capture(s.island, ISLAND)
	if s.casino != null:
		d["casino"] = SaveVars.capture(s.casino, CASINO)
	if s.dealer != null:
		d["dealer"] = SaveVars.capture(s.dealer, DEALER)
	if s.psych != null:
		d["psych"] = SaveVars.capture(s.psych, PSYCH)
	if s.agency != null:
		d["agency"] = SaveVars.capture(s.agency, AGENCY)
	if s.chronicle != null:
		d["chronicle"] = SaveVars.capture(s.chronicle, CHRONICLE)
	var ars := {}
	for side in s.arsenals:
		if s.arsenals[side] != null:
			ars[side] = SaveVars.capture(s.arsenals[side], ARSENAL)
	if not ars.is_empty():
		d["arsenals"] = ars
	if s.rackets != null:
		d["rackets"].merge(SaveVars.capture(s.rackets, RACKETS), true)


## The Organisation layer's nightly planning game. A save is parked, so a night that was mid-operation
## comes back at its planning phase (the plan is rebuilt when the pilot next takes off) and the bots
## plan it afresh; the two random streams carry on from where they were.
static func _capture_nights(n: NightDirector) -> Dictionary:
	var ss: HQ.Season = n.season
	var out := {"season": SaveVars.capture(ss, SEASON), "org": SaveVars.capture(ss.org, ORG), "law": SaveVars.capture(ss.law, TASK_FORCE),
		"director": SaveVars.capture(n, DIRECTOR), "phase": n.phase,
		"rng": {"season": ss.rng.get_state(), "bots": n._bot_rng.get_state()}}
	if ss.rival != null:
		out["rival"] = SaveVars.capture(ss.rival, RIVAL)
	if ss.rrng != null:
		out["rng"]["rival"] = ss.rrng.get_state()
	if ss.xrng != null:
		out["rng"]["extra"] = ss.xrng.get_state()
	var reports := []
	for r: HQ.NightReport in ss.reports:
		reports.append({"night": r.night, "lines": r.lines.duplicate(), "runner_lines": r.runner_lines.duplicate(), "law_lines": r.law_lines.duplicate()})
	out["reports"] = reports
	return out


static func _capture_war(g: GroundWar) -> Dictionary:
	var out := SaveVars.capture(g, WAR + WAR_PLAIN)
	var cmd := {}
	for f in g.commanders:
		var c: GroundWar.Commander = g.commanders[f]
		cmd[f] = {"cash": c.cash, "think_t": c.think_t, "log": c.log.duplicate(true)}
	out["commanders"] = cmd
	return out


## The workers who are on a job that ends with the save (a truck, a cash run, a squad that is not
## coming back) are free again; those on a post that outlasts it (a lookout at a stash, a dealer on
## a corner, a man in a squad that is) keep it.
static func _payroll(s: Session) -> Dictionary:
	var p: Payroll = s.payroll
	var keep := {}
	if s.ground != null:
		for q: GroundWar.Squad in s.ground.squads:
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
	s.phone_calls.restore(d.get("phone_calls", {}) if d.get("phone_calls") is Dictionary else {})
	s.phone_calls.tick(s.time)
	if d.get("fuel_spent") is Dictionary:
		s.fuel_spent = {"org": float(d.fuel_spent.get("org", 0.0)), "rival": float(d.fuel_spent.get("rival", 0.0))}
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
		l.ensure_acid()  # (an older save has no shelf for it)
		l.cash = _ints(ld.get("cash", {}))
		l.cash_since = ld.get("cash_since", {})
		l.aboard = int(ld.get("aboard", 0))
		l.lost = {"product": float(ld.get("lost", {}).get("product", 0.0)), "cash": int(ld.get("lost", {}).get("cash", 0))}
		l.lost_by = _ints(ld.get("lost_by", l.lost_by))
	if s.payroll != null and d.get("payroll") is Dictionary:
		_restore_payroll(s.payroll, d.payroll)
	if s.airframe != null and d.get("airframe") is Dictionary:
		var ad: Dictionary = d.airframe
		for k in ad.get("cond", {}):
			s.airframe.cond[str(k)] = {"engine": float(ad.cond[k].get("engine", 100.0)), "airframe": float(ad.cond[k].get("airframe", 100.0))}
		s.airframe.failures = int(ad.get("failures", 0))
		s.airframe.spent = int(ad.get("spent", 0))
	if s.races != null and d.get("races") is Dictionary:
		s.races.paid_at = d.races.get("paid_at", {})
		s.races.won = int(d.races.get("won", 0))
		s.races.betting = int(d.races.get("betting", 0))
		s.races.results = d.races.get("results", [])
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
	if s.ground != null and d.get("war") is Dictionary:
		_restore_war(s.ground, d.war)
	_restore_world(s, d)
	if s.payroll != null and d.get("people") is Dictionary:
		s.payroll.people.restore(d.people)
	if s.nights != null and d.get("nights") is Dictionary:
		_restore_nights(s.nights, d.nights)


static func _restore_nights(n: NightDirector, d: Dictionary) -> void:
	var ss: HQ.Season = n.season
	if d.get("season") is Dictionary:
		SaveVars.restore(ss, d.season, SEASON, SEASON_INTS)
	if d.get("org") is Dictionary:
		SaveVars.restore(ss.org, d.org, ORG)
	if d.get("law") is Dictionary:
		SaveVars.restore(ss.law, d.law, TASK_FORCE)
	if ss.rival != null and d.get("rival") is Dictionary:
		SaveVars.restore(ss.rival, d.rival, RIVAL)
	if d.get("director") is Dictionary:
		SaveVars.restore(n, d.director, DIRECTOR)
	var rng: Dictionary = d.get("rng", {})
	if rng.get("season") is Array:
		ss.rng.set_state(rng.season)
	if rng.get("bots") is Array:
		n._bot_rng.set_state(rng.bots)
	if ss.rrng != null and rng.get("rival") is Array:
		ss.rrng.set_state(rng.rival)
	if ss.xrng != null and rng.get("extra") is Array:
		ss.xrng.set_state(rng.extra)
	ss.reports = []
	for r in d.get("reports", []):
		var nr := HQ.NightReport.new(int(r.night), [])
		nr.lines = r.get("lines", [])
		nr.runner_lines = r.get("runner_lines", [])
		nr.law_lines = r.get("law_lines", [])
		ss.reports.append(nr)
	# parked: a night that was mid-operation starts again from planning
	if ss.phase == "operation":
		ss.phase = "planning"
	n.phase = "planning"
	n.main = null
	n.crews = []
	n.ended_at = null
	n._ai_planned = false
	n._show_forecast()  # the world's weather is tonight's forecast again


static func _restore_world(s: Session, d: Dictionary) -> void:
	if s.family != null and d.get("family") is Dictionary:
		SaveVars.restore(s.family, d.family, FAMILY, FAMILY_INTS)
	if s.trade != null and d.get("trade") is Dictionary:
		SaveVars.restore(s.trade, d.trade, TRADE)
	if s.econ != null and d.get("econ") is Dictionary:
		SaveVars.restore(s.econ, d.econ, ECON)
		if s.econ.market != null and d.get("market") is Dictionary:
			SaveVars.restore(s.econ.market, d.market, MARKET)
	if s.island != null and d.get("island") is Dictionary:
		SaveVars.restore(s.island, d.island, ISLAND, ISLAND_INTS)
	if d.get("psych") is Dictionary:
		s.enable_system("psychedelics")
		if s.logistics != null:
			s.logistics.ensure_acid()
		if s.psych != null:
			SaveVars.restore(s.psych, d.psych, PSYCH)
	if d.get("dealer") is Dictionary:
		s.enable_system("dealership")
		if s.dealer != null:
			SaveVars.restore(s.dealer, d.dealer, DEALER)
			s.dealer.apply()
	if s.casino != null and d.get("casino") is Dictionary:
		SaveVars.restore(s.casino, d.casino, CASINO)
	if s.agency != null and d.get("agency") is Dictionary:
		SaveVars.restore(s.agency, d.agency, AGENCY)
	if s.chronicle != null and d.get("chronicle") is Dictionary:
		SaveVars.restore(s.chronicle, d.chronicle, CHRONICLE)
	if d.get("arsenals") is Dictionary:
		for side in d.arsenals:
			var a = s.arsenals.get(side)
			if a != null:
				SaveVars.restore(a, d.arsenals[side], ARSENAL, Arsenal.ORDER)
				a.stock = _ints(a.stock)
	if s.rackets != null and d.get("rackets") is Dictionary:
		SaveVars.restore(s.rackets, d.rackets, RACKETS)


static func _restore_war(g: GroundWar, d: Dictionary) -> void:
	SaveVars.restore(g, d, WAR, WAR_INTS)
	SaveVars.restore(g, d, WAR_PLAIN)
	var cmd: Dictionary = d.get("commanders", {})
	for f in cmd:
		if g.commanders.has(f):
			var c: GroundWar.Commander = g.commanders[f]
			c.cash = float(cmd[f].get("cash", c.cash))
			c.think_t = float(cmd[f].get("think_t", 0.0))
			c.log = cmd[f].get("log", [])


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
	var full: bool = bool(d.get("full", false))
	for sd in d.get("list", []):
		var f := str(sd.get("faction", "org"))
		var q := GroundWar.Squad.new()
		q.id = str(sd.id)
		q.faction = f
		q.kind = str(sd.kind)
		q.men = int(sd.men)
		q.men0 = int(sd.men0)
		q.loadout = _ints(sd.get("loadout", {}))
		q.ammo = int(sd.get("ammo", 0))
		q.morale = float(sd.get("morale", GroundWar.MORALE0.org))
		q.tag = str(sd.get("tag", ""))
		q.xp = float(sd.get("xp", 0.0))
		if f == "org" or not full:
			var base: Vector2 = g.hq("org")
			q.x = base.x
			q.y = base.y
			q.home = base
		else:  # the other sides stand where they were
			q.x = float(sd.get("x", 0.0))
			q.y = float(sd.get("y", 0.0))
			q.home = Vector2(float(sd.get("hx", q.x)), float(sd.get("hy", q.y)))
		q.state = "holding"
		g.squads.append(q)
	if full:
		return
	for k in 2:  # an older save: keep in step with GroundWar._deploy
		g.recruit("rival", "foot" if k == 0 else "car", null, false)
	for k in 3:
		g.recruit("police", "car", null, false)


static func _ints(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = int(d[k])
	return out
