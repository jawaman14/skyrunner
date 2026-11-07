class_name Wanted
extends RefCounted
## Wanted names (owner, 7 Nov, D-95: the Borderlands study's dedicated drops). A few rival lieutenants and task-force captains
## have names, and each carries one signature prize. Every EVERY-th squad Los Cuervos or the task force raises is led by the next
## name on its roster that is still at large (and not already in the field). Beating that squad in a fight (a rout, by the
## organisation) is a take-down, and each take-down has a stated 1 in ODDS chance of the prize; while it hasn't dropped he gets
## away and leads again later, so he can be hunted. Once his prize has dropped he's finished, and the roster moves on.
##
## The first time an organisation squad fights him, he gets a title card (his name, his outfit, what he's known for) on the
## radio and as a `wanted_seen` event. The prizes use systems that already exist: an arms cache into the organisation's
## arsenal, a cartel man's take (Los Cuervos' cash to the safe), a captain's file (suspicion off the organisation's case).
##
## A named rival squad that surrenders to the task force puts him in custody: off the roster, no prize.
## Own RNG stream (seed + 187), drawn only on a take-down, saved with the roster. Behind ENABLED (in the parity set); built with the ground war.

static var ENABLED := true

const EVERY := 3  ## one squad in three raised by an outfit is led by a name
const ODDS := 3  ## a take-down drops the prize 1 time in 3

## id, name, outfit, the line on his card, and his prize: kind + amount.
##   cache: weapons of a tier into the organisation's arsenal;  take: dollars from Los Cuervos' chest to the safe;
##   file: suspicion off the organisation's case.
const ROSTER := [
	{"id": "tuerto", "name": "Ramon \"El Tuerto\" Salcedo", "outfit": "rival", "card": "one eye, two warehouses",
		"prize": {"kind": "cache", "tier": "rifle", "n": 8, "what": "his rifle cache"}},
	{"id": "flaca", "name": "Lidia \"La Flaca\" Orozco", "outfit": "rival", "card": "keeps the cartel's books in her head",
		"prize": {"kind": "take", "usd": 9000, "what": "the week's take"}},
	{"id": "padrino", "name": "Hector \"Padrino\" Villalba", "outfit": "rival", "card": "nobody has seen him lose a fight",
		"prize": {"kind": "cache", "tier": "mg", "n": 3, "what": "his machine guns"}},
	{"id": "rook", "name": "Captain Dale Rourke", "outfit": "police", "card": "runs the task force's informants",
		"prize": {"kind": "file", "heat": 25.0, "what": "his informant file"}},
	{"id": "marsh", "name": "Captain Irene Marsh", "outfit": "police", "card": "never lost a case at trial",
		"prize": {"kind": "file", "heat": 35.0, "what": "the case file on you"}},
]

var sess
var rng: PyRandom
var raised := {"rival": 0, "police": 0}  ## squads each outfit has raised (every EVERY-th gets a name)
var done := {}  ## id -> true: prize dropped, finished
var seen := {}  ## id -> true: his card has been shown
var takedowns := {}  ## id -> times beaten


func _init(sess_, rng_: PyRandom) -> void:
	sess = sess_
	rng = rng_


static func entry(id: String) -> Dictionary:
	for e in ROSTER:
		if e.id == id:
			return e
	return {}


## A new squad of `outfit`: the name that leads it, or "".
func assign(outfit: String, squads: Array) -> String:
	if not raised.has(outfit):
		return ""
	raised[outfit] = int(raised[outfit]) + 1
	if int(raised[outfit]) % EVERY != 0:
		return ""
	var in_field := {}
	for q in squads:
		if q.state != "gone" and str(q.get("leader")) != "":
			in_field[q.leader] = true
	for e in ROSTER:
		if e.outfit == outfit and not done.has(e.id) and not in_field.has(e.id):
			return e.id
	return ""


## The first fight against him: his card.
func contact(leader: String) -> void:
	if leader == "" or seen.has(leader):
		return
	seen[leader] = true
	var e := entry(leader)
	var line := "WANTED: %s, %s - %s." % [e.name, "Los Cuervos" if e.outfit == "rival" else "the task force", e.card]
	sess.say(line)
	sess.bus.emit("wanted_seen", sess.time, line, ["runner"], {"id": leader, "name": e.name, "outfit": e.outfit})


## His squad surrendered to the task force: in custody, so he is off the roster (no prize: the organisation didn't take him).
func captured(leader: String) -> void:
	if leader == "" or done.has(leader):
		return
	done[leader] = true
	var e := entry(leader)
	var line := "%s is in custody. The task force got to him first." % e.name
	sess.say(line)
	sess.bus.emit("wanted_captured", sess.time, line, ["runner", "law"], {"id": leader})


## He was beaten by the organisation: roll for his prize.
func taken_down(leader: String) -> void:
	if leader == "" or done.has(leader):
		return
	var e := entry(leader)
	takedowns[leader] = int(takedowns.get(leader, 0)) + 1
	if rng.randint(1, ODDS) != 1:
		var line := "%s got away again. He'll be back." % e.name
		sess.say(line)
		sess.bus.emit("wanted_escaped", sess.time, line, ["runner"], {"id": leader})
		return
	done[leader] = true
	var got := _grant(e.prize)
	var line2 := "%s is finished. You took %s%s." % [e.name, e.prize.what, got]
	sess.say(line2)
	sess.bus.emit("wanted_prize", sess.time, line2, ["runner"], {"id": leader, "prize": e.prize.duplicate()})


func _grant(p: Dictionary) -> String:
	match str(p.kind):
		"cache":
			var ars = sess.arsenals.get("org")
			if ars == null:
				return ""
			ars.add(str(p.tier), int(p.n))
			return " (%d %s to the armoury)" % [int(p.n), str(Arsenal.TIERS[p.tier].name).to_lower()]
		"take":
			var usd := int(p.usd)
			if sess.ground != null and sess.ground.commanders.has("rival"):
				usd = mini(usd, maxi(0, int(sess.ground.commanders.rival.cash)))
				sess.ground.commanders.rival.move_cash(-usd, "outside:street", "seized", true)
			sess.move_money(usd, "outside:street", "seized")
			return " ($%s)" % Py.money(usd)
		"file":
			if sess.police != null:
				var c = sess.police.case("runner")
				c.suspicion = maxf(0.0, c.suspicion - float(p.heat))
			return " (the heat on you is down)"
	return ""


func capture() -> Dictionary:
	return {"raised": raised.duplicate(), "done": done.keys(), "seen": seen.keys(), "takedowns": takedowns.duplicate(), "rng": rng.get_state()}


func restore(d: Dictionary) -> void:
	for k in d.get("raised", {}):
		raised[str(k)] = int(d.raised[k])
	done = {}
	for id in d.get("done", []):
		done[str(id)] = true
	seen = {}
	for id in d.get("seen", []):
		seen[str(id)] = true
	takedowns = {}
	for k in d.get("takedowns", {}):
		takedowns[str(k)] = int(d.takedowns[k])
	if d.get("rng") is Array:
		rng.set_state(d.rng)  # the prize rolls carry on where they were, so a reload can't replay a miss
