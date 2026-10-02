extends TestCase
## The strips a player lands on: wide enough for the aircraft that use them, marked so they can be seen,
## and forgiving about the ground beside them (tools/strip_audit.gd checks the rest, docs/STRIPS.md).


func after_each() -> void:
	World.use_map(0)  # the suite's default island, for whatever runs next


func test_no_strip_is_narrower_than_a_wing_and_a_half() -> void:
	World.use_map(MapCity.SEED)
	var smallest := 1e9
	for k in Aircraft.ROSTER:
		smallest = minf(smallest, Aircraft.ROSTER[k].visual.span_m)
	for af in World.AIRFIELDS:
		check(af.width >= smallest * 1.5, "%s is %.0f m wide; the smallest aircraft's wing is %.1f m" % [af.code, af.width, smallest])


func test_every_surface_has_runway_and_shoulder_colours() -> void:
	for surface in ["asphalt", "gravel", "grass", "dirt", "sand"]:
		check(Models.SURFACE_COLORS.has(surface) and Models.SHOULDER_COLORS.has(surface), surface)
	for af in World.AIRFIELDS:
		check(Models.SHOULDER_COLORS.has(af.surface), "%s: %s" % [af.code, af.surface])


func test_runway_designators_read_from_the_approach() -> void:
	check_eq(Models.designator(80.0), "08", "80 deg")
	check_eq(Models.designator(260.0), "26", "the other end")
	check_eq(Models.designator(0.0), "36", "north is 36")
	check_eq(Models.designator(354.0), "35", "rounds to the nearest ten")
	check_eq(Models.designator(3.0), "36", "and wraps")


func test_airfield_model_marks_both_ends_with_numbers() -> void:
	World.use_map(MapCity.SEED)
	var w := World.new()
	var af := World.airfield("FRM")
	var node := Models.build_airfield(w, af, Quality.get_preset("low"))
	var labels := node.get_children().filter(func(c): return c is Label3D)
	check_eq(labels.size(), 2, "a number at each end")
	var texts := labels.map(func(l): return l.text)
	check(texts.has(Models.designator(af.heading)) and texts.has(Models.designator(af.heading + 180.0)), "both designators: %s" % [texts])
	node.free()
