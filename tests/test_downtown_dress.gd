extends TestCase
## The downtown landmarks (DowntownDress, from the Quaternius Downtown City MegaKit): which towers they stand on, that the
## Kenney lots step aside for them, and that they are off when asked, on low quality and on the other maps.


func after_each() -> void:
	DowntownDress.ENABLED = true
	DowntownDress.marks = {}
	World.use_map(0)


func _boxes() -> Array:
	# Legacy renderer coverage uses explicit tower fixtures. Costa Brava's
	# rebuilt districts intentionally contain no generic skyscrapers.
	var out := []
	for i in 20:
		out.append({"x": MapCity.CITY_C.x + i * 65, "y": MapCity.CITY_C.y, "z": 4.0, "w": 45.0, "d": 45.0, "h": 40.0 + i, "style": "tower"})
	return out


func test_the_tallest_towers_nearest_the_centre_are_picked() -> void:
	var boxes := _boxes()
	var m := DowntownDress.pick(boxes)
	check(m.size() >= 6 and m.size() <= DowntownDress.MAX_LANDMARKS, "a handful of landmarks (%d)" % m.size())
	for i in m:
		var b: Dictionary = boxes[i]
		check(b.style == "tower" and float(b.w) >= DowntownDress.MIN_W and float(b.d) >= DowntownDress.MIN_D, "tower %d is a big enough tower" % i)
		check(Vector2(b.x, b.y).distance_to(MapCity.CITY_C) <= DowntownDress.NEAR_M, "and near the centre")
		check(DowntownDress.MODELS.has(m[i]), "with one of the kit's buildings: %s" % m[i])
	check_eq(DowntownDress.pick(boxes), m, "the same landmarks every time")


func test_the_kenney_lots_step_aside_for_a_landmark() -> void:
	var boxes := _boxes()
	var m := DowntownDress.pick(boxes)
	var i: int = m.keys()[0]
	check_eq(CityDress.lots(boxes[i], i).size(), 0, "no Kenney lots on a landmark's footprint")
	var other := 0
	while m.has(other) or boxes[other].style != "tower":
		other += 1
	check(CityDress.lots(boxes[other], other).size() > 0, "but the towers beside it keep theirs")


func test_the_landmarks_are_drawn_near_and_not_on_low_or_when_off() -> void:
	var boxes := _boxes()
	DowntownDress.pick(boxes)
	var n := DowntownDress.build(boxes, Quality.get_preset("high"))
	check_eq(n.get_child_count(), DowntownDress.marks.size(), "a node per landmark")
	n.free()
	var low := DowntownDress.build(boxes, Quality.get_preset("low"))
	check_eq(low.get_child_count(), 0, "none on low (the boxes stay)")
	low.free()
	DowntownDress.ENABLED = false
	check(DowntownDress.pick(boxes).is_empty(), "none when switched off")
	DowntownDress.ENABLED = true
	check(DowntownDress.pick(boxes).size() > 0, "and back when on")
