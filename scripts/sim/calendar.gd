class_name Calendar
extends RefCounted
## Loop idea 4 (docs/LOOP_IDEAS.md): a calendar the player can read. The Economy's own news is a surprise; these are known ahead. The
## island's week is posted LEAD events in advance on the radio and in the phone's News ("Coming up"): a carnival weekend (the clubs pay
## more), the harvest (grass cheap), a tanker in port (fuel cheap), tourist season (charter fares up), and a customs operation (the police
## strips search more loads). Plan a run round them.
##
## When an event starts it becomes an Economy event (so prices, the News' "In force now" and the board follow it), or for the customs
## operation sets Police.crackdown until it ends. Story sessions only, never over an HQ season. Own RNG stream (seed + 183). Opt-in switch.

static var ENABLED := true

const LEAD := 3  ## events posted ahead
const GAP_S := [2400.0, 4800.0]  ## between one event's start and the next
const FIRST_S := 1800.0  ## the first one, after the start
const WARN_S := 600.0  ## the radio's reminder before one starts
const CRACKDOWN := 0.6  ## a customs operation: inspections x1.6 at the police strips
## [kind, good, mult, minutes, headline]; good "customs" is the police operation
const KINDS := [
	["carnival", "cocaine", 1.3, 120, "Carnival weekend in San Telmo: the clubs want everything"],
	["harvest", "marijuana", 0.75, 150, "Harvest in the hills: grass is cheap"],
	["tanker", "fuel", 0.8, 120, "A tanker docks at San Telmo: fuel is cheap"],
	["tourists", "passengers", 1.3, 150, "Tourist season opens: charter fares up"],
	["customs", "customs", 1.0, 90, "Operation Tradewind: customs search every load at the police strips"],
]

var sess
var rng: PyRandom
var upcoming: Array = []  ## {kind, good, mult, minutes, text, start}, soonest first
var crackdown_until := -1.0


func _init(sess_, rng_: PyRandom) -> void:
	sess = sess_
	rng = rng_


func _on() -> bool:
	return ENABLED and sess != null and sess.story != null and sess.nights == null


func update(_dt: float) -> void:
	if not _on():
		return
	var now: float = sess.time
	if crackdown_until >= 0.0 and now >= crackdown_until:
		crackdown_until = -1.0
		sess.police.crackdown = 0.0
		_post("Operation Tradewind is over: customs are back to spot checks.", true)
	if not upcoming.is_empty() and not bool(upcoming[0].get("warned", false)) and now >= float(upcoming[0].start) - WARN_S:
		upcoming[0].warned = true
		_post("In %d minutes: %s." % [int(WARN_S / 60.0), str(upcoming[0].text)], true)
	while not upcoming.is_empty() and now >= float(upcoming[0].start):
		_begin(upcoming.pop_front())
	while upcoming.size() < LEAD:
		var after: float = float(upcoming.back().start) + float(upcoming.back().minutes) * 60.0 if not upcoming.is_empty() else now
		var e := _pick(after + (rng.uniform(GAP_S[0], GAP_S[1]) if not upcoming.is_empty() else FIRST_S))
		upcoming.append(e)
		_post("Coming up at %s: %s." % [_clock(float(e.start)), str(e.text)], false)  # the paper only: three at once would crowd the screen


func _pick(start: float) -> Dictionary:
	var k: Array = KINDS[rng.randint(0, KINDS.size() - 1)]
	return {"kind": k[0], "good": k[1], "mult": k[2], "minutes": k[3], "text": k[4], "start": snappedf(start, 60.0)}


func _begin(e: Dictionary) -> void:
	var until: float = sess.time + float(e.minutes) * 60.0
	if str(e.good) == "customs":
		crackdown_until = until
		sess.police.crackdown = CRACKDOWN
	elif sess.econ != null:
		sess.econ.events.append({"good": str(e.good), "mult": float(e.mult), "until": until, "text": str(e.text)})
	_post("%s (%d min)." % [str(e.text), int(e.minutes)], true)


func _post(text: String, aloud: bool) -> void:
	if aloud:
		sess.say(text)
	if sess.econ != null:
		sess.econ.news.append([sess.time, text])
		Py.keep_last(sess.econ.news, 12)


## The phone's "Coming up" lines: when, how long, what.
func lines() -> Array:
	var out := []
	if crackdown_until >= 0.0:
		out.append("Customs operation, %d min left" % maxi(1, ceili((crackdown_until - float(sess.time)) / 60.0)))
	for e in upcoming:
		out.append("%s for %d min: %s" % [_clock(float(e.start)), int(e.minutes), str(e.text)])
	return out


static func _clock(t: float) -> String:
	return "%d:%02d" % [int(t / 3600.0), int(t / 60.0) % 60]


## For StrategicSave: what is posted and a customs operation under way (so restoring draws nothing).
func capture() -> Dictionary:
	return {"upcoming": upcoming.duplicate(true), "crackdown_until": crackdown_until}


func restore(d: Dictionary) -> void:
	upcoming = (d.get("upcoming", []) as Array).duplicate(true) if d.get("upcoming") is Array else []
	crackdown_until = float(d.get("crackdown_until", -1.0))
	if crackdown_until >= 0.0 and sess != null and sess.police != null:
		sess.police.crackdown = CRACKDOWN
