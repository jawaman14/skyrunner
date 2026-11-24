extends TestCase
## The map rebuild's authored layout (docs/MAP_REDESIGN.md step 1; the owner-approved sketch, D-106): the files parse, every
## strip in the brief is one of strips.json's, and the districts are one polygon set: a point on land is in exactly one (L4's gate,
## checked here on the authored data; the coast clips them in L4).

const DIR := "res://data/maps/costa_brava/"


func _json(name: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DIR + name))
	return d if d is Dictionary else {}


func _poly(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out


func test_the_files_and_the_strips() -> void:
	var brief := _json("brief.json")
	var strips := _json("strips.json")
	check(not brief.is_empty() and not _json("districts.json").is_empty() and not _json("roads_plan.json").is_empty(), "the layout files parse")
	check_eq(int(brief.size_m), 32000, "32 x 32 km (D-104)")
	var codes := {}
	for s in strips.strips:
		codes[str(s.code)] = true
	for b in brief.strips:
		check(codes.has(str(b.code)), "%s is one of strips.json's" % b.code)
		check(absf(float(b.at[0])) < 16000.0 and absf(float(b.at[1])) < 16000.0, "%s inside the map" % b.code)
	check_eq((brief.strips as Array).size(), codes.size(), "every strip in the brief")
	for st in brief.sites:
		for a in st.anchors:
			check(absf(float(a[0])) < 16000.0 and absf(float(a[1])) < 16000.0, "%s inside the map" % st.name)


func test_a_point_is_in_exactly_one_district() -> void:
	var ds: Array = _json("districts.json").districts
	check_eq(ds.size(), 13, "thirteen districts")
	World.use_map(MapCity.SEED)
	var world := World.new()
	var gaps := 0
	var overlaps := 0
	var land := 0
	for j in range(-15500, 15600, 500):
		for i in range(-15500, 15600, 500):
			var p := Vector2(i + 137, j + 211)  # off the 100 m lines the districts' edges run on (an edge point counts as in both)
			if world.ground(p.x, p.y) <= 0.5:
				continue  # the sea: the districts may run out over it (L4 clips them to the coast)
			land += 1
			var n := 0
			for d in ds:
				if Geometry2D.is_point_in_polygon(p, _poly(d.polygon)) and not (d.has("hole") and Geometry2D.is_point_in_polygon(p, _poly(d.hole))):
					n += 1
			if n == 0:
				gaps += 1
			elif n > 1:
				overlaps += 1
	check(land > 1000, "a coast to test (%d land points)" % land)
	check_eq(overlaps, 0, "no point on land in two districts")
	check_eq(gaps, 0, "no point on land in none")
	World.use_map(0)
