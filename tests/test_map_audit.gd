extends TestCase
## The map audit (docs/MAP_REDESIGN.md section 4), L1: the strips as authored data in data/maps/costa_brava/strips.json.


func after_each() -> void:
	Terrain.natural = false
	World.use_map(0)


## What the game places: main.gd turns the natural terrain on before the map is generated, and the strip search reads the relief,
## so the classic terrain (the tests' default) puts several strips elsewhere. The data records the game's map.
func _game_strips() -> Array:
	Terrain.natural = true
	var l := MapCity.generate()
	Terrain.natural = false
	return l.airfields


func test_the_strips_file_loads_and_its_gate_is_clean() -> void:
	var strips := MapAudit.load_strips()
	check_eq(strips.size(), 9, "nine strips on the map")
	check_eq(MapAudit.strips_gate(strips, World.HALF), [], "the strips pass their own gate")


func test_the_strips_file_matches_what_the_game_generates() -> void:
	check_eq(MapAudit.drift(MapAudit.load_strips(), _game_strips()), [], "strips.json is the game's map (until MapCity reads it)")


func test_the_gate_names_each_rule_it_enforces() -> void:
	var good := {"code": "AAA", "name": "A", "x": 0.0, "y": 0.0, "heading": 90.0, "length": 600.0, "width": 20.0, "surface": "grass", "kind": "bush", "setting": "flat"}
	check_eq(MapAudit.strips_gate([good], World.HALF), [], "a sound strip")
	var short := good.duplicate()
	short.length = 200.0
	check(MapAudit.strips_gate([short], World.HALF).any(func(f): return "floor" in f), "too short for its kind")
	var edge := good.duplicate()
	edge.x = World.HALF - 100.0
	check(MapAudit.strips_gate([edge], World.HALF).any(func(f): return "edge" in f), "too near the map's edge")
	var twin := good.duplicate()
	twin.code = "BBB"
	twin.x = 800.0  # its runway starts inside AAA's approach volume
	check(MapAudit.strips_gate([good, twin], World.HALF).any(func(f): return "approach volume" in f), "a runway in another strip's volume")
	var pit := good.duplicate()
	pit.setting = "pit"
	pit.haul_road = null
	check(MapAudit.strips_gate([pit], World.HALF).any(func(f): return "haul road" in f), "a pit strip needs its haul road")
	var odd := good.duplicate()
	odd.kind = "seaplane"
	check(MapAudit.strips_gate([odd], World.HALF).any(func(f): return "unknown kind" in f), "an unknown kind")
