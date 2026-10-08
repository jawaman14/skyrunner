class_name SessionCommands
extends SessionTick
var _command_handlers: Dictionary = {}

## Layer 5 of 6 of the Session: the command surface. Every action goes through command(role, name, args), which
## dispatches through CommandDomains to stateless domain handlers.

## The single entry point for every non-flight action: [ok, message].
func command(role: String, name: String, args := {}) -> Array:
	if not Roles.valid(role):
		return [false, "Unknown role %s." % role]
	if not Roles.allowed(role, name):
		return [false, "%s can't do '%s'." % [role, name]]
	if _command_handlers.is_empty():
		_command_handlers = CommandDomains.handlers()
	var handler: Callable = _command_handlers.get(name, Callable())
	if not handler.is_valid():
		return [false, "Unknown command %s." % name]
	if name in ActionDescriptions.SUPPORTED:
		var action := describe_action(role, name, args)
		if not action.enabled:
			return [false, action.disabled_reason]
	var cash_before := money
	var prisoners_before: int = int(rackets.held) if rackets != null and name == "rackets" else 0
	var err = handler.call(role, args, self)
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


func set_pilot_input(role: String, roll: float, pitch: float, throttle: float) -> void:
	pilot_input[role] = [roll, pitch, throttle]
