extends TestCase
## The waiting room's entry paths through Main (#97): the host flying out of the room, the host closing it,
## a room that cannot listen, and a guest leaving it. Each checks which services exist afterwards.
const Main = preload("res://scripts/main.gd")

class Entry extends Main:
	func _ready() -> void:
		pass

var _entry: Entry
var _session: Session
var _save_dir := ""
var _servers: Array[HostServer] = []  ## servers the test made itself (a blocker, a guest's host)

func before_each() -> void:
	_entry = Entry.new()
	_save_dir = "user://startup-room-test-%d/" % Time.get_ticks_usec()
	_entry.save_dir = _save_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_save_dir))
	_entry.args.merge({"new": true, "port": 0, "graphics": "low", "unlocks": "open",
		"map": MapCity.SEED, "name": "Room host", "password": "room-only"}, true)
	var tree: SceneTree = Engine.get_main_loop()
	tree.root.add_child(_entry)

func after_each() -> void:
	for child in _entry.get_children():
		if child is NetClient: child.close()
	_entry.free()
	if _session != null:
		_session.dispose()
		_session = null
	for server in _servers:
		server.stop()
		server.free()
	_servers.clear()
	for file in DirAccess.get_files_at(_save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_dir + file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_dir))
	World.use_map(0)

func _child(kind: Script, parent: Node = null) -> Node:
	var root: Node = _entry if parent == null else parent
	for child in root.get_children():
		if is_instance_of(child, kind) and not child.is_queued_for_deletion():
			return child
	return null

func _count(kind: Script, parent: Node = null) -> int:
	var root: Node = _entry if parent == null else parent
	var count := 0
	for child in root.get_children():
		if is_instance_of(child, kind) and not child.is_queued_for_deletion(): count += 1
	return count

func _no_network_services(why: String) -> void:
	check_eq(_count(HostServer), 0, why + ": no server")
	check_eq(_count(NetClient), 0, why + ": no client link")
	check_eq(_count(VoiceChat), 0, why + ": no voice")
	check_eq(_count(RoomScreen), 0, why + ": no room")
	check(_child(Lobby) != null, why + ": back in the lobby")

func _own_server() -> HostServer:
	var server := HostServer.new()
	_servers.append(server)
	return server

func test_host_who_keeps_the_pilot_seat_flies_with_the_room_server() -> void:
	_entry.args["mode"] = Roles.COOP
	_entry._open_room()
	var server := _child(HostServer) as HostServer
	var room := _child(RoomScreen) as RoomScreen
	check(server != null and room != null)
	if server == null or room == null: return
	var beacon := _child(LanDiscovery.Announcer, server)
	check(beacon != null)
	check_eq(server.room.host_role(), Roles.PILOT, "the host flies unless they pick a desk")
	room._start()
	var pilot := _child(PilotApp) as PilotApp
	check(pilot != null, "Start opens the 3D seat")
	if pilot == null: return
	_session = pilot.s
	check_eq(pilot.server, server, "the pilot's game is the room's server")
	check_eq(server.sess, _session)
	check_eq(server.room, null, "begin() closed the room")
	check_eq(_entry.args["host_room"], null, "room handoff is consumed")
	check(_session.seats.human(Roles.PILOT), "the host holds the pilot's seat")
	check_eq(_child(HostDesk), null)
	check_eq(_child(RoomScreen), null)
	check_eq(_count(HostServer), 1, "one authoritative server")
	check_eq(_count(VoiceChat), 1, "one host voice pipeline")
	check_eq(_count(LanDiscovery.Announcer, server), 1, "one server-owned beacon")
	check_eq(_child(LanDiscovery.Announcer, server), beacon, "the room's beacon carries on")
	var voice := _child(VoiceChat) as VoiceChat
	if voice != null: check_eq(voice.server, server)

func test_host_closing_the_room_releases_listener_and_beacon() -> void:
	_entry.args["mode"] = Roles.VERSUS
	_entry._open_room()
	var server := _child(HostServer) as HostServer
	var room := _child(RoomScreen) as RoomScreen
	check(server != null and room != null)
	if server == null or room == null: return
	var port := server.port
	var beacon := _child(LanDiscovery.Announcer, server)
	room._cancel()
	check(server.is_queued_for_deletion(), "cancel releases the server")
	_no_network_services("cancelled room")
	# process_frame resumes us before the frame's delete queue is flushed, so give it a few frames
	for i in 5:
		if not is_instance_valid(server): break
		await Engine.get_main_loop().process_frame
	check(not is_instance_valid(server), "the server is gone after the frame")
	check(not is_instance_valid(beacon), "and its beacon with it")
	check(not is_instance_valid(room))
	var again := _own_server()
	check_eq(again.start(port), null, "the port is free to host again")

func test_room_that_cannot_listen_returns_to_the_lobby() -> void:
	var blocker := _own_server()
	check_eq(blocker.start(0), null)
	_entry.args["mode"] = Roles.COOP
	_entry.args["port"] = blocker.port
	_entry._open_room()
	_no_network_services("occupied port")
	for child in _entry.get_children():
		if child is HostServer:
			check(child.is_queued_for_deletion(), "the failed server is released")
			check_eq(_count(LanDiscovery.Announcer, child), 0, "and never advertised")
	check_eq(_child(PilotApp), null, "no game starts")

func test_guest_leaving_the_waiting_room_closes_the_link() -> void:
	var host := _own_server()
	host.password = "room-only"
	check_eq(host.start_room(0, Roles.VERSUS, "127.0.0.1", MapCity.SEED, "Host"), null)
	_entry.args["connect"] = "room-only@127.0.0.1:%d" % host.port
	_entry.args["role"] = "pick"
	_entry.args["name"] = "Room guest"
	_entry.start()
	var link := _child(NetClient) as NetClient
	var room := _child(RoomScreen) as RoomScreen
	check(link != null and room != null, "a guest waits in the room")
	if link == null or room == null: return
	check(_pump(host, link, func(): return link.welcome != null and host.room.players.size() == 2), "the guest is in the room")
	check_eq(_count(VoiceChat), 0, "the waiting room has no microphone")
	room._cancel()
	check(not link.alive(), "leaving closes the connection")
	check(link.is_queued_for_deletion(), "and releases the link")
	_no_network_services("guest left")
	check(_pump(host, null, func(): return host.room.players.size() == 1), "the host sees the guest go")

func _pump(server: HostServer, link: NetClient, done: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		server._process(0.0)
		if link != null: link.poll()
		if done.call(): return true
		OS.delay_msec(5)
	return false
