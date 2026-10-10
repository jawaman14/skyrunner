extends TestCase
const Main = preload("res://scripts/main.gd")

class Entry extends Main:
	func _ready() -> void:
		pass

func test_failed_direct_host_releases_server_and_keeps_local_game() -> void:
	var blocker := HostServer.new()
	check_eq(blocker.start(0), null)
	var entry := Entry.new()
	entry.save_dir = "user://startup-test-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(entry.save_dir))
	entry.args.merge({"new": true, "host": true, "port": blocker.port,
		"graphics": "low", "unlocks": "open", "map": MapCity.SEED}, true)
	var tree: SceneTree = Engine.get_main_loop()
	tree.root.add_child(entry)
	entry.start()
	var pilot: PilotApp = null
	for child in entry.get_children():
		check(not child is HostServer or child.is_queued_for_deletion(), "failed server is released")
		check(not child is VoiceChat, "failed host creates no voice service")
		if child is PilotApp: pilot = child
	check(pilot != null, "local fallback remains playable")
	var session: Session = pilot.s if pilot != null else null
	var save_dir: String = entry.save_dir
	tree.root.remove_child(entry)
	entry.free()
	if session != null: session.dispose()
	blocker.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir))
	World.use_map(0)


var _entry: Entry
var _server: HostServer
var _session: Session

func after_each() -> void:
	if _entry != null:
		for child in _entry.get_children():
			if child is NetClient: child.close()
		_entry.free()
		_entry = null
	if _server != null:
		_server.stop()
		_server.free()
		_server = null
	if _session != null:
		_session.dispose()
		_session = null
	World.use_map(0)

func _child(kind: Script) -> Node:
	for child in _entry.get_children():
		if is_instance_of(child, kind) and not child.is_queued_for_deletion():
			return child
	return null

func _remote_start(role: String, seat3d := false, waiting := false) -> NetClient:
	_server = HostServer.new()
	_server.password = "startup-only"
	if waiting:
		check_eq(_server.start_room(0, Roles.VERSUS, "127.0.0.1", MapCity.SEED), null)
	else:
		_session = Session.new({"seed": 4, "mode": Roles.VERSUS, "map_seed": MapCity.SEED})
		_server.attach(_session)
		check_eq(_server.start(0, Roles.VERSUS, "127.0.0.1", MapCity.SEED), null)
	_entry = Entry.new()
	_entry.args.merge({"connect": "startup-only@127.0.0.1:%d" % _server.port,
		"role": role, "seat3d": seat3d, "name": "Startup guest", "graphics": "low"}, true)
	var tree: SceneTree = Engine.get_main_loop()
	tree.root.add_child(_entry)
	_entry.start()
	return _child(NetClient) as NetClient

func _pump_until(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		_server._process(0.0)
		var link := _child(NetClient) as NetClient
		if link != null: link.poll()
		# Drive the real entry-point room callback without advancing gameplay.
		var room := _child(RoomScreen) as RoomScreen
		if room != null: room._process(0.0)
		if condition.call(): return true
		OS.delay_msec(5)
	return false

func test_join_running_game_opens_requested_station_with_one_voice() -> void:
	var link := _remote_start(Roles.COPILOT)
	check(_pump_until(func(): return _child(StationApp) != null), "hello transitions through the room to the desk")
	check_eq(link.error, null)
	check_eq(link.role, Roles.COPILOT)
	check_eq(link.password, "startup-only", "address password reaches the real host")
	var desk := _child(StationApp) as StationApp
	if desk != null:
		check_eq(desk.link, link)
		check_eq(desk.role, Roles.COPILOT)
	check_eq(_child(RemoteSeat), null, "default copilot uses a desk")
	check_eq(_child(RoomScreen), null, "transitional room is removed")
	var voices := _entry.get_children().filter(func(c): return c is VoiceChat)
	check_eq(voices.size(), 1)
	if not voices.is_empty(): check_eq(voices[0].link, link)

func test_late_join_picker_waits_for_host_claim_before_opening_station() -> void:
	var link := _remote_start("pick")
	check(_pump_until(func(): return _child(SeatPicker) != null), "unseated late join opens the live picker")
	check_eq(link.role, "")
	check_eq(_child(StationApp), null, "no desk before host claim")
	check_eq(_child(VoiceChat), null, "no microphone before seating")
	link.claim(Roles.CONTROLLER)
	check(_pump_until(func(): return _child(StationApp) != null), "host confirmation opens the claimed desk")
	check_eq(link.role, Roles.CONTROLLER)
	check_eq(_child(SeatPicker), null)
	var desk := _child(StationApp) as StationApp
	if desk != null: check_eq(desk.role, Roles.CONTROLLER)

func test_join_waiting_room_opens_station_only_after_host_starts() -> void:
	var link := _remote_start(Roles.COPILOT, false, true)
	check(_pump_until(func(): return link.welcome != null and not link.room_state.is_empty()), "real waiting-room handshake")
	check_eq(link.phase, "room")
	check_eq(_child(StationApp), null)
	check_eq(_child(VoiceChat), null)
	link.room_claim(Roles.COPILOT)
	check(_pump_until(func(): return _server.room.holder(Roles.COPILOT) != ""), "host records guest seat")
	_session = Session.new({"seed": 4, "mode": Roles.VERSUS, "map_seed": MapCity.SEED})
	_server.begin(_session)
	check(_pump_until(func(): return _child(StationApp) != null), "start packet invokes entry-point seating")
	check_eq(link.phase, "game")
	check_eq(link.role, Roles.COPILOT)
	check_eq(_child(RoomScreen), null)

func test_join_copilot_3d_option_opens_remote_seat() -> void:
	var link := _remote_start(Roles.COPILOT, true)
	check(_pump_until(func(): return _child(RemoteSeat) != null), "explicit 3D option reaches remote-seat setup")
	check_eq(_child(StationApp), null)
	var seat := _child(RemoteSeat) as RemoteSeat
	if seat != null:
		check_eq(seat.role, Roles.COPILOT)
		check_eq(seat.link, link)
		check(seat.scene != null and seat.cam != null, "remote world and camera are initialized")
