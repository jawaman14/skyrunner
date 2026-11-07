class_name BlackMarket
extends RefCounted
## The weekly black market and the week's hot job (owner, 7 Nov, D-95: the Borderlands study's round two, its weekly vendor and
## its rotating featured mission). Both turn over with the island week (Weekly), so every week has something worth checking.
##
## The black market: a fence posts OFFERS one-off deals from what this game has open, each good for the week and bought once:
##   arms     a crate of rifles (machine guns from renown tier 2) into the organisation's armoury, below the street price
##   vehicle  a stash truck that fell off a lorry, VEHICLE_OFF off the lot's price
##   fuel     FUEL_LB of fuel left at a back strip, for a song
##   file     a bent clerk loses part of the case file on you: FILE_HEAT suspicion off
## The phone's Week app lists them; ENTER on one buys it (the `black_market_buy` command). Money goes to outside:black-market.
##
## The week's hot job: the best job on one strip's board is marked (HOT_TAG in its title), pays HOT_PAY times as much, and pays
## HOT_RENOWN renown on delivery. When the week turns, an untaken one loses the mark (and the extra pay) and a new one is chosen.
##
## Drawn when the week posts, on its own stream (seed + 191). Behind ENABLED (in the parity set); only while the week runs.

static var ENABLED := true

const OFFERS := 3
const ARMS_OFF := 0.55  ## a crate at this share of the street price
const VEHICLE_OFF := 0.30  ## off the lot's price
const FUEL_LB := 400.0
const FUEL_PRICE := 150
const FILE_HEAT := 20.0
const FILE_PRICE := 4000  ## times (1 + renown tier)
const HOT_PAY := 1.5
const HOT_RENOWN := 20.0
const HOT_TAG := "HOT JOB OF THE WEEK: "

var sess
var rng: PyRandom
var week := 0  ## the week the offers below are for
var offers: Array = []  ## {kind, text, price, sold, ...}
var hot := {}  ## {job_id, code, base}: the week's hot job (empty when none)
var bought := 0


func _init(sess_, rng_: PyRandom) -> void:
	sess = sess_
	rng = rng_
	sess.bus.subscribe("job_delivered", _on_delivered)


func live() -> bool:
	return ENABLED and sess.weekly != null and sess.weekly.live() and int(sess.weekly.week) > 0


func update() -> void:
	if not live() or int(sess.weekly.week) == week:
		return
	week = int(sess.weekly.week)
	_post()


func _tier() -> int:
	return sess.renown.tier() if sess.renown != null else 0


# ------------------------------------------------------------------ the offers
func _pool() -> Array:
	var out := []
	if sess.arsenals.has("org"):
		var tier := "mg" if _tier() >= 2 else "rifle"
		var n := 2 if tier == "mg" else 6
		var price := int(round(float(Arsenal.TIERS[tier].price) * n * ARMS_OFF / 50.0)) * 50
		out.append({"kind": "arms", "tier": tier, "n": n, "price": price,
			"text": "A crate of %d %s off an army truck, $%s (street $%s)" % [n, str(Arsenal.TIERS[tier].name).to_lower(), Py.money(price),
				Py.money(int(Arsenal.TIERS[tier].price) * n)]})
	if sess.dealer != null:
		var trucks := Dealership.CATALOGUE.filter(func(c): return c.use == "haul")
		if not trucks.is_empty():
			var sp: Dictionary = trucks[rng.randint(0, trucks.size() - 1)]
			var price := int(round(float(sp.price) * (1.0 - VEHICLE_OFF) / 100.0)) * 100
			out.append({"kind": "vehicle", "id": str(sp.id), "price": price,
				"text": "A %s that fell off a lorry, $%s (the lot asks $%s)" % [sp.name, Py.money(price), Py.money(int(sp.price))]})
	var strips: Array = sess.world.airfields.filter(func(a): return a.kind in ["bush", "shady"])
	if not strips.is_empty():
		var af: Airfield = strips[rng.randint(0, strips.size() - 1)]
		out.append({"kind": "fuel", "code": af.code, "price": FUEL_PRICE,
			"text": "%d lb of fuel left in drums at %s, $%s" % [int(FUEL_LB), af.name, Py.money(FUEL_PRICE)]})
	if sess.police != null:
		var price := FILE_PRICE * (1 + _tier())
		out.append({"kind": "file", "price": price,
			"text": "A clerk who loses paper: %d off the heat on you, $%s" % [int(FILE_HEAT), Py.money(price)]})
	return out


func _post() -> void:
	var pool := _pool()
	offers = []
	while offers.size() < OFFERS and not pool.is_empty():
		var o: Dictionary = pool.pop_at(rng.randint(0, pool.size() - 1))
		o["sold"] = false
		offers.append(o)
	_post_hot()
	if not offers.is_empty():
		sess.say("The black market has new stock this week [Phone > Week].")


## Buy offer `i`. "" or why not.
func buy(i: int) -> String:
	if not live():
		return "Nobody is selling anything this week."
	if i < 0 or i >= offers.size():
		return "No such offer."
	var o: Dictionary = offers[i]
	if bool(o.sold):
		return "Already sold."
	var price := int(o.price)
	if sess.money < price:
		return "He wants $%s." % Py.money(price)
	match str(o.kind):
		"arms":
			var ars = sess.arsenals.get("org")
			if ars == null:
				return "There is no armoury to take it."
			sess.move_money(-price, "outside:black-market", "purchase", "org")
			ars.add(str(o.tier), int(o.n))
		"vehicle":
			var err: String = sess.dealer.buy(str(o.id), true, price, "outside:black-market")
			if err != "":
				return err
		"fuel":
			sess.move_money(-price, "outside:black-market", "purchase", "org")
			sess.fuel_caches[str(o.code)] = float(sess.fuel_caches.get(str(o.code), 0.0)) + FUEL_LB
		"file":
			sess.move_money(-price, "outside:black-market", "bribe", "org")
			var c = sess.police.case("runner")
			c.suspicion = maxf(0.0, c.suspicion - FILE_HEAT)
	o.sold = true
	bought += 1
	sess.say("Black market: %s. Done." % str(o.text))
	sess.bus.emit("black_market", sess.time, str(o.text), ["runner"], {"kind": str(o.kind), "price": price})
	return ""


# ------------------------------------------------------------------ the week's hot job
static func eligible(j) -> bool:
	return (j.kind in ["cargo", "passenger", "contraband", "medical", "fugitive"] and not j.is_airdrop() and j.checkpoints.is_empty()
		and j.employer_serial <= 0 and not str(j.title).begins_with("Windfall") and j.accepted_at == null)


func _find(id: int):
	for code in sess.boards:
		for j in sess.boards[code]:
			if j.id == id:
				return j
	return null


func _post_hot() -> void:
	if not hot.is_empty():  # last week's, untaken: back to an ordinary job
		var old = _find(int(hot.job_id))
		if old != null:
			old.payout = int(hot.base)
			old.title = str(old.title).trim_prefix(HOT_TAG)
	hot = {}
	var codes: Array = sess.boards.keys().filter(func(c): return World.airfield(str(c)) != null and World.airfield(str(c)).kind != "foreign")
	codes.sort()
	var tries := codes.duplicate()
	while not tries.is_empty():
		var code: String = str(tries.pop_at(rng.randint(0, tries.size() - 1)))
		var best = null
		for j in sess.boards[code]:
			if eligible(j) and (best == null or int(j.payout) > int(best.payout)):
				best = j
		if best == null:
			continue
		hot = {"job_id": int(best.id), "code": code, "base": int(best.payout)}
		best.payout = int(round(float(best.payout) * HOT_PAY))
		best.title = HOT_TAG + str(best.title)
		sess.say("The week's hot job is at %s: %s, $%s." % [World.airfield(code).name, str(best.title).trim_prefix(HOT_TAG),
			Py.money(int(best.payout))])
		return


func _on_delivered(e) -> void:
	if sess == null or hot.is_empty() or not e.data.has("job_id") or int(e.data.job_id) != int(hot.job_id):
		return
	hot = {}
	if sess.renown != null:
		sess.renown.add(HOT_RENOWN, "the week's hot job")
	sess.say("The week's hot job is done: the name gets around.")
	sess.bus.emit("hot_job_done", sess.time, "", ["runner"], {"job_id": int(e.data.job_id)})


# ------------------------------------------------------------------ the phone
## The Week app's black-market part: [text, offer index or -1].
func rows() -> Array:
	if not live():
		return []
	var out := []
	if not hot.is_empty():
		var j = _find(int(hot.job_id))
		var taken: bool = j == null and sess.active_jobs.any(func(x): return x.id == int(hot.job_id))
		if j != null or taken:
			var af := World.airfield(str(hot.code))
			out.append(["The hot job: at %s%s (x%.1f pay, +%d renown)" % [af.name if af != null else str(hot.code), ", taken" if taken else "",
				HOT_PAY, int(HOT_RENOWN)], -1])
	for i in offers.size():
		var o: Dictionary = offers[i]
		out.append([("SOLD  " if bool(o.sold) else "") + str(o.text), -1 if bool(o.sold) else i])
	return out


# ------------------------------------------------------------------ saves
func capture() -> Dictionary:
	return {"week": week, "offers": offers.duplicate(true), "hot": hot.duplicate(), "bought": bought, "rng": rng.get_state()}


func restore(d: Dictionary) -> void:
	week = int(d.get("week", 0))
	offers = []
	for o in d.get("offers", []):
		if o is Dictionary:
			var x: Dictionary = o.duplicate()
			x["price"] = int(x.get("price", 0))
			x["sold"] = bool(x.get("sold", false))
			if x.has("n"):
				x["n"] = int(x.n)
			offers.append(x)
	hot = {}
	var h: Dictionary = d.get("hot", {})
	if not h.is_empty():
		hot = {"job_id": int(h.get("job_id", 0)), "code": str(h.get("code", "")), "base": int(h.get("base", 0))}
	bought = int(d.get("bought", 0))
	if d.get("rng") is Array:
		rng.set_state(d.rng)
