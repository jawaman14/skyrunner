class_name DedicatedServer
extends RefCounted
## A dedicated Skyrunner server: no window, no pilot's 3D seat, nobody's machine as the host. The simulation runs here (on a
## cloud VM, a home server, a Raspberry Pi) and players connect with the game as remote seats: the boss's, the lieutenant's, the
## fixer's, the controller's desks and so on, or the pilot's seat flown from their own machine. Every seat nobody holds is the AI's,
## and the aircraft is flown by the AI (AutoRunner) until a player takes the pilot's seat.
##
## What a server adds to the listen server of a hosting game:
##   * it starts with no one at all, and keeps going: a game with nobody connected is the AI playing itself
##   * it saves (every AUTOSAVE_S and when the last player leaves) and picks up the save on the next start
##   * `--password` (a hello without it is refused), `--max-players`, a status probe for health checks ({"t":"status"})
##   * a log line for every join, leave and refusal; a stop file for a clean shutdown
##   * every option is a flag or an environment variable (SKYRUNNER_*), for a service file or a container
##
## Run it:  godot --headless --path . --script res://scripts/net/dedicated.gd -- --port 47800 --mode coop --unlocks open
## See docs/SERVER.md (Google Cloud, Docker, systemd).

const DT := 1.0 / 30.0
const AUTOSAVE_S := 120.0
const DEFAULTS := {
	"port": 47800, "bind": "*", "seed": 1, "mode": "coop", "unlocks": "open", "name": "Skyrunner server", "password": "", "max_players": 16,
	"save": "user://dedicated.json", "autosave": AUTOSAVE_S, "autopilot": true, "lan": false, "seconds": -1.0, "stop_file": "", "map": -1, "quiet": false,
}
const MODES := ["coop", "versus", "police"]

var cfg := {}
var sess: Session = null
var srv: HostServer = null
var bot: AutoRunner = null
var t := 0.0  ## server seconds
var lines: Array = []  ## the log, newest last (tests read it; the script prints it)
var print_log := true
var _acc := 0.0
var _save_t := 0.0
var _stop_t := 0.0
var _had_players := false
var _stopping := false


## The options from the command line (`--port 47800`, `--autopilot false`, `--lan`) over the environment (SKYRUNNER_PORT, ...)
## over the defaults. Returns {cfg, error}.
static func parse(args: Array, env := {}) -> Dictionary:
	var c: Dictionary = DEFAULTS.duplicate()
	var err := ""
	for k in DEFAULTS:
		var e := "SKYRUNNER_" + str(k).to_upper()
		if env.has(e) and str(env[e]) != "":
			c[k] = _coerce(DEFAULTS[k], str(env[e]))
	var i := 0
	while i < args.size():
		var k: String = str(args[i]).trim_prefix("--").replace("-", "_")
		if not DEFAULTS.has(k):
			err = "unknown option %s" % args[i]
			i += 1
			continue
		if DEFAULTS[k] is bool:
			if i + 1 < args.size() and str(args[i + 1]) in ["true", "false", "1", "0", "yes", "no", "on", "off"]:
				c[k] = _coerce(true, str(args[i + 1]))
				i += 1
			else:
				c[k] = true
		elif i + 1 < args.size():
			c[k] = _coerce(DEFAULTS[k], str(args[i + 1]))
			i += 1
		else:
			err = "%s needs a value" % args[i]
		i += 1
	if not str(c.mode) in MODES:
		err = "mode must be one of %s" % [", ".join(MODES)]
	if not str(c.unlocks) in ["open", "story"]:
		err = "unlocks must be open or story"
	c["port"] = int(c.port)
	if int(c.port) < 0 or int(c.port) > 65535:
		err = "port out of range"
	if int(c.map) == 0:
		err = PlayableMaps.CLASSIC_REMOVED
	c["max_players"] = clampi(int(c.max_players), 1, 64)
	return {"cfg": c, "error": err}


static func _coerce(like: Variant, v: String) -> Variant:
	if like is bool:
		return v.to_lower() in ["true", "1", "yes", "on"]
	if like is int:
		return int(v)
	if like is float:
		return float(v)
	return v


func _init(cfg_: Dictionary) -> void:
	cfg = DEFAULTS.duplicate()
	cfg.merge(cfg_, true)


## The options for a Session: the game the server runs (the open mode, or the story that a save carries on).
func session_options() -> Dictionary:
	var c := cfg
	if str(c.mode) == "police":  # a task-force desk for remote players against AI runners
		var po := {"mode": Roles.POLICE, "seed": int(c.seed), "map_seed": int(c.map) if int(c.map) >= 0 else MapCity.SEED, "ground_war": true, "chronicle": true,
			"agency": true, "family": true, "island": true, "court": true, "payroll": true, "trade": true, "logistics": true, "renown": true, "rackets": true,
			"races": true, "airframe": true, "casino": true, "dealership": true, "psychedelics": true, "career": true, "fog": true, "money": Session.OPEN_FLOAT}
		return po
	var o := {"seed": int(c.seed), "mode": str(c.mode), "ai_law_upgrades": true, "ground_war": true, "chronicle": true, "agency": true, "family": true,
		"island": true, "court": true, "payroll": true, "trade": true, "logistics": true, "renown": true, "rackets": true, "races": true, "airframe": true,
		"casino": true, "dealership": true, "psychedelics": true, "fog": true}
	if str(c.unlocks) == "story":
		for k in Session.SYSTEMS:
			o.erase(k)
		o["career"] = true
	else:
		o["money"] = Session.OPEN_FLOAT
	o["map_seed"] = int(c.map) if int(c.map) >= 0 else MapCity.SEED
	return o


## Build the game (loading the save if there is one), listen, and be ready to step. Returns "" or why not.
func start() -> String:
	var save := str(cfg.save)
	var map_error := PlayableMaps.error(int(cfg.map), Session.read_save(save))
	if map_error != "":
		return map_error
	var opts := session_options()
	if int(cfg.map) < 0 and FileAccess.file_exists(save):
		opts.erase("map_seed")
	opts["save_path"] = save
	var fresh := not FileAccess.file_exists(save)
	sess = Session.load_or_new(save, opts)
	if str(cfg.unlocks) == "story" and str(cfg.mode) != "police":
		var st := Story.from_dict(Session.read_save(save).get("story"))
		st.attach(sess)
	for role in sess.seats.seats.keys():  # a session starts with its pilot's seat the local player's: nobody is local on a server
		if sess.seats.who(role) == "human" and str(sess.seats.seats[role].token) == "":
			sess.seats.release(role)
	srv = HostServer.new()
	srv.attach(sess)
	srv.dedicated = true
	srv.password = str(cfg.password)
	srv.max_players = int(cfg.max_players)
	srv.host_name = str(cfg.name)
	srv.log_fn = Callable(self, "note")
	var err = srv.start(int(cfg.port), str(cfg.mode), str(cfg.bind), int(cfg.seed))
	if err:
		return str(err)
	note("%s listening on port %d: %s, %s, seed %d%s (%s)" % [cfg.name, srv.port, cfg.mode, cfg.unlocks, int(cfg.seed), ", password set" if str(cfg.password) != "" else ", no password",
		"new game" if fresh else "loaded %s" % save])
	return ""


func note(text: String) -> void:
	var stamp := Time.get_time_string_from_system()
	var line := "[%s] %s" % [stamp, text]
	lines.append(line)
	Py.keep_last(lines, 200)
	if print_log and not bool(cfg.quiet):
		print(line)


## One step of the server: the network, the AI pilot, the session, the snapshots, the saves. Call with the frame's delta.
## Returns true when the server is done (the time limit, or a stop file).
func step(delta: float) -> bool:
	_acc += delta
	var n := 0
	while _acc >= DT and n < 5:
		_acc -= DT
		n += 1
		srv.pump(sess)
		_pilot_seat()
		var remote: bool = sess.seats.human(Roles.PILOT) and sess.seats.seats[Roles.PILOT].token != ""
		var bc = bot.step(DT) if bot != null else (sess.remote_controls() if remote else null)
		sess.update(DT, null, bc)
		t += DT
	if n == 5:
		_acc = 0.0  # a slow machine drops time rather than spiralling
	srv.publish(sess)
	_autosave(delta)
	if str(cfg.stop_file) != "":
		_stop_t += delta
		if _stop_t >= 1.0:
			_stop_t = 0.0
			if FileAccess.file_exists(str(cfg.stop_file)):
				note("stop file found: shutting down")
				DirAccess.remove_absolute(ProjectSettings.globalize_path(str(cfg.stop_file)))
				return true
	return float(cfg.seconds) > 0.0 and t >= float(cfg.seconds)


## The AI flies whenever nobody holds the pilot's seat; a player who takes it flies from their own machine.
func _pilot_seat() -> void:
	if str(cfg.mode) == "police" or not bool(cfg.autopilot):
		return
	var who := sess.seats.who(Roles.PILOT)
	if who == "ai" and bot == null:
		bot = AutoRunner.new(sess)
	elif who != "ai" and bot != null:
		bot = null


func players() -> int:
	return srv.conns.filter(func(c): return c.joined).size()


func _autosave(delta: float) -> void:
	_save_t += delta
	var n := players()
	var last_left := _had_players and n == 0
	_had_players = n > 0
	if last_left or (float(cfg.autosave) > 0.0 and _save_t >= float(cfg.autosave)):
		save()


func save() -> void:
	_save_t = 0.0
	sess.save()
	note("saved (game time %d min)" % int(sess.time / 60.0))


## A clean stop: save, hang up, stop listening.
func shutdown() -> void:
	if _stopping:
		return
	_stopping = true
	if sess != null:
		sess.save()
		note("saved; shutting down")
	if srv != null:
		srv.stop()
