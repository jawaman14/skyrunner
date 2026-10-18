class_name AutoRunner
extends RefCounted
## AutoRunner: the pilot bot playing the career on its own.
##
## Picks a job at the current field (hot ones first when the layer allows),
## plans fuel, flies it, recovers from crashes and busts, repeats. Used by
## `--watch` (watch the AI, low graphics recommended) and as a soak test:
## hours of play without a human.

var sess: Session
var prefer_hot := true
var bot: PilotBot = null
var flights := 0
var skipped := {}  ## job id -> true: loads that would not fit the aircraft even re-planned (never picked again)
var log: Array = []
var _wait := 0.0


func _init(s: Session, prefer_hot_ := true) -> void:
	sess = s
	prefer_hot = prefer_hot_


## Tell the human where the AI pilot is taking them (owner, 17 Oct): the first thing the AI says when it takes a flight.
func _announce(legs: Array, no_job := false) -> void:
	var s := sess
	if legs.is_empty() or s.state == null:
		return
	var first: PilotBot.Leg = legs[0]
	var last: PilotBot.Leg = legs.back()
	var to_first := PyMath.hypot(first.x - s.state.x, first.y - s.state.y) / 1000.0
	var to_last := PyMath.hypot(last.x - s.state.x, last.y - s.state.y) / 1000.0
	var home: String = World.airfield(str(last.code)).name if last.code != null else "base"
	if first.kind == "drop":
		s.say("AI pilot: flying to the drop point (%.1f km), then back to %s." % [to_first, home])
	elif no_job:
		s.say("AI pilot: no job aboard, landing at the nearest field, %s (%.1f km)." % [home, to_last])
	elif last.code != null:
		s.say("AI pilot: flying to %s (%.0f km)." % [home, to_last])
	else:
		s.say("AI pilot: flying to a waypoint (%.1f km)." % to_first)


## The AI takes the controls part-way through a flight: fly the active job, or land at the nearest field when there is no job.
## On the ground with a job, PilotBot plans departure from the aircraft's current position.
func _adopt_flight() -> void:
	var s := sess
	if s.state == null or s.phase in ["crashed", "busted", "custody"]:
		return
	var legs: Array
	if s.active_jobs.is_empty():
		var af: Airfield = s.world.nearest_airfield(s.state.x, s.state.y)[0]
		legs = [PilotBot.Leg.new("land", af.x, af.y, af.code)]
	else:
		var job: Jobs.Job = s.active_jobs[0]
		var home = s.log.departed_from if s.log.departed_from else s.location
		legs = PilotBot.mission_for(s, job, home)
	bot = PilotBot.new(s, legs)
	if not s.state.on_ground:
		bot.pitch_base = s.state.pitch
		bot._set_phase("enroute")
	flights += 1
	_announce(legs, s.active_jobs.is_empty())


func _pick():
	var s := sess
	var board: Array = s.boards.get(s.location, [])
	var spec: Aircraft.Spec = s.spec
	var seats := spec.seat_count() - (1 if s.copilot else 0)
	var jobs := Py.filter(board, func(j):
		var pax := Py.count(j.items, func(i): return i.kind == "passenger")
		return pax <= seats and j.weight_lb() < spec.mtow_lb * 0.25 and not skipped.has(j.id))
	if jobs.is_empty():
		return null
	# Python's key is the tuple (hot, payout); payouts are far below 1e12
	return Py.max_by(jobs, func(j): return (1e12 if (prefer_hot and j.hot()) else 0.0) + j.payout)


func step(dt: float) -> FlightModel.Controls:
	var s := sess
	if s.phase in ["crashed", "busted"]:
		_wait += dt
		if _wait > 4.0:
			_wait = 0.0
			log.append(s.last_outcome)
			s.command(Roles.PILOT, "confirm", {})
			bot = null
		return null
	if bot != null and bot.phase != "done":
		return bot.step(dt)
	if bot == null and not s.parked and (not s.active_jobs.is_empty() or (s.state != null and not s.state.on_ground)):
		_adopt_flight()  # the human handed over (F3) in the middle of a flight or a take-off run
		if bot != null:
			return bot.step(dt)
	if not s.parked or not s.unloading.is_empty():
		return null
	if s.psych != null:
		s.psych.auto = true  # the organisation's AI trades its spare grass for acid and sells it
	if s.dealer != null:
		s.dealer.auto = true  # the AI runs the fleet: it buys the trucks the organisation can afford
	if s.airframe != null:
		s.airframe.auto_service()  # the ground crew sees to a worn aircraft; the bot waits for the work
		if not s.airframe.work.is_empty():
			return null
	_wait += dt
	if _wait < 3.0:  # a moment on the ground between flights
		return null
	_wait = 0.0
	if s.active_jobs.is_empty():
		var job = _pick()
		if job == null:
			s.refresh_board(s.location)
			return null
		if s.accept_job(job) != null:
			return null
	var job: Jobs.Job = s.active_jobs[0]
	if not s.loadout.compute().ok():
		s.hire_loadmaster()
	if not s.loadout.unassigned().is_empty():  # it does not fit even re-planned: put the job back and take another (a server's pilot must not wait forever)
		skipped[job.id] = true
		s.drop_job(job)
		return null
	var legs := PilotBot.mission_for(s, job, s.location)
	s.set_fuel(PilotBot.plan_fuel_lb(s, legs))
	bot = PilotBot.new(s, legs)
	flights += 1
	_announce(legs)
	return bot.step(dt)
