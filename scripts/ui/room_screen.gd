class_name RoomScreen
extends Control
## The multiplayer waiting room: every seat in the game by side (runners, the task force) with who has it (a player, or the AI),
## the players with their seats and whether they are ready, the table's chat, and the buttons: take or give back a seat, ready,
## and (the host) Start. The host builds it from its own `server`, a guest from its `link`; nobody sits in the 3D seat or a desk
## until the host starts, at which point `started(role)` tells a guest which seat is theirs.

signal start_game  ## the host pressed Start
signal started(role: String)  ## a guest: the game began; your seat ("" if you have none: pick one in the game)
signal game_running  ## a guest joined a game that is already on (no waiting room): pick a seat the old way
signal cancelled  ## the host closed the room, or a guest left
signal seated(role: String)  ## a running game's seat claim was confirmed

var server: HostServer = null
var link: NetClient = null
var title_lbl: Label
var info_lbl: Label
var status: Label
var seats_box: VBoxContainer
var players_box: VBoxContainer
var chat_log: RichTextLabel
var chat_in: LineEdit
var ready_cb: CheckBox
var start_btn: Button
var lock_cb: CheckBox
var _sig := ""
var _t := 0.0
var _joined := false
var running_mode := false
var table: DataTable
var _keys: Array = []
var _palette := ""
var _pending_role := ""
var _pending_at := 0
var _closed := false
var _local_error := ""


func setup(server_ = null, link_ = null, running_ := false) -> RoomScreen:
	server = server_
	link = link_
	running_mode = running_
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.theme()
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.04, 0.055)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + k, 28)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	title_lbl = UIStyle.title("Take a seat" if running_mode else "Waiting room", 36, UIStyle.ACCENT)
	v.add_child(title_lbl)
	info_lbl = UIStyle.label("", 15, UIStyle.CYAN)
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info_lbl)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 22)
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.6
	left.add_child(UIStyle.caption("SEATS: pick one (anything nobody takes is played by the AI)"))
	if running_mode:
		table = DataTable.new().setup([{"title": "Role", "min": 110}, {"title": "Side", "min": 70},
			{"title": "Seat", "min": 120}, {"title": "What you do", "expand": true, "ratio": 3}])
		table.row_activated.connect(func(_i): claim_selected())
		left.add_child(table)
	else:
		seats_box = VBoxContainer.new()
		seats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seats_box.add_theme_constant_override("separation", 3)
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.add_child(seats_box)
		left.add_child(sc)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UIStyle.caption("AT THE TABLE"))
	players_box = VBoxContainer.new()
	players_box.add_theme_constant_override("separation", 3)
	var players_scroll := ScrollContainer.new()
	players_scroll.custom_minimum_size.y = 100
	players_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	players_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_scroll.add_child(players_box)
	right.add_child(players_scroll)
	right.add_child(HSeparator.new())
	right.add_child(UIStyle.caption("TABLE TALK"))
	chat_log = RichTextLabel.new()
	chat_log.scroll_following = true
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(chat_log)
	chat_in = LineEdit.new()
	chat_in.placeholder_text = "say something and press ENTER"
	chat_in.max_length = 200
	chat_in.text_submitted.connect(func(t): _say(t))
	right.add_child(chat_in)
	cols.add_child(right)
	status = UIStyle.label("", 15, UIStyle.AMBER)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(status)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	if server != null:
		start_btn = Button.new()
		start_btn.text = "START THE GAME"
		start_btn.custom_minimum_size = Vector2(240, 46)
		start_btn.add_theme_font_size_override("font_size", 20)
		start_btn.pressed.connect(_start)
		bar.add_child(start_btn)
		lock_cb = CheckBox.new()
		lock_cb.text = "Close the table to new players"
		lock_cb.toggled.connect(func(on): server.locked = on)
		bar.add_child(lock_cb)
	elif not running_mode:
		ready_cb = CheckBox.new()
		ready_cb.text = "I'm ready"
		ready_cb.toggled.connect(func(on): link.set_ready(on))
		bar.add_child(ready_cb)
	var back := Button.new()
	back.text = "Close the room" if server != null else "Leave"
	back.pressed.connect(_cancel)
	bar.add_child(back)
	v.add_child(bar)
	if link != null:
		link.started.connect(func(r): started.emit(r))
		if running_mode:
			link.role_changed.connect(func(r):
				if r != "" and not _closed:
					_closed = true
					seated.emit(r))
	refresh()
	if running_mode:
		table.grab_focus.call_deferred()
	return self


func _process(dt: float) -> void:
	if _closed:
		return
	if not running_mode and link != null and link.welcome != null and link.phase == "game" and not _joined:
		_joined = true
		game_running.emit()
		return
	_t += dt
	if _t >= 0.2:
		_t = 0.0
		refresh()


# ------------------------------------------------------------------ what it shows
## The room as one dictionary, from the host's own Room or the last one the host sent: {mode, players, seats, start}.
func view() -> Dictionary:
	if server != null and server.room != null:
		return server.room.to_dict()
	if link != null:
		if running_mode:
			var players := []
			for p in link.players:
				players.append({"id": p.get("id", ""), "name": p.get("name", "?"),
					"role": p.get("role", ""), "host": p.get("host", false), "ready": true})
			return {"mode": "game", "players": players, "seats": link.seats}
		return link.room_state
	return {}


func _me() -> String:
	if server != null:
		return Room.HOST
	if link != null and link.token != "":
		return HostServer.public_id(link.token)
	return ""


func refresh() -> void:
	if _closed:
		return
	var d := view()
	if d.is_empty():
		info_lbl.text = "Joining..." if link != null and link.error == null else (str(link.error) if link != null else "")
		return
	var mode_name: String = {"coop": "Co-op: friends crew for you", "versus": "Versus: friends run the task force"}.get(str(d.mode), str(d.mode))
	if server != null:
		var ips := LanDiscovery.local_addresses()
		info_lbl.text = "%s.  Friends join with:  --connect %s:%d   (or find this game in the Multiplayer list)" % [mode_name, ips[0] if not ips.is_empty() else "YOUR_IP", server.port]
	elif running_mode:
		info_lbl.text = "AI crews keep untaken seats running. Select a role and press Enter, or double-click. T opens chat."
	else:
		info_lbl.text = "%s.  The host starts the game when everyone has a seat and is ready." % mode_name
	if _palette != UIStyle.palette:
		_palette = UIStyle.palette
		theme = UIStyle.theme()
		title_lbl.add_theme_color_override("font_color", UIStyle.ACCENT)
		info_lbl.add_theme_color_override("font_color", UIStyle.CYAN)
		status.add_theme_color_override("font_color", UIStyle.AMBER)
		if table != null:
			table.theme = theme
		_sig = ""
	var sig := JSON.stringify(d) + str(link.claim_error if link != null else "")
	if sig != _sig:
		_sig = sig
		if running_mode:
			_draw_running_seats(d)
		else:
			_draw_seats(d)
		_draw_players(d)
	_draw_status(d)
	_draw_chat()


func _draw_seats(d: Dictionary) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var focused_role := str(focus.get_meta("seat_role", "")) if focus != null else ""
	for c in seats_box.get_children():
		seats_box.remove_child(c)
		c.queue_free()
	var side := ""
	var me := _me()
	var my_role := ""
	for p in d.players:
		if str(p.id) == me:
			my_role = str(p.role)
	for s in d.seats:
		if str(s.side) != side:
			side = str(s.side)
			seats_box.add_child(UIStyle.caption("THE RUNNERS" if side == "runner" else "THE TASK FORCE"))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var rn := UIStyle.label(str(s.role).capitalize(), 16)
		rn.custom_minimum_size = Vector2(120, 0)
		h.add_child(rn)
		var about := UIStyle.label(str(s.about), 13, UIStyle.CAPTION)
		about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		about.clip_text = true
		h.add_child(about)
		var who := UIStyle.label("", 15)
		who.custom_minimum_size = Vector2(130, 0)
		match str(s.who):
			"player":
				who.text = str(s.name) + ("  (you)" if str(s.id) == me else "")
				who.add_theme_color_override("font_color", UIStyle.GREEN)
			"ai":
				who.text = "the AI"
				who.add_theme_color_override("font_color", UIStyle.DIM)
			_:
				who.text = "not in this game"
				who.add_theme_color_override("font_color", UIStyle.CAPTION)
		h.add_child(who)
		var role: String = s.role
		if str(s.who) == "ai":
			var b := Button.new()
			b.text = "Take"
			b.set_meta("seat_role", role)
			b.pressed.connect(func(): _take(role))
			h.add_child(b)
			if role == focused_role:
				b.grab_focus.call_deferred()
		elif str(s.id) == me and server == null:
			var b := Button.new()
			b.text = "Give back"
			b.set_meta("seat_role", role)
			b.pressed.connect(func(): link.room_release())
			h.add_child(b)
			if role == focused_role:
				b.grab_focus.call_deferred()
		else:
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(76, 0)
			h.add_child(sp)
		seats_box.add_child(h)


func _draw_players(d: Dictionary) -> void:
	for c in players_box.get_children():
		players_box.remove_child(c)
		c.queue_free()
	var me := _me()
	for p in d.players:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var ok := UIStyle.label("✔" if bool(p.ready) else "…", 16, UIStyle.GREEN if bool(p.ready) else UIStyle.DIM)
		ok.custom_minimum_size = Vector2(22, 0)
		h.add_child(ok)
		var nm := UIStyle.label("%s%s" % [p.name, "  (you)" if str(p.id) == me else ("  (host)" if bool(p.host) else "")], 16)
		nm.custom_minimum_size = Vector2(170, 0)
		nm.clip_text = true
		h.add_child(nm)
		h.add_child(UIStyle.label(str(p.role) if str(p.role) != "" else "no seat yet", 14, UIStyle.CAPTION))
		if server != null and not bool(p.host):
			var kb := Button.new()
			kb.text = "remove"
			var id: String = p.id
			kb.pressed.connect(func(): server.kick(id))
			h.add_child(kb)
		players_box.add_child(h)


func _draw_status(d: Dictionary) -> void:
	if link != null and link.error != null:
		status.text = str(link.error) + (" Seat result unknown." if _pending_role != "" else "")
		return
	if _pending_role != "":
		var mine := link.role if running_mode else ""
		if not running_mode:
			for p in d.players:
				if str(p.id) == _me(): mine = str(p.role)
		if mine == _pending_role or link.claim_error != null:
			_pending_role = ""
		else:
			status.text = "Waiting for the host to confirm %s…" % _pending_role
			if Time.get_ticks_msec() - _pending_at > 15000:
				status.text = "Seat result unknown. Leave and reconnect to check; no request was resent."
			return
	if running_mode:
		status.text = str(link.claim_error) if link.claim_error != null else (_local_error if _local_error != "" else "Select an AI seat to take it. Leave returns to the lobby.")
		return
	var why := ""
	if server != null:
		why = server.room.can_start() if server.room != null else ""
		start_btn.disabled = why != ""
		status.text = why if why != "" else "Everyone is ready. Start when you like."
	else:
		var me := _me()
		var mine := ""
		for p in d.players:
			if str(p.id) == me:
				mine = str(p.role)
		if link != null and link.claim_error != null:
			status.text = str(link.claim_error)
		elif mine == "":
			status.text = "Pick a seat on the left (or stay without one and take it in the game)."
		else:
			status.text = "You are the %s. Tick ready when you are happy with it." % mine
		ready_cb.disabled = mine == ""


func _draw_chat() -> void:
	var log: Array = []
	if server != null:
		log = server.chat_log.map(func(c): return {"from": c[0], "text": c[3]})
	elif link != null:
		log = link.chat_log
	var lines := []
	for c in log.slice(maxi(0, log.size() - 30)):
		lines.append("%s: %s" % [str(c.get("from", "")), str(c.get("text", ""))])
	var text := "\n".join(lines)
	if chat_log.text != text:
		chat_log.text = text


# ------------------------------------------------------------------ acting
func _take(role: String) -> void:
	if _closed or _pending_role != "":
		return
	if server != null:
		var why := server.host_claim(role)
		if why != "":
			status.text = why
	elif link != null:
		if not link.alive():
			_local_error = "Disconnected. No seat request was sent."
			status.text = _local_error
			return
		_local_error = ""
		link.claim_error = null
		_pending_role = role
		_pending_at = Time.get_ticks_msec()
		if running_mode:
			link.claim(role)
		else:
			link.room_claim(role)
		_draw_status(view())


func _say(text: String) -> void:
	var t := text.strip_edges()
	if t == "":
		return
	if server != null:
		server.chat(server.host_name, "", t, "all")
	elif link != null:
		link.say(t)
	chat_in.text = ""


func _start() -> void:
	if server != null and server.room != null and server.room.can_start() == "":
		start_game.emit()


func _cancel() -> void:
	if _closed:
		return
	_closed = true
	if link != null:
		link.close()
	cancelled.emit()


func _draw_running_seats(d: Dictionary) -> void:
	var selected := table.selected_row()
	var keep := str(_keys[selected]) if selected >= 0 and selected < _keys.size() else ""
	table.clear_rows()
	_keys.clear()
	for side in ["runner", "law"]:
		table.section("THE ORGANISATION" if side == "runner" else "THE TASK FORCE")
		_keys.append("")
		for s in d.seats:
			if str(s.side) != side: continue
			var who := str(s.who)
			var name_ := str(s.get("name", ""))
			var label_: String = {"ai": "AI — free", "human": "taken: " + name_,
				"reserved": "held for " + name_, "off": "not in this game"}.get(who, who)
			var color := UIStyle.GREEN if who == "ai" else (UIStyle.CAPTION if who == "off" else UIStyle.AMBER)
			table.add_row([s.role, side, label_, Roles.ABOUT.get(str(s.role), "")], {"cell_colors": {2: color}})
			_keys.append(str(s.role))
	var row := _keys.find(keep) if keep != "" else -1
	table.select_near(row if row >= 0 else 1)


func claim_selected() -> void:
	var row := table.selected_row()
	if row < 0 or row >= _keys.size() or _keys[row] == "": return
	var role := str(_keys[row])
	for seat in link.seats:
		if str(seat.role) == role and str(seat.who) != "ai":
			_local_error = "That seat is unavailable: " + str(seat.who) + "."
			status.text = _local_error
			return
	_take(role)


func key(k: String) -> void:
	if not running_mode or _closed: return
	match k:
		"up": table.move(-1)
		"down": table.move(1)
		"enter": claim_selected()
		"t": chat_in.grab_focus()
		"leave": _cancel()


func _unhandled_key_input(ev: InputEvent) -> void:
	if not running_mode or not (ev is InputEventKey and ev.pressed) or ev.echo or chat_in.has_focus(): return
	match ev.keycode:
		KEY_UP: key("up")
		KEY_DOWN: key("down")
		KEY_ENTER, KEY_KP_ENTER: key("enter")
		KEY_T: key("t")
		KEY_ESCAPE: key("leave")
		_: return
	get_viewport().set_input_as_handled()


func _input(ev: InputEvent) -> void:
	# Tree handles controller navigation, but does not activate rows with A.
	if not running_mode or _closed or not table.has_focus(): return
	if ev is InputEventJoypadButton and ev.pressed:
		match ev.button_index:
			JOY_BUTTON_A: claim_selected()
			JOY_BUTTON_B: _cancel()
			_: return
		get_viewport().set_input_as_handled()
