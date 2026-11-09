class_name OrgAI
extends RefCounted
## Organisation AI v1 (L-3; docs/EMPIRE_SIMULATION_SPEC.md section 7): the Morettis (`moretti`, an economic org, D-84) and Los
## Cuervos (`rival`) running their businesses in the Living District on the player's rules. Two of the spec's three layers:
##
## - **Policy** (fixed rules, a personality's parameters): at each books close, before the day's trade, every business of theirs
##   whose till is under its floor (a few days' rent and bills, plus a restock for a shop) is topped up from the org's safe.
## - **Strategy** (daily, after the costs): a scored choice between a few moves: pay off a business's arrears, skim a till that
##   holds more than it needs, buy a free business of a kind it likes, or hold. A near-tie is broken on the org's own stream.
## - Execution is the businesses' own day (the chain and the costs) and, for Los Cuervos, the street war as before.
##
## Equal rules: every move is a `command_as` with the org's own actor (Actor.AI_ORGS), so it is checked, paid from the org's
## own safe and refused for the same reasons a player's would be; every refused or blocked move is logged with its reason. It
## sees what a boss in its seat would: its own tills and safe, the businesses' owners and prices.
##
## The Morettis' safe is a ledger account (`moretti:safe`) opened at START_SAFE. Los Cuervos' is their war chest, and they run
## only with the street war on. Streams: seed + 1201 + org index for strategy (rival 1202, moretti 1203), seed + 1301 for policy
## (reserved: v1's policy draws nothing). Saved with the businesses. Behind ENABLED (in the parity set).

static var ENABLED := true

const ORGS := ["rival", "moretti"]  ## in the spec's org index order after the player's (1, 2)
const START_SAFE := {"moretti": 25000.0}
const LOG_MAX := 40
const TIE := 0.05  ## moves this close to the best are a tie
## The personalities: the kinds of business each likes to buy, the cash it keeps back, and its tills' floor and skim, in days of costs.
const PERSONALITY := {
	"moretti": {"likes": ["front", "retail"], "reserve": 8000.0, "floor_days": 3.0, "skim_days": 10.0},
	"rival": {"likes": ["product", "cover", "front+product"], "reserve": 6000.0, "floor_days": 2.0, "skim_days": 6.0},
}

var biz  ## Businesses (untyped: no cycle at parse time)
var rng := {}  ## org -> PyRandom (strategy)
var policy_rng: PyRandom
var log: Array = []  ## {t, org, layer, cmd, args, ok, why}, the latest LOG_MAX
var last := {}  ## org -> the day's move


func _init(biz_, rngs: Dictionary, policy_rng_: PyRandom) -> void:
	biz = biz_
	rng = rngs
	policy_rng = policy_rng_
	for o in START_SAFE:
		biz.sess.ledger.track(o + ":safe", START_SAFE[o], START_SAFE[o], biz.sess.time)  # opened, not takings


## Whether an org's AI is running now (Los Cuervos need their war chest: the street war).
func runs_for(o: String) -> bool:
	if not o in ORGS:
		return false
	return o != "rival" or (biz.sess.ground != null and biz.sess.ground.commanders.has("rival"))


func _act(o: String, layer: String, cmd: String, args: Dictionary) -> bool:
	var r: Array = biz.sess.command_as(Actor.of(o, Roles.BOSS, o + ":boss"), cmd, args)
	log.append({"t": biz.sess.time, "org": o, "layer": layer, "cmd": cmd, "args": JSON.parse_string(JSON.stringify(args)), "ok": bool(r[0]),  # as a load reads it back
		"why": "" if r[0] else str(r[1])})
	while log.size() > LOG_MAX:
		log.pop_front()
	return bool(r[0])


## What a business needs in its till to get through the next few days, by the org's personality.
func floor_of(o: String, b: Dictionary) -> float:
	var f := float(PERSONALITY[o].floor_days) * float(int(b.rent) + int(b.utilities))
	if Businesses.is_retail(b):
		f += Businesses.SHELF_LB * Businesses.TRADE_OUTSIDE
	elif Businesses.is_warehouse(b):
		f += Businesses.WAREHOUSE_LB * Businesses.WHOLESALE
	return f


# ------------------------------------------------------------------ policy
func policy() -> void:
	for o in ORGS:
		if not runs_for(o):
			continue
		for b in biz.catalog:
			if str(biz.owner[b.id]) != o:
				continue
			var short := floor_of(o, b) + float(biz.arrears.get(b.id, 0)) - float(biz.balance(b.id))
			if short < 1.0:
				continue
			if biz.safe_balance(o) < 1.0:
				log.append({"t": biz.sess.time, "org": o, "layer": "policy", "cmd": "business_fund", "args": {"id": b.id},
					"ok": false, "why": "The safe is empty: %s can't be topped up." % b.name})
				continue
			_act(o, "policy", "business_fund", {"id": b.id, "amount": int(ceil(short))})
		if Laundering.ENABLED:
			for m in biz.wash.ai_moves(o):  # then the rackets' money goes through its fronts, within the night's allowance
				_act(o, "policy", "business_launder", m)


# ------------------------------------------------------------------ strategy
## The moves open to an org today, scored.
func moves(o: String) -> Array:
	var p: Dictionary = PERSONALITY[o]
	var safe: float = biz.safe_balance(o)
	var out := [{"cmd": "", "args": {}, "score": 0.2, "why": "hold"}]
	for b in biz.catalog:
		var id: String = b.id
		var owner := str(biz.owner[id])
		if owner == o:
			var owed := float(biz.arrears.get(id, 0))
			if owed >= 1.0:
				out.append({"cmd": "business_fund", "args": {"id": id, "amount": int(ceil(owed))}, "score": 2.0 + owed / 1000.0,
					"why": "pay off %s's arrears" % b.name})
			var spare := float(biz.balance(id)) - floor_of(o, b) - float(p.skim_days) * float(int(b.rent) + int(b.utilities))
			if spare >= 100.0:
				out.append({"cmd": "business_take", "args": {"id": id, "amount": int(spare)}, "score": 1.0 + spare / 5000.0,
					"why": "skim %s's till" % b.name})
		elif owner == "" and int(b.price) > 0 and str(b.chain) in p.likes and safe - float(b.price) >= float(p.reserve):
			out.append({"cmd": "business_buy", "args": {"id": id}, "score": 1.5, "why": "buy %s" % b.name})
	return out


func strategy() -> void:
	for o in ORGS:
		if not runs_for(o):
			continue
		var ms := moves(o)
		var best := 0.0
		for m in ms:
			best = maxf(best, float(m.score))
		var tied := ms.filter(func(m): return float(m.score) >= best - TIE)
		var pick: Dictionary = tied[0] if tied.size() == 1 else tied[(rng[o] as PyRandom).randint(0, tied.size() - 1)]
		last[o] = str(pick.why)
		if str(pick.cmd) != "":
			_act(o, "strategy", str(pick.cmd), pick.args)


## The refused and blocked moves, newest first, for the desk (L-4).
func refused() -> Array:
	var out := log.filter(func(r): return not r.ok)
	out.reverse()
	return out


func capture() -> Dictionary:
	var states := {}
	for o in rng:
		states[o] = (rng[o] as PyRandom).get_state()
	return {"log": log.duplicate(true), "last": last.duplicate(), "rng": states, "policy_rng": policy_rng.get_state()}


func restore(d: Dictionary) -> void:
	log = (d.get("log", []) as Array).duplicate(true)
	last = (d.get("last", {}) as Dictionary).duplicate()
	var states: Dictionary = d.get("rng", {})
	for o in states:
		if rng.has(o) and states[o] is Array:
			(rng[o] as PyRandom).set_state(states[o])
	if d.get("policy_rng") is Array:
		policy_rng.set_state(d.policy_rng)
