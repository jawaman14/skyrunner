class_name Races
extends RefCounted
## The arena (Mount & Blade's tournaments): races for prize money and a name. Two courses at the airfield you are
## at: a STREET race in the car (the roads from the strip to the club and a stash house and back, the gates every
## half a kilometre, needs a ground war for its roads) and an AIR circuit (six gates round the strip, 180 m up).
##
## Enter one (the phone: "The track"): the fee is paid, the first gate is the start - the clock starts when you
## cross it - and the gates have to be taken in order. A field of four rivals runs against the clock; where your
## time falls among theirs is your place: first takes the prize, second half, third a quarter, and a name
## (Renown +6 / +3 / +1). A course pays once an hour. Getting out of the car, landing from the circuit, or taking
## three times the par time forfeits the fee.
##
## The rivals' times come from their own random stream, so the field is the same every time for a given session.
## Off for the replays (Races.ENABLED = false); a session asks with `races: true`.

static var ENABLED := true

const GATE_EVERY_M := 500.0
const STREET_MAX_M := 10000.0  ## the street race is a loop of about this long at most
const CAR_GATE_R := 24.0
const AIR_GATE_R := 130.0
const AIR_GATE_DZ := 110.0  ## vertical tolerance
const AIR_GATE_AGL := 180.0
const AIR_RADIUS_M := 2500.0
const AIR_GATES := 6
const CAR_MS := 19.0  ## what the field's cars average over the roads
const AIR_MS := 42.0  ## ... and its aeroplanes
const FIELD := 4
const CAR_PRIZE := 700
const AIR_PRIZE := 1400
const FEE_SHARE := 0.1
const PAYS_EVERY_S := 3600.0  ## a course pays once an hour
const TIME_LIMIT := 3.0  ## x par
const PLACE_SHARE := [1.0, 0.5, 0.25]
const RENOWN_BY_PLACE := [0.0, 6.0, 3.0, 1.0]  ## (index by place: 1..3) renown
const BET_STEPS := [0, 100, 200, 300]  ## the stakes the book takes, $ (on a race that is paying: see enter())
const BET_ODDS := {"win": 3.0, "place": 1.5}  ## a winning bet pays stake x this (place = in the top three); the stake is not returned

class Course:
	var id := ""
	var name := ""
	var kind := "car"  ## car | air
	var gates: Array = []  ## [Vector3(x, y, z)] (z: metres above sea level for the circuit, 0 for the street)
	var radius := 24.0
	var length_m := 0.0
	var par_s := 0.0
	var fee := 0
	var prize := 0

	func dict() -> Dictionary:
		return {"id": id, "name": name, "kind": kind, "length": length_m, "par": par_s, "fee": fee, "prize": prize, "gates": gates.size()}


var sess
var run: Dictionary = {}  ## the one under way: {id, next, t0 (or -1: not started), splits: [], entered}
var paid_at := {}  ## course id -> sim time it last paid
var results: Array = []  ## [{id, name, place, time, prize, t}], newest last
var won := 0  ## $ in prizes
var betting := 0  ## $ won (or, below zero, lost) at the book, net of the stakes
var _cache: Array = []  ## the courses at the strip we are at (the roads are not cheap to find)
var _cache_key := ""


func _init(sess_) -> void:
	sess = sess_


# ------------------------------------------------------------------ the courses
## The courses at the airfield the aircraft is at (rebuilt each time: the strip moves).
func courses_here() -> Array:
	var af: Airfield = sess.airfield
	if af == null:
		return []
	var live: int = 0 if sess.stash_net == null else int(sess.stash_net.live().size())
	var key := "%s-%d-%s" % [af.code, live, sess.ground != null]
	if key == _cache_key:
		return _cache
	var out := []
	if sess.ground != null:
		var c := _street(af)
		if c != null:
			out.append(c)
	out.append(_circuit(af))
	_cache_key = key
	_cache = out
	return out


func course(id: String) -> Course:
	for c in courses_here():
		if c.id == id:
			return c
	return null


func _street(af: Airfield) -> Course:
	var here := Vector2(af.x, af.y)
	# the places worth racing to: the club and the stash houses, nearest first (but not on top of the strip)
	var near: Array = [sess.ground.hq("org")]
	for st in (sess.stash_net.live() if sess.stash_net != null else []):
		near.append(Vector2(st.x, st.y))
	near = near.filter(func(p): return p.distance_to(here) > 400.0)
	near.sort_custom(func(a, b): return a.distance_to(here) < b.distance_to(here))
	var waypoints: Array = near.slice(0, 2)
	var path := PackedVector2Array()
	while true:
		path = _loop(here, waypoints)
		if path.size() < 2 or RoadGraph.length(path) <= STREET_MAX_M or waypoints.size() <= 1:
			break
		waypoints.pop_back()  # too long: drop the farther place
	if path.size() < 2:
		return null
	var c := Course.new()
	c.id = "car-" + af.code
	c.name = "The %s dash" % af.name
	c.kind = "car"
	c.radius = CAR_GATE_R
	c.length_m = RoadGraph.length(path)
	c.gates = _along(path, GATE_EVERY_M)
	c.par_s = c.length_m / CAR_MS
	c.prize = CAR_PRIZE
	c.fee = int(CAR_PRIZE * FEE_SHARE)
	return c


## The roads from `here` through each waypoint and back, as one path.
func _loop(here: Vector2, waypoints: Array) -> PackedVector2Array:
	var pts: Array = [here]
	pts.append_array(waypoints)
	pts.append(here)
	var path := PackedVector2Array()
	for i in pts.size() - 1:
		var leg: PackedVector2Array = sess.ground.route("org", pts[i], pts[i + 1])
		for k in leg.size():
			if path.is_empty() or path[path.size() - 1].distance_to(leg[k]) > 0.5:
				path.append(leg[k])
	return path


## Points every `step` metres along a path, the first the start and the last the end.
static func _along(path: PackedVector2Array, step: float) -> Array:
	var out: Array = [Vector3(path[0].x, path[0].y, 0.0)]
	var carry := 0.0
	for i in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		var d := a.distance_to(b)
		var pos := step - carry
		while pos <= d:
			var p := a.lerp(b, pos / d)
			out.append(Vector3(p.x, p.y, 0.0))
			pos += step
		carry = d - (pos - step)
	var last := Vector3(path[path.size() - 1].x, path[path.size() - 1].y, 0.0)
	if Vector2(out[out.size() - 1].x, out[out.size() - 1].y).distance_to(Vector2(last.x, last.y)) > 60.0:
		out.append(last)
	else:
		out[out.size() - 1] = last
	return out


func _circuit(af: Airfield) -> Course:
	var c := Course.new()
	c.id = "air-" + af.code
	c.name = "The %s circuit" % af.name
	c.kind = "air"
	c.radius = AIR_GATE_R
	var h := deg_to_rad(af.heading)
	var centre := Vector2(af.x, af.y) + Vector2(sin(h), cos(h)) * AIR_RADIUS_M  # out along the runway heading
	var pts: Array = []
	for k in AIR_GATES:
		var a := h + PI + TAU * float(k) / float(AIR_GATES)
		var p := centre + Vector2(sin(a), cos(a)) * AIR_RADIUS_M
		pts.append(Vector3(p.x, p.y, sess.world.ground(p.x, p.y) + AIR_GATE_AGL))
	pts.append(pts[0])  # round to the first again: the finish is the start
	c.gates = pts
	var total := 0.0
	for i in pts.size() - 1:
		total += Vector2(pts[i].x, pts[i].y).distance_to(Vector2(pts[i + 1].x, pts[i + 1].y))
	c.length_m = total
	c.par_s = total / AIR_MS
	c.prize = AIR_PRIZE
	c.fee = int(AIR_PRIZE * FEE_SHARE)
	return c


# ------------------------------------------------------------------ entering and running
func active() -> bool:
	return not run.is_empty()


## When the course pays again (0 when it is paying now).
func cooldown(id: String) -> float:
	return maxf(0.0, float(paid_at.get(id, -1e9)) + PAYS_EVERY_S - sess.time)


## Enter a race. `bet` is a stake on yourself (one of BET_STEPS) and `on` what it is on: "win" or "place" (top three).
## The book is only open on a race that is paying (a course that has paid within the hour takes no bets: that is what
## keeps betting from being a faster way to the same money), and a bet is lost if you drop out.
func enter(id: String, bet := 0, on := "win") -> String:
	if active():
		return "You are already in a race."
	var c := course(id)
	if c == null:
		return "No such race here."
	if c.kind == "car" and sess.ground == null:
		return "There are no roads to race on."
	if not BET_STEPS.has(bet):
		return "The book takes $100, $200 or $300."
	if bet > 0:
		if not BET_ODDS.has(on):
			return "Bet on a win or a place."
		if cooldown(id) > 0.0:
			return "The book is shut on that race: it paid within the hour."
	if sess.money < c.fee + bet:
		return "The entry is $%s%s." % [Py.money(c.fee), (" and the bet $%s" % Py.money(bet)) if bet > 0 else ""]
	sess.money -= c.fee + bet
	run = {"id": c.id, "next": 0, "t0": -1.0, "splits": [], "entered": sess.time, "bet": bet, "on": on}
	sess.say("RACE - %s: the fee is paid%s. Take the start gate (the first one) to begin; gates in order." % [c.name,
		(" and $%s down on a %s" % [Py.money(bet), on]) if bet > 0 else ""])
	return ""


func abort(why: String) -> void:
	if not active():
		return
	sess.say("RACE - out: %s. The fee is gone%s." % [why, (" and so is the $%s bet" % Py.money(int(run.get("bet", 0)))) if int(run.get("bet", 0)) > 0 else ""])
	run = {}


## The player's position, from the vehicle that counts for the course under way: "car" (the app feeds it) or "air"
## (the session does). Takes the next gate when close enough (and, for the circuit, at the right height).
func feed(kind: String, xy: Vector2, alt: float) -> void:
	if not active():
		return
	var c := course(str(run.id))
	if c == null or c.kind != kind:
		return
	var g: Vector3 = c.gates[int(run.next)]
	if xy.distance_to(Vector2(g.x, g.y)) > c.radius:
		return
	if kind == "air" and absf(alt - g.z) > AIR_GATE_DZ:
		return
	if int(run.next) == 0:
		run.t0 = sess.time
		sess.say("RACE - go! (%d gates)" % (c.gates.size() - 1))
	else:
		run.splits.append(sess.time - float(run.t0))
		sess.say("RACE - gate %d of %d: %s" % [int(run.next), c.gates.size() - 1, _clock(sess.time - float(run.t0))])
	run.next = int(run.next) + 1
	if int(run.next) >= c.gates.size():
		_finish(c)


func update(dt: float) -> void:
	if not active():
		return
	var c := course(str(run.id))
	if c == null:
		run = {}  # the strip it was run from is not where we are any more
		return
	if c.kind == "air" and sess.state != null:
		feed("air", Vector2(sess.state.x, sess.state.y), float(sess.state.alt))
		if sess.parked and float(run.t0) >= 0.0:
			abort("landed")
			return
	if float(run.t0) >= 0.0 and sess.time - float(run.t0) > TIME_LIMIT * c.par_s:
		abort("too slow")


## The HUD's race chip: where you are in the race under way ("" when none is on).
func hud_line() -> String:
	if not active():
		return ""
	var c := course(str(run.id))
	if c == null:
		return ""
	if float(run.t0) < 0.0:
		return "RACE  %s  take the start gate" % c.name
	var gates: int = c.gates.size() - 1
	var t: float = sess.time - float(run.t0)
	return "RACE  %s  gate %d/%d  %s  par %s" % [c.name, maxi(0, int(run.next) - 1), gates, _clock(t), _clock(c.par_s)]


func _clock(t: float) -> String:
	return "%d:%04.1f" % [int(t / 60.0), fmod(t, 60.0)]


## The field's times for a course: par over a spread of speeds. Same field for the same session and course.
func field(c: Course) -> Array:
	var r := PyRandom.new()
	r.seed(hash(c.id) + sess.seed)
	var out := []
	for i in FIELD:
		out.append(c.par_s * r.uniform(0.85, 1.35))
	out.sort()
	return out


func _finish(c: Course) -> void:
	var t: float = sess.time - float(run.t0)
	var place := 1
	for ft in field(c):
		if ft < t:
			place += 1
	var prize := 0
	var cool := cooldown(c.id)
	if place <= PLACE_SHARE.size():
		prize = int(float(c.prize) * float(PLACE_SHARE[place - 1]))
	if cool > 0.0:
		prize = 0  # it has paid within the hour: for the glory only
	if prize > 0:
		sess.money += prize
		won += prize
		paid_at[c.id] = sess.time
	var bet: int = int(run.get("bet", 0))
	var payout := 0
	if bet > 0:
		var hit: bool = (str(run.on) == "win" and place == 1) or (str(run.on) == "place" and place <= 3)
		if hit:
			payout = int(float(bet) * float(BET_ODDS[str(run.on)]))
			sess.money += payout
			betting += payout - bet
		else:
			betting -= bet
	if place <= 3 and sess.renown != null:
		sess.renown.add(float(RENOWN_BY_PLACE[place]), "placed %d in %s" % [place, c.name])
	results.append({"id": c.id, "name": c.name, "place": place, "time": t, "prize": prize, "bet": bet, "payout": payout, "t": sess.time})
	Py.keep_last(results, 20)
	sess.say("RACE - %s: %s, place %d of %d%s." % [c.name, _clock(t), place, FIELD + 1,
		(", $%s" % Py.money(prize)) if prize > 0 else (" (it paid within the hour)" if cool > 0.0 and place <= 3 else "")])
	if bet > 0:
		sess.say("RACE - the book: %s." % (("your $%s on a %s pays $%s" % [Py.money(bet), str(run.on), Py.money(payout)]) if payout > 0 else "your $%s on a %s is lost" % [Py.money(bet), str(run.on)]))
	sess.bus.emit("race_run", sess.time, "", ["runner"], {"id": c.id, "place": place, "time": t, "prize": prize})
	run = {}


func view() -> Dictionary:
	var rows := []
	for c in courses_here():
		var d: Dictionary = c.dict()
		d["cooldown"] = cooldown(c.id)
		d["field_best"] = field(c)[0]
		rows.append(d)
	return {"courses": rows, "run": run.duplicate(), "results": results.duplicate(true), "won": won, "betting": betting,
		"bet_steps": BET_STEPS, "odds": BET_ODDS}
