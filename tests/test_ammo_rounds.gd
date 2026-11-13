extends TestCase
## Ammunition as a good, stage 2 of D-61 (DESIGN 91): rounds are kept by the type of gun that fires them; the old single pool is
## their total and moves exactly as before; a crate of rounds is bought at the dealer, priced by the guns market and the type's
## scarcity; seizures carry rounds by type; saves keep them, and an older save's pool is shared out over the guns it holds.


func after_each() -> void:
	World.use_map(0)
	Arsenal.AMMO_TRADE = true


func test_rounds_come_with_their_guns() -> void:
	var a := Arsenal.new("x", false)
	a.add("rifle", 2)
	a.add("pistol", 1)
	check_eq([a.rounds.rifle, a.rounds.pistol, a.rounds.mg], [240, 120, 0], "a crate's worth of each gun's own")
	check_eq(a.ammo, 360, "and the pool is their total")


func test_the_pool_moves_exactly_as_one_number() -> void:
	var a := Arsenal.new("x", false)
	a.add("rifle", 3)
	a.add("pistol", 1)
	a.add("mg", 1)
	var before := a.ammo
	a.ammo -= 97
	check_eq(a.ammo, before - 97, "takes exactly what was asked")
	a.ammo += 53
	check_eq(a.ammo, before - 97 + 53, "and adds exactly")
	a.ammo = 0
	check_eq([a.ammo, a.rounds.rifle, a.rounds.pistol, a.rounds.mg], [0, 0, 0, 0], "to nothing")
	a.ammo = 500
	check_eq(a.ammo, 500, "added back in proportion to the guns")
	check(a.rounds.rifle > a.rounds.pistol and a.rounds.rifle > a.rounds.mg, "most for the most guns: %s" % str(a.rounds))
	var empty := Arsenal.new("y", false)
	empty.ammo = 90
	check_eq(empty.rounds.rifle, 90, "no guns at all: rifle rounds")


func test_takes_in_proportion_to_what_is_held() -> void:
	var a := Arsenal.new("x", false)
	a.rounds = {"pistol": 300, "rifle": 600, "mg": 100, "rpg": 0}
	a.ammo -= 100
	check_eq(a.rounds, {"pistol": 270, "rifle": 540, "mg": 90, "rpg": 0}, "a tenth of each")


func test_a_seizure_carries_rounds_by_type() -> void:
	var a := Arsenal.new("x", false)
	a.add("mg", 1)
	var law := Arsenal.new("law", false)
	a.seize_into(law)
	check_eq([a.ammo, law.rounds.mg], [0, 120], "the belts go with the gun")
	var b := Arsenal.new("z", false)
	b.take_seized({"pistol": 2})
	check_eq(b.rounds.pistol, 120, "half a crate's rounds with a seized gun")


func _sess() -> Session:
	var s := Session.new({"seed": 3, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	s.police.frozen = true
	s.update(1.0 / 30)
	s.money = 50000
	return s


func test_rounds_bought_by_the_crate() -> void:
	var s := _sess()
	var ars: Arsenal = s.arsenals["org"]
	var r0: int = int(ars.rounds.mg)
	var each := s.ammo_price("mg")
	check(each > 0, "a crate of belts: $%d" % each)
	var r: Array = s.command(Roles.BOSS, "buy_ammo", {"tier": "mg", "crates": 2})
	check(r[0], "bought: %s" % str(r[1]))
	check_eq(int(ars.rounds.mg), r0 + 800, "two crates of 400")
	check_eq(s.money, 50000 - 2 * each, "paid")
	check(not s.command(Roles.BOSS, "buy_ammo", {"tier": "cannon", "crates": 1})[0], "a type there is")
	check(not s.command(Roles.BOSS, "buy_ammo", {"tier": "rifle", "crates": 50})[0], "one to ten crates")
	s.money = 10
	check(not s.command(Roles.BOSS, "buy_ammo", {"tier": "rifle", "crates": 1})[0], "not without the money")
	check(not s.command(Roles.CONTROLLER, "buy_ammo", {"tier": "rifle", "crates": 1})[0], "not the task force's")
	s.dispose()


func test_scarce_guns_have_dear_rounds() -> void:
	var s := _sess()
	if s.crates == null:
		check(true, "no ladder this game")
		s.dispose()
		return
	var normal := s.ammo_price("rifle")
	s.crates.street["rifle"] = 2  # the street has nearly run out of rifles
	check(s.ammo_price("rifle") > normal, "rifle rounds dearer when rifles are scarce: $%d against $%d" % [s.ammo_price("rifle"), normal])
	s.dispose()


func test_saved_by_type_and_an_older_save_shared_out() -> void:
	var s := _sess()
	var ars: Arsenal = s.arsenals["org"]
	ars.rounds = {"pistol": 11, "rifle": 22, "mg": 33, "rpg": 4}
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	s.dispose()
	var r := _sess()
	StrategicSave.restore(r, d)
	check_eq(r.arsenals["org"].rounds, {"pistol": 11, "rifle": 22, "mg": 33, "rpg": 4}, "by type")
	r.dispose()
	d.arsenals.org.erase("rounds")
	d.arsenals.org.stock = {"pistol": 1, "rifle": 3, "mg": 0, "rpg": 0}
	d.arsenals.org.ammo = 400
	var o := _sess()
	StrategicSave.restore(o, d)
	check_eq(o.arsenals["org"].ammo, 400, "an older save keeps its pool")
	check_eq([o.arsenals["org"].rounds.pistol, o.arsenals["org"].rounds.rifle], [100, 300], "shared out over its guns")
	o.dispose()


func test_off_no_crates_of_rounds() -> void:
	Arsenal.AMMO_TRADE = false
	var s := _sess()
	check(not s.command(Roles.BOSS, "buy_ammo", {"tier": "rifle", "crates": 1})[0], "off: nobody sells them")
	s.dispose()


## DESIGN 93: a street at war bids rounds up; the dealer won't deliver into streets Los Cuervos hold.
func test_rounds_dearer_while_the_street_is_shooting() -> void:
	var s := _sess()
	var calm := s.ammo_price("rifle")
	s.ground.hot_spots = [[s.time, 0.0, 0.0], [s.time, 0.0, 0.0], [s.time, 0.0, 0.0]]
	check_near(float(s.ammo_price("rifle")), float(calm) * 1.3, 1.0, "three firefights: 30% dearer")
	for i in 20:
		s.ground.hot_spots.append([s.time, 0.0, 0.0])
	check_near(float(s.ammo_price("rifle")), float(calm) * 1.6, 1.0, "at most 60%")
	s.dispose()


func test_no_delivery_into_los_cuervos_streets() -> void:
	var s := _sess()
	var ars: Arsenal = s.arsenals["org"]
	ars.cache = ""
	s.ground.control["town"] = {"org": 0.0, "rival": 10.0, "police": 0.0}
	var r: Array = s.command(Roles.BOSS, "buy_ammo", {"tier": "rifle", "crates": 1})
	check(not r[0] and str(r[1]).contains("Los Cuervos"), "they hold the town, where the armoury is: %s" % str(r[1]))
	check_eq(s.money, 50000, "nothing paid")
	s.ground.control["town"] = {"org": 10.0, "rival": 0.0, "police": 0.0}
	check(s.command(Roles.BOSS, "buy_ammo", {"tier": "rifle", "crates": 1})[0], "ours again: delivered")
	s.dispose()
