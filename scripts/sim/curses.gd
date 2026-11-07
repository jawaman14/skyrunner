class_name Curses
extends RefCounted
## Cursed jobs (owner, 7 Nov, D-95: the Borderlands study's round two, its optional modifiers that pay more). A job on the board
## can carry an optional condition the client asks for, with a stated premium. Take it (X on the job board, before accepting) and
## fly the job under it: kept to the end, the premium is paid on delivery on top of the job's pay; broken, it is lost, and only
## the premium: the job itself pays as it always did. Nothing else rides on it, so the choice is pure risk against reward.
##
##   low     Under the radar: never above LOW_AGL_M after take-off                       +30%
##   squawk  Nothing to hide: transponder on the whole flight                             +35%
##   hands   Hands on: no autopilot and no AI pilot                                       +20%
##   gentle  Fragile: touch down at the destination at GENTLE_FPM or less                  +25%
##   clock   On the clock: land at the destination within the stated minutes of take-off   +30%
##
## About one eligible job in OFFER_IN (cargo, passengers, contraband; not airdrops, side gigs, the employer's work or a windfall)
## carries one, drawn when the board is dealt on its own stream (seed + 189). Behind ENABLED (in the parity set).

static var ENABLED := true

const OFFER_IN := 4
const LOW_AGL_M := 150.0
const GENTLE_FPM := 250.0
const CLOCK_MS := 45.0  ## the clock's speed: the straight line at this, plus CLOCK_SLACK_S
const CLOCK_SLACK_S := 240.0
const KINDS := ["cargo", "passenger", "contraband", "medical", "fugitive"]

## id -> [the condition, the premium as a share of the job's pay]
const LIST := {
	"low": ["Under the radar: never above %d m off the ground after take-off" % int(LOW_AGL_M), 0.30],
	"squawk": ["Nothing to hide: the transponder on the whole flight", 0.35],
	"hands": ["Hands on: no autopilot and no AI pilot", 0.20],
	"gentle": ["Fragile: touch down at the destination at %d fpm or less" % int(GENTLE_FPM), 0.25],
	"clock": ["On the clock: land at the destination within %d minutes of take-off", 0.30],
}
const ORDER := ["low", "squawk", "hands", "gentle", "clock"]

var sess
var rng: PyRandom
var taken := {}  ## job id -> {curse, broken, why, until, premium, dest}
var kept := 0  ## premiums earned
var broken := 0  ## premiums lost


func _init(sess_, rng_: PyRandom) -> void:
	sess = sess_
	rng = rng_
	sess.bus.subscribe("job_accepted", _on_accepted)
	sess.bus.subscribe("job_delivered", _on_delivered)


func _on_accepted(e) -> void:
	if sess != null and e.data.has("job_id"):
		_accepted(int(e.data.job_id))


func _on_delivered(e) -> void:
	if sess != null and e.data.has("job_id"):
		_delivered(int(e.data.job_id), str(e.data.get("dest", "")))


static func eligible(j) -> bool:
	return (j.kind in KINDS and not j.is_airdrop() and j.checkpoints.is_empty() and j.employer_serial <= 0
		and not str(j.title).begins_with("Windfall"))


## Deal the board's offers: about one eligible job in OFFER_IN gets a condition.
func offer(board: Array) -> void:
	if not ENABLED:
		return
	for j in board:
		if not eligible(j) or j.curse != "":
			continue
		if rng.randint(1, OFFER_IN) != 1:
			continue
		j.curse = str(ORDER[rng.randint(0, ORDER.size() - 1)])


## The minutes the clock gives this job (the straight line at CLOCK_MS, plus the slack).
static func clock_s(j) -> float:
	var a := World.airfield(str(j.origin))
	var b := World.airfield(str(j.dest))
	if a == null or b == null:
		return CLOCK_SLACK_S
	return PyMath.hypot(b.x - a.x, b.y - a.y) / CLOCK_MS + CLOCK_SLACK_S


## The condition as the board shows it.
static func line(j) -> String:
	if j.curse == "" or not LIST.has(j.curse):
		return ""
	var text: String = LIST[j.curse][0]
	if j.curse == "clock":
		text = text % int(ceil(clock_s(j) / 60.0))
	return "%s (+%d%%, $%s)" % [text, int(round(float(LIST[j.curse][1]) * 100.0)), Py.money(premium(j))]


static func premium(j) -> int:
	if j.curse == "" or not LIST.has(j.curse):
		return 0
	return int(round(float(j.payout) * float(LIST[j.curse][1]) / 50.0)) * 50


## X on the board: take the condition (or leave it). Only a job still on the board.
static func toggle(j) -> String:
	if j.curse == "":
		return "This client asks for nothing extra."
	j.cursed = not j.cursed
	return ("Taken: %s." if j.cursed else "Left: %s.") % line(j)


func _accepted(id: int) -> void:
	for j in sess.active_jobs:
		if j.id == id and j.cursed and j.curse != "":
			taken[id] = {"curse": j.curse, "broken": false, "why": "", "until": -1.0, "premium": premium(j), "dest": str(j.dest),
				"clock": clock_s(j)}
			sess.say("The client's condition: %s. Keep it and the premium is yours." % line(j))


func _break(id: int, why: String) -> void:
	var t: Dictionary = taken[id]
	if t.broken:
		return
	t.broken = true
	t.why = why
	broken += 1
	var text := "Condition broken (%s): no premium on this one." % why
	sess.say(text)
	sess.bus.emit("curse_broken", sess.time, text, ["runner"], {"job_id": id, "curse": t.curse, "why": why})


## Each tick: the conditions that are kept in flight.
func update(bot_flying: bool) -> void:
	if taken.is_empty():
		return
	var ids := {}
	for j in sess.active_jobs:
		ids[j.id] = true
	for id in taken.keys():
		if not ids.has(id):
			taken.erase(id)  # dropped, seized or lost: nothing to pay
	var s = sess.state
	var up: bool = sess.log != null and sess.log.airborne and not s.on_ground
	for id in taken:
		var t: Dictionary = taken[id]
		if t.broken:
			continue
		if up and float(t.until) < 0.0:
			t.until = sess.time + float(t.clock)  # the clock starts at take-off
		match str(t.curse):
			"low":
				if up and s.agl > LOW_AGL_M:
					_break(id, "climbed above %d m" % int(LOW_AGL_M))
			"squawk":
				if up and not sess.transponder:
					_break(id, "the transponder went off")
			"hands":
				if up and (sess.autopilot.engaged or bot_flying):
					_break(id, "the autopilot flew it")
			"clock":
				if float(t.until) >= 0.0 and sess.time > float(t.until):
					_break(id, "out of time")


func _delivered(id: int, dest: String) -> void:
	if not taken.has(id):
		return
	var t: Dictionary = taken[id]
	taken.erase(id)
	if not t.broken and t.curse == "gentle" and sess.log != null and float(sess.log.last_touchdown_fpm) > GENTLE_FPM:
		t.broken = true
		broken += 1
		var text := "Condition broken (touched down at %d fpm): no premium." % int(sess.log.last_touchdown_fpm)
		sess.say(text)
		sess.bus.emit("curse_broken", sess.time, text, ["runner"], {"job_id": id, "curse": t.curse, "why": "a hard landing"})
		return
	if t.broken:
		return
	kept += 1
	sess.move_money(int(t.premium), "outside:clients", "premium")
	var text := "Condition kept: the client pays the $%s premium." % Py.money(int(t.premium))
	sess.say(text)
	sess.bus.emit("curse_kept", sess.time, text, ["runner"], {"job_id": id, "curse": t.curse, "premium": int(t.premium), "dest": dest})


## The board offers live on the jobs (Jobs.SAVE_KEYS); this keeps the counts and the stream. Jobs in flight are not saved.
func capture() -> Dictionary:
	return {"kept": kept, "broken": broken, "rng": rng.get_state()}


func restore(d: Dictionary) -> void:
	kept = int(d.get("kept", 0))
	broken = int(d.get("broken", 0))
	if d.get("rng") is Array:
		rng.set_state(d.rng)
