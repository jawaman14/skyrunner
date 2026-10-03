extends TestCase
## The waiting room: seats chosen before the game starts, readiness, and the host starting it over real sockets.

var _srv: HostServer
var _links: Array = []
var _sess: Session


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


# ------------------------------------------------------------------ the rules
func test_a_new_room_has_the_host_in_the_pilots_seat() -> void:
	var r := Room.new(Roles.VERSUS, "Barry")
	check_eq(r.host_role(), Roles.PILOT, "the host flies by default")
	check_eq(r.holder(Roles.PILOT), Room.HOST, "so the pilot's seat is held")
	check_eq(r.players[Room.HOST].name, "Barry", "under their name")
	check_eq(r.can_start(), "", "alone, the host can start")


func test_seats_are_one_player_each_and_one_seat_each() -> void:
	var r := Room.new(Roles.VERSUS, "Barry")
	r.add("a", "Rosa")
	r.add("b", "Lee")
	check_eq(r.claim("a", Roles.COPILOT), "", "Rosa takes the co-pilot")
	check(r.claim("b", Roles.COPILOT) != "", "Lee cannot have the same seat")
	check(r.claim("b", Roles.PILOT).contains("taken"), "nor the host's pilot seat: %s" % r.claim("b", Roles.PILOT))
	check_eq(r.claim("b", Roles.CONTROLLER), "", "Lee takes the task force's desk")
	check_eq(r.claim("a", Roles.SPOTTER), "", "Rosa moves to the spotter's seat")
	check_eq(r.holder(Roles.COPILOT), "", "and the co-pilot's seat is free again")
	check(r.claim("nobody", Roles.BOAT) != "", "a stranger cannot take a seat")
	check(r.claim("a", "not_a_role") != "", "nor one that does not exist")
	r.release("a")
	check_eq(r.players["a"].role, "", "giving a seat back leaves the player without one")
	check_eq(r.holder(Roles.SPOTTER), "", "and the AI has it")


func test_a_co_op_table_is_runners_only_and_a_task_force_game_has_no_pilot() -> void:
	var co := Room.new(Roles.COOP, "Barry")
	co.add("a", "Lee")
	check(co.claim("a", Roles.CONTROLLER) != "", "no law seats in co-op: the law is the AI")
	check_eq(co.seats().filter(func(s): return s.side == "law").map(func(s): return s.who), ["off", "off", "off", "off", "off"], "they are listed as off")
	var po := Room.new(Roles.POLICE, "Barry", Roles.CONTROLLER)
	check_eq(po.host_role(), Roles.CONTROLLER, "a police game starts the host at a desk")
	check(po.claim("host", Roles.PILOT) != "", "and nobody flies")
	var vs := Room.new(Roles.VERSUS, "Barry", Roles.CONTROLLER)
	check_eq(vs.host_role(), Roles.CONTROLLER, "in versus the host may start at a desk")
	check(vs.claim("host", Roles.INTERCEPTOR).contains("guest"), "but the police pilot's 3D seat is for a guest")


func test_the_host_starts_only_when_everybody_has_a_seat_and_is_ready() -> void:
	var r := Room.new(Roles.VERSUS, "Barry")
	r.add("a", "Rosa")
	check(r.can_start().contains("Rosa has not chosen a seat"), "Rosa has no seat: %s" % r.can_start())
	r.claim("a", Roles.COPILOT)
	check(r.can_start().contains("not ready"), "she has one but is not ready: %s" % r.can_start())
	r.set_ready("a", true)
	check_eq(r.can_start(), "", "now the host can start")
	r.claim("a", Roles.SPOTTER)
	check(r.can_start().contains("not ready"), "changing seats takes the ready away")
	r.set_ready("a", true)
	r.set_ready(Room.HOST, false)
	check(r.players[Room.HOST].ready, "the host is always ready")
	r.remove("a")
	check_eq(r.can_start(), "", "a player who leaves no longer holds it up")
	r.remove(Room.HOST)
	check(r.players.has(Room.HOST), "and the host cannot be removed")


func test_the_room_says_what_each_seat_is() -> void:
	var r := Room.new(Roles.VERSUS, "Barry")
	r.add("a", "Rosa")
	r.claim("a", Roles.CONTROLLER)
	var seats := r.seats()
	check_eq(seats.size(), 11, "every role")
	check_eq(seats[0].role, Roles.PILOT, "runners first")
	check_eq(seats[0].who, "player", "the pilot is a player (the host)")
	check_eq(seats[0].name, "Barry", "named")
	var ctl: Dictionary = seats.filter(func(s): return s.role == Roles.CONTROLLER)[0]
	check(ctl.who == "player" and ctl.name == "Rosa" and ctl.side == "law", "the controller is Rosa, on the law side")
	var boat: Dictionary = seats.filter(func(s): return s.role == Roles.BOAT)[0]
	check(boat.who == "ai" and boat.about != "", "a free seat is the AI's, and says what it does")
	var d := r.to_dict()
	check(d.players.size() == 2 and d.seats.size() == 11 and d.mode == Roles.VERSUS, "and the whole room goes to everyone as a dictionary")


# ------------------------------------------------------------------ over the wire
func _room_game(mode := Roles.VERSUS) -> void:
	_srv = HostServer.new()
	check_eq(_srv.start_room(0, mode, "127.0.0.1", 4, "Barry"), null, "the waiting room is open")


func _join(name: String, role := "") -> NetClient:
	var c := NetClient.new().open("127.0.0.1", _srv.port, name, role)
	_links.append(c)
	return c


func _pump_until(cond: Callable, secs := 5.0) -> bool:
	var end := Time.get_ticks_msec() + int(secs * 1000)
	while Time.get_ticks_msec() < end:
		_srv._process(0.0)
		for c in _links:
			c.poll()
		if _sess != null:
			_srv.pump(_sess)
			_sess.update(1.0 / 60)
			_srv.publish(_sess, true)
		if cond.call():
			return true
		OS.delay_msec(5)
	return false


func test_players_join_a_room_before_there_is_a_game() -> void:
	_room_game()
	var rosa := _join("Rosa")
	check(_pump_until(func(): return rosa.welcome != null), "Rosa gets in with no session at all")
	check_eq(rosa.phase, "room", "told she is in the waiting room")
	check(_pump_until(func(): return not rosa.room_state.is_empty()), "and sent the room")
	check_eq(rosa.room_state.players.size(), 2, "the host and her")
	var seats: Array = rosa.room_state.seats
	check_eq(seats.size(), 11, "with every seat")
	rosa.room_claim(Roles.COPILOT)
	check(_pump_until(func(): return _srv.room.holder(Roles.COPILOT) != ""), "she picks the co-pilot's seat")
	check(_pump_until(func(): return rosa.room_state.seats.filter(func(s): return s.role == Roles.COPILOT)[0].who == "player"), "everybody sees it taken")
	var lee := _join("Lee")
	check(_pump_until(func(): return lee.welcome != null), "Lee joins")
	lee.room_claim(Roles.COPILOT)
	check(_pump_until(func(): return lee.claim_error != null), "Lee is refused the same seat")
	check(str(lee.claim_error).contains("taken"), "because it is taken: %s" % str(lee.claim_error))
	rosa.set_ready(true)
	check(_pump_until(func(): return rosa.room_state.players.any(func(p): return p.name == "Rosa" and p.ready)), "ready shows to all")
	rosa.room_release()
	check(_pump_until(func(): return _srv.room.holder(Roles.COPILOT) == ""), "she gives the seat back")


func test_a_seat_asked_for_on_joining_is_held_in_the_room() -> void:
	_room_game()
	var c := _join("Zed", Roles.SPOTTER)
	check(_pump_until(func(): return c.welcome != null), "joined")
	check(_pump_until(func(): return _srv.room.holder(Roles.SPOTTER) != ""), "with the spotter's seat he asked for")


func test_chat_works_in_the_room_and_a_drop_empties_the_seat() -> void:
	_room_game()
	var a := _join("Rosa", Roles.COPILOT)
	var b := _join("Lee")
	check(_pump_until(func(): return a.welcome != null and b.welcome != null), "both in")
	a.say("anyone for versus?")
	check(_pump_until(func(): return b.chat_log.size() >= 1), "the other hears the room's chat")
	check_eq(b.chat_log[0].text, "anyone for versus?", "the words")
	a.close()
	check(_pump_until(func(): return _srv.room.holder(Roles.COPILOT) == ""), "Rosa leaves and her seat is free")


func test_starting_the_game_hands_everyone_the_seat_they_chose() -> void:
	_room_game()
	var rosa := _join("Rosa", Roles.COPILOT)
	var lee := _join("Lee", Roles.CONTROLLER)
	var zed := _join("Zed")
	check(_pump_until(func(): return rosa.welcome != null and lee.welcome != null and zed.welcome != null), "three at the table")
	rosa.set_ready(true)
	lee.set_ready(true)
	check(_pump_until(func(): return _srv.room.players.size() == 4 and _srv.room.players.values().filter(func(p): return p.name == "Rosa")[0].ready), "Rosa and Lee are ready")
	check(_srv.room.can_start().contains("Zed has not chosen"), "Zed has no seat: the host cannot start yet")
	zed.room_claim(Roles.BOAT)
	zed.set_ready(true)
	check(_pump_until(func(): return _srv.room.can_start() == ""), "now it can")
	var started := {}
	for c in [rosa, lee, zed]:
		var cc: NetClient = c
		cc.started.connect(func(r): started[cc.name_] = r)
	_sess = Session.new({"seed": 4, "mode": Roles.VERSUS, "features": Session.SANDBOX_FEATURES})
	_srv.begin(_sess)
	check(_srv.room == null, "the room is closed")
	check(_pump_until(func(): return started.size() == 3), "all three are told the game began")
	check_eq(started["Rosa"], Roles.COPILOT, "Rosa is the co-pilot")
	check_eq(started["Lee"], Roles.CONTROLLER, "Lee the controller")
	check_eq(started["Zed"], Roles.BOAT, "Zed the boat")
	check_eq(_sess.seats.who(Roles.COPILOT), "human", "the session's seats agree")
	check_eq(_sess.seats.seats[Roles.COPILOT].name, "Rosa", "with names")
	check_eq(_sess.seats.who(Roles.PILOT), "human", "the host holds the pilot's seat")
	check_eq(_sess.seats.who(Roles.SPOTTER), "ai", "nobody chose the spotter: the AI has it")
	check_eq(rosa.phase, "game", "the client knows the game is on")
	check(_pump_until(func(): return rosa.latest != null), "and gets its role-filtered snapshots")


func test_a_host_at_a_desk_and_a_closed_door() -> void:
	_room_game()
	check_eq(_srv.host_claim(Roles.CONTROLLER), "", "the host moves to the controller's desk")
	check_eq(_srv.room.host_role(), Roles.CONTROLLER, "and is there")
	check(_srv.host_claim(Roles.INTERCEPTOR) != "", "but not the police pilot's seat")
	_srv.locked = true
	var late := _join("Late")
	check(_pump_until(func(): return late.error != null), "a locked room turns newcomers away")
