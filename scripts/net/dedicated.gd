extends SceneTree
## The dedicated server's entry point (see DedicatedServer and docs/SERVER.md):
##
##   godot --headless --path . --script res://scripts/net/dedicated.gd -- [options]
##
##   --port 47800        --bind "*"          --seed 1           --map -1 (the city coast)
##   --mode coop|versus|police               --unlocks open|story
##   --name "My server"  --password secret   --max-players 16
##   --save user://dedicated.json   --autosave 120 (seconds, 0 = off)   --stop-file /path (touch it for a clean stop)
##   --autopilot true    (the AI flies the aircraft until a player takes the pilot's seat)
##   --lan               (announce on the local network too; off in the cloud)
##   --seconds N         (stop after N server seconds: for tests)   --quiet
## Every option is also an environment variable: SKYRUNNER_PORT, SKYRUNNER_MODE, SKYRUNNER_PASSWORD, SKYRUNNER_MAX_PLAYERS, ...

var server: DedicatedServer
var announcer: LanDiscovery.Announcer = null


func _init() -> void:
	Terrain.natural = not OS.get_cmdline_user_args().has("--classic-terrain")
	var env := {}
	for k in DedicatedServer.DEFAULTS:
		var e := "SKYRUNNER_" + str(k).to_upper()
		if OS.has_environment(e):
			env[e] = OS.get_environment(e)
	var parsed := DedicatedServer.parse(OS.get_cmdline_user_args(), env)
	if str(parsed.error) != "":
		printerr("skyrunner server: " + str(parsed.error))
		quit(2)
		return
	server = DedicatedServer.new(parsed.cfg)
	var err := server.start()
	if err != "":
		printerr("skyrunner server: " + err)
		quit(1)
		return
	root.add_child(server.srv)  # the sockets are polled from the node's _process
	if bool(server.cfg.lan):
		announcer = LanDiscovery.Announcer.new()
		root.add_child(announcer)
		announcer.start(func(): return {"name": str(server.cfg.name), "port": server.srv.port, "mode": server.srv.mode, "players": server.players(), "locked": server.srv.locked})


func _process(delta: float) -> bool:
	if server == null:
		return true
	if server.step(delta):
		server.shutdown()
		return true
	return false


func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_CLOSE_REQUEST and server != null:
		server.shutdown()
