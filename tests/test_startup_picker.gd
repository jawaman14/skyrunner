extends TestCase
## Leaving the seat picker through Main (#97): a guest who joined a running game without a seat opens the live picker
## and backs out. RoomScreen closes the link and Main._leave tears the join down and returns to the lobby. These
## check the whole teardown with the real server, and that nothing the guest was about to be given can arrive late.
const Main = preload("res://scripts/main.gd")

class Entry extends Main:
	func _ready() -> void:
		pass

var _entry: Entry
var _server: HostServer
var _session: Session
var _save_dir := ""

func before_each() -> void:
	_save_dir = "user://startup-picker-test-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_save_dir))
	_server = HostServer.new()
	_server.password = "picker-only"
	_session = Session.new({"seed": 4, "mode": Roles.VERSUS, "map_seed": MapCity.SEED})
	_server.attach(_session)
	check_eq(_server.start(0, Roles.VERSUS, "127.0.0.1", MapCity.SEED), null)
	_entry = Entry.new()
	_entry.save_dir = _save_dir
	_entry.args.merge({"connect": "picker-only@127.0.0.1:%d" % _server.port, "role": "pick",
		"name": "Picker guest", "graphics": "low", "new": true}, true)
	var tree: SceneTree = Engine.get_main_loop()
	tree.root.add_child(_entry)

func after_each() -> void:
	for child in _entry.get_children():
		if child is NetClient: child.close()
	_entry.free()
	_server.stop()
	_server.free()
	_session.dispose()
	for file in DirAccess.get_files_at(_save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_dir + file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_dir))
	World.use_map(0)

func _child(kind: Script) -> Node:
	for child in _entry.get_children():
		if is_instance_of(child, kind) and not child.is_queued_for_deletion():
			return child
	return null

func _count(kind: Script) -> int:
	var n := 0
	for child in _entry.get_children():
		if is_instance_of(child, kind) and not child.is_queued_for_deletion(): n += 1
	return n

func _pump(done: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		_server._process(0.0)
		var link := _child(NetClient) as NetClient
		if link != null: link.poll()
		var room := _child(RoomScreen) as RoomScreen
		if room != null: room._process(0.0)
		if done.call(): return true
		OS.delay_msec(5)
	return false

## Join, reach the live picker and hand back the link and picker (null if it never opens).
func _open_picker() -> Array:
	_entry.start()
	var link := _child(NetClient) as NetClient
	check(link != null, "the join opens a client link")
	if link == null or not _pump(func(): return _child(SeatPicker) != null):
		check(false, "the live picker opens for an unseated late join")
		return []
	check_eq(link.role, "", "no seat yet")
	return [link, _child(SeatPicker)]

func _nothing_of_the_join_is_left(why: String) -> void:
	check_eq(_count(SeatPicker), 0, why + ": no picker")
	check_eq(_count(NetClient), 0, why + ": no client link")
	check_eq(_count(RoomScreen), 0, why + ": no room screen")
	check_eq(_count(StationApp), 0, why + ": no desk")
	check_eq(_count(RemoteSeat), 0, why + ": no 3D seat")
	check_eq(_count(VoiceChat), 0, why + ": no voice")
	check_eq(_count(HostServer), 0, why + ": no host service")
	check_eq(_count(HostDesk), 0, why + ": no host desk")
	check_eq(_count(PilotApp), 0, why + ": no game")
	check_eq(_count(Lobby), 1, why + ": back in the lobby, once")

func _guest_seats() -> Array:
	return Roles.ALL.filter(func(r): return _session.seats.who(r) in ["human", "reserved"] and r != Roles.PILOT)

func test_leaving_the_picker_returns_to_the_lobby_with_nothing_left() -> void:
	var opened := _open_picker()
	if opened.is_empty(): return
	var link: NetClient = opened[0]
	var picker: SeatPicker = opened[1]
	check(_pump(func(): return link.welcome != null), "welcomed by the real host")
	check(_guest_seats().is_empty(), "the guest holds no seat")
	picker.key("leave")
	check(not link.alive(), "leaving closes the connection")
	_nothing_of_the_join_is_left("left the picker")
	check_eq(_entry.args["new"], false, "a reload after leaving is the save as it is, never a fresh game")
	check(_pump(func(): return _server.conns.is_empty()), "the host sees the guest go")
	check(_guest_seats().is_empty(), "and no seat is held for them")

func test_a_late_confirmation_or_claim_after_leaving_opens_nothing() -> void:
	var opened := _open_picker()
	if opened.is_empty(): return
	var link: NetClient = opened[0]
	var picker: SeatPicker = opened[1]
	picker.key("leave")
	# the picker is only queued for deletion: anything the host says now must still come to nothing
	link.role_changed.emit(Roles.CONTROLLER)
	link.claim(Roles.CONTROLLER)
	_nothing_of_the_join_is_left("late events before the deletes flush")
	for i in 5:  # process_frame resumes before the frame's delete queue is flushed: give it a few
		await Engine.get_main_loop().process_frame
	check(not is_instance_valid(link), "the link is released, so nothing can arrive on it")
	check(not is_instance_valid(picker), "and so is the picker")
	_nothing_of_the_join_is_left("after the deletes flush")
	_server._process(0.0)
	check_eq(_session.seats.who(Roles.CONTROLLER), "ai", "the claim on the closed link never reached the host")
	check_eq(_session.seats.who(Roles.COPILOT), "ai", "and the late confirmation seated no one")

func test_leaving_with_a_claim_in_flight_leaves_no_human_seat_and_no_guest_ui() -> void:
	var opened := _open_picker()
	if opened.is_empty(): return
	var link: NetClient = opened[0]
	var picker: SeatPicker = opened[1]
	check(_pump(func(): return link.welcome != null), "welcomed")
	link.claim(Roles.CONTROLLER)  # sent, the host has not answered yet
	picker.key("leave")
	_nothing_of_the_join_is_left("claim in flight")
	# the host may already have granted it before the link closed: a dropped guest's seat is held (Seats.HOLD_S), never human
	for i in 20:
		_server._process(0.0)
		OS.delay_msec(5)
	check_eq(_count(StationApp), 0, "the confirmation cannot open a desk")
	check(_session.seats.who(Roles.CONTROLLER) in ["ai", "reserved"], "the seat is not left human: " + _session.seats.who(Roles.CONTROLLER))
	check_eq(_guest_seats().size(), 0 if _session.seats.who(Roles.CONTROLLER) == "ai" else 1)
