class_name Wear
extends RefCounted
## Weapons and vehicles wear with use (owner, 10 November 2026, D-97; docs/DESIGN.md section 82), as the aircraft already does
## (Airframe). Two conditions, 100 new and 0 worn out, each with a cost to put right:
##
##   arms    the organisation's armoury. Every round of a firefight one of our squads fights takes ARMS_ROUND off it, and every
##           shot the pilot fires on foot ARMS_SHOT. Our squads' fire falls with it, to ARMS_FLOOR of full at nothing (stoppages,
##           worn barrels). The armourer cleans and re-barrels the lot for ARMS_COST a point, plus a tenth of that a weapon.
##   fleet   the trucks we own (the dealership's haulers; hired vans are the hirer's problem). Every kilometre a stash truck drives
##           takes TRUCK_KM off it. The trucks slow with it, to TRUCK_FLOOR of their speed at nothing. The dealership's shop puts
##           them right for TRUCK_COST a point a truck.
##
## A line is said as each passes 75, 50 and 25. Nothing breaks outright: like the airframe it gets worse in steps, and the price of
## ignoring it is firepower and time.
##
## No random draws. Saved. Behind ENABLED (in the parity set): off, nothing wears and nothing is slowed.

static var ENABLED := true

const ARMS_ROUND := 0.4
const ARMS_SHOT := 0.05
const ARMS_FLOOR := 0.75
const ARMS_COST := 8.0
const TRUCK_KM := 0.25
const TRUCK_FLOOR := 0.75
const TRUCK_COST := 12.0
const BANDS := [75.0, 50.0, 25.0]
const KINDS := ["arms", "fleet"]

var sess
var arms := 100.0
var fleet := 100.0


func _init(sess_) -> void:
	sess = sess_


static func band_of(v: float) -> String:
	if v >= 75.0:
		return "good"
	if v >= 50.0:
		return "worn"
	if v >= 25.0:
		return "poor"
	return "worn out"


func _drop(kind: String, pts: float) -> void:
	if not ENABLED or pts <= 0.0:
		return
	var was: float = arms if kind == "arms" else fleet
	var now := maxf(0.0, was - pts)
	if kind == "arms":
		arms = now
	else:
		fleet = now
	for b in BANDS:
		if was >= b and now < b:
			sess.say("The %s: %s (%d%%). %s" % ["armoury is showing its use" if kind == "arms" else "trucks are showing their miles", band_of(now), int(round(now)),
				"The armourer can put it right." if kind == "arms" else "The dealership's shop can put them right."])
	if kind == "fleet" and sess.dealer != null:
		sess.dealer.apply()  # the trucks' speed follows their condition


## One of our squads fought a round of a firefight.
func fought() -> void:
	_drop("arms", ARMS_ROUND)


## The pilot fired a shot on foot.
func shot() -> void:
	_drop("arms", ARMS_SHOT)


## A truck of ours drove `km`. Only owned trucks wear.
func hauled(km: float) -> void:
	if sess.dealer != null and not sess.dealer.haulers().is_empty():
		_drop("fleet", TRUCK_KM * km)


## What our squads' fire is worth against a clean armoury.
func arms_mult() -> float:
	return 1.0 if not ENABLED else ARMS_FLOOR + (1.0 - ARMS_FLOOR) * arms / 100.0


## What the trucks' speed is worth against new ones.
func fleet_mult() -> float:
	return 1.0 if not ENABLED else TRUCK_FLOOR + (1.0 - TRUCK_FLOOR) * fleet / 100.0


## What putting `kind` right costs now.
func cost(kind: String) -> int:
	if kind == "arms":
		var n: int = sess.arsenals["org"].count() if sess.arsenals.has("org") else 0
		return int(ceil((100.0 - arms) * ARMS_COST * (1.0 + 0.1 * n)))
	var trucks: int = sess.dealer.haulers().size() if sess.dealer != null else 0
	return int(ceil((100.0 - fleet) * TRUCK_COST * trucks))


## Put `kind` ("arms" or "fleet") right, paid from the safe. "" or why not.
func service(kind: String) -> String:
	if not ENABLED:
		return "Nothing wears in this game."
	if not kind in KINDS:
		return "Service the arms or the fleet."
	if kind == "arms" and not sess.arsenals.has("org"):
		return "No armoury."
	if kind == "fleet" and (sess.dealer == null or sess.dealer.haulers().is_empty()):
		return "We own no trucks."
	var v: float = arms if kind == "arms" else fleet
	if v >= 99.5:
		return "Nothing to put right."
	var c := cost(kind)
	if sess.money < c:
		return "Need $%s." % Py.money(c)
	sess.move_money(-c, "outside:market", "repair")
	if kind == "arms":
		arms = 100.0
	else:
		fleet = 100.0
		sess.dealer.apply()
	sess.say("%s: $%s." % ["The armourer has been through the armoury" if kind == "arms" else "The shop has been through the trucks", Py.money(c)])
	return ""


## For the phone: each condition that applies, with its band, its effect and what it costs to put right.
func view() -> Array:
	var out := []
	if sess.arsenals.has("org"):
		out.append({"kind": "arms", "name": "Armoury", "condition": int(round(arms)), "band": band_of(arms), "effect": int(round(arms_mult() * 100.0)),
			"what": "our squads' fire", "cost": cost("arms")})
	if sess.dealer != null and not sess.dealer.haulers().is_empty():
		out.append({"kind": "fleet", "name": "Trucks", "condition": int(round(fleet)), "band": band_of(fleet), "effect": int(round(fleet_mult() * 100.0)),
			"what": "their speed", "cost": cost("fleet")})
	return out


func capture() -> Dictionary:
	return {"arms": arms, "fleet": fleet}


func restore(d: Dictionary) -> void:
	arms = clampf(float(d.get("arms", 100.0)), 0.0, 100.0)
	fleet = clampf(float(d.get("fleet", 100.0)), 0.0, 100.0)
