extends TestCase
const Main = preload("res://scripts/main.gd")

func _count(node: Node, kind: Script) -> int:
	var count := 0
	for child in node.get_children():
		if is_instance_of(child, kind): count += 1
	return count

func test_repeated_host_setup_keeps_one_voice_and_beacon() -> void:
	var app := Main.new()
	var server := HostServer.new()
	app.add_child(server)
	app._host_extras(server)
	app._host_extras(server)
	check_eq(_count(app, VoiceChat), 1, "one microphone/radio pipeline per host")
	check_eq(_count(server, LanDiscovery.Announcer), 1, "beacon follows server lifetime")
	app.free()

func test_null_host_does_not_create_network_services() -> void:
	var app := Main.new()
	app._host_extras(null)
	check_eq(app.get_child_count(), 0)
	app.free()

func test_waiting_room_beacon_is_reused_when_game_starts() -> void:
	var app := Main.new()
	var server := HostServer.new()
	app.add_child(server)
	server.host_name = "Test host"
	server.port = 47801
	var beacon := app._host_beacon(server)
	check_eq(_count(app, VoiceChat), 0, "waiting room does not open a microphone")
	check_eq(beacon.info.call().port, 47801)
	server.announce = false
	check(beacon.info.call().is_empty(), "announcement opt-out remains effective")
	server.announce = true
	app._host_extras(server)
	check_eq(app._host_beacon(server), beacon, "same beacon survives room-to-game transition")
	app.remove_child(server)
	server.free()
	check(not is_instance_valid(beacon), "cancelled host frees its beacon")
	app.free()

func test_client_seat_setup_reuses_one_voice_pipeline() -> void:
	var app := Main.new()
	var link := NetClient.new()
	var first := app._client_voice(link)
	check_eq(app._client_voice(link), first)
	check_eq(_count(app, VoiceChat), 1)
	app.free()
	link.free()
