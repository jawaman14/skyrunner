class_name Autopilot
extends RefCounted
## Simple two-axis autopilot: heading hold (through bank) and altitude hold.
##
## Cascade: altitude error -> target vertical speed -> target flight-path angle
## -> target pitch (integrator learns the trim pitch) -> elevator (PD + I).
## Heading error -> target bank -> aileron (PD). It exists so a solo pilot can
## leave the controls and go aft to kick bales - plain engage() just holds
## whatever heading and altitude it was switched on at.
##
## engage_route() (Session._cmd_autopilot, a second U) adds waypoints to fly -
## a winding, terrain-masking RoutePlanner route low over the ground with the
## transponder off for a hot leg, or for a legal one a cruise leg to a fix on
## the runway's extended centreline, a descent down a 3-degree path to a
## second fix and then down the runway (Session._approach_route): a join and a
## final, not a straight line at the field's centre. The cruise altitude is one
## number, set once from the route's highest terrain plus a margin (Session
## picks it): simpler and safer than following the terrain as it flies, which
## reacts late to what's coming up. A waypoint may carry its own altitude (the
## descent legs do).

var engaged := false
var alt_target := 0.0  ## m MSL
var hdg_target := 0.0
var pitch_base := 2.0  ## learned trim pitch, deg
var elev_i := 0.0
var min_ias_kts := 0.0  ## below this, give up altitude to keep flying speed
var waypoints: Array = []  ## [[x, y], or [x, y, alt_m], ...] still to fly; empty = plain heading hold. A third number is the altitude to fly on the way to that point.
var wp_i := 0
var arrived := false  ## engage_route() reached its last waypoint this frame (Session says so once)
var _leg_from := [0.0, 0.0]  ## the current leg's other end, for the course line (see update())
var _intercept = null  ## a temporary point flown ahead of waypoint wp_i when that fix lies behind us; the route itself is never edited
var _intercepted_wp := -1  ## the waypoint index that already had its one intercept, so a fix straight behind can't be put off for ever
const CLIMB_FPM_RECOVER := 1000.0  ## climb rate allowed when more than RECOVER_BELOW_M under the target
const RECOVER_BELOW_M := 120.0
const SPEED_MARGIN_KTS := 8.0  ## full power while within this of the minimum speed
const TERRAIN_LOOKAHEAD_S := 25.0  ## seconds of flight ahead whose ground height is checked on every frame
const TERRAIN_CLEARANCE_M := 100.0  ## the height above the highest of that ground it climbs to
const CLIMB_FPM_TERRAIN := 1800.0  ## the hardest climb it asks for when the ground ahead is above it
const AVOID_MARGIN_M := 150.0  ## ground this far above the aircraft ahead (after the clearance) is more than a climb will fix: turn away as well
const AVOID_STEP_DEG := 25.0
const LOW_TURN_AGL_M := 150.0  ## below this height above the ground a routed climb does not turn
const CLIMB_STRAIGHT_BELOW_M := 60.0  ## ... while it is at least this far under the target height
const MAX_BANK_DEG := 18.0  ## the bank limit of the lateral law below
var ground_fn := Callable()  ## (x, y) -> ground height in metres; Session sets it. Empty: no terrain look-ahead (unit tests of the pure law)
var terrain_aware := true  ## false for a hot (low, terrain-masking) route: it flies low on purpose, so the look-ahead must not lift it
var to_point := false  ## the route is the player's own waypoint, not an airfield: Session says so on arrival
const WAYPOINT_RADIUS_M := 800.0  ## this close (along the course, not as the crow flies): the next leg
const CROSS_TRACK_GAIN := 0.12  ## a sideways m/s to close per metre off the course line
const CROSS_TRACK_MAX_MS := 25.0  ## capped: don't bank hard just to shave off the last few metres
## The whole-route altitude margin above the highest terrain it crosses (Session._autopilot_navigate):
## matches the balance-tuned "low" and "high" tactics in scripts/balance/tactical.gd's TACTICS.
const LOW_AGL_M := 50.0  ## a hot leg: under the radar's clutter floor where the ground lets it
const CRUISE_AGL_M := 450.0  ## a legal leg: a proper cruise altitude


func engage(s: FlightModel.FlightState, elevator_now := 0.0) -> void:
	engaged = true
	terrain_aware = true
	alt_target = s.alt
	hdg_target = s.heading
	pitch_base = s.pitch
	elev_i = elevator_now
	waypoints = []
	wp_i = 0
	arrived = false


## `wps`: at least one waypoint, the last being the destination (Session._autopilot_navigate builds
## them: a straight shot for a legal leg, a valley route for a hot one). `alt_m`: MSL, held for the
## whole leg.
func engage_route(s: FlightModel.FlightState, wps: Array, alt_m: float, elevator_now := 0.0) -> void:
	engage(s, elevator_now)
	waypoints = wps
	wp_i = 0
	_intercept = null
	_intercepted_wp = -1
	_leg_from = [s.x, s.y]
	alt_target = alt_m


func disengage() -> void:
	engaged = false


func update(dt: float, s: FlightModel.FlightState, c: FlightModel.Controls) -> FlightModel.Controls:
	if not engaged or s.on_ground:
		return c
	if wp_i < waypoints.size():
		# a fixed course line for this leg (set once, not re-aimed at the waypoint every frame): aiming
		# straight at a point you're passing near, recomputed each frame, is pure-pursuit guidance,
		# and with a bank-limited turn it can settle into a stable orbit around the point instead of
		# ever reaching it. Flying a line and closing the cross-track error doesn't have that failure.
		var wp: Array = _intercept if _intercept != null else waypoints[wp_i]
		var course := PilotBot.bearing(_leg_from[0], _leg_from[1], wp[0], wp[1])
		var ac := _along_across(s.x, s.y, wp, course)
		# The fix is behind us (the course line points away from where we are heading): turning back onto it
		# inside the capture radius is what orbits it. Fly a short way ahead first, then take the real leg. The
		# intercept is temporary - the waypoint stays in the route - and each waypoint gets only one, so a fix
		# straight behind is turned back to after it, not postponed for ever.
		# Only a fix close enough that the turn itself would swing past it needs the fly-ahead; a far one behind is turned
		# towards directly (a bank-limited 180) instead of flying straight on first.
		var to_wp: float = PyMath.hypot(wp[0] - s.x, wp[1] - s.y)
		var turn_r: float = pow(s.gs_kts * 0.514444, 2.0) / (9.81 * tan(deg_to_rad(MAX_BANK_DEG)))  ## m: radius of a turn at the bank limit
		if _intercept == null and _intercepted_wp != wp_i and s.gs_kts > 20.0 \
				and absf(Py.wrap180(course - s.heading)) > 135.0 and to_wp < 4.0 * turn_r:
			var h := deg_to_rad(s.heading)
			var intercept_m := clampf(maxf(1200.0, s.gs_kts * 0.514444 * 12.0), 1200.0, 3500.0)
			_intercept = [s.x + sin(h) * intercept_m, s.y + cos(h) * intercept_m]
			_intercepted_wp = wp_i
			_leg_from = [s.x, s.y]
			wp = _intercept
			course = s.heading
			ac = _along_across(s.x, s.y, wp, course)
		if _intercept != null and ac[0] < WAYPOINT_RADIUS_M:
			# reached the intercept: now the real waypoint, along a course line from here
			_leg_from = _intercept
			_intercept = null
			wp = waypoints[wp_i]
			course = PilotBot.bearing(_leg_from[0], _leg_from[1], wp[0], wp[1])
			ac = _along_across(s.x, s.y, wp, course)
		if _intercept == null and ac[0] < WAYPOINT_RADIUS_M:
			if wp_i < waypoints.size() - 1:
				wp_i += 1
				_leg_from = wp
				wp = waypoints[wp_i]
				course = PilotBot.bearing(_leg_from[0], _leg_from[1], wp[0], wp[1])
				ac = _along_across(s.x, s.y, wp, course)
			else:
				# the last one: hold the course it arrived on rather than fly on past it for ever -
				# Session announces it once and this empties, so the next frame is a plain heading hold
				arrived = true
				waypoints = []
		if wp_i < waypoints.size():
			if wp.size() > 2:
				alt_target = float(wp[2])  # this leg has its own altitude: the descent down the glide path
			var across: float = ac[1]
			var gs := maxf(20.0, s.gs_kts * 0.514444)
			var v_lat := Py.clamp(-across * CROSS_TRACK_GAIN, -CROSS_TRACK_MAX_MS, CROSS_TRACK_MAX_MS)
			hdg_target = course + Py.degrees(asin(Py.clamp(v_lat / gs, -0.7, 0.7)))
	# terrain ahead: the ground within TERRAIN_LOOKAHEAD_S of flight along the heading, checked every frame, not only when it was engaged. If it is above the
	# height flown it climbs hard, at full power, to clear it; the route target is only raised, never lowered, and the leg resumes once clear.
	var threat := false
	var avoid_hdg := -1.0  ## >= 0: a heading with lower ground ahead, taken in preference to the route's
	# not on the descent legs of an approach (wp_i >= 1): the ground rises to meet the runway there, by design
	if ground_fn.is_valid() and terrain_aware and (waypoints.is_empty() or wp_i == 0):
		var reach := maxf(1500.0, s.gs_kts * 0.514444 * TERRAIN_LOOKAHEAD_S)
		var hr := deg_to_rad(s.heading)
		var peak := -1e9
		var d := 0.0
		while d <= reach:
			peak = maxf(peak, float(ground_fn.call(s.x + sin(hr) * d, s.y + cos(hr) * d)))
			d += 250.0
		if peak + TERRAIN_CLEARANCE_M > s.alt:
			threat = true
			alt_target = maxf(alt_target, peak + TERRAIN_CLEARANCE_M + 50.0)
		if peak + TERRAIN_CLEARANCE_M > s.alt + AVOID_MARGIN_M:
			# more ground than it can climb over: look left and right for a heading with lower ground ahead (not far from the one flown)
			var best_cost := peak
			for k in range(-4, 5):
				if k == 0:
					continue
				var h2 := deg_to_rad(s.heading + float(k) * AVOID_STEP_DEG)
				var pk := -1e9
				var d2 := 0.0
				while d2 <= reach:
					pk = maxf(pk, float(ground_fn.call(s.x + sin(h2) * d2, s.y + cos(h2) * d2)))
					d2 += 250.0
				var cost := pk + absf(float(k)) * 15.0
				if cost < best_cost - 30.0:
					best_cost = cost
					avoid_hdg = fposmod(s.heading + float(k) * AVOID_STEP_DEG, 360.0)
	# climbing out low (just off the ground, or recovering low) it keeps the heading it has and climbs: turning towards the next fix at 25 m up
	# is how it met the hill beside the strip. The route resumes once it is above LOW_TURN_AGL_M or near the target height.
	if not waypoints.is_empty() and s.agl < LOW_TURN_AGL_M and alt_target - s.alt > CLIMB_STRAIGHT_BELOW_M:
		hdg_target = s.heading
	if avoid_hdg >= 0.0:
		hdg_target = avoid_hdg
	# lateral
	var bank_t := Py.clamp(Py.wrap180(hdg_target - s.heading) * 1.2, -MAX_BANK_DEG, MAX_BANK_DEG)
	c.aileron = Py.clamp(0.04 * (bank_t - s.roll) - 0.012 * s.p_dps, -0.6, 0.6)
	c.rudder = 0.0
	# vertical
	# a long way below the target (climbing out after take-off, or recovering low) it may climb harder than the gentle cruise rate
	var climb_max := CLIMB_FPM_RECOVER if alt_target - s.alt > RECOVER_BELOW_M else 600.0
	if threat:
		climb_max = CLIMB_FPM_TERRAIN
		c.throttle = 1.0
	var vs_t := Py.clamp((alt_target - s.alt) * 18.0, -600.0, climb_max)  # fpm
	var tas := maxf(20.0, s.ias_kts * 0.514444)
	var gamma_t := Py.degrees(atan2(vs_t * 0.00508, tas))
	pitch_base = Py.clamp(pitch_base + (vs_t - s.vs_fpm) * 0.0006 * dt, -6.0, 12.0)
	var pitch_t := Py.clamp(pitch_base + gamma_t, -8.0, 14.0)
	if s.ias_kts < min_ias_kts:
		pitch_t = minf(pitch_t, s.pitch - (min_ias_kts - s.ias_kts) * 0.6)
		pitch_base = minf(pitch_base, pitch_t)
	if min_ias_kts > 0.0 and s.ias_kts < min_ias_kts + SPEED_MARGIN_KTS:
		c.throttle = 1.0  # too slow to be safe: full power until the speed is back (the pilot's throttle setting is not enough on its own)
	var err := pitch_t - s.pitch
	elev_i = Py.clamp(elev_i - err * 0.02 * dt, -0.6, 0.6)
	c.elevator = Py.clamp(-0.07 * err + 0.03 * s.q_dps + elev_i, -0.8, 0.8)
	return c


## [along, across] of (x, y) from `aim`, relative to the course line through it at heading `hdg_deg`
## (+along = not there yet, +across = right of the line). Same shape as FlightModel.Approach's.
static func _along_across(x: float, y: float, aim: Array, hdg_deg: float) -> Array:
	var h := deg_to_rad(hdg_deg)
	var ux := sin(h)
	var uy := cos(h)
	var dx: float = x - aim[0]
	var dy: float = y - aim[1]
	return [-(dx * ux + dy * uy), dx * uy - dy * ux]
