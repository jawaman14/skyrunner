class_name Laundering
extends RefCounted
## Fronts wash street cash (docs/DESIGN.md section 51.5, ROADMAP "Stock, ownership and the money loop" slice 5). A front is a
## Living District business whose chain names "front" (the laundromat, the club, the restaurant, the travel agency). Its owner
## deposits dirty money with it; the front books it as takings and, after its delay, the clean part reaches the owner's safe.
##
## - **The night's allowance** (per front, reset at every 06:00 books close: the night is the period the session really has).
##   Up to it a deposit adds no heat. Between it and the **ceiling** (1.5 times it) a deposit goes through but every $1,000
##   over adds case-file heat on the runner (less for a dearer front). Above the ceiling it is refused.
## - **The fee**: the front keeps FEE of every deposit in its till, as sales. That is the front's revenue: it pays its rent.
## - **The delay**: the rest waits in the front's wash account (`biz-N:wash`) for the front's hours, then moves to the safe.
## - **A large dirty balance** is heat too: at each close, street cash over DIRTY_FREE adds DIRTY_HEAT per $10,000 over.
##
## Equal rules (spec section 7): the same command (`business_launder`) for every org. The organisation's dirty money is the
## street's (a stash's cash, Logistics.STREET); an AI org's is its `<org>:dirty` account, fed each close by the rackets it runs
## off the map (RACKETS, outside:rackets), which its policy washes through its own fronts up to the allowance. The AI orgs have no
## case file, so heat is the organisation's only.
##
## Every number is a draft for the owner's G1 (the section 51.9 table, rescaled from a week to a night). No random draws: no
## stream. Saved with the businesses (the night's deposits, the money in the wash, the AI's dirty accounts). Behind ENABLED (in
## the parity set).

static var ENABLED := true

## kind: allowance a night ($), delay (game hours), heat per $1,000 over the allowance.
const FRONTS := {
	"laundromat": {"allowance": 1500, "delay_h": 24.0, "heat": 10.0},
	"bar": {"allowance": 2500, "delay_h": 12.0, "heat": 6.0},
	"restaurant": {"allowance": 3500, "delay_h": 6.0, "heat": 3.0},
	"travel agency": {"allowance": 5000, "delay_h": 6.0, "heat": 1.0},
}
const CEILING := 1.5  ## times the allowance: the most a front takes in a night
const FEE := 0.15  ## the front's share, kept in its till as sales
const MIN_DEPOSIT := 100
const DIRTY_FREE := 25000.0  ## street cash the case file shrugs at
const DIRTY_HEAT := 2.0  ## suspicion per $10,000 of street cash over DIRTY_FREE, at each close
const RACKETS := {"moretti": 2200.0}  ## an AI org's dirty takings a day from its rackets off the map
const RACKETS_FROM := "outside:rackets"

var biz  ## Businesses (untyped: no cycle at parse time)
var washed := {}  ## front id -> $ deposited this night
var pending: Array = []  ## {id, org, net, due}, oldest first


func _init(biz_) -> void:
	biz = biz_


static func is_front(b: Dictionary) -> bool:
	return "front" in str(b.get("chain", "")) and FRONTS.has(str(b.get("kind", "")))


static func wash_account(id: String) -> String:
	return id + ":wash"


static func dirty_account(o: String) -> String:
	return o + ":dirty"


func allowance(id: String) -> int:
	var b: Dictionary = biz.find(id)
	return int(FRONTS[str(b.kind)].allowance) if is_front(b) else 0


func ceiling(id: String) -> int:
	return int(floor(float(allowance(id)) * CEILING))


## What a front would still take tonight: [without heat, at most].
func room(id: String) -> Array:
	var done := int(washed.get(id, 0))
	return [maxi(0, allowance(id) - done), maxi(0, ceiling(id) - done)]


## What `o` has to wash: the street's cash for the organisation (one stash's, if named), the dirty account for an AI org.
func dirty_of(o: String, stash := "") -> int:
	if o == "org":
		var lg = biz.sess.logistics
		if lg == null:
			return 0
		if stash != "":
			return int(lg.cash.get(stash, 0))
		var n := 0
		for s in lg.cash:
			n += int(lg.cash[s])
		return n
	return int(biz.sess.ledger.balance(dirty_account(o)))


## The organisation's stash with the most cash (ties: the first by id), or "".
func richest_stash() -> String:
	var lg = biz.sess.logistics
	if lg == null:
		return ""
	var best := ""
	var keys: Array = lg.cash.keys()
	keys.sort()
	for s in keys:
		if int(lg.cash[s]) > 0 and (best == "" or int(lg.cash[s]) > int(lg.cash[best])):
			best = str(s)
	return best


## Deposit `amount` of `o`'s dirty money with front `id` (the organisation's from `stash`, or its richest). "" or why not.
func launder(id: String, amount: int, o := "org", stash := "") -> String:
	if not ENABLED:
		return "Laundering is off in this game."
	var b: Dictionary = biz.find(id)
	if b.is_empty():
		return "No such business."
	if str(biz.owner[id]) != o:
		return "That isn't ours."
	if not is_front(b):
		return "%s can't wash money: it isn't a front." % b.name
	if o == "org":
		if biz.sess.logistics == null:
			return "There is no street cash to wash."
		if stash == "":
			stash = richest_stash()
		if stash == "" or not biz.sess.logistics.cash.has(stash):
			return "There is no cash at a stash to wash."
	var r := room(id)
	if int(r[1]) < MIN_DEPOSIT:
		return "%s has taken all it can tonight ($%s)." % [b.name, Py.money(ceiling(id))]
	var n := mini(amount, mini(dirty_of(o, stash), int(r[1])))
	if n < MIN_DEPOSIT:
		return "Nothing to wash." if dirty_of(o, stash) < MIN_DEPOSIT else "Too little to bother the books with."
	var fee := int(round(float(n) * FEE))
	var net := n - fee
	var t: float = biz.sess.time
	if o == "org":
		var lg = biz.sess.logistics
		lg.cash[stash] = int(lg.cash[stash]) - n
		lg.book_cash(Logistics.STREET, Businesses.till(id), float(fee), "sales")
		lg.book_cash(Logistics.STREET, wash_account(id), float(net), "transfer")
	else:
		biz.sess.ledger.transfer(dirty_account(o), Businesses.till(id), float(fee), "sales", o, t)
		biz.sess.ledger.transfer(dirty_account(o), wash_account(id), float(net), "transfer", o, t)
	var over := maxi(0, int(washed.get(id, 0)) + n - allowance(id)) - maxi(0, int(washed.get(id, 0)) - allowance(id))
	washed[id] = int(washed.get(id, 0)) + n
	var due := t + float(FRONTS[str(b.kind)].delay_h) * 3600.0
	pending.append({"id": id, "org": o, "net": net, "due": due})
	var heat := 0.0
	if over > 0 and o == "org" and biz.sess.police != null:
		heat = float(FRONTS[str(b.kind)].heat) * float(over) / 1000.0
		var c = biz.sess.police.case("runner")
		c.suspicion = minf(100.0, c.suspicion + heat)
	if o == "org":
		biz.sess.say("%s books $%s as takings: $%s clean in the safe in %d hours, $%s to the till.%s" % [b.name, Py.money(n),
			Py.money(net), int(FRONTS[str(b.kind)].delay_h), Py.money(fee),
			" Over tonight's $%s: the books look heavy (+%.0f heat)." % [Py.money(allowance(id)), heat] if heat > 0.0 else ""])
	biz.sess.bus.emit("laundered", t, "", ["runner"], {"id": id, "org": o, "amount": n, "net": net, "over": over})
	return ""


## The clean money whose delay has run, to its owner's safe. Called every tick and at the close.
func mature() -> void:
	if pending.is_empty():
		return
	var t: float = biz.sess.time
	var keep: Array = []
	for p in pending:
		if float(p.due) > t:
			keep.append(p)
			continue
		var amt := minf(float(p.net), biz.sess.ledger.balance(wash_account(str(p.id))))
		if amt >= 0.005:
			biz._pay(str(p.org), amt, wash_account(str(p.id)), "transfer")
			if str(p.org) == "org":
				biz.sess.say("$%s from %s is clean and in the safe." % [Py.money(int(amt)), biz.find(str(p.id)).get("name", p.id)])
	pending = keep


## The books close: tonight's deposits start over, the AI orgs' rackets pay in, and a big pile of street cash is noticed.
func close() -> void:
	if not ENABLED:
		return
	mature()
	washed = {}
	var t: float = biz.sess.time
	for o in RACKETS:
		if biz.ai != null and biz.ai.runs_for(o):
			biz.sess.ledger.transfer(RACKETS_FROM, dirty_account(o), float(RACKETS[o]), "sales", "system:books", t)
	var lg = biz.sess.logistics
	if lg != null and biz.sess.police != null:
		var over: float = lg.cash_out() - DIRTY_FREE
		if over > 0.0:
			var c = biz.sess.police.case("runner")
			c.suspicion = minf(100.0, c.suspicion + DIRTY_HEAT * over / 10000.0)


## An AI org's policy (OrgAI): wash what its dirty account holds through its fronts, never over the allowance.
func ai_moves(o: String) -> Array:
	var out := []
	var left := dirty_of(o)
	for b in biz.catalog:
		if left < MIN_DEPOSIT or str(biz.owner[b.id]) != o or not is_front(b):
			continue
		var n := mini(left, int(room(b.id)[0]))
		if n >= MIN_DEPOSIT:
			out.append({"id": b.id, "amount": n})
			left -= n
	return out


## The money waiting in a front's wash, for the desk.
func waiting(id: String) -> int:
	var n := 0.0
	for p in pending:
		if str(p.id) == id:
			n += float(p.net)
	return int(n)


func capture() -> Dictionary:
	var dirty := {}
	for o in RACKETS:
		dirty[o] = biz.sess.ledger.balance(dirty_account(o))
	return {"washed": washed.duplicate(), "pending": pending.duplicate(true), "dirty": dirty}


## The wash accounts and the AI's dirty accounts live in the ledger, which the strategic save doesn't carry: restated here.
func restore(d: Dictionary) -> void:
	washed = {}
	for k in d.get("washed", {}):
		washed[str(k)] = int(d.washed[k])
	pending = []
	var sums := {}
	for p in d.get("pending", []):
		if p is Dictionary:
			pending.append({"id": str(p.id), "org": str(p.org), "net": float(p.net), "due": float(p.due)})
			sums[str(p.id)] = float(sums.get(str(p.id), 0.0)) + float(p.net)
	for b in biz.catalog:
		if is_front(b):
			biz.sess.ledger.restate(wash_account(b.id), float(sums.get(b.id, 0.0)), biz.sess.time)
	for o in d.get("dirty", {}):
		biz.sess.ledger.restate(dirty_account(str(o)), float(d.dirty[o]), biz.sess.time)
