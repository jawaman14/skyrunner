class_name Investments
extends RefCounted
## Investments with a return (loop idea 7, docs/LOOP_IDEAS.md; docs/DESIGN.md section 79): Mount & Blade's village improvements, for
## the empire. Each costs money once and an upkeep every hour, and gives something you can see:
##
##   depot      a fuel depot at a shady or bush strip: avgas there at DEPOT_PRICE of the pump, any amount (a shady strip otherwise
##              has only what you flew in, and a farmer's drums cost double) - a shorter run, with no fuel leg in it
##   strip      a crew that grades and keeps one rough strip: rolling on it no longer wears the airframe
##   safehouse  a quiet place for the organisation's people: the task force's suspicion of us cools SAFEHOUSE_COOL faster
##   informant  a clerk at the task force: the countdown to every raid on a stash, as a posted lookout gives for his own house,
##              and word when a warrant is signed
##
## One depot and one strip crew a strip; one safehouse and one informant. Upkeep is taken on the hour from the safe; an hour we
## cannot pay, that investment lapses (the depot is drained, the crew walks, the clerk stops calling) and must be bought again.
## Selling one back returns nothing: it can only be closed.
##
## No random draws. Saved. Behind ENABLED (in the parity set): off, nothing can be bought and nothing held has an effect.

static var ENABLED := true

const KINDS := {
	"depot": {"name": "Fuel depot", "cost": 3500, "upkeep": 40, "at": ["shady", "bush"],
		"blurb": "avgas there at 1.2x the pump, any amount"},
	"strip": {"name": "Strip crew", "cost": 4500, "upkeep": 50, "at": ["shady", "bush"],
		"blurb": "a graded strip: rolling on it no longer wears the airframe"},
	"safehouse": {"name": "Safehouse", "cost": 4000, "upkeep": 60, "at": [],
		"blurb": "the task force's suspicion of us cools 30% faster"},
	"informant": {"name": "Informant", "cost": 2500, "upkeep": 90, "at": [],
		"blurb": "the countdown to every stash raid, and word when a warrant is signed"},
}
const ORDER := ["depot", "strip", "safehouse", "informant"]
const UPKEEP_S := 3600.0
const DEPOT_PRICE := 1.2  ## of the pump price
const SAFEHOUSE_COOL := 1.3

var sess
var held: Array = []  ## {kind, at ("" for the island-wide ones), since, paid}
var _t := 0.0
var _warrants := {}  ## stash id -> true: warrants the informant has already told us about


func _init(sess_) -> void:
	sess = sess_


func has(kind: String, at := "") -> bool:
	if not ENABLED:
		return false
	for h in held:
		if h.kind == kind and (str(h.at) == at or KINDS[kind].at.is_empty()):
			return true
	return false


## Why `kind` cannot be bought at `at`, or "".
func why_not(kind: String, at := "") -> String:
	if not ENABLED:
		return "Nothing to invest in."
	if not KINDS.has(kind):
		return "Invest in a depot, a strip crew, a safehouse or an informant."
	var k: Dictionary = KINDS[kind]
	if not k.at.is_empty():
		var af = World.airfield(at) if at != "" else null
		if af == null or not af.kind in k.at:
			return "A %s goes at a bush or back-country strip." % str(k.name).to_lower()
		if sess.discovery != null and not sess.discovery.is_known(at):
			return "We have not found that strip yet."
	if has(kind, at):
		return "We have one already%s." % ("" if k.at.is_empty() else " there")
	if kind == "informant" and sess.investigation == null:
		return "Nobody at the task force to buy."
	if sess.money < int(k.cost):
		return "Need $%s." % Py.money(int(k.cost))
	return ""


func buy(kind: String, at := "") -> String:
	var err := why_not(kind, at)
	if err != "":
		return err
	var k: Dictionary = KINDS[kind]
	if k.at.is_empty():
		at = ""
	sess.move_money(-int(k.cost), "outside:market", "purchase")
	held.append({"kind": kind, "at": at, "since": sess.time, "paid": int(k.cost)})
	apply()
	sess.say("INVESTED - %s%s: $%s, then $%d an hour. %s." % [k.name, (" at " + World.airfield(at).name) if at != "" else "", Py.money(int(k.cost)),
		int(k.upkeep), str(k.blurb).capitalize()])
	sess.bus.emit("invested", sess.time, "", ["runner"], {"kind": kind, "at": at})
	return ""


## Close one (nothing comes back).
func close(kind: String, at := "") -> String:
	for h in held:
		if h.kind == kind and (str(h.at) == at or KINDS[kind].at.is_empty()):
			held.erase(h)
			apply()
			sess.say("Closed the %s%s." % [str(KINDS[kind].name).to_lower(), (" at " + World.airfield(str(h.at)).name) if str(h.at) != "" else ""])
			return ""
	return "We have no such investment."


func upkeep() -> int:
	var total := 0
	for h in held:
		total += int(KINDS[h.kind].upkeep)
	return total


func update(dt: float) -> void:
	if not ENABLED or held.is_empty():
		_t = 0.0
		return
	if has("informant"):
		_tell_warrants()
	_t += dt
	if _t < UPKEEP_S:
		return
	_t -= UPKEEP_S
	for h in held.duplicate():
		var k: Dictionary = KINDS[h.kind]
		if sess.money >= int(k.upkeep):
			sess.move_money(-int(k.upkeep), "outside:market", "fee")
			h.paid = int(h.paid) + int(k.upkeep)
		else:
			held.erase(h)
			sess.say("LAPSED - the %s%s: we could not pay its $%d this hour." % [str(k.name).to_lower(),
				(" at " + World.airfield(str(h.at)).name) if str(h.at) != "" else "", int(k.upkeep)])
			sess.bus.emit("investment_lapsed", sess.time, "", ["runner"], {"kind": h.kind, "at": h.at})
	apply()


## Put what we hold where the systems read it.
func apply() -> void:
	if sess.police != null:
		sess.police.cool_mult = SAFEHOUSE_COOL if has("safehouse") else 1.0


## The informant: a line the first time each stash's file reaches a warrant.
func _tell_warrants() -> void:
	var inv = sess.investigation
	if inv == null or sess.stash_net == null:
		return
	for st in sess.stash_net.live():
		var id := str(st.id)
		if inv.stage_of(id) == "warrant":
			if not _warrants.has(id):
				_warrants[id] = true
				sess.say("The clerk at the task force: a warrant is signed for %s. Move what is there, or call the lawyer." % st.name)
		else:
			_warrants.erase(id)


## Does the informant give the countdown for this stash (the Heat page's `warned`)?
func warned() -> bool:
	return has("informant")


## The avgas price a pound at `code` with a depot there, or -1.
func depot_price(code: String) -> float:
	if not has("depot", code):
		return -1.0
	return Session.FUEL_PRICE_PER_LB * DEPOT_PRICE * float(sess.econ.fuel_mult())


## For the phone: what we hold, and what can be bought here and now.
func view() -> Dictionary:
	var ours := []
	for h in held:
		var k: Dictionary = KINDS[h.kind]
		ours.append({"kind": h.kind, "at": h.at, "name": k.name, "where": World.airfield(str(h.at)).name if str(h.at) != "" else "",
			"upkeep": int(k.upkeep), "paid": int(h.paid), "blurb": k.blurb})
	var offers := []
	var here: String = str(sess.location) if sess.parked else ""
	for kind in ORDER:
		var k: Dictionary = KINDS[kind]
		var at := "" if k.at.is_empty() else here
		if has(kind, at):
			continue
		offers.append({"kind": kind, "at": at, "name": k.name, "cost": int(k.cost), "upkeep": int(k.upkeep), "blurb": k.blurb,
			"why": why_not(kind, at)})
	return {"held": ours, "offers": offers, "upkeep": upkeep()}


func capture() -> Dictionary:
	return {"held": held.duplicate(true), "t": _t, "warrants": _warrants.keys()}


func restore(d: Dictionary) -> void:
	held = []
	if d.get("held") is Array:
		for h in d.held:
			if h is Dictionary and KINDS.has(str(h.get("kind", ""))):
				held.append({"kind": str(h.kind), "at": str(h.get("at", "")), "since": float(h.get("since", 0.0)), "paid": int(h.get("paid", 0))})
	_t = float(d.get("t", 0.0))
	_warrants = {}
	if d.get("warrants") is Array:
		for id in d.warrants:
			_warrants[str(id)] = true
	apply()
