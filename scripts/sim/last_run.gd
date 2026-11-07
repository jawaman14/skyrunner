class_name LastRun
extends RefCounted
## The last run: a one-life extraction mode (owner, 7 Nov, D-95: the Borderlands study's round two, its last item). Everything is
## open, the pilot starts with START money at his home strip, and the run lasts RUN_S of game time. Money only counts once it is
## banked: landing back at the home strip banks what is in hand (the score so far). A bust or a crash ends the run there, on what
## was last banked; so does the clock running out away from home. Parked at home, the pilot can cash out (`last_run_out`), which
## banks everything and ends the run on his own terms. The best runs are kept (BEST_PATH, the top KEEP).
##
## One life: a last run is never saved (Main starts every one new and deletes the file), so a reload cannot undo a crash.
## Built only when the session's options ask (`last_run: true`; the lobby's "Last run"), so nothing else changes. No draws.

static var ENABLED := true

const START := 5000
const RUN_S := 7200.0  ## two hours of game time
const KEEP := 5
const BEST_PATH := "user://last_run_best.json"

var sess
var home := ""
var started := 0.0
var banked := 0  ## what counts if the run ended now
var over := false
var score := 0
var reason := ""  ## busted | crashed | time | out


func _init(sess_) -> void:
	sess = sess_
	home = str(sess.location) if sess.location != null else ""
	started = float(sess.time)
	banked = int(sess.money)
	for kind in ["busted", "crashed", "landed"]:
		sess.bus.subscribe(kind, _on_event)
	sess.say("THE LAST RUN: one life, %d minutes, $%s to start. Land back at %s to bank what you hold; a bust or a crash ends it." % [
		int(RUN_S / 60.0), Py.money(START), _home_name()])


func _home_name() -> String:
	var af := World.airfield(home)
	return af.name if af != null else "home"


func left_s() -> float:
	return maxf(0.0, started + RUN_S - float(sess.time))


func _on_event(e) -> void:
	if sess == null or over:
		return
	match str(e.kind):
		"landed":
			if str(e.data.get("code", "")) == home and int(sess.money) != banked:
				banked = int(sess.money)
				sess.say("Banked at %s: $%s." % [_home_name(), Py.money(banked)])
		"busted":
			_end("busted", banked)
		"crashed":
			_end("crashed", banked)


func update() -> void:
	if over:
		return
	if left_s() <= 0.0:
		var at_home: bool = sess.parked and str(sess.location) == home
		_end("time", int(sess.money) if at_home else banked)


## Cash out: parked at home, bank everything and end the run. "" or why not.
func cash_out() -> String:
	if over:
		return "The run is over."
	if not (sess.parked and str(sess.location) == home):
		return "Cash out at %s, parked." % _home_name()
	_end("out", int(sess.money))
	return ""


func _end(why: String, final: int) -> void:
	over = true
	reason = why
	score = maxi(0, final)
	var place := _record()
	var how: String = {"busted": "Busted", "crashed": "Crashed", "time": "Out of time", "out": "Cashed out"}[why]
	var line := "THE LAST RUN IS OVER. %s: $%s banked%s." % [how, Py.money(score), (" (best run #%d)" % place) if place > 0 else ""]
	sess.say(line)
	sess.bus.emit("run_over", sess.time, line, ["runner"], {"reason": why, "score": score, "place": place})


## The best runs, best first: [{score, reason}].
static func best() -> Array:
	if not FileAccess.file_exists(BEST_PATH):
		return []
	var f := FileAccess.open(BEST_PATH, FileAccess.READ)
	if f == null:
		return []
	var d = JSON.parse_string(f.get_as_text())
	return (d if d is Array else []).filter(func(r): return r is Dictionary)


## Keep this run if it makes the top KEEP. Its place (1 = the best), or 0.
func _record() -> int:
	var runs := best()
	runs.append({"score": score, "reason": reason, "new": true})
	runs.sort_custom(func(a, b): return int(a.score) > int(b.score))
	runs = runs.slice(0, KEEP)
	var place := 0
	for i in runs.size():
		if runs[i].get("new", false):
			place = i + 1
			runs[i].erase("new")
	var f := FileAccess.open(BEST_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(runs))
	return place


## The HUD's line.
func hud_line() -> String:
	if over:
		return "THE LAST RUN: over, $%s banked. ESC for the menu." % Py.money(score)
	var s := int(left_s())
	return "THE LAST RUN  %d:%02d:%02d left\nbanked $%s, in hand $%s; land at %s to bank%s" % [s / 3600, (s / 60) % 60, s % 60,
		Py.money(banked), Py.money(int(sess.money)), _home_name(), ", or SHIFT+X to cash out" if sess.parked and str(sess.location) == home else ""]
