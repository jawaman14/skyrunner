class_name PhoneMenu
extends GameMenu
## The phone, on foot (T): ring the people who otherwise need a walk to the desk or a landing at
## the right strip - Manny's hiring hall, the buyers, the lawyer, the Family, the General's aide -
## or open the boss's orders and the logistics view. Picking one closes the phone and emits
## `called(action)`; the pilot app does the rest, the same call the shortcut keys make.

signal called(action: String)

var list: DataTable
var rows: Array = []  ## [action, who, about]


func _build() -> void:
	list = GameMenu.make_table([
		{"title": "Who", "expand": true, "ratio": 2, "min": 220},
		{"title": "About", "expand": true, "ratio": 3, "min": 260},
	])
	list.row_activated.connect(func(_i): key("enter"))
	content.add_child(list)


## Who is on the phone book this game: only the systems that are switched on.
func contacts() -> Array:
	var out := []
	if s.payroll != null:
		out.append(["crew", "Manny Ortega", "the hiring hall: pilots, mules, dealers, soldiers"])
	if s.trade != null:
		out.append(["buyers", "Benny Ruiz", "who's buying, and at what"])
	if s.court != null:
		out.append(["lawyer", "Your lawyer", "bail, motions, the plea, a deal, the appeal"])
	if s.family != null:
		out.append(["family", Talk.CAPO, "a sit-down with the Family"])
	if s.island != null:
		out.append(["general", "The General's aide", "the island frequency"])
	if s.nights != null or s.ground != null:
		out.append(["desk", "The desk", "the boss's orders (and the squads, if there's a war on)"])
	if s.rackets != null:
		out.append(["rackets", "The collectors", "what the streets we hold pay, and the prisoners"])
	if s.logistics != null:
		out.append(["logistics", "Dispatch", "where the product and the cash are; trucks; cash bags"])
	out.append(["taxi", "A taxi", "a ride to the aircraft, the desk, the job board, a stash house"])
	return out


func refresh() -> void:
	title.text = "PHONE"
	subtitle.text = "$%s in hand" % Py.money(s.money)
	if s.renown != null:
		var nx: float = s.renown.next_at()
		subtitle.text += "   -   renown: %s (%d%s)" % [s.renown.title(), int(s.renown.score), ("/%d" % int(nx)) if nx > 0.0 else ""]
	var keep := list.selected_row()
	list.clear_rows()
	rows = contacts()
	for r in rows:
		list.add_row([r[1], r[2]])
	if not rows.is_empty():
		list.select_near(keep if keep >= 0 else 0)
	footer.text = "" if not rows.is_empty() else "Nobody to call yet."
	hints.set_hints([["UP/DOWN", "select", "down"], ["ENTER", "call", "enter"], ["ESC", "hang up", "esc"]])


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
			var action: String = rows[i][0]
			close()
			called.emit(action)
