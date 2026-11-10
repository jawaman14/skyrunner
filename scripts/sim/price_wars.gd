class_name PriceWars
extends RefCounted
## Price wars and supply cuts (loop idea 6, docs/LOOP_IDEAS.md; docs/DESIGN.md section 78).
##
## Now and then somebody moves a market against us, and says so:
##
##   undercut  Los Cuervos sell under us in a market where our dealers work: its price falls about a fifth, and our corners there
##             lose a third of their custom to the cheaper product while it lasts
##   flood     the Company dumps a load in one market: the price falls further, for a shorter time; our custom is untouched
##   cut       a boat is taken or a field burned: one good runs short everywhere and the street pays more for it
##
## The first two can be answered, once, while they run (`answer`):
##
##   match     our dealers there sell at MATCH_PRICE of the street: they keep their custom (and take a little of the other side's),
##             and every minute matched takes MATCH_BURN more off the war - nobody undercuts a price that follows him down
##   hold      our dealers there stop selling that good and the stock stays in the stash; when the war ends the customers who
##             waited come back at once (demand x HOLD_REBOUND for HOLD_REBOUND_MIN minutes in that market)
##
## Unanswered, the war runs its time and takes what it takes. A cut asks for nothing: it is a window to sell into.
## With no boss in the chair the organisation's AI matches an undercut and holds through a flood.
##
## Own RNG stream (seed + 197): one draw every CHECK_S with no war on, and a war's kind, market and length when one starts.
## Saved. Behind ENABLED (in the parity set): off, no war ever starts.

static var ENABLED := true

const CHECK_S := 600.0
const CHANCE := 0.3  ## a check: about one war every 35 minutes of quiet
const QUIET_S := 900.0  ## after a war ends, none for this long
const LENGTH_S := {"undercut": [1800.0, 3000.0], "flood": [1200.0, 2100.0], "cut": [1500.0, 2700.0]}
const SUPPLY := {"undercut": 1.5, "flood": 1.9}  ## the street supply the war holds its market at (the price follows demand / supply)
const CUT_SOURCE := 0.55  ## a cut holds the good's source at or under this
const UNDERCUT_SHARE := 0.67  ## our dealers' custom there while undercut and unanswered
const MATCH_PRICE := 0.85
const MATCH_SHARE := 1.1
const MATCH_BURN := 2.0  ## war-seconds taken off for each second matched
const HOLD_REBOUND := 1.3
const HOLD_REBOUND_MIN := 30.0
const WHO := {"undercut": "rival", "flood": "agency", "cut": "source"}
const ANSWERS := ["match", "hold"]

var sess
var trade
var rng: PyRandom
var war := {}  ## {} or {id, kind, good, market, started, until, answer}
var history: Array = []  ## the last few: {id, kind, good, market, answer, minutes}
var _next_id := 1
var _check_t := 0.0
var _quiet_until := 0.0


func _init(sess_, trade_, rng_: PyRandom) -> void:
	sess = sess_
	trade = trade_
	rng = rng_


func active() -> bool:
	return not war.is_empty()


func update(now: float, step: float) -> void:
	if active():
		_run(now, step)
		return
	_check_t += step
	if _check_t < CHECK_S:
		return
	_check_t = 0.0
	if now < _quiet_until or rng.random() >= CHANCE:
		return
	_start(now)


## Which wars can start now: an undercut needs Los Cuervos and a market where our dealers stand; a flood needs the Company's
## pipeline; a cut needs nothing.
func _kinds() -> Array:
	var out := ["cut"]
	if sess.ground != null and not _our_markets().is_empty():
		out.append("undercut")
		out.append("undercut")  # the commonest: they are next door
	if sess.agency != null and sess.agency.active() and trade.connected:
		out.append("flood")
	return out


func _our_markets() -> Array:
	var out := []
	for m in Economy.MARKETS:
		if not trade.dealers("org", m).is_empty():
			out.append(m)
	return out


func _start(now: float) -> void:
	var kinds := _kinds()
	var kind: String = kinds[rng.randint(0, kinds.size() - 1)]
	var good := "cocaine" if trade.connected else "marijuana"
	var market := "*"
	if kind == "undercut":
		var ms := _our_markets()
		market = ms[rng.randint(0, ms.size() - 1)]
	elif kind == "flood":
		market = Economy.MARKETS[rng.randint(0, Economy.MARKETS.size() - 1)]
	else:
		good = Trade.GOODS[rng.randint(0, Trade.GOODS.size() - 1)]
	var len: Array = LENGTH_S[kind]
	war = {"id": _next_id, "kind": kind, "good": good, "market": market, "started": now, "until": now + rng.uniform(len[0], len[1]), "answer": ""}
	_next_id += 1
	_run(now, 0.0)
	var text := headline(war)
	sess.say("NEWS - " + text)
	sess.bus.emit("price_war", now, text, ["runner"], {"id": war.id, "kind": kind, "good": good, "market": market})
	if sess.payroll != null and sess.payroll.ai.get("org", false) and kind != "cut":
		answer(int(war.id), "match" if kind == "undercut" else "hold")  # nobody in the chair: the organisation's AI answers


static func headline(w: Dictionary) -> String:
	var where := Market._name(str(w.market))
	var mins := int(round((float(w.until) - float(w.started)) / 60.0))
	match str(w.kind):
		"undercut":
			return "Los Cuervos are selling %s under our price in the %s: about %d minutes of it unless we answer" % [w.good, where, mins]
		"flood":
			return "The Company has dumped a load of %s in the %s: the price is on the floor for about %d minutes" % [w.good, where, mins]
	return "%s is short everywhere (%s): the street pays more for about %d minutes" % [str(w.good).capitalize(),
		"a boat was taken off the coast" if w.good == "cocaine" else "the fields upcountry were burned", mins]


## Hold the market where the war wants it, burn a matched war down, and end it on time.
func _run(now: float, step: float) -> void:
	var mk = sess.econ.market
	var kind := str(war.kind)
	if mk != null:
		if kind == "cut":
			if float(mk.source[war.good]) > CUT_SOURCE:
				mk.source_shock(str(war.good), CUT_SOURCE - float(mk.source[war.good]))
		else:
			var want: float = SUPPLY[kind]
			var has: float = mk.supply[war.good][war.market]
			if has < want:
				mk.flow(str(war.good), str(war.market), want - has, "a price war" if kind == "undercut" else "the Company's load")
	if war.answer == "match":
		war.until = float(war.until) - MATCH_BURN * step
	if now >= float(war.until):
		_end(now)


func _end(now: float) -> void:
	var w := war
	war = {}
	_quiet_until = now + QUIET_S
	_check_t = 0.0
	var text := ""
	match str(w.answer):
		"match":
			text = "Los Cuervos give up the price war in the %s: our corners kept their custom." % Market._name(str(w.market)) if w.kind == "undercut" else "The Company's load in the %s is sold out; we matched it all the way." % Market._name(str(w.market))
			if Trust.ENABLED and w.kind == "undercut":
				trade.trust.nudge("dealers", 2.0)  # the corners were stood by
		"hold":
			text = "The cheap %s in the %s is gone, and the customers who waited are back." % [w.good, Market._name(str(w.market))]
			if sess.econ.market != null:
				sess.econ.market.demand_shock(str(w.good), str(w.market), HOLD_REBOUND, HOLD_REBOUND_MIN)
		_:
			text = "The %s is over." % ("shortage of %s" % w.good if w.kind == "cut" else "price war in the %s" % Market._name(str(w.market)))
	history.append({"id": w.id, "kind": w.kind, "good": w.good, "market": w.market, "answer": w.answer,
		"minutes": int(round((now - float(w.started)) / 60.0))})
	Py.keep_last(history, 6)
	sess.say(text)
	sess.bus.emit("price_war_over", now, text, ["runner"], {"id": w.id, "kind": w.kind, "answer": w.answer})


## Answer the war under way: "match" or "hold". Returns "" or why not.
func answer(id: int, how: String) -> String:
	if not active() or int(war.id) != id:
		return "No such price war."
	if war.kind == "cut":
		return "Nothing to answer: sell into it, or wait it out."
	if not how in ANSWERS:
		return "Match their price, or hold the stock?"
	if war.answer != "":
		return "We have answered this one already."
	war.answer = how
	var where := Market._name(str(war.market))
	sess.say("Our corners in the %s match the price: thinner money, and the war ends sooner." % where if how == "match"
		else "Our corners in the %s stop selling %s until the price comes back." % [where, war.good])
	return ""


## What the war does to one of our dealers selling `good` in `market`: {share, price, hold}.
func street(good: String, market: String) -> Dictionary:
	var out := {"share": 1.0, "price": 1.0, "hold": false}
	if not active() or war.kind == "cut" or war.good != good or war.market != market:
		return out
	match str(war.answer):
		"match":
			out.price = MATCH_PRICE
			out.share = MATCH_SHARE
		"hold":
			out.hold = true
		_:
			if war.kind == "undercut":
				out.share = UNDERCUT_SHARE
	return out


func view() -> Dictionary:
	var now: float = sess.time
	var w := {}
	if active():
		w = war.duplicate()
		w["seconds_left"] = maxf(0.0, float(war.until) - now)
		w["who"] = WHO[war.kind]
		w["text"] = headline(war)
		w["can_answer"] = war.kind != "cut" and war.answer == ""
	return {"war": w, "history": history.duplicate(true)}


func capture() -> Dictionary:
	return {"war": war.duplicate(), "history": history.duplicate(true), "next_id": _next_id, "check_t": _check_t, "quiet_until": _quiet_until}


func restore(d: Dictionary) -> void:
	war = (d.get("war", {}) as Dictionary).duplicate() if d.get("war") is Dictionary else {}
	if war.has("id"):
		war.id = int(war.id)
	history = []
	if d.get("history") is Array:
		for h in d.history:
			if h is Dictionary:
				var e: Dictionary = h.duplicate()
				e["id"] = int(e.get("id", 0))
				e["minutes"] = int(e.get("minutes", 0))
				history.append(e)
	_next_id = int(d.get("next_id", 1))
	_check_t = float(d.get("check_t", 0.0))
	_quiet_until = float(d.get("quiet_until", 0.0))
