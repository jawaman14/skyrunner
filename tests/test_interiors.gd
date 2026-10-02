extends TestCase
## The villa and the club are furnished from Kenney's Furniture Kit (Buildings.Kit.prop), not boxes.


func _kit() -> Buildings.Kit:
	return Buildings.Kit.new("t")


func _names(k: Buildings.Kit) -> Array:
	return k.root.get_children().map(func(c): return str(c.name))


func test_a_prop_stands_where_it_is_put_at_the_kits_scale() -> void:
	var k := _kit()
	var b: AABB = k.prop("desk", Vector3(5.0, 0.0, 7.0), 0.0)
	var c := b.get_center()
	check_near(c.x, 5.0, 0.02, "centred on x (%.3f)" % c.x)
	check_near(c.z, 7.0, 0.02, "and z (%.3f)" % c.z)
	check_near(b.position.y, 0.0, 0.01, "feet on the floor")
	check(b.size.x > 1.5 and b.size.x < 2.2, "a desk about 1.8 m wide at 2.4x (%.2f)" % b.size.x)
	check(b.end.y > 0.7 and b.end.y < 1.1, "and a desk's height (%.2f)" % b.end.y)
	check("desk" in _names(k), "it is in the building: %s" % [_names(k)])
	k.root.free()


func test_a_turned_prop_swaps_its_extents_and_stays_centred() -> void:
	var k := _kit()
	var a: AABB = k.prop("desk", Vector3(0.0, 0.0, 0.0), 0.0)
	var b: AABB = k.prop("desk", Vector3(10.0, 0.0, 10.0), 90.0)
	check_near(a.size.x, b.size.z, 0.02, "turned a quarter, its width is its depth")
	check_near(a.size.z, b.size.x, 0.02, "and the other way")
	check_near(b.get_center().x, 10.0, 0.02, "still centred (x)")
	check_near(b.get_center().z, 10.0, 0.02, "still centred (z)")
	k.root.free()


func test_a_prop_collides_unless_told_not_to() -> void:
	var k := _kit()
	k.prop("desk", Vector3.ZERO, 0.0)
	k.prop("computerScreen", Vector3(0, 0.8, 0), 0.0, 2.4, false)
	var solid := 0
	for c in k.root.get_children():
		for g in c.get_children():
			if g is StaticBody3D:
				solid += 1
	check_eq(solid, 1, "the desk is solid, the screen on it is not")
	k.root.free()


func test_a_missing_model_is_skipped() -> void:
	var k := _kit()
	var b: AABB = k.prop("noSuchThing", Vector3(1, 0, 2), 0.0)
	check_eq(b.size, Vector3.ZERO, "nothing placed")
	check_eq(k.root.get_child_count(), 1, "only the collision body is in the building")
	k.root.free()


func test_the_villa_and_the_club_are_furnished() -> void:
	var v := _kit()
	Buildings._villa(v)
	var vn := _names(v)
	for want in ["desk", "chairDesk", "table", "bookcaseClosedWide", "loungeSofa"]:
		check(want in vn, "the villa has a %s" % want)
	v.root.free()
	var c := _kit()
	Buildings._nightclub(c)
	var cn := _names(c)
	for want in ["desk", "stoolBar", "speaker", "loungeDesignSofa", "table"]:
		check(want in cn, "the club has a %s" % want)
	c.root.free()
