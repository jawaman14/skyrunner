class_name Orders
extends RefCounted
## Buyers' orders (owner, 18 Oct: the product and money loop gets deadlines that follow demand). A buyer who is open for
## business asks for a quantity of a good by a time and pays more than his quote if it arrives in time; miss it and the crew's
## trust falls. How long he gives depends on how badly the street wants the stuff: where demand outruns supply it is a rush
## (10 to 20 minutes, a higher premium); otherwise it is a night's work (45 to 75 minutes, a lower one).
##
## It rides on Trade: an order is filled by any bulk sale to that buyer that SETTLES before the deadline (a truck reaching the
## meet, or a direct sale), so the lead time of the logistics is what the player is racing. Orders only exist where Trade does
## (live play, the story from 1980). Own RNG stream (seed + 167); off with `Orders.ENABLED`.

static var ENABLED := true

const RUSH_S := [600.0, 1200.0]  ## 10 to 20 minutes
const NIGHT_S := [2700.0, 4500.0]  ## a night's work: 45 to 75 minutes
const RUSH_PRESSURE := 1.25  ## demand over supply in the buyer's market from which an order is a rush
const PREMIUM := {"rush": [1.25, 1.40], "night": [1.10, 1.20]}  ## paid on top of the buyer's own quote (not the street price), on the pounds delivered in time
const EVERY_S := 900.0  ## about one new order this often while there is room for one
const MAX_OPEN := 2
const SHARE := [0.35, 0.7]  ## of the buyer's appetite cap
const DONE_TRUST := 3.0
const FAIL_TRUST := 4.0
const SAMPLE_S := 300.0  ## how often the board remembers prices, for its trend arrows
const TREND_MIN := 0.03

var sess
var trade
var rng: PyRandom
var open: Array = []  ## {id, buyer, good, qty, left, premium, kind, posted, due}
var history: Array = []  ## the last few: {id, buyer, good, qty, result: "filled"|"missed"|"part", filled}
var _next_id := 1
var _sample_t := 0.0
var _prev := {}  ## "good|market" -> the factor at the last sample


func _init(sess_, trade_, rng_: PyRandom) -> void:
	sess = sess_
	trade = trade_
	rng = rng_


## One step of Trade's minute clock: expire what is overdue, remember prices for the trend, maybe post a new order.
func update(now: float, step: float) -> void:
	for o in open.duplicate():
		if now >= float(o.due):
			_expire(o)
	if now - _sample_t >= SAMPLE_S:
		_sample_t = now
		_remember()
	if open.size() < MAX_OPEN and rng.random() < minf(1.0, step / EVERY_S):
		_post(now)


## The demand over supply of `good` in `market` (1 = normal).
func pressure(good: String, market: String) -> float:
	var mk: Market = sess.econ.market if sess.econ != null else null
	if mk == null or not mk.supply.has(good):
		return 1.0
	return float(mk.demand[good][market]) / maxf(0.15, float(mk.supply[good][market]))


func _candidates() -> Array:
	var out := []
	for b in Trade.BUYERS:
		if trade.available(b) != "":
			continue
		var mkt: String = Trade.BUYERS[b].market
		for g in Trade.BUYERS[b].cap:
			if trade.quote(b, g).why != "" or _has_open(b, g):
				continue
			if g == "guns" and not (sess.unlocked("guns") and sess.arsenals.has("org")):
				continue  # nobody orders what we cannot sell yet
			out.append([b, g, maxf(0.2, pressure(g, mkt))])
	return out


func _has_open(buyer: String, good: String) -> bool:
	for o in open:
		if o.buyer == buyer and o.good == good:
			return true
	return false


func _post(now: float) -> void:
	var c := _candidates()
	if c.is_empty():
		return
	var total := 0.0
	for x in c:
		total += float(x[2])
	var roll := rng.random() * total
	var pick: Array = c[c.size() - 1]
	for x in c:
		roll -= float(x[2])
		if roll <= 0.0:
			pick = x
			break
	var buyer: String = pick[0]
	var good: String = pick[1]
	var b: Dictionary = Trade.BUYERS[buyer]
	var kind := "rush" if pressure(good, b.market) >= RUSH_PRESSURE else "night"
	var window: Array = RUSH_S if kind == "rush" else NIGHT_S
	var cap := float(b.cap[good])
	var qty := roundf(cap * rng.uniform(SHARE[0], SHARE[1]))
	if good == "guns":
		qty = maxf(2.0, floorf(qty))
	qty = maxf(1.0, qty)
	var prem: Array = PREMIUM[kind]
	var o := {"id": _next_id, "buyer": buyer, "good": good, "qty": qty, "left": qty,
		"premium": snappedf(rng.uniform(prem[0], prem[1]), 0.01), "kind": kind, "posted": now, "due": now + rng.uniform(window[0], window[1])}
	_next_id += 1
	open.append(o)
	trade.appetite[buyer][good] = maxf(float(trade.appetite[buyer][good]), qty)  # he has asked for it: there is room
	var mins := int(round((float(o.due) - now) / 60.0))
	var unit := "%d lb of %s" % [int(qty), good] if good != "guns" else "%d rifles" % int(qty)
	var text := "%s want %s within %d minutes (%d%% above his usual price)%s." % [b.name, unit, mins, int(round((float(o.premium) - 1.0) * 100.0)),
		" - the street is hungry" if kind == "rush" else ""]
	sess.say(text)
	sess.bus.emit("order_posted", now, text, ["runner"], {"id": o.id, "buyer": buyer, "good": good, "qty": qty, "kind": kind})


## A bulk sale to `buyer` of `qty` of `good` settled at `unit_price` a pound (a weapon): the premium on what the open order
## still wanted, in dollars (0 when none). Fills the order, and completes it when nothing is left.
func on_settle(buyer: String, good: String, qty: float, unit_price: float) -> int:
	for o in open.duplicate():
		if o.buyer != buyer or o.good != good:
			continue
		if sess.time >= float(o.due):  # a truck that arrives after the deadline but before the next minute's check is late
			_expire(o)
			continue
		var fill := minf(qty, float(o.left))
		if fill <= 0.0:
			continue
		var bonus := int(unit_price * fill * (float(o.premium) - 1.0))
		o.left = float(o.left) - fill
		if float(o.left) < 0.5 or (good == "guns" and float(o.left) < 1.0):
			open.erase(o)
			_trust(buyer, DONE_TRUST)
			_log(o, "filled", float(o.qty))
			var text := "%s's order is filled in time: +$%s on top." % [Trade.BUYERS[buyer].name, Py.money(bonus)]
			sess.say(text)
			sess.bus.emit("order_filled", sess.time, text, ["runner"], {"id": o.id, "buyer": buyer, "good": good, "bonus": bonus})
		return bonus
	return 0


func _expire(o: Dictionary) -> void:
	open.erase(o)
	var done := float(o.qty) - float(o.left)
	var share := 1.0 - done / maxf(1.0, float(o.qty))  # a part delivered costs a part of the trust
	_trust(str(o.buyer), -FAIL_TRUST * share)
	_log(o, "part" if done > 0.0 else "missed", done)
	var text := "%s's order ran out: %s." % [Trade.BUYERS[o.buyer].name, "%d of %d delivered" % [int(done), int(o.qty)] if done > 0.0 else "nothing came"]
	sess.say(text)
	sess.bus.emit("order_missed", sess.time, text, ["runner"], {"id": o.id, "buyer": o.buyer, "good": o.good, "delivered": done})


func _log(o: Dictionary, result: String, filled: float) -> void:
	history.append({"id": o.id, "buyer": o.buyer, "good": o.good, "qty": o.qty, "result": result, "filled": filled})
	Py.keep_last(history, 8)


## The buyer's crew trusts us more or less (until the per-crew trust table of D-11 exists, the standing each crew already has).
func _trust(buyer: String, delta: float) -> void:
	match buyer:
		"family":
			if sess.family != null:
				sess.family.respect = clampf(sess.family.respect + delta, 0.0, 100.0)
		"agency":
			if sess.agency != null:
				sess.agency.trust = clampf(sess.agency.trust + delta, 0.0, 100.0)


func _remember() -> void:
	var mk: Market = sess.econ.market if sess.econ != null else null
	if mk == null:
		return
	for g in Market.HOT:
		for m in Economy.MARKETS:
			_prev["%s|%s" % [g, m]] = mk.factor(g, m)


## What the player's market board shows: for each hot good in each market the price against normal, the pressure behind it and
## which way it is going; the open orders with the time they have left; the last few results.
func board() -> Dictionary:
	var mk: Market = sess.econ.market if sess.econ != null else null
	var goods := {}
	if mk == null:
		return {"goods": goods}
	for g in Market.HOT:
		var rows := {}
		for m in Economy.MARKETS:
			var f := mk.factor(g, m)
			var was: float = float(_prev.get("%s|%s" % [g, m], f))
			rows[m] = {"price": snappedf(f, 0.01), "pressure": snappedf(pressure(g, m), 0.01),
				"trend": "up" if f - was > TREND_MIN else ("down" if was - f > TREND_MIN else "flat")}
		goods[g] = rows
	return {"goods": goods}


func view() -> Dictionary:
	var rows := []
	for o in open:
		rows.append({"id": o.id, "buyer": o.buyer, "name": Trade.BUYERS[o.buyer].name, "good": o.good, "qty": int(o.qty), "left": int(ceil(float(o.left))),
			"premium": o.premium, "kind": o.kind, "seconds_left": maxi(0, int(float(o.due) - sess.time))})
	return {"open": rows, "recent": history.duplicate(true), "board": board()}
