extends TestCase
## Weapons and vehicles wear with use (D-97, DESIGN 82): the armoury wears with every round our squads fight and every shot on
## foot, and their fire falls with it; owned trucks wear with the road, and slow with it; each is put right for a price; a line is
## said at 75, 50 and 25; saved; off, nothing wears.


func after_each() -> void:
	World.use_map(0)
	Wear.ENABLED = true


func _sess(opts := {}) -> Session:
	var o := {"seed": 21, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "money": 80000}
	o.merge(opts, true)
	var s := Session.new(o)
	s.police.frozen = true
	if s.ground != null:
		s.ground._started = true
		for f in s.ground.commanders:
			s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	s.money = 80000
	return s


func _said(s: Session, part: String) -> bool:
	return s.messages.any(func(m): return str(m[1]).contains(part))


func test_the_armoury_wears_with_fighting_and_fire_falls_with_it() -> void:
	var s := _sess({"ground_war": true})
	check(s.wear != null and s.wear.arms == 100.0, "as new")
	check_eq(s.wear.arms_mult(), 1.0, "full fire")
	for i in 100:
		s.wear.fought()
	check_near(s.wear.arms, 100.0 - 100 * Wear.ARMS_ROUND, 1e-6, "a hundred rounds of fighting")
	check_near(s.wear.arms_mult(), Wear.ARMS_FLOOR + (1.0 - Wear.ARMS_FLOOR) * s.wear.arms / 100.0, 1e-9, "and less fire for it")
	check(_said(s, "armoury is showing its use"), "said as it passes a band")
	for i in 1000:
		s.wear.fought()
	check_eq(s.wear.arms, 0.0, "never under nothing")
	check_eq(s.wear.arms_mult(), Wear.ARMS_FLOOR, "three quarters fire at the worst")
	s.dispose()


func test_our_squads_fire_less_with_a_worn_armoury_and_theirs_do_not() -> void:
	var s := _sess({"ground_war": true})
	var ours = null
	var theirs = null
	for q in s.ground.squads:
		if q.faction == "org" and ours == null:
			ours = q
		if q.faction == "rival" and theirs == null:
			theirs = q
	if ours == null:
		var r = s.ground.recruit("org", "foot", null, false)
		ours = r if not r is String else null
	check(ours != null, "a squad of ours")
	if ours != null:
		var clean: float = s.ground.fire(ours)
		s.wear.arms = 0.0
		check_near(s.ground.fire(ours), clean * Wear.ARMS_FLOOR, 1e-9, "ours: three quarters")
	if theirs != null:
		s.wear.arms = 100.0
		var rc: float = s.ground.fire(theirs)
		s.wear.arms = 0.0
		check_eq(s.ground.fire(theirs), rc, "Los Cuervos' guns are their own")
	s.dispose()


func test_shots_on_foot_wear_it_a_little() -> void:
	var s := _sess()
	s.wear.shot()
	check_near(s.wear.arms, 100.0 - Wear.ARMS_SHOT, 1e-9, "a shot")
	s.dispose()


func test_owned_trucks_wear_with_the_road_and_slow() -> void:
	var s := _sess({"dealership": true})
	check(s.dealer != null, "a dealership")
	s.wear.hauled(40.0)
	check_eq(s.wear.fleet, 100.0, "hired vans are the hirer's problem")
	var truck := ""
	for c in Dealership.CATALOGUE:
		if str(c.use) == "haul":
			truck = str(c.id)
			break
	check_eq(s.dealer.buy(truck), "", "a truck of our own")
	s.dealer.apply()
	var fast: float = s.stash_net.haul_ms
	s.wear.hauled(40.0)
	check_near(s.wear.fleet, 100.0 - 40.0 * Wear.TRUCK_KM, 1e-6, "forty kilometres")
	check_near(s.stash_net.haul_ms, fast * s.wear.fleet_mult(), 1e-6, "and they are slower for it")
	s.wear.hauled(4000.0)
	check_near(s.stash_net.haul_ms, fast * Wear.TRUCK_FLOOR, 1e-6, "three quarters speed at the worst")
	check(_said(s, "trucks are showing their miles"), "said")
	s.dispose()


func test_a_service_puts_it_right_for_a_price() -> void:
	var s := _sess({"dealership": true})
	check(not s.command(Roles.PILOT, "upkeep", {"what": "arms"})[0], "nothing to put right when new")
	s.wear.arms = 60.0
	var cost: int = s.wear.cost("arms")
	check(cost > 0, "a price: $%d" % cost)
	check(s.command(Roles.PILOT, "upkeep", {"what": "arms"})[0], "the armourer")
	check_eq(s.money, 80000 - cost, "paid")
	check_eq(s.wear.arms, 100.0, "as new")
	check(not s.command(Roles.PILOT, "upkeep", {"what": "fleet"})[0], "no trucks of ours to service")
	check(not s.command(Roles.PILOT, "upkeep", {"what": "boat"})[0], "arms or fleet")
	check(not s.command(Roles.CONTROLLER, "upkeep", {"what": "arms"})[0], "not the task force's")
	s.wear.arms = 10.0
	s.money = 5
	check(not s.command(Roles.PILOT, "upkeep", {"what": "arms"})[0], "not without the money")
	s.dispose()


func test_the_phone_line_says_condition_effect_and_price() -> void:
	var s := _sess()
	s.wear.arms = 40.0
	var v: Array = s.wear.view()
	check_eq(v.size(), 1, "the armoury (no trucks of ours)")
	var line := PhoneMenu.wear_line(v[0])
	check(line.contains("poor (40%)") and line.contains("our squads' fire at 85%") and line.contains("$"), "all three: %s" % line)
	s.wear.arms = 100.0
	check_eq(PhoneMenu.wear_line(s.wear.view()[0]), "Armoury: as new", "and nothing when new")
	s.dispose()


func test_it_is_saved_and_off_nothing_wears() -> void:
	var s := _sess()
	s.wear.arms = 62.0
	s.wear.fleet = 31.0
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	s.dispose()
	var r := _sess()
	StrategicSave.restore(r, d)
	check_eq([r.wear.arms, r.wear.fleet], [62.0, 31.0], "both conditions")
	d.erase("wear")
	var o := _sess()
	StrategicSave.restore(o, d)
	check_eq(o.wear.arms, 100.0, "an older save: as new")
	r.dispose()
	o.dispose()
	Wear.ENABLED = false
	var off := _sess()
	check(off.wear == null, "off: none")
	check(not off.command(Roles.PILOT, "upkeep", {"what": "arms"})[0], "nothing to service")
	check(not StrategicSave.capture(off).has("wear"), "nothing in the save")
	off.dispose()
