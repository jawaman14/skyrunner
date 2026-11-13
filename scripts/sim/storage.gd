class_name Storage
extends RefCounted
## Storage caps and costs per place (DESIGN section 51 slice 4; DESIGN 87). Each stash house holds so many pounds of product by its
## kind (a warehouse most, a shack little) and costs so much a day to keep, paid at the 06:00 close. The cap is soft: what a truck
## or a load brings over it is never lost but stacked in the yard, and a house over its cap draws heat while it is; the moves the
## boss chooses (a van, a pickup order) are refused when the house has no room, counting what is already on its way there.
##
## The owner left the cap's form open (a count, a weight or floor space you buy: DESIGN 51.8); this takes weight, the unit every
## stock already uses. No random draws. Nothing saved: the caps and the upkeep come from the kinds; heat lives on the stash.
## Behind ENABLED (in the parity set).

static var ENABLED := true

## lb of product (every good together) a house of each kind holds, and $ a day to keep it.
const CAP := {"warehouse": 4000.0, "barn": 2500.0, "villa": 1500.0, "boathouse": 1200.0, "lockup": 1000.0, "shed": 800.0, "camp": 600.0, "shack": 400.0}
const UPKEEP := {"warehouse": 150, "barn": 80, "villa": 120, "boathouse": 60, "lockup": 60, "shed": 40, "camp": 30, "shack": 20}
const DEFAULT_CAP := 1000.0
const DEFAULT_UPKEEP := 50
const YARD_HEAT := 3.0  ## heat an hour a house draws while it is a full cap over (in proportion below that; at most this)

var lg  ## Logistics
var owed := 0  ## upkeep the safe could not pay (paid first at the next close)
var _hour_t := 0.0


func _init(lg_) -> void:
	lg = lg_


static func cap_of(st: Dictionary) -> float:
	return float(CAP.get(str(st.get("kind", "")), DEFAULT_CAP))


static func upkeep_of(st: Dictionary) -> int:
	return int(UPKEEP.get(str(st.get("kind", "")), DEFAULT_UPKEEP))


## Product held at a stash now, every good together.
func held(site: String) -> float:
	var total := 0.0
	for g in lg.stock.get(site, {}):
		total += float(lg.stock[site][g])
	return total


## Product on the road to a stash (vans and rounds bound there).
func incoming(site: String) -> float:
	var total := 0.0
	for id in lg.convoys:
		var c: Dictionary = lg.convoys[id]
		if str(c.get("to", "")) == site and str(c.get("good", "")) not in ["", "cash"]:
			total += float(c.get("lb", 0.0))
	for o in lg.pickups.open_orders():
		if str(o.stash) == site and str(o.good) != "guns":
			total += float(o.lb)
	return total


## Room left at a stash, counting what is on its way; INF for a place that is not a stash (or when off).
func room(site: String) -> float:
	var st = lg.sess.stash_net.get_stash(site) if lg.sess.stash_net != null else null
	if not ENABLED or st == null:
		return INF
	return cap_of(st) - held(site) - incoming(site)


## "" or why `lb` more won't fit at `site`.
func full_reason(site: String, lb: float) -> String:
	var r := room(site)
	if r >= lb - 0.5:
		return ""
	return "%s has room for %d lb more (it holds %d of %d, with what is on its way)." % [lg.name_of(site), int(maxf(0.0, r)),
		int(held(site) + incoming(site)), int(cap_of(lg.sess.stash_net.get_stash(site)))]


## Every hour: a house over its cap draws heat, in proportion to how far over it is.
func update(dt: float) -> void:
	if not ENABLED or lg.sess.stash_net == null:
		return
	_hour_t += dt
	if _hour_t < 3600.0:
		return
	var hours := _hour_t / 3600.0
	_hour_t = 0.0
	for st in lg.sess.stash_net.live():
		var over := held(str(st.id)) - cap_of(st)
		if over > 0.5:
			st.heat = float(st.heat) + YARD_HEAT * hours * minf(1.0, over / cap_of(st))


## The day's upkeep for every live house, from the safe at the close; what it can't pay is owed and paid first next time.
func close() -> void:
	if not ENABLED or lg.sess.stash_net == null:
		return
	var due := owed
	for st in lg.sess.stash_net.live():
		due += upkeep_of(st)
	var pay := mini(due, maxi(0, int(lg.sess.money)))
	if pay > 0:
		lg.sess.move_money(-pay, "outside:landlord", "fee")
	owed = due - pay
	if owed > 0:
		lg.sess.say("The stash houses' upkeep came up $%s short: it is owed." % Py.money(owed))


## For the phone and the logistics screen: "1,200 of 2,500 lb".
func line(site: String) -> String:
	var st = lg.sess.stash_net.get_stash(site) if lg.sess.stash_net != null else null
	if not ENABLED or st == null:
		return ""
	return "%s of %s lb" % [Py.money(int(held(site))), Py.money(int(cap_of(st)))]


func capture() -> Dictionary:
	return {"owed": owed} if owed > 0 else {}


func restore(d: Dictionary) -> void:
	owed = int(d.get("owed", 0))
