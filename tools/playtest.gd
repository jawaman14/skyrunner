extends SceneTree
## A repeatable playtest without a window: the simulation (the same options the game builds, the employed story by
## default) steps for N simulated seconds, with the AI pilot (AutoRunner) flying unless told not to, and prints a state
## digest, optionally every T seconds. Same seed and arguments give the same digest, so a change can be compared with
## a run from before it. It is the headless half of the playtest protocol (#172); the picture half is skyrunner_screenshot.
##
##   godot --headless --path . --script res://tools/playtest.gd -- [--seed N] [--seconds S] [--every T] [--open]
##       [--no-bot] [--chapter N] [--location CODE] [--out PATH]
##
## Prints one line, `PLAYTEST_JSON {...}`, and writes the same JSON to --out when given. Through the MCP:
## skyrunner_run_tool(script="playtest.gd", args=[...], queue=true).

const DT := 1.0 / 30.0

var _args := {"seed": 1, "seconds": 600.0, "every": 0.0, "open": false, "bot": true, "chapter": 0, "location": "HAR", "out": ""}


func _initialize() -> void:
	call_deferred("_run")


func _parse() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		match a[i]:
			"--seed":
				i += 1
				_args.seed = int(a[i])
			"--seconds":
				i += 1
				_args.seconds = float(a[i])
			"--every":
				i += 1
				_args.every = float(a[i])
			"--chapter":
				i += 1
				_args.chapter = int(a[i])
			"--location":
				i += 1
				_args.location = a[i]
			"--out":
				i += 1
				_args.out = a[i]
			"--open":
				_args.open = true
			"--no-bot":
				_args.bot = false
		i += 1


func _run() -> void:
	_parse()
	var story: bool = not _args.open
	var opts: Dictionary = GameSetup.options(Roles.SOLO, int(_args.seed), story)
	opts["map_seed"] = MapCity.SEED
	opts["location"] = _args.location
	var s := Session.new(opts)
	if story:
		var st := Story.new_employed()
		st.attach(s)
		st.select_chapter(int(_args.chapter))
	var runner: AutoRunner = AutoRunner.new(s) if _args.bot else null
	var samples := []
	var next_sample: float = float(_args.every) if float(_args.every) > 0.0 else INF
	while s.time < float(_args.seconds):
		if runner != null:
			s.update(DT, null, runner.step(DT))
		else:
			s.update(DT)
		if s.time >= next_sample:
			samples.append(digest(s, runner))
			next_sample += float(_args.every)
	var result := {"args": _args, "final": digest(s, runner), "samples": samples}
	var line := JSON.stringify(result)
	print("PLAYTEST_JSON ", line)
	if _args.out != "":
		var f := FileAccess.open(str(_args.out), FileAccess.WRITE)
		if f != null:
			f.store_string(line)
	s.dispose()
	quit()


## What a tester would want to see at a glance, in numbers that do not depend on the run's wall-clock speed.
static func digest(s: Session, runner: AutoRunner) -> Dictionary:
	var d := {
		"time_s": snappedf(s.time, 0.1),
		"phase": s.phase,
		"location": s.location,
		"parked": s.parked,
		"money": s.money,
		"jobs_aboard": s.active_jobs.size(),
		"wanted": s.police.wanted if s.police != null else 0,
		"suspicion": snappedf(s.police.suspicion, 0.1) if s.police != null else 0.0,
		"messages": s.messages.slice(maxi(0, s.messages.size() - 6)).map(func(m): return str(m[1])),
	}
	if s.story != null:
		d["chapter"] = int(s.story.chapter.num)
		d["chapter_title"] = str(s.story.chapter.title)
	if s.state != null:
		d["x"] = snappedf(s.state.x, 1.0)
		d["y"] = snappedf(s.state.y, 1.0)
		d["agl_m"] = snappedf(s.state.agl, 1.0)
		d["alt_m"] = snappedf(s.state.alt, 1.0)
		d["ias_kts"] = snappedf(s.state.ias_kts, 0.1)
		d["gs_kts"] = snappedf(s.state.gs_kts, 0.1)
		d["fuel_lb"] = snappedf(s.state.fuel_lb, 0.1)
		d["on_ground"] = s.state.on_ground
	if runner != null:
		d["flights"] = runner.flights
	return d
