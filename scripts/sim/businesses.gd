class_name Businesses
extends RefCounted
## The Living District's businesses and districts (L-1; docs/EMPIRE_SIMULATION_SPEC.md sections 2 and 10, D-72). The sim side
## only: the twelve businesses of San Telmo Centro and its two neighbours as data, each with an owner, a till (a ledger account,
## `biz-N:till`), a stock place in the inventory (`biz-N`), costs, a price policy and open hours; and the district state the
## spec names (prosperity and demand, with control read from the street war's table, which it wraps and does not replace).
##
## What they do in L-1: they can be bought (a free one, by the organisation: `business_buy`), funded and drawn on (moving money
## between the safe and the till: `business_fund`, `business_take`), and at every 06:00 books close (Books) each pays its day's
## rent and utilities from its till. What the till can't cover is owed: it goes into the business's arrears, with the blocked
## reason, and is paid first when money comes in. (Only the organisation's pay yet; the Morettis' and Los Cuervos' from L-3.) Nothing ever reaches into an owner's safe by itself, so a game whose
## businesses nobody funds sees no change in its money. The legit chain (L-2) trades groceries through the warehouse and the
## retailers at the same close; staff and orders, L-4;
## the Morettis' and Los Cuervos' AI running theirs, L-3; placing them in the world is the 3D side's.
##
## Built only on a map that has San Telmo Centro. No random draws. Saved (owners, arrears, district state; the tills are ledger
## balances and the ledger is saved). Behind ENABLED (in the parity set).

static var ENABLED := true

const DISTRICT := "san-telmo-centro"
const LANDLORD := "outside:landlord"
const UTILITIES := "outside:utilities"

## L-2, the legit import-to-retail chain (spec section 10): the import warehouse buys groceries from outside:market and sells them
## on, to the district's retail businesses first and the shops outside the twelve after; the retail businesses sell to shoppers at
## the district's demand. Settled at the books close, from the tills, the same rules for every owner the chain runs for.
const GOOD := "groceries"
const WHOLESALE := 2.0  ## $/lb the warehouse pays outside:market
const TRADE := 3.0  ## $/lb a retailer pays the warehouse
const TRADE_OUTSIDE := 3.6  ## $/lb a retailer pays outside:market when no warehouse in the chain has stock
const RETAIL := 4.5  ## $/lb shoppers pay, at a district's prosperity 0.5
const WAREHOUSE_LB := 400.0  ## what the warehouse restocks to a day
const SHELF_LB := 120.0  ## what a retailer restocks to a day
const SHOPPERS_LB := 100.0  ## what a retailer's shoppers buy a day at demand 1 and prosperity 0.5
const OUTSIDE_SHOPS_LB := 150.0  ## what the shops outside the twelve take from the warehouse a day
## The owners whose businesses run the chain. The Morettis' and Los Cuervos' join with their AI and money (L-3).
const RUNS := ["org"]

## id, name, kind, district, site [x, y], starting owner (org id, "" free, "outside" not for sale), price to buy, rent and
## utilities a day, the chain it belongs to (L-2), open hours [from, to].
const DATA := [
	{"id": "biz-1", "name": "Corner on Calle Ocho", "kind": "corner", "district": "san-telmo-centro", "site": [-900.0, -10200.0],
		"owner": "org", "price": 0, "rent": 0, "utilities": 0, "chain": "product", "hours": [18, 4]},
	{"id": "biz-2", "name": "Corner by the arcade", "kind": "corner", "district": "san-telmo-centro", "site": [-300.0, -9600.0],
		"owner": "", "price": 4000, "rent": 0, "utilities": 0, "chain": "product", "hours": [18, 4]},
	{"id": "biz-3", "name": "Lavanderia Sol", "kind": "laundromat", "district": "san-telmo-centro", "site": [-1300.0, -10500.0],
		"owner": "moretti", "price": 0, "rent": 120, "utilities": 60, "chain": "front", "hours": [7, 22]},
	{"id": "biz-4", "name": "Club Tropicana", "kind": "bar", "district": "san-telmo-centro", "site": [-600.0, -10700.0],
		"owner": "org", "price": 0, "rent": 300, "utilities": 90, "chain": "front+product", "hours": [20, 4]},
	{"id": "biz-5", "name": "Trattoria del Porto", "kind": "restaurant", "district": "san-telmo-centro", "site": [-1100.0, -9800.0],
		"owner": "moretti", "price": 0, "rent": 250, "utilities": 80, "chain": "front", "hours": [11, 23]},
	{"id": "biz-6", "name": "Bodega La Esquina", "kind": "bodega", "district": "san-telmo-centro", "site": [100.0, -10300.0],
		"owner": "rival", "price": 0, "rent": 90, "utilities": 40, "chain": "retail", "hours": [6, 23]},
	{"id": "biz-7", "name": "Viajes Caribe", "kind": "travel agency", "district": "san-telmo-centro", "site": [-200.0, -10800.0],
		"owner": "", "price": 18000, "rent": 150, "utilities": 30, "chain": "front", "hours": [9, 18]},
	{"id": "biz-8", "name": "The car dealership", "kind": "dealership", "district": "san-telmo-centro", "site": [-1500.0, -9300.0],
		"owner": "outside", "price": 0, "rent": 0, "utilities": 0, "chain": "", "hours": [8, 20]},
	{"id": "biz-9", "name": "Costa Imports", "kind": "warehouse", "district": "the-docks", "site": [-3300.0, -11200.0],
		"owner": "", "price": 30000, "rent": 200, "utilities": 70, "chain": "retail", "hours": [6, 18]},
	{"id": "biz-10", "name": "Mercado del Mar", "kind": "fish market", "district": "the-docks", "site": [-2500.0, -10600.0],
		"owner": "moretti", "price": 0, "rent": 140, "utilities": 90, "chain": "retail", "hours": [4, 14]},
	{"id": "biz-11", "name": "Corner by the lock-up", "kind": "corner", "district": "barrio-chino", "site": [1500.0, -9700.0],
		"owner": "rival", "price": 0, "rent": 0, "utilities": 0, "chain": "product", "hours": [18, 4]},
	{"id": "biz-12", "name": "Taller Rapido", "kind": "garage", "district": "barrio-chino", "site": [900.0, -10100.0],
		"owner": "", "price": 12000, "rent": 110, "utilities": 50, "chain": "cover", "hours": [7, 19]},
]

var sess
var owner := {}  ## business id -> org id ("" free, "outside" not for sale)
var arrears := {}  ## business id -> dollars owed
var blocked := {}  ## business id -> why the day's costs weren't paid, or absent
var districts := {}  ## district id -> {prosperity, demand{good: float}}


func _init(sess_) -> void:
	sess = sess_
	for b in DATA:
		owner[b.id] = str(b.owner)
	for d in [DISTRICT, "the-docks", "barrio-chino"]:
		districts[d] = {"prosperity": 0.5, "demand": {"cocaine": 1.0, "marijuana": 1.0, "groceries": 1.0}}
	sess.bus.subscribe("books", _on_books)


## A map that has the district: the city coast. Other maps have no Living District.
static func on_this_map() -> bool:
	return not Territories.get_area(World.layout, DISTRICT).is_empty()


static func spec(id: String) -> Dictionary:
	for b in DATA:
		if b.id == id:
			return b
	return {}


static func till(id: String) -> String:
	return id + ":till"


func balance(id: String) -> int:
	return int(sess.ledger.balance(till(id)))


## The district state (spec section 2): control from the street war's table, the rest here.
func district(id: String) -> Dictionary:
	var d: Dictionary = districts.get(id, {"prosperity": 0.5, "demand": {}}).duplicate(true)
	d["id"] = id
	d["control"] = {}
	if sess.ground != null:
		var k := Territories.key(World.layout, id)
		if sess.ground.territory_control.has(k):
			d["control"] = sess.ground.territory_control[k].duplicate()
	return d


# ------------------------------------------------------------------ the organisation's commands
## Buy a free business. "" or why not.
func buy(id: String) -> String:
	var b := spec(id)
	if b.is_empty():
		return "No such business."
	if str(owner[id]) == "org":
		return "It's already ours."
	if str(owner[id]) != "":
		return "%s isn't for sale." % b.name
	if sess.money < int(b.price):
		return "%s costs $%s." % [b.name, Py.money(int(b.price))]
	sess.move_money(-int(b.price), "outside:market", "purchase")
	owner[id] = "org"
	sess.say("Bought %s ($%s). Its till is empty: fund it to pay the rent [business_fund]." % [b.name, Py.money(int(b.price))])
	sess.bus.emit("business_bought", sess.time, "", ["runner"], {"id": id, "price": int(b.price)})
	return ""


## Money from the safe into one of our tills (it pays the arrears first). "" or why not.
func fund(id: String, amount: int) -> String:
	var err := _ours(id)
	if err != "":
		return err
	amount = mini(amount, maxi(0, sess.money))
	if amount <= 0:
		return "Nothing to put in."
	sess.move_money(-amount, till(id), "transfer")
	_settle_arrears(id)
	return ""


## Money from one of our tills into the safe. "" or why not.
func take(id: String, amount: int) -> String:
	var err := _ours(id)
	if err != "":
		return err
	amount = mini(amount, balance(id))
	if amount <= 0:
		return "The till is empty."
	sess.move_money(amount, till(id), "transfer")
	return ""


func _ours(id: String) -> String:
	if spec(id).is_empty():
		return "No such business."
	if str(owner[id]) != "org":
		return "That isn't ours."
	return ""


# ------------------------------------------------------------------ the day's costs
func _on_books(_e) -> void:
	if sess == null:
		return
	_trade_day()
	for b in DATA:
		var id: String = b.id
		if str(owner[id]) != "org":
			continue  # free, outside, or another org's: theirs to run from L-3 (org AI v1)
		arrears[id] = int(arrears.get(id, 0)) + int(b.rent) + int(b.utilities)
		_settle_arrears(id)


## Pay what is owed from the till, rent first; what can't be paid stays owed, with the reason.
func _settle_arrears(id: String) -> void:
	var owed := int(arrears.get(id, 0))
	if owed <= 0:
		blocked.erase(id)
		return
	var pay := mini(owed, balance(id))
	if pay > 0:
		var b := spec(id)
		var to_rent := mini(pay, int(b.rent))
		if to_rent > 0:
			sess.ledger.transfer(till(id), LANDLORD, float(to_rent), "fee", "system:books", sess.time)
		if pay - to_rent > 0:
			sess.ledger.transfer(till(id), UTILITIES, float(pay - to_rent), "fee", "system:books", sess.time)
		owed -= pay
	arrears[id] = owed
	if owed > 0:
		blocked[id] = "The till is $%s short of the rent and the bills." % Py.money(owed)
	else:
		blocked.erase(id)


# ------------------------------------------------------------------ the legit chain (L-2)
func runs(id: String) -> bool:
	return str(owner.get(id, "")) in RUNS


static func is_warehouse(b: Dictionary) -> bool:
	return str(b.chain) == "retail" and str(b.kind) == "warehouse"


static func is_retail(b: Dictionary) -> bool:
	return str(b.chain) == "retail" and str(b.kind) != "warehouse"


func shelf(id: String) -> float:
	return sess.inventory.stock(id, GOOD)


## The day's trade, before the rent: shoppers buy, the retailers restock (from a warehouse in the chain first), then the warehouse
## sells what's left over to the shops outside and restocks from the market. Every pound is an inventory move and every dollar a
## transfer between tills and outside accounts; a till that can't pay buys what it can.
func _trade_day() -> void:
	var t: float = sess.time
	for b in DATA:
		if is_retail(b) and runs(b.id):
			var d: Dictionary = districts.get(str(b.district), {"prosperity": 0.5, "demand": {}})
			var want := SHOPPERS_LB * float(d.demand.get(GOOD, 1.0)) * (0.5 + float(d.prosperity))
			var lb := minf(want, shelf(b.id))
			if lb > 0.01:
				sess.inventory.transfer(b.id, Inventory.OUTSIDE + "shoppers", GOOD, lb, "sale", owner[b.id], t)
				sess.ledger.transfer("outside:shoppers", till(b.id), lb * price(str(b.district)), "sales", "system:books", t)
	for b in DATA:
		if is_retail(b) and runs(b.id):
			_restock_retail(b, t)
	for b in DATA:
		if is_warehouse(b) and runs(b.id):
			var lb := minf(OUTSIDE_SHOPS_LB, shelf(b.id))
			if lb > 0.01:
				sess.inventory.transfer(b.id, Inventory.OUTSIDE + "retail", GOOD, lb, "sale", owner[b.id], t)
				sess.ledger.transfer("outside:retail", till(b.id), lb * TRADE, "sales", "system:books", t)
			var need := WAREHOUSE_LB - shelf(b.id)
			var afford := floorf(float(balance(b.id)) / WHOLESALE)
			var buy := minf(need, afford)
			if buy >= 1.0:
				sess.ledger.transfer(till(b.id), "outside:market", buy * WHOLESALE, "purchase", "system:books", t)
				sess.inventory.add(GOOD, buy, b.id, "market", "", 0.5, 0.0, t)


## What shoppers pay a pound in a district: dearer where it's prosperous.
func price(district_id: String) -> float:
	var d: Dictionary = districts.get(district_id, {"prosperity": 0.5})
	return RETAIL * (0.8 + 0.4 * float(d.prosperity))


func _restock_retail(b: Dictionary, t: float) -> void:
	var need := SHELF_LB - shelf(b.id)
	for w in DATA:
		if need < 1.0:
			return
		if not is_warehouse(w) or not runs(w.id):
			continue
		var lb := minf(minf(need, shelf(w.id)), floorf(float(balance(b.id)) / TRADE))
		if lb >= 1.0:
			var moved: float = sess.inventory.transfer(w.id, b.id, GOOD, lb, "wholesale", owner[b.id], t)
			sess.ledger.transfer(till(b.id), till(w.id), moved * TRADE, "sales", "system:books", t)
			need -= moved
	var lb := minf(need, floorf(float(balance(b.id)) / TRADE_OUTSIDE))
	if lb >= 1.0:
		sess.ledger.transfer(till(b.id), "outside:market", lb * TRADE_OUTSIDE, "purchase", "system:books", t)
		sess.inventory.add(GOOD, lb, b.id, "market", "", 0.5, 0.0, t)


# ------------------------------------------------------------------ the books, for the desk (L-4) and A1
func view(id: String) -> Dictionary:
	var b := spec(id)
	if b.is_empty():
		return {}
	return {"id": id, "name": b.name, "kind": b.kind, "district": b.district, "owner": owner[id], "till": balance(id),
		"arrears": int(arrears.get(id, 0)), "blocked": str(blocked.get(id, "")), "rent": int(b.rent), "utilities": int(b.utilities),
		"price": int(b.price), "chain": b.chain, "hours": b.hours.duplicate(), "stock": id, "shelf": snappedf(shelf(id), 0.1)}


func ours() -> Array:
	return DATA.filter(func(b): return str(owner[b.id]) == "org").map(func(b): return view(b.id))


func capture() -> Dictionary:
	return {"owner": owner.duplicate(), "arrears": arrears.duplicate(), "blocked": blocked.duplicate(), "districts": districts.duplicate(true)}


func restore(d: Dictionary) -> void:
	for k in d.get("owner", {}):
		if owner.has(str(k)):
			owner[str(k)] = str(d.owner[k])
	arrears = {}
	for k in d.get("arrears", {}):
		arrears[str(k)] = int(d.arrears[k])
	blocked = {}
	for k in d.get("blocked", {}):
		blocked[str(k)] = str(d.blocked[k])
	for k in d.get("districts", {}):
		if d.districts[k] is Dictionary:
			districts[str(k)] = d.districts[k].duplicate(true)
