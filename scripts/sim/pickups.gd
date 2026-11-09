class_name Pickups
extends RefCounted
## Stock bought upfront and collected (docs/DESIGN.md section 51.2, ROADMAP "Stock, ownership and the money loop" slice 3, the sim):
## the player orders product from a contact, pays upfront, and the contact brings it to one of our stash houses in a window. It is
## collected by whoever is there in the window: the pilot (the aircraft stopped on the ground by the stash, or on foot at its door) or
## a lookout of ours posted at it. Then it is ours, in that stash, and the street and the buyers take it from there.
##
## Each order runs the PickupOrder lifecycle (ordered -> window -> at the place -> collected) with its failure exits:
## - **late**: the window ends with nobody there. The contact keeps the money and brings the lot once more, an hour on, and the
##   crew's standing drops (TRUST_LATE); late a second time and the lot is gone.
## - **cancelled**: the player calls it off before collecting; the money paid is lost (it was paid upfront).
## - **intercepted** (a rival at the place) is a state the model has; nothing sets it until the rivals act on pickups (a later slice,
##   with its own stream).
##
## The open owner question (DESIGN 51.4, "where the pickup happens") is taken as "the contact comes to a stash" for this slice, so a
## pickup needs no new place in the world; a fixed spot is the other answer and changes only `place`.
##
## No random draws (the window is fixed: OPENS_S after the order, WINDOW_S long). Saved in the strategic save. Behind ENABLED (in
## the parity set). Held by Logistics (`logistics.pickups`) and ticked by it.

static var ENABLED := true

## contact -> {name, goods it sells, markup on the board's wholesale price}. Trade.available decides whether the door is open.
const SELLERS := {
	"family": {"name": "the Morettis", "goods": ["marijuana", "cocaine"], "markup": 1.6},
	"agency": {"name": "the Company", "goods": ["cocaine"], "markup": 1.4},
}
const OPENS_S := 600.0  ## the window opens ten minutes after the order
const WINDOW_S := 900.0  ## and stays open fifteen (DESIGN 51.9: 10 to 20)
const REDO_S := 3600.0  ## a missed lot comes round once more, an hour on
const MAX_OPEN := 3
const MIN_LB := 5.0
const MAX_LB := 400.0
const NEAR_AIRCRAFT_M := 600.0  ## stopped on the ground this close to the stash
const NEAR_FOOT_M := 80.0
const TRUST_LATE := 3.0

var lg  ## Logistics (untyped: no cycle at parse time)
var orders: Array = []  ## {id, contact, good, lb, stash, paid, order: PickupOrder, missed, by}
var done: Array = []  ## the last few finished: {id, contact, good, lb, stash, result, t}
var _serial := 0


func _init(lg_) -> void:
	lg = lg_


## What `contact` asks a pound of `good` now: the board's wholesale price times its markup. 0 when it doesn't sell it.
func price(contact: String, good: String) -> float:
	var s: Dictionary = SELLERS.get(contact, {})
	if s.is_empty() or not good in s.goods or not Trade.OWN.has(good):
		return 0.0
	return float(Trade.OWN[good].per_lb) * lg.sess.econ.wholesale(good) * float(s.markup)


## Order `lb` of `good` from `contact`, brought to stash `stash` (the one nearest the HQ if ""). "" or why not.
func order(contact: String, good: String, lb: float, stash := "") -> String:
	if not ENABLED:
		return "Nobody takes stock orders in this game."
	var sess = lg.sess
	if not SELLERS.has(contact):
		return "Nobody by that name sells stock."
	var why: String = sess.trade.available(contact) if sess.trade != null else "There is no trade in this game."
	if why != "":
		return why
	if price(contact, good) <= 0.0:
		return "%s don't sell %s." % [str(SELLERS[contact].name).capitalize(), good]
	if good == "cocaine" and not sess.trade.connected:
		return "Nobody deals cocaine with us yet."
	if open_orders().size() >= MAX_OPEN:
		return "Three pickups are already on: collect one first."
	lb = clampf(lb, 0.0, MAX_LB)
	if lb < MIN_LB:
		return "They don't drive out for under %d lb." % int(MIN_LB)
	if stash == "":
		stash = lg.nearest_stash(lg.hq_pos())
	var st = sess.stash_net.get_stash(stash)
	if st == null or st.burned:
		return "That stash house can't take a delivery."
	var cost := int(ceil(lb * price(contact, good)))
	if sess.money < cost:
		return "%d lb costs $%s up front." % [int(lb), Py.money(cost)]
	sess.move_money(-cost, "outside:" + contact, "purchase")
	_serial += 1
	var po := PickupOrder.make(cost, "stash:" + stash, float(sess.time), OPENS_S, WINDOW_S)
	orders.append({"id": _serial, "contact": contact, "good": good, "lb": lb, "stash": stash, "paid": cost, "order": po, "missed": 0, "by": ""})
	sess.say("%s will bring %d lb of %s to %s in %d minutes and wait %d: be there, or have a lookout there ($%s paid)." % [
		str(SELLERS[contact].name).capitalize(), int(lb), good, lg.name_of(stash), int(OPENS_S / 60.0), int(WINDOW_S / 60.0), Py.money(cost)])
	sess.bus.emit("pickup_ordered", sess.time, "", ["runner"], {"id": _serial, "contact": contact, "good": good, "lb": lb, "stash": stash})
	return ""


func open_orders() -> Array:
	return orders


## Call off order `id` before it is collected. The money paid is lost. "" or why not.
func cancel(id: int) -> String:
	var o := _find(id)
	if o.is_empty():
		return "No such pickup."
	if not (o.order as PickupOrder).cancel():
		return "Too late to call it off."
	_finish(o, PickupOrder.CANCELLED)
	lg.sess.say("Called off: the $%s paid for %d lb of %s is gone." % [Py.money(int(o.paid)), int(o.lb), o.good])
	return ""


## Who is at a stash to take a delivery: "pilot", "lookout", or "".
func present(stash: String) -> String:
	var sess = lg.sess
	var p: Vector2 = lg.pos(stash)
	if sess.state != null and sess.state.on_ground and sess.state.gs_kts < 5.0 and Vector2(sess.state.x, sess.state.y).distance_to(p) <= NEAR_AIRCRAFT_M:
		return "pilot"
	if sess.foot != null and sess.foot.active and Vector2(sess.foot.x, sess.foot.y).distance_to(p) <= NEAR_FOOT_M:
		return "pilot"
	if sess.payroll != null:
		for w in sess.payroll.of("org", "lookout", "assigned"):
			if str(w.assigned) == "stash-" + stash:
				return "lookout"
	return ""


func update() -> void:
	if orders.is_empty():
		return
	var now: float = lg.sess.time
	for o in orders.duplicate():
		var po: PickupOrder = o.order
		var who := present(str(o.stash)) if now >= po.opens_at else ""
		po.advance(now, who != "")
		if po.state == PickupOrder.WINDOW and who != "":
			po.advance(now, true)  # opened with someone already there: at the place in the same check
		if po.state == PickupOrder.AT_PLACE and po.collect():
			o.by = who
			_collected(o)
		elif po.state == PickupOrder.LATE:
			_late(o)


func _collected(o: Dictionary) -> void:
	lg.add(str(o.stash), str(o.good), float(o.lb), str(o.contact))  # booked from outside:<contact>
	_finish(o, PickupOrder.COLLECTED)
	lg.sess.say("%d lb of %s from %s is in %s%s." % [int(o.lb), o.good, SELLERS[o.contact].name, lg.name_of(str(o.stash)),
		" (the lookout took it in)" if o.by == "lookout" else ""])
	lg.sess.bus.emit("pickup_collected", lg.sess.time, "", ["runner"], {"id": o.id, "good": o.good, "lb": o.lb, "by": o.by})


func _late(o: Dictionary) -> void:
	_trust(str(o.contact), -TRUST_LATE)
	o.missed = int(o.missed) + 1
	if int(o.missed) >= 2:
		_finish(o, PickupOrder.LATE)
		lg.sess.say("Nobody at %s again: %s keep the money and the %d lb of %s." % [lg.name_of(str(o.stash)), SELLERS[o.contact].name, int(o.lb), o.good])
		return
	var now: float = lg.sess.time
	o.order = PickupOrder.make(int(o.paid), "stash:" + str(o.stash), now, REDO_S - WINDOW_S, WINDOW_S)
	lg.sess.say("Nobody at %s to take the %s. %s will try once more in %d minutes." % [lg.name_of(str(o.stash)), o.good,
		str(SELLERS[o.contact].name).capitalize(), int((REDO_S - WINDOW_S) / 60.0)])


func _trust(contact: String, delta: float) -> void:
	var sess = lg.sess
	match contact:
		"family":
			if sess.family != null:
				sess.family.respect = clampf(sess.family.respect + delta, 0.0, 100.0)
		"agency":
			if sess.agency != null:
				sess.agency.trust = clampf(sess.agency.trust + delta, 0.0, 100.0)


func _finish(o: Dictionary, result: String) -> void:
	orders.erase(o)
	done.append({"id": o.id, "contact": o.contact, "good": o.good, "lb": o.lb, "stash": o.stash, "result": result, "t": lg.sess.time})
	Py.keep_last(done, 8)


func _find(id: int) -> Dictionary:
	for o in orders:
		if int(o.id) == id:
			return o
	return {}


## For the phone: each open order with its state and window.
func view() -> Array:
	return orders.map(func(o): return {"id": o.id, "contact": o.contact, "name": SELLERS[o.contact].name, "good": o.good, "lb": o.lb,
		"stash": o.stash, "place": lg.name_of(str(o.stash)), "state": (o.order as PickupOrder).state, "opens": (o.order as PickupOrder).opens_at,
		"closes": (o.order as PickupOrder).closes_at, "paid": o.paid, "missed": o.missed})


func capture() -> Dictionary:
	return {"serial": _serial, "done": done.duplicate(true), "orders": orders.map(func(o): return {"id": o.id, "contact": o.contact,
		"good": o.good, "lb": o.lb, "stash": o.stash, "paid": o.paid, "missed": o.missed, "state": (o.order as PickupOrder).state,
		"opens": (o.order as PickupOrder).opens_at, "closes": (o.order as PickupOrder).closes_at})}


func restore(d: Dictionary) -> void:
	_serial = int(d.get("serial", 0))
	done = (d.get("done", []) as Array).duplicate(true)
	orders = []
	for r in d.get("orders", []):
		if not r is Dictionary or not SELLERS.has(str(r.get("contact", ""))):
			continue
		var po := PickupOrder.new()
		po.paid = int(r.paid)
		po.place = "stash:" + str(r.stash)
		po.opens_at = float(r.opens)
		po.closes_at = float(r.closes)
		po.state = str(r.get("state", PickupOrder.ORDERED))
		orders.append({"id": int(r.id), "contact": str(r.contact), "good": str(r.good), "lb": float(r.lb), "stash": str(r.stash),
			"paid": int(r.paid), "order": po, "missed": int(r.get("missed", 0)), "by": ""})
