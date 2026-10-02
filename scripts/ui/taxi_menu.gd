class_name TaxiMenu
extends GameMenu
## The taxi (from the phone, on foot): a ride to somewhere the player would otherwise walk - the
## aircraft, the boss's desk, the job board, the hangar, a stash house. The pilot app owns the list
## (`stops_fn`: dictionaries with name, dist, fare, secs) and the ride; this picks one and emits
## `chosen(index)`.

signal chosen(index: int)

var list: DataTable
var stops_fn: Callable = func() -> Array: return []
var rows: Array = []


func _build() -> void:
	list = GameMenu.make_table([
		{"title": "Take me to", "expand": true, "ratio": 3, "min": 240},
		{"title": "Distance", "align": "right", "mono": true, "min": 100},
		{"title": "Ride", "align": "right", "mono": true, "min": 90},
		{"title": "Fare", "align": "right", "mono": true, "min": 90},
	])
	list.row_activated.connect(func(_i): key("enter"))
	content.add_child(list)


func refresh() -> void:
	title.text = "TAXI"
	subtitle.text = "$%s in hand" % Py.money(s.money)
	var keep := list.selected_row()
	list.clear_rows()
	rows = stops_fn.call()
	for r in rows:
		list.add_row([r.name, "%.1f km" % (float(r.dist) / 1000.0), "%d min" % maxi(1, int(round(float(r.secs) / 60.0))), "$%d" % int(r.fare)])
	if not rows.is_empty():
		list.select_near(keep if keep >= 0 else 0)
	footer.text = "" if not rows.is_empty() else "Nowhere to go."
	hints.set_hints([["UP/DOWN", "select", "down"], ["ENTER", "go", "enter"], ["ESC", "never mind", "esc"]])


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
			close()
			chosen.emit(i)
