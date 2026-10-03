extends TestCase
## The Hotel Cielo's tables (CasinoGames): their rules, and the house edge each one really has.


func _rng(seed_ := 7) -> PyRandom:
	var r := PyRandom.new()
	r.seed(seed_)
	return r


# ------------------------------------------------------------------ roulette
func test_roulette_bets_cover_what_the_table_says_and_pay_what_it_pays() -> void:
	var R := CasinoGames.Roulette
	check_eq(R.covers({"kind": "straight", "n": 17}), [17], "a straight-up number")
	check_eq(R.covers({"kind": "split", "a": 17, "b": 18}), [17, 18], "a split across")
	check_eq(R.covers({"kind": "split", "a": 17, "b": 20}), [17, 20], "and down")
	check(R.covers({"kind": "split", "a": 17, "b": 19}).is_empty(), "not a split on two numbers that do not touch")
	check(R.covers({"kind": "split", "a": 3, "b": 4}).is_empty(), "nor across the rows' edge")
	check_eq(R.covers({"kind": "split", "a": 0, "b": 2}), [0, 2], "the zero touches 1, 2 and 3")
	check_eq(R.covers({"kind": "street", "n": 5}), [13, 14, 15], "a street (a row of three)")
	check_eq(R.covers({"kind": "corner", "n": 14}), [14, 15, 17, 18], "a corner")
	check(R.covers({"kind": "corner", "n": 15}).is_empty(), "no corner on the last column")
	check_eq(R.covers({"kind": "line", "n": 2}).size(), 6, "a six line")
	check_eq(R.covers({"kind": "dozen", "n": 2}).size(), 12, "a dozen")
	check_eq(R.covers({"kind": "column", "n": 1}), [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34], "a column")
	check_eq(R.covers({"kind": "red"}).size(), 18, "eighteen reds")
	check_eq(R.covers({"kind": "black"}).size(), 18, "and eighteen blacks")
	check(not R.covers({"kind": "red"}).has(0) and not R.covers({"kind": "even"}).has(0), "the zero is on no outside bet")
	check_eq(R.net({"kind": "straight", "n": 17, "amount": 10}, 17), 350, "35 to 1")
	check_eq(R.net({"kind": "straight", "n": 17, "amount": 10}, 3), -10, "and the stake lost")
	check_eq(R.net({"kind": "red", "amount": 10}, 0), -10, "red loses on the zero")
	check_eq(R.net({"kind": "dozen", "n": 3, "amount": 10}, 30), 20, "a dozen pays 2 to 1")
	check(R.valid({"kind": "red", "amount": 5}) and not R.valid({"kind": "red", "amount": 4}) and not R.valid({"kind": "red", "amount": 501}), "the table's limits")


func test_every_roulette_bet_has_the_same_house_edge_of_one_in_thirty_seven() -> void:
	var R := CasinoGames.Roulette
	var bets := [{"kind": "straight", "n": 0}, {"kind": "straight", "n": 17}, {"kind": "split", "a": 14, "b": 15}, {"kind": "street", "n": 4},
		{"kind": "corner", "n": 20}, {"kind": "line", "n": 5}, {"kind": "dozen", "n": 1}, {"kind": "column", "n": 3}, {"kind": "red"}, {"kind": "black"},
		{"kind": "even"}, {"kind": "odd"}, {"kind": "low"}, {"kind": "high"}]
	for b in bets:
		var total := 0
		for n in 37:
			var bb: Dictionary = b.duplicate()
			bb["amount"] = 37
			total += R.net(bb, n)
		check_eq(total, -37, "%s: over all 37 numbers a 37-unit bet loses exactly 37 (2.70%%)" % [b.kind])


func test_a_spin_reports_the_number_and_the_nets() -> void:
	var out := CasinoGames.Roulette.play([{"kind": "red", "amount": 10}, {"kind": "straight", "n": 7, "amount": 5}], _rng(3))
	check(out.n >= 0 and out.n <= 36 and out.colour in ["red", "black", "green"], "a number and its colour: %d %s" % [out.n, out.colour])
	var sum := 0
	for l in out.lines:
		sum += int(l[1])
	check_eq(out.net, sum, "the net is the sum of the lines")
	var seen := {}
	var r := _rng(11)
	for i in 3700:
		seen[CasinoGames.Roulette.spin(r)] = true
	check_eq(seen.size(), 37, "every number comes up")


# ------------------------------------------------------------------ blackjack
func _table(hands: Array) -> CasinoGames.Blackjack:
	var bj := CasinoGames.Blackjack.new(_rng())
	# the shoe is dealt from the back: player, dealer, player, dealer, then the hits
	var order := hands.duplicate()
	order.reverse()
	bj.shoe = bj.shoe.slice(0, 80) + order  # (the back of the array is dealt first)
	return bj


func test_blackjack_values_and_a_natural_pays_three_to_two() -> void:
	var B := CasinoGames.Blackjack
	check_eq(B.value([1, 13]), [21, true], "ace and king: 21")
	check_eq(B.value([1, 1, 9]), [21, true], "two aces and a nine: 21")
	check_eq(B.value([1, 6, 10]), [17, false], "ace, six, ten: 17 hard")
	check_eq(B.value([10, 10, 5]), [25, false], "bust")
	var bj := _table([1, 5, 13, 6])  # player A K, dealer 5 6
	check_eq(bj.deal(10), "", "dealt")
	check_eq(bj.result, "blackjack", "a natural")
	check_eq(bj.net, 15, "$15 on a $10 bet")
	var push := _table([1, 1, 13, 13])  # both naturals
	push.deal(10)
	check_eq(push.result, "push", "two naturals push")
	var dbj := _table([10, 1, 9, 13])  # dealer A K, player 10 9
	dbj.deal(20)
	check_eq(dbj.result, "dealer_blackjack", "the dealer looks under his ace")
	check_eq(dbj.net, -20, "and takes the bet")


func test_blackjack_hit_stand_double_and_the_dealer_stands_on_seventeen() -> void:
	var bj := _table([10, 10, 6, 7, 5])  # player 10 6, dealer 10 7: stand
	bj.deal(10)
	check_eq(bj.phase, "player", "play goes on")
	bj.stand()
	check_eq(bj.result, "lose", "16 against 17")
	check_eq(bj.net, -10, "lose the stake")
	var h := _table([10, 10, 6, 7, 5])
	h.deal(10)
	h.hit()  # draws the 5: 21
	check_eq(CasinoGames.Blackjack.value(h.player)[0], 21, "hit to 21")
	h.stand()
	check_eq(h.result, "win", "21 beats 17")
	var d := _table([5, 10, 6, 7, 10])  # player 5 6 (11), dealer 10 7: double, draws a ten -> 21
	d.deal(10)
	d.double()
	check(d.doubled and d.net == 20 and d.result == "win", "doubled and won: +$20 (%s %d)" % [d.result, d.net])
	var busted := _table([10, 5, 6, 6, 10])  # player 10 6, dealer 5 6, hit a ten: bust
	busted.deal(10)
	busted.hit()
	check(busted.result == "bust" and busted.net == -10, "bust loses the stake")
	var dealer_draws := _table([10, 5, 8, 6, 6, 10])  # dealer 5 6 draws 6 (17) and stands
	dealer_draws.deal(10)
	dealer_draws.stand()
	check_eq(CasinoGames.Blackjack.value(dealer_draws.dealer)[0], 17, "the dealer draws to 16 and stands on 17")
	check(dealer_draws.result == "win", "18 beats 17")
	check(d.hit() != "", "no more once it is done")
	check(bj.double() != "", "and no double after")
	var soft := _table([1, 10, 6, 7])  # player A 6 = soft 17, dealer 10 7 = 17
	soft.deal(10)
	check_eq(CasinoGames.Blackjack.value(soft.player), [17, true], "a soft 17")
	check_eq(soft.advice(), "hit", "basic strategy hits it")


func test_blackjack_with_basic_strategy_is_a_losing_game_but_a_close_one() -> void:
	var r := _rng(21)
	var bj := CasinoGames.Blackjack.new(r)
	var staked := 0
	var net := 0
	for i in 30000:
		bj.deal(10)
		var guard := 0
		while bj.phase == "player" and guard < 12:
			guard += 1
			match bj.advice():
				"hit":
					bj.hit()
				"double":
					bj.double()
				_:
					bj.stand()
		staked += 10 * (2 if bj.doubled else 1)
		net += bj.net
	var edge := float(net) / float(staked)
	check(edge > -0.035 and edge < 0.012, "the player's return per dollar staked: %.2f%%" % (edge * 100.0))


# ------------------------------------------------------------------ craps
func _roll_to_end(c: CasinoGames.Craps) -> Dictionary:
	var out := {}
	var guard := 0
	while guard < 200:
		guard += 1
		out = c.roll()
		if out.over:
			return out
	return out


func test_craps_pass_and_dont_pass_odds_and_the_bar_twelve() -> void:
	var c := CasinoGames.Craps.new(_rng())
	check(c.roll().has("error"), "no roll without a bet")
	check_eq(c.place("pass", 10), "", "a pass bet")
	check(c.place("dont", 10) != "", "not both")
	check(c.add_odds(10) != "", "no odds before a point")
	# fix the dice with a scripted RNG
	var s := ScriptedRng.new([4, 3])  # a seven on the come-out
	c.rng = s
	var out := c.roll()
	check(out.over and out.net == 10, "a natural: pass wins $10")
	check_eq(c.pass_bet, 0, "the bet is cleared")
	c.place("pass", 10)
	c.rng = ScriptedRng.new([1, 1])  # snake eyes
	out = c.roll()
	check(out.over and out.net == -10, "craps: pass loses")
	c.place("dont", 10)
	c.rng = ScriptedRng.new([6, 6])  # boxcars
	out = c.roll()
	check(out.over and out.net == 0, "the don't pass bars the twelve: a push")
	c.place("dont", 10)
	c.rng = ScriptedRng.new([1, 2])
	check_eq(c.roll().net, 10, "a three wins the don't pass")
	# a point of 6, odds, and the point made
	c.place("pass", 10)
	c.rng = ScriptedRng.new([3, 3, 3, 3, 4, 4, 6, 6])
	var first := c.roll()
	check(not first.over and c.point == 6, "the point is 6")
	check_eq(c.add_odds(30), "", "free odds behind it")
	check(c.add_odds(10) != "", "up to three times the line bet")
	var second := c.roll()  # 3 + 3 again: the point made
	check(second.over and second.net == 10 + 36, "the point made: pass $10 and 6:5 on $30 odds = $36 (%d)" % second.net)
	# seven out on a point of 10, don't with lay odds
	c.place("dont", 10)
	c.rng = ScriptedRng.new([5, 5, 3, 4])
	c.roll()
	check_eq(c.point, 10, "a point of 10")
	c.add_odds(20)
	var seven := c.roll()
	check(seven.over and seven.net == 10 + 10, "seven out: don't pass $10 and $10 on 1:2 lay odds of $20 (%d)" % seven.net)


class ScriptedRng extends PyRandom:
	var seq: Array = []

	func _init(s: Array) -> void:
		seq = s

	func randint(a: int, b: int) -> int:
		return int(seq.pop_front()) if not seq.is_empty() else a


func test_craps_pass_line_is_a_losing_bet_by_about_one_and_a_half_per_cent() -> void:
	for kind in ["pass", "dont"]:
		var c := CasinoGames.Craps.new(_rng(5 if kind == "pass" else 6))
		var net := 0
		var n := 60000
		for i in n:
			c.place(kind, 10)
			net += int(_roll_to_end(c).net)
		var edge := float(net) / float(n * 10)
		check(edge > -0.03 and edge < 0.0, "%s: the player's return per dollar: %.2f%%" % [kind, edge * 100.0])


# ------------------------------------------------------------------ baccarat
func _shoe(bc: CasinoGames.Baccarat, draws: Array) -> void:
	var order := draws.duplicate()
	order.reverse()
	bc.shoe = bc.shoe.slice(0, 60) + order


func test_baccarat_third_card_rules_and_the_commission() -> void:
	var bc := CasinoGames.Baccarat.new(_rng())
	check(bc.deal("x", 10).has("error"), "a bet on nothing is refused")
	check(bc.deal("player", 4).has("error"), "the table's limits")
	check_eq(CasinoGames.Baccarat.total([7, 8]), 5, "7 + 8 = 15: the five")
	check_eq(CasinoGames.Baccarat.total([0, 0]), 0, "tens and faces are nothing")
	# a natural: both stand
	_shoe(bc, [3, 2, 5, 0])  # player 3 5 = 8, banker 2 0 = 2
	var n := bc.deal("player", 100)
	check(n.player.size() == 2 and n.banker.size() == 2 and n.winner == "player", "a natural eight: nobody draws")
	check_eq(n.net, 100, "the player's bet pays even money")
	_shoe(bc, [3, 2, 5, 0])
	check_eq(bc.deal("banker", 100).net, -100, "a banker bet loses to it")
	# the player stands on 6 or 7, the banker draws on 0-5 then
	_shoe(bc, [6, 4, 0, 1, 9])  # player 6 stands; banker 4 + 1 = 5 draws a 9: 4
	var s := bc.deal("banker", 100)
	check(s.player.size() == 2 and s.banker.size() == 3 and s.player_total == 6 and s.banker_total == 4, "player on 6 stands, banker on 5 draws: %s" % [s])
	check_eq(s.winner, "player", "6 beats 4")
	# the banker stands on 3 when the player's third card is an 8
	_shoe(bc, [2, 3, 0, 0, 8])  # player 2 draws an 8 (0); banker 3 stands against an 8
	var st := bc.deal("banker", 100)
	check(st.player.size() == 3 and st.banker.size() == 2, "banker 3 does not draw against an 8: %s" % [st])
	check(st.winner == "banker" and st.net == 95, "banker wins 3 to 0 and pays 95 for 100 (the 5%% commission): %s" % [st.net])
	# the banker on 5 draws against a 6, and a tie pays 8 to 1 on a tie bet and pushes the others
	_shoe(bc, [2, 5, 0, 0, 6, 7])  # player 2+0+6 = 8, banker 5 draws a 7: 2
	var d := bc.deal("player", 100)
	check(d.player.size() == 3 and d.banker.size() == 3 and d.winner == "player", "banker 5 draws against a 6: %s" % [d])
	_shoe(bc, [4, 4, 4, 4, 0, 0])  # 8 v 8: a tie
	var tie := bc.deal("tie", 100)
	check(tie.winner == "tie" and tie.net == 800, "a tie pays 8 to 1")
	_shoe(bc, [4, 4, 4, 4, 0, 0])
	check_eq(bc.deal("banker", 100).net, 0, "and pushes a banker bet")


func test_baccarat_edges() -> void:
	for on in ["banker", "player", "tie"]:
		var bc := CasinoGames.Baccarat.new(_rng(31))
		var net := 0
		var n := 80000
		for i in n:
			net += int(bc.deal(on, 100).net)
		var edge := float(net) / float(n * 100)
		var lo: float = {"banker": -0.02, "player": -0.022, "tie": -0.175}[on]
		var hi: float = {"banker": 0.0, "player": 0.0, "tie": -0.115}[on]
		check(edge > lo and edge < hi, "%s: the player's return per dollar: %.2f%%" % [on, edge * 100.0])


# ------------------------------------------------------------------ slots
func test_the_slot_machine_returns_about_ninety_two_per_cent() -> void:
	var rtp := CasinoGames.Slots.rtp()
	check(rtp > 0.91 and rtp < 0.93, "the exact return over all 8,000 stops: %.2f%%" % (rtp * 100.0))
	check_eq(CasinoGames.Slots.pays("7", "7", "7"), 450, "three sevens")
	check_eq(CasinoGames.Slots.pays("C", "C", "C"), 13, "three cherries")
	check_eq(CasinoGames.Slots.pays("C", "C", "L"), 5, "two cherries")
	check_eq(CasinoGames.Slots.pays("C", "L", "B"), 2, "a cherry")
	check_eq(CasinoGames.Slots.pays("L", "C", "C"), 0, "cherries have to start on the first reel")
	var r := _rng(9)
	var net := 0
	var n := 40000
	for i in n:
		net += int(CasinoGames.Slots.pull(5, r).net)
	var edge := float(net) / float(n * 5)
	check(edge > -0.2 and edge < 0.05, "40,000 pulls: %.1f%% (it swings: the seven is 1 in 8,000)" % (edge * 100.0))
	check(CasinoGames.Slots.pull(2, r).has("error"), "the machine's limits")
	check_eq(CasinoGames.Slots.REEL.size(), 20, "twenty stops")
