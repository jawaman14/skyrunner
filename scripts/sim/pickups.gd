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
## - **intercepted**: Los Cuervos stop the contact's car on its way (DESIGN 81). As a window opens the lot is taken with a chance
##   of INTERCEPT_SHARE times their hold on the stash's district, no more than INTERCEPT_MAX, and half that with one of ours at the
##   door (the pilot, a lookout). The lot and the money paid are gone; drugs reach their corners, weapons their armoury. Needs the
##   street war. Its own stream (seed + 201), one draw a window. Behind INTERCEPTS (in the parity set).
##
## **The gun dealer** is on the same flow (`order_guns`): crates of one type (Crates.SPEC), paid upfront at CRATE_PRICE of the
## dealer's price for that many singles, taken off the street's supply when ordered, brought to a stash in the same window and put in
## the armoury there. Missed twice or called off, the weapons go back on the street.
##
## The open owner question (DESIGN 51.4, "where the pickup happens") is taken as "the contact comes to a stash" for this slice, so a
## pickup needs no new place in the world; a fixed spot is the other answer and changes only `place`.
##
## The window is fixed (OPENS_S after the order, WINDOW_S long); the only draws are the interceptions'. Saved in the strategic save.
## Behind ENABLED (in the parity set). Held by Logistics (`logistics.pickups`) and ticked by it.

static var ENABLED := true
static var INTERCEPTS := true  ## Los Cuervos can take a lot on its way (off: the game as it was)

## contact -> {name, goods it sells, markup on the board's wholesale price}. Trade.available decides whether the door is open.
const SELLERS := {
	"family": {"name": "the Morettis", "goods": ["marijuana", "cocaine"], "markup": 1.6},
	"agency": {"name": "the Company", "goods": ["cocaine"], "markup": 1.4},
	"dealer": {"name": "the gun dealer", "goods": ["guns"], "markup": 1.0},  # crates, through order_guns
}
const CRATE_PRICE := 0.9  ## a crate ordered ahead, against the dealer's price for the same weapons one at a time
const MAX_CRATES := 4
const INTERCEPT_SHARE := 0.5  ## chance a lot is taken, per unit of Los Cuervos' hold on the district
const INTERCEPT_MAX := 0.4
const INTERCEPT_WATCHED := 0.5  ## with one of ours at the door
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
var rng: PyRandom = null  ## interceptions (seed + 201; set by the session, null without)
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


## Order `crates` crates of weapon `tier` from the gun dealer, brought to stash `stash`. "" or why not.
func order_guns(tier: String, crates: int, stash := "") -> String:
	if not ENABLED:
		return "Nobody takes stock orders in this game."
	var sess = lg.sess
	if not Arsenal.REALISM or not sess.arsenals.has("org"):
		return "No arsenal."
	if not sess.unlocked("guns"):
		return "No gun dealer will talk to us yet."
	if not Crates.SPEC.has(tier):
		return "Crates of what?"
	if crates < 1 or crates > MAX_CRATES:
		return "One to %d crates an order." % MAX_CRATES
	if open_orders().size() >= MAX_OPEN:
		return "Three pickups are already on: collect one first."
	var n: int = crates * int(Crates.SPEC[tier].holds)
	var kind: String = str(Arsenal.TIERS[tier].name).to_lower()
	if sess.crates != null and sess.crates.available(tier) < n:
		return "The dealers have only %d %s between them." % [sess.crates.available(tier), kind]
	if stash == "":
		stash = lg.nearest_stash(lg.hq_pos())
	var st = sess.stash_net.get_stash(stash)
	if st == null or st.burned:
		return "That stash house can't take a delivery."
	var cost := int(ceil(float(sess.weapon_price(tier, true)) * n * CRATE_PRICE))
	if sess.money < cost:
		return "%d %s cost $%s up front." % [n, kind, Py.money(cost)]
	sess.move_money(-cost, "outside:market", "purchase")
	if sess.crates != null:
		sess.crates.flow(tier, -n)  # spoken for: off the street now
	_serial += 1
	var po := PickupOrder.make(cost, "stash:" + stash, float(sess.time), OPENS_S, WINDOW_S)
	orders.append({"id": _serial, "contact": "dealer", "good": "guns", "tier": tier, "lb": float(n), "stash": stash, "paid": cost, "order": po, "missed": 0, "by": ""})
	sess.say("The gun dealer will bring %d crate%s of %s (%d) to %s in %d minutes and wait %d: be there, or have a lookout there ($%s paid)." % [
		crates, "" if crates == 1 else "s", kind, n, lg.name_of(stash), int(OPENS_S / 60.0), int(WINDOW_S / 60.0), Py.money(cost)])
	sess.bus.emit("pickup_ordered", sess.time, "", ["runner"], {"id": _serial, "contact": "dealer", "good": "guns", "tier": tier, "lb": float(n), "stash": stash})
	return ""


## What a lot is, in words: "50 lb of marijuana", "16 rifles".
static func describe(o: Dictionary) -> String:
	if str(o.good) == "guns":
		return "%d %s" % [int(o.lb), str(Arsenal.TIERS[str(o.get("tier", "rifle"))].name).to_lower()]
	return "%d lb of %s" % [int(o.lb), o.good]


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
	_back_on_the_street(o)
	lg.sess.say("Called off: the $%s paid for %s is gone." % [Py.money(int(o.paid)), describe(o)])
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
		var was := po.state
		po.advance(now, who != "")
		if was == PickupOrder.ORDERED and po.state == PickupOrder.WINDOW and _intercepted(o, who != ""):
			continue
		if po.state == PickupOrder.WINDOW and who != "":
			po.advance(now, true)  # opened with someone already there: at the place in the same check
		if po.state == PickupOrder.AT_PLACE and po.collect():
			o.by = who
			_collected(o)
		elif po.state == PickupOrder.LATE:
			_late(o)


## The window has just opened: do Los Cuervos have the car? One draw (with the street war on and a hold on the district to speak of).
func _intercepted(o: Dictionary, watched: bool) -> bool:
	var sess = lg.sess
	if not INTERCEPTS or rng == null or sess.ground == null:
		return false
	var st = sess.stash_net.get_stash(str(o.stash))
	var zone: String = str(st.zone) if st != null else "town"
	var share: float = maxf(0.0, float(sess.ground.rival_share(zone)))  # (a district nobody holds reads -1)
	var p: float = minf(INTERCEPT_MAX, INTERCEPT_SHARE * share) * (INTERCEPT_WATCHED if watched else 1.0)
	var tr := Trust.of_session(sess)
	if tr != null:
		p *= tr.rival_odds()  # a truce with Los Cuervos (DESIGN 84; the same draw)
	if rng.random() >= p:
		return false
	(o.order as PickupOrder).intercept()
	_finish(o, PickupOrder.INTERCEPTED)
	if str(o.good) == "guns":
		if sess.arsenals.has("rival"):
			sess.arsenals["rival"].add(str(o.get("tier", "rifle")), int(o.lb))
	elif sess.econ.market != null:
		sess.econ.market.flow(str(o.good), zone, 0.1, "Los Cuervos are selling a load they took")
	var text := "Los Cuervos stopped %s's car on its way to %s: the %s and the $%s paid are gone." % [SELLERS[o.contact].name,
		lg.name_of(str(o.stash)), describe(o), Py.money(int(o.paid))]
	sess.say(text)
	sess.bus.emit("pickup_intercepted", sess.time, text, ["runner"], {"id": o.id, "good": o.good, "lb": o.lb, "stash": o.stash})
	return true


## Weapons ordered and never taken in go back on the street's supply.
func _back_on_the_street(o: Dictionary) -> void:
	if str(o.good) == "guns" and lg.sess.crates != null:
		lg.sess.crates.flow(str(o.get("tier", "rifle")), float(o.lb))


func _collected(o: Dictionary) -> void:
	if str(o.good) == "guns":
		lg.sess.arsenals["org"].add(str(o.get("tier", "rifle")), int(o.lb))
		lg.sess.arsenals["org"].cache = str(o.stash)  # the armoury is where the crates were taken in
		lg.sess.bus.emit("weapons_stocked", lg.sess.time, "", ["runner"], {"weapons": {str(o.get("tier", "rifle")): int(o.lb)}, "cache": str(o.stash)})
	else:
		lg.add(str(o.stash), str(o.good), float(o.lb), str(o.contact))  # booked from outside:<contact>
	_finish(o, PickupOrder.COLLECTED)
	lg.sess.say("%s from %s %s in %s%s." % [describe(o).capitalize(), SELLERS[o.contact].name, "are" if str(o.good) == "guns" else "is", lg.name_of(str(o.stash)),
		" (the lookout took it in)" if o.by == "lookout" else ""])
	lg.sess.bus.emit("pickup_collected", lg.sess.time, "", ["runner"], {"id": o.id, "good": o.good, "lb": o.lb, "by": o.by})


func _late(o: Dictionary) -> void:
	_trust(str(o.contact), -TRUST_LATE)
	o.missed = int(o.missed) + 1
	if int(o.missed) >= 2:
		_finish(o, PickupOrder.LATE)
		_back_on_the_street(o)
		lg.sess.say("Nobody at %s again: %s keep%s the money and the %s." % [lg.name_of(str(o.stash)), SELLERS[o.contact].name,
			"s" if str(o.contact) == "dealer" else "", describe(o)])
		return
	var now: float = lg.sess.time
	o.order = PickupOrder.make(int(o.paid), "stash:" + str(o.stash), now, REDO_S - WINDOW_S, WINDOW_S)
	lg.sess.say("Nobody at %s to take the %s. %s will try once more in %d minutes." % [lg.name_of(str(o.stash)), "crates" if str(o.good) == "guns" else o.good,
		str(SELLERS[o.contact].name).capitalize(), int((REDO_S - WINDOW_S) / 60.0)])


func _trust(contact: String, delta: float) -> void:
	if lg.sess.trade != null:
		lg.sess.trade.trust.nudge(contact, delta)


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
		"tier": str(o.get("tier", "")), "what": describe(o),
		"stash": o.stash, "place": lg.name_of(str(o.stash)), "state": (o.order as PickupOrder).state, "opens": (o.order as PickupOrder).opens_at,
		"closes": (o.order as PickupOrder).closes_at, "paid": o.paid, "missed": o.missed})


func capture() -> Dictionary:
	return {"serial": _serial, "done": done.duplicate(true), "orders": orders.map(func(o): return {"id": o.id, "contact": o.contact,
		"good": o.good, "lb": o.lb, "tier": str(o.get("tier", "")), "stash": o.stash, "paid": o.paid, "missed": o.missed, "state": (o.order as PickupOrder).state,
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
		orders.append({"id": int(r.id), "contact": str(r.contact), "good": str(r.good), "lb": float(r.lb), "tier": str(r.get("tier", "")), "stash": str(r.stash),
			"paid": int(r.paid), "order": po, "missed": int(r.get("missed", 0)), "by": ""})
