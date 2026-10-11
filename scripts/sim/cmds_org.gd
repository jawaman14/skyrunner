extends RefCounted
## Stateless org commands; the passed Session owns all state.

static func _cmd_phone_answer(_role: String, args: Dictionary, session: Session):
	session.phone_calls.tick(session.time)
	var id := int(session._num(args, "id", -1))
	var pending := session.phone_calls.pending()
	var call = Py.first(pending, func(c): return int(c.id) == id)
	if call == null:
		return "This call is no longer ringing."
	var source := str(call.get("source", ""))
	if source.begins_with("family:") and (session.family == null or session.family.get_offer(source.trim_prefix("family:")) == null):
		return "The Family offer is no longer available."
	var result := session.phone_calls.answer(id)
	return null if result.ok else str(result.reason)


static func _cmd_phone_decline(_role: String, args: Dictionary, session: Session):
	session.phone_calls.tick(session.time)
	var result := session.phone_calls.decline(int(session._num(args, "id", -1)))
	return null if result.ok else "This call is no longer ringing."


static func _cmd_hq(role: String, a: Dictionary, session: Session):
	if session.nights == null:
		return "No HQ in this game (needs layer 5)."
	if role == Roles.PILOT and session.humans.has(Roles.BOSS):
		return "%s is the boss - ask them." % session.humans[Roles.BOSS]
	if role == Roles.CONTROLLER and session.humans.has(Roles.CHIEF):
		return "%s holds the budget - ask them." % session.humans[Roles.CHIEF]
	var args := a.duplicate()
	var order := str(args.get("order", ""))
	args.erase("order")
	return session.nights.order(Roles.side(role), order, args)


static func _cmd_chat(role: String, a: Dictionary, session: Session):
	var text := str(a.get("text", "")).substr(0, 200)
	if Roles.side(role) == "runner":
		session.say("[%s] %s" % [role, text])
		# crew radio is real radio: from the aircraft, anyone listening can hear it
		if RadioNet.REALISM and role in [Roles.PILOT, Roles.COPILOT] and session.state != null and not session.state.on_ground:
			session._df_on(session.radio.transmit(session.time, "runner", session.squawk, text, [session.state.x, session.state.y, session.state.alt],
				1.0 if session.upgrades["runner"].has("burst_radio") else -1.0))
	else:
		session.law_say("[%s] %s" % [role, text])
	return null


# law side

## Dispatch on the tactical channel: a scanner programmed only for dispatch goes
## quiet. Free, unlike encryption - but a runner can program the scanner too.
static func _cmd_radio_channel(role: String, a: Dictionary, session: Session):
	var ch := str(a.get("channel", ""))
	if not (ch in ["police", "police_tac"]):
		return "Bad arguments for radio_channel: police or police_tac"
	session.radio.police_channel = ch
	session.law_say("Dispatch now on the %s channel" % ("tactical" if ch == "police_tac" else "main"))
	return null


## Enter a race at this airfield: {id}.
static func _cmd_analyst(role: String, a: Dictionary, session: Session):
	if session.analyst == null or not Analyst.ENABLED:
		return "There is no analyst's desk in this game."
	var id := str(a.get("id", ""))
	var err := ""
	match str(a.get("do", "")):
		"verify":
			err = session.analyst.verify(id)
		"forward":
			err = session.analyst.forward(id)
		"discard":
			err = session.analyst.discard(id)
		_:
			err = "Verify, forward or discard."
	return err if err != "" else null


static func _cmd_plant_beacon(role: String, a: Dictionary, session: Session):
	if session.undercover == null:
		return "There is no agent in this game."
	var err := session.undercover.plant()
	return err if err != "" else null


static func _cmd_investigate_agency(role: String, a: Dictionary, session: Session):
	if session.agency == null:
		return "No Agency in this game."
	var err := session.agency.investigate()
	return err if err != "" else null


## The tutorial from a desk (local or remote): {do: skip | on | off}.
static func _cmd_tutorial(role: String, a: Dictionary, session: Session):
	var what := str(a.get("do", "skip"))
	if session.tutorial == null:
		if what == "off":
			return null
		Tutorial.new().attach(session)
		return null
	match what:
		"skip":
			if role == Roles.PILOT:
				session.tutorial.skip()
			else:
				session.tutorial.desk_skip(role)
		"on":
			session.tutorial.enabled = true
		"off":
			session.tutorial.enabled = false
	return null


static func _cmd_trace_money(role: String, a: Dictionary, session: Session):
	if session.trade == null:
		return "No money to follow in this game."
	var err := session.trade.trace()
	return err if err != "" else null


static func _cmd_family_accept(role: String, a: Dictionary, session: Session):
	if session.family == null or session.family.gone:
		return "No Family in this game."
	var err := session.family.accept(str(a.get("id", "")))
	return err if err != "" else null


static func _cmd_family_decline(role: String, a: Dictionary, session: Session):
	if session.family == null or session.family.gone:
		return "No Family in this game."
	var err := session.family.decline(str(a.get("id", "")))
	return err if err != "" else null


static func _cmd_family_probe(role: String, a: Dictionary, session: Session):
	if session.family == null or session.family.gone:
		return "No Family in this game."
	var err := session.family.probe(str(a.get("id", "")))
	return err if err != "" else null


static func _cmd_family_stall(role: String, a: Dictionary, session: Session):
	if session.family == null or session.family.gone:
		return "No Family in this game."
	var err := session.family.stall()
	return err if err != "" else null


static func _cmd_rico_case(role: String, a: Dictionary, session: Session):
	if session.family == null:
		return "No Family in this game."
	var err := session.family.rico_case()
	return err if err != "" else null
