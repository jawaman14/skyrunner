class_name Analyst
extends RefCounted
## The task force's analyst: the desk every tip crosses before dispatch acts on it.
##
## With no human in the seat nothing changes: a tip goes straight to dispatch (PoliceSystem.add_tip), as it always did.
## When a player holds the analyst seat, tips (an informant's word, an undercover agent's, the fuel desk's note that a
## tail number bought ferry fuel, a double agent's plant) wait here instead and the analyst chooses:
##   verify   spends VERIFY_S checking the source and the tail number; the answer is right ACCURACY of the time
##   forward  hands it to dispatch (a helicopter goes up for a real one); a false lead costs BAD_SORTIE in funds
##   discard  throws it away (a real one thrown away is a load that got through)
## A tip nobody touches is forwarded as it is after STALE_S: dispatch will not wait for ever.
## Behind `Analyst.ENABLED`; its dice are their own stream (seed + 909).

static var ENABLED := true

const VERIFY_S := 45.0
const STALE_S := 150.0
const ACCURACY := 0.85
const BAD_SORTIE := 1000
const MAX_DESK := 12

var sess
var held := false  ## a human sits at the desk
var desk: Array = []  ## [{id, t, x, y, r, text, squawk, target, truth, source, checked, verify_until}]
var rng: PyRandom
var forwarded := 0
var wasted := 0  ## false leads followed up
var missed := 0  ## real leads thrown away
var _serial := 0


func _init(sess_) -> void:
	sess = sess_
	rng = PyRandom.new()
	rng.seed(int(sess.seed) + 909)


func active() -> bool:
	return ENABLED and held


## Where a tip came from, read off its text.
static func source_of(text: String) -> String:
	for k in ["informant", "undercover", "fuel desk", "anonymous caller"]:
		if text.begins_with(k):
			return k
	return "tip"


## A tip arrives (PoliceSystem.add_tip hands it over when the seat is held). `truth` is what only the sim knows.
func intake(x: float, y: float, radius: float, text: String, squawk: String, target, truth: bool) -> void:
	_serial += 1
	desk.append({"id": "T%d" % _serial, "t": sess.time, "x": x, "y": y, "r": radius, "text": text, "squawk": squawk, "target": target,
		"truth": truth, "source": source_of(text), "checked": "", "verify_until": -1.0})
	sess.law_say("ANALYST: a new tip on the desk (%s)." % source_of(text))
	while desk.size() > MAX_DESK:
		_forward(desk[0], "the desk was full")
		desk.remove_at(0)


func find(id: String):
	for e in desk:
		if e.id == id:
			return e
	return null


func update(_dt: float) -> void:
	if desk.is_empty():
		return
	for e in desk.duplicate():
		if float(e.verify_until) >= 0.0 and sess.time >= float(e.verify_until):
			e.verify_until = -1.0
			var reads_true: bool = bool(e.truth) if rng.random() < ACCURACY else not bool(e.truth)
			e.checked = "good" if reads_true else "bad"
			sess.law_say("ANALYST: %s checked out %s." % [e.id, "as sound" if reads_true else "as doubtful"])
		elif sess.time - float(e.t) > STALE_S:
			desk.erase(e)
			_forward(e, "nobody got to it in %d s" % int(STALE_S))


func verify(id: String) -> String:
	var e = find(id)
	if e == null:
		return "No such tip."
	if e.checked != "":
		return "Already checked."
	if float(e.verify_until) >= 0.0:
		return "Already being checked."
	e.verify_until = sess.time + VERIFY_S
	return ""


func forward(id: String) -> String:
	var e = find(id)
	if e == null:
		return "No such tip."
	desk.erase(e)
	_forward(e, "")
	return ""


func discard(id: String) -> String:
	var e = find(id)
	if e == null:
		return "No such tip."
	desk.erase(e)
	if bool(e.truth):
		missed += 1
		sess.law_say("ANALYST: %s binned." % e.id)
	return ""


## Everything on the desk goes to dispatch (the seat was handed back to the AI).
func release_all() -> void:
	for e in desk.duplicate():
		desk.erase(e)
		_forward(e, "")


func _forward(e: Dictionary, why: String) -> void:
	forwarded += 1
	var police: PoliceSystem = sess.police
	police.release_tip(float(e.x), float(e.y), float(e.r), str(e.text), str(e.squawk), e.target)
	if not bool(e.truth):
		wasted += 1
		sess.law_funds = maxf(0.0, sess.law_funds - BAD_SORTIE)
		sess.law_say("ANALYST: %s was a false lead; the sortie cost $%s." % [e.id, Py.money(BAD_SORTIE)])
	elif why != "":
		sess.law_say("ANALYST: %s went to dispatch (%s)." % [e.id, why])


## What the desk shows: no truth, only what the analyst can know.
func view() -> Dictionary:
	var rows := []
	for e in desk:
		var verifying: float = maxf(0.0, float(e.verify_until) - sess.time) if float(e.verify_until) >= 0.0 else 0.0
		rows.append({"id": e.id, "age": int(sess.time - float(e.t)), "source": e.source, "text": e.text, "squawk": e.squawk,
			"checked": e.checked, "verifying_s": int(ceil(verifying)), "x": e.x, "y": e.y, "r": e.r})
	return {"desk": rows, "held": held, "forwarded": forwarded, "wasted": wasted, "missed": missed, "stale_s": int(STALE_S)}
