class_name Discovery
extends RefCounted
## Hidden strips (owner, 30 Oct: make the first chapters less bare). In a story game the island's shady strips start off the chart: no
## one marks a smuggler's strip on a map. Flying low near one finds it (under FIND_AGL_M within FIND_RANGE_M), and so does taking a job
## that goes there (Benny gives the coordinates). Found strips are on the chart and in the places list from then on, and saved.
##
## Reads positions only: no random draw. The landing rules do not care whether a strip is found; only the chart does.

static var ENABLED := true  ## off: every strip is on the chart, nothing is revealed (an opt-in switch: only story games hide any)

const FIND_RANGE_M := 2500.0
const FIND_AGL_M := 400.0

var sess
var hidden := {}  ## code -> true: not yet on the chart
var _t := 0.0


func _init(sess_) -> void:
	sess = sess_


## Called when the story starts: every shady strip begins hidden.
func hide_shady() -> void:
	if not ENABLED:
		return
	for af in sess.world.airfields:
		if af.kind == "shady":
			hidden[af.code] = true


func is_known(code: String) -> bool:
	return not ENABLED or not hidden.has(code)


func update(dt: float) -> void:
	if not ENABLED or hidden.is_empty() or sess.state == null:
		return
	_t += dt
	if _t < 1.0:
		return
	_t = 0.0
	for j in sess.active_jobs:  # a job's strip is given with the job
		if hidden.has(str(j.dest)):
			reveal(str(j.dest), "Benny gives you the coordinates")
	if sess.state.on_ground or sess.state.agl > FIND_AGL_M:
		return
	for code in hidden.keys():
		var af := World.airfield(code)
		if PyMath.hypot(af.x - sess.state.x, af.y - sess.state.y) < FIND_RANGE_M:
			reveal(code, "you spotted it from the air")


func reveal(code: String, how: String) -> void:
	if not hidden.has(code):
		return
	hidden.erase(code)
	sess.say("Unmarked strip found: %s (%s). It's on your chart now." % [World.airfield(code).name, how])
	sess.bus.emit("strip_found", sess.time, "", ["runner"], {"code": code})


func capture() -> Array:
	var codes: Array = hidden.keys()
	codes.sort()
	return codes


func restore(codes: Array) -> void:
	hidden = {}
	for c in codes:
		if World.AIRFIELD_BY_CODE.has(str(c)):
			hidden[str(c)] = true
