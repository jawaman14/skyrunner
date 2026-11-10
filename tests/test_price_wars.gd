extends TestCase
## Price wars and supply cuts (loop idea 6, DESIGN 78): somebody moves a market against us and says so; an undercut takes price and
## custom, a flood takes price, a cut raises it; matching keeps the custom at a thinner price and ends the war sooner, holding keeps
## the stock and brings the customers back; one answer a war; saved; its own stream; off, no war starts.


func after_each() -> void:
	World.use_map(0)
	PriceWars.ENABLED = true


func _sess(opts := {}) -> Session:
	var o := {"seed": 21, "map_seed": MapCity.SEED, "location": "FRM", "features": Session.SANDBOX_FEATURES, "trade": true, "payroll": true,
		"ground_war": true}
	o.merge(opts, true)
	var s := Session.new(o)
	s.police.frozen = true
	s.payroll.ai["org"] = false
	s.payroll.ai["rival"] = false
	if s.ground != null:
		s.ground._started = true
		for f in s.ground.commanders:
			s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	s.trade.connected = true
	s.trade.stock.cocaine = 2000.0
	return s


func _hire_dealers(s: Session, n: int) -> String:
	for i in n:
		var w: Dictionary = s.payroll._person("org", "dealer")
		w.skill = 0.7
		w.loyalty = 0.9
		s.payroll.candidates["org"].append(w)
		s.payroll.hire("org", w.id)
	s.trade.update(60.0)
	s.trade._t = 0.0
	var m := str(s.payroll.of("org", "dealer", "assigned")[0].assigned).trim_prefix("corner-")
	for w in s.payroll.of("org", "dealer", "assigned"):
		w.assigned = "corner-" + m  # all on one corner, so a war there is the whole street
	return m


func _minutes(s: Session, n: int) -> void:
	for i in n:
		s.time += 60.0
		s.trade._t = 0.0
		s.trade.update(60.0)
		s.econ.market.update(60.0, s.time, null)


func _force(s: Session, kind: String, market: String, minutes := 40.0, good := "cocaine") -> Dictionary:
	var w: PriceWars = s.trade.wars
	w.war = {"id": 7, "kind": kind, "good": good, "market": market, "started": s.time, "until": s.time + minutes * 60.0, "answer": ""}
	w._run(s.time, 0.0)
	return w.war


func test_a_session_with_trade_has_price_wars_and_off_has_none() -> void:
	var s := _sess()
	check(s.trade.wars != null and not s.trade.wars.active(), "there, and quiet")
	check(s.trade.view("runner").wars.war.is_empty(), "the desk sees no war")
	s.dispose()
	PriceWars.ENABLED = false
	var o := _sess()
	check(o.trade.wars == null, "off: none")
	_hire_dealers(o, 2)
	_minutes(o, 300)
	check(o.trade.view("runner").wars.war.is_empty(), "and none ever starts")
	check(not o.command(Roles.BOSS, "price_war", {"answer": "match"})[0], "nothing to answer")
	o.dispose()


func test_a_war_starts_and_says_so() -> void:
	var s := _sess()
	_hire_dealers(s, 2)
	var heard := []
	s.bus.subscribe("price_war", func(e): heard.append(e))
	var over := []
	s.bus.subscribe("price_war_over", func(e): over.append(e))
	for i in 600:
		_minutes(s, 1)
		if not heard.is_empty():
			break
	check(not heard.is_empty(), "a war starts within ten hours")
	if heard.is_empty():
		s.dispose()
		return
	var w: Dictionary = s.trade.wars.war
	check(str(w.kind) in ["undercut", "flood", "cut"], "of a kind: %s" % w.kind)
	check(float(w.until) - float(w.started) >= 1200.0 and float(w.until) - float(w.started) <= 3000.0, "with a length")
	check(str(heard[0].text) != "" and str(heard[0].text) == PriceWars.headline(w), "and a headline: %s" % heard[0].text)
	check_eq(s.trade.view("runner").wars.war.id, w.id, "the desk sees it")
	_minutes(s, 60)
	check(not over.is_empty() and not s.trade.wars.active(), "it ends on time")
	check_eq(s.trade.wars.history.size(), 1, "and is remembered")
	var quiet := true
	for i in int(PriceWars.QUIET_S / 60.0) - 1:
		_minutes(s, 1)
		quiet = quiet and not s.trade.wars.active()
	check(quiet, "no new war straight after")
	s.dispose()


func test_the_same_seed_brings_the_same_war() -> void:
	var seen := []
	for k in 2:
		var s := _sess()
		_hire_dealers(s, 2)
		for i in 600:
			_minutes(s, 1)
			if s.trade.wars.active():
				break
		var w: Dictionary = s.trade.wars.war
		seen.append([w.get("kind", ""), w.get("good", ""), w.get("market", ""), snappedf(float(w.get("until", 0.0)), 0.01), s.time])
		s.dispose()
	check_eq(seen[0], seen[1], "the same war at the same minute")
	check(seen[0][0] != "", "and there was one")


## Ten minutes of street takings in the dealers' market under `kind` answered `how` ("" = unanswered, "none" = no war).
func _takings(kind: String, how: String) -> Array:
	var s := _sess()
	var m := _hire_dealers(s, 2)
	if kind != "none":
		_force(s, kind, m)
		if how != "":
			check(s.command(Roles.BOSS, "price_war", {"id": 7, "answer": how})[0], "answered: %s" % how)
	var before: float = s.trade.stock.cocaine
	var earned := s.trade.earned
	_minutes(s, 10)
	var out := [float(s.trade.earned - earned), before - float(s.trade.stock.cocaine), s.trade.wars.active(), s.econ.market.factor("cocaine", m)]
	s.dispose()
	return out


func test_an_undercut_takes_price_and_custom() -> void:
	var peace := _takings("none", "")
	var war := _takings("undercut", "")
	check(float(war[3]) < float(peace[3]) * 0.9, "the market's price falls: x%.2f from x%.2f" % [war[3], peace[3]])
	check_near(float(war[1]) / float(peace[1]), PriceWars.UNDERCUT_SHARE, 0.02, "our corners sell a third less")
	check(float(war[0]) < float(peace[0]) * 0.65, "and take much less: $%d from $%d" % [int(war[0]), int(peace[0])])


func test_matching_keeps_the_custom_and_ends_it_sooner() -> void:
	var bare := _takings("undercut", "")
	var matched := _takings("undercut", "match")
	check(float(matched[1]) > float(bare[1]) * 1.5, "matched: the corners keep selling (%d lb against %d)" % [int(matched[1]), int(bare[1])])
	check(float(matched[0]) > float(bare[0]), "and take more than an unanswered war leaves them")
	var s := _sess()
	var m := _hire_dealers(s, 2)
	_force(s, "undercut", m, 30.0)
	s.command(Roles.BOSS, "price_war", {"answer": "match"})
	_minutes(s, 9)
	check(s.trade.wars.active(), "nine minutes in: still on")
	_minutes(s, 2)
	check(not s.trade.wars.active(), "a thirty-minute war matched is over in about ten")
	check_eq(str(s.trade.wars.history[-1].answer), "match", "and remembered as matched")
	s.dispose()


func test_holding_keeps_the_stock_and_the_customers_come_back() -> void:
	var s := _sess()
	var m := _hire_dealers(s, 2)
	_force(s, "undercut", m, 12.0)
	check(s.command(Roles.BOSS, "price_war", {"answer": "hold"})[0], "hold")
	var before: float = s.trade.stock.cocaine
	_minutes(s, 10)
	check_eq(s.trade.stock.cocaine, before, "nothing sold while it lasts")
	_minutes(s, 3)
	check(not s.trade.wars.active(), "the war ends")
	check(s.econ.market._demand_events.any(func(e): return e.good == "cocaine" and e.market == m and float(e.mult) == PriceWars.HOLD_REBOUND),
		"and the customers who waited are back")
	_minutes(s, 5)
	check(s.trade.stock.cocaine < before, "the corners sell again")
	s.dispose()


func test_one_answer_a_war_and_a_cut_takes_none() -> void:
	var s := _sess()
	var m := _hire_dealers(s, 2)
	_force(s, "flood", m)
	check(not s.command(Roles.BOSS, "price_war", {"answer": "burn it"})[0], "match or hold only")
	check(not s.command(Roles.BOSS, "price_war", {"id": 3, "answer": "hold"})[0], "the war under way only")
	check(s.command(Roles.BOSS, "price_war", {"answer": "hold"})[0], "answered")
	check(not s.command(Roles.BOSS, "price_war", {"answer": "match"})[0], "once")
	check(not s.command(Roles.CONTROLLER, "price_war", {"answer": "match"})[0], "not the task force's to answer")
	_force(s, "cut", "*", 30.0, "marijuana")
	check(not s.command(Roles.BOSS, "price_war", {"answer": "hold"})[0], "a cut asks for nothing")
	s.dispose()


func test_a_cut_raises_the_price_everywhere() -> void:
	var s := _sess()
	var before := s.econ.market.wholesale("marijuana")
	_force(s, "cut", "*", 30.0, "marijuana")
	_minutes(s, 20)
	check(s.econ.market.wholesale("marijuana") > before * 1.3, "the source is short: wholesale x%.2f" % s.econ.market.wholesale("marijuana"))
	for m in Economy.MARKETS:
		check(s.econ.market.factor("marijuana", m) > 1.15, "the %s pays more (x%.2f)" % [m, s.econ.market.factor("marijuana", m)])
	check_eq(s.trade.wars.street("marijuana", "town"), {"share": 1.0, "price": 1.0, "hold": false}, "our corners sell as ever, at the better price")
	s.dispose()


func test_the_ai_answers_when_nobody_is_in_the_chair() -> void:
	var s := _sess()
	_hire_dealers(s, 2)
	s.payroll.ai["org"] = true
	for i in 900:
		_minutes(s, 1)
		if s.trade.wars.active() and str(s.trade.wars.war.kind) != "cut":
			break
	if s.trade.wars.active() and str(s.trade.wars.war.kind) != "cut":
		check_eq(str(s.trade.wars.war.answer), "match" if str(s.trade.wars.war.kind) == "undercut" else "hold", "answered at once")
	s.dispose()


func test_a_war_survives_a_save() -> void:
	var s := _sess()
	var m := _hire_dealers(s, 2)
	_force(s, "undercut", m, 40.0)
	s.command(Roles.BOSS, "price_war", {"answer": "match"})
	s.trade.wars.history.append({"id": 3, "kind": "cut", "good": "cocaine", "market": "*", "answer": "", "minutes": 31})
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	var war: Dictionary = s.trade.wars.war.duplicate()
	s.dispose()
	var r := _sess()
	StrategicSave.restore(r, d)
	check_eq(r.trade.wars.war.id, 7, "the war, its id an int again")
	check_eq([r.trade.wars.war.kind, r.trade.wars.war.market, r.trade.wars.war.answer], [war.kind, war.market, "match"], "its kind, market and answer")
	check_near(float(r.trade.wars.war.until), float(war.until), 1e-6, "and when it ends")
	check_eq(r.trade.wars.history.size(), 1, "and the last few")
	d.erase("price_wars")
	var o := _sess()
	StrategicSave.restore(o, d)
	check(not o.trade.wars.active(), "an older save: no war on")
	r.dispose()
	o.dispose()


func test_the_phone_says_what_can_be_done() -> void:
	var s := _sess()
	var m := _hire_dealers(s, 2)
	_force(s, "undercut", m, 40.0)
	var lines: Array = PhoneMenu.war_lines(s.trade.wars.view().war)
	check(str(lines[0]).contains("Los Cuervos") and str(lines[1]).contains("M: match"), "the war and the two answers: %s" % [lines])
	s.command(Roles.BOSS, "price_war", {"answer": "hold"})
	lines = PhoneMenu.war_lines(s.trade.wars.view().war)
	check(str(lines[1]).contains("hold the stock"), "then what we chose: %s" % lines[1])
	s.dispose()
