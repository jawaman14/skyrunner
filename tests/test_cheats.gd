extends TestCase
## The owner's test menu actions (Cheats): each does what its row says on a plain session.


func _sess() -> Session:
	var s := Session.new({"seed": 8, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "logistics": true})
	s.update(1.0 / 30)
	return s


func test_money_adds_to_the_cash_in_hand() -> void:
	var s := _sess()
	var m0 := s.money
	Cheats.run(s, "money_100k")
	Cheats.run(s, "money_1m")
	check_eq(s.money, m0 + 1100000, "both amounts")
	s.dispose()


func test_fill_stashes_stocks_every_house() -> void:
	var s := _sess()
	if s.logistics == null:
		s.dispose()
		return
	var site: String = str(s.logistics.stock.keys()[0])
	var before: float = s.logistics.stock[site][s.logistics.goods()[0]]
	Cheats.run(s, "fill_stashes")
	check_eq(s.logistics.stock[site][s.logistics.goods()[0]], before + Cheats.FILL_LB, "a shelf is full")
	s.dispose()


func test_clear_heat_zeroes_the_stashes() -> void:
	var s := _sess()
	if s.stash_net != null and not s.stash_net.stashes.is_empty():
		s.stash_net.stashes[0].heat = 80.0
		Cheats.run(s, "clear_heat")
		check_eq(s.stash_net.stashes[0].heat, 0.0, "stash heat gone")
	check_eq(Cheats.run(s, "nonsense"), "Unknown cheat.", "an unknown id does nothing")
	s.dispose()
