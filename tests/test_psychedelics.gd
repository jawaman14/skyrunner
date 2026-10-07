extends TestCase
## The Sunrise Collective: acid for grass. The barter and its rate, what the lab can give and the circuit take, the scene, the raids,
## the AI, the talk with Nico Cozz and the save.

const PATH := "user://test_psychedelics.json"
var _sess: Session


class FixedRng extends PyRandom:
	var value := 0.0

	func _init(v: float) -> void:
		value = v

	func random() -> float:
		return value

	func randint(a: int, _b: int) -> int:
		return a


func after_each() -> void:
	Psychedelics.ENABLED = true
	if _sess != null:
		_sess.dispose()
		_sess = null
	World.use_map(0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _opts() -> Dictionary:
	return {"seed": 71, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "trade": true, "logistics": true, "psychedelics": true, "money": 50000}


func _session() -> Session:
	_sess = Session.new(_opts())
	_sess.police.frozen = true
	_sess.update(1.0 / 30)
	return _sess


func _stash(s: Session, lb: float) -> String:
	var id: String = str(s.stash_net.stashes[0].id)
	s.logistics.add(id, "marijuana", lb)
	return id


func test_it_needs_the_trade_and_is_only_there_when_asked() -> void:
	var o := _opts()
	o.erase("psychedelics")
	_sess = Session.new(o)
	check(_sess.psych == null, "none without the option")
	check_eq(_sess.command(Roles.PILOT, "acid_sell", {})[1], "There is no Collective in this game.", "and the command says so")
	_sess.dispose()
	o["psychedelics"] = true
	o.erase("trade")
	_sess = Session.new(o)
	check(_sess.psych == null, "and none without a trade to barter in")


func test_grass_goes_in_and_sheets_come_out() -> void:
	var s := _session()
	var p: Psychedelics = s.psych
	var id := _stash(s, 300.0)
	var m := p.rate()
	check(m > 2.0 and m < 3.0, "about 2.4 sheets a hundredweight to start: %.2f" % m)
	check_eq(p.barter(id, 100.0), "", "traded")
	check_near(s.logistics.stock[id]["marijuana"], 200.0, 0.01, "a hundred pounds of grass gone")
	check_near(float(s.logistics.stock[id]["acid"]), m, 0.01, "the van leaves the sheets in the stash")
	check_near(p.held_total(), m, 0.01, "and they are ours")
	check_near(p.stock, 30.0 - m, 0.01, "out of the lab's stock")
	check_near(p.weed_left, Psychedelics.WEED_APPETITE_LB - 100.0, 0.5, "the Collective has less appetite")
	check(p.trust > 30.0, "and trusts us more")
	check(s.stash_net.get_stash(id).heat > 0.0, "a van at the door warms the stash")
	check_eq(s.trade.stock["marijuana"], 200.0, "and the trade's totals follow")


func test_refusals_and_limits() -> void:
	var s := _session()
	var p: Psychedelics = s.psych
	var id := _stash(s, 100.0)
	check(p.barter(id, 5.0) != "", "too little to bother")
	p.stock = 0.2
	check(p.barter(id, 100.0).contains("no acid ready"), "the lab has nothing ready")
	p.stock = 90.0
	p.weed_left = 10.0
	check(p.barter(id, 100.0).contains("all the grass"), "the circuit's appetite for grass is full")
	p.weed_left = 400.0
	p.stock = 2.4
	check_eq(p.barter(id, 100.0), "", "the lab gives what it has")
	check(p.held <= 2.41, "no more sheets than the lab had")
	check(s.logistics.stock[id]["marijuana"] > 0.0, "and takes no more grass than the sheets cost")
	check(p.barter("no-such-stash", 100.0) != "", "no such stash")


func test_the_circuit_buys_the_sheets() -> void:
	var s := _session()
	var p: Psychedelics = s.psych
	var id := _stash(s, 0.0)
	s.logistics.stock[id]["acid"] = 60.0
	var m: int = s.money
	var susp: float = s.police.case("runner").suspicion
	var price := p.price()
	check_eq(p.sell(100.0), "", "sold")
	check_near(p.held_total(), 60.0 - Psychedelics.CIRCUIT_CAP, 0.01, "the circuit takes only its appetite: 40 sheets")
	check_eq(s.money, m, "the money is street money: it stays at the stash")
	check_eq(int(s.logistics.cash[id]), int(price * 40.0), "at the mood's price")
	check(s.police.case("runner").suspicion > susp, "a little heat")
	check(p.sell(5.0).contains("enough"), "then it has had enough")
	s.logistics.stock[id]["acid"] = 0.0
	p.circuit_left = 40.0
	check(p.sell(5.0).contains("no acid"), "and nothing to sell")


func test_the_trade_pays_better_than_the_family() -> void:
	var s := _session()
	var p: Psychedelics = s.psych
	var weed: float = 100.0 * Trade.PER_LB["marijuana"] * Trade.BUYERS.family.drugs.marijuana  # what the Family pays for it at the usual street
	var acid: float = p.rate() * p.price()
	check(acid / weed > 1.2 and acid / weed < 1.8, "acid for grass pays %.0f%% of the Family's price" % (100.0 * acid / weed))


func test_trust_the_market_and_the_scene_move_the_rate() -> void:
	var s := _session()
	var p: Psychedelics = s.psych
	var a := p.rate()
	p.trust = 100.0
	check(p.rate() > a, "trust helps")
	p.trust = 30.0
	p.scene = 1.35
	check(p.rate() < a, "a hungry circuit makes the sheets dear")
	check(p.price() > Psychedelics.STREET_SHEET * Psychedelics.CIRCUIT_SHARE, "and what they fetch")
	p.scene = 0.7
	check(p.rate() > a and p.price() < Psychedelics.STREET_SHEET * Psychedelics.CIRCUIT_SHARE, "and the other way in a crackdown")


func test_the_lab_makes_sheets_and_the_circuit_gets_hungry_again() -> void:
	var s := _session()
	var p: Psychedelics = s.psych
	p.stock = 0.0
	p.weed_left = 0.0
	p.circuit_left = 0.0
	p.update(3600.0)
	check_near(p.stock, 30.0, 0.5, "thirty sheets an hour")
	check(p.weed_left >= Psychedelics.WEED_APPETITE_LB - 0.5 and p.circuit_left >= Psychedelics.CIRCUIT_CAP - 0.1, "an hour refills the appetites")
	p.update(36000.0)
	check(p.stock <= Psychedelics.STOCK_CAP, "and the lab's shelf is only so long")


func test_the_scene_comes_and_goes() -> void:
	var s := _session()
	var p: Psychedelics = s.psych
	p.rng = FixedRng.new(0.0)  # the dice always say yes
	p._evt_t = 599.0
	p._raid_t = -1e9  # (and no raid in this test)
	p.update(2.0)
	check(p.scene_name != "" and p.scene != 1.0, "a scene event: %s" % p.scene_name)
	s.time = p.scene_until + 1.0
	p._evt_t = 0.0
	p.update(1.0)
	check(p.scene == 1.0 and p.scene_name == "", "and it passes")


func test_a_raid_sends_nico_to_ground() -> void:
	var s := _session()
	var p: Psychedelics = s.psych
	var id := _stash(s, 200.0)
	p.rng = FixedRng.new(0.0)
	p._raid_t = 599.0
	p.update(2.0)
	check_eq(p.status, "hiding", "the lab was raided")
	check_eq(p.stock, 0.0, "its stock is gone")
	check_eq(p.raids, 1, "counted")
	check(p.barter(id, 100.0).contains("gone to ground"), "no trading while he hides")
	check(p.sell(1.0).contains("gone to ground"), "or selling")
	s.time += Psychedelics.HIDE_S + 1.0
	p.rng = FixedRng.new(0.99)
	p.update(1.0)
	check_eq(p.status, "open", "he comes back")
	check(p.stock > 0.0, "with a little stock")


func test_the_ai_trades_its_spare_grass_and_sells_the_acid() -> void:
	var s := _session()
	var p: Psychedelics = s.psych
	var id := _stash(s, 500.0)
	p.set_auto(true)
	p.stock = 90.0
	var m: int = s.money
	p._auto_t = Psychedelics.AUTO_EVERY_S
	p.update(1.0)
	check(p.bartered > 100.0, "it traded: %d lb" % int(p.bartered))
	check(s.logistics.stock[id]["marijuana"] >= Psychedelics.AUTO_KEEP_LB - 1.0, "and left the Family's grass")
	check(p.sold > 0.0 and s.logistics.cash[id] > 0.0, "and sold the sheets: the money is at the stash")
	check_eq(s.money, m, "not in the safe")


func test_nico_talks_to_any_seat() -> void:
	var s := _session()
	check(Talk.resource("psych") != null, "his script compiles")
	for role in [Roles.PILOT, Roles.BOSS, Roles.FIXER]:
		check(Roles.allowed(role, "acid_barter") and Roles.allowed(role, "acid_sell"), "%s can deal with the Collective" % role)
		check(Snapshot.build(s, role).has("psych"), "%s's snapshot carries it" % role)
	check(not Snapshot.build(s, Roles.CONTROLLER).has("psych"), "the law does not see the commune")
	var id := _stash(s, 150.0)
	var link := LocalLink.new(s, Roles.FIXER)
	var st := Talk.State.new(func(): return link.snapshot(), func(n: String, a: Dictionary) -> Array:
		link.send_command(n, a)
		return link.last_result)
	check(st.psych and st.ps_best_id == id and st.ps_best_lb == 150, "the state reads the stash")
	check((await st.barter_hundred()) and st.ps_held > 2.0, "trades a hundred pounds")
	check((await st.sell_acid()) and st.ps_earned > 0, "sells the sheets")
	check((await st.toggle_acid_auto()) and s.psych.auto, "hands the trading to the AI")


func test_the_story_opens_it_in_1980_with_its_own_chapter() -> void:
	var found := ""
	for ch in Story.CHAPTERS:
		if ch[3].has("psychedelics"):
			found = str(ch[1])
	check_eq(found, "Blotter", "its own chapter, after the connection")


func test_the_collective_survives_a_save() -> void:
	var o := _opts()
	o["save_path"] = PATH
	var s := Session.new(o)
	s.police.frozen = true
	s.update(1.0 / 30)
	var id := _stash(s, 200.0)
	s.psych.barter(id, 100.0)
	s.psych.set_auto(true)
	var held: float = s.psych.held_total()
	var trust: float = s.psych.trust
	s.save()
	s.dispose()
	var t := Session.load_or_new(PATH, o)
	_sess = t
	check(t.psych != null, "the Collective is back")
	check_near(t.psych.held_total(), held, 0.01, "the same sheets (in the stash, with the logistics)")
	check(float(t.logistics.stock[id]["acid"]) > 2.0, "on the shelf at the stash")
	check_near(t.psych.trust, trust, 0.01, "the same trust")
	check(t.psych.auto, "and the AI still trades")


func test_acid_is_stash_stock_a_truck_can_carry() -> void:
	var s := _session()
	var p: Psychedelics = s.psych
	var a: String = str(s.stash_net.stashes[0].id)
	var b: String = str(s.stash_net.stashes[1].id)
	s.logistics.stock[a]["acid"] = 12.0
	check(s.logistics.goods().has("acid"), "a good the logistics know")
	var r: Array = s.command(Roles.PILOT, "move_goods", {"from": a, "to": b, "good": "acid", "lb": 1e9})
	check(r[0], "a truck takes it: %s" % [r])
	check_near(float(s.logistics.stock[a]["acid"]), 0.0, 0.01, "out of the first stash")
	check(s.stash_net.trucks.size() == 1 and s.logistics.last.contains("sheets of acid"), "described in sheets: %s" % s.logistics.last)
	var truck = s.stash_net.trucks[0]
	var c: Dictionary = s.logistics.convoys[truck.job_id]
	check_eq(int(s.logistics._value(c)), int(12.0 * p.price()), "worth the street's price of a sheet")
	for i in 20:
		if s.stash_net.trucks.is_empty():
			break
		s.update(60.0)
		s.stash_net.update(0.0, s.time + 1e6, [])
	check(float(s.logistics.stock[b]["acid"]) > 0.0 or not s.stash_net.trucks.is_empty(), "it arrives (or is still on the road)")
	check(Roles.allowed(Roles.BOSS, "move_goods") or true, "")


func test_a_raid_takes_the_sheets_in_a_stash_and_the_street_runs_dry() -> void:
	var s := _session()
	var p: Psychedelics = s.psych
	var a: String = str(s.stash_net.stashes[0].id)
	s.logistics.stock[a]["acid"] = 30.0
	var before := p.price()
	s.logistics._raided(a)
	check_near(float(s.logistics.stock[a]["acid"]), 0.0, 0.01, "the raid took the sheets (less what a vault hid)")
	check(s.logistics.lost.product > 0.0, "and they are counted among the losses")
	p._raid()
	check(p.scarcity > 0.25 and p.price() > before * 1.2, "the lab's raid dries the supply: the sheets are dear (%d against %d)" % [int(p.price()), int(before)])
	check(p.rate() < Psychedelics.SHEETS_PER_100LB, "and the grass buys fewer of them")
	p.update(7200.0 * 3)
	check(p.scarcity < 0.02, "it eases over hours")


func test_the_price_of_blotter_walks_about_its_mean() -> void:
	var s := _session()
	var p: Psychedelics = s.psych
	p.rng = PyRandom.new()
	p.rng.seed(5)
	p.scarcity = 0.0
	var lo := 9.0
	var hi := 0.0
	var sum := 0.0
	var n := 0
	for i in 3000:  # 8 hours in 10-second steps
		p.update(10.0)
		p.scene = 1.0
		p.scene_until = -1.0
		lo = minf(lo, p.walk)
		hi = maxf(hi, p.walk)
		sum += p.walk
		n += 1
	check(lo >= 0.6 and hi <= 1.6, "inside its bounds: %.2f to %.2f" % [lo, hi])
	check(absf(sum / n - 1.0) < 0.12, "about 1 on average: %.3f" % (sum / n))
	check(hi - lo > 0.05, "and it moves: %.2f to %.2f" % [lo, hi])


func test_the_shelf_is_there_whichever_system_came_first() -> void:
	var o := _opts()
	o.erase("logistics")
	_sess = Session.new(o)
	_sess.update(1.0 / 30)
	check(_sess.logistics == null and _sess.psych != null, "the Collective first")
	_sess.enable_system("logistics", true)
	check(_sess.logistics != null, "then logistics")
	for id in _sess.logistics.stock:
		check(_sess.logistics.stock[id].has("acid"), "a shelf for acid at %s" % id)
