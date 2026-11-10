extends TestCase
## Investments with a return (loop idea 7, DESIGN 79): a fuel depot, a strip crew, a safehouse and an informant; each costs money
## once and an upkeep on the hour, and each has a payoff you can see; one we cannot pay lapses; saved; off, nothing can be bought.


func after_each() -> void:
	World.use_map(0)
	Investments.ENABLED = true


func _sess(opts := {}) -> Session:
	var o := {"seed": 23, "map_seed": MapCity.SEED, "location": "QRY", "features": Session.SANDBOX_FEATURES, "airframe": true, "money": 50000}
	o.merge(opts, true)
	var s := Session.new(o)
	s.police.frozen = true
	s.update(1.0 / 30)
	return s


func _said(s: Session, part: String) -> bool:
	return s.messages.any(func(m): return str(m[1]).contains(part))


func test_buying_costs_once_and_then_on_the_hour() -> void:
	var s := _sess()
	check(s.investments != null and s.investments.held.is_empty(), "there, and empty")
	var m := s.money
	check(s.command(Roles.PILOT, "invest", {"what": "safehouse"})[0], "a safehouse")
	check_eq(s.money, m - 4000, "its price, once")
	check(not s.command(Roles.PILOT, "invest", {"what": "safehouse"})[0], "one safehouse")
	check(not s.command(Roles.PILOT, "invest", {"what": "yacht"})[0], "only what is on the list")
	check(not s.command(Roles.CONTROLLER, "invest", {"what": "informant"})[0], "not the task force's to buy")
	s.investments.update(Investments.UPKEEP_S - 1.0)
	check_eq(s.money, m - 4000, "nothing before the hour")
	s.investments.update(1.0)
	check_eq(s.money, m - 4000 - 60, "then its upkeep")
	check_eq(s.investments.upkeep(), 60, "which the phone states")
	s.dispose()


func test_a_depot_sells_fuel_where_there_was_none() -> void:
	var s := _sess()
	check_eq(s.fuel_source(), [0.0, 0.0], "a back-country strip has no fuel but what you flew in")
	check(s.command(Roles.PILOT, "invest", {"what": "depot"})[0], "a depot where we are parked")
	var src: Array = s.fuel_source()
	check_near(float(src[0]), Session.FUEL_PRICE_PER_LB * Investments.DEPOT_PRICE * s.econ.fuel_mult(), 1e-9, "avgas at 1.2x the pump")
	check(float(src[1]) > 1e6, "any amount")
	check(not s.command(Roles.PILOT, "invest", {"what": "depot", "at": "HAR"})[0], "not at the airport")
	check(s.command(Roles.PILOT, "invest", {"what": "depot", "at": "FRM"})[0], "another at a bush strip, by name")
	s.dispose()
	var b := _sess({"location": "FRM"})
	var farmer: float = b.fuel_source()[0]
	b.command(Roles.PILOT, "invest", {"what": "depot"})
	check(float(b.fuel_source()[0]) < farmer * 0.65, "and cheaper than the farmer's drums at a bush strip")
	b.dispose()


func test_a_strip_crew_stops_the_rough_strip_wearing_the_airframe() -> void:
	var s := _sess()
	var a: Airframe = s.airframe
	a.touchdown(100.0, 600.0, World.airfield("QRY"))
	var worn := a.airframe()
	check(worn < 100.0, "a dirt strip costs a little each landing")
	check(s.command(Roles.PILOT, "invest", {"what": "strip"})[0], "a crew to grade it")
	a.touchdown(100.0, 600.0, World.airfield("QRY"))
	check_eq(a.airframe(), worn, "and it costs nothing now")
	a.touchdown(100.0, 600.0, World.airfield("EGL"))
	check(a.airframe() < worn, "the other strips are as rough as ever")
	s.dispose()


func test_a_safehouse_cools_the_case_faster() -> void:
	var s := _sess()
	check_eq(s.police.cool_mult, 1.0, "as it was")
	s.command(Roles.PILOT, "invest", {"what": "safehouse"})
	check_eq(s.police.cool_mult, Investments.SAFEHOUSE_COOL, "30% faster while we keep it")
	check(s.command(Roles.PILOT, "invest", {"what": "safehouse", "close": true})[0], "closed")
	check_eq(s.police.cool_mult, 1.0, "and back")
	s.dispose()


func test_an_informant_tells_of_a_warrant_and_times_every_raid() -> void:
	var s := _sess()
	check(s.investigation != null and s.stash_net != null, "a game with case files")
	var st: Dictionary = s.stash_net.live()[0]
	st.heat = 60.0
	var t0 := s.time
	s.investigation.update(t0, s.stash_net)
	s.investigation.update(t0 + Investigation.SURVEIL_AFTER_S, s.stash_net)
	s.investigation.update(t0 + Investigation.SURVEIL_AFTER_S + Investigation.WARRANT_AFTER_S, s.stash_net)
	check_eq(s.investigation.stage_of(str(st.id)), "warrant", "a warrant on a house")
	s.investments.update(1.0)
	check(not _said(s, "The clerk at the task force"), "nobody tells us")
	check(not s.investments.warned(), "and no countdown")
	check(s.command(Roles.PILOT, "invest", {"what": "informant"})[0], "an informant")
	s.investments.update(1.0)
	check(_said(s, "a warrant is signed for %s" % st.name), "now he does")
	check(s.investments.warned(), "and the Heat page times every raid")
	s.messages.clear()
	s.investments.update(1.0)
	check(not _said(s, "The clerk"), "once a warrant")
	s.dispose()


func test_what_we_cannot_pay_lapses() -> void:
	var s := _sess()
	s.command(Roles.PILOT, "invest", {"what": "depot"})
	s.command(Roles.PILOT, "invest", {"what": "informant"})
	var lapsed := []
	s.bus.subscribe("investment_lapsed", func(e): lapsed.append(str(e.data.kind)))
	s.money = 50
	s.investments.update(Investments.UPKEEP_S)
	check_eq(s.money, 10, "the depot's hour is paid")
	check_eq(lapsed, ["informant"], "the informant's is not: he stops calling")
	check(s.investments.has("depot", "QRY") and not s.investments.has("informant"), "one kept, one gone")
	check_eq(s.fuel_source()[1] > 1e6, true, "the depot still pumps")
	s.dispose()


func test_the_view_says_what_is_held_and_what_can_be_bought_here() -> void:
	var s := _sess()
	s.command(Roles.PILOT, "invest", {"what": "strip"})
	var v: Dictionary = s.investments.view()
	check_eq(v.held.size(), 1, "one held")
	check(PhoneMenu.invest_line(v.held[0]).contains("Strip crew at") and PhoneMenu.invest_line(v.held[0]).contains("$50 an hour"), "with its upkeep: %s" % PhoneMenu.invest_line(v.held[0]))
	var kinds: Array = v.offers.map(func(o): return o.kind)
	check_eq(kinds, ["depot", "safehouse", "informant"], "the rest on offer")
	check(PhoneMenu.offer_line(v.offers[0]).contains("$3,500"), "at a price: %s" % PhoneMenu.offer_line(v.offers[0]))
	s.money = 100
	check(str(s.investments.view().offers[0].why).contains("Need $"), "or why not")
	s.dispose()


func test_investments_survive_a_save() -> void:
	var s := _sess()
	s.command(Roles.PILOT, "invest", {"what": "depot"})
	s.command(Roles.PILOT, "invest", {"what": "safehouse"})
	s.investments.update(600.0)
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	s.dispose()
	var r := _sess()
	StrategicSave.restore(r, d)
	check(r.investments.has("depot", "QRY") and r.investments.has("safehouse"), "both held")
	check_eq(r.police.cool_mult, Investments.SAFEHOUSE_COOL, "and working")
	var m := r.money
	r.investments.update(Investments.UPKEEP_S - 600.0)
	check_eq(r.money, m - 100, "the hour carries on where it was")
	d.erase("investments")
	var o := _sess()
	StrategicSave.restore(o, d)
	check(o.investments.held.is_empty(), "an older save: none held")
	r.dispose()
	o.dispose()


func test_off_is_the_game_as_it_was() -> void:
	Investments.ENABLED = false
	var s := _sess()
	check(s.investments == null, "none")
	check(not s.command(Roles.PILOT, "invest", {"what": "depot"})[0], "nothing to buy")
	check_eq(s.fuel_source(), [0.0, 0.0], "no depot")
	check(not StrategicSave.capture(s).has("investments"), "nothing in the save")
	s.dispose()
