class_name HeatDial
extends RefCounted
## The heat dial (owner, 7 Nov, D-95: the Borderlands study's round two, its Mayhem levels: the player turns the danger up for a
## bigger payout, and down when he needs a breather). Four settings; Steady is the game as it always was:
##
##   Quiet    sightings add 0.75 times the suspicion, customs checks 0.75 times as often;  board jobs pay 0.85 times
##   Steady   1, 1, 1
##   Hot      1.3, 1.3;  1.2 times the pay
##   Burning  1.6, 1.6;  1.45 times the pay
##
## The heat side is PoliceSystem.dial_mult (on every sighting, beside the chapter's pace) and dial_customs (on the customs roll's
## threshold, so the one draw stays the one draw). The pay side applies to every board dealt from then on (Session.refresh_board,
## after the day's prices), so a board on the wall keeps the pay it was posted with. Turned on the phone's Heat page (Q quieter,
## E hotter, the `heat_dial` command), only while parked: no turning it down in the middle of a chase. Saved. No random draws.
## Behind ENABLED (in the parity set); Steady is the identity, so a parity session is unchanged either way.

static var ENABLED := true

const LEVELS := [
	{"name": "Quiet", "heat": 0.75, "pay": 0.85},
	{"name": "Steady", "heat": 1.0, "pay": 1.0},
	{"name": "Hot", "heat": 1.3, "pay": 1.2},
	{"name": "Burning", "heat": 1.6, "pay": 1.45},
]
const STEADY := 1

var sess
var level := STEADY


func _init(sess_) -> void:
	sess = sess_
	apply()


func setting() -> Dictionary:
	return LEVELS[level]


func pay_mult() -> float:
	return float(setting().pay) if ENABLED else 1.0


## Hand the heat side to the police.
func apply() -> void:
	if sess.police == null:
		return
	var h: float = float(setting().heat) if ENABLED else 1.0
	sess.police.dial_mult = h
	sess.police.dial_customs = h


## Turn the dial to `to` (0..3). "" or why not.
func set_level(to: int) -> String:
	if not ENABLED:
		return "There is no heat dial in this game."
	if to < 0 or to >= LEVELS.size():
		return "The dial goes from Quiet to Burning."
	if to == level:
		return ""
	if not sess.parked:
		return "Turn the heat dial on the ground: park first."
	level = to
	apply()
	var s := setting()
	var line := "Heat dial: %s. Jobs posted from now pay x%.2f; the law notices x%.2f." % [s.name, float(s.pay), float(s.heat)]
	sess.say(line)
	sess.bus.emit("heat_dial", sess.time, line, ["runner"], {"level": level, "name": str(s.name)})
	return ""


## The Heat page's line.
func line() -> String:
	var s := setting()
	return "%s: jobs pay x%.2f, the law notices x%.2f   (Q quieter, E hotter)" % [s.name, float(s.pay), float(s.heat)]


func capture() -> Dictionary:
	return {"level": level}


func restore(d: Dictionary) -> void:
	level = clampi(int(d.get("level", STEADY)), 0, LEVELS.size() - 1)
	apply()
