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
##   the circuit    `sell(sheets, stash)`: the Collective's network collects the sheets at the stash's door and leaves the street money in
##                  it (a truck takes it home), at STREET_SHEET x CIRCUIT_SHARE x mood() (the scene, a price walk, the scarcity after a raid),
##                  up to CIRCUIT_CAP an interval. With logistics the sheets are stash stock like grass: Logistics moves them by truck
##                  (the `acid` good, in sheets), a raid on the stash takes them, and they are worth `price()` a sheet.
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
const WALK_VOL := 0.04  ## the price walk's size per square-root minute
const WALK_REVERT_S := 1800.0
const RAID_SCARCITY := 0.3  ## what a raid adds to the price of a sheet, easing off over SCARCITY_TAU_S
const SCARCITY_TAU_S := 7200.0
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
var held := 0.0  ## our sheets when the game has no logistics (with it they sit in the stashes: acid_at, held_total)
var walk := 1.0  ## the street's price index for blotter (a mean-reverting walk, own stream)
var scarcity := 0.0  ## a raid dries up the supply: the sheets are dear for hours
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
var _walk_t := 0.0


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


## What the street thinks of a sheet now: the scene (a festival, a crackdown), the walk, and the scarcity after a raid.
func mood() -> float:
	return scene * walk * (1.0 + scarcity)


## Sheets for a hundred pounds of grass now: better with trust and a dear market, worse with the circuit hungry.
func rate() -> float:
	var weed_mult := 1.0
	if sess.econ != null:
		weed_mult = float(sess.econ.mult("marijuana", "town"))
	var r := SHEETS_PER_100LB * (1.0 + TRUST_BONUS * trust / 100.0) * weed_mult / mood()
	return clampf(r, SHEETS_PER_100LB * 0.6, SHEETS_PER_100LB * 1.6)


## What a sheet fetches from the circuit now.
func price() -> float:
	return STREET_SHEET * mood() * CIRCUIT_SHARE


## The sheets in a stash (the pool, with no logistics).
func acid_at(stash: String) -> float:
	if sess.logistics != null:
		return float(sess.logistics.stock.get(stash, {}).get("acid", 0.0))
	return held


## All our sheets: in the stashes, on the road (not counted: a truck's load is its own), or the pool.
func held_total() -> float:
	if sess.logistics == null:
		return held
	var n := 0.0
	for id in sess.logistics.stock:
		n += float(sess.logistics.stock[id].get("acid", 0.0))
	return n


## The stash with the most sheets: [id, sheets] ("" if none).
func fullest_stash() -> Array:
	var best := ""
	var most := 0.0
	if sess.logistics != null:
		for id in sess.logistics.stock:
			var n: float = float(sess.logistics.stock[id].get("acid", 0.0))
			if n > most and id != Logistics.HQ:
				most = n
				best = id
	return [best, most]


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
	if sess.logistics != null:
		sess.logistics.stock[stash]["acid"] = float(sess.logistics.stock[stash].get("acid", 0.0)) + sheets  # the van leaves the sheets at the stash
	else:
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


## Sell `sheets` through the circuit from `stash` (the fullest one if none is named): the Collective's people collect at the door and
## leave the street money in that stash (it has to be trucked home like any other).
func sell(sheets: float, stash := "") -> String:
	var err := why_not()
	if err != "":
		return err
	if sess.logistics != null and stash == "":
		stash = str(fullest_stash()[0])
	var have := acid_at(stash)
	if have <= 0.0:
		return "We have no acid to sell." if stash == "" or sess.logistics == null else "There is no acid at %s." % sess.logistics.name_of(stash)
	var n := minf(sheets, minf(have, circuit_left))
	if n < 0.5:
		return "The circuit has had enough for now."
	var pay := int(price() * n)
	if sess.logistics != null:
		sess.logistics.stock[stash]["acid"] -= n
		sess.logistics.cash[stash] += pay
		var st = sess.stash_net.get_stash(stash)
		if st != null:
			st.heat += STASH_HEAT_PER_100LB * n / 4.0  # collectors at the door
	else:
		sess.money += pay
		held -= n
	circuit_left -= n
	sold += n
	earned += pay
	var c = sess.police.case("runner")
	c.suspicion = minf(100.0, c.suspicion + SUSPICION_PER_SHEET * n)
	last = ("Sold %.1f sheets through the circuit: $%s left at %s." % [n, Py.money(pay), sess.logistics.name_of(stash)]) if sess.logistics != null else "Sold %.1f sheets through the circuit: +$%s." % [n, Py.money(pay)]
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
	scarcity = maxf(0.0, scarcity * exp(-dt / SCARCITY_TAU_S))
	_walk_t += dt
	if _walk_t >= 10.0:  # the street's price: Ornstein-Uhlenbeck about 1
		var step := _walk_t
		_walk_t = 0.0
		walk = 1.0 + (walk - 1.0) * exp(-step / WALK_REVERT_S) + rng.gauss(0.0, WALK_VOL * sqrt(step / 60.0))
		walk = clampf(walk, 0.6, 1.6)
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
	scarcity = RAID_SCARCITY  # the supply is cut: the sheets on the street are dear
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
	if sess.logistics != null:
		var f := fullest_stash()
		if float(f[1]) >= 5.0:
			sell(float(f[1]), str(f[0]))
	elif held >= 5.0:
		sell(held)


func view(_side := "runner") -> Dictionary:
	return {"name": NAME, "chemist": CHEMIST, "status": status, "stock": snappedf(stock, 0.1), "held": snappedf(held_total(), 0.1), "mood": snappedf(mood(), 0.01), "trust": int(trust),
		"rate": snappedf(rate(), 0.01), "price": int(price()), "weed_left": int(weed_left), "circuit_left": snappedf(circuit_left, 0.1),
		"hide_min": maxi(0, int(ceil((hide_until - sess.time) / 60.0))) if status == "hiding" else 0, "scene": scene_name,
		"auto": auto, "bartered": int(bartered), "sold": snappedf(sold, 0.1), "earned": earned, "raids": raids, "last": last,
		"stashes": _stash_grass(), "acid_stashes": _stash_acid()}


## The stashes with sheets in them: [{id, name, sheets}], fullest first.
func _stash_acid() -> Array:
	var out := []
	if sess.logistics != null and sess.stash_net != null:
		for st in sess.stash_net.live():
			var n: float = float(sess.logistics.stock.get(st.id, {}).get("acid", 0.0))
			if n >= 0.5:
				out.append({"id": st.id, "name": st.name, "sheets": snappedf(n, 0.1)})
		out.sort_custom(func(a, b): return a.sheets > b.sheets)
	return out


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
