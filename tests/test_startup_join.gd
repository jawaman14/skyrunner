extends TestCase
## The guest's entry paths in main.gd (#97): `_join()` (address parsing, the waiting-room screen), `_enter_game()` (a seat
## by name, or the picker), `_seat()` (a station or a remote 3D seat) and the cancel path. Each leaves exactly one link,
## one client voice pipeline once seated, and no host services (a guest never owns a server or a beacon). The host side
## is in test_startup_host.gd and test_startup_room.gd.
const Main = preload("res://scripts/main.gd")


class Entry extends Main:
	func _ready() -> void:
		pass


var _entry: Entry
var _sess: Session
var _srv: HostServer


func before_each() -> void:
	_entry = Entry.new()
	_entry.args.merge({"graphics": "low", "name": "Guest", "password": "", "role": Roles.CONTROLLER}, true)
	Engine.get_main_loop().root.add_child(_entry)


func after_each() -> void:
	_entry.free()
	if _srv != null:
		_srv.stop()
		_srv.free()
		_srv = null
	if _sess != null:
		_sess.dispose()
		_sess = null
	World.use_map(0)


func _count(kind: Script, parent: Node = null) -> int:
	var root: Node = _entry if parent == null else parent
	var n := 0
	for child in root.get_children():
		if is_instance_of(child, kind) and not child.is_queued_for_deletion():
			n += 1
	return n


func _child(kind: Script) -> Node:
	for child in _entry.get_children():
		if is_instance_of(child, kind) and not child.is_queued_for_deletion():
			return child
	return null


## A running table on loopback, the way test_multiplayer_menu hosts one.
func _hosted() -> void:
	_sess = Session.new({"seed": 4, "mode": Roles.VERSUS, "features": Session.SANDBOX_FEATURES})
	_srv = HostServer.new()
	_srv.attach(_sess)
	_srv.host_name = "Barry"
	_srv.password = "join-pw"
	_srv.start(0, Roles.VERSUS, "127.0.0.1")


func _no_host_services(why: String) -> void:
	check_eq(_count(HostServer), 0, why + ": a guest owns no server")
	check_eq(_count(LanDiscovery.Announcer), 0, why + ": and no beacon")


func test_join_reads_password_host_and_port() -> void:
	_entry.args["connect"] = "secret@127.0.0.1:47811"
	_entry._join()
	var link := _child(NetClient) as NetClient
	check(link != null, "one link is opened")
	check_eq(_count(NetClient), 1)
	if link == null:
		return
	check_eq(link.host, "127.0.0.1")
	check_eq(link.port, 47811)
	check_eq(link.password, "secret", "the password before the @")
	check_eq(link.name_, "Guest")
	check_eq(link.role, Roles.CONTROLLER)
	check_eq(_count(RoomScreen), 1, "the waiting-room screen is up")
	check_eq(_count(VoiceChat), 0, "no voice until a seat is taken")
	check_eq(_count(StationApp) + _count(RemoteSeat) + _count(SeatPicker), 0, "no seat yet")
	_no_host_services("joining")


func test_join_without_a_port_uses_the_default_and_pick_means_no_seat_yet() -> void:
	_entry.args["connect"] = "192.0.2.1"
	_entry.args["role"] = "pick"
	_entry._join()
	var link := _child(NetClient) as NetClient
	check(link != null)
	if link == null:
		return
	check_eq(link.host, "192.0.2.1", "a bare address is the host (it used to be ignored in favour of this machine)")
	check_eq(link.port, HostServer.DEFAULT_PORT, "no port means the default one")
	check_eq(link.role, "", "'pick' asks for no seat")


func test_cancelling_the_room_drops_the_link_and_shows_the_lobby() -> void:
	_entry.args["connect"] = "127.0.0.1:47812"
	_entry._join()
	var room := _child(RoomScreen) as RoomScreen
	var link := _child(NetClient) as NetClient
	check(room != null and link != null)
	if room == null or link == null:
		return
	room.cancelled.emit()
	check(link.is_queued_for_deletion(), "the link is released")
	check_eq(_count(RoomScreen), 0, "the room is gone")
	check(_child(Lobby) != null, "back in the lobby")
	check_eq(_count(VoiceChat), 0, "no voice was ever made")
	_no_host_services("cancelled join")


func test_a_named_station_seat_gets_one_station_and_one_voice() -> void:
	var link := NetClient.new()
	_entry.add_child(link)
	_entry._seat(link, Roles.CONTROLLER)
	check_eq(_count(StationApp), 1, "a desk seat opens the 2D station")
	check_eq(_count(RemoteSeat), 0)
	check_eq(_count(VoiceChat), 1, "one client voice pipeline")
	var voice := _child(VoiceChat) as VoiceChat
	if voice != null:
		check_eq(voice.link, link, "bound to this guest's link")
	check_eq(_count(NetClient), 1, "still the one link")
	_no_host_services("seated")


func test_the_pilot_and_interceptor_seats_are_3d_remote_seats() -> void:
	for role in [Roles.PILOT, Roles.INTERCEPTOR]:
		var e := Entry.new()
		e.args.merge({"graphics": "low", "name": "Guest"}, true)
		Engine.get_main_loop().root.add_child(e)
		var link := NetClient.new()
		e.add_child(link)
		e._seat(link, role)
		var seats := 0
		var stations := 0
		var voices := 0
		for c in e.get_children():
			if c is RemoteSeat: seats += 1
			if c is StationApp: stations += 1
			if c is VoiceChat: voices += 1
		check_eq(seats, 1, "%s: one 3D seat" % role)
		check_eq(stations, 0, "%s: no station" % role)
		check_eq(voices, 1, "%s: one voice" % role)
		e.free()


func test_the_copilot_seat_follows_the_seat3d_option() -> void:
	for seat3d in [false, true]:
		var e := Entry.new()
		e.args.merge({"graphics": "low", "name": "Guest", "seat3d": seat3d}, true)
		Engine.get_main_loop().root.add_child(e)
		var link := NetClient.new()
		e.add_child(link)
		e._seat(link, Roles.COPILOT)
		var seats := 0
		var stations := 0
		for c in e.get_children():
			if c is RemoteSeat: seats += 1
			if c is StationApp: stations += 1
		check_eq(seats, 1 if seat3d else 0, "seat3d=%s: 3D seat" % seat3d)
		check_eq(stations, 0 if seat3d else 1, "seat3d=%s: station" % seat3d)
		e.free()


func test_no_seat_yet_opens_the_picker_and_choosing_one_seats_the_guest_once() -> void:
	var link := NetClient.new()
	_entry.add_child(link)
	_entry._enter_game(link, "")
	var picker := _child(SeatPicker) as SeatPicker
	check(picker != null, "the picker opens")
	check_eq(_count(StationApp) + _count(RemoteSeat), 0, "nobody is seated yet")
	check_eq(_count(VoiceChat), 0, "and there is no voice yet")
	if picker == null:
		return
	picker.seated.emit(Roles.CONTROLLER)
	check_eq(_count(SeatPicker), 0, "the picker is gone")
	check_eq(_count(StationApp), 1, "seated at the chosen desk")
	check_eq(_count(VoiceChat), 1, "one voice pipeline")
	check_eq(_count(NetClient), 1, "one link")
	_no_host_services("picked a seat")


func test_a_role_by_name_skips_the_picker() -> void:
	var link := NetClient.new()
	_entry.add_child(link)
	_entry._enter_game(link, Roles.CONTROLLER)
	check_eq(_count(SeatPicker), 0, "no picker when the seat is named")
	check_eq(_count(StationApp), 1)
	check_eq(_count(VoiceChat), 1)


func test_joining_a_running_table_ends_with_one_station_and_one_voice() -> void:
	_hosted()
	_entry.args["connect"] = "join-pw@127.0.0.1:%d" % _srv.port
	_entry.args["role"] = Roles.CONTROLLER
	_entry._join()
	var link := _child(NetClient) as NetClient
	check(link != null)
	if link == null:
		return
	check_eq(link.password, "join-pw")
	var end := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < end and _count(StationApp) == 0:
		_srv._process(0.0)
		_srv.pump(_sess)
		_sess.update(1.0 / 60)
		await Engine.get_main_loop().process_frame
		OS.delay_msec(5)
	check_eq(link.error, null, "the host accepted the guest")
	check_eq(_count(StationApp), 1, "the guest reached a desk")
	check_eq(_count(RoomScreen), 0, "the room screen is gone")
	check_eq(_count(NetClient), 1, "one link")
	check_eq(_count(VoiceChat), 1, "one client voice pipeline")
	var voice := _child(VoiceChat) as VoiceChat
	if voice != null:
		check_eq(voice.link, link)
	_no_host_services("joined a running table")
