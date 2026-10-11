extends TestCase
## Leaving a hosted game through Main (#97): going back to the lobby leaves no services, and joining another game
## from the multiplayer menu hands the table over without host services and reaches the other table's room.
## (A reload cannot start from a hosted game: the pause menu does not offer "Load last save" while hosting.)
const Main = preload("res://scripts/main.gd")

class Entry extends Main:
	func _ready() -> void:
		pass

var _entry: Entry
var _sessions: Array[Session] = []
var _servers: Array[HostServer] = []  ## servers the test made itself (the game being joined)
var _save_dir := ""

func before_each() -> void:
	_entry = Entry.new()
	_save_dir = "user://startup-leave-test-%d/" % Time.get_ticks_usec()
	_entry.save_dir = _save_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_save_dir))
	_entry.args.merge({"new": true, "host": true, "port": 0, "graphics": "low", "unlocks": "open",
		"map": MapCity.SEED, "name": "Leave host", "password": "leave-only"}, true)
	var tree: SceneTree = Engine.get_main_loop()
	tree.root.add_child(_entry)

func after_each() -> void:
	for child in _entry.get_children():
		if child is NetClient: child.close()
	_entry.free()
	for session in _sessions:
		session.dispose()
	_sessions.clear()
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

## A direct-hosted game running under Main; returns its pilot.
func _host_game() -> PilotApp:
	_entry.start()
	var pilot := _child(PilotApp) as PilotApp
	check(pilot != null, "the hosted game opens the 3D seat")
	if pilot != null: _sessions.append(pilot.s)
	return pilot

func _no_services(why: String) -> void:
	check_eq(_count(HostServer), 0, why + ": no server")
	check_eq(_count(VoiceChat), 0, why + ": no voice")
	check_eq(_count(NetClient), 0, why + ": no client link")
	check_eq(_count(PilotApp), 0, why + ": no game")

func test_leaving_a_hosted_game_for_the_lobby_leaves_no_services() -> void:
	var pilot := _host_game()
	var server := _child(HostServer) as HostServer
	check(pilot != null and server != null)
	if pilot == null or server == null: return
	var port := server.port
	var beacon := _child(LanDiscovery.Announcer, server)
	pilot.leave.emit("lobby")
	check(server.is_queued_for_deletion(), "the server is released")
	_no_services("lobby")
	check_eq(_count(RoomScreen), 0, "no room")
	check(_child(Lobby) != null, "the lobby is open")
	check_eq(_entry.args["new"], false)
	for i in 5:
		if not is_instance_valid(server): break
		await Engine.get_main_loop().process_frame
	check(not is_instance_valid(server), "the server is gone after the frames")
	check(not is_instance_valid(beacon), "and its beacon with it")
	var again := HostServer.new()
	_servers.append(again)
	check_eq(again.start(port), null, "the port is free to host again")

func test_joining_from_a_hosted_game_hands_the_table_over() -> void:
	var guest_game := HostServer.new()
	_servers.append(guest_game)
	guest_game.password = "other-table"
	check_eq(guest_game.start_room(0, Roles.COOP, "127.0.0.1", MapCity.SEED, "Other host"), null)
	var pilot := _host_game()
	var server := _child(HostServer) as HostServer
	check(pilot != null and server != null)
	if pilot == null or server == null: return
	var menu := _entry.open_mp()
	check(menu != null and _entry._mp == menu, "the multiplayer menu is open over the game")
	_entry._mp_join("other-table@127.0.0.1:%d" % guest_game.port, Roles.COPILOT, "Leave host")
	check(server.is_queued_for_deletion(), "the hosted game's server is released")
	check_eq(_count(HostServer), 0, "no host services remain")
	check_eq(_count(VoiceChat), 0, "no host voice")
	check_eq(_count(PilotApp), 0, "the old game is gone")
	check(menu.is_queued_for_deletion() or not is_instance_valid(menu), "the menu is closed")
	check_eq(_entry._mp, null, "and the entry forgets it")
	check_eq(_count(NetClient), 1, "one client link to the other table")
	check_eq(_count(RoomScreen), 1, "waiting in that table's room")
	check_eq(_entry.args["connect"], "other-table@127.0.0.1:%d" % guest_game.port)
	check_eq(_entry.args["new"], false)
	# the handoff only worked if the other table accepted us: wait for the welcome and the room roster
	var link := _child(NetClient) as NetClient
	if link == null: return
	check(_pump(guest_game, link, func(): return link.welcome != null and guest_game.room.players.size() == 2),
		"the other table welcomed the guest into its room")
	check_eq(link.error, null, "with the address's password accepted")
	check(Py.any(guest_game.room.players.values(), func(p): return p.name == "Leave host"), "under the name the player had")

func _pump(server: HostServer, link: NetClient, done: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		server._process(0.0)
		if link != null: link.poll()
		if done.call(): return true
		OS.delay_msec(5)
	return false
