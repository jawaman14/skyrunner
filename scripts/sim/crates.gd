class_name Crates
extends RefCounted
## Weapon crates and the scarcity ladder (D-61 stage 1; docs/DESIGN.md sections 50 and 77).
##
## A weapon travels in a crate of one type, with its own count and weight, and each type has its own supply on the island: what the
## dealers and fences hold between them (`street`, in weapons). The base supplies make the powerful rare (pistols 1.0, rifles 0.55,
## machine guns 0.18, RPGs 0.08 of STREET), so a machine-gun crate is an event and a pistol crate is stock.
##
## What follows the ladder:
##   - a gun run is one to three crates, each of one type drawn in proportion to what is on the street now;
##   - a type's price moves with (normal / street) ^ ELASTICITY at the dealer, the fence and the bulk buyers;
##   - the dealer can sell only what the street holds (`available`), and what he sells leaves it;
##   - what we sell the fence, and a gun run sold on delivery, goes onto the street; a seizure sends the dealers to ground.
## The street drifts back to its normal level in about two game hours.
##
## Draws only when a gun run is dealt, on its own stream (seed + 193; the island boards' gun runs on seed + 195, so a visit and a
## remote deal agree). Saved. Behind ENABLED (in the parity set): off, gun runs, prices and the dealer are as they were.

static var ENABLED := true

const SPEC := {
	"pistol": {"name": "Pistol crate", "holds": 12, "kg": 18.0},
	"rifle": {"name": "Rifle crate", "holds": 8, "kg": 40.0},
	"mg": {"name": "Machine-gun crate", "holds": 2, "kg": 60.0},
	"rpg": {"name": "RPG crate", "holds": 2, "kg": 35.0},
}
const LADDER := {"pistol": 1.0, "rifle": 0.55, "mg": 0.18, "rpg": 0.08}
const STREET := 60.0  ## weapons on the street at a supply of 1.0
const RESTOCK_TAU := 7200.0
const ELASTICITY := 0.5
const PRICE_MIN := 0.7
const PRICE_MAX := 2.5
const SECOND_CRATE := 0.35  ## a run's chance of a second crate, and (THIRD_CRATE) of a third after it
const THIRD_CRATE := 0.2
const SEIZED_SHARE := 0.5  ## of a seizure's count, how much the dealers pull off the street

var rng: PyRandom
var board_rng: PyRandom
var street := {}  ## tier -> weapons the dealers and fences hold
var _dealing_boards := false


func _init(rng_: PyRandom, board_rng_: PyRandom) -> void:
	rng = rng_
	board_rng = board_rng_
	for t in SPEC:
		street[t] = normal(t)


static func normal(tier: String) -> float:
	return STREET * float(LADDER.get(tier, 0.0))


## A type's price against its normal one: dear when the street is short of it.
func factor(tier: String) -> float:
	if not street.has(tier):
		return 1.0
	var n := normal(tier)
	return clampf(pow(n / maxf(0.15 * n, float(street[tier])), ELASTICITY), PRICE_MIN, PRICE_MAX)


## How many of a type the dealer can sell now.
func available(tier: String) -> int:
	return int(floor(float(street.get(tier, 0.0)) + 1e-6))


## Weapons leave the street (bought) or reach it (sold to the fence, a run sold on delivery).
func flow(tier: String, n: float) -> void:
	if street.has(tier):
		street[tier] = clampf(float(street[tier]) + n, 0.0, 3.0 * normal(tier))


func flow_all(weapons: Dictionary, sign_ := 1.0) -> void:
	for t in weapons:
		flow(t, sign_ * float(weapons[t]))


func seized(weapons: Dictionary) -> void:
	flow_all(weapons, -SEIZED_SHARE)


func update(dt: float) -> void:
	var k := 1.0 - exp(-dt / RESTOCK_TAU)
	for t in street:
		street[t] = float(street[t]) + (normal(t) - float(street[t])) * k


## The island boards are dealt on their own stream (Session.stock_island_boards).
func dealing_boards(on: bool) -> void:
	_dealing_boards = on


## A gun run's crates off the ladder: [tier, ...], one entry a crate.
func deal() -> Array:
	var r: PyRandom = board_rng if _dealing_boards else rng
	var n := 1
	if r.random() < SECOND_CRATE:
		n += 1
		if r.random() < THIRD_CRATE:
			n += 1
	var out := []
	for i in n:
		out.append(_draw(r))
	return out


func _draw(r: PyRandom) -> String:
	var total := 0.0
	for t in Arsenal.ORDER:
		total += float(street[t])
	if total <= 0.0:
		return "pistol"
	var x := r.random() * total
	for t in Arsenal.ORDER:
		x -= float(street[t])
		if x < 0.0:
			return t
	return "pistol"


## The weapons in a list of crates: {tier: count}.
static func contents(crates: Array) -> Dictionary:
	var w := {}
	for t in crates:
		w[t] = int(w.get(t, 0)) + int(SPEC[t].holds)
	return w


## The crates a load of weapons travels in: {tier: crates}, a part crate counted whole.
static func crates_for(weapons: Dictionary) -> Dictionary:
	var out := {}
	for t in weapons:
		if SPEC.has(t) and int(weapons[t]) > 0:
			out[t] = int(ceil(float(weapons[t]) / float(SPEC[t].holds)))
	return out


## What a load of weapons weighs crated, kg.
static func weight(weapons: Dictionary) -> float:
	var kg := 0.0
	var c := crates_for(weapons)
	for t in c:
		kg += int(c[t]) * float(SPEC[t].kg)
	return kg


static func describe(crates: Array) -> String:
	var n := {}
	for t in crates:
		n[t] = int(n.get(t, 0)) + 1
	var parts := []
	for t in Arsenal.ORDER:
		if n.has(t):
			parts.append("%d %s%s" % [int(n[t]), str(SPEC[t].name).to_lower(), "s" if int(n[t]) > 1 else ""])
	return ", ".join(parts) if not parts.is_empty() else "nothing"


## Street worth of weapons at the ladder's prices (before the guns market's multiplier).
func worth(weapons: Dictionary) -> float:
	var v := 0.0
	for t in weapons:
		if Arsenal.TIERS.has(t):
			v += int(weapons[t]) * float(Arsenal.TIERS[t].price) * factor(t)
	return v


## For the desks: each type with what is on the street, its normal level and its price factor.
func view() -> Array:
	var out := []
	for t in Arsenal.ORDER:
		out.append({"tier": t, "name": Arsenal.TIERS[t].name, "street": available(t), "normal": int(round(normal(t))),
			"factor": snappedf(factor(t), 0.01), "holds": int(SPEC[t].holds), "kg": float(SPEC[t].kg)})
	return out


func capture() -> Dictionary:
	return {"street": street.duplicate()}


func restore(d: Dictionary) -> void:
	var s: Dictionary = d.get("street", {}) if d.get("street") is Dictionary else {}
	for t in SPEC:
		street[t] = clampf(float(s.get(t, normal(t))), 0.0, 3.0 * normal(t))
