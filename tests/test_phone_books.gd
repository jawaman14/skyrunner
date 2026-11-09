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


func test_m_puts_someone_in_charge_and_o_gives_the_orders() -> void:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "payroll": true, "features": Session.SANDBOX_FEATURES})
	s.police.frozen = true
	s.update(1.0 / 30)
	var w: Dictionary = s.payroll._person("org", "lookout")
	w.status = "free"
	s.payroll.workers.append(w)
	_menu = PhoneMenu.new()
	Engine.get_main_loop().root.add_child(_menu)
	_menu.setup(s)
	_menu.open()
	_menu.open_app("books")
	_select(_menu, "biz-4")
	_menu.key("m")
	check_eq(s.businesses.staff.get("biz-4"), str(w.id), "M: the free hand runs the club")
	_select(_menu, "biz-4")
	_menu.key("o")
	check_eq(s.businesses.order_of("biz-4"), "hold", "O: the next order")
	check(_text(_menu).any(func(r): return str(r).contains("runs it 20:00-04:00: buy nothing")), "the line says who and what: %s" % [_text(_menu)])


func test_w_washes_street_cash_through_a_front() -> void:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "trade": true, "logistics": true})
	s.police.frozen = true
	s.update(1.0 / 30)
	s.logistics.cash["stash:test"] = 4000
	s.logistics.book_cash("outside:street", Logistics.STREET, 4000.0, "sales")
	_menu = PhoneMenu.new()
	Engine.get_main_loop().root.add_child(_menu)
	_menu.setup(s)
	_menu.open()
	_menu.open_app("books")
	check(_text(_menu).any(func(r): return str(r).contains("Washes $2,500 a night (tonight $0)")), "the club's line says what it washes")
	_select(_menu, "biz-4")
	_menu.key("w")
	check_eq(int(s.businesses.wash.washed.get("biz-4", 0)), 2500, "W: the night's allowance, no heat")
	check(_text(_menu).any(func(r): return str(r).contains("$2,125 on its way clean")), "and the line shows it coming: %s" % [_text(_menu)])


func test_the_stock_ledger_page() -> void:
	var s := Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "trade": true, "logistics": true})
	s.police.frozen = true
	s.update(1.0 / 30)
	var st: String = s.logistics.stock.keys()[0]
	s.logistics.book("outside:growers", "stash:" + st, "marijuana", 40.0, "arrive")
	s.logistics.stock[st]["marijuana"] = float(s.logistics.stock[st].get("marijuana", 0.0)) + 40.0
	_menu = PhoneMenu.new()
	Engine.get_main_loop().root.add_child(_menu)
	_menu.setup(s)
	_menu.open()
	_menu.open_app("empire")
	check(_menu._empire.has("stock"), "Empire lists the stock ledger")
	_menu.list.select(_menu._empire.find("stock"))
	_menu.key("enter")
	check_eq(_menu.page, "stock", "ENTER opens it")
	check(_text(_menu).any(func(r): return str(r).contains("lb marijuana at %s, grade 50%%" % s.logistics.name_of(st))), "the lot, where and its grade: %s" % [_text(_menu)])
	check(_menu.footer.text.contains("lb held, worth $"), "the header sums it: %s" % _menu.footer.text)
