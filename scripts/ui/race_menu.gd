class_name RaceMenu
extends GameMenu
## The track (from the phone): the races at this airfield - the street race in the car, the air circuit - with the
## length, the par time, the entry, the prize and when it pays again. ENTER enters the highlighted one.

var list: DataTable
var rows: Array = []


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
	subtitle.text = "$%s in hand   -   $%s won in the arena" % [Py.money(s.money), Py.money(won)]
	var keep := list.selected_row()
	list.clear_rows()
	rows = v.get("courses", [])
	for r in rows:
		var cool: float = float(r.cooldown)
		list.add_row([("%s (%s)" % [r.name, "car" if r.kind == "car" else "aircraft"]), "%.1f km" % (float(r.length) / 1000.0), _clock(float(r.par)), "$%s" % Py.money(int(r.fee)),
			"$%s" % Py.money(int(r.prize)), "now" if cool <= 0.0 else "%d min" % int(ceil(cool / 60.0))])
	if not rows.is_empty():
		list.select_near(keep if keep >= 0 else 0)
	var last: Array = v.get("results", [])
	footer.text = "No races run yet. Drive or fly through the gates in order; first takes the prize, second half, third a quarter." if last.is_empty() else "Last: %s, place %d, %s%s" % [
		str(last[last.size() - 1].name), int(last[last.size() - 1].place), _clock(float(last[last.size() - 1].time)), (", $%s" % Py.money(int(last[last.size() - 1].prize))) if int(last[last.size() - 1].prize) > 0 else ""]
	hints.set_hints([["UP/DOWN", "select", "down"], ["ENTER", "enter the race", "enter"], ["ESC", "back", "esc"]])


static func _clock(t: float) -> String:
	return "%d:%02d" % [int(t / 60.0), int(fmod(t, 60.0))]


func key(k: String) -> void:
	match k:
		"up":
			list.move(-1)
		"down":
			list.move(1)
		"enter":
			var i := list.selected_row()
			if i < 0 or i >= rows.size():
				return
			var r: Array = s.command(Roles.PILOT, "race_enter", {"id": rows[i].id})
			if not r[0]:
				s.say(str(r[1]))
			else:
				close()
