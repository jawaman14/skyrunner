class_name HostServer
extends Node
## Listen server: the host runs the only simulation; remote seats send commands
## and receive role-filtered snapshots (port of net/server.py).
##
## Transport: TCP, one JSON object per line (protocol v3; v2 clients that name
## their role in the hello still join straight into it).
##   client -> server  {"t":"hello","v":3,"name":"Rosa","role":"copilot"?,"token":"..."?}
##                     {"t":"claim","role":"lieutenant"}  {"t":"release"}
##                     {"t":"say","text":"...","to":"all"|"side"}
##                     {"t":"cmd","seq":7,"name":"kick","args":{"count":2}}
##                     {"t":"input","roll":0.2,"pitch":-0.1,"throttle":0.8}  (police pilot)
##   server -> client  {"t":"welcome","role":"","mode":"coop","seed":7,"token":"..."}
##                     {"t":"seats","seats":[{role,side,who,name}],"players":[{name,role}],"you":"..."}
##                     {"t":"claimed","role":"..."}  {"t":"claim_failed","msg":"..."}
##                     {"t":"chat","from":"Rosa","role":"copilot","side":"runner","text":"...","to":"all"}
##                     {"t":"error","msg":"..."}  {"t":"ack","seq":7,"ok":true,"msg":"ok"}
##                     {"t":"snap",...}  (Snapshot.build; only to players in a seat)
## Every role is the AI's until someone claims it (Session.seats). Joining
## without a role puts you in the lobby with the live seat list; a dropped
## player's seat is held for Seats.HOLD_S and the welcome's token takes it back.
## Sockets are polled from _process; commands reach the Session in pump(),
## which the game loop calls around its update.

const DEFAULT_PORT := 47800
const MAX_LINE := 1 << 20
const MAX_LINES_PER_POLL := 64
const MAX_PENDING_COMMANDS := 64
const MAX_COMMAND_QUEUE := 1024
const MAX_ACKS := 256
const INPUT_TIMEOUT_MS := 1000
const SNAPSHOT_HZ := 20.0
const HELLO_TIMEOUT_MS := 10000
const VOICE_FRAMES_PER_S := 40  ## a talker sends 25 a second; more than this is dropped
const VOICE_MAX_S := 30.0  ## a transmission this long is cut off (a stuck key)

## A voice frame for the host's own player (the pilot's game is the host): {from, id, role, ch, s, q, k, d, end}.
signal voice_heard(msg: Dictionary)


class Conn:
	var peer: StreamPeerTCP
	var buf := PackedByteArray()
	var role := ""
	var name := ""
	var token := ""
	var v := 3
	var joined := false
	var t0 := 0
	var command_high_water := 0
	var pending_commands := {}
	var command_acks := {}
	var input_time := -1
	var seat_generation := 0


var tcp := TCPServer.new()
var port := DEFAULT_PORT
var mode := Roles.COOP
var world_seed := 7
var conns: Array = []
var clients := {}  ## role -> Conn
var inbox: Array = []  ## [role, seq, name, args, originating connection, seat generation]
var sticks := {}  ## role -> [roll, pitch, throttle]
var sess = null  ## the Session the seats belong to (set by attach or the first pump)
var chat_log: Array = []  ## [from, role, side, text, to]
var host_role := Roles.PILOT  ## the seat the host plays itself (its voice comes from there)
var room: Room = null  ## the waiting room, before the game exists (null once it has started)
var _room_rev := -1
var locked := false  ## closed to new players (a player who held a seat can still come back)
var banned := {}  ## tokens of players the host removed: they cannot rejoin this game
var max_players := 16
var dedicated := false  ## nobody plays the host's seat: the roster's first entry is the server itself
var password := ""  ## a dedicated server's: a hello without it is refused ("" = open to anyone who can reach the port)
var log_fn: Callable = Callable()  ## called with a line of text for joins, leaves and refusals (the dedicated server prints them)
var host_name := "host"
var announce := true  ## the LAN beacon says where this game is (the menu switches it)
var _keyed := {}  ## talker token -> {t0, n, sec, last} (when the key went down; frames this second)
var _seats_rev := -1
var _seats_t := 0.0
var _seq := 0
var _last_pub := -1e9


## Returns an error string, or null. Port 0 picks a free port (see `port`).
func start(port_ := DEFAULT_PORT, mode_ := Roles.COOP, bind := "*", seed := 7):
	mode = mode_
	world_seed = seed
	if port_ == 0:
		for p in range(47900, 48900):
			if tcp.listen(p, bind) == OK:
				port = p
				return null
		return "No free port."
	var err := tcp.listen(port_, bind)
	if err != OK:
		return "Can't listen on port %d (%s)." % [port_, error_string(err)]
	port = port_
	return null


func stop() -> void:
	for c in conns:
		c.peer.disconnect_from_host()
	conns.clear()
	clients.clear()
	tcp.stop()


func _exit_tree() -> void:
	stop()


static func line(msg: Dictionary) -> PackedByteArray:
	return (JSON.stringify(msg) + "\n").to_utf8_buffer()


## Pull complete lines out of a connection's buffer.
static func read_lines(peer: StreamPeerTCP, buf: PackedByteArray) -> Array:
	var n := mini(peer.get_available_bytes(), maxi(0, MAX_LINE + 1 - buf.size()))
	if n > 0:
		var r := peer.get_partial_data(n)
		if r[0] == OK:
			buf.append_array(r[1])
	return extract_lines(buf)


## Leave an oversized frame buffered so the caller can close it before parsing.
static func extract_lines(buf: PackedByteArray) -> Array:
	var out := []
	while out.size() < MAX_LINES_PER_POLL:
		var i := buf.find(10)
		if i < 0 or i > MAX_LINE:
			break
		out.append(buf.slice(0, i).get_string_from_utf8())
		var rest := buf.slice(i + 1)
		buf.clear()
		buf.append_array(rest)
	return out


func _process(_dt: float) -> void:
	if room != null and sess == null and room.rev != _room_rev:
		_room_rev = room.rev
		_broadcast_room()
	while tcp.is_listening() and tcp.is_connection_available():
		var c := Conn.new()
		c.peer = tcp.take_connection()
		c.peer.set_no_delay(true)
		c.t0 = Time.get_ticks_msec()
		conns.append(c)
	for c in conns.duplicate():
		c.peer.poll()
		var st: int = c.peer.get_status()
		if st != StreamPeerTCP.STATUS_CONNECTED:
			_drop(c)
			continue
		var lines := read_lines(c.peer, c.buf)
		if c.buf.size() > MAX_LINE:
			_drop(c)
			continue
		for l in lines:
			var msg = JSON.parse_string(l)
			if not (msg is Dictionary):
				continue
			if not c.joined:
				_hello(c, msg)
				if not c.joined:
					break
			else:
				_message(c, msg)
		if not c.joined and Time.get_ticks_msec() - c.t0 > HELLO_TIMEOUT_MS and conns.has(c):
			_drop(c)


func attach(sess_) -> void:
	sess = sess_


## Open a waiting room: listen now, before the game exists. Players join, choose seats and ready up (the room screen),
## and the host calls begin(session) to start.
func start_room(port_ := DEFAULT_PORT, mode_ := Roles.COOP, bind := "*", seed := 7, host_name_ := "host"):
	host_name = host_name_
	room = Room.new(mode_, host_name_)
	return start(port_, mode_, bind, seed)


func _room_message(c: Conn, msg: Dictionary) -> void:
	if room == null:
		return
	var pid := public_id(c.token)
	match msg.get("t"):
		"room_claim":
			var why := room.claim(pid, str(msg.get("role", "")))
			if why != "":
				c.peer.put_data(line({"t": "claim_failed", "msg": why}))
		"room_release":
			room.release(pid)
		"ready":
			room.set_ready(pid, bool(msg.get("on", false)))
		"say":
			var text := str(msg.get("text", "")).strip_edges().substr(0, 200)
			if text != "":
				chat(c.name, "", text, "all")


func _broadcast_room() -> void:
	var msg := room.to_dict()
	msg["t"] = "room"
	for c in conns:
		if c.joined:
			c.peer.put_data(line(msg))


## The host's own pick, in the room.
func host_claim(role: String) -> String:
	return room.claim(Room.HOST, role) if room != null else "No waiting room."


## Start the game: the Session exists now; everyone gets the seat they chose (the AI keeps the rest) and is told to begin.
func begin(sess_: Session) -> void:
	sess = sess_
	if room == null:
		return
	var host_seat := room.host_role()
	if host_seat != Roles.PILOT:
		sess.seats.release(Roles.PILOT)  # (a session starts with its pilot's seat the local player's: the host is at a desk)
	for id in room.players:
		var p: Dictionary = room.players[id]
		if p.role == "":
			continue
		if p.host:
			sess.seats.claim(p.role, p.name, "")
			continue
		for c in conns:
			if c.joined and public_id(c.token) == id:
				if sess.seats.claim(p.role, p.name, c.token) == "":
					c.role = p.role
					clients[p.role] = c
	room = null
	_seats_rev = -1
	for c in conns:
		if c.joined:
			c.peer.put_data(line({"t": "start", "role": c.role, "mode": mode, "seed": world_seed, "host_role": host_seat}))


func _log(text: String) -> void:
	if log_fn.is_valid():
		log_fn.call(text)


## What a status probe (or the multiplayer menu's list) may know before it has joined: no secrets.
func status() -> Dictionary:
	return {"t": "status", "name": host_name, "mode": mode, "players": roster().size() - (1 if dedicated else 0), "max": max_players, "locked": locked, "password": password != "",
		"v": Snapshot.PROTOCOL_VERSION, "time": snappedf(sess.time, 0.1) if sess != null else 0.0, "phase": "room" if (sess == null and room != null) else "game"}


func _hello(c: Conn, hello: Dictionary) -> void:
	if hello.get("t") == "status":  # a health check: answer and hang up (a load balancer or `nc` can ask without joining)
		c.peer.put_data(line(status()))
		_drop(c)
		return
	var role := str(hello.get("role", ""))
	var name := str(hello.get("name", "player")).substr(0, 32)
	var v := int(hello.get("v", -1))
	var err := ""
	if hello.get("t") != "hello" or not (v in [2, Snapshot.PROTOCOL_VERSION]):
		err = "Protocol mismatch (server v%d)." % Snapshot.PROTOCOL_VERSION
	elif sess == null and room == null:
		err = "The host isn't ready yet."
	elif role != "" and not Roles.valid(role):
		err = "No such role %s." % role
	elif v == 2 and role == "":
		err = "Protocol v2 needs a role."
	elif password != "" and str(hello.get("password", "")) != password:
		err = "This server needs a password (join as password@host:port, or --password)."
	if err != "":
		c.peer.put_data(line({"t": "error", "msg": err}))
		_log("refused %s: %s" % [name, err])
		_drop(c)
		return
	c.name = name
	c.v = v
	c.token = str(hello.get("token", "")).substr(0, 64)
	if c.token == "":
		c.token = "%08x%08x" % [randi(), randi()]
	var refusal := ""
	if banned.has(c.token):
		refusal = "The host has removed you from this game."
	elif locked and (sess == null or sess.seats.held_for(c.token) == ""):
		refusal = "The host has closed the table to new players."
	elif conns.filter(func(x): return x.joined).size() >= max_players:
		refusal = "The table is full (%d)." % max_players
	if refusal != "":
		c.peer.put_data(line({"t": "error", "msg": refusal}))
		_log("refused %s: %s" % [name, refusal])
		_drop(c)
		return
	if sess == null:  # the waiting room: sit down, pick a seat, get ready
		var pid := public_id(c.token)
		room.add(pid, name)
		if role != "":
			room.claim(pid, role)  # (a seat asked for on the way in; if it is taken they simply have none yet)
		c.joined = true
		c.peer.put_data(line({"t": "welcome", "capabilities": ["action_previews"], "role": "", "mode": mode, "seed": world_seed, "token": c.token, "v": Snapshot.PROTOCOL_VERSION, "phase": "room"}))
		_room_rev = -1
		return
	# a returning player takes back the seat held for them
	var held: String = sess.seats.held_for(c.token)
	if held != "" and role == "":
		role = held
	if role != "":
		var why: String = sess.seats.claim(role, name, c.token)
		if why != "":
			c.peer.put_data(line({"t": "error", "msg": why}))
			_drop(c)
			return
		c.role = role
		clients[role] = c
	c.joined = true
	c.peer.put_data(line({"t": "welcome", "capabilities": ["action_previews"], "role": c.role, "mode": mode, "seed": world_seed, "token": c.token, "v": Snapshot.PROTOCOL_VERSION}))
	_log("%s joined%s (%d here)" % [name, (" as " + c.role) if c.role != "" else " (no seat yet)", conns.filter(func(x): return x.joined).size()])
	_seats_rev = -1  # everyone gets the new roster


func _message(c: Conn, msg: Dictionary) -> void:
	if sess == null and msg.get("t") == "preview_request":
		c.peer.put_data(line({"t": "preview", "seq": int(msg.get("seq", 0)), "role": c.role, "action": ActionDescriptions.unavailable(str(msg.get("name", "")), {}, "Game not started; preview unavailable.")}))
		return
	if sess == null:
		_room_message(c, msg)
		return
	if msg.get("t") == "preview_request":
		var name := str(msg.get("name", "")).substr(0, 32)
		var raw: Dictionary = msg.get("args", {}) if msg.get("args") is Dictionary else {}
		var args := {}
		for key in raw.keys().slice(0, 8):
			args[str(key).substr(0, 32)] = raw[key]
		var action: Dictionary = sess.describe_action(c.role, name, args)
		c.peer.put_data(line({"t": "preview", "seq": int(msg.get("seq", 0)), "role": c.role, "action": action}))
		return
	match msg.get("t"):
		"claim":
			var role := str(msg.get("role", ""))
			c.seat_generation += 1
			if c.role != "":
				_clear_input(c)
				sess.seats.release(c.role)
				clients.erase(c.role)
				c.role = ""
			var why: String = sess.seats.claim(role, c.name, c.token)
			if why != "":
				c.peer.put_data(line({"t": "claim_failed", "msg": why}))
			else:
				c.role = role
				clients[role] = c
				c.peer.put_data(line({"t": "claimed", "role": role}))
				_log("%s took the %s seat" % [c.name, role])
			_seats_rev = -1
			return
		"release":
			if c.role != "":
				c.seat_generation += 1
				_clear_input(c)
				sess.seats.release(c.role)
				clients.erase(c.role)
				sticks.erase(c.role)
				c.role = ""
				c.peer.put_data(line({"t": "claimed", "role": ""}))
				_seats_rev = -1
			return
		"voice":
			relay_voice(c.token, c.name, c.role, str(msg.get("ch", "net")), int(msg.get("s", 0)), str(msg.get("d", "")), bool(msg.get("end", false)))
			return
		"say":
			var text := str(msg.get("text", "")).strip_edges().substr(0, 200)
			if text != "":
				chat(c.name, c.role, text, "side" if msg.get("to") == "side" else "all")
			return
	if c.role == "":
		if msg.get("t") == "cmd":
			c.peer.put_data(line({"t": "ack", "seq": int(msg.get("seq", 0)), "ok": false, "msg": "Claim a seat first."}))
		return
	if msg.get("t") == "cmd" and msg.get("args", {}) is Dictionary:
		var seq := int(msg.get("seq", 0))
		if c.command_acks.has(seq):
			c.peer.put_data(line(c.command_acks[seq]))
			return
		if c.pending_commands.has(seq):
			return
		if seq <= c.command_high_water:
			c.peer.put_data(line({"t": "ack", "seq": seq, "ok": false, "msg": "Expired or invalid command sequence; command not executed."}))
			return
		c.command_high_water = seq
		if c.pending_commands.size() >= MAX_PENDING_COMMANDS or inbox.size() >= MAX_COMMAND_QUEUE:
			_complete_command(c, seq, false, "Command queue full; command not executed.")
			return
		var args := {}
		var raw: Dictionary = msg.get("args", {})
		for k in raw.keys().slice(0, 8):
			args[str(k).substr(0, 32)] = raw[k]
		c.pending_commands[seq] = true
		inbox.append([c.role, seq, str(msg.get("name", "")).substr(0, 32), args, c, c.seat_generation])
	elif msg.get("t") == "input" and c.role == Roles.PILOT:
		var st := {}
		for k in ["roll", "pitch", "throttle", "rudder", "brake"]:
			var x = msg.get(k, 0.0)
			st[k] = clampf(float(x), -1.0 if k in ["roll", "pitch", "rudder"] else 0.0, 1.0) if (x is float or x is int) else 0.0
		sess.remote_stick = st
		c.input_time = Time.get_ticks_msec()
	elif msg.get("t") == "input" and c.role == Roles.INTERCEPTOR:
		var v := []
		for k in ["roll", "pitch", "throttle"]:  # latest stick position wins; no queueing, no acks
			var x = msg.get(k, 0.0)
			v.append(clampf(float(x), -1.0, 1.0) if (x is float or x is int) else 0.0)
		sticks[c.role] = v
		c.input_time = Time.get_ticks_msec()


func _drop(c: Conn) -> void:
	if c.joined and conns.has(c):
		_log("%s left%s" % [c.name, (" (seat %s held for them)" % c.role) if c.role != "" else ""])
	conns.erase(c)
	if sess == null and room != null and c.joined:
		room.remove(public_id(c.token))
	if c.joined and c.role != "" and clients.get(c.role) == c:
		_clear_input(c)
		clients.erase(c.role)
		sticks.erase(c.role)
		if sess != null:
			sess.seats.release(c.role, true)  # held for them: the token takes it back
		_seats_rev = -1
	c.peer.disconnect_from_host()


## Neutralize expired controls without changing seat ownership or issuing AI orders.
func _clear_input(c: Conn) -> void:
	c.input_time = -1
	if sess == null:
		return
	if c.role == Roles.PILOT:
		sess.remote_stick = {}
	elif c.role == Roles.INTERCEPTOR:
		sticks.erase(c.role)
		sess.set_pilot_input(c.role, 0.0, 0.0, 0.0)


## A chat line: to everyone, or to one side's players (and the host, who sees
## both sides' as a spectator of the table's talk only when it's to all).
func chat(from: String, role: String, text: String, to := "all") -> void:
	var side := Roles.side(role) if role != "" else ""
	var msg := {"t": "chat", "from": from, "role": role, "side": side, "text": text, "to": to}
	chat_log.append([from, role, side, text, to])
	Py.keep_last(chat_log, 50)
	for c in conns:
		if c.joined and (to == "all" or (c.role != "" and Roles.side(c.role) == side)):
			c.peer.put_data(line(msg))
	if sess != null:
		var t := "[%s%s] %s: %s" % ["team " if to == "side" else "", role if role != "" else "lobby", from, text]
		if to == "all" or side == "runner":
			sess.say(t)
		if to == "all" or side == "law":
			sess.law_say(t)


## One voice frame (or, with `end`, the key coming up) from a talker: routed by the radio's rules (VoiceRouter) to
## whoever hears it, each with the quality they hear it at. A transmission on the net also goes to the DF stations
## when it ends (Session.voice_transmitted). `from_id` is the talker's token ("host" for the host's own voice).
## A player's public id: what the others see them as (the voice roster, mutes, kicks). The token is the reconnect
## credential, so it is never sent to anyone but its owner.
static func public_id(token: String) -> String:
	return token if token == "host" else token.sha1_text().substr(0, 10)


func relay_voice(from_id: String, from_name: String, from_role: String, ch: String, seq: int, d: String, end: bool) -> void:
	if sess == null or not (ch in ["net", "all"]) or d.length() > VoiceCodec.MAX_FRAME_B64:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var k: Dictionary = _keyed.get(from_id, {})
	if k.is_empty() or now - float(k.get("last", -99.0)) > 1.0:
		k = {"t0": now, "n": 0, "sec": int(now), "last": now}  # a new transmission: the key went down
	if int(k.sec) != int(now):
		k.sec = int(now)
		k.n = 0
	k.n = int(k.n) + 1
	k.last = now
	_keyed[from_id] = k
	if int(k.n) > VOICE_FRAMES_PER_S or now - float(k.t0) > VOICE_MAX_S:
		if end:
			_keyed.erase(from_id)
		return
	var listeners := conns.filter(func(c): return c.joined).map(func(c): return {"id": c.token, "role": c.role})
	listeners.append({"id": "host", "role": host_role})
	for r in VoiceRouter.route(sess, from_id, from_role, ch, listeners):
		var msg := {"t": "voice", "from": from_name, "id": public_id(from_id), "role": from_role, "ch": ch, "s": seq, "q": snappedf(float(r.q), 0.01),
			"k": r.kind, "d": d, "end": end}
		if str(r.id) == "host":
			voice_heard.emit(msg)
			continue
		for c in conns:
			if c.joined and c.token == str(r.id):
				c.peer.put_data(line(msg))
	if end:
		if ch == "net":
			sess.voice_transmitted(from_role, now - float(k.t0))
		_keyed.erase(from_id)


## The host's own microphone (its seat is host_role).
func host_voice(ch: String, seq: int, d: String, end: bool) -> void:
	relay_voice("host", host_name, host_role, ch, seq, d, end)


## Remove a player (their token): they are told why, and with `ban` they cannot come back this game.
func kick(token: String, ban := true) -> bool:
	for c in conns:
		if c.joined and (c.token == token or public_id(c.token) == token):
			c.peer.put_data(line({"t": "error", "msg": "The host has removed you from this game."}))
			if ban:
				banned[c.token] = true
			_drop(c)
			return true
	return false


## Who is at the table: [{token, name, role, host}], the host first.
func roster() -> Array:
	var out := [{"token": "host", "id": "host", "name": host_name, "role": host_role, "host": true}]
	for c in conns:
		if c.joined:
			out.append({"token": c.token, "id": public_id(c.token), "name": c.name, "role": c.role, "host": false})
	return out


func _broadcast_seats() -> void:
	var roster: Array = sess.seats.roster()
	var players := [{"id": "host", "name": host_name, "role": host_role}]
	players.append_array(conns.filter(func(c): return c.joined).map(func(c): return {"id": public_id(c.token), "name": c.name, "role": c.role}))
	for c in conns:
		if c.joined:
			c.peer.put_data(line({"t": "seats", "seats": roster, "players": players, "you": c.role}))


func _send(role: String, msg: Dictionary) -> void:
	var c: Conn = clients.get(role)
	if c != null and c.peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		c.peer.put_data(line(msg))


## Deduplication is connection-scoped. Reconnects never replay pending mutations.
func _complete_command(c: Conn, seq: int, ok: bool, message: String) -> void:
	c.pending_commands.erase(seq)
	var ack := {"t": "ack", "seq": seq, "ok": ok, "msg": message}
	c.command_acks[seq] = ack
	while c.command_acks.size() > MAX_ACKS:
		c.command_acks.erase(c.command_acks.keys()[0])
	if conns.has(c) and c.peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		c.peer.put_data(line(ack))


# ------------------------------------------------------------ game side
## Apply joins/leaves and queued commands. Call from the game loop.
func pump(sess_: Session) -> void:
	sess = sess_
	sess.seats.tick(sess.time)
	var now := Time.get_ticks_msec() / 1000.0
	for c in conns:
		if c.input_time >= 0 and Time.get_ticks_msec() - c.input_time > INPUT_TIMEOUT_MS:
			_clear_input(c)
	if sess.seats.rev != _seats_rev or now - _seats_t > 1.0:
		_seats_rev = sess.seats.rev
		_seats_t = now
		_broadcast_seats()
	for role in sticks:
		sess.set_pilot_input(role, sticks[role][0], sticks[role][1], sticks[role][2])
	var batch := inbox.slice(0, MAX_PENDING_COMMANDS)
	inbox = inbox.slice(batch.size())
	for m in batch:
		var c: Conn = m[4]
		if not conns.has(c) or clients.get(m[0]) != c or c.role != m[0] or c.seat_generation != m[5]:
			_complete_command(c, m[1], false, "Seat changed or disconnected; command not executed.")
			continue
		var r: Array = sess.command(m[0], m[2], m[3])
		_complete_command(c, m[1], bool(r[0]), str(r[1]))


func publish(sess: Session, force := false) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not force and now - _last_pub < 1.0 / SNAPSHOT_HZ:
		return
	_last_pub = now
	_seq += 1
	for role in clients.keys():
		_send(role, Snapshot.build(sess, role, _seq))
