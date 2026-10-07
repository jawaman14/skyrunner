class_name PhoneMenu
extends GameMenu
## The phone (T on foot, Shift+T from the cockpit): ring the people who otherwise need a walk to the desk or a landing at
## the right strip - Manny's hiring hall, the buyers, the lawyer, the Family, the General's aide -
## or open the boss's orders and the logistics view. The book is only the people you have: each system that
## opens (a story chapter, a Family offer taken) adds its number, announced and marked NEW until you ring it. Picking one closes the phone and emits
## `called(action)`; the pilot app does the rest, the same call the shortcut keys make.

signal called(action: String)

var list: DataTable
var rows: Array = []  ## [action, who, about]
var fresh := {}  ## numbers added since you last rang them (PilotApp._phone_watch): marked NEW
var _call_ids: Array = []
var history_label: Label
var campaign_scroll: ScrollContainer
var campaign_text: Label
var campaign_button: Button


func _build() -> void:
	campaign_button = Button.new()
	campaign_button.text = "Chapter guidance and history"
	campaign_button.visible = s.story != null
	campaign_button.pressed.connect(func():
		campaign_scroll.visible = not campaign_scroll.visible
		if campaign_scroll.visible:
			campaign_button.grab_focus()
		else:
			list.grab_focus()
		list.visible = not campaign_scroll.visible
		if s.story != null:
			campaign_text.text = s.story.journal_text()
			if campaign_scroll.visible:
				Speech.say(campaign_text.text, true))
	content.add_child(campaign_button)
	campaign_scroll = ScrollContainer.new()
	campaign_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	campaign_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	campaign_scroll.visible = false
	content.add_child(campaign_scroll)
	campaign_text = UIStyle.label("", 16)
	campaign_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	campaign_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campaign_scroll.add_child(campaign_text)
	history_label = UIStyle.label("", 14, UIStyle.CAPTION)
	history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(history_label)
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
	if s.psych != null:
		out.append(["psych", "The Sunrise Collective", "Nico Cozz: acid for grass, and the circuit"])
	if s.dealer != null:
		out.append(["dealer", "The dealership", "cars to drive, vans and trucks for the stash runs"])
	if s.casino != null:
		out.append(["casino", "The Hotel Cielo", "Lenny Vance: your stake, the cage, the General, the Lucky Palm"])
	if s.nights != null or s.ground != null:
		out.append(["desk", "The desk", "the boss's orders (and the squads, if there's a war on)"])
	if s.races != null:
		out.append(["track", "The track", "races for prize money: the street race in the car, the air circuit"])
	if s.rackets != null:
		out.append(["rackets", "The collectors", "what the streets we hold pay, and the prisoners"])
	if s.logistics != null:
		out.append(["logistics", "Dispatch", "where the product and the cash are; trucks; cash bags"])
	out.append(["taxi", "A taxi", "a ride to the aircraft, the desk, the job board, a stash house"])
	return out


func open() -> void:
	super.open()
	if not campaign_scroll.visible:
		list.grab_focus()


func refresh() -> void:
	title.text = "PHONE"
	campaign_button.text = "Chapter guidance and history  [G]"
	subtitle.text = "$%s in hand" % Py.money(s.money)
	if s.story != null and campaign_scroll.visible:
		campaign_text.text = s.story.journal_text()
	if s.renown != null:
		var nx: float = s.renown.next_at()
		subtitle.text += "   -   renown: %s (%d%s)" % [s.renown.title(), int(s.renown.score), ("/%d" % int(nx)) if nx > 0.0 else ""]
	var selected := list.selected_row()
	var keep = _row_id(rows[selected]) if selected >= 0 and selected < rows.size() else ""
	list.clear_rows()
	rows = []
	for call in s.phone_calls.pending():
		rows.append([str(call.action), str(call.from), "RINGING — Enter to answer; D to decline this call", int(call.id)])
	rows.append_array(contacts())
	for r in rows:
		list.add_row([("INCOMING  " if r.size() > 3 else ("NEW  " if fresh.has(r[0]) else "")) + str(r[1]), r[2]])
	if not rows.is_empty():
		var ids: Array = rows.map(_row_id)
		list.select_near(ids.find(keep) if ids.has(keep) else 0)
	_call_ids = s.phone_calls.pending().map(func(call): return int(call.id))
	var recent: Array[Dictionary] = s.phone_calls.history().filter(func(call): return call.state != "pending")
	history_label.text = "\n".join(recent.slice(-3).map(func(call): return "%s: %s — use the contact below to call back." % [str(call.state).capitalize(), str(call.from)]))
	footer.text = "" if not rows.is_empty() else "Nobody to call yet."
	hints.set_hints([["UP/DOWN", "select", "down"], ["ENTER", "answer / call", "enter"], ["D", "decline ringing call", "d"], ["ESC", "hang up", "esc"]])


static func _row_id(row: Array) -> String:
	return "call:" + str(row[3]) if row.size() > 3 else "contact:" + str(row[0])


func _process(delta: float) -> void:
	super._process(delta)
	if visible and s != null:
		var ids: Array = s.phone_calls.pending().map(func(call): return int(call.id))
		if ids != _call_ids:
			refresh()


func key(k: String) -> void:
	if s.story != null and (k == "g" or (k == "enter" and campaign_button.has_focus())):
		campaign_button.pressed.emit()
		return
	if campaign_scroll.visible:
		if k == "up":
			campaign_scroll.scroll_vertical -= 48
		elif k == "down":
			campaign_scroll.scroll_vertical += 48
		return
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
			if rows[i].size() > 3:
				var result: Array = s.command(Roles.PILOT, "phone_answer", {"id": rows[i][3]})
				if not result[0]:
					show_feedback(str(result[1]), false)
					refresh()
					return
			fresh.erase(action)
			close()
			called.emit(action)
		"d":
			var i := list.selected_row()
			if i >= 0 and i < rows.size() and rows[i].size() > 3:
				var result: Array = s.command(Roles.PILOT, "phone_decline", {"id": rows[i][3]})
				show_feedback("Call declined. The offer remains available through the contact." if result[0] else str(result[1]), bool(result[0]))
				refresh()


func _input(event: InputEvent) -> void:
	if visible and s.story != null and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		key("g")
		get_viewport().set_input_as_handled()
		return
	if visible and campaign_scroll.visible:
		for pair in [["ui_up", "up"], ["ui_down", "down"]]:
			if event.is_action_pressed(pair[0], true):
				key(pair[1])
				get_viewport().set_input_as_handled()
				return
	super._input(event)
