extends TestCase
## Finding games on the network, and the host running the table: kicking, closing it, the roster.


var _sess: Session
var _srv: HostServer
var _links: Array = []


func _tree() -> SceneTree:
	return Engine.get_main_loop()


# ------------------------------------------------------------------ the beacon
func test_a_beacon_round_trips_and_strangers_are_ignored() -> void:
	var b := LanDiscovery.beacon("Barry's table", 47800, "coop", 3, true)
	var g := LanDiscovery.parse(b, "192.168.1.20")
	check_eq(g.name, "Barry's table", "the name")
	check_eq(g.ip, "192.168.1.20", "where it came from")
	check_eq(g.port, 47800, "the port to join on")
	check_eq(g.mode, "coop", "the mode")
	check_eq(g.players, 3, "who is in")
	check(g.locked, "and that it is closed")
	check(LanDiscovery.parse("hello".to_utf8_buffer(), "10.0.0.1").is_empty(), "random bytes are not a game")
	check(LanDiscovery.parse(JSON.stringify({"magic": "other-game", "v": 3, "port": 5}).to_utf8_buffer(), "10.0.0.1").is_empty(), "another game's beacon is not ours")
	check(LanDiscovery.parse(JSON.stringify({"magic": LanDiscovery.MAGIC, "v": 1, "port": 5}).to_utf8_buffer(), "10.0.0.1").is_empty(), "a different protocol is not joinable")
	check(LanDiscovery.parse(JSON.stringify({"magic": LanDiscovery.MAGIC, "v": Snapshot.PROTOCOL_VERSION, "port": 0}).to_utf8_buffer(), "10.0.0.1").is_empty(), "no port, no game")
	check(LanDiscovery.parse(PackedByteArray(), "10.0.0.1").is_empty(), "an empty packet")
	var long := LanDiscovery.beacon("x".repeat(100), 1, "", 0)
	check(str(LanDiscovery.parse(long, "1.1.1.1").name).length() <= 32, "a long name is cut")


func test_the_finder_lists_games_and_forgets_them() -> void:
	var f := LanDiscovery.Finder.new()
	f.ingest(LanDiscovery.beacon("Zed", 47800, "versus", 2), "10.0.0.5", 100.0)
	f.ingest(LanDiscovery.beacon("Amy", 47800, "coop", 1), "10.0.0.6", 101.0)
	f.ingest(LanDiscovery.beacon("Zed", 47800, "versus", 3), "10.0.0.5", 103.0)  # the same game, newer
	f.ingest("junk".to_utf8_buffer(), "10.0.0.9", 103.0)
	var l := f.list(104.0)
	check_eq(l.map(func(g): return g.name), ["Amy", "Zed"], "two games, by name")
	check_eq(l[1].players, 3, "the newer beacon replaced the older")
	check_eq(f.list(109.0).map(func(g): return g.name), ["Zed"], "Amy has not been heard from in 8 s: gone")
	check(f.list(120.0).is_empty(), "and then Zed")
	f.ingest(LanDiscovery.beacon("Two ports", 47801, "coop", 1), "10.0.0.5", 120.0)
	f.ingest(LanDiscovery.beacon("Two ports", 47800, "coop", 1), "10.0.0.5", 120.0)
	check_eq(f.list(121.0).size(), 2, "two games on one machine are two entries")
	f.free()


func test_a_beacon_really_travels_over_udp() -> void:
	var f := LanDiscovery.Finder.new()
	_tree().root.add_child(f)
	var port := 47900 + randi() % 90
	f.start(port)
	if not f.listening:
		check(true, "(the port is busy on this machine: skipping the socket check)")
		f.queue_free()
		return
	var a := LanDiscovery.Announcer.new()
	_tree().root.add_child(a)
	a.start(func(): return {"name": "Loop", "port": 47800, "mode": "coop", "players": 2}, "127.0.0.1", port)
	a.send_now()
	var end := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < end and f.list().is_empty():
		f._process(0.0)
		OS.delay_msec(10)
	var l := f.list()
	check_eq(l.size(), 1, "the finder heard it")
	if not l.is_empty():
		check_eq(l[0].name, "Loop", "the right game")
		check_eq(l[0].port, 47800, "on the right port")
		check_eq(l[0].players, 2, "with its players")
	a.queue_free()
	f.queue_free()


func test_this_machines_addresses_are_what_a_friend_would_type() -> void:
	for a in LanDiscovery.local_addresses():
		check(a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."), "%s is a usable IPv4 address" % a)


# ------------------------------------------------------------------ the table
func _game() -> void:
	_sess = Session.new({"seed": 4, "mode": Roles.VERSUS, "features": Session.SANDBOX_FEATURES})
	_srv = HostServer.new()
	_srv.attach(_sess)
	_srv.host_name = "Barry"
	_srv.start(0, Roles.VERSUS, "127.0.0.1")


func _end() -> void:
	for c in _links:
		c.close()
		c.free()
	_links.clear()
	_srv.stop()
	_srv.free()
	_sess.dispose()


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


func test_the_roster_lists_the_host_and_everyone_seated() -> void:
	_game()
	var rosa := _join("Rosa", Roles.COPILOT)
	check(_pump_until(func(): return rosa.welcome != null), "Rosa is in")
	var r := _srv.roster()
	check_eq(r.size(), 2, "the host and Rosa")
	check(r[0].host and r[0].name == "Barry" and r[0].role == Roles.PILOT, "the host first, in the pilot's seat")
	check(not r[1].host and r[1].name == "Rosa" and r[1].role == Roles.COPILOT, "then Rosa, the co-pilot")
	check(r[1].token != "" and r[1].token != "host", "with a token to mute or kick her by")
	_end()


func test_the_host_can_remove_a_player_who_cannot_come_back() -> void:
	_game()
	var rosa := _join("Rosa", Roles.COPILOT)
	check(_pump_until(func(): return rosa.welcome != null), "Rosa is in")
	var tok: String = rosa.token
	check(_srv.kick(tok), "kicked")
	check(_pump_until(func(): return rosa.error != null), "she is told")
	check(str(rosa.error).contains("removed"), "why: %s" % str(rosa.error))
	check_eq(_srv.roster().size(), 1, "and the roster is the host again")
	check(not _srv.kick("nobody"), "kicking nobody is a no")
	var again := NetClient.new()
	again.token = tok
	_links.append(again)
	again.open("127.0.0.1", _srv.port, "Rosa", Roles.COPILOT)
	again.token = tok
	check(_pump_until(func(): return again.error != null), "she tries again with the same token")
	check(str(again.error).contains("removed"), "and is refused: %s" % str(again.error))
	_end()


func test_a_closed_table_lets_back_those_who_had_a_seat_only() -> void:
	_game()
	var rosa := _join("Rosa", Roles.COPILOT)
	check(_pump_until(func(): return rosa.welcome != null), "Rosa is in")
	_srv.locked = true
	var late := _join("Late", Roles.SPOTTER)
	check(_pump_until(func(): return late.error != null), "a newcomer is told")
	check(str(late.error).contains("closed"), "the table is closed: %s" % str(late.error))
	rosa.close()
	check(_pump_until(func(): return _srv.roster().size() == 1), "Rosa drops")
	rosa.reconnect()
	check(_pump_until(func(): return rosa.welcome != null and rosa.error == null and _srv.roster().size() == 2), "Rosa comes back to her held seat")
	_srv.locked = false
	_end()


func test_a_full_table_turns_people_away() -> void:
	_game()
	_srv.max_players = 1
	var a := _join("A", Roles.COPILOT)
	check(_pump_until(func(): return a.welcome != null), "the first is in")
	var b := _join("B", Roles.SPOTTER)
	check(_pump_until(func(): return b.error != null), "the second is told")
	check(str(b.error).contains("full"), "the table is full: %s" % str(b.error))
	_end()
