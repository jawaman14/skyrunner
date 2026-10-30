extends TestCase
## The map audit (docs/MAP_REDESIGN.md section 4), L1: the strips as authored data in data/maps/costa_brava/strips.json.


func after_each() -> void:
	Terrain.natural = false
	World.use_map(0)


## What the game places: main.gd turns the natural terrain on before the map is generated, and MapCity then reads strips.json.
func _game_strips() -> Array:
	Terrain.natural = true
	var l := MapCity.generate()
	Terrain.natural = false
	return l.airfields


## What the relief search places on the natural terrain: the file was its snapshot, until the new L1 moves a strip.
func _searched_strips() -> Array:
	Terrain.natural = true
	var placed := MapCity._searched_strips()
	Terrain.natural = false
	return placed


func test_the_strips_file_loads_and_its_gate_is_clean() -> void:
	var strips := MapAudit.load_strips()
	check_eq(strips.size(), 9, "nine strips on the map")
	# The baseline: today's map has one finding, Cayo Largo's approach out over the sea past the east edge. The new map's L1 must
	# clear it; until then the gate's output is pinned so a new finding cannot slip in.
	check_eq(MapAudit.strips_gate(strips, World.HALF), ["ISL: its protected approach volume leaves the map (the terrain pass could not keep it clear)"],
		"the strips' gate: only the known ISL finding")


func test_the_strips_file_matches_what_the_game_generates() -> void:
	check_eq(MapAudit.drift(MapAudit.load_strips(), _game_strips()), [], "MapCity builds every field of strips.json on the game's terrain")
	check_eq(MapAudit.drift(MapAudit.load_strips(), _searched_strips()), [], "the file is still the search's snapshot (drop when L1 moves a strip)")
	var moved := MapAudit.load_strips()
	moved[0] = (moved[0] as Dictionary).duplicate()
	moved[0].radar_km = 1.0
	moved[0].elev = null
	var found := MapAudit.drift(moved, _game_strips())
	check(found.any(func(f): return "radar_km" in f) and found.any(func(f): return "elev" in f), "radar range and elevation are compared, null is not a number")


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
	check_eq(MapAudit.strips_gate([], World.HALF).size(), 1, "an empty or unreadable file fails")
	var partial := good.duplicate()
	partial.erase("kind")
	partial.erase("heading")
	check(MapAudit.strips_gate([partial, good], World.HALF).any(func(f): return "missing kind" in f), "a missing field is a finding, not a crash")
	var odd := good.duplicate()
	odd.kind = "seaplane"
	check(MapAudit.strips_gate([odd], World.HALF).any(func(f): return "unknown kind" in f), "an unknown kind")


func test_the_classic_terrain_keeps_the_search() -> void:
	var l := MapCity.generate()
	check_eq(MapAudit.drift(MapAudit.load_strips(), l.airfields).is_empty(), false, "the tests' classic terrain sites its own strips (the goldens)")
	check_eq(l.airfields.size(), 9, "all nine strips")
