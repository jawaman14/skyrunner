class_name RacketsMenu
extends GameMenu
## The collectors (from the phone): what each market pays us in tribute and on what terms (ENTER cycles fair /
## squeeze / off), and the prisoners we are holding (A ransom them, F put them on the payroll, G let them go).

var list: DataTable
var markets: Array = []


func _build() -> void:
	list = GameMenu.make_table([
		{"title": "Market", "expand": true, "ratio": 2, "min": 140},
		{"title": "Our hold", "align": "right", "mono": true, "min": 100},
		{"title": "Terms", "min": 110},
		{"title": "Next round", "align": "right", "mono": true, "min": 110},
	])
	list.row_activated.connect(func(_i): key("enter"))
	content.add_child(list)


func refresh() -> void:
	title.text = "THE COLLECTORS"
	var v: Dictionary = s.rackets.view() if s.rackets != null else {}
	subtitle.text = "$%s in hand   -   %d prisoners held   -   next round in %d min" % [Py.money(s.money), int(v.get("held", 0)), int(float(v.get("next_round", 0.0)) / 60.0)]
	var keep := list.selected_row()
	list.clear_rows()
	markets = v.get("markets", [])
	for m in markets:
		var share: float = float(m.share)
		list.add_row([str(m.market).capitalize(), "-" if share < 0.0 else "%d%%" % int(share * 100.0), str(m.policy), "$%s" % Py.money(int(m.expected))])
	if not markets.is_empty():
		list.select_near(keep if keep >= 0 else 0)
	footer.text = "Tribute so far $%s; ransoms $%s. Over half the street to be paid by it. Squeezing pays 2x and the street resents it." % [Py.money(int(v.get("collected", 0))), Py.money(int(v.get("ransom_cash", 0)))]
	hints.set_hints([["UP/DOWN", "select", "down"], ["ENTER", "terms", "enter"], ["A", "ransom them", "a"], ["F", "put them on the payroll", "f"], ["G", "let them go", "g"], ["ESC", "back", "esc"]])


func _go(what: String, extra := {}) -> void:
	var a := {"what": what}
	a.merge(extra)
	var r: Array = s.command(Roles.PILOT, "rackets", a)
	if not r[0]:
		s.say(str(r[1]))
	refresh()


func key(k: String) -> void:
	match k:
		"up":
			list.move(-1)
		"down":
			list.move(1)
		"enter":
			var i := list.selected_row()
			if i >= 0 and i < markets.size():
				var cur: String = markets[i].policy
				var nxt: String = Rackets.POLICIES[(Rackets.POLICIES.find(cur) + 1) % Rackets.POLICIES.size()]
				_go("policy", {"market": markets[i].market, "mode": nxt})
		"a":
			_go("ransom")
		"f":
			_go("turn")
		"g":
			_go("release")
