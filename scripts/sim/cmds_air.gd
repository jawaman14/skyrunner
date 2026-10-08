extends RefCounted
## Stateless air commands; the passed Session owns all state.

static func _cmd_accept_job(role: String, a: Dictionary, session: Session):
	var action: Dictionary = session.job_action(role, "accept_job", int(session._num(a, "job_id", -1)))
	if not action.enabled:
		return action.disabled_reason
	var job := session.find_job(int(session._num(a, "job_id", -1)))
	return session.accept_job(job) if job else "No such job."


static func _cmd_drop_job(role: String, a: Dictionary, session: Session):
	var action: Dictionary = session.job_action(role, "drop_job", int(session._num(a, "job_id", -1)))
	if not action.enabled:
		return action.disabled_reason
	var job := session.find_job(int(session._num(a, "job_id", -1)))
	if job == null:
		return "No such job."
	session.drop_job(job)
	return null


static func _cmd_move_item(role: String, a: Dictionary, session: Session):
	if not session.parked:
		return "Loading happens on the ground, stopped."
	var iid := int(session._num(a, "item_id", -1))
	if not session.loadout.items.has(iid):
		return "No such item."
	if a.has("station"):  # direct placement (the load screen); -1 = back to the ramp
		var st = session._num(a, "station")
		if st == null:
			return "Bad arguments for move_item."
		return session.place_item(iid, int(st))
	session.cycle_item(iid, int(session._num(a, "direction", 1)))
	return null


static func _cmd_loadmaster(role: String, a: Dictionary, session: Session):
	return null if session.hire_loadmaster() else "Loadmaster couldn't fit everything."


static func _cmd_set_fuel(role: String, a: Dictionary, session: Session):
	if not session.parked:
		return "Refuel on the ground."
	session.set_fuel(float(session._num(a, "lb", 0.0)))
	return null


static func _cmd_fill_ferry(role: String, a: Dictionary, session: Session):
	return session.fill_ferry(float(session._num(a, "lb", 0.0)))


static func _cmd_buy_aircraft(role: String, a: Dictionary, session: Session):
	if not Aircraft.ROSTER.has(str(a.get("key", ""))):
		return "Bad arguments for buy_aircraft: unknown aircraft"
	return session.buy_or_switch(str(a["key"]))


static func _cmd_buy_gear(role: String, a: Dictionary, session: Session):
	return session.buy_gear(str(a.get("name", "")))


## Dial a Mode A code: four octal digits. 1200 is plain VFR; 7500/7600/7700 are
## the emergency codes, and Center reacts to them (police.gd _classify).
static func _cmd_squawk(role: String, a: Dictionary, session: Session):
	var code := str(a.get("code", "")).strip_edges()
	if code.length() != 4 or not code.is_valid_int() or code.contains("8") or code.contains("9"):
		return "Bad arguments for squawk: four octal digits, 0000-7777"
	session.squawk_code = code
	session.say("Squawking %s%s" % [code, {"7500": " (hijack)", "7600": " (radio failure)", "7700": " (emergency)"}.get(code, "")])
	return null


static func _cmd_upgrade(role: String, a: Dictionary, session: Session):
	return session.buy_upgrade(Roles.side(role), str(a.get("id", "")))


## The jammer van (law upgrade): a 5 km zone for three minutes around a point.
static func _cmd_jam(role: String, a: Dictionary, session: Session):
	if not session.upgrades["law"].has("jammer"):
		return "No jammer van (a Signals upgrade)."
	var p = session._point(a)
	if p == null:
		return "Bad arguments for jam: need x and y"
	session.radio.jammed_zones = session.radio.jammed_zones.filter(func(z): return z.size() < 4 or z[3] > session.time)
	session.radio.jammed_zones.append([p[0], p[1], 5000.0, session.time + 180.0])
	session.law_say("Jammer van on station at %.1f, %.1f km: 5 km, three minutes" % [p[0] / 1000, p[1] / 1000])
	return null


static func _cmd_transponder(role: String, a: Dictionary, session: Session):
	var on = a.get("on")
	session.transponder = (not session.transponder) if on == null else Py.truthy(on)
	var on_text := ("ON, %s squawking %s" % [session.squawk, session.squawk_code]) if SensorNet.REALISM else "ON, squawking " + session.squawk
	session.say("Transponder %s" % [on_text if session.transponder else "OFF"])
	return null


static func _cmd_turn_around(role: String, a: Dictionary, session: Session):
	return session.turn_around()


## U cycles off -> holding course -> routing to an airfield -> off (no new key: SHIFT+U already
## means something else when the island's in the game). `{"on": true/false}` (tests, other callers)
## is the plain hold, not the cycle - always just on or off. `{"on": true, "navigate": true}` asks
## for the routed leg directly.
static func _cmd_autopilot(role: String, a: Dictionary, session: Session):
	if a.has("on"):
		if not Py.truthy(a.on):
			session.autopilot.disengage()
			session.say("Autopilot OFF")
			return null
		if session.state == null or session.state.on_ground:
			return "Autopilot needs to be airborne."
		session.autopilot.min_ias_kts = session.spec.approach_kts * 1.05
		if Py.truthy(a.get("navigate", false)):
			session._autopilot_navigate()
		else:
			session.autopilot.engage(session.state, session.fm.controls.elevator)
			session.say("Autopilot ON: holding %s ft, heading %s" % [Py.f(session.state.alt / Session.FT, 0), Py.f(session.state.heading, 0)])
		return null
	if not session.autopilot.engaged:
		if session.state == null or session.state.on_ground:
			return "Autopilot needs to be airborne."
		session.autopilot.engage(session.state, session.fm.controls.elevator)
		session.autopilot.min_ias_kts = session.spec.approach_kts * 1.05
		session.say("Autopilot ON: holding %s ft, heading %s. U again to route to an airfield." % [Py.f(session.state.alt / Session.FT, 0), Py.f(session.state.heading, 0)])
	elif session.autopilot.waypoints.is_empty():
		session._autopilot_navigate()
	else:
		session.autopilot.disengage()
		session.say("Autopilot OFF")
	return null


static func _cmd_kick(role: String, a: Dictionary, session: Session):
	return session.request_kick(role, int(session._num(a, "count", 1)))


static func _cmd_auto_kick(role: String, a: Dictionary, session: Session):
	var on = a.get("on")
	session.auto_kick = (not session.auto_kick) if on == null else Py.truthy(on)
	return null


static func _cmd_pump(role: String, a: Dictionary, session: Session):
	if session.loadout.ferry_tanks().is_empty():
		return "No ferry tank aboard."
	var on = a.get("on")
	session.pumping = (not session.pumping) if on == null else Py.truthy(on)
	session.say("Ferry pump %s" % ("ON" if session.pumping else "OFF"))
	return null


static func _cmd_call_boat(role: String, a: Dictionary, session: Session):
	return session.call_boat(Py.truthy(a.get("brief", false)))


## The cutter captain: send a cutter (the one at sea, or launch one) to x, y.
static func _cmd_cutter_goto(role: String, a: Dictionary, session: Session):
	var p = session._point(a)
	if p == null:
		return "Bad arguments for cutter_goto: need x and y"
	var cutters := session.maritime.boats.filter(func(b): return b.kind == "cutter" and b.state != "sunk")
	var c = Py.first(cutters, func(b): return str(b.id) == str(a.get("id", ""))) if a.has("id") else (cutters[0] if not cutters.is_empty() else null)
	if c == null:
		if session.police.stock.get("cutter", 0) <= 0:
			return "No cutter available."
		session.police.stock["cutter"] -= 1
		c = session.maritime.new_cutter(p)
		session.radio.transmit(session.time, "police", c.id, "underway", [c.x, c.y])
	c.goal = p
	c.state = "patrol"
	return null


static func _cmd_boat_goto(role: String, a: Dictionary, session: Session):
	var boats := session.maritime.boats.filter(func(b): return b.kind == "gofast" and not (b.state in ["seized", "delivered"]))
	if boats.is_empty():
		return "No boat at sea."
	var p = session._point(a)
	if p == null:
		return "Bad arguments for boat_goto: need x and y"
	boats[0].goal = p
	boats[0].state = "to_rendezvous"
	return null


static func _cmd_confirm(role: String, a: Dictionary, session: Session):
	if session.court != null and session.court.holding():
		return "You're in custody: talk to your lawyer."
	if session.phase in ["crashed", "busted"]:
		session.respawn()
	return null


static func _cmd_launch(role: String, a: Dictionary, session: Session):
	var kind := str(a.get("kind", ""))
	var goal = session._point(a)
	if kind == "cutter":
		if not session.features.has("cutters"):
			return "No cutter assigned."
		if session.police.stock.get("cutter", 0) <= 0:
			return "No cutter available."
		session.police.stock["cutter"] -= 1
		var c := session.maritime.new_cutter(goal)
		session.radio.transmit(session.time, "police", c.id, "underway from the harbor", [c.x, c.y])
		return null
	return session.police.launch(kind, a.get("base"), null, goal)


static func _cmd_dispatch(role: String, a: Dictionary, session: Session):
	var point = session._point(a)
	var target = session.police.resolve(a.get("target"))
	var b := session.maritime.boat(a.get("unit"))
	if b != null and b.kind == "cutter":
		if point == null and target:
			var tr: SensorNet.Track = session.police.sensors.tracks.get(target)
			point = [tr.x, tr.y] if tr else null
		if point == null:
			return "Cutters need a point."
		b.goal = point
		b.state = "patrol"
		return null
	return session.police.dispatch(str(a.get("unit", "")), target, point)


static func _cmd_recall(role: String, a: Dictionary, session: Session):
	var b := session.maritime.boat(a.get("unit"))
	if b != null and b.kind == "cutter":
		b.state = "return"
		b.goal = null
		return null
	return session.police.recall(str(a.get("unit", "")))


## Police pilot seat: take the controls of an airborne unit, or launch one.
static func _cmd_claim_unit(role: String, a: Dictionary, session: Session):
	var ps := session.police
	if Py.any(ps.units, func(u): return u.pilot == role):
		return "You're already flying one."
	var unit = a.get("unit")
	if unit:
		var u = Py.first(ps.units, func(u): return u.id == unit and u.faction() == "police" and u.state != "crashed")
		if u == null or u.pilot:
			return "Can't take that one."
		u.pilot = role
		session.law_say("%s has the controls of %s" % [session.humans.get(role, role), u.id])
		return null
	var kind := str(a.get("kind", "interceptor"))
	if not (kind in ["heli", "interceptor"]):
		return "Helicopter or interceptor."
	var err = ps.launch(kind)
	if err:
		return err
	ps.pending_claim[role] = kind
	session.law_say("%s launching for %s" % [kind, session.humans.get(role, role)])
	return null


static func _cmd_release_unit(role: String, a: Dictionary, session: Session):
	for u in session.police.units:
		if u.pilot == role:
			u.pilot = null
			return null
	return "Not flying anything."


static func _cmd_encrypt(role: String, a: Dictionary, session: Session):
	return session.police.set_encryption(Py.truthy(a.get("on", true)))


static func _cmd_aerostat(role: String, a: Dictionary, session: Session):
	return session.police.set_aerostat(Py.truthy(a.get("on", true)))


static func _cmd_gun_mode(role: String, a: Dictionary, session: Session):
	var job = session.find_job(int(session._num(a, "job_id", -1)))
	if job == null:
		job = Py.first(session.active_jobs, func(j): return not j.weapons.is_empty())
	if job == null or job.weapons.is_empty():
		return "No gun run to set."
	var m := str(a.get("mode", "stock" if job.gun_mode == "sell" else "sell"))
	if not m in ["sell", "stock"]:
		return "Sell or stock."
	job.gun_mode = m
	for t in session.stash_net.trucks if session.stash_net != null else []:
		if t.job_id == job.id:
			t.gun_mode = m
	session.say("Gun run: %s on delivery." % ("sell them" if m == "sell" else "keep them for our soldiers"))
	return null
