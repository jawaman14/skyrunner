extends TestCase
## CityDress: the city's boxes dressed as Kenney buildings. The lots a building is cut into stay inside its
## footprint and near its height; the same building always gets the same lots; the models are drawn near
## the camera and the shader boxes beyond (in chunks); low quality and a missing kit keep the boxes.


func after_each() -> void:
	CityDress.ENABLED = true
	World.use_map(0)


func _boxes(n := 160) -> Array:
	World.use_map(MapCity.SEED)
	var w := World.new()
	var out := []
	for b in w.map.buildings:
		if b.style != "crane":
			out.append(b)
		if out.size() >= n:
			break
	return out


func _bld(style: String, w: float, d: float, h: float) -> Dictionary:
	return {"x": 1000.0, "y": -2000.0, "z": 5.0, "w": w, "d": d, "h": h, "style": style}


func test_lots_stay_inside_the_building_and_near_its_height() -> void:
	for style in ["res", "shop", "tower", "warehouse"]:
		var b := _bld(style, 36.0, 30.0, 40.0 if style == "tower" else 12.0)
		var lots := CityDress.lots(b, 3)
		check(not lots.is_empty(), "%s: some lots" % style)
		for lot in lots:
			var p: Vector3 = (lot.xf as Transform3D).origin
			# the origin is the model's own corner of the world: its base centre is what stands on the lot
			check(lot.roof > float(b.z) - 1.0, "%s: the roof is above the ground" % style)
			var height: float = float(lot.roof) - (float(b.z) - CityDress.SINK)
			check(height > 0.4 * float(b.h) and height < 2.2 * float(b.h), "%s: a lot %.1f m tall under a %.0f m box" % [style, height, float(b.h)])
			check(lot.colour is Color, "%s: tinted" % style)
		var kits := {}
		for lot in lots:
			kits[lot.kit] = true
		match style:
			"warehouse":
				check_eq(kits.keys(), ["industrial"], "warehouses are industrial sheds")
			"tower":
				check(kits.has("commercial"), "towers are commercial")


func test_a_box_is_cut_into_lots_by_its_size_and_the_same_box_always_the_same() -> void:
	var small := CityDress.lots(_bld("res", 22.0, 22.0, 10.0), 1)
	var big := CityDress.lots(_bld("res", 44.0, 44.0, 10.0), 1)
	check(small.size() < big.size(), "a bigger box has more lots (%d vs %d)" % [small.size(), big.size()])
	check(big.size() <= 9, "no more than 9")
	var a := CityDress.lots(_bld("shop", 40.0, 30.0, 14.0), 77)
	var b := CityDress.lots(_bld("shop", 40.0, 30.0, 14.0), 77)
	check_eq(a.size(), b.size(), "same number of lots")
	for i in a.size():
		check(a[i].name == b[i].name and (a[i].xf as Transform3D).is_equal_approx(b[i].xf), "lot %d is the same" % i)
	var other := CityDress.lots(_bld("shop", 40.0, 30.0, 14.0), 78)
	var same := other.size() == a.size()
	for i in mini(a.size(), other.size()):
		same = same and a[i].name == other[i].name
	check(not same or a.size() == 1, "another building, another pick")


func test_buildings_face_the_nearest_street() -> void:
	var go: Vector2 = MapCity.CITY_C - MapCity.CITY_R
	var g := CityRender.GRID_BLOCK
	# just east of a north-south street: the street is to the west (-x), so face -x: yaw atan2(-1, 0)
	var west := CityDress.street_yaw(go.x + 6.0, go.y + g * 0.5)
	check(absf(west - atan2(-1.0, 0.0)) < 0.001, "street to the west: yaw %.2f" % west)
	var east := CityDress.street_yaw(go.x + g - 6.0, go.y + g * 0.5)
	check(absf(east - atan2(1.0, 0.0)) < 0.001, "street to the east: yaw %.2f" % east)
	# near an east-west street to the south (smaller y): face -y, which is +z in Godot: yaw 0
	var south := CityDress.street_yaw(go.x + g * 0.5, go.y + 6.0)
	check(absf(south) < 0.001, "street to the south: yaw %.2f" % south)


func test_build_draws_models_near_and_boxes_far_in_chunks() -> void:
	var boxes := _boxes(200)
	var q := Quality.get_preset("high")
	check(CityDress.draw_range(q) > 0.0, "the kits are there: models on high (%.0f m)" % CityDress.draw_range(q))
	var root := CityDress.build(boxes, q)
	var chunks := root.get_children()
	check(chunks.size() >= 1, "at least a chunk (%d)" % chunks.size())
	var lots := 0
	var models := 0
	var boxes_drawn := 0
	for c in chunks:
		for n in c.get_children():
			if n is StaticBody3D:
				continue  # the collision
			var mmi := n as MultiMeshInstance3D
			if mmi.name == "buildings":
				boxes_drawn += mmi.multimesh.instance_count
				check_eq(mmi.visibility_range_begin, CityDress.draw_range(q), "the boxes take over beyond the models' range")
				continue
			models += 1
			lots += mmi.multimesh.instance_count
			check(mmi.visibility_range_end > CityDress.draw_range(q), "%s is drawn to a range" % mmi.name)
			check(mmi.material_override is ShaderMaterial, "%s has the lot shader" % mmi.name)
	check_eq(boxes_drawn, boxes.size(), "every building is still a box beyond the range")
	var expect := 0
	for i in boxes.size():
		expect += CityDress.lots(boxes[i], i).size()
	check_eq(lots, expect, "every lot of every building is an instance (%d)" % lots)
	check(models >= 3, "several kinds of model (%d)" % models)
	root.free()


func test_low_quality_and_a_switched_off_dress_keep_only_the_boxes() -> void:
	var boxes := _boxes(60)
	for case in ["low", "off"]:
		if case == "off":
			CityDress.ENABLED = false
		var q := Quality.get_preset("low" if case == "low" else "high")
		check_eq(CityDress.draw_range(q), 0.0, "%s: no models" % case)
		var root := CityDress.build(boxes, q)
		var total := 0
		for c in root.get_children():
			check_eq(c.get_child_count(), 2, "%s: a chunk holds just its boxes and its collision" % case)
			total += ((c.get_child(0) as MultiMeshInstance3D).multimesh.instance_count)
			check_eq((c.get_child(0) as MultiMeshInstance3D).visibility_range_begin, 0.0, "%s: always visible" % case)
		check_eq(total, boxes.size(), "%s: all the boxes" % case)
		root.free()


func test_a_box_is_the_same_colour_whichever_chunk_it_is_in() -> void:
	var boxes := _boxes(80)
	var q := Quality.get_preset("low")
	var whole := CityRender.box_layer(boxes, q)
	var idx := []
	var some := []
	for i in boxes.size():
		if i % 3 == 0:
			idx.append(i)
			some.append(boxes[i])
	var part := CityRender.box_layer(some, q, idx)
	for k in some.size():
		var a := whole.multimesh.get_instance_color(idx[k])
		var b := part.multimesh.get_instance_color(k)
		check(a.is_equal_approx(b), "building %d keeps its colour" % idx[k])
	whole.free()
	part.free()


func test_the_night_reaches_the_lot_shader() -> void:
	var m := CityDress.material("commercial")
	CityDress.set_night(1.0)
	check_eq(float(m.get_shader_parameter("night")), 1.0, "lit windows at night")
	CityDress.set_night(0.0)
	check_eq(float(m.get_shader_parameter("night")), 0.0, "and dark by day")


func test_the_roads_are_marked_and_the_town_has_pavements() -> void:
	World.use_map(MapCity.SEED)
	var w := World.new()
	var d := CityRender._road_details(w, w.map.roads)
	var paint := d.get_node("markings") as MeshInstance3D
	var pave := d.get_node("pavements") as MeshInstance3D
	check(paint.mesh.get_surface_count() == 1, "lane markings are painted")
	check(pave.mesh.get_surface_count() == 1, "and the town has pavements")
	var pv := (paint.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var kv := (pave.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	check(pv > 1000 and kv > 500, "plenty of both (%d, %d vertices)" % [pv, kv])
	# the paint sits just above the asphalt ribbon: every paint vertex is within 15 cm of it, above the ground
	var smp := CityRender._samples(w, w.map.roads[0])
	var s: Array = smp[smp.size() / 2]
	var p: Vector2 = s[0]
	check(float(s[2]) > w.ground(p.x, p.y) - 0.01, "the ribbon is on or above the ground")
	d.free()


func test_the_city_is_solid_one_box_a_building() -> void:
	var boxes := [{"x": 100.0, "y": 50.0, "z": 3.0, "w": 20.0, "d": 12.0, "h": 15.0, "style": "block"},
		{"x": -80.0, "y": 10.0, "z": 0.0, "w": 30.0, "d": 30.0, "h": 40.0, "style": "tower"}]
	var body := CityDress.colliders(boxes)
	check_eq(body.get_child_count(), 2, "a shape each")
	var cs := body.get_child(0) as CollisionShape3D
	var bs := cs.shape as BoxShape3D
	check_eq(bs.size, Vector3(20.0, 16.5, 12.0), "the footprint and the height, sunk 1.5 m like the drawn box")
	check_near(cs.position.x, 100.0, 0.001, "at its x")
	check_near(cs.position.z, -50.0, 0.001, "and -y (the island's north is -z)")
	check_near(cs.position.y, 3.0 - 1.5 + 8.25, 0.001, "its base under the ground")
	body.free()
	var q := Quality.get_preset("low")
	var city := CityDress.build(boxes, q)
	var chunks := 0
	for c in city.get_children():
		if c.get_node_or_null("collision") != null:
			chunks += 1
	check_eq(chunks, city.get_child_count(), "every chunk carries its collision, whatever the quality")
	city.free()


## Nothing the player has to reach may be inside a building's footprint, or the new walls would wall it in.
func test_no_stash_strip_or_headquarters_is_inside_a_building() -> void:
	World.use_map(MapCity.SEED)
	var s := Session.new({"seed": 1, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	var bs: Array = s.world.map.buildings.filter(func(b): return b.style != "crane")
	var pts := {}
	for st in s.world.map.stashes:
		pts["stash " + str(st.id)] = Vector2(st.x, st.y)
	for a in s.world.airfields:
		pts["strip " + a.code] = Vector2(a.x, a.y)
	pts["the organisation's base"] = s.ground.hq("org")
	pts["the rival's base"] = s.ground.hq("rival")
	pts["the task force's base"] = s.ground.hq("police")
	check(bs.size() > 1000, "the city has buildings (%d)" % bs.size())
	for k in pts:
		var p: Vector2 = pts[k]
		var inside := bs.any(func(b): return absf(p.x - b.x) < float(b.w) / 2.0 + 2.0 and absf(p.y - b.y) < float(b.d) / 2.0 + 2.0)
		check(not inside, "%s is clear of the buildings" % k)
	s.dispose()
	World.use_map(0)
