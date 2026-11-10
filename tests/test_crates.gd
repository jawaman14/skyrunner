extends TestCase
## Weapon crates and the scarcity ladder (D-61 stage 1, DESIGN 77): a gun run is crates of one type each, dealt off what the street
## holds; a type's price follows its scarcity at the dealer, the fence and the bulk buyers; the dealer sells only what there is;
## seizures and sales move the street, and it drifts back; saved; off, everything is as it was.


func after_each() -> void:
	World.use_map(0)
	Crates.ENABLED = true


func _city(opts := {}) -> Session:
	var o := {"seed": 4, "map_seed": MapCity.SEED, "location": "QRY", "features": Session.SANDBOX_FEATURES}
	o.merge(opts, true)
	var s := Session.new(o)
	s.update(1.0 / 30)
	s.police.frozen = true
	return s


func _run(s: Session) -> Jobs.Job:
	for i in 40:
		var j = Arsenal.gun_run(World.airfield("QRY"), s.world.airfields, s.stash_net, s.arng, 1.0, s.crates)
		if j != null:
			return j
	return null


func test_the_ladder_makes_the_powerful_rare() -> void:
	check(Crates.normal("pistol") > Crates.normal("rifle") and Crates.normal("rifle") > Crates.normal("mg")
		and Crates.normal("mg") > Crates.normal("rpg"), "pistols plentiful, rifles common, machine guns scarce, RPGs rare")
	var c := Crates.new(PyRandom.new(), PyRandom.new())
	c.rng.seed(11)
	var n := {"pistol": 0, "rifle": 0, "mg": 0, "rpg": 0}
	var total := 0
	for i in 2000:
		for t in c.deal():
			n[t] += 1
			total += 1
	check(n.pistol > n.rifle and n.rifle > n.mg and n.mg > n.rpg and n.rpg > 0, "crates are dealt in the ladder's order: %s" % [n])
	check_near(float(n.mg) / total, 0.18 / 1.81, 0.03, "about one crate in ten is machine guns")
	check_near(float(n.rpg) / total, 0.08 / 1.81, 0.02, "and fewer than one in twenty RPGs")


func test_a_gun_run_is_crates_of_one_type_each() -> void:
	var s := _city()
	check(s.crates != null, "the ladder is on")
	for i in 20:
		var j := _run(s)
		check(j != null, "a run is dealt")
		if j == null:
			break
		check(j.items.size() >= 1 and j.items.size() <= 3, "one to three crates")
		var held := {}
		var kg := 0.0
		for it in j.items:
			var tier := ""
			for t in Crates.SPEC:
				if Crates.SPEC[t].name == it.label:
					tier = t
			check(tier != "", "each item is a crate of one type: %s" % it.label)
			if tier == "":
				continue
			held[tier] = int(held.get(tier, 0)) + int(Crates.SPEC[tier].holds)
			kg += float(Crates.SPEC[tier].kg)
			check_near(it.weight_lb, float(Crates.SPEC[tier].kg) * Aircraft.LB_PER_KG, 0.06, "at its type's weight")
		check_eq(j.weapons, held, "and the weapons are what the crates hold")
		check_near(Crates.weight(j.weapons), kg, 1e-6, "the crated weight agrees")
		check(j.hot() and Economy.good_of(j) == "guns", "hot, and priced as guns")
	s.dispose()


func test_where_a_run_goes_is_unchanged() -> void:
	# the old draws are still made on arng, so the ladder moves only what is in the crates
	var a := _city()
	Crates.ENABLED = false
	var b := _city()
	Crates.ENABLED = true
	check(b.crates == null, "off: no ladder")
	for i in 12:
		var ja = Arsenal.gun_run(World.airfield("QRY"), a.world.airfields, a.stash_net, a.arng, 1.0, a.crates)
		var jb = Arsenal.gun_run(World.airfield("QRY"), b.world.airfields, b.stash_net, b.arng, 1.0, b.crates)
		check_eq(ja == null, jb == null, "dealt or not, alike")
		if ja != null and jb != null:
			check_eq([ja.dest, ja.stash], [jb.dest, jb.stash], "the same place")
			check(jb.items.all(func(it): return it.label == "Weapons crate"), "off: the old unmarked weapons crates")
	a.dispose()
	b.dispose()


func test_scarcity_prices_the_dealer_and_the_fence() -> void:
	var s := _city()
	s.money = 500000
	var base := s.weapon_price("mg", true)
	check_eq(s.crates.factor("mg"), 1.0, "the street at its normal level: the old price")
	var have: int = s.crates.available("mg")
	check(have >= 8 and have <= 12, "about ten machine guns on the island: %d" % have)
	check(not s.command(Roles.BOSS, "buy_weapons", {"tier": "mg", "n": have + 1})[0], "the dealers cannot sell more than they hold")
	check(s.command(Roles.BOSS, "buy_weapons", {"tier": "mg", "n": 6})[0], "six of them")
	check_eq(s.crates.available("mg"), have - 6, "leave the street")
	check(s.weapon_price("mg", true) > base * 1.3, "and the rest are dear: $%d from $%d" % [s.weapon_price("mg", true), base])
	var fence := s.weapon_price("mg", false)
	check(s.command(Roles.BOSS, "sell_weapons", {"tier": "mg", "n": 6})[0], "sold back to the fence")
	check_eq(s.crates.available("mg"), have, "they are on the street again")
	check(s.weapon_price("mg", false) < fence, "and the fence pays less for the next")
	check(s.command(Roles.BOSS, "buy_weapons", {"tier": "pistol", "n": 6})[0], "six pistols")
	check(s.crates.factor("pistol") < 1.1, "barely move a plentiful type: x%.2f" % s.crates.factor("pistol"))
	s.dispose()


func test_the_bulk_buyers_follow_the_ladder() -> void:
	var s := _city({"trade": true, "family": true})
	var q0 := float(s.trade.quote("family", "guns", "rpg").price)
	s.crates.flow("rpg", -3.0)
	var q1 := float(s.trade.quote("family", "guns", "rpg").price)
	check(q1 > q0 * 1.3, "RPGs short on the street: the Morettis pay more ($%d from $%d)" % [int(q1), int(q0)])
	s.crates.flow("rpg", 20.0)
	check(float(s.trade.quote("family", "guns", "rpg").price) < q0, "and less in a glut")
	check(s.crates.factor("rpg") >= Crates.PRICE_MIN, "never under the floor")
	s.dispose()


func test_a_seizure_dries_the_street_and_it_drifts_back() -> void:
	var s := _city()
	var was: int = s.crates.available("rifle")
	s._seize_weapons({"rifle": 10}, "a truck")
	check_eq(s.crates.available("rifle"), was - 5, "the dealers pull half a seizure's count off the street")
	check(s.crates.factor("rifle") > 1.0, "rifles are dearer")
	s.crates.update(Crates.RESTOCK_TAU * 6.0)
	check_near(float(s.crates.street.rifle), Crates.normal("rifle"), 0.1, "and the street is back in a few hours")
	s.dispose()


func test_a_run_sold_on_delivery_reaches_the_street() -> void:
	var s := _city()
	var j := _run(s)
	check(j != null, "a run")
	if j == null:
		s.dispose()
		return
	var before: Dictionary = s.crates.street.duplicate()
	s.active_jobs.append(j)
	s._complete_delivery(j, World.airfield(j.dest))
	if j.stash == "":
		for t in j.weapons:
			check_near(float(s.crates.street[t]), minf(3.0 * Crates.normal(t), float(before[t]) + int(j.weapons[t])), 1e-6, "%s sold: on the street" % t)
	else:
		check_eq(s.crates.street, before, "on the truck: not sold yet")
	s.dispose()


func test_the_street_is_saved() -> void:
	var s := _city()
	s.crates.flow("mg", -4.0)
	s.crates.flow("pistol", 9.0)
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	var street: Dictionary = s.crates.street.duplicate()
	s.dispose()
	var r := _city()
	StrategicSave.restore(r, d)
	for t in street:
		check_near(float(r.crates.street[t]), float(street[t]), 1e-6, "%s on the street survives a save" % t)
	d.erase("crates")
	var o := _city()
	StrategicSave.restore(o, d)
	check_near(float(o.crates.street.mg), Crates.normal("mg"), 1e-6, "an older save: the street at its normal levels")
	r.dispose()
	o.dispose()


func test_off_is_the_game_as_it_was() -> void:
	Crates.ENABLED = false
	var s := _city()
	check(s.crates == null, "no ladder")
	s.money = 500000
	check_eq(s.weapon_price("mg", true), int(Arsenal.TIERS.mg.price * s.econ.mult("guns", "town") * 1.4), "the old dealer's price")
	check(s.command(Roles.BOSS, "buy_weapons", {"tier": "mg", "n": 40})[0], "and no limit on what he sells")
	check(not StrategicSave.capture(s).has("crates"), "nothing in the save")
	s.dispose()
