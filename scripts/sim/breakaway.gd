class_name Breakaway
extends RefCounted
## Breakaway (owner, 7 Nov, D-95: the Borderlands study's "Fight For Your Life"). A stop on the ground is no longer the end of the
## run in one event: an arrest on landing (customs, a patrol, a wanted pilot), a raid while the load is being counted out, or a
## sting opens a window of WINDOW_S seconds, and the pilot gets out one of three ways:
##   run   take off and get RUN_M from where he was stopped: free, but the patrol is on his tail (wanted 1, suspicion +HEAT_RUN);
##   dump  leave the hot load to them (it is seized as a bust's would be): free, with suspicion +HEAT_DUMP;
##   pay   put money in the officer's hand (bribe(): BRIBE_BASE plus BRIBE_SHARE of the hot load's pay, more the hotter he is):
##         free, with suspicion +HEAT_PAY.
## The window running out is the bust exactly as it was (Session._bust_now), so nothing after it changes.
##
## Earned, not free (owner): one breakaway an island day, one more for every second renown tier (allowance()). After one, the
## task force is on alert for ALERT_S seconds and the next stop goes straight through. The air chase keeps its own escape (the
## bust meter); being arrested on foot is the foot fight's. No random draws, so no stream: every way out is the player's choice.
##
## Behind ENABLED (in the parity set); with it off a stop is the bust it always was.

static var ENABLED := true

const WINDOW_S := 45.0  ## long enough to start up, roll and climb away from a strip; short enough to have to decide
const RUN_M := 1200.0  ## airborne and this far from the stop is clear
const ALERT_S := 600.0  ## after a breakaway the next stop goes through
const DAY_S := 86400.0
const BRIBE_BASE := 2000
const BRIBE_SHARE := 0.4  ## of the hot load's pay
const HEAT_RUN := 25.0
const HEAT_DUMP := 10.0
const HEAT_PAY := 5.0

var sess
var how := ""  ## what the stop was ("arrested on landing at ..."), for the bust if the window runs out
var until := -1.0  ## when the window shuts (-1: no stop under way)
var at := [0.0, 0.0]  ## where the pilot was stopped
var day := -1  ## the island day the count below is for
var used := 0  ## breakaways started today
var last_free := -1e9  ## when the last one got away (the alert)
var covered := false  ## dumped or paid: the stop is settled, and nobody at this spot stops him again until he leaves (or ALERT_S passes)
var resume := ""  ## what the stop interrupted, picked up again once it is settled: "arrive" (the landing) or "unload" (the count)
var resume_af := ""  ## the airfield of an interrupted landing
var held: Array = []  ## job ids being counted out when a raid stopped it
var lose: Array = []  ## job ids gone however he gets out (a sting's load: the Agency's buyer was the DEA)


func _init(sess_) -> void:
	sess = sess_


func active() -> bool:
	return until >= 0.0


## Breakaways an island day at a renown tier: one, and one more for every second tier.
static func allowance(tier: int) -> int:
	return 1 + tier / 2


func _tier() -> int:
	return sess.renown.tier() if sess.renown != null else 0


## Breakaways left today.
func left() -> int:
	var d := int(sess.time / DAY_S)
	return allowance(_tier()) - (used if d == day else 0)


func can_start() -> bool:
	return ENABLED and not active() and left() > 0 and sess.time - last_free >= ALERT_S


func seconds_left() -> float:
	return maxf(0.0, until - sess.time) if active() else 0.0


func start(how_: String) -> void:
	var d := int(sess.time / DAY_S)
	if d != day:
		day = d
		used = 0
	used += 1
	how = how_
	covered = false
	resume = ""
	resume_af = ""
	held = []
	lose = []
	until = sess.time + WINDOW_S
	at = [sess.state.x, sess.state.y]
	var line := "STOPPED (%s). %d s to get out: take off and get clear, 1 dump the load, 2 pay him off ($%s)." % [
		how, int(WINDOW_S), Py.money(bribe())]
	sess.say(line)
	sess.bus.emit("breakaway", sess.time, line, ["runner", "law"], {"how": how, "bribe": bribe(), "seconds": WINDOW_S})


## What the hot load pays (what a bribe is a share of).
func _hot_value() -> float:
	var v := 0.0
	for j in sess.active_jobs:
		if j.hot():
			v += float(j.payout)
	return v


func bribe() -> int:
	var heat: float = sess.police.case("runner").suspicion if sess.police != null else 0.0
	return int(round((BRIBE_BASE + BRIBE_SHARE * _hot_value()) * (1.0 + heat / 100.0) / 50.0)) * 50


## Each tick while a window is open: clear of the stop in the air is a run; the window shutting is the bust.
func update() -> void:
	var s = sess.state
	if covered and not s.on_ground and PyMath.hypot(s.x - float(at[0]), s.y - float(at[1])) >= RUN_M:
		covered = false  # gone from the stop: the next one is a new one
	if not active():
		return
	if sess.phase in ["crashed", "busted"]:
		cancel()  # the flight ended some other way
		return
	if not s.on_ground and PyMath.hypot(s.x - float(at[0]), s.y - float(at[1])) >= RUN_M:
		_free("run")
	elif sess.time >= until:
		var h := how
		cancel()
		sess.say("Out of time.")
		sess._bust_now(h)


## Leave the hot load to them.
func dump() -> Array:
	if not active():
		return [false, "Nobody has stopped you."]
	var hot: Array = sess.active_jobs.filter(func(j): return j.hot())
	if hot.is_empty():
		return [false, "There's nothing hot aboard to give them."]
	for j in hot:
		sess.econ.record_seizure(Economy.good_of(j), Economy.job_market(j))
		sess._seize_weapons(Arsenal.weapons_of(j), "the aircraft")
		sess.loadout.remove_job(j.id)
		sess.active_jobs.erase(j)
	sess.unloading = []  # (the cash bags aboard stay: money isn't contraband)
	held = []
	_free("dump")
	return [true, "You left them the load and walked."]


## Put money in the officer's hand.
func pay() -> Array:
	if not active():
		return [false, "Nobody has stopped you."]
	var b := bribe()
	if sess.money < b:
		return [false, "He wants $%s and you have $%s." % [Py.money(b), Py.money(sess.money)]]
	sess.move_money(-b, "outside:police", "bribe")
	_free("pay")
	return [true, "$%s changed hands. Nobody saw anything." % Py.money(b)]


func _free(way: String) -> void:
	until = -1.0
	last_free = sess.time
	for id in lose:
		for j in sess.active_jobs.filter(func(j): return j.id == id):
			sess.loadout.remove_job(j.id)
			sess.active_jobs.erase(j)
	lose = []
	if sess.fm != null:
		sess.fm.apply_loadout(sess.loadout)  # a load lighter: the aircraft flies it
	covered = way != "run"
	if sess.police != null:
		var c = sess.police.case("runner")
		c.suspicion = minf(100.0, c.suspicion + float({"run": HEAT_RUN, "dump": HEAT_DUMP, "pay": HEAT_PAY}[way]))
		if way == "run":
			c.wanted = maxi(c.wanted, 1)
	var line: String = {"run": "You got away. They have your number now.", "dump": "Free, and a load lighter.",
		"pay": "Free. The officer's pocket is heavier."}[way]
	sess.say("BREAKAWAY: " + line)
	sess.bus.emit("broke_away", sess.time, line, ["runner", "law"], {"how": how, "way": way})
	var r := resume
	var af := resume_af
	var ids := held
	resume = ""
	resume_af = ""
	held = []
	if way != "run":
		sess._after_breakaway(r, af, ids)  # still parked: what the stop interrupted goes on


## A breakable stop at the spot that was settled (dumped or paid), within the alert after it: nobody stops him twice for it.
func settled_here() -> bool:
	var s = sess.state
	return covered and sess.time - last_free < ALERT_S and PyMath.hypot(s.x - float(at[0]), s.y - float(at[1])) < RUN_M


## A second stop while a window is open: no second chance.
func cancel() -> void:
	until = -1.0
	resume = ""
	resume_af = ""
	held = []
	lose = []


func capture() -> Dictionary:
	return {"how": how, "until": until, "at": at.duplicate(), "day": day, "used": used, "last_free": last_free, "covered": covered,
		"resume": resume, "resume_af": resume_af, "held": held.duplicate(), "lose": lose.duplicate()}


func restore(d: Dictionary) -> void:
	how = str(d.get("how", ""))
	until = float(d.get("until", -1.0))
	var a: Array = d.get("at", [0.0, 0.0])
	at = [float(a[0]), float(a[1])]
	day = int(d.get("day", -1))
	used = int(d.get("used", 0))
	last_free = float(d.get("last_free", -1e9))
	covered = bool(d.get("covered", false))
	resume = str(d.get("resume", ""))
	resume_af = str(d.get("resume_af", ""))
	held = Array(d.get("held", [])).map(func(x): return int(x))
	lose = Array(d.get("lose", [])).map(func(x): return int(x))
