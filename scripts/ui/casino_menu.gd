class_name CasinoMenu
extends GameMenu
## A table at the Hotel Cielo, opened from the walker's E key at the roulette wheel, the blackjack, craps and baccarat tables and
## the slot banks (`game` says which). Every move is a `casino_play` command on the pilot's seat, so the rules, the odds and the
## money are Casino.play's and CasinoGames': this screen only picks the bet and shows the felt.
##
##   + / - or B   the stake ($5 to $500)         ENTER   the main move (bet, deal, roll, pull)
##   roulette     LEFT/RIGHT the bet, UP/DOWN the number on a straight, ENTER lays it, S spins, C clears
##   blackjack    ENTER deals, A hits, S stands, D doubles
##   craps        P the pass line, D don't pass, O free odds, ENTER or R rolls
##   baccarat     LEFT/RIGHT player / banker / tie, ENTER deals

const STAKES := [5, 10, 25, 50, 100, 250, 500]
const TITLES := {"roulette": "ROULETTE", "blackjack": "BLACKJACK", "craps": "CRAPS", "baccarat": "BACCARAT", "slots": "THE SLOTS"}
const SPOTS := [
	{"kind": "red", "name": "Red"}, {"kind": "black", "name": "Black"}, {"kind": "even", "name": "Even"}, {"kind": "odd", "name": "Odd"},
	{"kind": "low", "name": "1-18"}, {"kind": "high", "name": "19-36"},
	{"kind": "dozen", "n": 1, "name": "First dozen"}, {"kind": "dozen", "n": 2, "name": "Second dozen"}, {"kind": "dozen", "n": 3, "name": "Third dozen"},
	{"kind": "column", "n": 1, "name": "First column"}, {"kind": "column", "n": 2, "name": "Second column"}, {"kind": "column", "n": 3, "name": "Third column"},
	{"kind": "straight", "name": "Straight up"},
]
const SIDES := ["player", "banker", "tie"]

var game := "roulette"
var stake_i := 2
var spot := 0  ## roulette: index into SPOTS; baccarat: index into SIDES
var number := 17  ## the number a straight-up bet is on
var layout: Array = []  ## the roulette bets laid and not yet spun
var felt: Label
var note := ""  ## the last refusal, until the next move


func _build() -> void:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UIStyle.box(Color(0.04, 0.26, 0.14, 0.96), 18, Color(0.75, 0.6, 0.25, 0.8), 3, Vector4(28, 22, 28, 22)))
	content.add_child(panel)
	felt = UIStyle.label("", 22, Color(0.95, 0.95, 0.88), UIStyle.mono())
	felt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(felt)


## Sit down at `which` ("roulette", "blackjack", "craps", "baccarat" or "slots").
func sit(which: String) -> void:
	game = which
	spot = 0
	layout = []
	note = ""
	open()


func stake() -> int:
	return STAKES[stake_i]


func _casino() -> Casino:
	return s.casino


func refresh() -> void:
	title.text = TITLES.get(game, "THE TABLES")
	subtitle.text = "Hotel Cielo   -   $%s in hand   -   stake $%s   -   $%s to $%s" % [Py.money(s.money), Py.money(stake()), CasinoGames.MIN_BET, CasinoGames.MAX_BET]
	var c := _casino()
	var why := "There is no casino in this game." if c == null else c.at_tables()
	if why != "":
		felt.text = why
		footer.text = ""
		hints.set_hints([["ESC", "leave the table", "esc"]])
		return
	var play: Dictionary = c.last_play if str(c.last_play.get("game", "")) == game else {}
	match game:
		"roulette":
			felt.text = _roulette(play)
		"blackjack":
			felt.text = _blackjack(play)
		"craps":
			felt.text = _craps(play)
		"baccarat":
			felt.text = _baccarat(play)
		_:
			felt.text = _slots(play)
	var net: int = c.gamble_net
	footer.text = note if note != "" else str(play.get("text", "Place your bets."))
	if note == "" and net != 0:
		footer.text += "   -   %s $%s at the tables all told" % ["up" if net > 0 else "down", Py.money(absi(net))]
	hints.set_hints(_hints())


func _hints() -> Array:
	var out := [["+/-", "stake", "+"]]
	match game:
		"roulette":
			out += [["LEFT/RIGHT", "the bet", "right"], ["UP/DOWN", "the number", "up"], ["ENTER", "lay the bet", "enter"], ["S", "spin", "s"], ["C", "clear", "c"]]
		"blackjack":
			out += [["ENTER", "deal", "enter"], ["A", "hit", "a"], ["S", "stand", "s"], ["D", "double", "d"]]
		"craps":
			out += [["P", "pass line", "p"], ["D", "don't pass", "d"], ["O", "odds", "o"], ["ENTER", "roll", "enter"]]
		"baccarat":
			out += [["LEFT/RIGHT", "player / banker / tie", "right"], ["ENTER", "deal", "enter"]]
		_:
			out += [["ENTER", "pull the handle", "enter"]]
	out.append(["ESC", "leave the table", "esc"])
	return out


# ------------------------------------------------------------------ the felts
static func card(r: int) -> String:
	return {1: "A", 11: "J", 12: "Q", 13: "K"}.get(r, str(r))


static func hand(cards: Array) -> String:
	var out := []
	for r in cards:
		out.append(card(int(r)))
	return " ".join(out)


func _spot_name() -> String:
	var sp: Dictionary = SPOTS[spot]
	return "%d straight up" % number if sp.kind == "straight" else str(sp.name)


func _roulette(play: Dictionary) -> String:
	var t := "European wheel, one zero.   Pays: straight 35, dozen and column 2, even money 1.\n\n"
	t += "The bet:  < %s >   $%s\n" % [_spot_name(), Py.money(stake())]
	if layout.is_empty():
		t += "On the layout: nothing yet.\n"
	else:
		var total := 0
		var names := []
		for b in layout:
			total += int(b.amount)
			names.append("%s $%d" % [str(b.name), int(b.amount)])
		t += "On the layout: %s   (total $%s)\n" % [", ".join(names), Py.money(total)]
	if not play.is_empty():
		t += "\nThe ball: %d %s." % [int(play.n), str(play.colour)]
	return t


func _blackjack(play: Dictionary) -> String:
	var t := "Two decks, the dealer stands on every 17, blackjack pays 3 to 2, double on any two cards.\n\n"
	if play.is_empty():
		return t + "Place your stake and deal."
	var live := not bool(play.get("done", true))
	t += "Dealer:  %s%s\n" % [hand(play.dealer), "  ?" if live else "  (%d)" % CasinoGames.Blackjack.value(play.dealer)[0]]
	t += "You:      %s  (%d%s)\n" % [hand(play.player), CasinoGames.Blackjack.value(play.player)[0], " soft" if CasinoGames.Blackjack.value(play.player)[1] else ""]
	if live:
		t += "\nBasic strategy says: %s." % str(play.get("advice", ""))
	return t


func _craps(play: Dictionary) -> String:
	var cr = _casino().tables.get("craps")
	var t := "Pass and don't pass with free odds up to three times the line bet.\n\n"
	if cr == null:
		return t + "The stick is waiting for a line bet."
	t += "Pass $%d   Don't pass $%d   Odds $%d   Point: %s\n" % [cr.pass_bet, cr.dont_bet, cr.odds, str(cr.point) if cr.point != 0 else "off (come-out roll)"]
	if play.has("dice"):
		t += "\nThe dice: %s." % " and ".join(PackedStringArray(play.dice.map(func(d): return str(d))))
	return t


func _baccarat(play: Dictionary) -> String:
	var t := "Punto banco, eight decks.  Player pays 1, banker 0.95, tie 8.\n\n"
	t += "Your bet:  < %s >   $%s\n" % [SIDES[spot], Py.money(stake())]
	if not play.is_empty() and play.has("player"):
		t += "\nPlayer: %s  (%d)\nBanker: %s  (%d)\nThe %s wins." % [hand(play.player), CasinoGames.Baccarat.total(play.player), hand(play.banker), CasinoGames.Baccarat.total(play.banker), str(play.winner)]
	return t


func _slots(play: Dictionary) -> String:
	var t := "Three reels, seven pays 450, bar 90, cherries pay too.   Return 91.9 %.\n\n"
	if play.has("reels"):
		t += "     [ %s ]   [ %s ]   [ %s ]" % [str(play.reels[0]), str(play.reels[1]), str(play.reels[2])]
		if int(play.mult) > 0:
			t += "      pays %dx" % int(play.mult)
	else:
		t += "     [ - ]   [ - ]   [ - ]"
	return t


# ------------------------------------------------------------------ keys
func key(k: String) -> void:
	match k:
		"+", "b":
			stake_i = (stake_i + 1) % STAKES.size() if k == "b" else mini(stake_i + 1, STAKES.size() - 1)
			note = ""
			refresh()
			return
		"-":
			stake_i = maxi(stake_i - 1, 0)
			note = ""
			refresh()
			return
		"left", "right":
			var n := SPOTS.size() if game == "roulette" else SIDES.size()
			if game in ["roulette", "baccarat"]:
				spot = posmod(spot + (1 if k == "right" else -1), n)
				refresh()
			return
		"up", "down":
			if game == "roulette":
				number = posmod(number + (1 if k == "up" else -1), 37)
				spot = SPOTS.size() - 1
				refresh()
			return
	if _casino() == null:
		return
	var a := {}
	match game:
		"roulette":
			match k:
				"enter":
					var sp: Dictionary = SPOTS[spot].duplicate()
					sp["amount"] = stake()
					if sp.kind == "straight":
						sp["n"] = number
						sp["name"] = "%d" % number
					layout.append(sp)
					note = ""
					refresh()
				"c":
					layout = []
					note = ""
					refresh()
				"s":
					a = {"game": "roulette", "bets": layout}
		"blackjack":
			var lp: Dictionary = _casino().last_play if str(_casino().last_play.get("game", "")) == "blackjack" else {}
			var live := not lp.is_empty() and not bool(lp.get("done", true))
			match k:
				"enter":
					if not live:
						a = {"game": "blackjack", "do": "deal", "amount": stake()}
				"a":
					a = {"game": "blackjack", "do": "hit"}
				"s":
					a = {"game": "blackjack", "do": "stand"}
				"d":
					a = {"game": "blackjack", "do": "double"}
		"craps":
			match k:
				"p":
					a = {"game": "craps", "do": "pass", "amount": stake()}
				"d":
					a = {"game": "craps", "do": "dont", "amount": stake()}
				"o":
					a = {"game": "craps", "do": "odds", "amount": stake()}
				"enter", "r":
					a = {"game": "craps", "do": "roll"}
		"baccarat":
			if k == "enter":
				a = {"game": "baccarat", "on": SIDES[spot], "amount": stake()}
		_:
			if k == "enter":
				a = {"game": "slots", "amount": stake()}
	if a.is_empty():
		return
	var r: Array = s.command(Roles.PILOT, "casino_play", a)
	note = "" if r[0] else str(r[1])
	if r[0] and game == "roulette":
		layout = []
	refresh()
