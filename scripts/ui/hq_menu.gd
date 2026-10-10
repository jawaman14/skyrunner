class_name HQMenu
extends GameMenu
## The organisation's orders, from the boss's desk in the villa (walk in and
## press E). The same HQBoard as the boss station: headline tiles, tonight's
## conditions, the order table (LEFT/RIGHT sets an order, ENTER issues it).
## `intel` mode is the map table: what the organisation knows about Los Cuervos,
## their turf, tonight's leak and the news.
##
## Q (even with no season running) swaps the desk for the same squad command
## the boss's seat gives in co-op (StationApp.squad_mode): CLICK a squad,
## RIGHT-CLICK the map to send it, guerrilla orders by button. It claims the
## BOSS seat for as long as that lasts (Session.seat_driver stands the ground
## war's AI commander aside the same way it already does for a human
## lieutenant), and hands it back on Q again or on leaving the desk.

var intel := false
var board: HQBoard
var list: DataTable  ## the board's order table (kept for callers that drive it)
var rows: Array = []
var info: Label
var turf: VBoxContainer
var squad_mode := false
var _claimed_boss := false
var map: StationMap
var squad_label: Label
var squad_buttons: HFlowContainer
var sel_squad = null
var districts_open := false
var districts_button: Button
var district_scroll: ScrollContainer
var district_text: Label


func _build() -> void:
	board = HQBoard.new().setup("runner")
	content.add_child(board)
	list = board.table
	info = UIStyle.label("", 15, UIStyle.WHITE)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)
	turf = VBoxContainer.new()
	turf.add_theme_constant_override("separation", 6)
	content.add_child(turf)
	list.row_activated.connect(func(_i): key("enter"))
	map = StationMap.new().setup(s.world)
	map.role = Roles.BOSS
	map.custom_minimum_size = Vector2(0, 360)
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.clicked.connect(_on_map_click)
	content.add_child(map)
	squad_label = UIStyle.label("- (click a squad)", 15, UIStyle.DIM)
	squad_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(squad_label)
	squad_buttons = HFlowContainer.new()
	squad_buttons.add_theme_constant_override("h_separation", 6)
	squad_buttons.add_theme_constant_override("v_separation", 6)
	for b in [["Melt away", "melt"], ["Hold", "hold"], ["Disband", "disband"], ["Raise foot", "raise_foot"],
			["Raise car", "raise_car"], ["Raise truck", "raise_truck"]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.focus_mode = Control.FOCUS_ALL
		btn.pressed.connect(key.bind(b[1]))
		squad_buttons.add_child(btn)
	content.add_child(squad_buttons)
	districts_button = Button.new()
	districts_button.text = "District overview  [D]"
	districts_button.pressed.connect(_toggle_districts)
	content.add_child(districts_button)
	district_scroll = ScrollContainer.new()
	district_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	district_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(district_scroll)
	district_text = UIStyle.label("", 15, UIStyle.WHITE)
	district_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	district_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	district_scroll.add_child(district_text)


func _view():
	return s.nights.view("runner") if s.nights != null else null


## The map is a live tactical picture (squads moving, fights breaking out), so
## it needs a snapshot every frame, not just on open() or a keypress like the
## rest of this menu's static panels.
func _process(_dt: float) -> void:
	super._process(_dt)
	if visible and squad_mode:
		map.snap = Snapshot.build(s, Roles.BOSS, 0)
		if sel_squad != null and s.ground.get_squad(str(sel_squad)) == null:
			sel_squad = null
		map.sel_squad = sel_squad
		_squad_detail()
		if districts_open:
			district_text.text = preload("res://scripts/ui/widgets/district_summary.gd").describe(map.snap.get("ground", {}).get("districts", [])) + "\n\n" + preload("res://scripts/ui/widgets/battle_report.gd").describe(map.snap.get("ground", {}).get("battle_reports", []))


## With no season running the orders board has nothing to show, so a solo player's desk would
## open on a "no season" note with squad command hidden behind Q: open straight into the squads.
func open() -> void:
	if not intel and not squad_mode and _view() == null and s.ground != null:
		_enter_squad_mode()
	super.open()


func close() -> void:
	if squad_mode:
		_leave_squad_mode()
	super.close()


## Belt and braces: something elsewhere (switching to another desk menu,
## climbing back into the aircraft) can hide this panel directly without
## going through close() - never leave the boss's seat claimed if that happens.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible and squad_mode:
		_leave_squad_mode()


func refresh() -> void:
	board.visible = false
	turf.visible = false
	info.visible = false
	map.visible = squad_mode and not districts_open
	squad_label.visible = squad_mode and not districts_open
	squad_buttons.visible = squad_mode and not districts_open
	districts_button.visible = squad_mode
	district_scroll.visible = squad_mode and districts_open
	if squad_mode:
		title.text = "THE BOSS'S DESK"
		subtitle.text = "Districts" if districts_open else "Squads"
		districts_button.text = "Back to squads  [D]" if districts_open else "District overview  [D]"
		if districts_open:
			district_text.text = preload("res://scripts/ui/widgets/district_summary.gd").describe(s.ground.district_view("org")) + "\n\n" + preload("res://scripts/ui/widgets/battle_report.gd").describe(s.ground.battle_history("org"))
			hints.set_hints([["UP/DOWN", "scroll", "down"], ["D", "back to squads", "d"], ["ESC", "leave the desk", "esc"]])
			return
		_squad_detail()
		hints.set_hints(([["Q", "back to the orders", "q"]] if _view() != null else []) + [["CLICK", "squad", ""],
			["RIGHT-CLICK", "send it", ""], ["D", "districts", "d"], ["ESC", "leave the desk", "esc"]])
		return
	var ss = _view()
	if ss == null:
		title.text = "THE VILLA"
		subtitle.text = ""
		info.text = "No season is running: the organisation and its HQ orders come with the fifth rule layer\n(--players 5 or more, or --layer 5)."
		info.visible = true
		hints.set_hints(([["Q", "squads", "q"]] if s.ground != null else []) + [["ESC", "close", "esc"]])
		return
	var head := "NIGHT %d/%d  -  %s" % [int(ss.night), int(ss.nights), str(ss.phase).to_upper()]
	if intel:
		_intel(ss, head)
		return
	title.text = "THE BOSS'S DESK"
	subtitle.text = head
	board.visible = true
	board.update(ss)
	rows = board.rows
	footer.text = ""
	hints.set_hints([["UP/DOWN", "order", "down"], ["LEFT/RIGHT", "change it", "right"], ["ENTER", "issue", "enter"]]
		+ ([["Q", "squads", "q"]] if s.ground != null else []) + [["ESC", "close", "esc"]])


func _intel(ss: Dictionary, head: String) -> void:
	title.text = "MAP TABLE"
	subtitle.text = head
	info.visible = true
	for c in turf.get_children():
		turf.remove_child(c)
		c.queue_free()
	var rv = ss.get("rival")
	var lines := []
	if rv is Dictionary:
		lines.append("%s: %s%s%s" % [rv.name, rv.band, ("   -   truce %d nights" % int(rv.truce_nights)) if rv.truce_nights else "",
			"   -   OUT FOR REVENGE" if rv.grudge else ""])
		turf.add_child(UIStyle.caption("Their share of each market"))
		for z in HQOrders.ZONES:
			var t := StatTile.new().setup(z, true, 16)
			var share := float(rv.turf[z])
			t.set_value("%d%%" % int(share * 100), UIStyle.RED if share > 0.5 else UIStyle.AMBER, share)
			turf.add_child(t)
	else:
		lines.append("No rival outfit on this island.")
	if ss.get("patrol_leak"):
		lines.append("Our man in dispatch: the patrol goes %s tonight." % ss.patrol_leak)
	lines += HQOrders.realism_lines(ss, "runner")
	lines += ["", "NEWS"] + ss.get("news", []).slice(-5).map(func(n): return "  " + str(n))
	lines += ["", "LOG"] + ss.get("log", []).slice(-6).map(func(n): return "  " + str(n))
	info.text = "\n".join(lines)
	hints.set_hints([["ESC", "close", "esc"]])


func _detail() -> void:
	board._detail()


func key(k: String) -> void:
	if confirmation_key(k):
		return
	if intel:
		return
	if squad_mode and k == "d":
		_toggle_districts()
		return
	if k == "q" and s.ground != null:
		if squad_mode:
			_leave_squad_mode()
		else:
			_enter_squad_mode()
		refresh()
		return
	if squad_mode and districts_open:
		if k in ["up", "down"]:
			district_scroll.scroll_vertical += -40 if k == "up" else 40
		return
	if squad_mode:
		_squad_key(k)
		refresh()
		return
	var ss = _view()
	if ss == null:
		return
	match k:
		"up":
			list.move(-1)
			_detail()
			return
		"down":
			list.move(1)
			_detail()
			return
		"left", "right":
			board.adjust(1 if k == "right" else -1, ss)
		"enter":
			var args := board.command_args()
			if not args.is_empty():
				var res: Array = s.command(Roles.PILOT, "hq", args)
				if not res[0]:
					s.say(res[1])
	refresh()


# ------------------------------------------------------------------ squads
func _toggle_districts() -> void:
	districts_open = not districts_open
	refresh()
	districts_button.grab_focus()
	if districts_open: Speech.say(district_text.text)


## The same squad command a human boss's seat gives in co-op (StationApp),
## reached from the villa desk directly: claim the seat for as long as this
## lasts, so Session.seat_driver stands the ground war's AI aside exactly as
## it already does for a human lieutenant - and hand it straight back on Q
## again or on leaving the desk.
func _enter_squad_mode() -> void:
	var name: String = s.seats.seats[Roles.PILOT].name if s.seats != null else "Boss"
	var err := s.seats.claim(Roles.BOSS, name if name != "" else "Boss", "")
	if err != "":
		s.say(err)
		return
	_claimed_boss = true
	squad_mode = true
	sel_squad = null


func _leave_squad_mode() -> void:
	if _claimed_boss:
		s.seats.release(Roles.BOSS)
		_claimed_boss = false
	squad_mode = false
	districts_open = false
	sel_squad = null


func _my_squads() -> Array:
	return s.ground.of("org") if s.ground != null else []


func _squad_detail() -> void:
	var q = s.ground.get_squad(str(sel_squad)) if sel_squad != null else null
	if q == null:
		squad_label.text = "- (click a squad)"
		return
	squad_label.text = preload("res://scripts/ui/widgets/squad_card.gd").describe(s.ground.squad_view(q, "org"))


func _squad_key(k: String) -> void:
	var raise := {"raise_foot": "foot", "raise_car": "car", "raise_truck": "truck"}
	if raise.has(k):
		var res: Array = s.command(Roles.BOSS, "recruit_squad", {"kind": raise[k]})
		if not res[0]:
			s.say(res[1])
		return
	if sel_squad == null:
		return
	match k:
		"melt":
			s.command(Roles.BOSS, "squad_order", {"id": sel_squad, "order": {"type": "melt"}})
		"hold":
			s.command(Roles.BOSS, "squad_order", {"id": sel_squad, "order": {"type": "hold"}})
		"disband":
			perform_action("disband_squad", {"id": sel_squad}, Roles.BOSS)


## Click: pick one of ours. Right-click: the order that fits the spot - a
## stash (guard it), an enemy squad (go after it), or anywhere else (patrol).
func _on_map_click(button: int, p: Vector2) -> void:
	if not squad_mode or districts_open:
		return
	if button == MOUSE_BUTTON_LEFT:
		var d = Py.min_by(_my_squads(), func(o): return PyMath.hypot(o.x - p.x, o.y - p.y))
		sel_squad = d.id if d != null and PyMath.hypot(d.x - p.x, d.y - p.y) < 1200 else null
		_squad_detail()
		return
	if button != MOUSE_BUTTON_RIGHT or sel_squad == null:
		return
	var enemy = Py.min_by(s.ground.visible_to("org").filter(func(q): return q.faction != "org"), func(o): return PyMath.hypot(o.x - p.x, o.y - p.y))
	var stash = Py.min_by(s.stash_net.stashes if s.stash_net != null else [], func(o): return PyMath.hypot(o.x - p.x, o.y - p.y))
	var o := {}
	if enemy != null and PyMath.hypot(enemy.x - p.x, enemy.y - p.y) < 500:
		o = {"type": "attack", "squad": enemy.id}
	elif stash != null and PyMath.hypot(stash.x - p.x, stash.y - p.y) < 700:
		o = {"type": "guard", "stash": stash.id}
	else:
		o = {"type": "patrol_zone", "x": p.x, "y": p.y, "market": GroundWar.market_at(p.x, p.y)}
	var res: Array = s.command(Roles.BOSS, "squad_order", {"id": sel_squad, "order": o})
	if not res[0]:
		s.say(res[1])
	_squad_detail()
