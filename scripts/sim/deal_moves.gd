class_name DealMoves
extends RefCounted
## Loop idea 5 (docs/LOOP_IDEAS.md): the deal moves mid-flight. On the way to an airdrop the phone rings: the boat has moved the drop
## some 8 km, the pay doubles, but a Coast Guard cutter is on picket near the new point. Answer to take it, decline to keep the old one.
##
## One offer per job at most, only in the air and still well short of the drop, and only when a person is flying (`live`: the pilot app
## sets it; the bots and balance sims never get a call). Own RNG stream (seed + 173). Off for the Python replays (Switches.PARITY).

static var ENABLED := true

const CHANCE_PER_MIN := 0.12  ## while it can happen, about one flight in three hears from Benny
const MIN_LEFT_M := 6000.0  ## at least this far from the drop: a change at the last minute is no use to anyone
const MOVE_M := 8000.0
const PAY_MULT := 2.0
const CUTTER_OFFSET_M := 1800.0  ## the cutter waits this far from the new point
const RING_S := 30.0
const PICKET_S := 1500.0  ## the cutter holds its picket this long: long enough for the pilot to fly the detour

var sess
var rng: PyRandom
var live := false  ## a human is flying (PilotApp.setup)
var offered := {}  ## job id -> true: each job hears from Benny once
var pending := {}  ## job id -> the new point [x, y] while the phone rings
var _t := 0.0


func _init(sess_, rng_: PyRandom) -> void:
	sess = sess_
	rng = rng_


func update(dt: float) -> void:
	if not ENABLED or not live or sess.state == null or sess.state.on_ground:
		return
	_t += dt
	if _t < 60.0:
		return
	_t = 0.0
	for j in sess.active_jobs:
		if not j.is_airdrop() or offered.has(j.id) or not _bales_aboard(j.id) or not _boat_on_station(j):
			continue  # nothing left aboard (the bales are already in the sea): no deal to move
		if PyMath.hypot(float(j.drop_point[0]) - sess.state.x, float(j.drop_point[1]) - sess.state.y) < MIN_LEFT_M:
			continue
		if rng.random() >= CHANCE_PER_MIN:
			continue
		var p := _new_point(j.drop_point)
		offered[j.id] = true
		if p.is_empty():
			continue  # nowhere at sea to move it to: the boat stays put
		pending[j.id] = p
		sess.phone_calls.enqueue("deal_move", "Benny Ruiz", sess.time, RING_S, "deal:" + str(j.id))
		sess.say("PHONE - Benny: they moved the drop %.0f km. Pay doubles, but there's a cutter out there. Answer to take it (T / Shift+T), decline to keep the old point." % (MOVE_M / 1000.0))
		return


## A point MOVE_M away at sea, tried in eight directions from a random start; [] if none is water.
func _new_point(old: Array) -> Array:
	var a0 := rng.uniform(0.0, TAU)
	for k in 8:
		var a := a0 + k * TAU / 8.0
		var x: float = float(old[0]) + sin(a) * MOVE_M
		var y: float = float(old[1]) + cos(a) * MOVE_M
		if absf(x) < World.HALF - 1000.0 and absf(y) < World.HALF + 8000.0 and sess.world.is_water(x, y):
			return [x, y]
	return []


## The pilot answered: the drop, the boat's course and the pay change, and a cutter takes up picket near the new point.
func accept(job_id: int) -> String:
	if not pending.has(job_id):
		return "That deal is off."
	var p: Array = pending[job_id]
	pending.erase(job_id)
	var j = Py.first(sess.active_jobs, func(x): return x.id == job_id)
	if j == null:
		return "That job is gone."
	if not _bales_aboard(job_id):
		return "The bales are already in the water: the deal stands where it was."
	if not _boat_on_station(j):
		return "The boat has gone home: there is no drop to move."
	j.drop_point = p
	j.payout = int(round(j.payout * PAY_MULT))
	if j.boat_id:
		var b = sess.maritime.boat(j.boat_id)
		if b != null and b.state in ["to_rendezvous", "waiting"]:
			b.goal = p  # a boat already waiting at the old point goes to the new one, its wait started afresh
			b.state = "to_rendezvous"
			b.wait_t = 0.0
		elif b != null and b.state == "fleeing":
			b.goal = p  # hiding from a cutter: when it comes back for the drop it comes to the new point
			b.wait_t = 0.0  # and waits there afresh, not for what was left of the old wait
	var at := _picket_point(p)
	var cutter: Maritime.Boat = sess.maritime.new_cutter(null, at)
	cutter.picket_s = PICKET_S
	sess.say("New drop point set: %s pays $%s now. Watch for the cutter." % [j.title, Py.money(j.payout)])
	return ""


## Where the cutter waits: CUTTER_OFFSET_M from the new point, at sea (eight bearings from a random start, then nearer in); the drop
## itself as a last resort, which _new_point already found to be water. A cutter spawned on land could never move.
func _picket_point(p: Array) -> Array:
	var a0 := rng.uniform(0.0, TAU)
	for r in [CUTTER_OFFSET_M, CUTTER_OFFSET_M * 0.5]:
		for k in 8:
			var a := a0 + k * TAU / 8.0
			var x: float = float(p[0]) + sin(a) * r
			var y: float = float(p[1]) + cos(a) * r
			if sess.world.is_water(x, y):
				return [x, y]
	return [float(p[0]), float(p[1])]


## The go-fast is still out for this drop (on its way, waiting or hiding from a cutter), not running home or done.
func _boat_on_station(j) -> bool:
	if not j.boat_id:
		return true
	var b = sess.maritime.boat(j.boat_id)
	return b != null and b.state in ["to_rendezvous", "waiting", "fleeing"]


func _bales_aboard(job_id: int) -> bool:
	return sess.loadout.items.values().any(func(i): return i.job_id == job_id)


func decline(job_id: int) -> void:
	if pending.has(job_id):
		pending.erase(job_id)
		sess.say("Keeping the old drop point.")
