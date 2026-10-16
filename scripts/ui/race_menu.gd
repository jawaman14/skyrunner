class_name RaceMenu
extends GameMenu
## The track (from the phone): the races at this airfield - the street race in the car, the air circuit - with the
## length, the par time, the entry, the prize and when it pays again. ENTER enters the highlighted one.

var list: DataTable
var rows: Array = []
var bet_i := 0  ## index into Races.BET_STEPS
var on := "win"  ## what the bet is on: "win" or "place"


func _build() -> void:
	list = GameMenu.make_table([
		{"title": "Race", "expand": true, "ratio": 3, "min": 220},
		{"title": "Length", "align": "right", "mono": true, "min": 80},
		{"title": "Par", "align": "right", "mono": true, "min": 70},
		{"title": "Entry", "align": "right", "mono": true, "min": 80},
		{"title": "Prize", "align": "right", "mono": true, "min": 80},
		{"title": "Pays again", "align": "right", "mono": true, "min": 100},
	])
	list.row_activated.connect(func(_i): key("enter"))
	content.add_child(list)


func refresh() -> void:
	title.text = "THE TRACK"
	var v: Dictionary = s.races.view() if s.races != null else {}
	var won: int = int(v.get("won", 0))
	var book := int(v.get("betting", 0))
	subtitle.text = "$%s in hand   -   $%s won in the arena   -   the book %s$%s" % [Py.money(s.money), Py.money(won), "+" if book >= 0 else "-", Py.money(absi(book))]
	var keep := list.selected_row()
	var keep_id := str(rows[keep].id) if keep >= 0 and keep < rows.size() else ""
	list.clear_rows()
	rows = v.get("courses", [])
	for r in rows:
		var cool: float = float(r.cooldown)
		list.add_row([("%s (%s)" % [r.name, "car" if r.kind == "car" else "aircraft"]), "%.1f km" % (float(r.length) / 1000.0), _clock(float(r.par)), "$%s" % Py.money(int(r.fee)),
			"$%s" % Py.money(int(r.prize)), "now" if cool <= 0.0 else "%d min" % int(ceil(cool / 60.0))])
	if not rows.is_empty():
		for i in rows.size():
			if str(rows[i].id) == keep_id:
				keep = i
				break
		list.select_near(keep if keep >= 0 else 0)
	var last: Array = v.get("results", [])
	footer.text = "No races run yet. Drive or fly through the gates in order; first takes the prize, second half, third a quarter." if last.is_empty() else "Last: %s, place %d, %s%s" % [
		str(last[last.size() - 1].name), int(last[last.size() - 1].place), _clock(float(last[last.size() - 1].time)), (", $%s" % Py.money(int(last[last.size() - 1].prize))) if int(last[last.size() - 1].prize) > 0 else ""]
	var stake: int = Races.BET_STEPS[bet_i]
	var line := "bet: none" if stake == 0 else "bet $%s on a %s (pays %sx)" % [Py.money(stake), on, str(Races.BET_ODDS[on]).trim_suffix(".0")]
	footer.text += "   -   " + line
	hints.set_hints([["UP/DOWN", "select", "down"], ["ENTER", "enter the race", "enter"], ["B", "stake: $0 / 100 / 200 / 300", "b"], ["N", "win or place", "n"], ["ESC", "back", "esc"]])


static func _clock(t: float) -> String:
	return "%d:%02d" % [int(t / 60.0), int(fmod(t, 60.0))]


func key(k: String) -> void:
	match k:
		"up":
			list.move(-1)
		"down":
			list.move(1)
		"b":
			bet_i = (bet_i + 1) % Races.BET_STEPS.size()
			refresh()
		"n":
			on = "place" if on == "win" else "win"
			refresh()
		"enter":
			var i := list.selected_row()
			if i < 0 or i >= rows.size():
				return
			var r: Array = s.command(Roles.PILOT, "race_enter", {"id": rows[i].id, "bet": Races.BET_STEPS[bet_i], "on": on})
			if not r[0]:
				show_feedback(str(r[1]), false)
				s.say(str(r[1]))
			else:
				close()
