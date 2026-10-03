extends TestCase
## The dedicated server: its options, the game it builds, and over real loopback sockets the password, the status probe, the seats,
## the AI pilot, the saves and the stop file.

const SAVE := "user://test_dedicated.json"
const STOP := "user://test_dedicated.stop"

var _srv: DedicatedServer = null
var _clients: Array = []


func after_each() -> void:
	for c in _clients:
		c.close()
		c.free()
	_clients.clear()
	if _srv != null:
		_srv.shutdown()
		if _srv.srv != null:
			_srv.srv.free()
		_srv.sess.dispose()
		_srv = null
	World.use_map(0)
	for p in [SAVE, STOP]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _server(extra := {}) -> DedicatedServer:
	var cfg := {"port": 0, "bind": "127.0.0.1", "save": SAVE, "quiet": true, "seed": 3, "stop_file": STOP}
	cfg.merge(extra, true)
	_srv = DedicatedServer.new(cfg)
	var err := _srv.start()
	check_eq(err, "", "listening")
	return _srv


func _client(name: String, role: String, password := "") -> NetClient:
	var c := NetClient.new()
	c.password = password
	c.open("127.0.0.1", _srv.srv.port, name, role)
	_clients.append(c)
	return c


func _pump_until(cond: Callable, secs := 5.0) -> bool:
	var end := Time.get_ticks_msec() + int(secs * 1000)
	while Time.get_ticks_msec() < end:
		_srv.srv._process(0.0)
		for c in _clients:
			c.poll()
		_srv.step(1.0 / 30.0)
		if cond.call():
			return true
		OS.delay_msec(5)
	return false


func test_the_options_come_from_the_flags_the_environment_and_the_defaults() -> void:
	var d := DedicatedServer.parse([], {})
	check_eq(d.error, "", "defaults are fine")
	check_eq(d.cfg.port, 47800, "the usual port")
	check_eq(d.cfg.mode, "coop", "co-op")
	check_eq(d.cfg.password, "", "open")
	check(bool(d.cfg.autopilot) and not bool(d.cfg.lan), "the AI flies and the LAN beacon is off")
	var e := DedicatedServer.parse(["--port", "4000", "--mode", "police", "--lan", "--autopilot", "false", "--max-players", "100", "--stop-file", "/tmp/stop"], {"SKYRUNNER_PASSWORD": "pw", "SKYRUNNER_PORT": "5000", "SKYRUNNER_SEED": "9"})
	check_eq(e.error, "", "no error")
	check_eq(e.cfg.port, 4000, "a flag beats the environment")
	check_eq(e.cfg.seed, 9, "the environment beats the default")
	check_eq(e.cfg.password, "pw", "a password from the environment")
	check_eq(e.cfg.mode, "police", "a mode")
	check(bool(e.cfg.lan) and not bool(e.cfg.autopilot), "booleans: a bare flag is true, 'false' turns one off")
	check_eq(e.cfg.max_players, 64, "the table is capped at 64")
	check_eq(e.cfg.stop_file, "/tmp/stop", "dashes and underscores are the same")
	check(DedicatedServer.parse(["--mode", "chess"], {}).error != "", "an unknown mode is refused")
	check(DedicatedServer.parse(["--frobnicate"], {}).error != "", "so is an unknown option")
	check(DedicatedServer.parse(["--port", "99999"], {}).error != "", "and a port out of range")
	check(DedicatedServer.parse(["--unlocks", "never"], {}).error != "", "and unlocks")


func test_the_game_it_builds() -> void:
	var s := DedicatedServer.new({"unlocks": "open"})
	var o := s.session_options()
	check(o.has("money") and o.ground_war and o.casino and o.dealership and o.psychedelics, "open mode: everything on with a float")
	var st := DedicatedServer.new({"unlocks": "story"}).session_options()
	check(st.has("career") and not st.has("family") and not st.has("casino"), "story mode: the chapters open the systems")
	var p := DedicatedServer.new({"mode": "police"}).session_options()
	check_eq(p.mode, Roles.POLICE, "police mode: a task-force table")


func test_it_runs_with_nobody_there_and_the_ai_flies() -> void:
	var s := _server()
	for i in 90:
		s.step(1.0 / 30.0)
	check(s.sess.time > 2.5, "the game runs: %.1f s" % s.sess.time)
	check(s.bot != null, "the AI flies the aircraft")
	check_eq(s.players(), 0, "and nobody is connected")


func test_a_desk_joins_and_gets_snapshots() -> void:
	_server()
	var c := _client("Rosa", "boss")
	check(_pump_until(func(): return c.latest != null), "a snapshot arrives: %s" % c.error)
	check_eq(c.latest.role, "boss", "as the boss")
	check_eq(_srv.sess.seats.who("boss"), "human", "the seat is hers")
	check(_srv.lines.any(func(l): return str(l).contains("Rosa joined as boss")), "and the log says so")


func test_the_password_keeps_strangers_out() -> void:
	_server({"password": "hunter2"})
	var bad := _client("Mallory", "boss", "wrong")
	check(_pump_until(func(): return bad.error != null), "refused")
	check(str(bad.error).contains("password"), "with a reason: %s" % bad.error)
	var none := _client("Eve", "boss")
	check(_pump_until(func(): return none.error != null), "no password, no seat")
	var good := _client("Alice", "boss", "hunter2")
	check(_pump_until(func(): return good.latest != null), "the right one gets in")
	check_eq(_srv.sess.seats.who("boss"), "human", "and the seat")
	check(_srv.lines.any(func(l): return str(l).contains("refused Mallory")), "the refusals are logged")


func test_the_table_is_capped() -> void:
	_server({"max_players": 1})
	var a := _client("A", "boss")
	check(_pump_until(func(): return a.latest != null), "the first is in")
	var b := _client("B", "fixer")
	check(_pump_until(func(): return b.error != null), "the second is refused")
	check(str(b.error).contains("full"), "the table is full: %s" % b.error)


func test_a_status_probe_answers_without_joining() -> void:
	_server({"password": "x", "name": "Test table"})
	var peer := StreamPeerTCP.new()
	check_eq(peer.connect_to_host("127.0.0.1", _srv.srv.port), OK, "connected")
	var sent := false
	var reply := {}
	var buf := PackedByteArray()
	var end := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < end and reply.is_empty():
		_srv.srv._process(0.0)
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED and not sent:
			peer.put_data(HostServer.line({"t": "status"}))
			sent = true
		for l in HostServer.read_lines(peer, buf):
			reply = JSON.parse_string(l)
		_srv.step(1.0 / 30.0)
		OS.delay_msec(5)
	check_eq(reply.get("t"), "status", "an answer")
	check_eq(reply.get("name"), "Test table", "the table's name")
	check(bool(reply.get("password")), "says it wants a password, without saying which")
	check(not reply.has("token") and not str(reply).contains("\"x\""), "and nothing secret")
	check_eq(reply.get("max"), 16, "the size")
	check_eq(reply.get("players"), 0, "nobody is here (the server itself does not count)")
	peer.disconnect_from_host()


func test_it_saves_when_the_last_player_leaves_and_picks_the_save_up() -> void:
	var s := _server({"autosave": 0.0})
	var c := _client("Rosa", "boss")
	check(_pump_until(func(): return c.latest != null), "joined")
	check(not FileAccess.file_exists(SAVE), "nothing saved yet")
	c.close()
	check(_pump_until(func(): return FileAccess.file_exists(SAVE)), "saved when she left")
	s.sess.money = 4242
	s.save()
	s.shutdown()
	s.srv.free()
	s.sess.dispose()
	_srv = null
	var again := _server({"autosave": 0.0})
	check_eq(again.sess.money, 4242, "the game carries on from the save")


func test_a_stop_file_ends_it_cleanly() -> void:
	var s := _server()
	var f := FileAccess.open(STOP, FileAccess.WRITE)
	f.store_string("stop")
	f.close()
	var done := false
	for i in 120:
		if s.step(0.05):
			done = true
			break
	check(done, "it stopped")
	check(not FileAccess.file_exists(STOP), "and took the file away so the next start is clean")


func test_a_time_limit_ends_it() -> void:
	var s := _server({"seconds": 1.0})
	var done := false
	for i in 60:
		if s.step(1.0 / 30.0):
			done = true
			break
	check(done, "a test run ends by itself")


func test_the_ai_pilot_keeps_flying_for_a_server_hour() -> void:
	var s := _server({"seed": 5})
	for i in 30 * 1500:  # twenty-five minutes of server time
		s.step(1.0 / 30.0)
	check(s.bot != null and s.bot.flights >= 2, "the AI flew at least twice and was never stuck waiting on a load: %d" % (s.bot.flights if s.bot != null else -1))
	check(s.sess.loadout.unassigned().is_empty() or s.sess.phase != "parked" or s.bot.skipped.size() > 0, "a load that does not fit is put back, not waited on")


func test_a_story_server_runs_the_chapters_and_remembers_them() -> void:
	var s := _server({"unlocks": "story", "autosave": 0.0})
	check(s.sess.story != null, "the story is attached")
	check_eq(s.sess.story.chapter.title, "Square Grouper", "at its first chapter")
	for i in 30 * 60:
		s.step(1.0 / 30.0)
	check(s.sess.time > 59.0, "a minute of the story served")
	s.sess.story.advance()
	s.save()
	s.shutdown()
	s.srv.free()
	s.sess.dispose()
	_srv = null
	var again := _server({"unlocks": "story", "autosave": 0.0})
	check_eq(again.sess.story.chapter.title, "The Connection", "the next start picks the story up where it was")
