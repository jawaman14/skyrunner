extends TestCase
const Main = preload("res://scripts/main.gd")

class Entry extends Main:
	func _ready() -> void:
		pass

var _entry: Entry
var _session: Session
var _save_dir := ""

func before_each() -> void:
	_entry = Entry.new()
	_save_dir = "user://startup-host-test-%d/" % Time.get_ticks_usec()
	_entry.save_dir = _save_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_save_dir))
	_entry.args.merge({"new": true, "port": 0, "graphics": "low", "unlocks": "open",
		"map": MapCity.SEED, "name": "Startup host", "password": "host-only"}, true)
	var tree: SceneTree = Engine.get_main_loop()
	tree.root.add_child(_entry)

func after_each() -> void:
	_entry.free()
	if _session != null:
		_session.dispose()
		_session = null
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

func _check_services(server: HostServer) -> void:
	check_eq(_count(HostServer), 1, "one authoritative server")
	check_eq(_count(VoiceChat), 1, "one host voice pipeline")
	check_eq(_count(LanDiscovery.Announcer, server), 1, "one server-owned beacon")
	var voice := _child(VoiceChat) as VoiceChat
	if voice != null: check_eq(voice.server, server)
	check_eq(server.sess, _session, "services share the active session")
	check(server.port > 0, "host listens on an assigned port")
	check_eq(server.password, "host-only")

func test_direct_host_starts_pilot_and_services() -> void:
	_entry.args["host"] = true
	_entry.start()
	var pilot := _child(PilotApp) as PilotApp
	check(pilot != null)
	if pilot == null: return
	_session = pilot.s
	var server := _child(HostServer) as HostServer
	check(server != null)
	if server == null: return
	_check_services(server)
	check_eq(_child(HostDesk), null)

func test_coop_mode_implicitly_hosts_without_host_flag() -> void:
	_entry.args["mode"] = Roles.COOP
	_entry.start()
	var pilot := _child(PilotApp) as PilotApp
	check(pilot != null)
	if pilot == null: return
	_session = pilot.s
	var server := _child(HostServer) as HostServer
	check(server != null)
	if server != null: _check_services(server)

func test_waiting_room_host_desk_reuses_server_and_beacon() -> void:
	_entry.args["mode"] = Roles.VERSUS
	_entry._open_room()
	var server := _child(HostServer) as HostServer
	var room := _child(RoomScreen) as RoomScreen
	check(server != null and room != null)
	if server == null or room == null: return
	var beacon := _child(LanDiscovery.Announcer, server)
	check(beacon != null)
	check_eq(_count(VoiceChat), 0, "waiting room has no microphone")
	check_eq(server.room.claim(Room.HOST, Roles.CONTROLLER), "")
	room.start_game.emit()
	var desk := _child(HostDesk) as HostDesk
	check(desk != null, "host choice opens the controller desk")
	if desk == null: return
	_session = desk.sess
	check_eq(desk.role, Roles.CONTROLLER)
	check_eq(desk.server, server)
	check_eq(_child(PilotApp), null)
	check_eq(_child(RoomScreen), null)
	check_eq(_entry.args["host_room"], null, "room handoff is consumed")
	check_eq(_child(LanDiscovery.Announcer, server), beacon)
	_check_services(server)
