extends TestCase
## Ammunition in the war, stage 3 first part (DESIGN 92): a squad draws the rounds of the guns it carries, 90 a man; its pool spends
## in proportion; a gun out of its rounds fires like bare hands; a squad out of every round keeps the old fifth; what is left goes
## back by type; saved by type, an older save shared over the loadout; off, the old pooled draw.


func after_each() -> void:
	World.use_map(0)
	GroundWar.AMMO_BY_TYPE = true


func _war() -> Session:
	var s := Session.new({"seed": 3, "map_seed": MapCity.SEED, "location": "QRY", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	s.police.frozen = true
	s.ground._started = true
	for f in s.ground.commanders:
		s.ground.commanders[f].ai = false
	s.update(1.0 / 30)
	return s


func _arm(s: Session, weapons: Dictionary, rounds: Dictionary) -> Arsenal:
	var a: Arsenal = s.arsenals["org"]
	for t in a.stock:
		a.stock[t] = int(weapons.get(t, 0))
	for t in a.rounds:
		a.rounds[t] = int(rounds.get(t, 0))
	return a


func test_a_squad_draws_its_guns_rounds() -> void:
	var s := _war()
	var a := _arm(s, {"rifle": 2, "mg": 2}, {"rifle": 1000, "mg": 50, "pistol": 999})
	var q = s.ground.recruit("org", "foot", null, false)
	check(q is GroundWar.Squad, "a squad")
	var rifles: int = int(q.loadout.get("rifle", 0))
	var mgs: int = int(q.loadout.get("mg", 0))
	check_eq(int(q.by.rifle), rifles * 90, "90 rifle rounds a rifleman")
	check_eq(int(q.by.mg), mini(50, mgs * 90), "the belts there are")
	check_eq(int(q.by.pistol), 0, "no pistol rounds for men with no pistols")
	check_eq(int(a.rounds.pistol), 999, "left in the armoury")
	s.dispose()


func test_a_gun_out_of_its_rounds_fires_like_bare_hands() -> void:
	var s := _war()
	var q = s.ground.recruit("org", "foot", null, false)
	q.loadout = {"mg": 1, "rifle": 3}
	q.men = 4
	q.by = {"pistol": 0, "rifle": 270, "mg": 90, "rpg": 0}
	var full: float = s.ground.fire(q)
	q.by.mg = 0
	var dry_mg: float = s.ground.fire(q)
	check(dry_mg < full, "the machine gun out of belts: less fire (%.2f against %.2f)" % [dry_mg, full])
	var expect: float = Arsenal.power({"rifle": 3}, 4) / Arsenal.power({"mg": 1, "rifle": 3}, 4)
	check_near(dry_mg / full, expect, 1e-6, "as if that man carried nothing")
	q.by.rifle = 0
	var none: float = s.ground.fire(q)
	GroundWar.AMMO_BY_TYPE = false
	check_near(none, s.ground.fire(q), 1e-9, "no rounds at all: the old fifth, as before")
	s.dispose()


func test_spending_is_in_proportion_and_the_rest_goes_back() -> void:
	var s := _war()
	var a := _arm(s, {"rifle": 4}, {"rifle": 2000})
	var q = s.ground.recruit("org", "foot", null, false)
	var drawn: int = q.ammo
	q.ammo -= 50
	check_eq(q.ammo, drawn - 50, "a fight takes exactly what it took")
	var before: int = int(a.rounds.rifle)
	s.ground.disband(q)
	check_eq(int(a.rounds.rifle), before + drawn - 50, "what is left goes back as rifle rounds")
	s.dispose()


func test_saved_by_type() -> void:
	var s := _war()
	_arm(s, {"rifle": 4, "mg": 1}, {"rifle": 2000, "mg": 400})
	var q = s.ground.recruit("org", "foot", null, false)
	var by: Dictionary = q.by.duplicate()
	var d: Dictionary = JSON.parse_string(JSON.stringify(StrategicSave.capture(s)))
	s.dispose()
	var r := _war()
	StrategicSave.restore(r, d)
	var rq = r.ground.squads.filter(func(x): return x.faction == "org" and x.loadout == q.loadout)
	check(not rq.is_empty(), "the squad is back")
	if not rq.is_empty():
		check_eq(rq[0].by, by, "with its rounds by type")
	r.dispose()


func test_off_the_old_pooled_draw() -> void:
	GroundWar.AMMO_BY_TYPE = false
	var s := _war()
	var a := _arm(s, {"rifle": 4}, {"pistol": 1000})
	var q = s.ground.recruit("org", "foot", null, false)
	check_eq(q.ammo, q.men * 90, "off: drawn from the pool whatever the type")
	check_eq(a.ammo, 1000 - q.men * 90, "and the pool is down by as much")
	s.dispose()
