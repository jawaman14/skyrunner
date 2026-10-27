class_name Inventory
extends RefCounted
## Goods as lots in locations (docs/EMPIRE_SIMULATION_SPEC.md section 4), the stock twin of Ledger. F-4 starts here: a pure model with the
## invariants and no call site yet; later slices wrap the stash stock and the aircraft load, then move each site to `move`.
## Locations are strings: "org:stash-docks", "aircraft:N123", "truck-7"; "outside:*" is where goods come from and go (growers, state, street).

const OUTSIDE := "outside:"

var lots := {}  ## id -> {id, good, lb, origin, quality, heat, born, at}
var log: Array = []  ## {id, t, lot, good, lb, from, to, reason, actor}
var _serial := 0


## A new lot arrives at `at` from outside:`source` (growers, market, ...). Returns its id, or 0 when refused.
func add(good: String, lb: float, at: String, source := "growers", origin := "", quality := 0.5, heat := 0.0, t := 0.0) -> int:
	if lb <= 0.0 or good == "" or at == "" or at.begins_with(OUTSIDE):
		return 0
	var lot := _new_lot(good, lb, at, origin, quality, heat, t)
	_log(lot, lb, OUTSIDE + source, at, "arrive", "system", t)
	return int(lot.id)


## Move `lb` of a lot (all of it when lb <= 0) to `to`. A part splits the lot and the part gets a new id. Returns the id of the lot now at
## `to`, or 0 when refused (unknown lot, more than it holds, already there). Moving to outside:* is a loss: seizure, sale or consumption.
func move(lot_id: int, lb: float, to: String, reason: String, actor := "system", t := 0.0) -> int:
	if not lots.has(lot_id) or to == "" or reason == "":
		return 0
	var lot: Dictionary = lots[lot_id]
	var amount: float = lb if lb > 0.0 else float(lot.lb)
	if amount > float(lot.lb) + 0.0001 or to == lot.at:
		return 0
	var from: String = lot.at
	if amount >= float(lot.lb) - 0.0001:
		lot.at = to
		_log(lot, float(lot.lb), from, to, reason, actor, t)
		return lot_id
	lot.lb = float(lot.lb) - amount
	var part := _new_lot(str(lot.good), amount, to, str(lot.origin), float(lot.quality), float(lot.heat), float(lot.born))
	_log(part, amount, from, to, reason, actor, t)
	return int(part.id)


## Move up to `lb` pounds of `good` from `from` to `to`, oldest lots first. Returns the pounds moved (less than `lb` when `from` holds less).
func transfer(from: String, to: String, good: String, lb: float, reason: String, actor := "system", t := 0.0) -> float:
	var ids := []
	for id in lots:
		if lots[id].at == from and lots[id].good == good:
			ids.append(id)
	ids.sort()
	var moved := 0.0
	for id in ids:
		if lb - moved <= 0.0001:
			break
		var take := minf(lb - moved, float(lots[id].lb))
		if move(id, take, to, reason, actor, t) != 0:
			moved += take
	return moved


## The F-4 wrap: make `at` hold `value` pounds of `good` for a change the old code made directly. A shortfall arrives from
## outside:unattributed and an excess leaves to it (oldest lots first), so the unattributed flow is the to-do list for the later slices.
func reconcile(at: String, good: String, value: float, t := 0.0) -> void:
	if at == "" or at.begins_with(OUTSIDE):
		return
	var diff := value - stock(at, good)
	if diff > 0.0001:
		add(good, diff, at, "unattributed", "", 0.5, 0.0, t)
	elif diff < -0.0001:
		var owed := -diff
		var ids := []
		for id in lots:
			if lots[id].at == at and lots[id].good == good:
				ids.append(id)
		ids.sort()
		for id in ids:
			if owed <= 0.0001:
				break
			var take := minf(owed, float(lots[id].lb))
			move(id, take, OUTSIDE + "unattributed", "adjust", "system", t)
			owed -= take


## Pounds of `good` held at a location (outside:* counts too, as the loss account).
func stock(at: String, good: String) -> float:
	var sum := 0.0
	for id in lots:
		if lots[id].at == at and lots[id].good == good:
			sum += float(lots[id].lb)
	return sum


## Everything of `good` inside the map (not outside:*).
func held(good: String) -> float:
	var sum := 0.0
	for id in lots:
		if lots[id].good == good and not str(lots[id].at).begins_with(OUTSIDE):
			sum += float(lots[id].lb)
	return sum


## Goods that came in across the boundary minus goods that left it: what `held` must equal (conservation per good).
func net_inflow(good: String) -> float:
	var sum := 0.0
	for row in log:
		if row.good != good:
			continue
		if str(row.from).begins_with(OUTSIDE):
			sum += float(row.lb)
		if str(row.to).begins_with(OUTSIDE):
			sum -= float(row.lb)
	return sum


## Invariant breaches: a lot with no pounds, or no location. (One location per lot holds by construction: `at` is a single field.)
func violations() -> Array:
	var bad := []
	for id in lots:
		if float(lots[id].lb) <= 0.0 or str(lots[id].at) == "":
			bad.append(id)
	return bad


func _new_lot(good: String, lb: float, at: String, origin: String, quality: float, heat: float, born: float) -> Dictionary:
	_serial += 1
	var lot := {"id": _serial, "good": good, "lb": lb, "origin": origin, "quality": quality, "heat": heat, "born": born, "at": at}
	lots[_serial] = lot
	return lot


func _log(lot: Dictionary, lb: float, from: String, to: String, reason: String, actor: String, t: float) -> void:
	log.append({"id": log.size() + 1, "t": t, "lot": lot.id, "good": lot.good, "lb": lb, "from": from, "to": to, "reason": reason, "actor": actor})
