extends TestCase
## tools/playtest.gd: a headless playtest digest. The same seed and the same steps give the same digest (so a change can be
## compared with a run from before it), and the digest has what a tester looks at.

const TOOL := "res://tools/playtest.gd"


func _play(seed_: int, seconds: float, bot: bool) -> Dictionary:
	var opts: Dictionary = GameSetup.options(Roles.SOLO, seed_, true)
	opts["map_seed"] = MapCity.SEED
	opts["location"] = "HAR"
	var s := Session.new(opts)
	var st := Story.new_employed()
	st.attach(s)
	var runner: AutoRunner = AutoRunner.new(s) if bot else null
	var dt := 1.0 / 30.0
	while s.time < seconds:
		if runner != null:
			s.update(dt, null, runner.step(dt))
		else:
			s.update(dt)
	var tool_script: GDScript = load(TOOL)
	var d: Dictionary = tool_script.digest(s, runner)
	s.dispose()
	return d


func test_the_same_seed_gives_the_same_digest() -> void:
	var a := _play(11, 90.0, true)
	var b := _play(11, 90.0, true)
	check_eq(JSON.stringify(a), JSON.stringify(b), "two runs of seed 11 agree")


func test_the_digest_has_what_a_tester_looks_at() -> void:
	var d := _play(11, 30.0, true)
	for key in ["time_s", "phase", "location", "parked", "money", "jobs_aboard", "wanted", "suspicion", "messages", "chapter", "chapter_title", "flights"]:
		check(d.has(key), "the digest has %s" % key)
	check(d.time_s >= 30.0, "it ran the 30 simulated seconds (%.1f)" % float(d.time_s))
	check(d.messages is Array and d.messages.size() <= 6, "the last few messages, at most six")
	var idle := _play(11, 30.0, false)
	check(not idle.has("flights"), "without the bot there is no flight count")
