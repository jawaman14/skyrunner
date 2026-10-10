class_name StripTrials
extends RefCounted
## Per-runway-end takeoff and landing trials for the strip feasibility question (#88), flown by the pilot bot.
##
## Feasibility (the balance sweep, pinned by test_trials_parity) lets the bot choose its own runway end and
## keeps stepping after the bot is done, so a glide into the ground after the goal is scored as a takeoff
## pass. These trials measure one forced end at a time instead and stop as soon as the trial has an answer:
##
##   takeoff: from the threshold of `end`, straight out along the runway. Pass = 3 km along the runway's line
##            from the start of the run, inside the straight-departure corridor, without crashing. Reaching
##            300 m above the ground is not a pass on its own: the climb has to clear the terrain all the way
##            out. If the bot's terrain avoidance turns it out of the corridor first, the result is
##            "inconclusive": the straight departure was not flown, which says nothing either way about the
##            aircraft. Records the ground roll, the distance to 15 m, the least clearance over terrain and
##            trees once clear of the runway, and the largest sideways deviation.
##   landing: spawned on the final the bot's own planner would fly for `end` (no route planning, so #80/#82
##            geometry is out of it). Pass = parked on the strip. An end the planner cannot find a clear
##            glide path to, even at its steepest, is reported "obstructed" with the reason, and not flown.
##
## Nothing here changes the flight model, the bot, the terrain or the jobs: the end is forced by setting the
## bot's own fields. Call use_map() first; trials run on whatever map and terrain mode are current.

const TAKEOFF_GOAL_M := 3000.0
const TAKEOFF_MAX_S := 400.0
const LANDING_MAX_S := 600.0
const DT := 1.0 / 30
const CLEAR_RADIUS_M := 15.0  ## obstacle search radius under the aircraft for the climb clearance
## The straight-departure corridor: 90 m either side of the runway line at the start of the run, widening by
## 12.5% of the distance flown along it (465 m either side at 3 km). This is the shape of the ICAO Annex 6
## take-off flight path area (90 m semi-width plus 0.125 D), measured here from the start of the run, which
## is wider near the field than the rule; it allows for drift while the bot climbs, not for a turn away.
const CORRIDOR_HALF_M := 90.0
const CORRIDOR_SPLAY := 0.125
const FIELDS := ["QRY", "PNR", "EGL", "HAR"]  ## the mountain strips of #88, and the hub as a control
const AIRCRAFT := ["c172p", "c182"]


## Make `map_seed` current with the classic or the natural terrain pass (main.gd turns natural on for play).
static func use_map(map_seed: int, natural: bool) -> void:
	Terrain.natural = natural
	World.use_map(map_seed)


## The runway direction for taking off from, or landing at, `end` (the convention of Airfield.threshold).
static func end_heading(af: Airfield, end: int) -> float:
	return af.heading if end == 0 else fposmod(af.heading + 180.0, 360.0)


static func _base(test: String, aircraft: String, code: String, load: String, end: int) -> Dictionary:
	var af := World.airfield(code)
	return {"test": test, "aircraft": aircraft, "field": code, "load": load, "end": end,
		"heading": end_heading(af, end), "map_seed": World.layout.map_seed, "natural": Terrain.natural}


## Half-width of the straight-departure corridor `along_m` metres down the runway line from the start of the run.
static func corridor_m(along_m: float) -> float:
	return CORRIDOR_HALF_M + CORRIDOR_SPLAY * maxf(0.0, along_m)


## Progress along a forced departure: signed along-track distance on the runway line from the start of the run,
## signed cross-track deviation (+ = right of the line), and the verdict once there is one.
class Departure:
	var x0: float
	var y0: float
	var ux: float  ## unit vector down the runway line (x east, y north)
	var uy: float
	var along := 0.0
	var cross := 0.0
	var max_cross := 0.0  ## largest |cross| so far, m

	func _init(x0_: float, y0_: float, heading_deg: float) -> void:
		x0 = x0_
		y0 = y0_
		ux = sin(deg_to_rad(heading_deg))
		uy = cos(deg_to_rad(heading_deg))

	## "" while still going, "3km" on reaching the goal along the line inside the corridor, "left corridor" when
	## the path strays outside it first (checked before the goal, so a wide 3 km arc cannot pass).
	func sample(x: float, y: float) -> String:
		var dx := x - x0
		var dy := y - y0
		along = dx * ux + dy * uy
		cross = dx * uy - dy * ux
		max_cross = maxf(max_cross, absf(cross))
		if absf(cross) > StripTrials.corridor_m(along):
			return "left corridor"
		if along >= StripTrials.TAKEOFF_GOAL_M:
			return "3km"
		return ""


## Did the session end the flight (crash or arrest)?
static func _ended(s: Session) -> bool:
	return s.phase in ["crashed", "busted"]


static func takeoff(aircraft: String, code: String, load: String, end: int) -> Dictionary:
	var r := _base("takeoff", aircraft, code, load, end)
	var af := World.airfield(code)
	var hdg: float = r.heading
	var s := Feasibility._session(aircraft, code)
	Feasibility.load_aircraft(s, Feasibility.LOADS[load][0], Feasibility.LOADS[load][1])
	# the start of the run: 25 m in from the threshold of this end, facing down the runway (as Session.spawn_at)
	var t: Array = af.threshold(end)
	var h := deg_to_rad(hdg)
	var x0: float = t[0] + sin(h) * 25.0
	var y0: float = t[1] + cos(h) * 25.0
	var elev := s.world.airfield_elev(af)
	s.fm.spawn(x0, y0, hdg, elev, s.loadout)
	s.fm.controls.brake = 1.0
	s.fm.step(0.5, s.world.ground)
	s._after_spawn()
	r.weight_lb = s.state.weight_lb
	var roll := s.spec.est_landing_roll(s.state.weight_lb, elev) * 1.35
	r.required_gradient = _departure_gradient(s.world, af, end, roll)
	# a goal well past the 3 km mark on the runway line, so the bot never finishes its leg first
	var bot := PilotBot.new(s, [PilotBot.Leg.new("goto", x0 + sin(h) * TAKEOFF_GOAL_M * 2.0, y0 + cos(h) * TAKEOFF_GOAL_M * 2.0)])
	bot.dep_af = af
	bot.runway_hdg = hdg
	bot.departure_gradient = r.required_gradient
	bot._set_phase("takeoff")
	var t0 := s.time
	var dep := Departure.new(x0, y0, hdg)
	var liftoff = null
	var to_15m = null
	var min_clear = null
	var stop := "timeout"
	while s.time - t0 < TAKEOFF_MAX_S:
		var c := bot.step(DT)
		if _ended(s):
			stop = "crash"
			break
		if bot.phase == "done":
			stop = "bot gave up"
			break
		s.update(DT, null, c)
		if _ended(s):
			stop = "crash"
			break
		var st := s.state
		var verdict := dep.sample(st.x, st.y)
		if liftoff == null and not st.on_ground:
			liftoff = dep.along
		if to_15m == null and st.agl >= 15.0:
			to_15m = dep.along
		if liftoff != null and not af.contains(st.x, st.y, 4.0):
			var clear := st.alt - s.world.obstacle_top(st.x, st.y, CLEAR_RADIUS_M)
			min_clear = clear if min_clear == null else minf(min_clear, clear)
		if verdict != "":
			stop = verdict
			break
	r.status = "pass" if stop == "3km" else ("inconclusive" if stop == "left corridor" else "fail")
	r.stop = stop
	if stop == "left corridor":
		r.outcome = "left the straight-departure corridor %.0f m along the line, %.0f m %s of it (limit %.0f m)" % [
			dep.along, absf(dep.cross), "right" if dep.cross > 0 else "left", corridor_m(dep.along)]
	else:
		r.outcome = s.last_outcome if stop == "crash" else (str(bot.outcome) if stop == "bot gave up" else stop)
	r.liftoff_m = liftoff
	r.to_15m_m = to_15m
	r.min_clear_m = min_clear
	r.along_m = dep.along
	r.max_cross_m = dep.max_cross
	r.seconds = s.time - t0
	s.dispose()
	return r


## The climb gradient the departure off `end` needs over the first 3 km (PilotBot.plan_departure, one end).
static func _departure_gradient(world: World, af: Airfield, end: int, roll_m: float) -> float:
	var elev := world.airfield_elev(af)
	var h := deg_to_rad(end_heading(af, end))
	var t: Array = af.threshold(end)
	var worst := 0.0
	var x := roll_m + 20
	while x < 3000:
		var px: float = t[0] + sin(h) * x
		var py: float = t[1] + cos(h) * x
		if not af.contains(px, py, 4.0):
			var rise := maxf(0.0, world.obstacle_top(px, py, 25.0) - elev)
			worst = maxf(worst, (rise + 10.0) / maxf(150.0, x - roll_m))
		x += 20 if x < 800 else 80
	return worst


## PilotBot.plan_approach for one end only: the first glide angle and aim point (shallowest first) whose final
## clears the terrain and trees, else the best of them with where and what blocks it.
## Returns {ap: PilotBot.Approach, clear: bool, worst_at_m, worst_what}.
static func approach_for_end(world: World, af: Airfield, end: int, gear_h: float, roll_m: float) -> Dictionary:
	var elev := world.airfield_elev(af)
	var aims := [0.1, 0.18, 0.26, 0.34, 0.42].filter(func(f): return af.length * (1 - f) > roll_m * 1.25)
	if aims.is_empty():
		aims = [0.08]
	var hdg := end_heading(af, end)
	var t: Array = af.threshold(end)
	var h := deg_to_rad(hdg)
	var best := {}
	for gamma in [3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5]:
		var final_len := minf(5000.0, PilotBot.FINAL_HEIGHT_M / tan(deg_to_rad(gamma)))
		for frac in aims:
			var aim_d := minf(maxf(25.0, af.length * frac), 150.0 + af.length * (frac - 0.1))
			var aim := [t[0] + sin(h) * aim_d, t[1] + cos(h) * aim_d]
			var ap := PilotBot.Approach.new(af, hdg, aim, elev + gear_h, gamma, 1e9)
			var worst := 1e9
			var at := 0.0
			var what := "terrain"
			var d := aim_d + 10
			while d < final_len:
				var p := ap.point(d)
				var need := minf(25.0, 3.0 + (d - aim_d) * 0.035)
				var top := world.obstacle_top(p[0], p[1], 30.0)
				var m := ap.path_alt(d) - gear_h - top - need
				if m < worst:
					worst = m
					at = d
					what = "trees" if top > world.ground(p[0], p[1]) + 1.0 else "terrain"
				d += 20 if d < 800 else 60
			ap.clear_m = worst
			if worst >= 0:
				return {"ap": ap, "clear": true, "worst_at_m": at, "worst_what": what}
			if best.is_empty() or worst > best.ap.clear_m:
				best = {"ap": ap, "clear": false, "worst_at_m": at, "worst_what": what}
	return best


static func landing(aircraft: String, code: String, load: String, end: int) -> Dictionary:
	var r := _base("landing", aircraft, code, load, end)
	var af := World.airfield(code)
	var s := Feasibility._session(aircraft, "HAR" if code != "HAR" else "VAL")
	Feasibility.load_aircraft(s, Feasibility.LOADS[load][0], Feasibility.LOADS[load][1])
	r.weight_lb = s.state.weight_lb
	var gear_h := s.fm.mass.gear_height_ft * 0.3048
	var roll := s.spec.est_landing_roll(s.state.weight_lb, s.world.airfield_elev(af))
	var plan := approach_for_end(s.world, af, end, gear_h, roll)
	var ap: PilotBot.Approach = plan.ap
	r.glide_deg = ap.gamma
	r.approach_clear_m = ap.clear_m
	if not plan.clear:
		r.status = "obstructed"
		r.stop = "obstructed"
		r.outcome = "no clear final to end %d: at %.1f deg the path is %.0f m into %s %.0f m out" % [
			end, ap.gamma, -ap.clear_m, plan.worst_what, plan.worst_at_m]
		r.seconds = 0.0
		s.dispose()
		return r
	# the start of Feasibility.landing_trial: on this final, well out, at least 250 m up
	var dist := minf(5000.0, 320.0 / tan(deg_to_rad(ap.gamma))) + 2500
	var xy := ap.point(dist)
	var agl := maxf(ap.path_alt(dist) - s.world.ground(xy[0], xy[1]), 250.0)
	s.spawn_airborne(xy[0], xy[1], ap.hdg, agl, s.spec.approach_kts * 1.3)
	var leg := PilotBot.Leg.new("land", af.x, af.y, code)
	leg.routed = true  # straight to the final: no valley routing
	var bot := PilotBot.new(s, [leg])
	bot.approach = ap
	bot.phase = "enroute"
	var t0 := s.time
	var t: Array = af.threshold(end)
	var h := deg_to_rad(ap.hdg)
	var touchdown := []
	var stop := "timeout"
	while s.time - t0 < LANDING_MAX_S:
		if bot.approach == null and bot.phase in ["climb", "enroute"]:
			bot.approach = ap  # after a go-around the bot replans; keep it on this end
		var c := bot.step(DT)
		if _ended(s):
			stop = "crash"
			break
		if bot.phase == "done":
			stop = "landed" if bot.outcome == "landed" else "bot gave up"
			break
		s.update(DT, null, c)
		if _ended(s):
			stop = "crash"
			break
		var st := s.state
		if touchdown.is_empty() and st.on_ground:
			touchdown = [st.x, st.y, absf(s.fm.last_touchdown_fpm)]  # sink rate, positive down
	var ok: bool = s.phase == "parked" and s.location == code
	r.status = "pass" if ok else "fail"
	r.stop = stop
	r.outcome = "landed" if ok else (s.last_outcome if stop == "crash" else (str(bot.outcome) if stop == "bot gave up" else stop))
	r.go_arounds = bot.go_arounds
	r.touchdown_from_threshold_m = null
	r.touchdown_fpm = null
	r.roll_m = null
	if not touchdown.is_empty():
		r.touchdown_from_threshold_m = (touchdown[0] - t[0]) * sin(h) + (touchdown[1] - t[1]) * cos(h)
		r.touchdown_fpm = touchdown[2]
		if ok:
			r.roll_m = PyMath.hypot(s.state.x - touchdown[0], s.state.y - touchdown[1])
	r.seconds = s.time - t0
	s.dispose()
	return r


## Every [test, aircraft, field, load, end] the filters allow (null = all).
static func jobs(aircraft = null, fields = null, loads = null, ends = null, tests = null) -> Array:
	var out := []
	for k in (aircraft if aircraft != null else AIRCRAFT):
		for c in (fields if fields != null else FIELDS):
			for ld in (loads if loads != null else Feasibility.LOADS.keys()):
				for e in (ends if ends != null else [0, 1]):
					for t in (tests if tests != null else ["takeoff", "landing"]):
						out.append([t, k, c, ld, e])
	return out


static func run_job(j: Array) -> Dictionary:
	if j[0] == "takeoff":
		return takeoff(j[1], j[2], j[3], j[4])
	return landing(j[1], j[2], j[3], j[4])


static func _num(v, fmt := "%.0f") -> String:
	return "-" if v == null else fmt % v


## Markdown: one row per trial, in job order.
static func table(results: Array) -> String:
	var lines := ["| field | end | hdg | aircraft | load | test | result | liftoff m | 15 m at | min clear m | along m | max off-line m | touchdown m | sink fpm | roll m | go-arounds | outcome |",
		"|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
	for r in results:
		lines.append("| %s | %d | %03.0f | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % [r.field, r.end, r.heading,
			r.aircraft, r.load, r.test, r.status, _num(r.get("liftoff_m")), _num(r.get("to_15m_m")), _num(r.get("min_clear_m")),
			_num(r.get("along_m")), _num(r.get("max_cross_m")), _num(r.get("touchdown_from_threshold_m")), _num(r.get("touchdown_fpm")), _num(r.get("roll_m")),
			_num(r.get("go_arounds"), "%d"), str(r.outcome).replace("|", "/")])
	return "\n".join(lines)
