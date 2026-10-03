extends TestCase
## The docks' piers, crates and moored boats (PortDress, from the Pirate Kit).


func after_each() -> void:
	PortDress.ENABLED = true
	World.use_map(0)


func _city() -> World:
	World.use_map(MapCity.SEED)
	return World.new()


func test_the_piers_stand_on_the_quay_edge_inside_the_harbour() -> void:
	var w := _city()
	var ps := PortDress.piers(w)
	check(ps.size() >= 8, "the harbour has piers (%d)" % ps.size())
	for p in ps:
		check(p[0] > MapCity.HARBOUR_X.x and p[0] < MapCity.HARBOUR_X.y, "pier %d is inside the basin's width" % p[2])
		check(w.ground(p[0], p[1]) < 0.3, "its end of the quay is the water's edge")
		check(w.ground(p[0], p[1] + 14.0) > 0.5, "with quay behind it")
	check_eq(PortDress.piers(w), ps, "the same piers every time")


func test_it_builds_the_pieces_and_is_off_when_asked_or_on_another_map() -> void:
	var w := _city()
	var n := PortDress.build(w, Quality.get_preset("high"))
	check(n.get_child_count() > 40, "a pier's tiles, crates and a boat for each of them (%d pieces)" % n.get_child_count())
	n.free()
	PortDress.ENABLED = false
	var off := PortDress.build(w, Quality.get_preset("high"))
	check_eq(off.get_child_count(), 0, "nothing when switched off")
	off.free()
	PortDress.ENABLED = true
	var low := PortDress.build(w, Quality.get_preset("low"))
	check_eq(low.get_child_count(), 0, "nothing on the lowest preset")
	low.free()
	World.use_map(0)
	var classic := PortDress.build(World.new(), Quality.get_preset("high"))
	check_eq(classic.get_child_count(), 0, "and nothing on the classic island")
	classic.free()
