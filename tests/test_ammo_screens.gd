extends TestCase
## Ammunition on the screens, D-61 stage 4 (DESIGN 99): the market board quotes the dealer's crates of rounds, the war's mark-up and
## a blocked delivery's reason; the stock ledger lists the armoury's rounds by type and A orders a crate of the neediest on the
## pickup flow; the logistics view carries the rounds; off, none of it shows.

var _menu: PhoneMenu


func after_each() -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
	World.use_map(0)
	Arsenal.AMMO_TRADE = true


func _sess() -> Session:
	var s := Session.new({"seed": 21, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES,
		"trade": true, "logistics": true, "family": true, "ground_war": true})
	s.police.frozen = true
	s.update(1.0 / 30)
	s.money = 80000
	return s


func _phone(s: Session, page: String) -> PhoneMenu:
	_menu = PhoneMenu.new()
	Engine.get_main_loop().root.add_child(_menu)
	_menu.setup(s)
	_menu.open()
	_menu.page = page
	_menu.refresh()
	return _menu


func _text(m: PhoneMenu) -> Array:
	var out := []
	for i in m.list.row_count():
		out.append(str(m.list.cell(i, 0)))
	return out


func test_the_words() -> void:
	check_eq(Arsenal.rounds_text({"pistol": 1000, "rifle": 600, "mg": 0, "rpg": 0}), "600 rifle rounds, 1,000 pistol rounds",
		"best gun first, with thousands marked")
	check_eq(Arsenal.rounds_text({"pistol": 0, "rifle": 0}), "no rounds")
	check_eq(Arsenal.neediest({"pistol": 4, "rifle": 2}, {"pistol": 480, "rifle": 120}), "rifle", "60 a rifle against 120 a pistol")
	check_eq(Arsenal.neediest({"pistol": 2, "rifle": 2, "mg": 0}, {"pistol": 100, "rifle": 100, "mg": 0}), "rifle",
		"a tie goes to the better gun; a type with no guns doesn't count")
	check_eq(Arsenal.neediest({}, {}), "rifle", "no guns: rifle rounds")


func test_the_market_board_quotes_the_dealer() -> void:
	var s := _sess()
	check(PhoneMenu.ammo_open(s), "guns are open in the sandbox")
	var rows := _text(_phone(s, "market"))
	check(rows.has("AMMUNITION (THE GUN DEALER)"), "its own heading: %s" % [rows])
	var rifle := "Rifle rounds: $%s a crate of 600, 18 kg" % Py.money(s.ammo_price("rifle"))
	check(rows.has(rifle), "the dealer's price now: %s" % [rows])
	check(not rows.any(func(r): return str(r).contains("The street is fighting")), "no mark-up in a calm street")
	s.ground.hot_spots = [[s.time, 0.0, 0.0], [s.time, 0.0, 0.0]]
	s.arsenals["org"].cache = ""
	s.ground.control["town"] = {"org": 0.0, "rival": 10.0, "police": 0.0}
	_menu.refresh()
	rows = _text(_menu)
	check(rows.has("  The street is fighting: rounds cost 20% more until it quiets."), "two firefights: 20%% more: %s" % [rows])
	check(rows.any(func(r): return str(r).contains("won't drive into Los Cuervos' streets")), "and why he won't deliver")
	s.dispose()


func test_the_ledger_lists_the_rounds_and_a_orders_the_neediest() -> void:
	var s := _sess()
	var ars: Arsenal = s.arsenals["org"]
	var m := _phone(s, "stock")
	check(_text(m).has("THE ARMOURY'S ROUNDS"), "a heading for the rounds")
	check(_text(m).has(Arsenal.rounds_text(ars.rounds)), "by type: %s" % Arsenal.rounds_text(ars.rounds))
	var need := Arsenal.neediest(ars.stock, ars.rounds)
	var paid := s.money
	m.key("a")
	check_eq(s.logistics.pickups.orders.size(), 1, "A ordered a crate on the pickup flow")
	var o: Dictionary = s.logistics.pickups.orders[0]
	check_eq([str(o.good), str(o.tier)], ["ammo", need], "of the rounds we're shortest of")
	check(s.money < paid, "paid up front")
	s.dispose()


func test_the_logistics_view_carries_the_rounds() -> void:
	var s := _sess()
	var arm: Dictionary = s.logistics.view().armoury
	check_eq(arm.rounds, s.arsenals["org"].rounds, "the desk's armoury line has them by type")
	s.dispose()


func test_off_none_of_it() -> void:
	Arsenal.AMMO_TRADE = false
	var s := _sess()
	check(not PhoneMenu.ammo_open(s), "no dealer selling rounds: nothing to show")
	var rows := _text(_phone(s, "market"))
	check(not rows.has("AMMUNITION (THE GUN DEALER)"), "no section on the board")
	_menu.queue_free()
	_menu = null
	var m := _phone(s, "stock")
	m.key("a")
	check_eq(s.logistics.pickups.orders.size(), 0, "and A orders nothing")
	s.dispose()
