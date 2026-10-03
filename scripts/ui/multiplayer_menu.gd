class_name MultiplayerMenu
extends CanvasLayer
## The multiplayer menu (F4 in a game, or "Multiplayer" in the lobby): three tabs.
##
##   Games   the games heard on your network (LAN discovery) and a box for an address, to join; and, when you are hosting,
##           where your game is, whether it is announced on the network, whether new players may sit down
##   Table   who is at the table (the roster, with a dot for whoever is talking), mute anyone, kick anyone (the host),
##           take or leave a seat, and the table's chat
##   Voice   push-to-talk radio settings: the microphone, the key, the volumes, how much radio is in your voice, a
##           loop-back test with a level meter, and voice chat on/off
##
## It knows the game only through what it is given (`server` when you host, `link` when you joined, `voice` the VoiceChat,
## `finder` the LAN finder), so the same menu works from the lobby with none of them. It asks for nothing itself:
## `join_requested(address, role, name)` is the lobby's or the game's to act on.

signal closed
signal join_requested(address: String, role: String, player_name: String)

const REFRESH_S := 0.5
const JOIN_ROLES := ["", "copilot", "spotter", "boat", "boss", "lieutenant", "controller", "interceptor", "cutter", "chief", "patrol"]

var server: HostServer = null
var link: NetClient = null
var voice: VoiceChat = null
var finder: LanDiscovery.Finder = null
var settings: VoiceSettings = VoiceSettings.new()
var player_name := "player"

var tabs: TabContainer
var games_list: ItemList
var games_status: Label
var addr: LineEdit
var name_le: LineEdit
var role_ob: OptionButton
var host_info: Label
var lock_cb: CheckBox
var announce_cb: CheckBox
var roster_box: VBoxContainer
var chat_log: RichTextLabel
var chat_in: LineEdit
var chat_to: OptionButton
var seat_ob: OptionButton
var _t := 0.0
var _sig := ""
var _key_btn: Button = null
var _rebinding := false
var _mic_ob: OptionButton
var _meter: ProgressBar
var _loop_btn: Button
var _games: Array = []


func setup(server_ = null, link_ = null, voice_ = null, finder_ = null) -> MultiplayerMenu:
	server = server_
	link = link_
	voice = voice_
	finder = finder_
	settings = voice.settings if voice != null else VoiceSettings.load_from()
	layer = 62  # over the pause menu (60), under the controls panel (70)
	name = "MultiplayerMenu"
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIStyle.theme()
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.box(Color(0.05, 0.03, 0.09, 0.97), 10, UIStyle.ACCENT, 2, Vector4(26, 18, 26, 18)))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(760, 520)
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(UIStyle.title("Multiplayer", 36, UIStyle.ACCENT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var x := Button.new()
	x.text = "Close (ESC)"
	x.pressed.connect(close)
	head.add_child(x)
	v.add_child(head)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	_build_games()
	if server != null or link != null:
		_build_table()
	_build_voice()
	refresh()
	return self


func close() -> void:
	if voice != null:
		voice.set_loopback(false)
	closed.emit()
	queue_free()


func _unhandled_key_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	if _rebinding:
		if ev.keycode != KEY_ESCAPE:
			settings.ptt_key = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
			settings.save()
		_rebinding = false
		_refresh_key_btn()
		get_viewport().set_input_as_handled()
		return
	if ev.keycode == KEY_ESCAPE or ev.keycode == KEY_F4:
		close()
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	_t += dt
	if _t >= REFRESH_S:
		_t = 0.0
		refresh()
	if _meter != null and voice != null:
		_meter.value = voice.level()


# ------------------------------------------------------------------ the tabs
func _page(title: String) -> VBoxContainer:
	var m := MarginContainer.new()
	m.name = title
	for k in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + k, 10)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	tabs.add_child(m)
	return v


func _build_games() -> void:
	var v := _page("Games")
	v.add_child(UIStyle.caption("GAMES ON YOUR NETWORK"))
	games_list = ItemList.new()
	games_list.custom_minimum_size = Vector2(0, 130)
	games_list.item_activated.connect(func(i): _join_game(i))
	v.add_child(games_list)
	games_status = UIStyle.label("", 14, UIStyle.DIM)
	games_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(games_status)
	var b := HBoxContainer.new()
	var jb := Button.new()
	jb.text = "Join the selected game"
	jb.pressed.connect(func():
		var s := games_list.get_selected_items()
		if not s.is_empty():
			_join_game(s[0]))
	b.add_child(jb)
	v.add_child(b)
	v.add_child(HSeparator.new())
	v.add_child(UIStyle.caption("JOIN BY ADDRESS"))
	var j := HBoxContainer.new()
	j.add_theme_constant_override("separation", 8)
	addr = LineEdit.new()
	addr.placeholder_text = "host:47800 (password@host:47800)"
	addr.custom_minimum_size = Vector2(190, 0)
	role_ob = OptionButton.new()
	for r in JOIN_ROLES:
		role_ob.add_item(r if r != "" else "pick a seat")
	name_le = LineEdit.new()
	name_le.placeholder_text = "your name"
	name_le.text = player_name if player_name != "player" else ""
	var go := Button.new()
	go.text = "Join"
	go.pressed.connect(func(): _join_address())
	addr.text_submitted.connect(func(_t): _join_address())
	for c in [addr, role_ob, name_le, go]:
		j.add_child(c)
	v.add_child(j)
	if server != null:
		v.add_child(HSeparator.new())
		v.add_child(UIStyle.caption("YOU ARE HOSTING"))
		host_info = UIStyle.label("", 15, UIStyle.CYAN)
		host_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(host_info)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		announce_cb = CheckBox.new()
		announce_cb.text = "Show this game to people on my network"
		announce_cb.button_pressed = server.announce
		announce_cb.toggled.connect(func(on): server.announce = on)
		lock_cb = CheckBox.new()
		lock_cb.text = "Close the table to new players"
		lock_cb.button_pressed = server.locked
		lock_cb.toggled.connect(func(on): server.locked = on)
		hb.add_child(announce_cb)
		hb.add_child(lock_cb)
		v.add_child(hb)


func _build_table() -> void:
	var v := _page("Table")
	v.add_child(UIStyle.caption("WHO IS AT THE TABLE"))
	roster_box = VBoxContainer.new()
	roster_box.add_theme_constant_override("separation", 4)
	v.add_child(roster_box)
	if link != null:
		var sb := HBoxContainer.new()
		sb.add_theme_constant_override("separation", 8)
		sb.add_child(UIStyle.label("My seat", 15))
		seat_ob = OptionButton.new()
		sb.add_child(seat_ob)
		var take := Button.new()
		take.text = "Take it"
		take.pressed.connect(func():
			if seat_ob.selected >= 0:
				link.claim(str(seat_ob.get_item_metadata(seat_ob.selected))))
		var leave := Button.new()
		leave.text = "Give it back to the AI"
		leave.pressed.connect(func(): link.release())
		sb.add_child(take)
		sb.add_child(leave)
		v.add_child(sb)
	v.add_child(HSeparator.new())
	v.add_child(UIStyle.caption("TABLE TALK"))
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = false
	chat_log.scroll_following = true
	chat_log.custom_minimum_size = Vector2(0, 110)
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(chat_log)
	var cr := HBoxContainer.new()
	cr.add_theme_constant_override("separation", 8)
	chat_to = OptionButton.new()
	chat_to.add_item("to everyone")
	chat_to.add_item("to my side")
	chat_in = LineEdit.new()
	chat_in.placeholder_text = "type and press ENTER (or hold ` to talk)"
	chat_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_in.text_submitted.connect(func(t): _say(t))
	cr.add_child(chat_to)
	cr.add_child(chat_in)
	v.add_child(cr)


func _build_voice() -> void:
	var v := _page("Voice")
	var en := CheckBox.new()
	en.text = "Voice chat on"
	en.button_pressed = settings.enabled
	en.toggled.connect(func(on):
		settings.enabled = on
		settings.save())
	v.add_child(en)
	var kr := HBoxContainer.new()
	kr.add_theme_constant_override("separation", 8)
	kr.add_child(UIStyle.label("Push to talk", 15))
	_key_btn = Button.new()
	_key_btn.pressed.connect(func():
		_rebinding = true
		_key_btn.text = "press a key (ESC cancels)")
	kr.add_child(_key_btn)
	kr.add_child(UIStyle.label("hold it for your side's net; with SHIFT, the whole table", 13, UIStyle.DIM))
	v.add_child(kr)
	_refresh_key_btn()
	var mr := HBoxContainer.new()
	mr.add_theme_constant_override("separation", 8)
	mr.add_child(UIStyle.label("Microphone", 15))
	_mic_ob = OptionButton.new()
	_mic_ob.custom_minimum_size = Vector2(300, 0)
	var devs: PackedStringArray = AudioServer.get_input_device_list()
	var sel := 0
	for i in devs.size():
		_mic_ob.add_item(devs[i])
		if devs[i] == (settings.device if settings.device != "" else AudioServer.input_device):
			sel = i
	if devs.is_empty():
		_mic_ob.add_item("(no microphone found: you can listen)")
		_mic_ob.disabled = true
	else:
		_mic_ob.select(sel)
	_mic_ob.item_selected.connect(func(i):
		if voice != null:
			voice.use_device(_mic_ob.get_item_text(i))
		else:
			settings.device = _mic_ob.get_item_text(i)
			settings.save())
	mr.add_child(_mic_ob)
	v.add_child(mr)
	_slider(v, "Microphone volume", 0.0, 4.0, settings.in_gain, func(x): settings.in_gain = x)
	_slider(v, "Radio volume", 0.0, 2.0, settings.out_volume, func(x): settings.out_volume = x)
	_slider(v, "Radio effect", 0.0, 1.0, settings.effect, func(x): settings.effect = x)
	var note := UIStyle.label("0 is your friends' own voices, 1 is a crackling radio: band-limited, hissy at the edge of range, dropouts, squelch clicks.", 13, UIStyle.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(700, 0)
	v.add_child(note)
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 8)
	_loop_btn = Button.new()
	_loop_btn.toggle_mode = true
	_loop_btn.text = "Test: hear myself over the radio"
	_loop_btn.disabled = voice == null or not voice.has_mic()
	_loop_btn.toggled.connect(func(on):
		if voice != null:
			voice.set_loopback(on))
	tr.add_child(_loop_btn)
	_meter = ProgressBar.new()
	_meter.min_value = 0.0
	_meter.max_value = 1.0
	_meter.custom_minimum_size = Vector2(200, 18)
	_meter.show_percentage = false
	tr.add_child(_meter)
	v.add_child(tr)
	if voice == null or not voice.has_mic():
		var warn := UIStyle.label("No microphone is open (plug one in and restart the game): you can still hear everyone.", 13, UIStyle.AMBER)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.custom_minimum_size = Vector2(700, 0)
		v.add_child(warn)


func _slider(v: VBoxContainer, text: String, lo: float, hi: float, val: float, set_fn: Callable) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	var l := UIStyle.label(text, 15)
	l.custom_minimum_size = Vector2(160, 0)
	r.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(260, 0)
	s.value_changed.connect(func(x):
		set_fn.call(x)
		settings.save())
	r.add_child(s)
	v.add_child(r)


func _refresh_key_btn() -> void:
	if _key_btn != null:
		_key_btn.text = settings.key_name()


# ------------------------------------------------------------------ acting
func _join_game(i: int) -> void:
	if i < 0 or i >= _games.size():
		return
	var g: Dictionary = _games[i]
	join_requested.emit("%s:%d" % [g.ip, g.port], "", _name())


func _join_address() -> void:
	var a := addr.text.strip_edges()
	if a == "":
		games_status.text = "Enter the host's address (host:port)."
		return
	join_requested.emit(a, JOIN_ROLES[role_ob.selected], _name())


func _name() -> String:
	return name_le.text.strip_edges() if name_le != null and name_le.text.strip_edges() != "" else player_name


func _say(text: String) -> void:
	var t := text.strip_edges()
	if t == "":
		return
	var to := "side" if chat_to != null and chat_to.selected == 1 else "all"
	if server != null:
		server.chat(server.host_name, server.host_role, t, to)
	elif link != null:
		link.say(t, to)
	chat_in.text = ""


## Mute (or unmute) a player by their public id.
func set_muted(id: String, on: bool) -> void:
	settings.set_muted(id, on)
	settings.save()
	if voice != null and on:
		voice.talking.erase(id)


## Remove a player (the host only).
func kick(id: String) -> bool:
	return server != null and server.kick(id)


# ------------------------------------------------------------------ what it shows
## The table as the menu lists it: [{id, name, role, host, talking, muted, me}], the host first.
func roster() -> Array:
	var out := []
	var talk := {}
	if voice != null:
		for t in voice.talkers():
			talk[str(t.id)] = t
		if voice.transmitting:
			talk["host" if server != null else "me"] = {"ch": voice.channel}
	if server != null:
		for r in server.roster():
			out.append({"id": r.id, "name": r.name, "role": r.role, "host": r.host, "talking": talk.has(r.id), "muted": settings.is_muted(r.id), "me": r.id == "host"})
	elif link != null:
		for p in link.players:
			out.append({"id": str(p.get("id", "")), "name": str(p.get("name", "")), "role": str(p.get("role", "")), "host": str(p.get("id", "")) == "host",
				"talking": talk.has(str(p.get("id", ""))) or (str(p.get("name", "")) == link.name_ and talk.has("me")), "muted": settings.is_muted(str(p.get("id", ""))),
				"me": str(p.get("name", "")) == link.name_})
	return out


func refresh() -> void:
	_games = finder.list() if finder != null else []
	if games_list != null:
		games_list.clear()
		for g in _games:
			games_list.add_item("%s   -   %s:%d   -   %s, %d at the table%s" % [g.name, g.ip, g.port, g.mode, g.players, "  (closed)" if g.locked else ""])
		if finder == null:
			games_status.text = "Looking for games needs the network finder (it runs from the lobby and in a game)."
		elif not finder.listening:
			games_status.text = "Could not listen for games here (another copy of Skyrunner on this machine may be). You can still join by address."
		elif _games.is_empty():
			games_status.text = "No games heard yet. A host on your network shows up here within a couple of seconds."
		else:
			games_status.text = "%d game%s on your network. Double-click one to join." % [_games.size(), "" if _games.size() == 1 else "s"]
	if host_info != null and server != null:
		var ips := LanDiscovery.local_addresses()
		host_info.text = "Port %d on %s. Friends join with: --connect %s:%d (or find this game in their list)." % [server.port, ", ".join(ips) if not ips.is_empty() else "this machine", ips[0] if not ips.is_empty() else "YOUR_IP", server.port]
	if roster_box != null:
		_refresh_roster()
	if chat_log != null:
		_refresh_chat()
	if seat_ob != null and link != null:
		_refresh_seats()


func _refresh_roster() -> void:
	var rows := roster()
	var sig := JSON.stringify(rows)
	if sig == _sig:
		return
	_sig = sig
	for c in roster_box.get_children():
		c.queue_free()
	if rows.is_empty():
		roster_box.add_child(UIStyle.label("Nobody else is here yet.", 14, UIStyle.DIM))
	for r in rows:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var dot := UIStyle.label("●" if r.talking else "○", 16, UIStyle.GREEN if r.talking else UIStyle.DIM)
		dot.custom_minimum_size = Vector2(22, 0)
		h.add_child(dot)
		var nm := UIStyle.label("%s%s" % [r.name, "  (you)" if r.me else ("  (host)" if r.host else "")], 16)
		nm.custom_minimum_size = Vector2(240, 0)
		h.add_child(nm)
		var seat := UIStyle.label(r.role if r.role != "" else "no seat", 15, UIStyle.CAPTION)
		seat.custom_minimum_size = Vector2(120, 0)
		h.add_child(seat)
		if not r.me and r.id != "":
			var mute := CheckBox.new()
			mute.text = "mute"
			mute.button_pressed = r.muted
			var id: String = r.id
			mute.toggled.connect(func(on): set_muted(id, on))
			h.add_child(mute)
			if server != null and not r.host:
				var kb := Button.new()
				kb.text = "remove"
				kb.pressed.connect(func(): kick(id))
				h.add_child(kb)
		roster_box.add_child(h)


func _refresh_chat() -> void:
	var lines := []
	var log: Array = []
	if server != null:
		log = server.chat_log.map(func(c): return {"from": c[0], "role": c[1], "to": c[4], "text": c[3]})
	elif link != null:
		log = link.chat_log
	for c in log.slice(maxi(0, log.size() - 40)):
		lines.append("%s%s: %s" % ["(team) " if str(c.get("to", "")) == "side" else "", str(c.get("from", "")), str(c.get("text", ""))])
	var text := "\n".join(lines)
	if chat_log.text != text:
		chat_log.text = text


func _refresh_seats() -> void:
	var cur := ""
	if seat_ob.selected >= 0:
		cur = str(seat_ob.get_item_metadata(seat_ob.selected))
	seat_ob.clear()
	var free := []
	for s in link.seats:
		var who := str(s.get("who", ""))
		if who == "" or who == "ai":
			free.append(s)
	for s in free:
		seat_ob.add_item("%s (%s)" % [s.role, "AI plays it"])
		seat_ob.set_item_metadata(seat_ob.item_count - 1, s.role)
		if str(s.role) == cur:
			seat_ob.select(seat_ob.item_count - 1)
