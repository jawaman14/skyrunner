class_name Weekly
extends RefCounted
## The week's work: the game's repeatable goal (owner, 4 Nov 2026, D-93; docs/ROADMAP.md, "Repeatable goal").
##
## World of Warcraft kept players with a loop that always had a short payoff and a long one: a weekly raid reset and a visible
## tier. Here every island week (WEEK_S of game time) posts three goals drawn from what is open in this game, each a few hours
## of play at most and each measured off the event bus: loads delivered, hot loads, a bulk sale, a buyer's order filled, cash
## trucked home, a hidden strip found, a clean week, a district held. A goal met pays renown at once; all three pay a bonus and
## extend the run of clean weeks, which the phone's Week app shows beside the best run. The rank is the existing Renown tier,
## whose perks (better hires, better bulk prices) are the reward that lasts. No money is paid (D-65: nothing from nowhere).
##
## Targets grow with the renown tier, so the week stays a stretch as the organisation grows. Goals are drawn on their own stream
## (seed + 185) only when a week is posted; counting and the week's end draw nothing. Live once the employed opening is over
## (it has its own goals), never over an HQ season. Opt-in switch.

static var ENABLED := true

const WEEK_S := 5400.0  ## an island week: about one evening's play
const PICK := 3  ## goals a week
const POINTS := 10.0  ## renown for each goal met
const CLEAR_BONUS := 15.0  ## renown for all of them
const KEEP := 6  ## past weeks shown

var sess
var rng: PyRandom
var week := 0  ## the current week's number (0 = none posted yet)
var ends := -1.0  ## when it ends, in session time
var goals: Array = []  ## {kind, text, target, progress, done, at_end}
var run := 0  ## weeks cleared in a row
var best := 0
var history: Array = []  ## {week, met, of}, newest last
var _bad := 0  ## busts and stash raids this week (the clean-week goal)


func _init(sess_, rng_: PyRandom) -> void:
	sess = sess_
	rng = rng_
	if sess == null or sess.bus == null:
		return
	for kind in ["job_delivered", "bulk_sale", "order_filled", "cash_home", "strip_found", "busted", "stash_raided"]:
		sess.bus.subscribe(kind, _on_event)


func live() -> bool:
	return ENABLED and sess != null and sess.nights == null and not sess._first_missions() \
		and (sess.story != null or sess.renown != null)


func update(_dt: float) -> void:
	if not live():
		return
	if week == 0:
		_post_week()
	elif sess.time >= ends:
		_end_week()
		_post_week()


# ------------------------------------------------------------------ the goals
## What can be asked of this game right now: [kind, text, target, at_end]. Targets grow with the renown tier.
func _pool() -> Array:
	var t: int = sess.renown.tier() if sess.renown != null else 0
	var out := [
		["loads", "Deliver %d loads", 3 + t, false],
		["clean", "Keep it clean: no bust and no stash raided this week", 1, true],
	]
	if sess.trade != null:
		out.append(["hot", "Deliver %d hot loads", 2 + int(t / 2), false])
		# a bulk buyer has to be open for business this week (Trade.available), or the goal could not be met
		if Trade.BUYERS.keys().any(func(b): return sess.trade.available(b) == ""):
			out.append(["bulk", "Sell %d lb to the bulk buyers", 100 * (1 + t), false])
			if sess.trade.get("orders") != null and Orders.ENABLED:
				out.append(["order", "Fill a buyer's order in time", 1, false])
	if sess.logistics != null:
		out.append(["cash", "Truck $%s of street money home", 3000 * (1 + t), false])
	if sess.discovery != null and not sess.discovery.hidden.is_empty():
		out.append(["strip", "Find a hidden strip", 1, false])
	if sess.ground != null and Territories.ENABLED:
		out.append(["turf", "Hold a district (half its streets) when the week ends", 1, true])
	return out


func _post_week() -> void:
	week += 1
	ends = sess.time + WEEK_S
	_bad = 0
	var pool := _pool()
	goals = []
	while goals.size() < PICK and not pool.is_empty():
		var g: Array = pool.pop_at(rng.randint(0, pool.size() - 1))
		var target: int = int(g[2])
		var text: String = str(g[1]) % [Py.money(target) if str(g[0]) == "cash" else target] if str(g[1]).contains("%") else str(g[1])
		goals.append({"kind": str(g[0]), "text": text, "target": target, "progress": 0, "done": false, "at_end": bool(g[3])})
	sess.say("Week %d: %s." % [week, "; ".join(goals.map(func(x): return str(x.text)))])


func _on_event(ev) -> void:
	if not live() or week == 0:
		return
	var kind: String = ev.kind
	if kind in ["busted", "stash_raided"]:
		_bad += 1
		return
	for g in goals:
		if g.done:
			continue
		match str(g.kind):
			"loads":
				if kind == "job_delivered":
					_count(g, 1)
			"hot":
				if kind == "job_delivered" and bool(ev.data.get("hot", false)):
					_count(g, 1)
			"bulk":
				if kind == "bulk_sale" and str(ev.data.get("good", "")) != "guns":
					_count(g, int(round(float(ev.data.get("qty", 0.0)))))
			"order":
				if kind == "order_filled":
					_count(g, 1)
			"cash":
				if kind == "cash_home":
					_count(g, int(ev.data.get("amount", 0)))
			"strip":
				if kind == "strip_found":
					_count(g, 1)


func _count(g: Dictionary, n: int) -> void:
	g.progress = mini(int(g.target), int(g.progress) + n)
	if int(g.progress) >= int(g.target):
		_met(g)


func _met(g: Dictionary) -> void:
	g.done = true
	if sess.renown != null:
		sess.renown.add(POINTS, "the week's work: %s" % str(g.text).to_lower())
	sess.say("Week %d: done - %s." % [week, str(g.text)])
	if goals.all(func(x): return bool(x.done)):
		sess.say("The week's work is done: every goal met.")


## A district is held when our share of its streets is at least half (the ground war's own share rule).
func _holds_a_district() -> bool:
	if sess.ground == null:
		return false
	for key in sess.ground.territory_control:
		if GroundWar._control_share(sess.ground.territory_control[key], "org") >= 0.5:
			return true
	return false


func _end_week() -> void:
	for g in goals:
		if g.done or not g.at_end:
			continue
		if (str(g.kind) == "clean" and _bad == 0) or (str(g.kind) == "turf" and _holds_a_district()):
			g.progress = int(g.target)
			_met(g)
	var met := goals.filter(func(x): return bool(x.done)).size()
	var cleared := met == goals.size() and not goals.is_empty()
	if cleared:
		run += 1
		best = maxi(best, run)
		if sess.renown != null:
			sess.renown.add(CLEAR_BONUS, "a clean sweep of week %d" % week)
	else:
		run = 0
	history.append({"week": week, "met": met, "of": goals.size()})
	Py.keep_last(history, KEEP)
	sess.say("Week %d is over: %d of %d done%s." % [week, met, goals.size(), (", %d weeks running" % run) if run > 1 else ""])


# ------------------------------------------------------------------ the phone
## The Week app's lines: a "# heading" line for each part, then rows.
func lines() -> Array:
	if not live() or week == 0:
		return ["The week's work starts once you are your own boss."]
	var left := maxi(0, int(ceil((ends - float(sess.time)) / 60.0)))
	var out := ["# Week %d, %d min left" % [week, left]]
	for g in goals:
		var mark := "[x]" if g.done else "[ ]"
		var count := ""
		if not g.done and not g.at_end and int(g.target) > 1:
			count = "  (%s of %s)" % [Py.money(int(g.progress)) if g.kind == "cash" else str(g.progress), Py.money(int(g.target)) if g.kind == "cash" else str(g.target)]
		out.append("%s %s%s" % [mark, str(g.text), count])
	out.append("# Standing")
	if sess.renown != null:
		out.append("%s (renown %d)" % [sess.renown.title(), int(sess.renown.score)])
	out.append("Weeks cleared in a row: %d (best %d)" % [run, best])
	if not history.is_empty():
		out.append("# Past weeks")
		for i in range(history.size() - 1, -1, -1):
			var h: Dictionary = history[i]
			out.append("Week %d: %d of %d" % [int(h.week), int(h.met), int(h.of)])
	return out


# ------------------------------------------------------------------ saves
## For StrategicSave: everything, so restoring draws nothing.
func capture() -> Dictionary:
	return {"week": week, "ends": ends, "goals": goals.duplicate(true), "run": run, "best": best, "history": history.duplicate(true), "bad": _bad,
		"rng": rng.get_state()}  # so the next week's picks continue the sequence instead of repeating the first week's


func restore(d: Dictionary) -> void:
	week = int(d.get("week", 0))
	ends = float(d.get("ends", -1.0))
	goals = []
	for g in d.get("goals", []):
		if g is Dictionary:
			goals.append({"kind": str(g.get("kind", "")), "text": str(g.get("text", "")), "target": int(g.get("target", 1)),
				"progress": int(g.get("progress", 0)), "done": bool(g.get("done", false)), "at_end": bool(g.get("at_end", false))})
	run = int(d.get("run", 0))
	best = int(d.get("best", 0))
	history = []
	for h in d.get("history", []):
		if h is Dictionary:
			history.append({"week": int(h.get("week", 0)), "met": int(h.get("met", 0)), "of": int(h.get("of", 0))})
	_bad = int(d.get("bad", 0))
	if d.get("rng") is Array:
		rng.set_state(d.rng)
