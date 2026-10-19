class_name CheatMenu
extends GameMenu
## Ctrl+F6, solo play only: the owner's test actions (Cheats). ENTER runs the highlighted row.

var list: DataTable


func _build() -> void:
	list = GameMenu.make_table([
		{"title": "Cheat", "expand": true, "ratio": 2, "min": 220},
		{"title": "What it does", "expand": true, "ratio": 3, "min": 280},
	])
	list.row_activated.connect(func(_i): key("enter"))
	content.add_child(list)


func refresh() -> void:
	title.text = "TEST MENU"
	subtitle.text = "$%s in hand   -   for testing; saves made with these are ordinary saves" % Py.money(s.money)
	var keep := list.selected_row()
	list.clear_rows()
	for a in Cheats.ACTIONS:
		list.add_row([a[1], a[2]])
	list.select_near(keep if keep >= 0 else 0)
	hints.set_hints([["UP/DOWN", "select", "down"], ["ENTER", "run it", "enter"], ["ESC", "close", "esc"]])


func key(k: String) -> void:
	match k:
		"up":
			list.move(-1)
		"down":
			list.move(1)
		"enter":
			var i := list.selected_row()
			if i >= 0 and i < Cheats.ACTIONS.size():
				show_feedback(Cheats.run(s, Cheats.ACTIONS[i][0]), true)
				refresh()
