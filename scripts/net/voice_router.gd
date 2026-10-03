class_name VoiceRouter
extends RefCounted
## Who hears a voice transmission, and how well: the radio's rules, applied to the seats.
##
## Two channels, picked by the speaker:
##   "net"  the speaker's own side's radio net (runners: pilot, co-pilot, boss, lieutenant, spotter, boat; law: controller,
##          chief, patrol, interceptor, cutter). Heard at a quality that falls with distance and dies where the terrain or the
##          horizon is in the way (RadioNet.can_hear: the same VHF line of sight the scanner and the DF stations use). Seats
##          with no place on the map (a spotter, a boat) are heard at a flat 0.75.
##   "all"  the table: everyone, always clear (the lobby, and a word across the table).
##
## And the other side listening in, with the game's own counters:
##   * the law hears a runner net transmission once it has bought "Intercept runner channels" (and is in range of a DF
##     station or its own seat), clear;
##   * a runner hears the police net only with the scanner, and it is scrambled when the task force has paid for
##     encryption.
##
## Pure: Session in, [{id, q, kind}] out ("net" | "all" | "intercept" | "scrambled"), so it is tested without a network.

const NO_GEOMETRY_Q := 0.75
const INTERCEPT_FACTOR := 0.85


## `listeners`: [{id, role}] (role "" is a player in the lobby with no seat). `from_id` is not sent its own voice.
static func route(sess, from_id: String, from_role: String, channel: String, listeners: Array) -> Array:
	var out := []
	for l in listeners:
		if str(l.id) == from_id:
			continue
		var h := hear(sess, from_role, channel, str(l.role))
		if float(h[0]) > 0.0:
			out.append({"id": l.id, "q": h[0], "kind": h[1]})
	return out


## [quality, kind] with which a seat `to_role` hears a seat `from_role` on `channel` (quality 0: not at all).
static func hear(sess, from_role: String, channel: String, to_role: String) -> Array:
	if channel == "all":
		return [1.0, "all"]
	if from_role == "" or to_role == "":
		return [0.0, ""]  # the net is for seated players
	var a := Roles.side(from_role)
	var b := Roles.side(to_role)
	if a == b:
		return [link(sess, from_role, to_role), "net"]
	if a == "runner":  # the law listening in
		if sess.upgrades["law"].has("intercept"):
			var q := link(sess, from_role, to_role) * INTERCEPT_FACTOR
			return [q, "intercept"]
		return [0.0, ""]
	# a runner listening to the police net
	if not sess.features.has("scanner"):
		return [0.0, ""]
	var q := link(sess, from_role, to_role) * INTERCEPT_FACTOR
	return [q, "scrambled" if sess.radio.encrypted else "intercept"]


## How well two seats' radios reach each other (0 none, 1 right beside): the VHF horizon and the hills between them.
static func link(sess, a_role: String, b_role: String) -> float:
	var pa = sess.role_position(a_role)
	var pb = sess.role_position(b_role)
	if pa == null or pb == null or sess.radio == null or sess.radio.world == null or not RadioNet.REALISM:
		return NO_GEOMETRY_Q if (pa == null or pb == null) else 1.0
	if not sess.radio.can_hear(pa, pb):
		return 0.0
	var w: World = sess.radio.world
	var h1: float = maxf(2.0, float(pa[2]) - w.ground(pa[0], pa[1])) if pa[2] != null else 2.0
	var h2: float = maxf(2.0, float(pb[2]) - w.ground(pb[0], pb[1])) if pb[2] != null else 2.0
	var d := Vector2(pa[0], pa[1]).distance_to(Vector2(pb[0], pb[1]))
	var horizon := 4120.0 * (sqrt(h1) + sqrt(h2))
	return clampf(1.0 - d / horizon, 0.12, 1.0)
