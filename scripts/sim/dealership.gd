class_name Dealership
extends RefCounted
## The car dealership: vehicles for the organisation, bought with the organisation's money.
##
## Two kinds, by what they are for (`use`):
##   "drive"  a car the pilot drives on the ground (the starter car's replacement): faster on the road, better across
##            country, quicker off the line. One is the active car at a time; it is the one that stands by the aircraft.
##   "haul"   a stash truck for the organisation's drivers (StashNet / Logistics trucks, driven by AI agents or by hired
##            hands). Owned trucks change how every run goes: the fleet's best speed is the trucks' speed, its best cover
##            (an ambulance nobody stops) cuts the roadblock odds, and a steel box can bust through a roadblock that
##            would have seized the load (`armour`).
## The speed is the fleet's best truck, cover and steel the best of each, so a heavy truck alone is slower than the hired van
## it replaces and a quick van beside it brings the speed back. Owned vehicles cost insurance by the hour. Selling gets RESALE of the price back.
##
## Makers (owner, 7 Nov, D-95: the Borderlands study's manufacturers). Every vehicle on the lot is built by one of four fictional
## makers, and each maker has one behaviour you can read off the badge: Halcyon is cheap to keep, Corsair holds its value, Mercy
## is built for the back roads, Bastion's steel stacks. Owning different models from one maker is a set: two models give a small
## fleet bonus, three a bigger one (see MAKERS). Sets count models, not vehicles, so three hatches are not a set.
##
## The dealership can also be run by the AI (`auto`): when the organisation is flush and has no better truck than the
## ones it owns, it buys one. Nothing here draws random numbers, so no stream is needed.
##
## Behind ENABLED and the session's "dealership" system (Story opens it with logistics); with it off the trucks run at
## StashNet.TRUCK_MS as they always did, so the parity tests are untouched.

static var ENABLED := true

const RESALE := 0.55
const MAX_OWNED := 10
const INSURANCE_DRIVE := 40.0  ## dollars an hour
const INSURANCE_HAUL := 90.0
const AUTO_EVERY_S := 900.0
const AUTO_RESERVE := 40000  ## the AI keeps this much in hand after a purchase

## id, the name on the lot, what it is for, the price, the model (Kenney's Car Kit) and its length, then the numbers.
## drive: road m/s, cross-country m/s, acceleration m/s^2.  haul: m/s, stealth (cuts roadblock odds), armour (the chance it
## gets through a roadblock that would have seized it).
const CATALOGUE := [
	{"id": "hatch", "maker": "halcyon", "name": "Sunrise Hatch", "use": "drive", "price": 4000, "model": "hatchback-sports", "len": 4.0, "road": 23.0, "off": 10.0, "accel": 8.5,
		"blurb": "cheap, cheerful, and gone before the owner notices"},
	{"id": "coupe", "maker": "halcyon", "name": "Harbor Coupe", "use": "drive", "price": 6500, "model": "sedan", "len": 4.6, "road": 26.0, "off": 11.0, "accel": 9.0,
		"blurb": "the starter car's twin, in a better colour"},
	{"id": "suv", "maker": "mercy", "name": "Valley SUV", "use": "drive", "price": 12000, "model": "suv", "len": 4.8, "road": 25.0, "off": 16.0, "accel": 8.0,
		"blurb": "the one for the cane roads and the farm tracks"},
	{"id": "roadster", "maker": "corsair", "name": "Marlin GT", "use": "drive", "price": 21000, "model": "sedan-sports", "len": 4.5, "road": 34.0, "off": 12.0, "accel": 13.0,
		"blurb": "the fastest thing on four wheels in the county"},
	{"id": "luxury", "maker": "mercy", "name": "Palmetto Limited", "use": "drive", "price": 30000, "model": "suv-luxury", "len": 5.0, "road": 29.0, "off": 17.0, "accel": 10.0,
		"blurb": "leather, air conditioning and a bar; the Family's own choice"},
	{"id": "van", "maker": "halcyon", "name": "Courier Van", "use": "haul", "price": 14000, "model": "van", "len": 5.2, "speed": 12.5, "stealth": 0.15, "armour": 0.0,
		"blurb": "a plain white van; nobody looks twice"},
	{"id": "box", "maker": "bastion", "name": "Steel Box Truck", "use": "haul", "price": 24000, "model": "delivery", "len": 6.0, "speed": 11.5, "stealth": 0.05, "armour": 0.25,
		"blurb": "a delivery truck with a steel liner and a heavy bumper"},
	{"id": "fast", "maker": "corsair", "name": "Midnight Van", "use": "haul", "price": 38000, "model": "van", "len": 5.2, "speed": 15.0, "stealth": 0.25, "armour": 0.0,
		"blurb": "a van with the Marlin's engine in it"},
	{"id": "ambulance", "maker": "mercy", "name": "Ambulance Conversion", "use": "haul", "price": 55000, "model": "ambulance", "len": 5.8, "speed": 14.0, "stealth": 0.45, "armour": 0.0,
		"blurb": "lights and a siren; no cop will stop it, and fewer will look in the back"},
	{"id": "armoured", "maker": "bastion", "name": "Armoured Truck", "use": "haul", "price": 70000, "model": "truck", "len": 6.4, "speed": 9.5, "stealth": 0.0, "armour": 0.6,
		"blurb": "slow, heavy, and a roadblock is a speed bump"},
]

## The makers: the name on the badge, the one-line pitch, the behaviour, and the set bonuses (models owned -> fleet numbers).
## Traits:  halcyon  insurance at HALCYON_INSURANCE;   corsair  resale at CORSAIR_RESALE;
##          mercy    its cars MERCY_OFF faster across country, its trucks MERCY_COVER more cover;
##          bastion  steel stacks: a second Bastion truck adds BASTION_STACK of its own steel to the fleet's best.
const MAKERS := {
	"halcyon": {"name": "Halcyon Motors", "pitch": "cheap to keep", "trait": "half the insurance",
		"sets": {2: {"stealth": 0.05}, 3: {"stealth": 0.10}}},
	"corsair": {"name": "Corsair", "pitch": "built to run", "trait": "resells for 70%",
		"sets": {2: {"speed": 1.5, "road": 2.0}}},
	"mercy": {"name": "Mercy Coachworks", "pitch": "built for the back roads", "trait": "cars quicker across country, trucks better cover",
		"sets": {2: {"stealth": 0.10}, 3: {"stealth": 0.10, "armour": 0.10}}},
	"bastion": {"name": "Bastion Works", "pitch": "built like a vault", "trait": "steel stacks across its trucks",
		"sets": {2: {"armour": 0.10}}},
}
const HALCYON_INSURANCE := 0.5
const CORSAIR_RESALE := 0.70
const MERCY_OFF := 3.0  ## m/s across country
const MERCY_COVER := 0.05
const BASTION_STACK := 0.5
const MAX_COVER := 0.6  ## the fleet's cover and steel never pass these, however the bonuses add up
const MAX_STEEL := 0.8

var sess
var owned: Array = []  ## [{serial, id, bought}]
var active := 0  ## the serial of the car the pilot drives (0: the starter car)
var spent := 0
var auto := false  ## the AI manages the fleet
var rev := 0  ## counts changes the 3D side must act on (a new active car)
var rng: PyRandom
var _pass := {}  ## "job/squad" -> whether the fleet's cover or steel got that truck past that stop (rolled once)
var _serial := 0
var _hour_t := 0.0
var _auto_t := 0.0
var _insured := 0.0


func _init(s) -> void:
	sess = s
	rng = PyRandom.new()
	rng.seed(int(s.seed) + 947)
	apply()


static func spec(id: String) -> Dictionary:
	for c in CATALOGUE:
		if c.id == id:
			return c
	return {}


## "" when the vehicle can be bought now, else why not.
func why_not(id: String, by_ai := false) -> String:
	if not ENABLED:
		return "There is no dealership in this game."
	var sp := spec(id)
	if sp.is_empty():
		return "The lot has no such vehicle."
	if owned.size() >= MAX_OWNED:
		return "You are at the limit: %d vehicles. Sell one first." % MAX_OWNED
	if not by_ai and sp.use == "drive" and not sess.parked:
		return "Come to a full stop at an airfield first: the car is delivered to the aircraft."
	if sess.money < int(sp.price):
		return "%s costs $%s." % [sp.name, Py.money(int(sp.price))]
	return ""


func buy(id: String, by_ai := false) -> String:
	var err := why_not(id, by_ai)
	if err != "":
		return err
	var sp := spec(id)
	sess.move_money(-int(sp.price), "outside:market", "purchase", "org")
	spent += int(sp.price)
	_serial += 1
	owned.append({"serial": _serial, "id": id, "bought": sess.time})
	if sp.use == "drive" and active == 0:
		active = _serial
		rev += 1  # the first car you buy is the one you drive
	apply()
	sess.say("Bought: %s ($%s)." % [sp.name, Py.money(int(sp.price))])
	sess.bus.emit("vehicle_bought", sess.time, "", ["runner"], {"id": id, "price": int(sp.price)})
	return ""


func sell(serial: int) -> String:
	if not ENABLED:
		return "There is no dealership in this game."
	var i := _find(serial)
	if i < 0:
		return "You do not own that."
	var v: Dictionary = owned[i]
	var sp := spec(str(v.id))
	var back := resale(str(sp.id))
	owned.remove_at(i)
	sess.move_money(back, "outside:market", "resale", "org")
	if active == serial:
		active = 0
		for o in owned:
			if spec(str(o.id)).use == "drive":
				active = int(o.serial)
				break
		rev += 1
	apply()
	sess.say("Sold the %s for $%s." % [sp.name, Py.money(back)])
	return ""


## Make an owned car the one the pilot drives (0 for the starter car).
func use_car(serial: int) -> String:
	if not ENABLED:
		return "There is no dealership in this game."
	if serial != 0:
		var i := _find(serial)
		if i < 0:
			return "You do not own that."
		if spec(str(owned[i].id)).use != "drive":
			return "That is a truck: the drivers take it."
	if active != serial:
		active = serial
		rev += 1
	return ""


func set_auto(on: bool) -> String:
	if not ENABLED:
		return "There is no dealership in this game."
	auto = on
	return ""


## What a vehicle fetches when it is sold.
static func resale(id: String) -> int:
	var sp := spec(id)
	return int(float(sp.price) * (CORSAIR_RESALE if sp.get("maker") == "corsair" else RESALE))


## maker -> how many different models of it the organisation owns.
func models() -> Dictionary:
	var seen := {}
	for v in owned:
		var sp := spec(str(v.id))
		seen["%s/%s" % [sp.maker, sp.id]] = str(sp.maker)
	var out := {}
	for k in seen:
		out[seen[k]] = int(out.get(seen[k], 0)) + 1
	return out


## The set bonus a maker gives with `n` models owned: the biggest tier reached, or {}.
static func set_bonus(maker: String, n: int) -> Dictionary:
	var best := {}
	var sets: Dictionary = MAKERS[maker].sets
	for need in sets:
		if n >= int(need):
			best = sets[need]
	return best


## Every set bonus the fleet has earned, added up: {speed, stealth, armour, road}.
func bonuses() -> Dictionary:
	var b := {"speed": 0.0, "stealth": 0.0, "armour": 0.0, "road": 0.0}
	var m := models()
	for maker in m:
		var got := set_bonus(str(maker), int(m[maker]))
		for k in got:
			b[k] = float(b[k]) + float(got[k])
	return b


## The makers' line for the screen: "Halcyon Motors 2 of 3 (+5% cover)", one for each maker owned.
func sets_line() -> String:
	var m := models()
	var parts := []
	for maker in MAKERS:
		if not m.has(maker):
			continue
		var n := int(m[maker])
		var of := 0
		for sp in CATALOGUE:
			if sp.maker == maker:
				of += 1
		var got := set_bonus(maker, n)
		var what := []
		if got.has("speed"):
			what.append("+%d km/h trucks" % int(float(got.speed) * 3.6))
		if got.has("road"):
			what.append("+%d km/h its cars" % int(float(got.road) * 3.6))
		if got.has("stealth"):
			what.append("+%d%% cover" % int(round(float(got.stealth) * 100.0)))
		if got.has("armour"):
			what.append("+%d%% steel" % int(round(float(got.armour) * 100.0)))
		parts.append("%s %d of %d%s" % [MAKERS[maker].name, n, of, (" (%s)" % ", ".join(what)) if not what.is_empty() else ""])
	return "   ".join(parts)


func _find(serial: int) -> int:
	for i in owned.size():
		if int(owned[i].serial) == serial:
			return i
	return -1


## The stats of the car the pilot drives: {name, model, len, road, off, accel}, or {} for the starter car.
func drive_spec() -> Dictionary:
	if not ENABLED or active == 0:
		return {}
	var i := _find(active)
	if i < 0:
		return {}
	var sp: Dictionary = spec(str(owned[i].id)).duplicate()
	if sp.maker == "mercy":
		sp.off = float(sp.off) + MERCY_OFF
	var b := set_bonus(str(sp.maker), int(models().get(sp.maker, 0)))
	sp.road = float(sp.road) + float(b.get("road", 0.0))
	return sp


func haulers() -> Array:
	var out := []
	for v in owned:
		var sp := spec(str(v.id))
		if sp.use == "haul":
			out.append(sp)
	return out


## What the owned trucks make of every stash run: the fleet's best of each number.
func fleet() -> Dictionary:
	var f := {"speed": StashNet.TRUCK_MS, "stealth": 0.0, "armour": 0.0, "count": 0}
	if not ENABLED:
		return f
	var best := 0.0
	var steel := []  # each Bastion truck's steel, for the stack
	for sp in haulers():
		f.count += 1
		best = maxf(best, float(sp.speed))
		var cover := float(sp.stealth) + (MERCY_COVER if sp.maker == "mercy" else 0.0)
		f.stealth = maxf(float(f.stealth), cover)
		f.armour = maxf(float(f.armour), float(sp.armour))
		if sp.maker == "bastion":
			steel.append(float(sp.armour))
	if f.count > 0:
		f.speed = best  # the trucks you own are the trucks that run: an armoured one alone is slower than the hired van it replaces
		steel.sort()
		steel.reverse()
		var stack := 0.0
		for i in range(1, steel.size()):
			stack += float(steel[i]) * BASTION_STACK
		var b := bonuses()
		f.speed = float(f.speed) + float(b.speed)
		f.stealth = minf(MAX_COVER, float(f.stealth) + float(b.stealth))
		f.armour = minf(MAX_STEEL, float(f.armour) + stack + float(b.armour))
	return f


## Hand the fleet's numbers to the stash network (it drives the trucks).
func apply() -> void:
	if sess.stash_net == null:
		return
	var f := fleet()
	sess.stash_net.haul_ms = float(f.speed)
	sess.stash_net.risk_mult = 1.0 - float(f.stealth)
	sess.stash_net.armour = float(f.armour)


## A truck pulled over by a checkpoint or a patrol: does the cover (an ambulance nobody stops) or the steel (a truck that
## drives through the barrier) get it past this one? Rolled once for each truck and stop, only when the fleet has either.
func gets_past(job_id: int, squad_id: String) -> bool:
	if not ENABLED:
		return false
	var f := fleet()
	var p := minf(0.9, float(f.stealth) + float(f.armour))
	if p <= 0.0:
		return false
	var key := "%d/%s" % [job_id, squad_id]
	if not _pass.has(key):
		_pass[key] = rng.random() < p
		if _pass.size() > 300:
			_pass.clear()
	return _pass[key]


func insurance_hour() -> int:
	var t := 0.0
	for v in owned:
		var sp := spec(str(v.id))
		t += (INSURANCE_DRIVE if sp.use == "drive" else INSURANCE_HAUL) * (HALCYON_INSURANCE if sp.maker == "halcyon" else 1.0)
	return int(t)


func update(dt: float) -> void:
	if not ENABLED or (owned.is_empty() and not auto):
		return
	# insurance, by the second, in whole dollars
	_insured += float(insurance_hour()) * dt / 3600.0
	if _insured >= 1.0:
		var due := int(_insured)
		_insured -= due
		sess.move_money(-(mini(due, maxi(0, sess.money))), "outside:market", "fee")
	if auto:
		_auto_t += dt
		if _auto_t >= AUTO_EVERY_S:
			_auto_t = 0.0
			_auto_buy()


## The AI's rule: the best truck it can pay for with AUTO_RESERVE left over, if it beats the fleet it has.
func _auto_buy() -> void:
	if sess.logistics == null:
		return
	var f := fleet()
	var pick := ""
	var best := 0.0
	for sp in CATALOGUE:
		if sp.use != "haul" or why_not(str(sp.id), true) != "" or sess.money - int(sp.price) < AUTO_RESERVE:
			continue
		# worth: the speed it adds, its cover and its armour, per $10,000
		var gain := maxf(0.0, float(sp.speed) - float(f.speed)) / 3.0 + maxf(0.0, float(sp.stealth) - float(f.stealth)) * 2.0 + maxf(0.0, float(sp.armour) - float(f.armour)) * 1.2
		var score := gain / (float(sp.price) / 10000.0)
		if gain > 0.15 and score > best:
			best = score
			pick = str(sp.id)
	if pick != "":
		buy(pick, true)


## The small view the seats' snapshots carry (the talk with the dealer reads it): id -> [price, can buy, use] and what is owned.
func view_lite() -> Dictionary:
	var cat := {}
	for sp in CATALOGUE:
		cat[str(sp.id)] = [int(sp.price), why_not(str(sp.id)) == "", str(sp.use)]
	var cars := 0
	var trucks := 0
	var last_car := {}
	var last_truck := {}
	for v in owned:
		var sp := spec(str(v.id))
		var row := {"serial": int(v.serial), "name": str(sp.name), "resale": resale(str(sp.id))}
		if sp.use == "drive":
			cars += 1
			last_car = row
		else:
			trucks += 1
			last_truck = row
	var f := fleet()
	return {"cat": cat, "cars": cars, "trucks": trucks, "last_car": last_car, "last_truck": last_truck, "insurance": insurance_hour(), "auto": auto,
		"speed": int(float(f.speed) * 3.6), "cover": int(float(f.stealth) * 100.0), "steel": int(float(f.armour) * 100.0), "limit": MAX_OWNED, "sets": sets_line()}


func view() -> Dictionary:
	var cat := []
	for sp in CATALOGUE:
		var c: Dictionary = sp.duplicate()
		c["can_buy"] = why_not(str(sp.id)) == ""
		cat.append(c)
	var mine := []
	for v in owned:
		var sp := spec(str(v.id))
		mine.append({"serial": int(v.serial), "id": str(v.id), "name": str(sp.name), "use": str(sp.use), "resale": resale(str(sp.id)), "active": int(v.serial) == active})
	return {"catalogue": cat, "owned": mine, "active": active, "fleet": fleet(), "insurance": insurance_hour(), "auto": auto, "spent": spent,
		"limit": MAX_OWNED, "sets": sets_line()}
