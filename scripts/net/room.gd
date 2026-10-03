class_name Room
extends RefCounted
## The waiting room before a multiplayer game starts: who is here, which seat each has chosen, who is ready. Pure data and
## rules (the host's HostServer keeps one and sends it to everyone; the room screen draws it), so it is tested without a
## network. When the host starts the game each player's seat is handed to them (HostServer.begin); seats nobody chose are
## the AI's.
##
## A player holds at most one seat and a seat at most one player. The host plays one too: the pilot's (the 3D seat) by
## default, or any desk (a 2D station): the aircraft then flies itself unless somebody else takes the seat.

const HOST := "host"
const RUNNER_ROLES := [Roles.PILOT, Roles.COPILOT, Roles.SPOTTER, Roles.BOAT, Roles.BOSS, Roles.LIEUTENANT]
const LAW_ROLES := [Roles.CONTROLLER, Roles.INTERCEPTOR, Roles.CUTTER, Roles.CHIEF, Roles.PATROL]
## What the host can sit in: the pilot (3D), or a desk it can run as a 2D station (the police pilot's 3D seat is for guests).
const HOST_ROLES := [Roles.PILOT, Roles.COPILOT, Roles.SPOTTER, Roles.BOAT, Roles.BOSS, Roles.LIEUTENANT, Roles.CONTROLLER, Roles.CUTTER, Roles.CHIEF, Roles.PATROL]

var mode := Roles.COOP
var players := {}  ## id -> {id, name, role, ready, host}
var rev := 0  ## bumped on every change


func _init(mode_ := Roles.COOP, host_name := "host", host_role := Roles.PILOT) -> void:
	mode = mode_
	players[HOST] = {"id": HOST, "name": host_name, "role": host_role if available(host_role) else Roles.PILOT, "ready": true, "host": true}


## Is `role` in this kind of game? A co-op table is the runners only (the law is the AI); a task-force game (police) has no pilot.
func available(role: String) -> bool:
	if not Roles.valid(role):
		return false
	if mode == Roles.COOP and Roles.side(role) == "law":
		return false
	if mode == Roles.POLICE and role == Roles.PILOT:
		return false
	return true


func add(id: String, name: String) -> void:
	if players.has(id):
		players[id].name = name
		return
	players[id] = {"id": id, "name": name.substr(0, 32), "role": "", "ready": false, "host": false}
	rev += 1


func remove(id: String) -> void:
	if id != HOST and players.erase(id):
		rev += 1


func holder(role: String) -> String:
	for id in players:
		if players[id].role == role:
			return id
	return ""


## `id` takes `role` (leaving the one they had). Returns "" or why not.
func claim(id: String, role: String) -> String:
	if not players.has(id):
		return "You are not at this table."
	if not available(role):
		return "There is no %s in this kind of game." % role
	if id == HOST and not (role in HOST_ROLES):
		return "The host can't take the %s: the police pilot's seat is for a guest." % role
	var h := holder(role)
	if h != "" and h != id:
		return "%s is taken by %s." % [role, players[h].name]
	if players[id].role != role:
		players[id].role = role
		if id != HOST:
			players[id].ready = false  # a new seat: confirm it again
		rev += 1
	return ""


## `id` gives their seat back to the AI (and may not stay ready).
func release(id: String) -> void:
	if players.has(id) and players[id].role != "":
		players[id].role = ""
		rev += 1


func set_ready(id: String, on: bool) -> void:
	if players.has(id) and not players[id].host and players[id].ready != on:
		players[id].ready = on
		rev += 1


## The host may start when everyone else has a seat and is ready. Returns "" or what is missing.
func can_start() -> String:
	for id in players:
		var p: Dictionary = players[id]
		if p.host:
			continue
		if p.role == "":
			return "%s has not chosen a seat." % p.name
		if not p.ready:
			return "%s is not ready." % p.name
	return ""


## The seats as the screen lists them, runners then law: [{role, side, about, available, who ("player" | "ai" | "off"), id, name}].
func seats() -> Array:
	var out := []
	for role in RUNNER_ROLES + LAW_ROLES:
		var h := holder(role)
		var who := "off" if not available(role) else ("player" if h != "" else "ai")
		out.append({"role": role, "side": Roles.side(role), "about": Roles.ABOUT.get(role, ""), "available": available(role), "who": who,
			"id": h, "name": players[h].name if h != "" else ""})
	return out


## What goes to everyone: {mode, players: [{id, name, role, ready, host}], seats}.
func to_dict() -> Dictionary:
	var ps := []
	for id in players:
		ps.append(players[id].duplicate())
	return {"mode": mode, "players": ps, "seats": seats(), "start": can_start() == ""}


## The host's pick as a role string ("" is not possible: the host always has a seat).
func host_role() -> String:
	return players[HOST].role
