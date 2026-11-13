extends TestCase
## Storage caps and costs per place (DESIGN 87): a house holds so much by its kind; a van or a pickup order to a house with no room
## is refused, counting what is on its way; what arrives over the cap is kept but draws heat by the hour; every live house costs its
## upkeep at the close, owed when the safe can't pay; off, no caps and no upkeep.


func after_each() -> void:
	World.use_map(0)
	Storage.ENABLED = true


func _sess() -> Session:
	var s := Session.new({"seed": 21, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES,
		"trade": true, "logistics": true, "payroll": true, "family": true})
	s.police.frozen = true
	s.payroll.ai["org"] = false
	s.update(1.0 / 30)
	s.money = 80000
	s.family.respect = 60.0
	for site in s.logistics.stock:
		for g in s.logistics.stock[site]:
			s.logistics.stock[site][g] = 0.0
	return s


func test_each_kind_holds_its_own() -> void:
	var s := _sess()
	var st: Storage = s.logistics.storage
	check_eq(Storage.cap_of(s.stash_net.get_stash("docks")), 4000.0, "the warehouse holds most")
	check_eq(Storage.cap_of(s.stash_net.get_stash("shack")), 400.0, "the shack little")
	s.logistics.add("shack", "marijuana", 150.0, "farm")
	s.logistics.add("shack", "cocaine", 50.0, "island")
	check_near(st.room("shack"), 200.0, 1e-6, "every good counts against it")
	check_eq(st.line("shack"), "200 of 400 lb", "said so")
	s.dispose()


func test_a_van_to_a_full_house_is_refused() -> void:
	var s := _sess()
	var lg: Logistics = s.logistics
	lg.add("docks", "marijuana", 1000.0, "farm")
	lg.add("shack", "marijuana", 300.0, "farm")
	var why := lg.send("docks", "shack", "marijuana", 200.0)
	check(why.contains("room for 100 lb"), "no room for 200: %s" % why)
	check_eq(lg.send("docks", "shack", "marijuana", 100.0), "", "100 fits")
	why = lg.send("docks", "shack", "marijuana", 50.0)
	check(why != "", "and what is on its way counts: %s" % why)
	s.dispose()


func test_a_pickup_to_a_full_house_is_refused() -> void:
	var s := _sess()
	s.logistics.add("shack", "marijuana", 390.0, "farm")
	var r: Array = s.command(Roles.PILOT, "stock_order", {"contact": "family", "good": "marijuana", "lb": 50, "stash": "shack"})
	check(not r[0] and str(r[1]).contains("room for"), "no room: %s" % str(r[1]))
	check_eq(s.money, 80000, "nothing paid")
	s.dispose()


func test_over_the_cap_it_is_kept_and_heats_the_house() -> void:
	var s := _sess()
	var lg: Logistics = s.logistics
	var shack = s.stash_net.get_stash("shack")
	shack.heat = 0.0
	lg.add("shack", "marijuana", 800.0, "farm")  # a load landed over the cap: kept
	check_near(float(lg.stock.shack.marijuana), 800.0, 1e-6, "nothing lost")
	lg.storage.update(3600.0)
	check_near(float(shack.heat), Storage.YARD_HEAT, 0.001, "a full cap over: the full yard heat for the hour")
	lg.stock.shack.marijuana = 600.0
	shack.heat = 0.0
	lg.storage.update(3600.0)
	check_near(float(shack.heat), Storage.YARD_HEAT * 0.5, 0.001, "half a cap over: half")
	lg.stock.shack.marijuana = 100.0
	shack.heat = 0.0
	lg.storage.update(3600.0)
	check_eq(float(shack.heat), 0.0, "under it: nothing")
	s.dispose()


func test_upkeep_at_the_close_and_owed_when_short() -> void:
	var s := _sess()
	var lg: Logistics = s.logistics
	var due := 0
	for st in s.stash_net.live():
		due += Storage.upkeep_of(st)
	check(due > 0, "the houses cost $%d a day" % due)
	lg.storage.close()
	check_eq(s.money, 80000 - due, "paid from the safe")
	s.money = 100
	lg.storage.close()
	check_eq([s.money, lg.storage.owed], [0, due - 100], "short: what's left is owed")
	s.money = 80000
	lg.storage.close()
	check_eq([s.money, lg.storage.owed], [80000 - 2 * due + 100, 0], "paid first next time")
	lg.storage.owed = 55
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	s.dispose()
	var r := _sess()
	StrategicSave.restore(r, d)
	check_eq(r.logistics.storage.owed, 55, "saved")
	r.dispose()


func test_off_no_caps_no_upkeep() -> void:
	Storage.ENABLED = false
	var s := _sess()
	var lg: Logistics = s.logistics
	lg.add("docks", "marijuana", 1000.0, "farm")
	check_eq(lg.send("docks", "shack", "marijuana", 900.0), "", "any amount")
	var before := s.money
	lg.storage.close()
	check_eq(s.money, before, "no upkeep")
	s.dispose()
