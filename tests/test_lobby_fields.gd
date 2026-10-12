extends TestCase
## The lobby's hosting fields (owner, 12 Oct, #97): game name, password and port go with the options; every seat a guest can take is a join role; and "Host a
## multiplayer game" with the task-force desk selected opens a police table, not the offline desk the Fly button starts.

var _lobby: Lobby


func before_each() -> void:
	_lobby = Lobby.new()
	Engine.get_main_loop().root.add_child(_lobby)


func after_each() -> void:
	_lobby.free()


func test_the_name_password_and_port_go_with_the_options() -> void:
	var plain := _lobby._opts()
	check(not plain.has("name"), "a blank name keeps the game's own default")
	check_eq(plain.port, 47800, "the usual port")
	check_eq(plain.password, "", "no password")
	_lobby.host_name_le.text = "  Ann's table  "
	_lobby.password_le.text = "swordfish"
	_lobby.port_box.value = 5000
	var o := _lobby._opts()
	check_eq(o.name, "Ann's table", "the typed name, trimmed")
	check_eq(o.password, "swordfish")
	check_eq(o.port, 5000)


func test_every_seat_a_guest_can_take_is_a_join_role() -> void:
	for r in [Roles.FIXER, Roles.MECHANIC, Roles.ANALYST, Roles.UNDERCOVER]:
		check(r in Lobby.JOIN_ROLES, "%s can be picked when joining" % r)
	for r in Lobby.JOIN_ROLES:
		check(r == "" or Roles.valid(r), "%s is a real role" % r)


func test_hosting_a_task_force_desk_opens_a_police_table_and_fly_starts_the_offline_desk() -> void:
	var police_index := -1
	for i in Lobby.MODES.size():
		if Lobby.MODES[i][1] == "police":
			police_index = i
	check(police_index >= 0)
	_lobby.mode_ob.select(police_index)
	var fly := _lobby._opts()
	check(fly.police and fly.mode == "solo", "Fly: the offline desk against AI runners")
	var room := _lobby._room_opts()
	check(room.mode == "police" and not room.police, "Host a multiplayer game: a police table")
