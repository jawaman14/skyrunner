extends RefCounted
## Stateless crew commands; the passed Session owns all state.

static func _cmd_hire_spotter(role: String, a: Dictionary, session: Session):
	var code = a.get("code")
	return session.hire_spotter(code if code else session.location)


static func _cmd_spotter_move(role: String, a: Dictionary, session: Session):
	var code = a.get("code")
	if not World.AIRFIELD_BY_CODE.has(code) or session.spotters.is_empty():
		return "No spotter / unknown field."
	var sp: Session.Spotter = session.spotters[mini(int(session._num(a, "index", 0)), session.spotters.size() - 1)]
	sp.moving_to = code
	sp.move_t = Session.SPOTTER_MOVE_S
	session.say("Spotter heading to %s (60 s)" % World.airfield(code).name)
	return null


static func _cmd_service(role: String, a: Dictionary, session: Session):
	if session.airframe == null:
		return "No wear in this game: nothing to service."
	var part := str(a.get("part", "both"))
	var parts: Array = ["engine", "airframe"] if part == "both" else [part]
	var err := session.airframe.repair(parts, float(a.get("to", 100.0)))
	return err if err != "" else null


static func _cmd_stop_work(role: String, a: Dictionary, session: Session):
	if session.airframe == null:
		return "No wear in this game."
	session.airframe.stop("you called it off")
	return null


static func _cmd_inspect(role: String, a: Dictionary, session: Session):
	if session.airframe == null:
		return "No wear in this game."
	var v := session.airframe.view(true)
	session.say("INSPECTION: engine %.0f%% (power %d%%, quits %.1f%% a minute), airframe %.0f%% (the gear takes %d%% of its limit)." % [v.engine_pts, int(round(float(v.power) * 100.0)),
		float(v.fail_pct_min), v.airframe_pts, int(round(float(v.gear_factor) * 100.0))])
	return null


static func _cmd_hire_worker(role: String, a: Dictionary, session: Session):
	return session._pay(func(): return session.payroll.hire("org", str(a.get("id", ""))))


static func _cmd_fire_worker(role: String, a: Dictionary, session: Session):
	return session._pay(func(): return session.payroll.fire("org", str(a.get("id", ""))))


static func _cmd_pay_bonus(role: String, a: Dictionary, session: Session):
	return session._pay(func(): return session.payroll.bonus("org"))


static func _cmd_pay_worker_lawyer(role: String, a: Dictionary, session: Session):
	return session._pay(func(): return session.payroll.pay_lawyer("org", str(a.get("id", ""))))


static func _cmd_post_lookout(role: String, a: Dictionary, session: Session):
	return session._pay(func(): return session.payroll.post_lookout(str(a.get("id", "")), str(a.get("stash", ""))))


static func _cmd_offer_worker_deal(role: String, a: Dictionary, session: Session):
	return session._pay(func(): return session.payroll.offer_deal(str(a.get("id", ""))))
