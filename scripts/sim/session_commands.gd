class_name SessionCommands
extends SessionTick
## Layer 5 of 6 of the Session: the command surface. Every action goes through command(role, name, args), which
## dispatches to a _cmd_* handler here.

## The single entry point for every non-flight action: [ok, message].
func command(role: String, name: String, args := {}) -> Array:
	if not Roles.valid(role):
		return [false, "Unknown role %s." % role]
	if not Roles.allowed(role, name):
		return [false, "%s can't do '%s'." % [role, name]]
	var handler := "_cmd_" + name
	if not has_method(handler):
		return [false, "Unknown command %s." % name]
	if name in ActionDescriptions.SUPPORTED:
		var action := describe_action(role, name, args)
		if not action.enabled:
			return [false, action.disabled_reason]
	var cash_before := money
	var prisoners_before: int = int(rackets.held) if rackets != null and name == "rackets" else 0
	var err = call(handler, role, args)
	if err:
		return [false, err]
	var message := "ok"
	if logistics != null and name in ["move_cash", "move_goods", "cash_round", "goods_round", "sell_product", "move_armoury"]:
		message = str(logistics.last)
	elif trade != null and name == "sell_product" and not trade.bulk_log.is_empty():
		var sale: Array = trade.bulk_log[-1]
		message = "Sold %.1f %s to %s: +$%s." % [float(sale[3]), str(sale[2]), Trade.BUYERS[str(sale[1])].name, Py.money(money - cash_before)]
	if name == "rackets":
		match str(args.get("what", "")):
			"ransom": message = "Ransomed %d prisoners: credited $%s." % [prisoners_before, Py.money(money - cash_before)]
			"turn": message = "Recruited %d soldiers; continuing payroll wages apply." % prisoners_before
			"release": message = "Released %d prisoners." % prisoners_before
			"policy": message = "Policy for %s: %s." % [str(args.get("market", "")), str(args.get("mode", ""))]
	if tutorial != null:
		tutorial.command_done(role, name)
	return [true, message if not message.is_empty() else "ok"]


## A numeric command argument, or null when missing or not a number. GDScript has
## no try/except, so commands from the network are validated here instead.
static func _num(args: Dictionary, k: String, default = null):
	var v = args.get(k)
	if v is int or v is float:
		return float(v)
	if v is String and v.is_valid_float():
		return v.to_float()
	return default


static func _point(args: Dictionary):
	var x = _num(args, "x")
	var y = _num(args, "y")
	return [x, y] if x != null and y != null else null


func _cmd_accept_job(role: String, a: Dictionary):
	var action: Dictionary = job_action(role, "accept_job", int(_num(a, "job_id", -1)))
	if not action.enabled:
		return action.disabled_reason
	var job := find_job(int(_num(a, "job_id", -1)))
	return accept_job(job) if job else "No such job."


func _cmd_drop_job(role: String, a: Dictionary):
	var action: Dictionary = job_action(role, "drop_job", int(_num(a, "job_id", -1)))
	if not action.enabled:
		return action.disabled_reason
	var job := find_job(int(_num(a, "job_id", -1)))
	if job == null:
		return "No such job."
	drop_job(job)
	return null


func _cmd_move_item(role: String, a: Dictionary):
	if not parked:
		return "Loading happens on the ground, stopped."
	var iid := int(_num(a, "item_id", -1))
	if not loadout.items.has(iid):
		return "No such item."
	if a.has("station"):  # direct placement (the load screen); -1 = back to the ramp
		var st = _num(a, "station")
		if st == null:
			return "Bad arguments for move_item."
		return place_item(iid, int(st))
	cycle_item(iid, int(_num(a, "direction", 1)))
	return null


func _cmd_loadmaster(role: String, a: Dictionary):
	return null if hire_loadmaster() else "Loadmaster couldn't fit everything."


func _cmd_set_fuel(role: String, a: Dictionary):
	if not parked:
		return "Refuel on the ground."
	set_fuel(float(_num(a, "lb", 0.0)))
	return null


func _cmd_fill_ferry(role: String, a: Dictionary):
	return fill_ferry(float(_num(a, "lb", 0.0)))


func _cmd_buy_aircraft(role: String, a: Dictionary):
	if not Aircraft.ROSTER.has(str(a.get("key", ""))):
		return "Bad arguments for buy_aircraft: unknown aircraft"
	return buy_or_switch(str(a["key"]))


func _cmd_buy_gear(role: String, a: Dictionary):
	return buy_gear(str(a.get("name", "")))


func _cmd_hire_spotter(role: String, a: Dictionary):
	var code = a.get("code")
	return hire_spotter(code if code else location)


func _cmd_spotter_move(role: String, a: Dictionary):
	var code = a.get("code")
	if not World.AIRFIELD_BY_CODE.has(code) or spotters.is_empty():
		return "No spotter / unknown field."
	var sp: Spotter = spotters[mini(int(_num(a, "index", 0)), spotters.size() - 1)]
	sp.moving_to = code
	sp.move_t = SPOTTER_MOVE_S
	say("Spotter heading to %s (60 s)" % World.airfield(code).name)
	return null


## Dial a Mode A code: four octal digits. 1200 is plain VFR; 7500/7600/7700 are
## the emergency codes, and Center reacts to them (police.gd _classify).
func _cmd_squawk(role: String, a: Dictionary):
	var code := str(a.get("code", "")).strip_edges()
	if code.length() != 4 or not code.is_valid_int() or code.contains("8") or code.contains("9"):
		return "Bad arguments for squawk: four octal digits, 0000-7777"
	squawk_code = code
	say("Squawking %s%s" % [code, {"7500": " (hijack)", "7600": " (radio failure)", "7700": " (emergency)"}.get(code, "")])
	return null


func _cmd_upgrade(role: String, a: Dictionary):
	return buy_upgrade(Roles.side(role), str(a.get("id", "")))


## The jammer van (law upgrade): a 5 km zone for three minutes around a point.
func _cmd_jam(role: String, a: Dictionary):
	if not upgrades["law"].has("jammer"):
		return "No jammer van (a Signals upgrade)."
	var p = _point(a)
	if p == null:
		return "Bad arguments for jam: need x and y"
	radio.jammed_zones = radio.jammed_zones.filter(func(z): return z.size() < 4 or z[3] > time)
	radio.jammed_zones.append([p[0], p[1], 5000.0, time + 180.0])
	law_say("Jammer van on station at %.1f, %.1f km: 5 km, three minutes" % [p[0] / 1000, p[1] / 1000])
	return null


func _cmd_transponder(role: String, a: Dictionary):
	var on = a.get("on")
	transponder = (not transponder) if on == null else Py.truthy(on)
	var on_text := ("ON, %s squawking %s" % [squawk, squawk_code]) if SensorNet.REALISM else "ON, squawking " + squawk
	say("Transponder %s" % [on_text if transponder else "OFF"])
	return null


func _cmd_turn_around(role: String, a: Dictionary):
	return turn_around()


## U cycles off -> holding course -> routing to an airfield -> off (no new key: SHIFT+U already
## means something else when the island's in the game). `{"on": true/false}` (tests, other callers)
## is the plain hold, not the cycle - always just on or off. `{"on": true, "navigate": true}` asks
## for the routed leg directly.
func _cmd_autopilot(role: String, a: Dictionary):
	if a.has("on"):
		if not Py.truthy(a.on):
			autopilot.disengage()
			say("Autopilot OFF")
			return null
		if state == null or state.on_ground:
			return "Autopilot needs to be airborne."
		autopilot.min_ias_kts = spec.approach_kts * 1.05
		if Py.truthy(a.get("navigate", false)):
			_autopilot_navigate()
		else:
			autopilot.engage(state, fm.controls.elevator)
			say("Autopilot ON: holding %s ft, heading %s" % [Py.f(state.alt / FT, 0), Py.f(state.heading, 0)])
		return null
	if not autopilot.engaged:
		if state == null or state.on_ground:
			return "Autopilot needs to be airborne."
		autopilot.engage(state, fm.controls.elevator)
		autopilot.min_ias_kts = spec.approach_kts * 1.05
		say("Autopilot ON: holding %s ft, heading %s. U again to route to an airfield." % [Py.f(state.alt / FT, 0), Py.f(state.heading, 0)])
	elif autopilot.waypoints.is_empty():
		_autopilot_navigate()
	else:
		autopilot.disengage()
		say("Autopilot OFF")
	return null


## The second U: fly toward a destination instead of just holding course - a straight shot at
## cruise altitude for a legal load, a winding, terrain-low RoutePlanner route for a hot one. The
## transponder defaults to squawking either way - squawking traffic that isn't already a tip or a
## known case draws no suspicion at all (PoliceSystem._classify), so it's the safer default even
## hot. It only goes dark on a hot leg once there's heat to hide from (wanted, tipped, or suspicion
## already up) - and only below the clutter floor does dark actually make it vanish; above it, a
## squawk that cuts out is itself the tell (see HELP_TEXT). (Open: routing doesn't avoid known radar
## coverage, only gets under its clutter floor - see docs/ROADMAP.md.)
func _autopilot_navigate() -> void:
	var af := _autopilot_target()
	if af == null or PyMath.hypot(af.x - state.x, af.y - state.y) < AUTOPILOT_MIN_ROUTE_M:
		autopilot.engage(state, fm.controls.elevator)
		say("Autopilot ON: nowhere worth routing to from here - holding %s ft, heading %s" % [Py.f(state.alt / FT, 0), Py.f(state.heading, 0)])
		return
	var hot := carrying_hot()
	var wps: Array
	if hot:
		wps = RoutePlanner.plan_route(world, [state.x, state.y], [af.x, af.y])
		var c := police.case("runner")
		transponder = not (c.wanted > 0 or c.tipped or c.suspicion >= AUTOPILOT_HOT_DARK_SUSPICION)
	else:
		wps = _approach_route(af)
	var peak := world.ground(state.x, state.y)
	var prev: Array = [state.x, state.y]
	for wp in wps:
		var steps := maxi(1, int(PyMath.hypot(wp[0] - prev[0], wp[1] - prev[1]) / 500.0))
		for k in steps + 1:
			var p := [lerpf(prev[0], wp[0], float(k) / steps), lerpf(prev[1], wp[1], float(k) / steps)]
			peak = maxf(peak, world.ground(p[0], p[1]))
		prev = wp
	var margin := Autopilot.LOW_AGL_M if hot else Autopilot.CRUISE_AGL_M
	if not hot:
		wps[0] = [wps[0][0], wps[0][1], peak + margin]
		if wps.size() > 2:  # the descent legs must clear the ground they cross, whatever the glide path says
			wps[1][2] = maxf(float(wps[1][2]), maxf(world.ground(wps[1][0], wps[1][1]), world.ground(wps[2][0], wps[2][1])) + 90.0)
	autopilot.engage_route(state, wps, peak + margin, fm.controls.elevator)
	say("Autopilot ON, heading for %s: %s, %s, %s ft." % [af.name, "low over the ground" if hot else "joining the approach",
		"squawking" if transponder else "transponder off", Py.f((peak + margin) / FT, 0)])


## A legal leg to `af`: a join on the extended centreline of the runway end it comes at, then down a 3-degree
## path to a final fix and along the runway at 30 m. [x, y, alt_m] each (the first altitude is set by the caller
## to the cruise altitude). Which end: whichever puts the join nearer the aircraft, so it never overflies the field
## to turn back onto it. Close in (less than the join's distance), it goes straight to the final fix.
func _approach_route(af: Airfield) -> Array:
	var elev := world.airfield_elev(af)
	var best: Array = []
	var best_d := INF
	for end in [0, 1]:
		var th: Array = af.threshold(end)
		var sgn := -1.0 if end == 0 else 1.0  ## the way out along the extended centreline from this threshold
		var fix := [th[0] + sgn * af.ux * APPROACH_FINAL_M, th[1] + sgn * af.uy * APPROACH_FINAL_M]
		var d := PyMath.hypot(fix[0] - state.x, fix[1] - state.y)
		if d < best_d:
			best_d = d
			best = [th, sgn, fix]
	var th2: Array = best[0]
	var sg: float = best[1]
	var fix2: Array = best[2]
	var join := [th2[0] + sg * af.ux * APPROACH_JOIN_M, th2[1] + sg * af.uy * APPROACH_JOIN_M]
	var final_alt := elev + APPROACH_FINAL_M * tan(deg_to_rad(3.0)) + 15.0
	var route: Array = []
	if PyMath.hypot(join[0] - state.x, join[1] - state.y) > APPROACH_JOIN_M * 0.6:
		route.append([join[0], join[1], final_alt + 200.0])
	else:
		route.append([fix2[0], fix2[1], final_alt + 200.0])
	route.append([fix2[0], fix2[1], final_alt])
	route.append([th2[0], th2[1], elev + 30.0])
	return route


## An active job's own strip (not an airdrop: that's a point in the water, not somewhere to land),
## nearest first; failing that, the nearest airfield worth the trip - never the one just departed
## (fresh off the ramp, "the nearest airfield" is almost always the one behind you) or one that's
## implausibly close for some other reason.
func _autopilot_target() -> Airfield:
	var best: Airfield = null
	var bd := INF
	for j in active_jobs:
		if j.is_airdrop():
			continue
		var af := World.airfield(j.dest)
		var d: float = PyMath.hypot(af.x - state.x, af.y - state.y)
		if d < bd:
			bd = d
			best = af
	if best != null:
		return best
	for af in World.AIRFIELDS:
		if af.code == log.departed_from:
			continue
		var d: float = PyMath.hypot(af.x - state.x, af.y - state.y)
		if d < bd and d > AUTOPILOT_MIN_ROUTE_M:
			bd = d
			best = af
	return best if best != null else world.nearest_airfield(state.x, state.y)[0]


func _cmd_kick(role: String, a: Dictionary):
	return request_kick(role, int(_num(a, "count", 1)))


func _cmd_auto_kick(role: String, a: Dictionary):
	var on = a.get("on")
	auto_kick = (not auto_kick) if on == null else Py.truthy(on)
	return null


func _cmd_pump(role: String, a: Dictionary):
	if loadout.ferry_tanks().is_empty():
		return "No ferry tank aboard."
	var on = a.get("on")
	pumping = (not pumping) if on == null else Py.truthy(on)
	say("Ferry pump %s" % ("ON" if pumping else "OFF"))
	return null


func _cmd_call_boat(role: String, a: Dictionary):
	return call_boat(Py.truthy(a.get("brief", false)))


## Flip one role between its AI and a human (Seats calls this; every switch is
## symmetric, so a seat handed back works exactly as it did before).
func seat_driver(role: String, human: bool) -> void:
	match role:
		Roles.COPILOT:
			if human:
				_ai_defaults[role] = copilot if copilot != "human" else _ai_defaults.get(role)
				set_copilot("human")
			else:
				set_copilot(_ai_defaults.get(role))
		Roles.CONTROLLER:
			police.controller = "human" if human else "ai"
			if court != null:
				court.prosecutor_ai = not (human or humans.has(Roles.CHIEF))
			if nights != null and not humans.has(Roles.CHIEF):
				nights.law_ai = null if human else "adaptive"
		Roles.BOSS:
			if family != null:
				family.ai = not (human or humans.has(Roles.LIEUTENANT))
			if payroll != null:
				payroll.ai["org"] = not (human or humans.has(Roles.LIEUTENANT))
			if ground != null:
				ground.commanders["org"].ai = not (human or humans.has(Roles.LIEUTENANT))
			if nights != null:
				if human:
					_ai_defaults[role] = nights.runner_ai
					nights.runner_ai = null
				else:
					nights.runner_ai = _ai_defaults.get(role, nights.runner_ai)
		Roles.CHIEF:
			if court != null:
				court.prosecutor_ai = not (human or humans.has(Roles.CONTROLLER))
			if nights != null:
				nights.law_ai = null if (human or humans.has(Roles.CONTROLLER)) else "adaptive"
		Roles.INTERCEPTOR:
			if not human:
				command(role, "release_unit", {})
		Roles.LIEUTENANT:
			if ground != null:
				ground.commanders["org"].ai = not (human or humans.has(Roles.BOSS))
			if family != null:
				family.ai = not (human or humans.has(Roles.BOSS))
			if payroll != null:
				payroll.ai["org"] = not (human or humans.has(Roles.BOSS))
		Roles.PATROL:
			if ground != null:
				ground.commanders["police"].ai = not human
		Roles.UNDERCOVER:
			if undercover != null:
				undercover.held = human
		Roles.MECHANIC:
			if airframe != null:
				airframe.held = human
		Roles.ANALYST:
			if analyst != null:
				analyst.held = human
				if not human:
					analyst.release_all()  # dispatch gets whatever was waiting
	var who := "joined as" if human else "handed back"
	var name: String = humans.get(role, seats.seats[role].name if seats != null else "")
	var text := ("%s %s %s." % [name, who, role]) if human else ("%s is back on the AI." % role)
	say(text)
	law_say(text)


## A remote pilot's stick as flight controls (pitch +1 = nose up).
func remote_controls() -> FlightModel.Controls:
	var r := remote_stick
	return FlightModel.Controls.make({"aileron": float(r.get("roll", 0.0)), "elevator": -float(r.get("pitch", 0.0)),
		"throttle": float(r.get("throttle", 0.0)), "rudder": float(r.get("rudder", 0.0)), "brake": float(r.get("brake", 0.0)),
		"flaps": fm.controls.flaps if fm != null else 0.0})


## The cutter captain: send a cutter (the one at sea, or launch one) to x, y.
func _cmd_cutter_goto(role: String, a: Dictionary):
	var p = _point(a)
	if p == null:
		return "Bad arguments for cutter_goto: need x and y"
	var cutters := maritime.boats.filter(func(b): return b.kind == "cutter" and b.state != "sunk")
	var c = Py.first(cutters, func(b): return str(b.id) == str(a.get("id", ""))) if a.has("id") else (cutters[0] if not cutters.is_empty() else null)
	if c == null:
		if police.stock.get("cutter", 0) <= 0:
			return "No cutter available."
		police.stock["cutter"] -= 1
		c = maritime.new_cutter(p)
		radio.transmit(time, "police", c.id, "underway", [c.x, c.y])
	c.goal = p
	c.state = "patrol"
	return null


func _cmd_boat_goto(role: String, a: Dictionary):
	var boats := maritime.boats.filter(func(b): return b.kind == "gofast" and not (b.state in ["seized", "delivered"]))
	if boats.is_empty():
		return "No boat at sea."
	var p = _point(a)
	if p == null:
		return "Bad arguments for boat_goto: need x and y"
	boats[0].goal = p
	boats[0].state = "to_rendezvous"
	return null


func _cmd_confirm(role: String, a: Dictionary):
	if court != null and court.holding():
		return "You're in custody: talk to your lawyer."
	if phase in ["crashed", "busted"]:
		respawn()
	return null


func _cmd_hq(role: String, a: Dictionary):
	if nights == null:
		return "No HQ in this game (needs layer 5)."
	if role == Roles.PILOT and humans.has(Roles.BOSS):
		return "%s is the boss - ask them." % humans[Roles.BOSS]
	if role == Roles.CONTROLLER and humans.has(Roles.CHIEF):
		return "%s holds the budget - ask them." % humans[Roles.CHIEF]
	var args := a.duplicate()
	var order := str(args.get("order", ""))
	args.erase("order")
	return nights.order(Roles.side(role), order, args)


## Where a seat's radio is: [x, y, z (m MSL, null on the ground)], or null when the seat has no place on the map. The
## pilot and co-pilot are the aircraft; the desks are their headquarters' masts (RadioNet.DF_MAST_M up).
func role_position(role: String):
	match role:
		Roles.PILOT, Roles.COPILOT:
			if state == null:
				return null
			return [state.x, state.y, null if state.on_ground else state.alt]
		Roles.BOSS, Roles.LIEUTENANT, Roles.CONTROLLER, Roles.CHIEF, Roles.PATROL:
			var kind := "org" if role in [Roles.BOSS, Roles.LIEUTENANT] else "law"
			var h = world.map.hqs.get(kind)
			if h != null:
				return [h.x, h.y, world.ground(h.x, h.y) + RadioNet.DF_MAST_M]
	return null


## A voice transmission on the side's net has ended (`dur` s on the air): from the air it is a runner transmission like
## any other, so the DF stations get their bearing (and, with the intercept upgrade, the law hears the words).
func voice_transmitted(role: String, dur: float) -> void:
	if RadioNet.REALISM and role in [Roles.PILOT, Roles.COPILOT] and state != null and not state.on_ground:
		_df_on(radio.transmit(time, "runner", squawk, "(voice)", [state.x, state.y, state.alt], clampf(dur, 1.0, 20.0)))


func _cmd_chat(role: String, a: Dictionary):
	var text := str(a.get("text", "")).substr(0, 200)
	if Roles.side(role) == "runner":
		say("[%s] %s" % [role, text])
		# crew radio is real radio: from the aircraft, anyone listening can hear it
		if RadioNet.REALISM and role in [Roles.PILOT, Roles.COPILOT] and state != null and not state.on_ground:
			_df_on(radio.transmit(time, "runner", squawk, text, [state.x, state.y, state.alt],
				1.0 if upgrades["runner"].has("burst_radio") else -1.0))
	else:
		law_say("[%s] %s" % [role, text])
	return null


# law side
## Dispatch on the tactical channel: a scanner programmed only for dispatch goes
## quiet. Free, unlike encryption - but a runner can program the scanner too.
func _cmd_radio_channel(role: String, a: Dictionary):
	var ch := str(a.get("channel", ""))
	if not (ch in ["police", "police_tac"]):
		return "Bad arguments for radio_channel: police or police_tac"
	radio.police_channel = ch
	law_say("Dispatch now on the %s channel" % ("tactical" if ch == "police_tac" else "main"))
	return null


func _cmd_launch(role: String, a: Dictionary):
	var kind := str(a.get("kind", ""))
	var goal = _point(a)
	if kind == "cutter":
		if not features.has("cutters"):
			return "No cutter assigned."
		if police.stock.get("cutter", 0) <= 0:
			return "No cutter available."
		police.stock["cutter"] -= 1
		var c := maritime.new_cutter(goal)
		radio.transmit(time, "police", c.id, "underway from the harbor", [c.x, c.y])
		return null
	return police.launch(kind, a.get("base"), null, goal)


func _cmd_dispatch(role: String, a: Dictionary):
	var point = _point(a)
	var target = police.resolve(a.get("target"))
	var b := maritime.boat(a.get("unit"))
	if b != null and b.kind == "cutter":
		if point == null and target:
			var tr: SensorNet.Track = police.sensors.tracks.get(target)
			point = [tr.x, tr.y] if tr else null
		if point == null:
			return "Cutters need a point."
		b.goal = point
		b.state = "patrol"
		return null
	return police.dispatch(str(a.get("unit", "")), target, point)


func _cmd_recall(role: String, a: Dictionary):
	var b := maritime.boat(a.get("unit"))
	if b != null and b.kind == "cutter":
		b.state = "return"
		b.goal = null
		return null
	return police.recall(str(a.get("unit", "")))


## Police pilot seat: take the controls of an airborne unit, or launch one.
func _cmd_claim_unit(role: String, a: Dictionary):
	var ps := police
	if Py.any(ps.units, func(u): return u.pilot == role):
		return "You're already flying one."
	var unit = a.get("unit")
	if unit:
		var u = Py.first(ps.units, func(u): return u.id == unit and u.faction() == "police" and u.state != "crashed")
		if u == null or u.pilot:
			return "Can't take that one."
		u.pilot = role
		law_say("%s has the controls of %s" % [humans.get(role, role), u.id])
		return null
	var kind := str(a.get("kind", "interceptor"))
	if not (kind in ["heli", "interceptor"]):
		return "Helicopter or interceptor."
	var err = ps.launch(kind)
	if err:
		return err
	ps.pending_claim[role] = kind
	law_say("%s launching for %s" % [kind, humans.get(role, role)])
	return null


func _cmd_release_unit(role: String, a: Dictionary):
	for u in police.units:
		if u.pilot == role:
			u.pilot = null
			return null
	return "Not flying anything."


func set_pilot_input(role: String, roll: float, pitch: float, throttle: float) -> void:
	pilot_input[role] = [roll, pitch, throttle]


func _cmd_encrypt(role: String, a: Dictionary):
	return police.set_encryption(Py.truthy(a.get("on", true)))


func _cmd_aerostat(role: String, a: Dictionary):
	return police.set_aerostat(Py.truthy(a.get("on", true)))


func _cmd_gun_mode(role: String, a: Dictionary):
	var job = find_job(int(_num(a, "job_id", -1)))
	if job == null:
		job = Py.first(active_jobs, func(j): return not j.weapons.is_empty())
	if job == null or job.weapons.is_empty():
		return "No gun run to set."
	var m := str(a.get("mode", "stock" if job.gun_mode == "sell" else "sell"))
	if not m in ["sell", "stock"]:
		return "Sell or stock."
	job.gun_mode = m
	for t in stash_net.trucks if stash_net != null else []:
		if t.job_id == job.id:
			t.gun_mode = m
	say("Gun run: %s on delivery." % ("sell them" if m == "sell" else "keep them for our soldiers"))
	return null


func _cmd_sell_weapons(role: String, a: Dictionary):
	if not Arsenal.REALISM:
		return "No arsenal."
	if not unlocked("guns"):
		return "No gun dealer will talk to us yet."
	var tier := str(a.get("tier", ""))
	var n := int(_num(a, "n", 1))
	if not Arsenal.TIERS.has(tier) or n <= 0:
		return "Sell what?"
	var k: int = arsenals["org"].take(tier, n)
	if k == 0:
		return "None of those in the armoury."
	var pay := weapon_price(tier, false) * k
	money += pay
	econ.record_delivery("guns", "town")
	say("Sold %d %s to the fence: +$%s" % [k, Arsenal.TIERS[tier].name.to_lower(), Py.money(pay)])
	return null


func _cmd_buy_weapons(role: String, a: Dictionary):
	if not Arsenal.REALISM:
		return "No arsenal."
	if not unlocked("guns"):
		return "No gun dealer will talk to us yet."
	var tier := str(a.get("tier", ""))
	var n := int(_num(a, "n", 1))
	if not Arsenal.TIERS.has(tier) or n <= 0:
		return "Buy what?"
	var cost := weapon_price(tier, true) * n
	if money < cost:
		return "Need $%s." % Py.money(cost)
	money -= cost
	arsenals["org"].add(tier, n)
	say("Bought %d %s from a dealer: -$%s" % [n, Arsenal.TIERS[tier].name.to_lower(), Py.money(cost)])
	return null


func _cmd_set_cache(role: String, a: Dictionary):
	if not Arsenal.REALISM:
		return "No arsenal."
	var id := str(a.get("stash", ""))
	if id != "" and (stash_net == null or stash_net.get_stash(id) == null or stash_net.get_stash(id).burned):
		return "No such stash."
	arsenals["org"].cache = id
	say("The guns are kept at %s now." % ("the club" if id == "" else stash_net.get_stash(id).name))
	return null


func _cmd_squad_order(role: String, a: Dictionary):
	if ground == null:
		return "No ground war here."
	var q = ground.get_squad(str(a.get("id", "")))
	if q == null or q.faction != _faction_of(role):
		return "Not one of ours."
	var o: Dictionary = a.get("order", {}) if a.get("order") is Dictionary else {"type": str(a.get("order", ""))}
	for k in ["x", "y", "stash", "market", "squad", "job_id"]:
		if a.has(k) and not o.has(k):
			o[k] = a[k]
	var err: String = ground.order(q, o)
	if err != "":
		return err
	q.human = true
	if o.get("type", "") == "stakeout" and o.has("stash"):
		ground.stakeouts[str(o.stash)] = q.id
	return null


## On foot, an order to the nearest of our squads: {what: come | hold | charge | fall_back, x, y} (where the man stands).
func _cmd_field_order(role: String, a: Dictionary):
	if ground == null:
		return "No ground war here: nobody to command."
	var r: Array = ground.field_order(_faction_of(role), Vector2(float(_num(a, "x", 0.0)), float(_num(a, "y", 0.0))), str(a.get("what", "")))
	if r[0] != "":
		return r[0]
	say(str(r[1]))
	return null


## The collectors and the prisoners: {what: policy (market, mode) | ransom | turn | release}.
func _cmd_rackets(role: String, a: Dictionary):
	if rackets == null:
		return "Nobody collects for us here."
	var err := ""
	match str(a.get("what", "")):
		"policy":
			err = rackets.set_policy(str(a.get("market", "")), str(a.get("mode", "")))
		"ransom":
			err = rackets.ransom()
		"turn":
			err = rackets.turn()
		"release":
			err = rackets.release()
		_:
			err = "Policy, ransom, turn or release."
	return err if err != "" else null


## Build at a stash house: {stash, what: vault | guard}.
func _cmd_stash_works(role: String, a: Dictionary):
	var err := StashWorks.build(self, str(a.get("stash", "")), str(a.get("what", "")))
	return err if err != "" else null


## Enter a race at this airfield: {id}.
func _cmd_analyst(role: String, a: Dictionary):
	if analyst == null or not Analyst.ENABLED:
		return "There is no analyst's desk in this game."
	var id := str(a.get("id", ""))
	var err := ""
	match str(a.get("do", "")):
		"verify":
			err = analyst.verify(id)
		"forward":
			err = analyst.forward(id)
		"discard":
			err = analyst.discard(id)
		_:
			err = "Verify, forward or discard."
	return err if err != "" else null


func _cmd_casino(role: String, a: Dictionary):
	if casino == null:
		return "There is no casino in this game."
	var err := ""
	match str(a.get("do", "")):
		"stake":
			err = casino.buy_stake()
		"collect":
			err = casino.collect()
		"launder":
			err = casino.launder(str(a.get("stash", "")), int(a.get("amount", 0)))
		"general":
			err = casino.pay_general()
		"rival":
			err = casino.buy_out_rival()
		"evacuate":
			err = casino.evacuate()
		_:
			err = "Stake, collect, launder, general, rival or evacuate."
	return err if err != "" else null


func _cmd_acid_barter(role: String, a: Dictionary):
	if psych == null:
		return "There is no Collective in this game."
	var err := psych.barter(str(a.get("stash", "")), float(_num(a, "lb", 0)))
	return err if err != "" else null


func _cmd_acid_sell(role: String, a: Dictionary):
	if psych == null:
		return "There is no Collective in this game."
	var err := psych.sell(float(_num(a, "sheets", 1e9)), str(a.get("stash", "")))
	return err if err != "" else null


func _cmd_acid_auto(role: String, a: Dictionary):
	if psych == null:
		return "There is no Collective in this game."
	var err := psych.set_auto(bool(a.get("on", false)))
	return err if err != "" else null


func _cmd_buy_vehicle(role: String, a: Dictionary):
	if dealer == null:
		return "There is no dealership in this game."
	var err := dealer.buy(str(a.get("id", "")))
	return err if err != "" else null


func _cmd_sell_vehicle(role: String, a: Dictionary):
	if dealer == null:
		return "There is no dealership in this game."
	var err := dealer.sell(int(a.get("serial", 0)))
	return err if err != "" else null


func _cmd_use_vehicle(role: String, a: Dictionary):
	if dealer == null:
		return "There is no dealership in this game."
	var err := dealer.use_car(int(a.get("serial", 0)))
	return err if err != "" else null


func _cmd_fleet_auto(role: String, a: Dictionary):
	if dealer == null:
		return "There is no dealership in this game."
	var err := dealer.set_auto(bool(a.get("on", false)))
	return err if err != "" else null


func _cmd_casino_play(role: String, a: Dictionary):
	if casino == null:
		return "There is no casino in this game."
	var err := casino.play(str(a.get("game", "")), a)
	return err if err != "" else null


func _cmd_casino_case(role: String, a: Dictionary):
	if casino == null:
		return "There is no casino in this game."
	var err := casino.case_action(str(a.get("do", "")))
	return err if err != "" else null


func _cmd_service(role: String, a: Dictionary):
	if airframe == null:
		return "No wear in this game: nothing to service."
	var part := str(a.get("part", "both"))
	var parts: Array = ["engine", "airframe"] if part == "both" else [part]
	var err := airframe.repair(parts, float(a.get("to", 100.0)))
	return err if err != "" else null


func _cmd_stop_work(role: String, a: Dictionary):
	if airframe == null:
		return "No wear in this game."
	airframe.stop("you called it off")
	return null


func _cmd_inspect(role: String, a: Dictionary):
	if airframe == null:
		return "No wear in this game."
	var v := airframe.view(true)
	say("INSPECTION: engine %.0f%% (power %d%%, quits %.1f%% a minute), airframe %.0f%% (the gear takes %d%% of its limit)." % [v.engine_pts, int(round(float(v.power) * 100.0)),
		float(v.fail_pct_min), v.airframe_pts, int(round(float(v.gear_factor) * 100.0))])
	return null


func _cmd_plant_beacon(role: String, a: Dictionary):
	if undercover == null:
		return "There is no agent in this game."
	var err := undercover.plant()
	return err if err != "" else null


func _cmd_race_enter(role: String, a: Dictionary):
	if races == null:
		return "There is no arena here."
	var err: String = races.enter(str(a.get("id", "")), int(a.get("bet", 0)), str(a.get("on", "win")))
	return err if err != "" else null


func _cmd_recruit_squad(role: String, a: Dictionary):
	if ground == null:
		return "No ground war here."
	var r = ground.recruit(_faction_of(role), str(a.get("kind", "foot")))
	if r is String:
		return r
	var text := "Raised %s: %s" % [r.id, Arsenal.describe(r.loadout)]
	if r.faction == "org":
		say(text)
	else:
		law_say(text)
	return null


func _cmd_disband_squad(role: String, a: Dictionary):
	if ground == null:
		return "No ground war here."
	var q = ground.get_squad(str(a.get("id", "")))
	if q == null or q.faction != _faction_of(role):
		return "Not one of ours."
	if q.fight != null:
		return "They're in a firefight."
	ground.disband(q)
	return null


func _cmd_investigate_agency(role: String, a: Dictionary):
	if agency == null:
		return "No Agency in this game."
	var err := agency.investigate()
	return err if err != "" else null


func _cmd_island_ship(role: String, a: Dictionary):
	if island == null:
		return "No island in this game."
	var err := island.ship(str(a.get("method", "")), int(_num(a, "amount", 0)))
	return err if err != "" else null


func _cmd_buy_passage(role: String, a: Dictionary):
	if island == null:
		return "No island in this game."
	var err := island.buy_passage()
	return err if err != "" else null


func _cmd_airport_crackdown(role: String, a: Dictionary):
	if island == null:
		return "No island in this game."
	if law_funds < 2000.0:
		return "Need $2,000 in funds."
	law_funds -= 2000.0
	island.crackdown_until = time + 1800.0
	law_say("Customs profile every passenger off the island flights for 30 min")
	return null


func _cmd_port_inspections(role: String, a: Dictionary):
	if island == null:
		return "No island in this game."
	if law_funds < 3000.0:
		return "Need $3,000 in funds."
	law_funds -= 3000.0
	island.inspections_until = time + 1800.0
	law_say("Every container from Isla Soberana opened for 30 min")
	return null


func _cmd_court_bail(role: String, a: Dictionary):
	return _court(func(): return court.post_bail(str(a.get("how", ""))))


func _cmd_court_hire(role: String, a: Dictionary):
	return _court(func(): return court.hire(str(a.get("tier", ""))))


func _cmd_court_motion(role: String, a: Dictionary):
	return _court(func(): return court.motion(str(a.get("kind", ""))))


func _cmd_court_tamper(role: String, a: Dictionary):
	return _court(func(): return court.tamper())


func _cmd_court_bribe(role: String, a: Dictionary):
	return _court(func(): return court.bribe_judge())


func _cmd_court_plea(role: String, a: Dictionary):
	return _court(func(): return court.plead())


func _cmd_court_cooperate(role: String, a: Dictionary):
	return _court(func(): return court.cooperate())


func _cmd_court_appeal(role: String, a: Dictionary):
	return _court(func(): return court.appeal())


## In custody or inside: let the time pass (the world moves on, fast).
func _cmd_court_wait(role: String, a: Dictionary):
	if court == null or not court.holding() or court.stage() == "bail":
		return "Nothing to wait for."
	var st := court.stage()
	var t := 0.0
	while court.open() and court.stage() == st and t < 3600.0:
		update(2.0)
		t += 2.0
	return null


func _cmd_court_no_bail(role: String, a: Dictionary):
	return _court(func(): return court.no_bail())


func _cmd_court_immunity(role: String, a: Dictionary):
	return _court(func(): return court.immunity())


func _cmd_court_forfeiture(role: String, a: Dictionary):
	return _court(func(): return court.forfeiture())


func _cmd_court_charge(role: String, a: Dictionary):
	return _court(func(): return court.add_conspiracy())


func _cmd_court_offer_plea(role: String, a: Dictionary):
	return _court(func(): return court.offer_plea(bool(a.get("lenient", false))))


func _cmd_sell_product(role: String, a: Dictionary):
	if trade == null:
		return "No trade in this game."
	var g := str(a.get("good", ""))
	if not g in ["cocaine", "marijuana", "guns"]:
		return "Sell what?"
	var err := trade.sell(str(a.get("buyer", "")), g, float(_num(a, "qty", 0)), str(a.get("tier", "rifle")), str(a.get("from", "")))
	return err if err != "" else null


## Logistics: a truck of product between stashes, or to a buyer's meet.
func _cmd_move_goods(role: String, a: Dictionary):
	if logistics == null:
		return "No logistics in this game: the product is just there."
	var g := str(a.get("good", ""))
	if not g in logistics.goods():
		return "Move what?"
	var err: String = logistics.send(str(a.get("from", "")), str(a.get("to", "")), g, float(_num(a, "lb", 0)))
	return err if err != "" else null


## Logistics: a truck of cash (to the HQ, usually).
func _cmd_move_cash(role: String, a: Dictionary):
	if logistics == null:
		return "No logistics in this game: money is money."
	var err: String = logistics.send(str(a.get("from", "")), str(a.get("to", Logistics.HQ)), "cash", float(_num(a, "amount", 1e12)))
	return err if err != "" else null


## Logistics: ONE truck through several stashes, taking the cash at each, to the club (or another stash).
## {stops: [ids], to, plan: true to let the planner order them}.
func _cmd_cash_round(role: String, a: Dictionary):
	if logistics == null:
		return "No logistics in this game: money is money."
	var stops: Array = []
	for x in a.get("stops", []):
		stops.append(str(x))
	var to := str(a.get("to", Logistics.HQ))
	if bool(a.get("plan", false)) and stops.size() >= 2:
		stops = logistics.plan_order(stops, logistics.pos(to) if to != "" else logistics.hq_pos())
	var err: String = logistics.cash_round(stops, to)
	return err if err != "" else null


## Logistics: ONE truck loaded at `from` that drops `lb` of `good` at each stop in turn.
func _cmd_goods_round(role: String, a: Dictionary):
	if logistics == null:
		return "No logistics in this game: money is money."
	var stops: Array = []
	for x in a.get("stops", []):
		stops.append(str(x))
	var err: String = logistics.goods_round(str(a.get("from", "")), stops, str(a.get("good", "")), float(_num(a, "lb", 1e9)))
	return err if err != "" else null


## An escort for one of our trucks: the nearest free squad of ours rides with it
## (a checkpoint gets a fight instead of a search; an ambush meets guns).
func _cmd_escort_truck(role: String, a: Dictionary):
	if ground == null or stash_net == null:
		return "No street war in this game: nobody to escort it."
	var id := int(_num(a, "job_id", -1))
	var t = Py.first(stash_net.trucks, func(x): return x.job_id == id)
	if t == null:
		return "No such truck on the road."
	if ground.squads.any(func(q): return q.faction == "org" and int(q.order.get("job_id", -1)) == id and q.state != "gone"):
		return "It already has an escort."
	var p: Array = t.pos(time)
	var free: Array = ground._free("org")
	if free.is_empty():
		return "No squad free to ride with it (the lieutenant raises them)."
	var q = Py.min_by(free, func(s): return s.pos().distance_to(Vector2(p[0], p[1])))
	var err: String = ground.order(q, {"type": "escort", "job_id": id})
	if err != "":
		return err
	say("%s rides with the truck%s." % [q.id, (" to " + logistics.truck_info(t).to) if logistics != null else ""])
	return null


## The tutorial from a desk (local or remote): {do: skip | on | off}.
func _cmd_tutorial(role: String, a: Dictionary):
	var what := str(a.get("do", "skip"))
	if tutorial == null:
		if what == "off":
			return null
		Tutorial.new().attach(self)
		return null
	match what:
		"skip":
			if role == Roles.PILOT:
				tutorial.skip()
			else:
				tutorial.desk_skip(role)
		"on":
			tutorial.enabled = true
		"off":
			tutorial.enabled = false
	return null


## Logistics: the whole armoury by truck to a stash or the club.
func _cmd_move_armoury(role: String, a: Dictionary):
	if logistics == null:
		return "No logistics in this game: the guns are just there."
	var err: String = logistics.send_guns(str(a.get("to", "")), {})
	return err if err != "" else null


func _cmd_load_cash(role: String, a: Dictionary):
	if logistics == null:
		return "No logistics in this game."
	var err: String = logistics.load_cash(float(_num(a, "amount", 1e12)))
	return err if err != "" else null


func _cmd_unload_cash(role: String, a: Dictionary):
	if logistics == null:
		return "No logistics in this game."
	var err: String = logistics.unload_cash()
	return err if err != "" else null


func _cmd_street_sweep(role: String, a: Dictionary):
	if trade == null:
		return "No street trade in this game."
	var err := trade.sweep(str(a.get("market", "")))
	return err if err != "" else null


func _cmd_trace_money(role: String, a: Dictionary):
	if trade == null:
		return "No money to follow in this game."
	var err := trade.trace()
	return err if err != "" else null


func _cmd_hire_worker(role: String, a: Dictionary):
	return _pay(func(): return payroll.hire("org", str(a.get("id", ""))))


func _cmd_fire_worker(role: String, a: Dictionary):
	return _pay(func(): return payroll.fire("org", str(a.get("id", ""))))


func _cmd_pay_bonus(role: String, a: Dictionary):
	return _pay(func(): return payroll.bonus("org"))


func _cmd_pay_worker_lawyer(role: String, a: Dictionary):
	return _pay(func(): return payroll.pay_lawyer("org", str(a.get("id", ""))))


func _cmd_post_lookout(role: String, a: Dictionary):
	return _pay(func(): return payroll.post_lookout(str(a.get("id", "")), str(a.get("stash", ""))))


func _cmd_offer_worker_deal(role: String, a: Dictionary):
	return _pay(func(): return payroll.offer_deal(str(a.get("id", ""))))


func _cmd_family_accept(role: String, a: Dictionary):
	if family == null or family.gone:
		return "No Family in this game."
	var err := family.accept(str(a.get("id", "")))
	return err if err != "" else null


func _cmd_family_decline(role: String, a: Dictionary):
	if family == null or family.gone:
		return "No Family in this game."
	var err := family.decline(str(a.get("id", "")))
	return err if err != "" else null


func _cmd_family_probe(role: String, a: Dictionary):
	if family == null or family.gone:
		return "No Family in this game."
	var err := family.probe(str(a.get("id", "")))
	return err if err != "" else null


func _cmd_family_stall(role: String, a: Dictionary):
	if family == null or family.gone:
		return "No Family in this game."
	var err := family.stall()
	return err if err != "" else null


func _cmd_pay_tribute(role: String, a: Dictionary):
	if family == null or family.gone:
		return "No Family in this game."
	var err := family.pay_tribute()
	return err if err != "" else null


func _cmd_rico_case(role: String, a: Dictionary):
	if family == null:
		return "No Family in this game."
	var err := family.rico_case()
	return err if err != "" else null


func _cmd_raid_stash(role: String, a: Dictionary):
	if stash_net == null:
		return "No stash houses on this map."
	return _raid(str(a.get("id", "")))
