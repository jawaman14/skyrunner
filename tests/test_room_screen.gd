extends TestCase
## The waiting room's screen (host and guest), the host at a desk (HostDesk), and the lobby's way into the room.

var _srv: HostServer
var _links: Array = []
var _sess: Session


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
	World.use_map(0)


func _room(mode := Roles.VERSUS) -> void:
	_srv = HostServer.new()
	_srv.start_room(0, mode, "127.0.0.1", 4, "Barry")


func _pump_until(cond: Callable, secs := 5.0) -> bool:
	var end := Time.get_ticks_msec() + int(secs * 1000)
	while Time.get_ticks_msec() < end:
		_srv._process(0.0)
		for c in _links:
			c.poll()
		if cond.call():
			return true
		OS.delay_msec(5)
	return false


func _rows(box: Control, kind) -> int:
	var n := 0
	for c in box.get_children():
		if is_instance_valid(c) and not c.is_queued_for_deletion() and c is HBoxContainer:
			n += 1
	return n


func test_the_host_sees_every_seat_and_takes_one() -> void:
	_room()
	var s := RoomScreen.new()
	_tree().root.add_child(s)
	s.setup(_srv, null)
	var d := s.view()
	check_eq(d.seats.size(), 11, "every seat is in the view")
	check_eq(_rows(s.seats_box, null), 11, "and has a row on screen")
	check_eq(_rows(s.players_box, null), 1, "the host is the only one at the table")
	check(s.start_btn != null and not s.start_btn.disabled, "alone, the host can start")
	check(s.info_lbl.text.contains(str(_srv.port)), "the room says where it is: %s" % s.info_lbl.text)
	s._take(Roles.CONTROLLER)
	check_eq(_srv.room.host_role(), Roles.CONTROLLER, "taking the controller's desk moves the host")
	s._take(Roles.INTERCEPTOR)
	check(s.status.text.contains("guest"), "the police pilot's seat is refused with a reason: %s" % s.status.text)
	var started := []
	s.start_game.connect(func(): started.append(1))
	s._start()
	check_eq(started.size(), 1, "Start fires when the room is ready")
	s.queue_free()


func test_a_guest_sees_the_room_picks_a_seat_and_readies() -> void:
	_room()
	var link := NetClient.new().open("127.0.0.1", _srv.port, "Rosa", "")
	_links.append(link)
	_tree().root.add_child(link)
	var s := RoomScreen.new()
	_tree().root.add_child(s)
	s.setup(null, link)
	check(_pump_until(func(): return not link.room_state.is_empty()), "the room reaches her")
	s.refresh()
	check_eq(_rows(s.seats_box, null), 11, "she sees every seat")
	check(s.ready_cb.disabled, "she cannot ready with no seat")
	s._take(Roles.COPILOT)
	check(_pump_until(func(): return _srv.room.holder(Roles.COPILOT) != ""), "she takes the co-pilot's")
	check(_pump_until(func(): return link.room_state.players.any(func(p): return p.role == Roles.COPILOT)), "the room confirms it")
	s.refresh()
	check(s.status.text.contains("copilot"), "and says what she is: %s" % s.status.text)
	check(not s.ready_cb.disabled, "she can ready now")
	s.ready_cb.button_pressed = true
	check(_pump_until(func(): return _srv.room.players.values().any(func(p): return p.name == "Rosa" and p.ready)), "ready reaches the host")
	var cancelled := []
	s.cancelled.connect(func(): cancelled.append(1))
	s._cancel()
	check_eq(cancelled.size(), 1, "leaving tells whoever is listening")
	s.queue_free()


func test_a_guest_is_told_when_the_game_starts_and_when_there_is_no_room() -> void:
	_room()
	var link := NetClient.new().open("127.0.0.1", _srv.port, "Rosa", Roles.COPILOT)
	_links.append(link)
	_tree().root.add_child(link)
	var s := RoomScreen.new()
	_tree().root.add_child(s)
	s.setup(null, link)
	var got := []
	s.started.connect(func(r): got.append(r))
	check(_pump_until(func(): return link.welcome != null), "in")
	_sess = Session.new({"seed": 4, "mode": Roles.VERSUS, "features": Session.SANDBOX_FEATURES})
	_srv.begin(_sess)
	check(_pump_until(func(): return got.size() == 1), "the screen passes on that the game began")
	check_eq(got[0], Roles.COPILOT, "with her seat")
	s.queue_free()
	# a host that is already running a game: no waiting room for a newcomer
	var late := NetClient.new().open("127.0.0.1", _srv.port, "Late", "")
	_links.append(late)
	_tree().root.add_child(late)
	var s2 := RoomScreen.new()
	_tree().root.add_child(s2)
	s2.setup(null, late)
	var running := []
	s2.game_running.connect(func(): running.append(1))
	var end := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < end and running.is_empty():
		_srv._process(0.0)
		_srv.pump(_sess)
		_sess.update(1.0 / 60)
		late.poll()
		s2._process(0.05)
		OS.delay_msec(5)
	check_eq(running.size(), 1, "a guest who joins a game already on is sent to the seat picker")
	s2.queue_free()


func test_a_host_at_a_desk_runs_the_game_and_the_ai_flies() -> void:
	_room()
	_srv.host_claim(Roles.CONTROLLER)
	_sess = Session.new({"seed": 4, "mode": Roles.VERSUS, "features": Session.SANDBOX_FEATURES})
	_srv.begin(_sess)
	check_eq(_sess.seats.who(Roles.CONTROLLER), "human", "the host holds the controller's desk")
	check_eq(_sess.seats.who(Roles.PILOT), "ai", "and nobody holds the pilot's seat")
	var desk := HostDesk.new()
	_tree().root.add_child(desk)
	desk.setup(_sess, _srv, Roles.CONTROLLER)
	check(desk.station != null and desk.station.role == Roles.CONTROLLER, "the station for that seat is on screen")
	var t0 := _sess.time
	for i in 30:
		desk._process(0.05)
	check(_sess.time > t0 + 1.0, "the desk runs the session (%.1f s)" % (_sess.time - t0))
	check(desk.bot != null, "the AI has the aircraft")
	_sess.seats.claim(Roles.PILOT, "Rosa", "tok")
	desk._process(0.05)
	check(desk.bot == null, "until a guest takes the pilot's seat")
	desk.set_process(false)
	desk.free()  # (now: a queued desk would run one more frame on a disposed session)


func test_the_lobby_offers_the_waiting_room() -> void:
	var lobby := Lobby.new()
	_tree().root.add_child(lobby)
	var got := []
	lobby.room_requested.connect(func(o): got.append(o))
	var opts := lobby._opts()
	check(opts.has("mode") and opts.has("seed") and opts.has("graphics"), "the lobby's options are one dictionary: %s" % [opts.keys()])
	lobby.mode_ob.select(3)  # versus
	lobby.room_requested.emit(lobby._opts())
	check_eq(got[0].mode, "versus", "the room gets the mode chosen")
	lobby.queue_free()
