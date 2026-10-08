extends RefCounted
## Stateless court commands; the passed Session owns all state.

static func _cmd_court_bail(role: String, a: Dictionary, session: Session):
	return session._court(func(): return session.court.post_bail(str(a.get("how", ""))))


static func _cmd_court_hire(role: String, a: Dictionary, session: Session):
	return session._court(func(): return session.court.hire(str(a.get("tier", ""))))


static func _cmd_court_motion(role: String, a: Dictionary, session: Session):
	return session._court(func(): return session.court.motion(str(a.get("kind", ""))))


static func _cmd_court_tamper(role: String, a: Dictionary, session: Session):
	return session._court(func(): return session.court.tamper())


static func _cmd_court_bribe(role: String, a: Dictionary, session: Session):
	return session._court(func(): return session.court.bribe_judge())


static func _cmd_court_plea(role: String, a: Dictionary, session: Session):
	return session._court(func(): return session.court.plead())


static func _cmd_court_cooperate(role: String, a: Dictionary, session: Session):
	return session._court(func(): return session.court.cooperate())


static func _cmd_court_appeal(role: String, a: Dictionary, session: Session):
	return session._court(func(): return session.court.appeal())


## In custody or inside: let the time pass (the world moves on, fast).
static func _cmd_court_wait(role: String, a: Dictionary, session: Session):
	if session.court == null or not session.court.holding() or session.court.stage() == "bail":
		return "Nothing to wait for."
	var st := session.court.stage()
	var t := 0.0
	while session.court.open() and session.court.stage() == st and t < 3600.0:
		session.update(2.0)
		t += 2.0
	return null


static func _cmd_court_no_bail(role: String, a: Dictionary, session: Session):
	return session._court(func(): return session.court.no_bail())


static func _cmd_court_immunity(role: String, a: Dictionary, session: Session):
	return session._court(func(): return session.court.immunity())


static func _cmd_court_forfeiture(role: String, a: Dictionary, session: Session):
	return session._court(func(): return session.court.forfeiture())


static func _cmd_court_charge(role: String, a: Dictionary, session: Session):
	return session._court(func(): return session.court.add_conspiracy())


static func _cmd_court_offer_plea(role: String, a: Dictionary, session: Session):
	return session._court(func(): return session.court.offer_plea(bool(a.get("lenient", false))))
