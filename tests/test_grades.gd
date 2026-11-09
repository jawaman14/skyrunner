extends TestCase
## Stock grades and age at the till (DESIGN 51.3, slice 2's first call sites): a lot's grade is set where it enters the map, and
## the street pays (0.5 + grade) of the street price, less what a drying lot has lost; grade 0.5 pays as before.


func after_each() -> void:
	World.use_map(0)


func _city() -> Session:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "trade": true, "logistics": true})
	s.police.frozen = true
	s.update(1.0 / 30)
	return s


func test_each_strip_has_its_own_grade() -> void:
	check_eq(Grades.own("FRM"), 0.5, "the home farm's grass is par: the early game pays as before")
	check(Grades.own("PNR") > Grades.own("QRY"), "a good strip beats a poor one")
	check_eq(Grades.own("ZZZ"), Grades.BASE, "a strip not in the table is par")
	for m in [0, MapCity.SEED]:
		World.use_map(m)
		for af in World.AIRFIELDS:
			if af.kind in ["bush", "shady"]:
				check(Grades.OWN.has(str(af.code)), "map %d: own-load strip %s has a grade" % [m, af.code])


func test_the_street_pays_for_the_grade_sold() -> void:
	var s := _city()
	var lg = s.logistics
	var st = s.stash_net.live()[0]
	var id := str(st.id)
	s.inventory.reconcile("stash:" + id, "cocaine", 0.0, s.time)
	lg.stock[id]["cocaine"] = 0.0
	lg.add(id, "cocaine", 10.0, "island")
	var lot: Dictionary = s.inventory.lots.values().filter(func(l): return l.at == "stash:" + id and l.good == "cocaine")[0]
	check_eq(snappedf(float(lot.quality), 0.01), Grades.ISLAND, "the island's grade on the lot")
	var got: Array = lg.take_market("cocaine", str(st.zone), 4.0)
	check(absf(float(got[0]) - 4.0) < 0.001, "four pounds sold")
	check(absf(float(got[2]) - (0.5 + Grades.ISLAND)) < 0.001, "at (0.5 + grade) of the street price: %s" % got[2])
	s.dispose()


func test_grass_dries() -> void:
	check(Grades.lot_mult("marijuana", 0.5, 0.0) == 1.0, "fresh grass at 0.5 is the street price")
	check(absf(Grades.lot_mult("marijuana", 0.5, Grades.HALF_LIFE_S.marijuana) - 0.5) < 0.001, "a half-life on, half")
	check_eq(Grades.lot_mult("cocaine", 0.5, 30.0 * 86400.0), 1.0, "cocaine keeps")


func test_an_own_load_carries_its_strip() -> void:
	var s := _city()
	var at := "aircraft:test"
	s.inventory.add("marijuana", 20.0, at, "unattributed", "", 0.5, 0.0, s.time)
	check_eq(s.inventory.stamp(at, "marijuana", Grades.own("FRM"), "own:FRM"), 20.0, "the unnamed lot aboard is stamped")
	var lot: Dictionary = s.inventory.lots.values().filter(func(l): return l.at == at)[0]
	check_eq(str(lot.origin), "own:FRM", "with where it was grown")
	check_eq(float(lot.quality), Grades.own("FRM"), "and its grade")
	check_eq(s.inventory.stamp(at, "marijuana", 0.9, "own:X"), 0.0, "a named lot keeps its provenance")
	s.dispose()


func test_mult_counts_unbooked_pounds_at_par() -> void:
	check(absf(Grades.mult("cocaine", [{"lb": 5.0, "quality": 1.0, "born": 0.0}], 10.0, 0.0) - 1.25) < 0.001, "5 lb at 1.5, 5 at 1.0")
	check_eq(Grades.mult("cocaine", [], 0.0, 0.0), 1.0, "nothing sold")


func test_off_everything_is_par() -> void:
	var saved := Switches.snapshot()
	Grades.ENABLED = false
	check_eq(Grades.own("HAR"), Grades.BASE, "off: every strip 0.5")
	check_eq(Grades.source("island"), Grades.BASE, "and the island")
	check_eq(Grades.mult("cocaine", [{"lb": 5.0, "quality": 1.0, "born": 0.0}], 5.0, 0.0), 1.0, "and the street pays its price")
	Switches.restore(saved)
