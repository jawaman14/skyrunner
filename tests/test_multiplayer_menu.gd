extends TestCase
## The multiplayer menu: what it lists (the table, the games on the network), muting and removing people, joining, the
## voice settings it saves, and F4 opening it from the game's main node.

const TMP := "user://zz_mp_menu.cfg"

var _sess: Session
var _srv: HostServer
var _links: Array = []


func _tree() -> SceneTree:
	return Engine.get_main_loop()


func after_each() -> void:
	for c in _links:
		c.close()
		c.free()
	_links.clear()
	if _srv != null:
		_srv.stop()
		_srv.free()
		_srv = null
	if _sess != null:
		_sess.dispose()
		_sess = null
	DirAccess.remove_absolute(TMP)
	DirAccess.remove_absolute(VoiceSettings.PATH)


func _hosted() -> void:
	_sess = Session.new({"seed": 4, "mode": Roles.VERSUS, "features": Session.SANDBOX_FEATURES})
	_srv = HostServer.new()
	_srv.attach(_sess)
	_srv.host_name = "Barry"
	_srv.start(0, Roles.VERSUS, "127.0.0.1")


func _join(name: String, role: String) -> NetClient:
	var c := NetClient.new().open("127.0.0.1", _srv.port, name, role)
	_links.append(c)
	return c


func _pump_until(cond: Callable, secs := 5.0) -> bool:
	var end := Time.get_ticks_msec() + int(secs * 1000)
	while Time.get_ticks_msec() < end:
		_srv._process(0.0)
		for c in _links:
			c.poll()
		_srv.pump(_sess)
		_sess.update(1.0 / 60)
		if cond.call():
			return true
		OS.delay_msec(5)
	return false


func _menu(finder = null, voice = null) -> MultiplayerMenu:
	var m := MultiplayerMenu.new()
	_tree().root.add_child(m)
	m.setup(_srv, null, voice, finder)
	return m


func test_the_host_sees_the_table_and_can_mute_and_remove() -> void:
	_hosted()
	var rosa := _join("Rosa", Roles.COPILOT)
	var lee := _join("Lee", Roles.CONTROLLER)
	check(_pump_until(func(): return rosa.welcome != null and lee.welcome != null), "both seated")
	var m := _menu()
	var r := m.roster()
	check_eq(r.size(), 3, "the host and two players")
	check(r[0].me and r[0].host and r[0].name == "Barry", "the host first, and it is you")
	check(not r[1].me and r[1].role == Roles.COPILOT, "Rosa the co-pilot")
	check(r[1].id != "" and r[1].id != rosa.token, "with a public id that is not her reconnect token")
	check(not r[1].muted and not r[1].talking, "not muted, not talking")
	m.set_muted(r[1].id, true)
	check(m.roster()[1].muted, "muting Rosa shows in the roster")
	check(m.settings.is_muted(r[1].id), "and in the settings")
	check(VoiceSettings.load_from().is_muted(r[1].id), "and on disk")
	check(m.kick(r[2].id), "the host removes Lee")
	check(_pump_until(func(): return lee.error != null), "Lee is told")
	check_eq(m.roster().size(), 2, "and he is off the roster")
	check(not m.kick("host"), "the host cannot remove itself")
	m.close()


func test_a_talking_player_gets_a_dot() -> void:
	_hosted()
	var rosa := _join("Rosa", Roles.COPILOT)
	check(_pump_until(func(): return rosa.welcome != null), "Rosa is in")
	var voice := VoiceChat.new()
	_tree().root.add_child(voice)
	voice.settings = VoiceSettings.new()
	var m := _menu(null, voice)
	var id: String = m.roster()[1].id
	voice.hear({"t": "voice", "from": "Rosa", "id": id, "role": Roles.COPILOT, "ch": "net", "s": 1, "q": 0.9, "k": "net", "d": VoiceCodec.pack(PackedFloat32Array([0.0, 0.1])), "end": false})
	check(m.roster()[1].talking, "Rosa is talking")
	voice.hear({"t": "voice", "from": "Rosa", "id": id, "role": Roles.COPILOT, "ch": "net", "s": 2, "q": 0.9, "k": "net", "d": "", "end": true})
	check(not m.roster()[1].talking, "and then not")
	m.close()
	voice.queue_free()


func test_the_games_tab_lists_what_the_finder_heard() -> void:
	_hosted()
	var f := LanDiscovery.Finder.new()
	_tree().root.add_child(f)
	f.ingest(LanDiscovery.beacon("Amy's game", 47800, "versus", 3), "192.168.1.31")
	var m := _menu(f)
	check_eq(m.games_list.item_count, 1, "one game in the list")
	check(m.games_list.get_item_text(0).contains("Amy's game") and m.games_list.get_item_text(0).contains("192.168.1.31:47800"), "named, with where to find it: %s" % m.games_list.get_item_text(0))
	var asked := []
	m.join_requested.connect(func(a, r, n): asked.append([a, r, n]))
	m._join_game(0)
	check_eq(asked, [["192.168.1.31:47800", "", "player"]], "joining it asks for that address, with no seat chosen")
	m.addr.text = "10.0.0.7:47800"
	m.role_ob.select(1)
	m.name_le.text = "Zed"
	m._join_address()
	check_eq(asked.back(), ["10.0.0.7:47800", "copilot", "Zed"], "joining by address carries the seat and the name")
	m.addr.text = ""
	var n := asked.size()
	m._join_address()
	check_eq(asked.size(), n, "an empty address asks for nothing")
	m.close()
	f.queue_free()


func test_hosting_controls_reach_the_server() -> void:
	_hosted()
	var m := _menu()
	check(m.announce_cb.button_pressed and not m.lock_cb.button_pressed, "announced and open to begin with")
	m.lock_cb.button_pressed = true
	check(_srv.locked, "closing the table closes it")
	m.announce_cb.button_pressed = false
	check(not _srv.announce, "and stopping the announcement stops it")
	check(m.host_info.text.contains(str(_srv.port)), "it says where the game is: %s" % m.host_info.text)
	m.close()


func test_table_talk_goes_through_the_host() -> void:
	_hosted()
	var rosa := _join("Rosa", Roles.COPILOT)
	check(_pump_until(func(): return rosa.welcome != null), "Rosa is in")
	var m := _menu()
	m._say("Ready when you are")
	check(_pump_until(func(): return rosa.chat_log.size() >= 1), "Rosa gets the line")
	check_eq(rosa.chat_log[0].from, "Barry", "from the host")
	m.chat_to.select(1)
	m._say("team only")
	check(_pump_until(func(): return rosa.chat_log.size() >= 2), "and the side-only line, as she is on his side")
	check_eq(rosa.chat_log[1].to, "side", "marked as a team line")
	m._refresh_chat()
	check(m.chat_log.text.contains("Ready when you are"), "the log shows it")
	m.close()


func test_the_voice_settings_are_edited_and_remembered() -> void:
	_hosted()
	var m := _menu()
	m.settings.in_gain = 2.0
	m.settings.save()
	m._rebinding = true
	var ev := InputEventKey.new()
	ev.keycode = KEY_F6
	ev.physical_keycode = KEY_F6
	ev.pressed = true
	m._unhandled_key_input(ev)
	check_eq(m.settings.ptt_key, KEY_F6, "a key pressed while rebinding becomes the push-to-talk key")
	check(not m._rebinding, "and rebinding is over")
	check_eq(VoiceSettings.load_from().ptt_key, KEY_F6, "kept on disk")
	check_near(VoiceSettings.load_from().in_gain, 2.0, 0.001, "with the rest")
	check_eq(VoiceSettings.new().key_name().substr(0, 1), "`", "the default key is named as it looks")
	m.close()


func test_f4_opens_the_menu_over_a_running_game_and_esc_closes_it() -> void:
	var main: Node = load("res://scripts/main.gd").new()
	_tree().root.add_child(main)
	main.set_process(false)
	var m: MultiplayerMenu = main.open_mp()
	check(m != null and main._mp == m, "the menu is open")
	check(main.open_mp() == m, "asking again gives the same one")
	check(m.finder != null, "with the network finder behind it")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	m._unhandled_key_input(esc)
	check(main._mp == null, "ESC closes it")
	main.queue_free()
