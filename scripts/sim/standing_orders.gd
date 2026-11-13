class_name StandingOrders
extends RefCounted
## Standing orders (DESIGN 95; ROADMAP "After that: the four product steps", step 2: "conditional orders (stock thresholds) first";
## D-01's automation). The boss leaves instructions and the crew carry them out; the AI never invents one:
##
##   keep: keep at least `below` lb of `good` at `stash`; when it falls under, a van brings it up to `fill_to` from `from` (or, with
##         no `from`, from the stash with the most to spare that can lose it and still keep its own orders)
##   cash: when `stash` holds more than `over` dollars, a van takes it home to the club
##   route: a task sequence (DESIGN 96): a list of steps done in order, each one a van run {from, to, good, lb} (good "cash" for
##         money, lb 0 for all of it; `to` may be a buyer's meet) or a wait {wait_min}; the next step starts when the last van has
##         arrived (or been lost); `repeat` starts it over at the end, otherwise the order is done and goes
##   watch: a lookout follows the heat (DESIGN 97): he moves to the hottest house nobody is watching once it runs WATCH_MARGIN
##         hotter than his own; the order goes with him (fired, lost)
##
## Checked every minute; one truck per order on the road at a time; at most MAX orders. Every move goes through Logistics.send, the
## same as the boss's own vans: the same drivers, fuel, risk, room at the other end (DESIGN 87) and refusals. No random draws.
## Saved with the logistics. Behind ENABLED (opt-in: with no orders given, nothing happens).

static var ENABLED := true

const MAX := 6
const KINDS := ["keep", "cash", "route", "watch"]
const STEPS_MAX := 6
const WAIT_MAX_MIN := 240.0
const WATCH_MARGIN := 10.0  ## heat (a delivery adds StashNet.HEAT_DELIVERY): enough not to hop between two warm houses
const CHECK_S := 60.0

var lg  ## Logistics
var orders: Array = []  ## {id, kind, stash, good, below, fill_to, from, over}
var _serial := 0
var _t := 0.0
var last := ""  ## what the last order did, for the phone


func _init(lg_) -> void:
	lg = lg_


## Give a standing order. "" or why not.
func add(d: Dictionary) -> String:
	if not ENABLED:
		return "Nobody takes standing orders here."
	if orders.size() >= MAX:
		return "Six standing orders already: cancel one first."
	var kind := str(d.get("kind", ""))
	var stash := str(d.get("stash", ""))
	if not kind in KINDS:
		return "Keep a stash stocked, bring its cash home, or run a route."
	if kind == "route":
		return _add_route(d)
	if kind == "watch":
		return _add_watch(str(d.get("lookout", "")))
	var st = lg.sess.stash_net.get_stash(stash) if lg.sess.stash_net != null else null
	if st == null or st.burned:
		return "No such stash house."
	var o := {"kind": kind, "stash": stash}
	if kind == "keep":
		var good := str(d.get("good", ""))
		if not good in lg.goods():
			return "Keep what?"
		var below := float(d.get("below", 0.0))
		var fill_to := float(d.get("fill_to", 0.0))
		if not is_finite(below) or not is_finite(fill_to) or below <= 0.0 or fill_to <= below:
			return "Say how low it may fall and what to fill it to (more than that)."
		var from := str(d.get("from", ""))
		if from != "" and (lg.sess.stash_net.get_stash(from) == null or from == stash):
			return "From which stash?"
		o.merge({"good": good, "below": below, "fill_to": fill_to, "from": from})
	else:
		var over := float(d.get("over", 0.0))
		if not is_finite(over) or over < 100.0:
			return "Bring it home over how much ($100 or more)?"
		o["over"] = over
	return _give(o)


func _give(o: Dictionary) -> String:
	_serial += 1
	o["id"] = _serial
	orders.append(o)
	lg.sess.say("Standing order %d: %s" % [_serial, describe(o)])
	return ""


## A lookout follows the heat: one order a lookout.
func _add_watch(id: String) -> String:
	var pr = lg.sess.payroll
	var w = pr.get_worker(id) if pr != null else null
	if w == null or w.outfit != "org" or w.role != "lookout" or not str(w.status) in ["free", "assigned"]:
		return "Which of our lookouts?"
	for x in orders:
		if str(x.kind) == "watch" and str(x.lookout) == id:
			return "%s already follows the heat." % w.name
	return _give({"kind": "watch", "stash": "", "lookout": id})


## A task sequence: up to STEPS_MAX steps, each a van run or a wait, done in order.
func _add_route(d: Dictionary) -> String:
	var raw = d.get("steps", [])
	if not raw is Array or (raw as Array).is_empty():
		return "A route needs its steps: where each van goes, or how long to wait."
	if (raw as Array).size() > STEPS_MAX:
		return "Six steps at most."
	var steps: Array = []
	for x in raw:
		if not x is Dictionary:
			return "Each step is a run or a wait."
		var step: Dictionary = x
		if step.has("wait_min"):
			var m := float(step.wait_min)
			if not is_finite(m) or m < 1.0 or m > WAIT_MAX_MIN:
				return "Wait from a minute to four hours."
			steps.append({"wait_min": m})
			continue
		var from := str(step.get("from", ""))
		var to := str(step.get("to", ""))
		var good := str(step.get("good", ""))
		var lb := float(step.get("lb", 0.0))
		if not is_finite(lb) or lb < 0.0:
			return "Carry how much (0 for all of it)?"
		if good != "cash" and not good in lg.goods():
			return "Carry what? (a good, or cash)"
		if not (lg.stock.has(from) or (from == Logistics.HQ and good == "cash")):
			return "From which stash?"
		if not (lg.stock.has(to) or to == Logistics.HQ or Logistics.MEETS.has(to)) or to == from:
			return "To where?"
		steps.append({"from": from, "to": to, "good": good, "lb": lb})
	return _give({"kind": "route", "stash": "", "steps": steps, "repeat": bool(d.get("repeat", false)), "at": 0, "sent": false, "until": -1.0})


func cancel(id: int) -> String:
	for o in orders:
		if int(o.id) == id:
			orders.erase(o)
			lg.sess.say("Standing order %d cancelled." % id)
			return ""
	return "No standing order %d." % id


## In words, for the phone: "keep 200 lb of marijuana at the Mangrove shack, filled to 400 from Warehouse 7".
func describe(o: Dictionary) -> String:
	if str(o.kind) == "watch":
		var w = lg.sess.payroll.get_worker(str(o.lookout)) if lg.sess.payroll != null else null
		return "%s watches whichever house is hottest" % (str(w.name) if w != null else "the lookout")
	if str(o.kind) == "route":
		var parts: Array = []
		for i in o.steps.size():
			var st: Dictionary = o.steps[i]
			var mark := "> " if i == int(o.get("at", 0)) else ""
			if st.has("wait_min"):
				parts.append("%swait %d min" % [mark, int(st.wait_min)])
			else:
				var what: String = ("cash" if int(st.lb) <= 0 else "$%s" % Py.money(int(st.lb))) if str(st.good) == "cash" \
					else ("all the %s" % st.good if int(st.lb) <= 0 else "%d lb of %s" % [int(st.lb), st.good])
				parts.append("%s%s from %s to %s" % [mark, what, lg.name_of(str(st.from)), lg.name_of(str(st.to))])
		return "route: %s%s" % [", then ".join(parts), " (again and again)" if bool(o.get("repeat", false)) else ""]
	if str(o.kind) == "cash":
		return "bring %s's cash home when it passes $%s" % [lg.name_of(str(o.stash)), Py.money(int(o.over))]
	var src: String = (" from " + lg.name_of(str(o.from))) if str(o.get("from", "")) != "" else " from wherever has most"
	return "keep %d lb of %s at %s, filled to %d%s" % [int(o.below), o.good, lg.name_of(str(o.stash)), int(o.fill_to), src]


func update(dt: float) -> void:
	if not ENABLED or orders.is_empty():
		return
	_t += dt
	if _t < CHECK_S:
		return
	_t = 0.0
	for o in orders.duplicate():
		if str(o.kind) == "route":
			_route(o)
			continue
		if str(o.kind) == "watch":
			_watch(o)
			continue
		var st = lg.sess.stash_net.get_stash(str(o.stash))
		if st == null or st.burned:
			continue  # a burned house: the order waits (the boss can cancel it)
		if _on_the_road(o):
			continue
		if str(o.kind) == "cash":
			if float(lg.cash.get(str(o.stash), 0.0)) > float(o.over):
				_did(o, lg.send(str(o.stash), Logistics.HQ, "cash", float(lg.cash[str(o.stash)]), true))
		else:
			var have := float(lg.stock[str(o.stash)].get(str(o.good), 0.0))
			if have < float(o.below):
				var need := float(o.fill_to) - have
				var from := str(o.get("from", ""))
				if from == "":
					from = _richest(o, need)
				if from != "":
					_did(o, lg.send(from, str(o.stash), str(o.good), minf(need, float(lg.stock[from].get(str(o.good), 0.0))), true))


## The lookout moves to the hottest unwatched house once it runs WATCH_MARGIN hotter than his (heat only: what the street
## sees, not what the task force knows).
func _watch(o: Dictionary) -> void:
	var pr = lg.sess.payroll
	var w = pr.get_worker(str(o.lookout)) if pr != null else null
	if w == null or w.outfit != "org" or w.role != "lookout":
		orders.erase(o)
		last = "%d: the lookout is gone" % int(o.id)
		return
	if not str(w.status) in ["free", "assigned"]:
		return
	var here := str(w.assigned).trim_prefix("stash-") if str(w.status) == "assigned" else ""
	var st_here = lg.sess.stash_net.get_stash(here) if here != "" else null
	var heat_here: float = float(st_here.heat) if st_here != null and not st_here.burned else -1e9
	var watched := {}
	for x in pr.of("org", "lookout", "assigned"):
		watched[str(x.assigned)] = true
	var best = null
	for st in lg.sess.stash_net.live():
		if watched.has("stash-" + str(st.id)):
			continue
		if best == null or float(st.heat) > float(best.heat):
			best = st
	if best == null or float(best.heat) <= heat_here + WATCH_MARGIN and st_here != null and not st_here.burned:
		return
	var old_status := str(w.status)
	var old_at := str(w.assigned)
	w.status = "free"
	w.assigned = ""
	var err: String = pr.post_lookout(str(w.id), str(best.id))
	if err != "":
		w.status = old_status
		w.assigned = old_at
	_did(o, err if err != "" else "moved to %s" % best.name)


## One step of a task sequence: start it, or see whether it has finished and move on.
func _route(o: Dictionary) -> void:
	var at := int(o.get("at", 0))
	var step: Dictionary = o.steps[at]
	if step.has("wait_min"):
		if float(o.until) < 0.0:
			o["until"] = lg.sess.time + float(step.wait_min) * 60.0
		elif lg.sess.time >= float(o.until):
			_next(o)
		return
	if bool(o.get("sent", false)):
		if not _leg_on_road(step):
			_next(o)
		return
	var good := str(step.good)
	var from := str(step.from)
	var lb := float(step.lb)
	if lb <= 0.0:
		if good == "cash":
			lb = float(lg.sess.money) if from == Logistics.HQ else float(lg.cash.get(from, 0.0))
		else:
			lb = float(lg.stock[from].get(good, 0.0))
	var err: String = lg.send(from, str(step.to), good, lb, true)
	_did(o, err)
	if err == "":
		o["sent"] = true


func _leg_on_road(step: Dictionary) -> bool:
	var g := "" if str(step.good) == "cash" else str(step.good)
	for c in lg.convoys.values():
		if str(c.get("from", "")) == str(step.from) and str(c.get("to", "")) == str(step.to) and str(c.get("good", "")) == g:
			return true
	return false


func _next(o: Dictionary) -> void:
	o["sent"] = false
	o["until"] = -1.0
	o["at"] = int(o.get("at", 0)) + 1
	if int(o.at) < o.steps.size():
		return
	if bool(o.get("repeat", false)):
		o["at"] = 0
		return
	orders.erase(o)
	last = "%d: route done" % int(o.id)
	lg.sess.say("Standing order %d: the route is done." % int(o.id))


## A truck already carrying this order's kind to (or from) its stash: wait for it.
func _on_the_road(o: Dictionary) -> bool:
	for c in lg.convoys.values():
		if str(o.kind) == "cash" and str(c.get("from", "")) == str(o.stash) and str(c.get("good", "")) in ["", "cash"]:
			return true
		if str(o.kind) == "keep" and str(c.get("to", "")) == str(o.stash) and str(c.get("good", "")) == str(o.good):
			return true
	return false


## The live stash with the most of the good to spare: what it holds above its own keep orders' floor.
func _richest(o: Dictionary, need: float) -> String:
	var best := ""
	var most := 0.0
	for st in lg.sess.stash_net.live():
		var id := str(st.id)
		if id == str(o.stash):
			continue
		var floor_lb := 0.0
		for x in orders:
			if str(x.kind) == "keep" and str(x.stash) == id and str(x.good) == str(o.good):
				floor_lb = maxf(floor_lb, float(x.fill_to))
		var spare := float(lg.stock[id].get(str(o.good), 0.0)) - floor_lb
		if spare > most and spare >= minf(need, 25.0):
			most = spare
			best = id
	return best


func _did(o: Dictionary, err: String) -> void:
	last = "%d: %s" % [int(o.id), "sent" if err == "" else err]  # (a watch passes what it did)


func capture() -> Dictionary:
	return {"serial": _serial, "orders": orders.duplicate(true)} if not orders.is_empty() or _serial > 0 else {}


func restore(d: Dictionary) -> void:
	_serial = int(d.get("serial", 0))
	orders = []
	for o in d.get("orders", []):
		if o is Dictionary and str(o.get("kind", "")) in KINDS:
			var r: Dictionary = o.duplicate(true)
			r["id"] = int(r.get("id", 0))
			if str(r.kind) == "route":
				if not r.get("steps") is Array or (r.steps as Array).is_empty():
					continue
				r["at"] = clampi(int(r.get("at", 0)), 0, r.steps.size() - 1)
				r["sent"] = bool(r.get("sent", false))
				r["until"] = float(r.get("until", -1.0))
			orders.append(r)
