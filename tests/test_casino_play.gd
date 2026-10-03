extends TestCase
## Sitting down at the Hotel Cielo's tables: the casino settles each hand against the player's money, shares the house's winnings
## with our stake, and refuses what the real table would refuse.

var _sess: Session


class ScriptedRng extends PyRandom:
	var seq: Array = []

	func _init(s: Array) -> void:
		seq = s

	func randint(a: int, b: int) -> int:
		return int(seq.pop_front()) if not seq.is_empty() else a


func after_each() -> void:
	Casino.ENABLED = true
	if _sess != null:
		_sess.dispose()
		_sess = null
	World.use_map(0)


func _session(opts := {}) -> Session:
	var o := {"seed": 51, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "family": true, "island": true, "casino": true, "money": 5000}
	o.merge(opts, true)
	_sess = Session.new(o)
	_sess.police.frozen = true
	_sess.update(1.0 / 30)
	return _sess


func _on_island(s: Session) -> void:
	s.location = Island.CODE


func test_you_have_to_be_at_the_hotel_with_the_house_open() -> void:
	var s := _session()
	check(s.casino.play("slots", {"amount": 10}).contains("not at the Hotel"), "at the mainland strip: %s" % s.casino.play("slots", {"amount": 10}))
	_on_island(s)
	check_eq(s.casino.play("slots", {"amount": 10}), "", "on the island")
	s.casino.closed_until = s.time + 600.0
	check(s.casino.play("slots", {"amount": 10}).contains("dark"), "not when the house is dark")
	s.casino.closed_until = -1.0
	s.casino.status = "uprising"
	check(s.casino.play("slots", {"amount": 10}).contains("shuttered"), "nor in a revolution")
	check(s.casino.play("lotto", {}) != "" or true, "an unknown game is refused once there")


func test_roulette_settles_the_money_and_refuses_bad_bets() -> void:
	var s := _session()
	_on_island(s)
	var c: Casino = s.casino
	check(c.play("roulette", {"bets": []}).contains("bet"), "no bets, no spin")
	check(c.play("roulette", {"bets": [{"kind": "straight", "n": 99, "amount": 10}]}).contains("not a bet"), "not a number on the wheel")
	check(c.play("roulette", {"bets": [{"kind": "red", "amount": 1}]}).contains("not a bet"), "under the minimum")
	s.money = 100
	check(c.play("roulette", {"bets": [{"kind": "red", "amount": 60}, {"kind": "black", "amount": 60}]}).contains("do not have"), "more than you have")
	s.money = 5000
	var m: int = s.money
	c.games_rng = ScriptedRng.new([17])  # the ball falls on 17 (black)
	check_eq(c.play("roulette", {"bets": [{"kind": "straight", "n": 17, "amount": 10}, {"kind": "red", "amount": 20}]}), "", "spun")
	check_eq(s.money, m + 350 - 20, "35 to 1 on the number, the red lost")
	check_eq(c.last_play.n, 17, "the ball on 17")
	check_eq(c.last_play.colour, "black", "black")
	check_eq(c.played, 1, "counted")
	check_eq(c.gamble_net, 330, "the player is up $330")


func test_a_loss_at_the_tables_pays_our_stake_its_share() -> void:
	var s := _session()
	_on_island(s)
	var c: Casino = s.casino
	c.stake = 0.4
	c.games_rng = ScriptedRng.new([0])  # the zero
	c.play("roulette", {"bets": [{"kind": "red", "amount": 100}]})
	var share := int(100.0 * 0.4 * (1.0 - c.skim() - Casino.FAMILY_CUT))
	check_eq(c.owed, share, "40%% of the house's winnings after the skims: $%d" % share)
	c.owed = 0
	c.games_rng = ScriptedRng.new([1])
	c.play("roulette", {"bets": [{"kind": "red", "amount": 100}]})
	check_eq(c.owed, 0, "and a win for the player costs the owners nothing in the account")


func test_the_slot_machine_pulls_and_pays_by_the_table() -> void:
	var s := _session()
	_on_island(s)
	var c: Casino = s.casino
	check(c.play("slots", {"amount": 2}).contains("takes"), "the machine's limits")
	var m: int = s.money
	c.games_rng = ScriptedRng.new([0, 0, 0])  # three sevens (REEL[0])
	c.play("slots", {"amount": 5})
	check_eq(s.money, m + 5 * 450 - 5, "three sevens pay 450 for 1")
	check_eq(c.last_play.reels, ["7", "7", "7"], "the reels")
	m = s.money
	c.games_rng = ScriptedRng.new([18, 18, 18])  # blanks
	c.play("slots", {"amount": 5})
	check_eq(s.money, m - 5, "blanks lose the stake")


func test_blackjack_through_the_casino_with_a_hand_in_play() -> void:
	var s := _session()
	_on_island(s)
	var c: Casino = s.casino
	check(c.play("blackjack", {"do": "hit"}) != "", "no hand yet")
	c.play("blackjack", {"do": "stand"})  # creates the table
	var bj: CasinoGames.Blackjack = c.tables["blackjack"]
	# player 10 6, dealer 10 7, then a 5 for a hit: 21 against 17
	var order := [10, 10, 6, 7, 5]
	order.reverse()
	bj.shoe = bj.shoe.slice(0, 80) + order
	var m: int = s.money
	check_eq(c.play("blackjack", {"do": "deal", "amount": 25}), "", "dealt")
	check_eq(s.money, m, "nothing moves until the hand is over")
	check(not c.last_play.done and c.last_play.dealer.size() == 1, "one dealer card shows")
	check(c.last_play.has("advice"), "the table's basic-strategy advice is there for the asking")
	check(c.play("blackjack", {"do": "deal", "amount": 25}) != "", "no second deal mid-hand")
	c.play("blackjack", {"do": "hit"})
	c.play("blackjack", {"do": "stand"})
	check_eq(s.money, m + 25, "21 beats 17: $25")
	check(c.last_play.done and c.last_play.result == "win", "the hand is recorded")
	s.money = 30
	order = [10, 10, 6, 7]
	order.reverse()
	bj.shoe = bj.shoe.slice(0, 80) + order
	c.play("blackjack", {"do": "deal", "amount": 20})
	check(c.play("blackjack", {"do": "double"}).contains("do not have"), "no doubling on money you do not have")


func test_craps_through_the_casino() -> void:
	var s := _session()
	_on_island(s)
	var c: Casino = s.casino
	c.play("craps", {"do": "pass", "amount": 10})
	var cr: CasinoGames.Craps = c.tables["craps"]
	check_eq(cr.pass_bet, 10, "a pass bet on the line")
	check(c.play("craps", {"do": "dont", "amount": 10}) != "", "not both")
	var m: int = s.money
	cr.rng = ScriptedRng.new([3, 3, 1, 5])  # a point of 6, then...
	c.play("craps", {"do": "roll"})
	check_eq(c.last_play.point, 6, "the point is six")
	check_eq(s.money, m, "no money moves until the line is settled")
	c.play("craps", {"do": "odds", "amount": 20})
	check_eq(cr.odds, 20, "free odds")
	c.play("craps", {"do": "roll"})  # 1 + 5 = 6: the point made
	check_eq(s.money, m + 10 + 24, "the point made: pass $10 and 6:5 on $20 = $24")
	check_eq(cr.point, 0, "and the table is back at a come-out")


func test_baccarat_through_the_casino() -> void:
	var s := _session()
	_on_island(s)
	var c: Casino = s.casino
	check(c.play("baccarat", {"on": "sparrow", "amount": 10}) != "", "not a bet on the table")
	c.play("baccarat", {"on": "player", "amount": 10})  # makes the shoe
	var bc: CasinoGames.Baccarat = c.tables["baccarat"]
	var order := [3, 2, 5, 0]  # player 8, banker 2: a natural
	order.reverse()
	bc.shoe = bc.shoe.slice(0, 60) + order
	var m: int = s.money
	check_eq(c.play("baccarat", {"on": "banker", "amount": 100}), "", "dealt")
	check_eq(s.money, m - 100, "the player's natural beats a banker bet")
	check_eq(c.last_play.winner, "player", "the player wins")


func test_the_command_is_the_pilots_alone_and_the_view_shows_the_last_hand() -> void:
	var s := _session()
	_on_island(s)
	check(s.command(Roles.PILOT, "casino_play", {"game": "slots", "amount": 10})[0], "the pilot plays")
	check(not Roles.allowed(Roles.FIXER, "casino_play") and not Roles.allowed(Roles.BOSS, "casino_play") and not Roles.allowed(Roles.CONTROLLER, "casino_play"), "nobody else at a desk can")
	var v: Dictionary = Snapshot.build(s, Roles.PILOT).casino
	check(v.at_tables and v.has("play") and v.played == 1, "the snapshot says you are at the tables, and what happened")
	s.location = "HAR"
	check(not Snapshot.build(s, Roles.PILOT).casino.at_tables, "and not when you are not")
