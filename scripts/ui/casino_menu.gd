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
var stage: VBoxContainer  ## what is on the felt, as pictures (CasinoMenu.card_node and the rest)
var note := ""  ## the last refusal, until the next move


func _build() -> void:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UIStyle.box(Color(0.04, 0.26, 0.14, 0.96), 18, Color(0.75, 0.6, 0.25, 0.8), 3, Vector4(28, 22, 28, 22)))
	content.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	stage = VBoxContainer.new()  # the cards, dice, reels and the ball, drawn
	stage.add_theme_constant_override("separation", 8)
	v.add_child(stage)
	felt = UIStyle.label("", 22, Color(0.95, 0.95, 0.88), UIStyle.mono())
	felt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(felt)


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
	_fill_stage(play)
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


# ------------------------------------------------------------------ the pictures
const SUITS := ["♠", "♥", "♦", "♣"]
const RED_SUITS := [1, 2]


## The suit a card shows: the shoe deals ranks only, so the suit is dressed on (the same card in the same place is always the same suit).
static func suit_of(rank: int, place: int) -> int:
	return (rank * 3 + place * 5 + 1) % 4


## A playing card (a back when `down`).
static func card_node(rank: int, place: int, down := false, baccarat := false) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(66, 94)
	var suit := suit_of(rank, place)
	p.add_theme_stylebox_override("panel", UIStyle.box(Color(0.55, 0.1, 0.16) if down else Color(0.97, 0.95, 0.9), 7, Color(0.08, 0.08, 0.1, 0.9), 2, Vector4(6, 4, 6, 4)))
	p.set_meta("rank", rank if not down else -1)
	var face := "10" if (baccarat and rank == 0) else card(rank)  # baccarat deals the pip value: a nought is a ten, jack, queen or king
	var l := UIStyle.label("" if down else "%s\n%s" % [face, SUITS[suit]], 26, Color(0.78, 0.08, 0.1) if suit in RED_SUITS else Color(0.08, 0.08, 0.12))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## A die showing `n`.
static func die_node(n: int) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(72, 72)
	p.add_theme_stylebox_override("panel", UIStyle.box(Color(0.96, 0.95, 0.92), 12, Color(0.15, 0.1, 0.1), 2, Vector4(6, 4, 6, 4)))
	p.set_meta("die", n)
	var l := UIStyle.label(str(n), 42, Color(0.75, 0.05, 0.08))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## A slot reel stopped on `sym` (7, B bar, L lemon, P plum, O orange, M melon, C cherry, - blank).
static func reel_node(sym: String) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(104, 120)
	p.add_theme_stylebox_override("panel", UIStyle.box(Color(0.1, 0.06, 0.08), 10, Color(0.85, 0.7, 0.25), 3, Vector4(6, 4, 6, 4)))
	p.set_meta("sym", sym)
	var colours := {"7": Color(1.0, 0.2, 0.2), "B": Color(0.95, 0.95, 0.95), "L": Color(1.0, 0.9, 0.2), "P": Color(0.7, 0.35, 0.9), "O": Color(1.0, 0.6, 0.15), "M": Color(0.35, 0.85, 0.35), "C": Color(1.0, 0.25, 0.4), "-": Color(0.35, 0.35, 0.4)}
	var l := UIStyle.label(sym if sym != "-" else "·", 64, colours.get(sym, Color.WHITE))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## The roulette ball's pocket: a coloured disc with its number.
static func pocket_node(n: int, colour: String) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(84, 84)
	var bg := Color(0.1, 0.55, 0.2) if colour == "green" else (Color(0.78, 0.08, 0.1) if colour == "red" else Color(0.07, 0.07, 0.09))
	p.add_theme_stylebox_override("panel", UIStyle.box(bg, 42, Color(0.9, 0.8, 0.35), 3, Vector4(4, 4, 4, 4)))
	p.set_meta("pocket", n)
	var l := UIStyle.label(str(n), 36, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func _row(caption: String, nodes: Array, total := "") -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	var cap := UIStyle.label(caption, 18, Color(0.85, 0.85, 0.75))
	cap.custom_minimum_size = Vector2(110, 0)
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r.add_child(cap)
	for n in nodes:
		r.add_child(n)
	if total != "":
		var t := UIStyle.label(total, 22, Color(0.95, 0.9, 0.6))
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		r.add_child(t)
	stage.add_child(r)


## Draw what is on the felt (rebuilt on every refresh).
func _fill_stage(play: Dictionary) -> void:
	for ch in stage.get_children():
		stage.remove_child(ch)
		ch.queue_free()
	match game:
		"blackjack":
			if play.has("player"):
				var live := not bool(play.get("done", true))
				var dealer := []
				for i in play.dealer.size():
					dealer.append(card_node(int(play.dealer[i]), i))
				if live:
					dealer.append(card_node(1, 9, true))
				_row("DEALER", dealer, "" if live else str(CasinoGames.Blackjack.value(play.dealer)[0]))
				var mine := []
				for i in play.player.size():
					mine.append(card_node(int(play.player[i]), i + 5))
				var v: Array = CasinoGames.Blackjack.value(play.player)
				_row("YOU", mine, "%d%s" % [int(v[0]), " soft" if v[1] else ""])
		"baccarat":
			if play.has("player"):
				var pl := []
				for i in play.player.size():
					pl.append(card_node(int(play.player[i]), i, false, true))
				var bk := []
				for i in play.banker.size():
					bk.append(card_node(int(play.banker[i]), i + 4, false, true))
				_row("PLAYER", pl, str(CasinoGames.Baccarat.total(play.player)))
				_row("BANKER", bk, str(CasinoGames.Baccarat.total(play.banker)))
		"craps":
			if play.has("dice"):
				_row("DICE", [die_node(int(play.dice[0])), die_node(int(play.dice[1]))], str(int(play.dice[0]) + int(play.dice[1])))
		"roulette":
			if play.has("n"):
				_row("THE BALL", [pocket_node(int(play.n), str(play.colour))])
		"slots":
			var reels: Array = play.get("reels", ["-", "-", "-"])
			_row("", [reel_node(str(reels[0])), reel_node(str(reels[1])), reel_node(str(reels[2]))], ("pays %dx" % int(play.mult)) if int(play.get("mult", 0)) > 0 else "")


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
	return t


func _blackjack(play: Dictionary) -> String:
	var t := "Two decks, the dealer stands on every 17, blackjack pays 3 to 2, double on any two cards.\n\n"
	if play.is_empty():
		return t + "Place your stake and deal."
	var live := not bool(play.get("done", true))
	if live:
		t += "\nBasic strategy says: %s." % str(play.get("advice", ""))
	return t


func _craps(play: Dictionary) -> String:
	var cr = _casino().tables.get("craps")
	var t := "Pass and don't pass with free odds up to three times the line bet.\n\n"
	if cr == null:
		return t + "The stick is waiting for a line bet."
	t += "Pass $%d   Don't pass $%d   Odds $%d   Point: %s\n" % [cr.pass_bet, cr.dont_bet, cr.odds, str(cr.point) if cr.point != 0 else "off (come-out roll)"]
	return t


func _baccarat(play: Dictionary) -> String:
	var t := "Punto banco, eight decks.  Player pays 1, banker 0.95, tie 8.\n\n"
	t += "Your bet:  < %s >   $%s\n" % [SIDES[spot], Py.money(stake())]
	if not play.is_empty() and play.has("player"):
		t += "\nThe %s wins." % str(play.winner)
	return t


func _slots(play: Dictionary) -> String:
	var t := "Three reels, seven pays 450, bar 90, cherries pay too.   Return 91.9 %.\n\n"
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
