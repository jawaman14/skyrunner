class_name LanDiscovery
extends RefCounted
## Finding games on the local network without typing an address. A hosting game shouts a small JSON beacon every two
## seconds by UDP broadcast (port 47801); the multiplayer menu listens and lists what it hears. The beacon is only
## where the game is and who is in it - joining still goes through the host's own TCP port and its seats.
##
##   Announcer   (a Node under the hosting game) sends the beacon
##   Finder      (a Node under the menu) collects them

const PORT := 47801
const MAGIC := "skyrunner-lan"
const EVERY_S := 2.0
const STALE_S := 7.0  ## a game not heard from for this long is gone from the list


## The bytes of a beacon.
static func beacon(name: String, port: int, mode: String, players: int, locked := false) -> PackedByteArray:
	return JSON.stringify({"magic": MAGIC, "v": Snapshot.PROTOCOL_VERSION, "name": name.substr(0, 32), "port": port, "mode": mode,
		"players": players, "locked": locked}).to_utf8_buffer()


## A beacon as a dictionary {name, ip, port, mode, players, locked}, or {} if the packet is not one of ours.
static func parse(bytes: PackedByteArray, from_ip: String) -> Dictionary:
	if bytes.size() == 0 or bytes.size() > 512:
		return {}
	var j := JSON.new()
	if j.parse(bytes.get_string_from_utf8()) != OK:
		return {}
	var d = j.data
	if not (d is Dictionary) or d.get("magic") != MAGIC or int(d.get("v", -1)) != Snapshot.PROTOCOL_VERSION:
		return {}
	var port := int(d.get("port", 0))
	if port < 1 or port > 65535:
		return {}
	return {"name": str(d.get("name", "game")).substr(0, 32), "ip": from_ip, "port": port, "mode": str(d.get("mode", "")),
		"players": int(d.get("players", 0)), "locked": bool(d.get("locked", false))}


## This machine's private IPv4 addresses (what a friend on the network would type).
static func local_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out


class Announcer:
	extends Node
	## Add under the hosting game; `info` is a Callable returning {name, port, mode, players, locked}.
	var info: Callable = Callable()
	var dest := "255.255.255.255"
	var dest_port := PORT
	var _udp := PacketPeerUDP.new()
	var _t := EVERY_S  ## the first beacon goes out at once

	func start(info_: Callable, dest_ := "255.255.255.255", dest_port_ := PORT) -> Announcer:
		info = info_
		dest = dest_
		dest_port = dest_port_
		_udp.set_broadcast_enabled(true)
		_udp.set_dest_address(dest, dest_port)
		name = "lan_announcer"
		return self

	func _process(dt: float) -> void:
		_t += dt
		if _t >= EVERY_S:
			_t = 0.0
			send_now()

	func send_now() -> void:
		if not info.is_valid():
			return
		var i: Dictionary = info.call()
		if i.is_empty():
			return  # (not announcing)
		_udp.put_packet(LanDiscovery.beacon(str(i.get("name", "game")), int(i.get("port", 0)), str(i.get("mode", "")), int(i.get("players", 0)), bool(i.get("locked", false))))

	func _exit_tree() -> void:
		_udp.close()


class Finder:
	extends Node
	## Add under the menu; `games` is key ("ip:port") -> {name, ip, port, mode, players, locked, seen}.
	var games := {}
	var _udp := PacketPeerUDP.new()
	var listening := false

	func start(port := PORT) -> Finder:
		name = "lan_finder"
		listening = _udp.bind(port) == OK  # (another copy of the game on this machine may hold it: then the list stays empty)
		return self

	func _process(_dt: float) -> void:
		while listening and _udp.get_available_packet_count() > 0:
			var bytes := _udp.get_packet()
			ingest(bytes, _udp.get_packet_ip())

	## One packet (also how the tests feed it).
	func ingest(bytes: PackedByteArray, from_ip: String, now := -1.0) -> void:
		var g := LanDiscovery.parse(bytes, from_ip)
		if g.is_empty():
			return
		g["seen"] = now if now >= 0.0 else Time.get_ticks_msec() / 1000.0
		games["%s:%d" % [g.ip, g.port]] = g

	## The games heard from recently, newest-name first by name.
	func list(now := -1.0) -> Array:
		var t := now if now >= 0.0 else Time.get_ticks_msec() / 1000.0
		var out := []
		for k in games.keys():
			if t - float(games[k].seen) > STALE_S:
				games.erase(k)
			else:
				out.append(games[k])
		out.sort_custom(func(a, b): return str(a.name) < str(b.name))
		return out

	func _exit_tree() -> void:
		_udp.close()
