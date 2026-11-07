extends TestCase
## The business books on the phone (L-4; spec A1): Empire > Businesses opens the books: ours with their tills, debts and the
## reasons; the free ones to buy (ENTER); F funds, T takes the till; the AI orgs' refused moves with their reasons.

var _menu: PhoneMenu


func after_each() -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
	World.use_map(0)


func _books() -> PhoneMenu:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "HAR"})
	s.police.frozen = true
	s.update(1.0 / 30)
	s.money = 20000
	_menu = PhoneMenu.new()
	Engine.get_main_loop().root.add_child(_menu)
	_menu.setup(s)
	_menu.open()
	return _menu


func _text(m: PhoneMenu) -> Array:
	var out := []
	for i in m.list.row_count():
		out.append(m.list.cell(i, 0))
	return out


func _select(m: PhoneMenu, id: String) -> void:
	m.list.select(m._books_rows.find(id))


func test_empire_opens_the_books() -> void:
	var m := _books()
	m.open_app("empire")
	check(m._empire.has("books"), "Empire lists the books")
	m.list.select(m._empire.find("books"))
	m.key("enter")
	check_eq(m.page, "books", "and ENTER opens them")
	var rows := _text(m)
	check(rows.has("OURS") and rows.has("FOR SALE (ENTER BUYS)") and rows.has("THE DISTRICT'S OTHERS"), "three groups: %s" % [rows])
	check(rows.any(func(r): return str(r).begins_with("Club Tropicana: till $0")), "the club with its till")
	check(rows.any(func(r): return str(r).contains("Lavanderia Sol") and str(r).contains("The Morettis")), "and the Morettis' laundromat")


func test_a1_buy_a_business_and_read_its_books() -> void:
	var m := _books()
	m.open_app("books")
	_select(m, "biz-12")
	m.key("enter")
	check_eq(m.s.businesses.owner["biz-12"], "org", "bought from the phone")
	check_eq(int(m.s.money), 8000, "for its price")
	_select(m, "biz-12")
	m.key("f")
	check_eq(m.s.businesses.balance("biz-12"), PhoneMenu.BOOKS_FUND, "F put money in its till")
	m.s.businesses._on_books(null)
	m.refresh()
	check(_text(m).any(func(r): return str(r).begins_with("Taller Rapido: till $840")), "and the books read the day's costs out: %s" % [_text(m)])
	_select(m, "biz-12")
	m.key("t")
	check_eq(m.s.businesses.balance("biz-12"), 0, "T took the till")
	check_eq(int(m.s.money), 7840, "into the safe")


func test_debts_and_refusals_show_with_their_reasons() -> void:
	var m := _books()
	var s: Session = m.s
	s.ledger.transfer("moretti:safe", "outside:market", s.ledger.balance("moretti:safe"), "purchase", "moretti", s.time)
	s.businesses._on_books(null)
	m.open_app("books")
	var rows := _text(m)
	check(rows.any(func(r): return str(r).begins_with("Club Tropicana") and str(r).contains("OWES $390")), "our club owes, with why: %s" % [rows])
	check(rows.has("REFUSED AND BLOCKED"), "the refused moves have their own heading")
	check(rows.any(func(r): return str(r).begins_with("The Morettis: The safe is empty")), "with the Morettis' reason")
