class_name PhoneMenu
extends GameMenu
## The phone (T on foot, Shift+T from the cockpit): a handset in the corner of the screen with apps on its home screen,
## in the manner of the phones in open-world crime games.
##
##   Contacts   ring the people who otherwise need a walk to the desk or a landing at the right strip: Manny's hiring
##              hall, the buyers, the lawyer, the Family, the General's aide, the Collective, the car lot, the casino,
##              the desk, dispatch, a taxi. Only the systems that are switched on are in the book; a new number is NEW
##              until you ring it.
##   Messages   what the phone has buzzed with (PhoneNotify's history) and the radio and crew lines, newest first
##   Map        the chart, to pick a place or a waypoint
##   Jobs       the jobs you have taken: ENTER puts a waypoint on the one you pick
##   Bank       the money: in hand, in the stash houses, in bags aboard
##   Radio      the stations on the dial: ENTER tunes to one
##   Settings   the pause menu (graphics, controls, the save)
##
## Arrows move, ENTER opens, the number keys open an app straight from the home screen, ESC goes back (and from the
## home screen puts the phone away). Picking a contact (or Map, or Settings) puts the phone away and emits
## `called(action)`; the pilot app does the rest, the same call the shortcut keys make.

signal called(action: String)
signal waypoint_to(world: Vector2)

const APPS := [
	["contacts", "Contacts", Color(0.3, 0.85, 0.45)],
	["messages", "Messages", Color(0.35, 0.65, 1.0)],
	["map", "Map", Color(1.0, 0.55, 0.25)],
	["jobs", "Jobs", Color(0.95, 0.8, 0.3)],
	["bank", "Bank", Color(0.45, 0.9, 0.85)],
	["radio", "Radio", Color(0.95, 0.4, 0.7)],
	["settings", "Settings", Color(0.65, 0.65, 0.72)],
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
	title.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
		glyph.kind = str(a[0])
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
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(list)
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
	page = "home"
	super.open()


## Open one of the apps (or do what it does at once: Map and Settings put the phone away).
func open_app(id: String) -> void:
	match id:
		"map", "settings":
			page = "home"
			super.close()
			called.emit(id)
			return
	page = id
	if list != null:
		list.clear_rows()
	refresh()
	if list != null and list.row_count() > 0:
		list.select_near(0)
	_update_info()


func refresh() -> void:
	subtitle.text = "$%s   %s" % [Py.money(s.money), "|||"]
	var home := page == "home"
	_grid.visible = home
	list.visible = not home
	_info.visible = not home
	rows = contacts()  # the book is always current (the walker's tests and the pilot app read it)
	if home:
		title.text = "Phone"
		_style_tiles()
		footer.text = ""
		hints.set_hints([["ARROWS", "choose", "right"], ["ENTER", "open", "enter"], ["1-7", "app", ""], ["ESC", "put away", "esc"]])
		return
	var keep := list.selected_row()
	list.clear_rows()
	footer.text = ""
	match page:
		"contacts":
			title.text = "Contacts"
			for r in rows:
				list.add_row([("NEW  " if fresh.has(r[0]) else "") + str(r[1])])
			if rows.is_empty():
				footer.text = "Nobody to call yet."
			hints.set_hints([["UP/DOWN", "select", "down"], ["ENTER", "call", "enter"], ["ESC", "back", "esc"]])
		"messages":
			title.text = "Messages"
			for m in _messages():
				list.add_row([m])
			hints.set_hints([["UP/DOWN", "scroll", "down"], ["ESC", "back", "esc"]])
		"jobs":
			title.text = "Jobs"
			_jobs = s.active_jobs.slice(0, 12)
			for j in _jobs:
				list.add_row(["%s%s   $%s" % ["HOT " if j.hot() else "", j.dest_label(), Py.money(j.payout)]])
			if _jobs.is_empty():
				footer.text = "No jobs taken. The board is J at a strip's hangar."
			hints.set_hints([["UP/DOWN", "select", "down"], ["ENTER", "waypoint", "enter"], ["ESC", "back", "esc"]])
		"bank":
			title.text = "Bank"
			for line in _bank_lines():
				list.add_row([line])
			hints.set_hints([["ESC", "back", "esc"]])
		"radio":
			title.text = "Radio"
			if radio != null:
				for st in radio.stations:
					list.add_row(["%s  %s" % [st.dial(), st.name]])
			if radio == null or radio.stations.is_empty():
				footer.text = "No stations on the dial."
			hints.set_hints([["UP/DOWN", "select", "down"], ["ENTER", "tune", "enter"], ["ESC", "back", "esc"]])
	if list.row_count() > 0:
		list.select_near(keep if keep >= 0 else 0)
	_update_info()


func _messages() -> Array:
	var out := []
	if notify != null:
		for h in notify.history.slice(-20):
			out.push_front("%s: %s" % [h.sender, h.body])
	for m in s.messages.slice(-15):
		out.append("%d:%02d  %s" % [int(m[0] / 60.0), int(m[0]) % 60, str(m[1])])
	return out


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
	elif page == "radio" and radio != null and i >= 0 and i < radio.stations.size():
		_info.text = str(radio.stations[i].blurb)
	elif page == "jobs" and i >= 0 and i < _jobs.size():
		var j = _jobs[i]
		var tl = j.time_left(s.time)
		_info.text = "%s%s" % [j.dest_label(), ("  -  %d:%02d left" % [int(tl / 60), int(fposmod(tl, 60))]) if tl != null else ""]


## ESC: back to the home screen, and from there away.
func close() -> void:
	if visible and page != "home":
		page = "home"
		refresh()
		return
	super.close()


func key(k: String) -> void:
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
			_update_info()
		"down":
			list.move(1)
			_update_info()
		"enter":
			var i := list.selected_row()
			match page:
				"contacts":
					if i < 0 or i >= rows.size():
						return
					var action: String = rows[i][0]
					fresh.erase(action)
					page = "home"
					super.close()
					called.emit(action)
				"jobs":
					if i >= 0 and i < _jobs.size():
						var xy: Array = s.job_xy(_jobs[i])
						waypoint_to.emit(Vector2(float(xy[0]), float(xy[1])))
						page = "home"
						super.close()
				"radio":
					if radio != null and i >= 0 and i < radio.stations.size():
						radio.idx = i
						radio.power(true)
						_info.text = radio.line()
