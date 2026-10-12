class_name HostLoop
extends RefCounted
## The one frame loop a host runs (host service step 2, #97; the owner chose a fixed 30 Hz step on 12 Oct). The host desk and the dedicated server each had their
## own accumulator or a clamped variable step; both use this now, so a hosted game steps the same way on every path and replays line up.
##
##   var loop := HostLoop.new()
##   loop.advance(delta, func(dt): server.pump(sess); sess.update(dt, null, bot_controls))
##
## Not the 3D pilot app: that one flies on human input every rendered frame, and a fixed step there needs render interpolation (a separate decision).

const DT := 1.0 / 30.0
const MAX_STEPS := 5  ## a slow machine drops time rather than spiralling

var _acc := 0.0


## Run `step.call(DT)` once for every whole DT contained in `delta` (plus what was left over before), at most MAX_STEPS times. Returns the steps run.
func advance(delta: float, step: Callable) -> int:
	_acc += delta
	var n := 0
	while _acc >= DT and n < MAX_STEPS:
		_acc -= DT
		n += 1
		step.call(DT)
	if n == MAX_STEPS:
		_acc = 0.0
	return n


## The AI flies whenever nobody holds the pilot's seat; a player who takes it flies from their own machine. Returns the bot to use from now on.
static func ai_pilot(sess: Session, bot):
	var who := sess.seats.who(Roles.PILOT)
	if who == "ai" and bot == null:
		return AutoRunner.new(sess)
	if who != "ai" and bot != null:
		return null
	return bot
