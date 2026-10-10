extends TestCase
## The switch registry (scripts/sim/switches.gd) names every static on/off switch, and the parity set
## really turns the Godot-only rules off and back on. Plus a scan that keeps the sim deterministic:
## no global random draws, no clock reads, no unseeded generators in scripts/sim or scripts/bots.

const SWITCH_DIRS := ["res://scripts/sim", "res://scripts/render"]
const SIM_DIRS := ["res://scripts/sim", "res://scripts/bots"]
var _original: Dictionary = {}

## Lines that are allowed to break the determinism rules, with the reason.
const ALLOWED := {
	"rng_.seed(randi())": "HQ.Season with no generator handed in (a hand-made one, never a replay): the caller seeds it in every seeded path",
}


func before_each() -> void:
	_original = Switches.snapshot()

func after_each() -> void:
	Switches.restore(_original)


func _files(dirs: Array) -> Array:
	var out := []
	for d in dirs:
		var stack := [d]
		while not stack.is_empty():
			var cur: String = stack.pop_back()
			for f in DirAccess.get_files_at(cur):
				if f.ends_with(".gd"):
					out.append(cur + "/" + f)
			for sub in DirAccess.get_directories_at(cur):
				stack.append(cur + "/" + sub)
	return out


func test_every_switch_in_the_sim_is_registered() -> void:
	var known: Array = Switches.PARITY + Switches.OPT_IN
	var re := RegEx.create_from_string("(?m)^static var ([A-Z][A-Z_]*) := (?:true|false)")
	var found := 0
	for p in _files(SWITCH_DIRS):
		if p.ends_with("switches.gd"):
			continue
		var text := FileAccess.get_file_as_string(p)
		var m := re.search(text)
		if m == null:
			continue
		var cn := RegEx.create_from_string("(?m)^class_name (\\w+)").search(text)
		check(cn != null, "%s has a switch but no class_name" % p)
		if cn == null:
			continue
		for mm in re.search_all(text):
			found += 1
			var id: String = "%s.%s" % [cn.get_string(1), mm.get_string(1)]
			check(known.has(id), "%s is a static switch that is in neither Switches.PARITY nor Switches.OPT_IN" % id)
	check(found >= 20, "the scan found the switches (%d)" % found)
	for id in known:
		check(known.count(id) == 1, "%s is listed once" % id)


func test_the_parity_set_flips_and_restores() -> void:
	Switches.parity_off()
	check(not SensorNet.REALISM and not Economy.REALISM and not Arsenal.REALISM, "the realism rules are off")
	check(not GroundWar.ENABLED and not Chronicle.ENABLED and not Agency.ENABLED, "the ground war, chronicle and agency are off")
	check(not Agent.ENABLED and not Fuel.ENABLED, "agents and fuel are off")
	Switches.parity_on()
	check(SensorNet.REALISM and Economy.REALISM and Arsenal.REALISM, "and back on")
	check(GroundWar.ENABLED and Chronicle.ENABLED and Agency.ENABLED and Agent.ENABLED and Fuel.ENABLED, "all of them")
	check_eq(Switches.PARITY.size(), 8, "eight switches in the parity set")

func test_scoped_parity_restores_mixed_states_and_nested_overrides() -> void:
	Switches.parity_on()
	Fuel.ENABLED = false
	Agency.ENABLED = false
	var mixed := Switches.snapshot()
	check_eq(mixed.size(), Switches.PARITY.size())
	for key in Switches.PARITY: check(mixed.has(key), "snapshot covers " + key)
	var outer := Switches.parity_off()
	var inner := Switches.parity_off()
	Switches.restore(inner)
	check_eq(Switches.snapshot(), inner, "inner restoration preserves outer override")
	Switches.restore(outer)
	check_eq(Switches.snapshot(), mixed, "pre-existing disabled features stay disabled")


func _bad_re() -> RegEx:
	return RegEx.create_from_string("(?<![.\\w])(randf|randi|randf_range|randi_range|randomize|rand_from_seed)\\(|pick_random\\(|\\.shuffle\\(\\)|Time\\.get_(ticks|unix|datetime)|OS\\.get_(unix|ticks)")


func test_the_scan_itself_catches_what_it_should() -> void:
	var bad := _bad_re()
	for line in ["var x := randf()", "var y := randi_range(1, 3)", "arr.shuffle()", "var t := Time.get_ticks_msec()", "x = arr.pick_random()", "randomize()"]:
		check(bad.search(line) != null, "caught: " + line)
	for line in ["var x := rng.randf()", "var y := rng.randi_range(1, 3)", "var z := my_randf(2)", "var s := \"shuffled\""]:
		check(bad.search(line) == null, "let through: " + line)

func _seeded_generator(lines: PackedStringArray, at: int) -> bool:
	var assignment := RegEx.create_from_string("(?:var\\s+)?([A-Za-z_]\\w*)\\s*(?::\\s*RandomNumberGenerator\\s*)?(?::=|=)\\s*RandomNumberGenerator\\.new\\(\\)").search(lines[at].split("#")[0])
	if assignment == null: return false
	var seeded := RegEx.create_from_string("\\b" + assignment.get_string(1) + "\\.seed\\s*=")
	for i in range(at, mini(at + 4, lines.size())):
		if seeded.search(lines[i].split("#")[0]) != null: return true
	return false

func test_generator_scan_requires_the_created_generator_to_be_seeded() -> void:
	check(_seeded_generator(PackedStringArray(["var rng := RandomNumberGenerator.new()", "rng.seed = 12"]), 0))
	check(_seeded_generator(PackedStringArray(["var rng: RandomNumberGenerator = RandomNumberGenerator.new()", "rng.seed = seed"]), 0))
	check(not _seeded_generator(PackedStringArray(["var rng := RandomNumberGenerator.new()"]), 0), "unseeded constructor is caught")
	check(not _seeded_generator(PackedStringArray(["var rng := RandomNumberGenerator.new()", "other.seed = 12"]), 0), "another generator's seed cannot mask the error")
	check(not _seeded_generator(PackedStringArray(["var rng := RandomNumberGenerator.new()", "# rng.seed = 12"]), 0), "commented seed is not initialization")


func test_the_sim_draws_no_global_randomness_and_reads_no_clock() -> void:
	var bad := _bad_re()
	var gen := RegEx.create_from_string("RandomNumberGenerator\\.new\\(\\)")
	var scanned := 0
	for p in _files(SIM_DIRS):
		var lines := FileAccess.get_file_as_string(p).split("\n")
		scanned += 1
		for i in lines.size():
			var line := lines[i].strip_edges()
			if line.begins_with("#") or line.begins_with("##"):
				continue
			var code := line.split(" #")[0]
			if bad.search(code) != null:
				var ok := false
				for k in ALLOWED:
					if code.contains(k):
						ok = true
				check(ok, "%s:%d draws global randomness or reads the clock: %s" % [p, i + 1, line])
			if gen.search(code) != null:  # an own generator is fine if it is seeded straight away
				check(_seeded_generator(lines, i), "%s:%d makes a RandomNumberGenerator without seeding it; assign that generator's .seed immediately" % [p, i + 1])
	check(scanned > 50, "the scan covered the sim and the bots (%d files)" % scanned)
