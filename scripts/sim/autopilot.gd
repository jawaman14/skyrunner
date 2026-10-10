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
const WAYPOINT_RADIUS_M := 800.0  ## this close (along the course, not as the crow flies): the next leg
const CROSS_TRACK_GAIN := 0.12  ## a sideways m/s to close per metre off the course line
const CROSS_TRACK_MAX_MS := 25.0  ## capped: don't bank hard just to shave off the last few metres
## The whole-route altitude margin above the highest terrain it crosses (Session._autopilot_navigate):
## matches the balance-tuned "low" and "high" tactics in scripts/balance/tactical.gd's TACTICS.
const LOW_AGL_M := 50.0  ## a hot leg: under the radar's clutter floor where the ground lets it
const CRUISE_AGL_M := 450.0  ## a legal leg: a proper cruise altitude


func engage(s: FlightModel.FlightState, elevator_now := 0.0) -> void:
	engaged = true
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
		var wp: Array = waypoints[wp_i]
		var course := PilotBot.bearing(_leg_from[0], _leg_from[1], wp[0], wp[1])
		var ac := _along_across(s.x, s.y, wp, course)
		# Rebuild a short forward intercept when a passed fix would otherwise orbit.
		var course_behind := absf(Py.wrap180(course - s.heading)) > 135.0
		if (ac[0] < -WAYPOINT_RADIUS_M or course_behind) and s.gs_kts > 20.0:
			var h := deg_to_rad(s.heading)
			var intercept_m := clampf(maxf(1200.0, s.gs_kts * 0.514444 * 12.0), 1200.0, 3500.0)
			var intercept := [s.x + sin(h) * intercept_m, s.y + cos(h) * intercept_m]
			_leg_from = [s.x, s.y]
			wp = intercept
			waypoints[wp_i] = intercept
			course = s.heading
			ac = _along_across(s.x, s.y, wp, course)
		if ac[0] < WAYPOINT_RADIUS_M:
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
	# lateral
	var bank_t := Py.clamp(Py.wrap180(hdg_target - s.heading) * 1.2, -18.0, 18.0)
	c.aileron = Py.clamp(0.04 * (bank_t - s.roll) - 0.012 * s.p_dps, -0.6, 0.6)
	c.rudder = 0.0
	# vertical
	var vs_t := Py.clamp((alt_target - s.alt) * 18.0, -600.0, 600.0)  # fpm
	var tas := maxf(20.0, s.ias_kts * 0.514444)
	var gamma_t := Py.degrees(atan2(vs_t * 0.00508, tas))
	pitch_base = Py.clamp(pitch_base + (vs_t - s.vs_fpm) * 0.0006 * dt, -6.0, 12.0)
	var pitch_t := Py.clamp(pitch_base + gamma_t, -8.0, 14.0)
	if s.ias_kts < min_ias_kts:
		pitch_t = minf(pitch_t, s.pitch - (min_ias_kts - s.ias_kts) * 0.6)
		pitch_base = minf(pitch_base, pitch_t)
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
