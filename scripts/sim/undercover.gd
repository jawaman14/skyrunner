class_name Undercover
extends RefCounted
## The task force's undercover agent: plants a tracking beacon on the runner's aircraft while it sits on the ground.
##
## A seat for a player (Roles.UNDERCOVER); the AI chief never does this (the law upgrade "undercover" still leaks
## destinations on its own, Session._spy_roll). While a beacon is live (BEACON_S) the controller's picture carries the
## aircraft wherever it flies, radar or not, transponder or not (PoliceSystem.tick reports it with a tight error).
##
## Planting only works with the aircraft parked at a strip. The odds are BASE_ODDS, less if a spotter of the runners'
## watches that strip. A failed attempt burns the agent: cover drops, the crew is told a man was seen at the tail,
## and the agent must lie low (COOLDOWN_S). The runner's bug sweeps may find a beacon the moment it is planted.
## Cover recovers slowly; at zero the agent is blown for BLOWN_S. Behind `Undercover.ENABLED`; own dice (seed + 919).

static var ENABLED := true

const BEACON_S := 1500.0
const BASE_ODDS := 0.75
const SPOTTER_PENALTY := 0.25
const SWEEP_FIND := 0.5  ## the runner's bug sweep finds a fresh beacon this often
const COVER_LOSS := 50.0
const COVER_REGEN_PER_S := 1.0 / 30.0
const COOLDOWN_S := 600.0
const BLOWN_S := 1200.0
const TRACK_SIGMA_M := 25.0

var sess
var held := false
var cover := 100.0
var busy_until := -1.0  ## lying low until
var beacons := 0  ## planted that held
var burned := 0
var found := 0  ## beacons the runner's sweep found
var rng: PyRandom


func _init(sess_) -> void:
	sess = sess_
	rng = PyRandom.new()
	rng.seed(int(sess.seed) + 919)


func active() -> bool:
	return ENABLED and held


func update(dt: float) -> void:
	if cover < 100.0:
		cover = minf(100.0, cover + COVER_REGEN_PER_S * dt)


## The chance a plant here and now works, or 0 when it cannot be tried.
func odds() -> float:
	if sess.phase != "parked" or sess.location == null:
		return 0.0
	var p := BASE_ODDS
	for s in sess.spotters:
		if s.code == sess.location:
			p -= SPOTTER_PENALTY
			break
	return clampf(p, 0.05, 0.95)


func why_not() -> String:
	if not ENABLED:
		return "There is no agent in this game."
	if sess.phase != "parked" or sess.location == null:
		return "The aircraft is not on the ground at a strip."
	if sess.time < busy_until:
		return "You are lying low for %d more seconds." % int(ceil(busy_until - sess.time))
	if beacon_live():
		return "There is a beacon on it already."
	return ""


func beacon_live() -> bool:
	return sess.police.beacon_until > sess.time


func plant() -> String:
	var err := why_not()
	if err != "":
		return err
	var name: String = World.airfield(sess.location).name
	if rng.random() > odds():
		cover = maxf(0.0, cover - COVER_LOSS)
		burned += 1
		busy_until = sess.time + (BLOWN_S if cover <= 0.0 else COOLDOWN_S)
		sess.say("A stranger was seen at the aircraft's tail at %s. Have it looked over." % name)
		sess.law_say("AGENT: spotted at the aircraft; cover %d%%%s." % [int(cover), " - blown" if cover <= 0.0 else ""])
		return ""
	if sess.upgrades["runner"].has("bug_sweep") and rng.random() < SWEEP_FIND:
		found += 1
		sess.say("Your bug sweep finds a beacon under the aircraft's belly at %s." % name)
		sess.law_say("AGENT: planted at %s, but the runner's sweep found it." % name)
		busy_until = sess.time + COOLDOWN_S * 0.5
		return ""
	sess.police.beacon_until = sess.time + BEACON_S
	beacons += 1
	sess.law_say("AGENT: beacon planted at %s; it reports for %d min." % [name, int(BEACON_S / 60.0)])
	return ""


func view() -> Dictionary:
	var here = sess.location if sess.phase == "parked" else null
	return {"held": held, "at": here, "at_name": World.airfield(here).name if here != null else "", "odds": odds(), "cover": int(cover),
		"lying_low_s": maxi(0, int(ceil(busy_until - sess.time))), "beacon_s": maxi(0, int(ceil(sess.police.beacon_until - sess.time))),
		"planted": beacons, "burned": burned, "found": found}
