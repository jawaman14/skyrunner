class_name PhoneMenu
extends GameMenu
## The phone (T on foot, Shift+T from the cockpit): a handset in the corner of the screen with apps on its home screen,
## in the manner of the phones in open-world crime games.
##
##   Contacts   ring the people who otherwise need a walk to the desk or a landing at the right strip: Manny's hiring
##              hall, the buyers, the lawyer, the Family, the General's aide, the Collective, the car lot, the casino,
##              the desk, dispatch, a taxi. Only the systems that are switched on are in the book; a new number is NEW
##              until you ring it. A ringing call (PhoneCalls) sits above the book as INCOMING: ENTER answers, D
##              declines; the phone opens on Contacts while one rings.
##   Messages   what the phone has buzzed with (PhoneNotify's history) and the radio and crew lines, newest first
##   Map        the chart, to pick a place or a waypoint
##   Jobs       the jobs you have taken: ENTER puts a waypoint on the one you pick
##   Bank       the money: in hand, in the stash houses, in bags aboard
##   Radio      the stations on the dial: ENTER tunes to one
##   Settings   the pause menu (graphics, controls, the save)
##
## Arrows move, ENTER opens, the number keys open an app straight from the home screen, ESC goes back (and from the
## home screen puts the phone away). Picking a contact (or Map, or Settings) puts the phone away and emits
## `called(action)`; the pilot app does the rest, the same call the shortcut keys make. In a story, G (or the button
## on the home screen) opens the chapter guide over the phone.

signal called(action: String)
signal waypoint_to(world: Vector2)

## The phone as the hub (owner, 18 Oct; the system map's proposal): [page, name, colour, glyph]. Work, People and Empire
## gather what used to be Jobs, Contacts and Bank; Guide and Help bring the chapter guide and the F1 sheet in.
const APPS := [
	["work", "Work", Color(0.95, 0.8, 0.3), "jobs"],
	["contacts", "People", Color(0.3, 0.85, 0.45), "contacts"],
	["empire", "Empire", Color(0.45, 0.9, 0.85), "bank"],
	["map", "Map", Color(1.0, 0.55, 0.25), "map"],
	["messages", "Messages", Color(0.35, 0.65, 1.0), "messages"],
	["guide", "Guide", Color(0.85, 0.7, 1.0), "guide"],
	["help", "Help", Color(0.8, 0.8, 0.5), "help"],
	["radio", "Radio", Color(0.95, 0.4, 0.7), "radio"],
	["settings", "Settings", Color(0.65, 0.65, 0.72), "settings"],
	["done", "Done", Color(0.55, 0.85, 0.55), "guide"],  # past the 1-9 keys: arrows and ENTER reach these two
	["news", "News", Color(0.9, 0.9, 0.95), "guide"],
]
## People, in groups: each contact's action, by group.
const GROUPS := [
	["Crew and business", ["crew", "buyers", "dealer", "logistics", "rackets", "desk"]],
	["Law and politics", ["lawyer", "family", "general"]],
	["Leisure", ["casino", "track", "psych"]],
	["Rides", ["taxi"]],
]
const W := 380.0
const H := 540.0

var list: DataTable
var rows: Array = []  ## the contacts: [action, who, about]
var fresh := {}  ## numbers added since you last rang them (PilotApp._phone_watch): marked NEW
var page := "home"
var notify: PhoneNotify = null  ## the banners' history, for Messages (PilotApp sets it)
var radio: CarRadio = null  ## the dial, for Radio (PilotApp sets it)
var _grid: GridContainer
var _tiles: Array = []
var _sel := 0
var _info: Label
var _jobs: Array = []
var _work: Array = []  ## the Work page's rows: [kind, payload] - "board", "job" (a Job), or "" for a heading
var _empire: Array = []  ## the Empire page's rows: an action to call, or "" for a line
var _order_rows: Array = []
var _call_ids: Array = []  ## the ringing calls last drawn: a new one refreshes the phone
var history_label: Label  ## Contacts: the last few calls, answered, declined or missed
var campaign_scroll: ScrollContainer  ## the chapter guide (G, or its button on the home screen), over any app
var campaign_text: Label
var campaign_button: Button
var _drop_pending := -1  ## the job id the first D press asked about (Work > My jobs)
var _read_sig: Array = []  ## what the News or Done list was last built from (see refresh)


func _build() -> void:
	# a handset, not a full-screen panel: the bottom-right corner, rounded, with a status bar
	add_theme_stylebox_override("panel", UIStyle.box(Color(0.025, 0.028, 0.045, 0.97), 34, Color(1, 1, 1, 0.22), 3, Vector4(20, 18, 20, 16)))
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -W - 24.0
	offset_right = -24.0
	offset_top = -H - 24.0
	offset_bottom = -24.0
	# pinned to the corner: if the contents need more room the handset grows left and up, never off the screen
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	title.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	campaign_button = Button.new()
	campaign_button.text = "Chapter guide  [G]"
	campaign_button.visible = s.story != null
	campaign_button.pressed.connect(func():
		campaign_scroll.visible = not campaign_scroll.visible
		_show_page()
		if campaign_scroll.visible:
			campaign_button.grab_focus()
		elif list.visible:
			list.grab_focus()
		if s.story != null:
			campaign_text.text = s.story.journal_text())
	content.add_child(campaign_button)
	campaign_scroll = ScrollContainer.new()
	campaign_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	campaign_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	campaign_scroll.visible = false
	content.add_child(campaign_scroll)
	campaign_text = UIStyle.label("", 15)
	campaign_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	campaign_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campaign_scroll.add_child(campaign_text)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 18)
	content.add_child(_grid)
	for i in APPS.size():
		var a: Array = APPS[i]
		var tile := VBoxContainer.new()
		tile.add_theme_constant_override("separation", 4)
		tile.custom_minimum_size = Vector2(98, 96)
		var icon := Button.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var glyph := AppGlyph.new()
		glyph.kind = str(a[3])
		glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(glyph)
		icon.pressed.connect(open_app.bind(str(a[0])))
		tile.add_child(icon)
		var cap := UIStyle.label("%d  %s" % [i + 1, a[1]], 13, UIStyle.DIM)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(cap)
		_grid.add_child(tile)
		_tiles.append(icon)
	list = GameMenu.make_table([{"title": "", "expand": true, "ratio": 1, "min": 200}])
	list.row_activated.connect(func(_i): key("enter"))
	list.row_selected.connect(func(_i): _update_info())  # a mouse click shows that row's detail, as the arrow keys do
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(list)
	history_label = UIStyle.label("", 13, UIStyle.CAPTION)
	history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(history_label)
	_info = UIStyle.label("", 14, UIStyle.DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_info)


## An app's picture, drawn: a person, a speech bubble, a map pin, a briefcase, a dollar, radio waves, a gear.
class AppGlyph:
	extends Control
	var kind := ""

	func _draw() -> void:
		var c := size / 2.0
		var ink := Color(0.04, 0.04, 0.07)
		var r := minf(size.x, size.y) * 0.3
		match kind:
			"contacts":
				draw_circle(c + Vector2(0, -r * 0.45), r * 0.42, ink)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.85, r * 0.95), c + Vector2(-r * 0.6, r * 0.2), c + Vector2(0, 0.05 * r), c + Vector2(r * 0.6, r * 0.2), c + Vector2(r * 0.85, r * 0.95)]), ink)
			"messages":
				draw_rect(Rect2(c - Vector2(r, r * 0.75), Vector2(r * 2, r * 1.3)), ink)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.5, r * 0.5), c + Vector2(-r * 0.75, r * 1.05), c + Vector2(-r * 0.05, r * 0.5)]), ink)
			"map":
				draw_circle(c + Vector2(0, -r * 0.3), r * 0.65, ink)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r * 0.05), c + Vector2(0, r * 1.05), c + Vector2(r * 0.6, -r * 0.05)]), ink)
				draw_circle(c + Vector2(0, -r * 0.3), r * 0.25, Color(1, 1, 1, 0.9))
			"jobs":
				draw_rect(Rect2(c - Vector2(r, r * 0.45), Vector2(r * 2, r * 1.35)), ink)
				draw_rect(Rect2(c - Vector2(r * 0.4, r * 0.8), Vector2(r * 0.8, r * 0.4)), ink, false, 3.0)
			"bank":
				var f := UIStyle.mono()
				draw_string(f, c + Vector2(-r, r * 0.6), "$", HORIZONTAL_ALIGNMENT_CENTER, r * 2, int(r * 2.2), ink)
			"radio":
				draw_circle(c + Vector2(0, r * 0.5), r * 0.22, ink)
				for k in 3:
					draw_arc(c + Vector2(0, r * 0.5), r * (0.55 + 0.4 * k), deg_to_rad(-140), deg_to_rad(-40), 12, ink, 3.0, true)
			"guide":
				draw_rect(Rect2(c - Vector2(r * 0.9, r * 0.8), Vector2(r * 1.8, r * 1.6)), ink)
				for k in 3:
					draw_line(c + Vector2(-r * 0.55, -r * 0.35 + k * r * 0.38), c + Vector2(r * 0.55, -r * 0.35 + k * r * 0.38), Color(1, 1, 1, 0.85), 3.0)
			"help":
				draw_string(UIStyle.mono(), c + Vector2(-r, r * 0.7), "?", HORIZONTAL_ALIGNMENT_CENTER, r * 2, int(r * 2.2), ink)
			"settings":
				for k in 8:
					var a := TAU * k / 8.0
					draw_line(c, c + Vector2(cos(a), sin(a)) * r * 1.05, ink, 5.0)
				draw_circle(c, r * 0.72, ink)
				draw_circle(c, r * 0.3, Color(1, 1, 1, 0.85))


func _style_tiles() -> void:
	for i in _tiles.size():
		var col: Color = APPS[i][2]
		var on := i == _sel
		var b: Button = _tiles[i]
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, UIStyle.box(col if on else col.darkened(0.35), 18, Color(1, 1, 1, 0.85) if on else Color(0, 0, 0, 0), 3 if on else 0, Vector4(0, 0, 0, 0)))
		b.add_theme_color_override("font_color", Color(0.04, 0.04, 0.06))


## The phone book in its groups: a heading row ["", "Leisure", ""] before each group that has anyone in it.
func grouped_contacts() -> Array:
	var all := contacts()
	var out := []
	for g in GROUPS:
		var members := all.filter(func(r): return str(r[0]) in g[1])
		if not members.is_empty():
			out.append(["", str(g[0]), ""])
			out.append_array(members)
	for r in all:  # anyone a group does not name still gets called
		if not GROUPS.any(func(g): return str(r[0]) in g[1]):
			out.append(r)
	return out


## Who is on the phone book this game: only the systems that are switched on.
func contacts() -> Array:
	var out := []
	if s.payroll != null:
		out.append(["crew", "Manny Ortega", "the hiring hall: pilots, mules, dealers, soldiers"])
	if s.trade != null:
		out.append(["buyers", "Benny Ruiz", "who's buying, and at what"])
	if s.court != null:
		out.append(["lawyer", "Your lawyer", "motions, the plea, a deal"])
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


## The home screen, unless a call is ringing: then the phone opens on Contacts, with the call at the top.
func open() -> void:
	page = "home"
	_drop_pending = -1
	campaign_scroll.visible = false
	super.open()
	if not s.phone_calls.pending().is_empty():
		open_app("contacts")


## Open one of the apps (or do what it does at once: Map, Help and Settings put the phone away; Guide opens the chapter guide).
func open_app(id: String) -> void:
	match id:
		"map", "settings", "help":
			page = "home"
			super.close()
			called.emit(id)
			return
		"guide":
			if s.story != null:
				campaign_button.pressed.emit()
			else:
				show_feedback("No story in this game: there is no chapter guide.", false)
			return
	page = id
	_drop_pending = -1
	_read_sig = []
	campaign_scroll.visible = false
	if list != null:
		list.clear_rows()
	refresh()
	if list != null and list.row_count() > 0:
		list.select_near(0)
		list.grab_focus()
	_update_info()


## What shows: the chapter guide over everything when it is open, else the home screen's tiles or the app's list.
func _show_page() -> void:
	var guide := campaign_scroll.visible
	var home := page == "home"
	_grid.visible = home and not guide
	list.visible = not home and not guide
	_info.visible = not home and not guide
	history_label.visible = page == "contacts" and not guide and history_label.text != ""
	campaign_button.visible = s.story != null and (home or guide)


## A ringing call is a row of its own above the book: [action, from, what to do, call id].
static func _row_id(row: Array) -> String:
	return "call:" + str(row[3]) if row.size() > 3 else "contact:" + str(row[0])


func refresh() -> void:
	subtitle.text = "$%s   %s" % [Py.money(s.money), "|||"]
	if s.story != null and campaign_scroll.visible:
		campaign_text.text = s.story.journal_text()
	var selected := list.selected_row()
	var order_keep: int = int(_order_rows[selected].id) if page == "orders" and selected >= 0 and selected < _order_rows.size() else -1
	var keep: String = _row_id(rows[selected]) if page == "contacts" and selected >= 0 and selected < rows.size() else ""
	# the book is always current (the walker's tests and the pilot app read it); ringing calls come first
	rows = []
	for call in s.phone_calls.pending():
		rows.append([str(call.action), str(call.from), "RINGING: Enter to answer, D to decline", int(call.id)])
	rows.append_array(grouped_contacts())
	_call_ids = s.phone_calls.pending().map(func(call): return int(call.id))
	var recent: Array[Dictionary] = s.phone_calls.history().filter(func(call): return call.state != "pending")
	history_label.text = "\n".join(recent.slice(-3).map(func(call): return "%s: %s. Call back from the book." % [str(call.state).capitalize(), str(call.from)]))
	_show_page()
	if page == "home":
		title.text = "Phone"
		_style_tiles()
		footer.text = ""
		hints.set_hints([["ARROWS", "choose", "right"], ["ENTER", "open", "enter"], ["1-%d" % APPS.size(), "app", ""], ["ESC", "put away", "esc"]])
		return
	if page in ["news", "done"]:
		# the pilot app refreshes an open phone about six times a second; rebuilding an unchanged list snapped a reader's scroll back to
		# the selected row, so these two read-only lists are only rebuilt when their text changes
		var lines: Array = _news_lines() if page == "news" else _finished_objectives()
		if lines == _read_sig and list.row_count() > 0:
			return
		_read_sig = lines
	list.clear_rows()
	footer.text = ""
	match page:
		"contacts":
			title.text = "Contacts"
			title.text = "People"
			for r in rows:
				if str(r[0]) == "" and r.size() <= 3:
					list.section(str(r[1]))
				else:
					list.add_row([("INCOMING  " if r.size() > 3 else ("NEW  " if fresh.has(r[0]) else "")) + str(r[1])])
			if rows.is_empty():
				footer.text = "Nobody to call yet."
			hints.set_hints([["UP/DOWN", "select", "down"], ["ENTER", "answer / call", "enter"], ["D", "decline", "d"], ["ESC", "back", "esc"]])
		"messages":
			title.text = "Messages"
			for m in _messages():
				list.add_row([m])
			hints.set_hints([["UP/DOWN", "scroll", "down"], ["ESC", "back", "esc"]])
		"work":
			title.text = "Work"
			_jobs = s.active_jobs.slice(0, 12)
			_work = []
			list.section("The job board")
			_work.append(["", null])
			list.add_row(["Open the job board"])
			_work.append(["board", null])
			list.section("Market and buyers")
			_work.append(["", null])
			list.add_row(["Market prices"])
			_work.append(["market", null])
			list.add_row(["Buyers' orders"])
			_work.append(["orders", null])
			list.section("My jobs: ENTER puts a waypoint on one, D drops it")
			_work.append(["", null])
			for j in _jobs:
				list.add_row(["%s%s   $%s" % ["HOT " if j.hot() else "", j.dest_label(), Py.money(j.payout)]])
				_work.append(["job", j])
			if _jobs.is_empty():
				footer.text = "No jobs taken yet."
			hints.set_hints([["UP/DOWN", "select", "down"], ["ENTER", "open / waypoint", "enter"], ["D", "drop job", "d"], ["ESC", "back", "esc"]])
		"empire":
			title.text = "Empire"
			_empire = []
			for part in _empire_parts():
				list.section(str(part[0]))
				_empire.append("")
				for item in part[1]:
					list.add_row([str(item[0])])
					_empire.append(str(item[1]))
			hints.set_hints([["UP/DOWN", "select", "down"], ["ENTER", "open", "enter"], ["ESC", "back", "esc"]])
		"news":
			title.text = "The Daily Coast"
			for line in _news_lines():
				if str(line).begins_with("# "):
					list.section(str(line).substr(2))
				else:
					list.add_row([line])
			if list.row_count() == 0:
				footer.text = "No news yet today."
			hints.set_hints([["UP/DOWN", "scroll", "down"], ["ESC", "back", "esc"]])
		"done":
			title.text = "Done"
			for line in _finished_objectives():
				if line.begins_with("# "):
					list.section(line.substr(2))
				else:
					list.add_row([line])
			if list.row_count() == 0:
				footer.text = "Nothing finished yet."
			hints.set_hints([["UP/DOWN", "scroll", "down"], ["ESC", "back", "esc"]])
		"market":
			_market_page()
		"orders":
			_orders_page()
		"heat":
			_heat_page()
		"radio":
			title.text = "Radio"
			if radio != null:
				for st in radio.stations:
					list.add_row(["%s  %s" % [st.dial(), st.name]])
			if radio == null or radio.stations.is_empty():
				footer.text = "No stations on the dial."
			hints.set_hints([["UP/DOWN", "select", "down"], ["ENTER", "tune", "enter"], ["ESC", "back", "esc"]])
	if list.row_count() > 0:
		if page == "contacts":
			# keep the same person selected when a call starts or stops ringing above them
			var ids: Array = rows.map(_row_id)
			list.select_near(ids.find(keep) if ids.has(keep) else 0)
		elif page == "orders":
			var ids: Array = _order_rows.map(func(o): return int(o.id))
			list.select_near(ids.find(order_keep) if ids.has(order_keep) else 0)
		else:
			list.select_near(selected if selected >= 0 else 0)
	_update_info()


## A call that starts ringing while the phone is out: the home screen goes to Contacts, any app redraws.
func _process(delta: float) -> void:
	super._process(delta)
	if visible and s != null:
		var ids: Array = s.phone_calls.pending().map(func(call): return int(call.id))
		if ids != _call_ids:
			if page == "home" and not campaign_scroll.visible and ids.size() > _call_ids.size():
				open_app("contacts")
			else:
				refresh()


## The paper: the island's headlines (the chronicle's, as the runner hears them) and the market's, newest first.
func _news_lines() -> Array:
	var items := []
	if s.chronicle != null:
		for e in s.chronicle.entries:
			if e[3] or e[1] == "org" or e[1] == "family":
				items.append([float(e[0]), str(e[4])])
	if s.econ != null:
		for n in s.econ.news:
			items.append([float(n[0]), "Market: %s" % str(n[1])])
	items.sort_custom(func(a, b): return a[0] > b[0])
	var out := []
	# what is moving prices right now, and for how long: something to plan a run around, not only to read about afterwards
	var now_on := []
	if s.econ != null:
		for e in s.econ.events:
			var good := str(e.good)
			var name := str(Economy.GOODS.get(good, {}).get("name", good.capitalize()))
			# the effect and the countdown first: the handset is narrow and a long headline would push them off the edge
			now_on.append("%s x%.2f, %d min left: %s" % [name, float(e.mult), maxi(1, ceili((float(e.until) - s.time) / 60.0)), str(e.text)])
	if not now_on.is_empty():
		out.append("# In force now")
		out.append_array(now_on)
		out.append("# Headlines")
	out.append_array(items.slice(0, 20).map(func(i): return "%d:%02d  %s" % [int(i[0] / 3600.0), int(i[0] / 60.0) % 60, i[1]]))
	return out


## The objectives already met, newest chapter first: a "# heading" line for each chapter, then its ticked goals.
func _finished_objectives() -> Array:
	var out := []
	if s.story == null:
		return ["No story in this game."]
	var now: Array = s.story.objective_lines().filter(func(l): return str(l).begins_with("[x]"))
	if not now.is_empty():
		out.append("# Now: %s" % s.story.chapter.title)
		for l in now:
			out.append(str(l).substr(4))
	for k in range(s.story.history.size() - 1, -1, -1):
		var entry: Dictionary = s.story.history[k]
		var done: Array = entry.get("objectives", []).filter(func(l): return str(l).begins_with("[x]"))
		if done.is_empty():
			continue
		out.append("# %s" % entry.get("title", "Earlier"))
		for l in done:
			out.append(str(l).substr(4))
	return out


func _messages() -> Array:
	var out := []
	if notify != null:
		for h in notify.history.slice(-20):
			out.push_front("%s: %s" % [h.sender, h.body])
	for m in s.messages.slice(-15):
		out.append("%d:%02d  %s" % [int(m[0] / 60.0), int(m[0]) % 60, str(m[1])])
	return out


## The Empire page: [heading, [[line, action or ""], ...]] for money, the fleet and the turf.
func _empire_parts() -> Array:
	var money := []
	for line in _bank_lines():
		money.append([line, ""])
	if s.logistics != null:
		money.append(["Dispatch: move product and cash", "logistics"])
	var fleet := [["Flying the %s" % s.spec.name, ""]]
	if s.owned.size() > 1:
		fleet.append(["Aircraft owned: %d" % s.owned.size(), ""])
	if s.airframe != null:
		var v: Dictionary = s.airframe.view(false)
		fleet.append(["Engine %s, airframe %s" % [v.get("engine", "?"), v.get("airframe", "?")], ""])
	if s.dealer != null:
		fleet.append(["The car lot: cars, vans and trucks", "dealer"])
	var parts := [["Money", money], ["Fleet", fleet], ["The law", [["Heat and case files", "heat"]]]]
	var turf := []
	if s.rackets != null:
		turf.append(["The collectors: the streets we hold", "rackets"])
	if s.nights != null or s.ground != null:
		turf.append(["The desk: orders and squads", "desk"])
	if not turf.is_empty():
		parts.append(["Turf", turf])
	return parts


func _bank_lines() -> Array:
	var out := ["In hand: $%s" % Py.money(s.money)]
	if s.logistics != null:
		var total := 0.0
		for id in s.logistics.cash:
			var c: float = float(s.logistics.cash[id])
			if c >= 1.0:
				out.append("At %s: $%s" % [s.logistics.name_of(str(id)), Py.money(int(c))])
				total += c
		out.append("In the stash houses: $%s" % Py.money(int(total)))
		if int(s.logistics.aboard) > 0:
			out.append("In bags aboard: $%s" % Py.money(int(s.logistics.aboard)))
	if s.renown != null:
		out.append("Renown: %s (%d)" % [s.renown.title(), int(s.renown.score)])
	return out


## The line under the list: who a contact is, what a station is playing.
func _update_info() -> void:
	var i := list.selected_row()
	_info.text = ""
	if page == "contacts" and i >= 0 and i < rows.size():
		_info.text = str(rows[i][2])
	elif page in ["news", "done"] and i >= 0 and i < list.row_count():
		_info.text = list.cell(i, 0)  # the whole line, wrapped, for a headline wider than the handset
	elif page == "radio" and radio != null and i >= 0 and i < radio.stations.size():
		_info.text = str(radio.stations[i].blurb)
	elif page == "work" and i >= 0 and i < _work.size() and str(_work[i][0]) == "job":
		var j = _work[i][1]
		var tl = j.time_left(s.time)
		_info.text = "%s%s" % [j.dest_label(), ("  -  %d:%02d left" % [int(tl / 60), int(fposmod(tl, 60))]) if tl != null else ""]


## ESC: back to the home screen, and from there away. With the chapter guide open it puts the phone away.
func close() -> void:
	if visible and page in ["market", "orders", "heat"] and not campaign_scroll.visible:
		open_app("empire" if page == "heat" else "work")
		return
	if visible and page != "home" and not campaign_scroll.visible:
		page = "home"
		refresh()
		return
	page = "home"
	super.close()


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
	if page == "home":
		match k:
			"left", "up":
				_sel = posmod(_sel - (1 if k == "left" else 3), APPS.size())
				_style_tiles()
			"right", "down":
				_sel = posmod(_sel + (1 if k == "right" else 3), APPS.size())
				_style_tiles()
			"enter":
				open_app(str(APPS[_sel][0]))
			_:
				if k.is_valid_int() and int(k) >= 1 and int(k) <= APPS.size():
					_sel = int(k) - 1
					open_app(str(APPS[_sel][0]))
		return
	match k:
		"up":
			list.move(-1)
			_drop_pending = -1  # moving away keeps the job: the next D asks again
			_update_info()
		"down":
			list.move(1)
			_drop_pending = -1
			_update_info()
		"enter":
			var i := list.selected_row()
			match page:
				"contacts":
					if i < 0 or i >= rows.size():
						return
					var action: String = rows[i][0]
					if action == "" and rows[i].size() <= 3:
						return  # a group's heading
					if not _can_call(action):
						return
					if rows[i].size() > 3:
						var result: Array = s.command(Roles.PILOT, "phone_answer", {"id": rows[i][3]})
						if not result[0]:
							show_feedback(str(result[1]), false)
							refresh()
							return
					fresh.erase(action)
					page = "home"
					super.close()
					called.emit(action)
				"work":
					if i < 0 or i >= _work.size() or str(_work[i][0]) == "":
						return
					if str(_work[i][0]) in ["market", "orders"]:
						open_app(str(_work[i][0]))
						return
					if str(_work[i][0]) == "board" and not _can_call("job_board"):
						return
					page = "home"
					super.close()
					if str(_work[i][0]) == "board":
						called.emit("job_board")
					else:
						var xy: Array = s.job_xy(_work[i][1])
						waypoint_to.emit(Vector2(float(xy[0]), float(xy[1])))
				"empire":
					if i >= 0 and i < _empire.size() and str(_empire[i]) != "":
						if str(_empire[i]) == "heat":
							open_app("heat")
							return
						if not _can_call(str(_empire[i])):
							return
						page = "home"
						super.close()
						called.emit(str(_empire[i]))
				"orders":
					if i >= 0 and i < _order_rows.size():
						page = "home"
						super.close()
						called.emit("buyers")
				"radio":
					if radio != null and i >= 0 and i < radio.stations.size():
						radio.idx = i
						radio.power(true)
						_info.text = radio.line()
		"d":
			var i := list.selected_row()
			if page == "contacts" and i >= 0 and i < rows.size() and rows[i].size() > 3:
				var result: Array = s.command(Roles.PILOT, "phone_decline", {"id": rows[i][3]})
				show_feedback("Call declined. The offer stays open through the contact." if result[0] else str(result[1]), bool(result[0]))
				refresh()
			elif page == "work" and i >= 0 and i < _work.size() and str(_work[i][0]) == "job":
				_drop_job(_work[i][1])


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


## D on one of My jobs: drop it (no delivery pay). The first press asks, the second does it, as the job board does.
func _drop_job(j: Jobs.Job) -> void:
	var action: Dictionary = s.job_action(Roles.PILOT, "drop_job", j.id)
	if not action.enabled:
		_drop_pending = -1
		show_feedback(str(action.disabled_reason), false)
		return
	if action.confirmation_required and _drop_pending != j.id:
		_drop_pending = j.id
		show_feedback("Drop '%s'? You get no delivery pay. Press D again to confirm, or move away to keep it." % j.title, false)
		return
	_drop_pending = -1
	var result: Array = s.command(Roles.PILOT, "drop_job", action.args)
	show_feedback(("Dropped %s. No delivery pay." % j.title) if result[0] else str(result[1]), bool(result[0]))
	if result[0]:
		s.say("Dropped %s. No delivery pay." % j.title)
	refresh()


## These services need a parked aircraft; calls and the read-only apps work aloft.
func _can_call(action: String) -> bool:
	if not s.parked and action in ["job_board", "desk", "logistics", "taxi", "rackets", "dealer", "track"]:
		show_feedback("Land and park before using this service.", false)
		return false
	return true


func _market_page() -> void:
	title.text = "Market prices"
	if s.trade == null or s.trade.orders == null:
		footer.text = "The market board is not available in this game."
		return
	var goods: Dictionary = s.trade.orders.board().goods
	for good in goods:
		list.section(str(good).capitalize())
		for market in goods[good]:
			var quote: Dictionary = goods[good][market]
			list.add_row(["%s: %d%% of usual, %s" % [str(market).capitalize(), roundi(float(quote.price) * 100.0), str(quote.trend)]])
			list.add_row(["  demand / supply: %.2fx" % float(quote.pressure)])
	footer.text = "Relative prices, not a sale quote. Call Benny for the buyer's terms."
	hints.set_hints([["UP/DOWN", "scroll", "down"], ["ESC", "back", "esc"]])


func _orders_page() -> void:
	title.text = "Buyers' orders"
	_order_rows = []
	if s.trade != null and s.trade.orders != null:
		_order_rows = s.trade.orders.view().open
	for order in _order_rows:
		var seconds := maxi(0, int(order.seconds_left))
		var unit := "rifles" if str(order.good) == "guns" else "lb"
		list.add_row(["%s: %d %s %s  +%d%%  %d:%02d" % [str(order.name), int(order.left), unit,
			str(order.good), roundi((float(order.premium) - 1.0) * 100.0), seconds / 60, seconds % 60]])
	if _order_rows.is_empty():
		footer.text = "No open orders. Check back when buyers post demand."
	else:
		footer.text = "ENTER calls Benny. Deliver and sell to the named buyer before the deadline; calling does not accept a sale."
	hints.set_hints([["UP/DOWN", "select", "down"], ["ENTER", "call Benny", "enter"], ["ESC", "back", "esc"]])


func _heat_page() -> void:
	title.text = "Heat and case files"
	if s.investigation == null:
		footer.text = "Case files are not available in this game."
		return
	var investigation: Investigation = s.investigation
	list.section("Aircraft")
	list.add_row(["Current tail: %d%%" % roundi(float(investigation.tail_heat.get(s.aircraft_key, 0.0)))])
	list.section("Districts")
	var districts: Array = investigation.district_heat.keys()
	districts.sort()
	for district in districts:
		list.add_row(["%s: %d%%" % [str(district).capitalize(), roundi(float(investigation.district_heat[district]))]])
	if districts.is_empty():
		list.add_row(["No district heat recorded."])
	list.section("Stash case files")
	var warned := {}
	if s.payroll != null and s.stash_net != null:
		for worker in s.payroll.workers:
			if str(worker.outfit) == "org" and str(worker.role) == "lookout" and str(worker.status) == "assigned":
				for stash in s.stash_net.stashes:
					if str(worker.assigned) == "stash-" + str(stash.id):
						warned[str(stash.id)] = true
	var cases: Array = investigation.view(s.stash_net, s.time, warned) if s.stash_net != null else []
	for case in cases:
		var line := "%s: %s" % [str(case.name), str(case.stage)]
		if case.has("raid_in_s"):
			var seconds := maxi(0, int(case.raid_in_s))
			line += "  lookout: %d:%02d" % [seconds / 60, seconds % 60]
		list.add_row([line])
	if cases.is_empty():
		list.add_row(["No active stash case files."])
	footer.text = "Park (a hangar cools the tail faster), lie low or move stock. Call your lawyer about a warrant. Raid timing needs a posted lookout."
	hints.set_hints([["UP/DOWN", "scroll", "down"], ["ESC", "back", "esc"]])
