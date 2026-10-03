extends TestCase
## The car dealership: cars for the pilot, trucks for the stash runs, what they cost to keep, what they do to the runs, the AI buying
## trucks, and what a save keeps.

const PATH := "user://test_dealership.json"
var _sess: Session


func after_each() -> void:
	Dealership.ENABLED = true
	if _sess != null:
		_sess.dispose()
		_sess = null
	World.use_map(0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _opts() -> Dictionary:
	return {"seed": 61, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "dealership": true, "trade": true, "logistics": true, "money": 200000}


func _session() -> Session:
	_sess = Session.new(_opts())
	_sess.police.frozen = true
	_sess.update(1.0 / 30)
	return _sess


func test_the_catalogue_is_sound() -> void:
	var ids := {}
	var drive := 0
	var haul := 0
	for c in Dealership.CATALOGUE:
		check(not ids.has(c.id), "unique id %s" % c.id)
		ids[c.id] = true
		check(int(c.price) > 0 and str(c.name) != "" and str(c.model) != "", "%s is priced and named" % c.id)
		if c.use == "drive":
			drive += 1
			check(float(c.road) > float(c.off) * 0.9 and float(c.accel) > 0.0, "%s has drive numbers" % c.id)
		else:
			haul += 1
			check(float(c.speed) > 0.0 and float(c.stealth) >= 0.0 and float(c.armour) >= 0.0, "%s has haul numbers" % c.id)
	check(drive >= 4 and haul >= 4, "cars to drive and trucks to haul: %d and %d" % [drive, haul])


func test_a_dealership_is_only_there_when_asked() -> void:
	var o := _opts()
	o.erase("dealership")
	_sess = Session.new(o)
	check(_sess.dealer == null, "none without the option")
	check_eq(_sess.command(Roles.PILOT, "buy_vehicle", {"id": "coupe"})[1], "There is no dealership in this game.", "and the command says so")


func test_buying_a_car_takes_the_money_and_makes_it_the_one_you_drive() -> void:
	var s := _session()
	var d: Dealership = s.dealer
	var rev := d.rev
	check_eq(s.command(Roles.PILOT, "buy_vehicle", {"id": "roadster"})[0], true, "bought")
	check_eq(s.money, 200000 - 21000, "$21,000 gone")
	check_eq(d.owned.size(), 1, "one owned")
	check_eq(d.active, int(d.owned[0].serial), "the first car is the one you drive")
	check(d.rev > rev, "the 3D side is told")
	check_eq(str(d.drive_spec().id), "roadster", "its numbers")
	d.buy("coupe")
	check_eq(str(d.drive_spec().id), "roadster", "a second car does not take over")
	check_eq(d.use_car(int(d.owned[1].serial)), "", "until you say so")
	check_eq(str(d.drive_spec().id), "coupe", "now the coupe")
	check_eq(d.use_car(0), "", "or back to the starter car")
	check(d.drive_spec().is_empty(), "the starter car has no spec")


func test_refusals() -> void:
	var s := _session()
	var d: Dealership = s.dealer
	check(d.buy("zeppelin").contains("no such"), "not on the lot")
	s.money = 1000
	check(d.buy("van").contains("costs"), "not enough money")
	s.money = 500000
	s.phase = "flying"
	check(d.buy("coupe").contains("full stop"), "a car is delivered to the aircraft: not in the air")
	check_eq(d.buy("van"), "", "a truck can be bought from anywhere")
	check(d.use_car(int(d.owned[0].serial)).contains("truck"), "you cannot drive a truck")
	s.phase = "parked"
	for i in Dealership.MAX_OWNED - 1:
		check_eq(d.buy("hatch"), "", "within the limit")
	check(d.buy("hatch").contains("limit"), "and not past it")


func test_selling_pays_resale_and_hands_the_wheel_on() -> void:
	var s := _session()
	var d: Dealership = s.dealer
	d.buy("coupe")
	d.buy("suv")
	var m := s.money
	var first := int(d.owned[0].serial)
	check_eq(d.sell(first), "", "sold the one you were driving")
	check_eq(s.money, m + int(6500.0 * Dealership.RESALE), "for 55%")
	check_eq(str(d.drive_spec().id), "suv", "the other car is the one you drive")
	check(d.sell(first).contains("do not own"), "not twice")
	check_eq(d.sell(int(d.owned[0].serial)), "", "the last one")
	check_eq(d.active, 0, "back to the starter car")


func test_trucks_change_what_the_stash_runs_do() -> void:
	var s := _session()
	var sn: StashNet = s.stash_net
	check_eq(sn.haul_ms, StashNet.TRUCK_MS, "the old speed with no fleet")
	check_eq(sn.risk_mult, 1.0, "the old odds")
	check_eq(sn.armour, 0.0, "and no steel")
	var af := World.airfield("HAR")
	var jid := Jobs.new_id()
	var job := Jobs.Job.new(jid, "a load", "contraband", "HAR", "FRM", [], 5000)
	job.stash = str(sn.stashes[0].id)
	job.weapons = {}
	job.gun_mode = "sell"
	var slow := sn.dispatch(job, af, s.time, 1000)
	sn.trucks.erase(slow)
	s.dealer.buy("fast")
	check_eq(sn.haul_ms, 15.0, "the Midnight Van's speed")
	check_near(sn.risk_mult, 0.75, 0.001, "its cover")
	var fast := sn.dispatch(job, af, s.time, 1000)
	check(fast.dur < slow.dur, "the same run is quicker: %.0f s against %.0f s" % [fast.dur, slow.dur])
	s.dealer.buy("armoured")
	check_eq(sn.haul_ms, 15.0, "the fleet's best speed")
	check_near(sn.armour, 0.6, 0.001, "and its best steel")
	s.dealer.buy("ambulance")
	check_near(sn.risk_mult, 0.55, 0.001, "the ambulance's cover is the best")
	for v in s.dealer.owned.duplicate():
		s.dealer.sell(int(v.serial))
	check(sn.haul_ms == StashNet.TRUCK_MS and sn.risk_mult == 1.0 and sn.armour == 0.0, "sold off: the old numbers")


func test_steel_drives_through_a_roadblock() -> void:
	var s := _session()
	var sn: StashNet = s.stash_net
	s.dealer.buy("armoured")
	sn.armour = 1.0  # certain
	var af := World.airfield("HAR")
	var jid := Jobs.new_id()
	var job := Jobs.Job.new(jid, "a load", "contraband", "HAR", "FRM", [], 5000)
	job.stash = str(sn.stashes[0].id)
	job.weapons = {}
	job.gun_mode = "sell"
	var t := sn.dispatch(job, af, s.time, 1000)
	t.stop_at = 0.3
	var seized := 0
	var delivered := 0
	var now := s.time + t.dur * 0.5
	for r in sn.update(0.1, now, []):
		if r[1] == "seized":
			seized += 1
	check_eq(seized, 0, "the roadblock did not take it")
	check_eq(t.stop_at, -1.0, "it is through")
	for r in sn.update(0.1, s.time + t.dur + 1.0, []):
		if r[1] == "delivered":
			delivered += 1
	check_eq(delivered, 1, "and it arrives")


func test_cover_and_steel_get_trucks_past_a_checkpoint_once_per_stop() -> void:
	var s := _session()
	var d: Dealership = s.dealer
	check(not d.gets_past(1, "q1"), "no fleet: pulled over")
	d.buy("ambulance")
	d.buy("armoured")
	var past := 0
	for i in 200:
		if d.gets_past(i, "q1"):
			past += 1
	check(past > 80 and past < 190, "about 90%% of 200 get past: %d" % past)
	var first := d.gets_past(5, "q2")
	for i in 5:
		check_eq(d.gets_past(5, "q2"), first, "the same truck at the same stop gets the same answer")


func test_vehicles_cost_insurance_by_the_hour() -> void:
	var s := _session()
	var d: Dealership = s.dealer
	d.buy("coupe")
	d.buy("van")
	check_eq(d.insurance_hour(), int(Dealership.INSURANCE_DRIVE + Dealership.INSURANCE_HAUL), "a car and a truck")
	var m := s.money
	for i in 3600:
		d.update(1.0)
	check_near(float(m - s.money), float(d.insurance_hour()), 2.0, "an hour of insurance")


func test_the_ai_buys_the_best_truck_it_can_afford_and_keeps_a_reserve() -> void:
	var s := _session()
	var d: Dealership = s.dealer
	d.set_auto(true)
	s.money = 60000
	d.update(Dealership.AUTO_EVERY_S + 1.0)
	var bought := d.haulers()
	check(not bought.is_empty(), "it bought a truck")
	check(s.money >= Dealership.AUTO_RESERVE, "and left the reserve: $%d" % s.money)
	s.money = 10000
	var n := d.owned.size()
	d.update(Dealership.AUTO_EVERY_S + 1.0)
	check_eq(d.owned.size(), n, "broke: it buys nothing")
	s.money = 400000
	for i in 6:
		d.update(Dealership.AUTO_EVERY_S + 1.0)
	check(float(d.fleet().speed) >= 14.0 and float(d.fleet().stealth) >= 0.25, "rich: the fleet gets quick and quiet")
	var count := d.owned.size()
	for i in 6:
		d.update(Dealership.AUTO_EVERY_S + 1.0)
	check_eq(d.owned.size(), count, "and it stops when nothing would improve it")
	check(d.owned.all(func(v): return Dealership.spec(str(v.id)).use == "haul"), "the AI buys trucks, not cars for the pilot")


func test_the_dealership_survives_a_save() -> void:
	var o := _opts()
	o["save_path"] = PATH
	var s := Session.new(o)
	s.police.frozen = true
	s.update(1.0 / 30)
	s.dealer.buy("roadster")
	s.dealer.buy("fast")
	s.dealer.set_auto(true)
	var serial := int(s.dealer.owned[0].serial)
	s.save()
	s.dispose()
	var t := Session.load_or_new(PATH, o)
	_sess = t
	check(t.dealer != null, "the dealership is back")
	check_eq(t.dealer.owned.size(), 2, "both vehicles")
	check_eq(t.dealer.active, serial, "the same car to drive")
	check(t.dealer.auto, "the AI still runs the fleet")
	check_eq(t.stash_net.haul_ms, 15.0, "and the trucks are at the fleet's speed again")


func test_the_story_opens_it_with_logistics() -> void:
	var found := false
	for ch in Story.CHAPTERS:
		if ch[3].has("dealership"):
			found = true
			check(ch[3].has("logistics"), "in the chapter that opens logistics")
	check(found, "a chapter opens the dealership")


func test_the_dealer_screen_buys_sells_and_drives() -> void:
	var s := _session()
	var m := DealerMenu.new()
	m.setup(s)
	m.browse()
	check(m.lot_rows.size() == Dealership.CATALOGUE.size(), "the whole lot is listed")
	m.key("enter")  # the first row: the hatch
	check_eq(s.dealer.owned.size(), 1, "bought from the lot")
	m.key("right")
	m.key("s")
	check_eq(s.dealer.owned.size(), 0, "sold from the list of yours")
	m.key("a")
	check(s.dealer.auto, "A hands the fleet to the AI")
	m.free()


func test_the_dealer_talks_to_any_seat() -> void:
	var s := _session()
	check(Talk.resource("dealer") != null, "Marty Quintero's script compiles")
	for role in [Roles.PILOT, Roles.BOSS, Roles.FIXER]:
		check(Roles.allowed(role, "buy_vehicle") and Roles.allowed(role, "sell_vehicle"), "%s can buy and sell vehicles" % role)
		check(Snapshot.build(s, role).has("dealer"), "%s's snapshot carries the lot" % role)
	check(not Snapshot.build(s, Roles.CONTROLLER).has("dealer"), "the law does not see the organisation's lot")
	var link := LocalLink.new(s, Roles.FIXER)
	var st := Talk.State.new(func(): return link.snapshot(), func(n: String, a: Dictionary) -> Array:
		link.send_command(n, a)
		return link.last_result)
	check(st.dealer and st.dl_price("van") == 14000 and st.dl_can("van"), "the state reads the lot")
	check(st.buy_vehicle("van") and st.dl_trucks == 1, "buys a van through the command")
	check(st.dl_fleet_line.contains("1 truck"), "and describes the fleet: %s" % st.dl_fleet_line)
	check(st.buy_vehicle("fast") and s.stash_net.haul_ms == 15.0, "a second truck")
	check(st.sell_truck() and st.dl_trucks == 1, "sells the newest")
	check(st.toggle_fleet_auto() and s.dealer.auto and st.dl_auto, "hands the fleet to the AI")
	s.money = 100
	st.refresh()
	check(not st.dl_can("armoured"), "and cannot afford the armoured truck")
