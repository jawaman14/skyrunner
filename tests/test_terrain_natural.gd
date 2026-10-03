extends TestCase
## The natural terrain pass (Terrain.natural): hills and mountains reworked into ridges, gullies and eroded slopes, with
## the coast, the lowlands and everything near a strip left exactly as the classic generator made it. (Both variants are
## baked into res://data/terrain, so this loads rather than generates.)

var _classic: PackedFloat32Array
var _natural: PackedFloat32Array
var _fe_classic := {}
var _fe_natural := {}


func after_each() -> void:
	Terrain.natural = false
	World.use_map(0)


func _load(map_seed: int) -> void:
	Terrain.natural = false
	World.use_map(map_seed)
	var a := World.new()
	_classic = a.terrain.get_heights()
	_fe_classic = a.terrain.get_field_elev().duplicate()
	Terrain.natural = true
	World.use_map(map_seed)
	var b := World.new()
	_natural = b.terrain.get_heights()
	_fe_natural = b.terrain.get_field_elev().duplicate()


func _check_map(map_seed: int, label: String, post_pass := false) -> void:
	_load(map_seed)
	check_eq(_natural.size(), _classic.size(), "%s: the same grid" % label)
	var cv := Terrain._cv()
	var changed := 0
	var bad := 0
	for k in _natural.size():
		if not is_finite(_natural[k]):
			bad += 1
		elif absf(_natural[k] - _classic[k]) > 0.5:
			changed += 1
	check_eq(bad, 0, "%s: every height is a number" % label)
	check(changed > 20000, "%s: the hills really are different (%d cells moved)" % [label, changed])
	for code in _fe_classic:
		check_near(float(_fe_natural[code]), float(_fe_classic[code]), 0.001, "%s: %s keeps its elevation" % [label, code])
	var kept := 0
	for af in World.AIRFIELDS:
		var moved := 0
		var seen := 0
		for r in Terrain.GRID:
			var dy: float = cv[r] - af.y
			if absf(dy) > 700.0 + af.length:
				continue
			for c in Terrain.GRID:
				var dx: float = cv[c] - af.x
				var lon: float = dx * af.ux + dy * af.uy
				var lat: float = dx * af.uy - dy * af.ux
				if absf(lon) > af.length / 2.0 + 300.0 or absf(lat) > af.width / 2.0 + 300.0:
					continue
				seen += 1
				if absf(_natural[r * Terrain.GRID + c] - _classic[r * Terrain.GRID + c]) > 0.001:
					moved += 1
		check_eq(moved, 0, "%s: %s's strip and the 300 m around it are untouched (%d cells)" % [label, af.code, seen])
		kept += seen
	check(kept > 100, "%s: the strips were checked" % label)
	var sea := 0
	for k in _natural.size():
		if _classic[k] < 25.0 and absf(_natural[k] - _classic[k]) > 0.001:
			sea += 1
	# (the city map has a post-pass of its own - rivers, flattened blocks - that reads the hills it sits among, so only the classic island is exact)
	check(sea == 0 or post_pass, "%s: the coast and the lowlands under 25 m are as they were (%d cells)" % [label, sea])
	var steep := 0
	var G := Terrain.GRID
	for r in range(1, G - 1):
		for c in range(1, G - 1):
			var k := r * G + c
			if _natural[k] > 40.0 and absf(_natural[k] - _natural[k + 1]) > Terrain.CELL * 1.6:
				steep += 1
	check(steep < 400, "%s: no cliffs steeper than rock stands (%d cells)" % [label, steep])


func test_the_classic_island() -> void:
	_check_map(0, "classic island")

# (The city coast is not checked here: its layout caches what MapCity.post computed from the first terrain it saw, so building it on
# both variants inside one process would leak the natural one into every later test. The game only ever uses one.)
