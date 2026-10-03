class_name CasinoGames
extends RefCounted
## The Hotel Cielo's tables, with their real rules and their real odds: roulette (European, a single zero), blackjack (two decks,
## the dealer stands on every 17, blackjack pays 3 to 2, double down on any two cards), craps (the pass and don't-pass lines
## with free odds), baccarat (punto banco, eight decks, the banker's 5 % commission) and the one-armed bandits (three reels of
## twenty stops). Havana's casinos of the 1950s dealt these games, and the house edge on each is the one the real house had.
##
## Everything takes an RNG (a PyRandom) so a session replays. Nothing here touches money: each game says what the player's net is
## for a hand (a loss is minus the stake) and Casino.play settles it.
##
## House edge per unit staked (tests/test_casino_games.gd checks every one):
##   roulette 2.70 %   blackjack about 0.7 % (basic strategy)   craps pass 1.41 %, don't pass 1.36 %
##   baccarat banker 1.06 %, player 1.24 %, tie 14.4 %   slots 8.1 % (a return of 91.9 %)

const MIN_BET := 5
const MAX_BET := 500


# ================================================================== roulette
class Roulette:
	const RED := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
	const PAYS := {"straight": 35, "split": 17, "street": 11, "corner": 8, "line": 5, "dozen": 2, "column": 2, "red": 1, "black": 1, "even": 1, "odd": 1,
		"low": 1, "high": 1}

	static func spin(rng: PyRandom) -> int:
		return rng.randint(0, 36)

	## The numbers a bet covers, or an empty list for a bet that is not a real one at the table.
	static func covers(bet: Dictionary) -> Array:
		var out := []
		match str(bet.get("kind", "")):
			"straight":
				var n := int(bet.get("n", -1))
				if n >= 0 and n <= 36:
					out = [n]
			"split":
				var a := int(bet.get("a", -1))
				var b := int(bet.get("b", -1))
				if _adjacent(a, b):
					out = [a, b]
			"street":
				var r := int(bet.get("n", 0))
				if r >= 1 and r <= 12:
					out = [3 * r - 2, 3 * r - 1, 3 * r]
			"corner":
				var n := int(bet.get("n", 0))  # the top-left number of the 2 x 2 block: 1..32 not in the last column
				if n >= 1 and n <= 32 and n % 3 != 0:
					out = [n, n + 1, n + 3, n + 4]
			"line":
				var r := int(bet.get("n", 0))  # the first of two adjacent streets
				if r >= 1 and r <= 11:
					out = [3 * r - 2, 3 * r - 1, 3 * r, 3 * r + 1, 3 * r + 2, 3 * r + 3]
			"dozen":
				var d := int(bet.get("n", 0))
				if d >= 1 and d <= 3:
					for i in 12:
						out.append((d - 1) * 12 + i + 1)
			"column":
				var c := int(bet.get("n", 0))
				if c >= 1 and c <= 3:
					for i in 12:
						out.append(c + 3 * i)
			"red":
				out = RED.duplicate()
			"black":
				for n in range(1, 37):
					if not RED.has(n):
						out.append(n)
			"even":
				for n in range(2, 37, 2):
					out.append(n)
			"odd":
				for n in range(1, 37, 2):
					out.append(n)
			"low":
				out = range(1, 19)
			"high":
				out = range(19, 37)
		return out

	static func _adjacent(a: int, b: int) -> bool:
		if a < 0 or b < 0 or a > 36 or b > 36 or a == b:
			return false
		if a == 0 or b == 0:
			return maxi(a, b) <= 3
		var lo := mini(a, b)
		var hi := maxi(a, b)
		return hi - lo == 3 or (hi - lo == 1 and (lo - 1) / 3 == (hi - 1) / 3)

	## The player's net on one bet for the number that came up.
	static func net(bet: Dictionary, result: int) -> int:
		var amount := int(bet.get("amount", 0))
		if covers(bet).has(result):
			return amount * int(PAYS[str(bet.kind)])
		return -amount

	static func valid(bet: Dictionary) -> bool:
		return not covers(bet).is_empty() and int(bet.get("amount", 0)) >= MIN_BET and int(bet.get("amount", 0)) <= MAX_BET

	## Spin once for a list of bets: {n, colour, net, lines: [[bet, net]]}.
	static func play(bets: Array, rng: PyRandom) -> Dictionary:
		var n := spin(rng)
		var total := 0
		var lines := []
		for b in bets:
			var x := net(b, n)
			total += x
			lines.append([b, x])
		return {"n": n, "colour": "green" if n == 0 else ("red" if RED.has(n) else "black"), "net": total, "lines": lines}


# ================================================================== blackjack
class Blackjack:
	const DECKS := 2
	var rng: PyRandom
	var shoe: Array = []
	var player: Array = []
	var dealer: Array = []
	var bet := 0
	var phase := "idle"  ## idle | player | done
	var doubled := false
	var result := ""  ## blackjack | win | push | lose | bust | dealer_blackjack
	var net := 0

	func _init(rng_: PyRandom) -> void:
		rng = rng_
		_shuffle()

	func _shuffle() -> void:
		shoe = []
		for d in DECKS:
			for r in range(1, 14):
				for s in 4:
					shoe.append(r)
		rng.shuffle(shoe)

	func _draw() -> int:
		if shoe.size() < 12:
			_shuffle()
		return int(shoe.pop_back())

	## [best total, is soft] of a hand (aces are 1 or 11, face cards 10).
	static func value(hand: Array) -> Array:
		var t := 0
		var aces := 0
		for r in hand:
			t += mini(int(r), 10)
			if int(r) == 1:
				aces += 1
		var soft := false
		if aces > 0 and t + 10 <= 21:
			t += 10
			soft = true
		return [t, soft]

	static func is_blackjack(hand: Array) -> bool:
		return hand.size() == 2 and value(hand)[0] == 21

	func deal(amount: int) -> String:
		if phase == "player":
			return "A hand is in play."
		if amount < MIN_BET or amount > MAX_BET:
			return "The table takes $%d to $%d." % [MIN_BET, MAX_BET]
		bet = amount
		doubled = false
		result = ""
		net = 0
		if shoe.size() < 26:
			_shuffle()
		player = [_draw()]  # dealt round the table: player, dealer, player, dealer
		dealer = [_draw()]
		player.append(_draw())
		dealer.append(_draw())
		var up := mini(int(dealer[0]), 10)
		var pbj := is_blackjack(player)
		var dbj := is_blackjack(dealer) and (up == 10 or int(dealer[0]) == 1)  # the dealer looks under an ace or a ten
		if pbj or dbj:
			if pbj and dbj:
				_finish("push", 0)
			elif pbj:
				_finish("blackjack", floori(float(bet * 3) / 2.0))
			else:
				_finish("dealer_blackjack", -bet)
			return ""
		phase = "player"
		return ""

	func hit() -> String:
		if phase != "player":
			return "No hand in play."
		player.append(_draw())
		if value(player)[0] > 21:
			_finish("bust", -bet * (2 if doubled else 1))
		return ""

	func stand() -> String:
		if phase != "player":
			return "No hand in play."
		_dealer_plays()
		return ""

	func double() -> String:
		if phase != "player":
			return "No hand in play."
		if player.size() != 2:
			return "You can only double on your first two cards."
		doubled = true
		player.append(_draw())
		if value(player)[0] > 21:
			_finish("bust", -bet * 2)
		else:
			_dealer_plays()
		return ""

	func _dealer_plays() -> void:
		while value(dealer)[0] < 17:
			dealer.append(_draw())
		var p: int = value(player)[0]
		var d: int = value(dealer)[0]
		var stake := bet * (2 if doubled else 1)
		if d > 21 or p > d:
			_finish("win", stake)
		elif p == d:
			_finish("push", 0)
		else:
			_finish("lose", -stake)

	func _finish(res: String, n: int) -> void:
		phase = "done"
		result = res
		net = n

	## The basic strategy's move for the player's hand against the dealer's up card: "hit", "stand" or "double".
	func advice() -> String:
		var v := value(player)
		var t: int = v[0]
		var up := mini(int(dealer[0]), 10)
		if int(dealer[0]) == 1:
			up = 11
		var can_double := player.size() == 2
		if v[1]:  # a soft hand
			if t >= 19:
				return "stand"
			if t == 18:
				return "double" if (can_double and up >= 3 and up <= 6) else ("stand" if up <= 8 else "hit")
			if t >= 15 and can_double and up >= 4 and up <= 6:
				return "double"
			if t >= 13 and can_double and up >= 5 and up <= 6:
				return "double"
			return "hit"
		if t >= 17:
			return "stand"
		if t >= 13:
			return "stand" if up <= 6 else "hit"
		if t == 12:
			return "stand" if (up >= 4 and up <= 6) else "hit"
		if t == 11:
			return "double" if can_double else "hit"
		if t == 10:
			return "double" if (can_double and up <= 9) else "hit"
		if t == 9:
			return "double" if (can_double and up >= 3 and up <= 6) else "hit"
		return "hit"


# ================================================================== craps
class Craps:
	var rng: PyRandom
	var point := 0
	var pass_bet := 0
	var dont_bet := 0
	var odds := 0
	var rolls := 0
	var last := {}

	func _init(rng_: PyRandom) -> void:
		rng = rng_

	func place(kind: String, amount: int) -> String:
		if point != 0:
			return "The line bets are made on the come-out roll."
		if amount < MIN_BET or amount > MAX_BET:
			return "The table takes $%d to $%d." % [MIN_BET, MAX_BET]
		if kind == "pass":
			if dont_bet > 0:
				return "Pass or don't pass, not both."
			pass_bet += amount
		elif kind == "dont":
			if pass_bet > 0:
				return "Pass or don't pass, not both."
			dont_bet += amount
		else:
			return "Pass or don't pass."
		return ""

	## Free odds behind the line bet once there is a point: up to three times the line bet.
	func add_odds(amount: int) -> String:
		if point == 0:
			return "No point yet."
		var line := pass_bet + dont_bet
		if amount <= 0 or odds + amount > 3 * line:
			return "Odds are limited to three times the line bet ($%d)." % (3 * line)
		odds += amount
		return ""

	static func pass_odds_pays(point_: int, amount: int) -> int:
		match point_:
			4, 10:
				return amount * 2
			5, 9:
				return floori(float(amount * 3) / 2.0)
			_:
				return floori(float(amount * 6) / 5.0)

	static func dont_odds_pays(point_: int, amount: int) -> int:
		match point_:
			4, 10:
				return floori(float(amount) / 2.0)
			5, 9:
				return floori(float(amount * 2) / 3.0)
			_:
				return floori(float(amount * 5) / 6.0)

	## Roll the dice: {dice, total, point, net, over, text}. `over` is true when the line bet was settled.
	func roll() -> Dictionary:
		if pass_bet + dont_bet == 0:
			return {"error": "Make a line bet first."}
		var a := rng.randint(1, 6)
		var b := rng.randint(1, 6)
		var t := a + b
		rolls += 1
		var net := 0
		var over := false
		var text := ""
		if point == 0:
			if t == 7 or t == 11:
				net = pass_bet - dont_bet
				over = true
				text = "%d: a natural. Pass wins." % t
			elif t == 2 or t == 3 or t == 12:
				net = -pass_bet + (dont_bet if t != 12 else 0)
				over = true
				text = "%d: craps. %s" % [t, "Pass loses; don't pass wins." if t != 12 else "Pass loses; the bar 12 pushes the don't."]
			else:
				point = t
				text = "The point is %d." % t
		else:
			if t == point:
				net = pass_bet - dont_bet + pass_odds_pays(point, odds) * (1 if pass_bet > 0 else 0) - (odds if dont_bet > 0 else 0)
				over = true
				text = "%d: the point is made. Pass wins." % t
			elif t == 7:
				net = -pass_bet + dont_bet - (odds if pass_bet > 0 else 0) + dont_odds_pays(point, odds) * (1 if dont_bet > 0 else 0)
				over = true
				text = "Seven out. Pass loses; don't pass wins."
			else:
				text = "%d. Still on the %d." % [t, point]
		last = {"dice": [a, b], "total": t, "point": point, "net": net, "over": over, "text": text}
		if over:
			point = 0
			pass_bet = 0
			dont_bet = 0
			odds = 0
		return last


# ================================================================== baccarat
class Baccarat:
	const DECKS := 8
	var rng: PyRandom
	var shoe: Array = []

	func _init(rng_: PyRandom) -> void:
		rng = rng_
		_shuffle()

	func _shuffle() -> void:
		shoe = []
		for d in DECKS:
			for r in range(1, 14):
				for s in 4:
					shoe.append(mini(r, 10) % 10)  # an ace is 1 (rank 1 stays 1), the tens and faces are 0
		rng.shuffle(shoe)

	func _draw() -> int:
		if shoe.size() < 20:
			_shuffle()
		return int(shoe.pop_back())

	static func total(hand: Array) -> int:
		var t := 0
		for c in hand:
			t += int(c)
		return t % 10

	## Deal one coup. `on` is "player", "banker" or "tie". {player, banker, winner, net}
	func deal(on: String, amount: int) -> Dictionary:
		if not on in ["player", "banker", "tie"]:
			return {"error": "Bet on the player, the banker or a tie."}
		if amount < MIN_BET or amount > MAX_BET:
			return {"error": "The table takes $%d to $%d." % [MIN_BET, MAX_BET]}
		var p := [_draw()]  # player, banker, player, banker
		var b := [_draw()]
		p.append(_draw())
		b.append(_draw())
		var pt := total(p)
		var bt := total(b)
		if pt < 8 and bt < 8:  # no natural
			var p3 := -1
			if pt <= 5:
				p3 = _draw()
				p.append(p3)
			if p3 < 0:
				if bt <= 5:
					b.append(_draw())
			else:
				var draw := false
				match bt:
					0, 1, 2:
						draw = true
					3:
						draw = p3 != 8
					4:
						draw = p3 >= 2 and p3 <= 7
					5:
						draw = p3 >= 4 and p3 <= 7
					6:
						draw = p3 == 6 or p3 == 7
					_:
						draw = false
				if draw:
					b.append(_draw())
		pt = total(p)
		bt = total(b)
		var winner := "tie" if pt == bt else ("player" if pt > bt else "banker")
		var net := 0
		if winner == "tie":
			net = amount * 8 if on == "tie" else 0
		elif on == winner:
			net = amount if winner == "player" else floori(float(amount * 95) / 100.0)
		else:
			net = -amount
		return {"player": p, "banker": b, "player_total": pt, "banker_total": bt, "winner": winner, "net": net}


# ================================================================== slots
class Slots:
	## The reel: seven (7), bar (B), bell (L), plum (P), orange (O), lemon (M), cherry (C), blank (-).
	const REEL := ["7", "B", "B", "L", "L", "L", "P", "P", "P", "O", "O", "O", "M", "M", "M", "C", "C", "C", "-", "-"]
	const TRIPLE := {"7": 450, "B": 90, "L": 45, "P": 28, "O": 22, "M": 17, "C": 13}
	const CHERRY_FIRST := 2  ## a cherry on the first reel, alone
	const CHERRY_TWO := 5  ## cherries on the first two reels

	static func pays(a: String, b: String, c: String) -> int:
		if a == b and b == c and TRIPLE.has(a):
			return int(TRIPLE[a])
		if a == "C" and b == "C":
			return CHERRY_TWO
		if a == "C":
			return CHERRY_FIRST
		return 0

	## The return to the player over every one of the 8,000 stops, exactly.
	static func rtp() -> float:
		var t := 0
		for a in REEL:
			for b in REEL:
				for c in REEL:
					t += pays(a, b, c)
		return float(t) / float(REEL.size() * REEL.size() * REEL.size())

	static func pull(amount: int, rng: PyRandom) -> Dictionary:
		if amount < MIN_BET or amount > MAX_BET:
			return {"error": "The machine takes $%d to $%d." % [MIN_BET, MAX_BET]}
		var a: String = REEL[rng.randint(0, REEL.size() - 1)]
		var b: String = REEL[rng.randint(0, REEL.size() - 1)]
		var c: String = REEL[rng.randint(0, REEL.size() - 1)]
		var mult := pays(a, b, c)
		return {"reels": [a, b, c], "mult": mult, "net": amount * mult - amount}
