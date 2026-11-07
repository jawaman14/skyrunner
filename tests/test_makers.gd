extends TestCase
## Makers (D-95): each vehicle on the lot is built by one of four fictional makers with one behaviour, and two or three models
## from one maker make a set with a fleet bonus.

var _sess: Session


func after_each() -> void:
	if _sess != null:
		_sess.dispose()
		_sess = null
	World.use_map(0)


func _session() -> Dealership:
	_sess = Session.new({"seed": 61, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES,
		"dealership": true, "trade": true, "logistics": true, "money": 500000})
	_sess.police.frozen = true
	_sess.update(1.0 / 30)
	return _sess.dealer


func test_every_maker_builds_at_least_two_models_and_has_a_set() -> void:
	for maker in Dealership.MAKERS:
		var n := Dealership.CATALOGUE.filter(func(c): return c.maker == maker).size()
		check(n >= 2, "%s builds %d" % [maker, n])
		check(not Dealership.set_bonus(maker, n).is_empty(), "%s has a set at %d models" % [maker, n])
		check(Dealership.set_bonus(maker, 1).is_empty(), "one model is not a set")


func test_halcyon_is_cheap_to_keep() -> void:
	var d := _session()
	d.buy("van")
	check_eq(d.insurance_hour(), int(Dealership.INSURANCE_HAUL * Dealership.HALCYON_INSURANCE), "half the insurance")
	d.buy("box")
	check_eq(d.insurance_hour(), int(Dealership.INSURANCE_HAUL * Dealership.HALCYON_INSURANCE + Dealership.INSURANCE_HAUL), "a Bastion pays in full")


func test_corsair_holds_its_value() -> void:
	var d := _session()
	d.buy("fast")
	var m: int = _sess.money
	d.sell(int(d.owned[0].serial))
	check_eq(_sess.money, m + int(38000 * Dealership.CORSAIR_RESALE), "70% back")
	check_eq(Dealership.resale("van"), int(14000 * Dealership.RESALE), "others 55%")


func test_mercy_cars_take_the_back_roads() -> void:
	var d := _session()
	d.buy("suv")
	check_near(float(d.drive_spec().off), 16.0 + Dealership.MERCY_OFF, 0.001, "quicker across country")
	check_near(float(Dealership.spec("suv").off), 16.0, 0.001, "the catalogue itself is untouched")


func test_bastion_steel_stacks_and_the_set_adds_more() -> void:
	var d := _session()
	d.buy("armoured")
	check_near(float(d.fleet().armour), 0.6, 0.001, "one truck: its own steel")
	d.buy("box")
	check_near(float(d.fleet().armour), minf(Dealership.MAX_STEEL, 0.6 + 0.25 * Dealership.BASTION_STACK + 0.10), 0.001, "stacked, plus the set")
	d.buy("box")
	check_near(float(d.fleet().armour), Dealership.MAX_STEEL, 0.001, "never past the cap")


func test_sets_count_models_not_vehicles() -> void:
	var d := _session()
	d.buy("hatch")
	d.buy("hatch")
	check(d.models().halcyon == 1, "two hatches are one model")
	d.buy("van")
	check_near(float(d.fleet().stealth), 0.15 + 0.05, 0.001, "hatch and van: the two-model set")
	d.buy("coupe")
	check_near(float(d.fleet().stealth), 0.15 + 0.10, 0.001, "all three: the bigger one")
	check("Halcyon Motors 3 of 3" in d.sets_line(), d.sets_line())


func test_the_corsair_set_quickens_the_trucks_and_the_car() -> void:
	var d := _session()
	d.buy("roadster")
	d.buy("fast")
	check_near(float(d.fleet().speed), 15.0 + 1.5, 0.001, "the trucks")
	check_near(float(d.drive_spec().road), 34.0 + 2.0, 0.001, "and the Marlin")
	check_near(_sess.stash_net.haul_ms, 16.5, 0.001, "handed to the stash runs")


func test_selling_breaks_the_set() -> void:
	var d := _session()
	d.buy("roadster")
	d.buy("fast")
	d.sell(int(d.owned[0].serial))
	check_near(float(d.fleet().speed), 15.0, 0.001, "back to the van's own speed")
	check_eq(d.sets_line(), "Corsair 1 of 2", "no bonus shown")


func test_the_dealer_screen_shows_the_maker() -> void:
	check("Bastion Works" in DealerMenu.stats(Dealership.spec("armoured")), DealerMenu.stats(Dealership.spec("armoured")))
