class_name Psychedelics
extends RefCounted
## The Sunrise Collective: a commune of chemists in the hills that makes LSD (blotter, by the sheet of a hundred doses) and
## wants grass. Its people run the festival and campus circuit up and down the coast; they have more acid than they can carry
## and no way to buy the marijuana the circuit asks for, so they trade: our grass, from a stash, for their acid. Their chemist is
## Nico Cozz. (Fiction: Nico, the Collective and everything about them are invented, and nothing here says how acid is made;
## the lab is a number that produces sheets.)
##
##   the barter     `barter(stash, lb)`: a Collective van calls at the stash and takes `lb` of grass; we get
##                  lb / 100 x rate() sheets. The rate is SHEETS_PER_100LB, better with trust and with grass dear, worse
##                  with the circuit hungry (acid dear). The lab holds only what it has made (OUTPUT_PER_HOUR, up to
##                  STOCK_CAP) and wants only WEED_APPETITE_LB of grass every REFILL_S. A van at the door warms the stash.
##   the circuit    `sell(sheets)`: the sheets go out through the Collective's network at STREET_SHEET x CIRCUIT_SHARE x the
##                  scene (a festival, a campus crackdown), up to CIRCUIT_CAP an interval. It is soft money: little heat.
##   the lab        raided now and then (the odds climb with the task force's case against us): it goes to ground for HIDE_S,
##                  its stock is gone, trust falls. Nico comes back; he always does.
##   the AI         `auto` barters the fullest stash's grass whenever it has 200 lb to spare and sells what it holds.
##
## One grass-for-acid trade at 2.4 sheets a hundredweight pays about a third more than selling the grass to the Family; acid
## weighs nothing, so it flies in a pocket. Own stream (seed + 953). Behind ENABLED; the story opens it with 1980's chapter.

static var ENABLED := true

const NAME := "the Sunrise Collective"
const CHEMIST := "Nico Cozz"
const STREET_SHEET := 325.0  ## what a sheet fetches on the street, before the scene
const CIRCUIT_SHARE := 0.8  ## what the Collective's network pays us of that
const SHEETS_PER_100LB := 2.4
const TRUST_BONUS := 0.25  ## up to this much better at full trust
const WEED_APPETITE_LB := 400.0
const CIRCUIT_CAP := 40.0  ## sheets an interval
const REFILL_S := 1800.0
const OUTPUT_PER_HOUR := 30.0
const STOCK_CAP := 90.0
const MIN_LB := 20.0
const STASH_HEAT_PER_100LB := 0.4
const SUSPICION_PER_SHEET := 0.12
const RAID_BASE := 0.012  ## a ten-minute chance
const HIDE_S := 10800.0
const AUTO_EVERY_S := 1800.0
const AUTO_KEEP_LB := 200.0  ## the AI leaves this much grass in the stash for the Family
## [name, scene multiplier, seconds, headline]
const SCENE := [
	["festival", 1.35, 5400.0, "A festival up the coast: the circuit is hungry and the sheets fetch more"],
	["crackdown", 0.7, 3600.0, "Narcs on the campuses: the circuit has gone quiet"],
	["heatwave", 1.15, 2700.0, "A heatwave and a dozen outdoor concerts: the circuit is busy"],
	["bad_batch", 0.8, 3600.0, "A bad batch on the street, not ours: the buyers are wary of blotter"],
]

var sess
var rng: PyRandom
var stock := 30.0  ## sheets at the lab, ready to trade
var held := 0.0  ## our sheets
var trust := 30.0  ## 0..100
var status := "open"  ## open | hiding
var hide_until := -1.0
var weed_left := WEED_APPETITE_LB
var circuit_left := CIRCUIT_CAP
var scene := 1.0  ## the circuit's mood: a multiplier on the sheet
var scene_name := ""
var scene_until := -1.0
var bartered := 0.0  ## lb of grass given
var sold := 0.0  ## sheets sold
var earned := 0
var raids := 0
var auto := false
var last := ""
var _t := 0.0
var _evt_t := 0.0
var _raid_t := 0.0
var _auto_t := 0.0


func _init(s) -> void:
	sess = s
	rng = PyRandom.new()
	rng.seed(int(s.seed) + 953)


func active() -> bool:
	return ENABLED and sess != null and sess.trade != null


## Why not, now ("" = open for business).
func why_not() -> String:
	if not active():
		return "There is no Collective in this game."
	if status == "hiding":
		return "%s has gone to ground: the lab was raided. Try again in %d minutes." % [CHEMIST, int(ceil((hide_until - sess.time) / 60.0))]
	return ""


## Sheets for a hundred pounds of grass now: better with trust and a dear market, worse with the circuit hungry.
func rate() -> float:
	var weed_mult := 1.0
	if sess.econ != null:
		weed_mult = float(sess.econ.mult("marijuana", "town"))
	var r := SHEETS_PER_100LB * (1.0 + TRUST_BONUS * trust / 100.0) * weed_mult / scene
	return clampf(r, SHEETS_PER_100LB * 0.6, SHEETS_PER_100LB * 1.6)


## What a sheet fetches from the circuit now.
func price() -> float:
	return STREET_SHEET * scene * CIRCUIT_SHARE


func _grass_at(stash: String) -> float:
	if sess.logistics != null:
		return float(sess.logistics.stock.get(stash, {}).get("marijuana", 0.0))
	return float(sess.trade.stock["marijuana"])


func _take_grass(stash: String, lb: float) -> void:
	if sess.logistics != null:
		sess.logistics.stock[stash]["marijuana"] -= lb
		sess.logistics.sync()
	else:
		sess.trade.stock["marijuana"] -= lb


func barter(stash: String, lb: float) -> String:
	var err := why_not()
	if err != "":
		return err
	var st = sess.stash_net.get_stash(stash) if sess.stash_net != null else null
	if sess.logistics != null and (st == null or st.burned):
		return "No such stash."
	var have := _grass_at(stash)
	if have < MIN_LB:
		return "There is no grass at that stash."
	lb = minf(lb, minf(have, weed_left))
	var r := rate()
	if lb / 100.0 * r > stock:
		lb = stock / r * 100.0
	if lb < MIN_LB:
		if weed_left < MIN_LB:
			return "%s has all the grass the circuit can use for now." % NAME.capitalize()
		return "%s has no acid ready: the next batch is a few hours off." % CHEMIST
	var sheets := lb / 100.0 * r
	_take_grass(stash, lb)
	stock -= sheets
	held += sheets
	weed_left -= lb
	bartered += lb
	trust = minf(100.0, trust + 0.6 * lb / 100.0)
	if st != null:
		st.heat += STASH_HEAT_PER_100LB * lb / 100.0
	last = "Traded %d lb of grass for %.1f sheets with %s." % [int(lb), sheets, CHEMIST]
	sess.say(last)
	sess.bus.emit("acid_barter", sess.time, last, ["runner"], {"lb": lb, "sheets": sheets})
	return ""


func sell(sheets: float) -> String:
	var err := why_not()
	if err != "":
		return err
	var n := minf(sheets, minf(held, circuit_left))
	if held <= 0.0:
		return "We have no acid to sell."
	if n < 0.5:
		return "The circuit has had enough for now."
	var pay := int(price() * n)
	sess.money += pay
	held -= n
	circuit_left -= n
	sold += n
	earned += pay
	var c = sess.police.case("runner")
	c.suspicion = minf(100.0, c.suspicion + SUSPICION_PER_SHEET * n)
	last = "Sold %.1f sheets through the circuit: +$%s." % [n, Py.money(pay)]
	sess.say(last)
	sess.bus.emit("acid_sold", sess.time, last, ["runner"], {"sheets": n, "pay": pay})
	return ""


func set_auto(on: bool) -> String:
	if not active():
		return "There is no Collective in this game."
	auto = on
	return ""


func update(dt: float) -> void:
	if not active():
		return
	if status == "hiding":
		if sess.time >= hide_until:
			status = "open"
			stock = 20.0
			sess.say("%s is back at the lab. The Collective is trading again." % CHEMIST)
	else:
		stock = minf(STOCK_CAP, stock + OUTPUT_PER_HOUR * dt / 3600.0)
	weed_left = minf(WEED_APPETITE_LB, weed_left + WEED_APPETITE_LB * dt / REFILL_S)
	circuit_left = minf(CIRCUIT_CAP, circuit_left + CIRCUIT_CAP * dt / REFILL_S)
	if scene_until >= 0.0 and sess.time >= scene_until:
		scene = 1.0
		scene_name = ""
		scene_until = -1.0
	_evt_t += dt
	if _evt_t >= 600.0:
		_evt_t = 0.0
		if scene_until < 0.0 and rng.random() < 0.12:
			var ev: Array = SCENE[rng.randint(0, SCENE.size() - 1)]
			scene = float(ev[1])
			scene_name = str(ev[0])
			scene_until = sess.time + float(ev[2])
			sess.say(str(ev[3]))
	_raid_t += dt
	if _raid_t >= 600.0:
		_raid_t = 0.0
		if status == "open":
			var suspicion: float = float(sess.police.case("runner").suspicion)
			if rng.random() < RAID_BASE + 0.04 * suspicion / 100.0:
				_raid()
	if auto:
		_auto_t += dt
		if _auto_t >= AUTO_EVERY_S:
			_auto_t = 0.0
			_auto()


func _raid() -> void:
	status = "hiding"
	hide_until = sess.time + HIDE_S
	stock = 0.0
	trust = maxf(0.0, trust - 15.0)
	raids += 1
	sess.say("%s's lab in the hills was raided: %s has gone to ground for a few hours." % [NAME.capitalize(), CHEMIST])
	sess.law_say("The task force took the Sunrise Collective's lab in the hills: a chemist is missing")


func _auto() -> void:
	if why_not() != "":
		return
	if sess.logistics != null:
		var best := ""
		var most := 0.0
		for id in sess.logistics.stock:
			var g: float = float(sess.logistics.stock[id].get("marijuana", 0.0))
			if g > most and id != Logistics.HQ:
				most = g
				best = id
		if best != "" and most > AUTO_KEEP_LB + MIN_LB:
			barter(best, most - AUTO_KEEP_LB)
	if held >= 5.0:
		sell(held)


func view(_side := "runner") -> Dictionary:
	return {"name": NAME, "chemist": CHEMIST, "status": status, "stock": snappedf(stock, 0.1), "held": snappedf(held, 0.1), "trust": int(trust),
		"rate": snappedf(rate(), 0.01), "price": int(price()), "weed_left": int(weed_left), "circuit_left": snappedf(circuit_left, 0.1),
		"hide_min": maxi(0, int(ceil((hide_until - sess.time) / 60.0))) if status == "hiding" else 0, "scene": scene_name,
		"auto": auto, "bartered": int(bartered), "sold": snappedf(sold, 0.1), "earned": earned, "raids": raids, "last": last,
		"stashes": _stash_grass()}


## The stashes with grass in them: [{id, name, lb}], fullest first (what a barter can draw on).
func _stash_grass() -> Array:
	var out := []
	if sess.logistics != null and sess.stash_net != null:
		for st in sess.stash_net.live():
			var lb: float = float(sess.logistics.stock.get(st.id, {}).get("marijuana", 0.0))
			if lb >= MIN_LB:
				out.append({"id": st.id, "name": st.name, "lb": int(lb)})
		out.sort_custom(func(a, b): return a.lb > b.lb)
	elif sess.trade != null:
		out.append({"id": "", "name": "the stock", "lb": int(sess.trade.stock["marijuana"])})
	return out
