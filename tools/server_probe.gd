extends SceneTree
## Asks a Skyrunner server for its status without joining (what a health check does) and prints it; exits 0 if it answered, 1 if not.
##
##   godot --headless --script res://tools/server_probe.gd -- HOST [PORT] [--join ROLE] [--password PW]
##
## --join also takes a seat (ROLE, e.g. boss) and waits for a snapshot, to prove the game is really being served.
var peer := StreamPeerTCP.new()
var link: NetClient = null
var buf := PackedByteArray()
var host := "127.0.0.1"
var port := 47800
var join_role := ""
var password := ""
var t := 0.0
var sent := false
var status := {}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	var plain := []
	while i < a.size():
		match a[i]:
			"--join":
				join_role = a[i + 1]
				i += 1
			"--password":
				password = a[i + 1]
				i += 1
			_:
				plain.append(a[i])
		i += 1
	if plain.size() > 0:
		host = plain[0]
	if plain.size() > 1:
		port = int(plain[1])
	peer.connect_to_host(host, port)


func _process(dt: float) -> bool:
	t += dt
	if status.is_empty():
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED and not sent:
			peer.put_data(HostServer.line({"t": "status"}))
			sent = true
		for l in HostServer.read_lines(peer, buf):
			var m = JSON.parse_string(l)
			if m is Dictionary and m.get("t") == "status":
				status = m
		if status.is_empty():
			if t > 8.0 or peer.get_status() == StreamPeerTCP.STATUS_ERROR:
				printerr("no answer from %s:%d" % [host, port])
				quit(1)
				return true
			return false
		print(JSON.stringify(status))
		if join_role == "":
			quit(0)
			return true
		link = NetClient.new()
		link.password = password
		root.add_child(link)
		link.open(host, port, "probe", join_role)
		t = 0.0
		return false
	if link != null:
		if link.error != null:
			printerr("join failed: %s" % link.error)
			quit(1)
			return true
		if link.latest != null:
			print("joined as %s and received a snapshot" % link.latest.get("role"))
			quit(0)
			return true
		if t > 10.0:
			printerr("joined but no snapshot arrived")
			quit(1)
			return true
	return false
