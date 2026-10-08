extends Node
## Entry point (port of skyrunner/__main__.py).
##
##   godot                                   # sandbox, solo
##   godot                                   # the story: Costa Brava 1979-1989, factions unlock chapter by chapter
##   godot -- --unlocks open                 # open world: every faction and mechanic from the start
##   godot -- --tutorial                     # the tutorial: lessons as you play, tips when things happen
##   godot -- --chapter 4                    # the story, skipping ahead to chapter 4 (1982)
##   godot -- --mode campaign                # four flying lessons on Costa Brava
##   godot -- --mode coop                    # host: friends join as co-pilot / spotter
##   godot -- --mode versus                  # host: a friend runs the task-force desk
##   godot -- --police                       # play the task force against AI runners
##   godot -- --players 6                    # seats and rule layers for a table of six
##   godot -- --watch --graphics low         # the AI flies the career; you watch
##   godot -- --map city                     # Costa Brava, the city coast (the default for new games)
##   godot -- --map 42                       # a generated island (positive seeds only)
##   godot -- --shot out.png --frames 90     # render N frames, save a screenshot, quit
##   godot --headless -- --smoke 600         # run N frames of a new game, print SMOKE OK, quit (CI)
##
## With no arguments the lobby opens, which sets the same options with menus.

var _finder: LanDiscovery.Finder = null  ## listens for games on the network (the multiplayer menu's list)
var _mp: MultiplayerMenu = null
var save_dir := "user://"  ## the tests point it elsewhere so they never touch a player's saves

var args := {"mode": "solo", "police": false, "host": false, "port": 47800, "bind": "*", "new": false, "seed": 1,
	"players": 0, "layer": 0, "graphics": "high", "watch": false, "shot": "", "frames": 90, "hour": -1.0,
	"map": -1, "weather": "", "connect": "", "host_room": null, "role": "copilot", "name": "player", "password": "", "seat3d": false, "lobby": true, "unlocks": "story", "chapter": 0, "tutorial": false, "smoke": 0}


func _ready() -> void:
	Terrain.natural = not OS.get_cmdline_user_args().has("--classic-terrain")  # eroded hills; --classic-terrain for the generator the balance numbers were measured on
	var look := ControlsConfig.settings()
	UIStyle.set_palette(look.palette)  # neon, or colour-safe (F8 in the 3D seat, or the pause menu)
	PauseMenu.apply_volume(float(look.volume))
	args["graphics"] = str(look.graphics)  # the pause menu's choice; --graphics still wins
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		var k: String = a[i].trim_prefix("--")
		if args.has(k) and args[k] is bool:
			args[k] = true
		elif args.has(k) and i + 1 < a.size():
			var v: String = a[i + 1]
			if k == "map" and v == "city":
				v = str(MapCity.SEED)
			args[k] = int(v) if args[k] is int else (float(v) if args[k] is float else v)
			i += 1
		else:
			push_warning("unknown argument " + a[i])
		i += 1
	if not a.is_empty():
		args["lobby"] = false
	if args["lobby"]:
		show_lobby()
		return
	start()


func show_lobby(notice := "") -> void:
	var lobby := Lobby.new()
	lobby.startup_notice = notice
	add_child(lobby)
	lobby.multiplayer_requested.connect(func(): open_mp())
	lobby.room_requested.connect(func(opts):
		lobby.queue_free()
		args.merge(opts, true)
		_open_room())
	lobby.start.connect(func(opts):
		lobby.queue_free()
		args.merge(opts, true)
		start())


## Voice and the network beacon for a hosting game.
func _host_extras(server) -> void:
	if server == null:
		return
	_host_beacon(server)
	for child in get_children():
		if child is VoiceChat and child.server == server and not child.is_queued_for_deletion():
			return
	add_child(VoiceChat.new().attach_host(server))  # push-to-talk radio voice for the table

## Available in the waiting room as well as the running game. Server ownership
## makes cancellation close the beacon without leaving a stale lobby advert.
func _host_beacon(server: HostServer) -> LanDiscovery.Announcer:
	for child in server.get_children():
		if child is LanDiscovery.Announcer and not child.is_queued_for_deletion():
			return child
	var ann := LanDiscovery.Announcer.new()
	server.add_child(ann)
	ann.start(func(): return {} if not server.announce else {"name": "%s's game" % server.host_name, "port": server.port, "mode": server.mode, "players": server.roster().size(), "locked": server.locked})
	return ann


## The host's waiting room: listen now, show the room, and when the host starts, build the game with the server that is already
## listening (its players have chosen their seats).
func _open_room() -> void:
	var map_error := PlayableMaps.error(int(args["map"]))
	if map_error != "":
		show_lobby(map_error)
		return
	var server := HostServer.new()
	server.password = str(args["password"])
	add_child(server)
	var mode: String = "versus" if args["mode"] == "versus" else "coop"
	var err = server.start_room(args["port"], mode, "*", args["seed"], str(args["name"]))
	if err:
		push_warning(str(err))
		server.queue_free()
		show_lobby()
		return
	_host_beacon(server)
	var room := RoomScreen.new()
	add_child(room)
	room.setup(server, null)
	room.start_game.connect(func():
		room.queue_free()
		args["host_room"] = server
		args["mode"] = mode
		start())
	room.cancelled.connect(func():
		room.queue_free()
		server.queue_free()
		show_lobby())


## F4 (and the lobby's Multiplayer button): the multiplayer menu over whatever is running.
func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F4 and _mp == null:
		open_mp()
		get_viewport().set_input_as_handled()


func open_mp() -> MultiplayerMenu:
	if _mp != null:
		return _mp
	if _finder == null:
		_finder = LanDiscovery.Finder.new().start()
		add_child(_finder)
	var server: HostServer = null
	var link: NetClient = null
	var voice: VoiceChat = null
	for c in get_children():
		if c is HostServer:
			server = c
		elif c is NetClient:
			link = c
		elif c is VoiceChat:
			voice = c
	_mp = MultiplayerMenu.new()
	add_child(_mp)
	_mp.player_name = str(args["name"])
	_mp.setup(server, link, voice, _finder)
	_mp.join_requested.connect(_mp_join)
	_mp.closed.connect(func(): _mp = null)
	return _mp


## The menu asked to join a game: leave whatever is running and connect.
func _mp_join(address: String, role: String, player_name: String) -> void:
	args["connect"] = address
	args["role"] = role if role != "" else "pick"
	args["name"] = player_name
	if _mp != null:
		_mp.queue_free()
		_mp = null
	for c in get_children():
		if c is Lobby:
			c.queue_free()
	_leave("join")


## The pause menu's exits: tear the game down, then reload its save, open the lobby, or quit.
func _leave(to: String) -> void:
	if to == "desktop":
		get_tree().quit()
		return
	for c in get_children():
		if c is PilotApp or c is StationApp or c is HostServer or c is RemoteSeat or c is NetClient or c is VoiceChat or c is LanDiscovery.Announcer or c is MultiplayerMenu or c is RoomScreen or c is SeatPicker or c is HostDesk:
			remove_child(c)
			c.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	args["new"] = false  # a reload is the save as it is now, never a fresh game
	if to == "load" or to == "join":
		args["graphics"] = str(ControlsConfig.settings().graphics)
		start()
	else:
		show_lobby()


func start() -> void:
	if args["connect"] != "":
		_join()
		return
	var map_error := PlayableMaps.error(int(args["map"]))
	if map_error != "":
		show_lobby(map_error)
		return
	var features = null
	if args["players"] or args["layer"]:
		var plan := Layers.plan_match(maxi(1, args["players"]), args["mode"] != "coop", args["layer"])
		print(plan.describe())
		if args["mode"] in ["solo", "coop", "versus"]:
			args["mode"] = plan.mode
		features = Layers.features_for(plan.layer)
		if plan.layer >= 5:
			features["hq"] = true
		features = features.keys()
	if args["police"]:  # offline task-force desk against AI runners
		var ps := Session.new({"mode": Roles.POLICE, "seed": args["seed"], "humans": {Roles.CONTROLLER: args["name"]},
			"map_seed": args["map"] if args["map"] >= 0 else MapCity.SEED})
		var desk := StationApp.new()
		add_child(desk)
		desk.setup(LocalLink.new(ps, Roles.CONTROLLER), Roles.CONTROLLER, ps.world)
		return
	var mode: String = args["mode"]
	var story: bool = args["unlocks"] == "story" and mode != Roles.CAMPAIGN and features == null
	var save := save_dir + ("campaign.json" if mode == Roles.CAMPAIGN else ("story.json" if story else "save.json"))
	if not args["new"]:
		var save_error := PlayableMaps.error(int(args["map"]), Session.read_save(save))
		if save_error != "":
			show_lobby(save_error)
			return
	if args["new"] and FileAccess.file_exists(save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save))
	var opts := {"seed": args["seed"], "mode": mode, "ai_law_upgrades": true, "ground_war": true, "chronicle": true, "agency": true, "family": true, "island": true, "court": true, "payroll": true, "trade": true, "logistics": true, "renown": true, "rackets": true, "races": true, "airframe": true, "casino": true, "dealership": true, "psychedelics": true, "fog": true}  # the AI chief shops as forfeiture comes in
	if story:  # the chapters build the rest as they open (Story.CHAPTERS)
		for k in Session.SYSTEMS:
			opts.erase(k)
		opts["career"] = true
	elif mode != Roles.CAMPAIGN and features == null:
		opts["money"] = Session.OPEN_FLOAT  # open mode: everything live at once, so a float (a new game only)
	if args["map"] >= 0:  # positive seeds select generated maps; zero is rejected above
		opts["map_seed"] = args["map"]
	elif not FileAccess.file_exists(save):
		opts["map_seed"] = MapCity.SEED  # a new game starts on the city coast; old saves keep their island
	if features != null:
		opts["features"] = features
	var fresh := not FileAccess.file_exists(save)
	var sess := Session.load_or_new(save, opts)
	if fresh and opts.has("money"):
		sess.say("Benny Ruiz fronts the start-up money: $%s. Everything's open from the first minute - spend it well." % Py.money(int(opts.money)))
	if args["weather"] != "":  # --weather clear|cloud|storm[,moon 0..1]; the HQ season sets its own each night
		var wp: PackedStringArray = str(args["weather"]).split(",")
		sess.set_weather({"sky": wp[0], "moon": float(wp[1]) if wp.size() > 1 else 0.5})
	if mode == Roles.CAMPAIGN:
		Campaign.from_dict(Session.read_save(save).get("campaign")).attach(sess)
	elif story:
		var st := Story.from_dict(Session.read_save(save).get("story"))
		st.attach(sess)
		while st.index + 1 < args["chapter"] and not st.completed_all:  # --chapter N: skip ahead
			st.advance()
	# the tutorial: asked for, or still on in this save
	var tut = Session.read_save(save).get("tutorial")
	if args["tutorial"] or (tut is Dictionary and bool(tut.get("on", false)) and not args["new"]):
		Tutorial.new(tut if not args["new"] else null).attach(sess)
		if args["tutorial"]:
			sess.tutorial.enabled = true
	var server = null
	var host_seat := Roles.PILOT
	if args["host_room"] != null:  # the waiting room: its server is already listening, and its players have chosen their seats
		server = args["host_room"]
		args["host_room"] = null
		host_seat = server.room.host_role() if server.room != null else Roles.PILOT
		server.begin(sess)
		sess.say("Hosting on port %d: your friends are seated; the AI plays every seat nobody took." % server.port)
	elif args["host"] or mode in [Roles.COOP, Roles.VERSUS]:
		server = HostServer.new()
		server.password = str(args["password"])
		server.host_name = str(args["name"])
		add_child(server)
		var err = server.start(args["port"], mode if mode != Roles.SOLO else Roles.COOP)
		if err:
			sess.say(err)
			server = null
		else:
			sess.say("Hosting on port %d: friends join with --connect YOUR_IP:%d (--role pick to choose a seat; the AI plays every seat nobody takes)" % [server.port, server.port])
	var bot = null
	if args["watch"]:
		bot = AutoRunner.new(sess)
		sess.say("Watching the AI fly. [C] cycles cameras.")
	if host_seat != Roles.PILOT and server != null:  # the host took a desk in the waiting room: a 2D station, the aircraft flown by the AI
		var desk := HostDesk.new()
		add_child(desk)
		desk.setup(sess, server, host_seat)
		_host_extras(server)
		return
	var app := PilotApp.new()
	add_child(app)
	app.setup(sess, args["graphics"], bot, server)
	app.leave.connect(_leave)
	_host_extras(server)
	if args["hour"] >= 0:
		app.scene.set_hour(args["hour"])
	if args["shot"] != "":
		_shoot(app)
	elif args["smoke"] > 0:
		_smoke(sess)


## Remote seat: a 3D view for the police pilot (and the co-pilot with --seat3d),
## the 2D station for everyone else.
func _join() -> void:
	var a: String = args["connect"]
	var at := a.find("@")  # password@host:port
	if at > 0:
		args["password"] = a.substr(0, at)
		a = a.substr(at + 1)
	var i := a.rfind(":")
	var host := a.substr(0, i) if i > 0 else "127.0.0.1"
	var port := int(a.substr(i + 1)) if i >= 0 else HostServer.DEFAULT_PORT
	var link := NetClient.new()
	add_child(link)
	var role: String = args["role"] if args["role"] != "pick" else ""
	link.password = str(args["password"])
	link.open(host, port, args["name"], role)
	# the waiting room if the host is still in it; if the game is already running, the old way (a seat by name, or the picker)
	var room := RoomScreen.new()
	add_child(room)
	room.setup(null, link)
	room.started.connect(func(r):
		room.queue_free()
		_enter_game(link, r), CONNECT_ONE_SHOT)
	room.game_running.connect(func():
		room.queue_free()
		_enter_game(link, link.role), CONNECT_ONE_SHOT)
	room.cancelled.connect(func():
		room.queue_free()
		link.queue_free()
		show_lobby())


## Into the game as `role` ("" = no seat yet: pick one from the live list).
func _enter_game(link: NetClient, role: String) -> void:
	if role != "":
		_seat(link, role)
		return
	var picker := SeatPicker.new()
	add_child(picker)
	picker.setup(link)
	picker.seated.connect(func(r):
		picker.queue_free()
		_seat(link, r), CONNECT_ONE_SHOT)
	picker.cancelled.connect(func(): _leave("lobby"), CONNECT_ONE_SHOT)


func _seat(link: NetClient, role: String) -> void:
	_client_voice(link)
	if role in [Roles.INTERCEPTOR, Roles.PILOT] or (role == Roles.COPILOT and args["seat3d"]):
		var seat := RemoteSeat.new()
		add_child(seat)
		seat.setup(link, role, args["graphics"])
	else:
		var st := StationApp.new()
		add_child(st)
		st.setup(link, role)

func _client_voice(link: NetClient) -> VoiceChat:
	for child in get_children():
		if child is VoiceChat and child.link == link and not child.is_queued_for_deletion():
			return child
	var voice := VoiceChat.new().attach_client(link)
	add_child(voice)
	return voice


## Run a new game for a while and quit (the release smoke test in CI): the
## output is checked for SCRIPT ERROR, and the game has to reach the end.
func _smoke(sess: Session) -> void:
	for f in args["smoke"]:
		await get_tree().process_frame
	print("SMOKE OK %s t=%.1fs phase=%s money=%s" % [Beta.version(), sess.time, sess.phase, sess.money])
	get_tree().quit()


## Render a few frames and save a screenshot (docs, CI smoke tests).
func _shoot(app: PilotApp) -> void:
	for f in args["frames"]:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path: String = args["shot"]
	img.save_png(path if path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path))
	print("saved ", path)
	get_tree().quit()
