extends TestCase
## The chart lays its labels out together (place_labels): none overlaps another or a mark, the more important keep their spot,
## a crowded label moves below, above or to the mark's other side, and one with no free spot is left off. Round HAR five names
## (the strip, the boss's, the club's stash, the docks, a truck's destination) printed over one another until 12 November.

const CHART := Rect2(0, 0, 560, 560)


func _item(x: float, y: float, w := 80.0, h := 12.0, prio := 5, flip := true) -> Dictionary:
	return {"rect": Rect2(x, y, w, h), "prio": prio, "flip": flip}


func _final(items: Array, placed: Array) -> Array:
	var out := []
	for i in items.size():
		if placed[i] != null:
			out.append(Rect2((items[i].rect as Rect2).position + (placed[i] as Vector2), (items[i].rect as Rect2).size))
	return out


func _overlaps(rects: Array) -> int:
	var n := 0
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).intersects(rects[j]):
				n += 1
	return n


func test_a_label_alone_stays_where_it_was_put() -> void:
	var placed := Minimap.place_labels([_item(100, 100)], CHART)
	check_eq(placed[0], Vector2.ZERO, "not moved")


func test_five_on_one_spot_spread_out_without_overlapping() -> void:
	var items := []
	for i in 5:
		items.append(_item(200, 200, 110.0, 12.0, 5))
	var placed := Minimap.place_labels(items, CHART)
	var rects := _final(items, placed)
	check_eq(rects.size(), 5, "all five find a spot (below, above, the other side...)")
	check_eq(_overlaps(rects), 0, "and none lies over another")
	check_eq(placed[0], Vector2.ZERO, "the first keeps its own")


func test_the_more_important_label_keeps_its_spot() -> void:
	var items := [_item(200, 200, 80.0, 12.0, Minimap.P_TURF), _item(200, 200, 80.0, 12.0, Minimap.P_PLACE)]
	var placed := Minimap.place_labels(items, CHART)
	check_eq(placed[1], Vector2.ZERO, "the strip's code stays put")
	check(placed[0] == null or placed[0] != Vector2.ZERO, "the district's name moves or goes")


func test_with_no_free_spot_the_least_important_is_left_off() -> void:
	# a strip of labels filling a narrow chart: the last, least important one has nowhere to go
	var narrow := Rect2(0, 0, 100, 14)
	var items := [_item(5, 1, 90.0, 12.0, Minimap.P_PLACE), _item(5, 1, 90.0, 12.0, Minimap.P_TURF)]
	var placed := Minimap.place_labels(items, narrow)
	check_eq(placed[0], Vector2.ZERO, "the place")
	check(placed[1] == null, "the district's name is not drawn over it")


func test_labels_stay_on_the_chart_and_off_the_marks() -> void:
	var items := [_item(500, 300, 80.0, 12.0)]  # runs off the right edge where it was put
	var placed := Minimap.place_labels(items, CHART)
	check(placed[0] != null, "found a spot")
	var r: Rect2 = _final(items, placed)[0]
	check(CHART.encloses(r), "inside the chart: %s" % r)
	var mark := Rect2(150, 150, 10, 10)
	var by := [_item(145, 150, 60.0, 12.0)]
	var p2 := Minimap.place_labels(by, CHART, [mark])
	check(p2[0] != null and not (_final(by, p2)[0] as Rect2).intersects(mark), "not over a stash's square")


func test_a_centred_label_does_not_flip() -> void:
	var items := [_item(200, 200, 80.0, 12.0, 5), _item(200, 200, 80.0, 12.0, 1, false), _item(200, 213, 80.0, 12.0, 5), _item(200, 187, 80.0, 12.0, 5)]
	var placed := Minimap.place_labels(items, CHART)
	check(placed[1] == null, "the turf name, centred on its district, only moves up or down; with both taken it goes")


func test_the_same_labels_lay_out_the_same_way() -> void:
	var items := []
	for i in 12:
		items.append(_item(180 + (i % 3) * 20, 200 + (i % 4) * 6, 90.0, 12.0, i % 4))
	check_eq(Minimap.place_labels(items, CHART), Minimap.place_labels(items, CHART), "no jitter frame to frame")
