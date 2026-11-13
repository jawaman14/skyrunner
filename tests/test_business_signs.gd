extends TestCase
## The Living District's businesses in the 3D world (DESIGN 98): a sign at each site with its name and owner, in that org's colour,
## following the sim (a business bought changes its sign), shown only near the camera.


func after_each() -> void:
	World.use_map(0)


func test_a_sign_for_each_business_follows_its_owner() -> void:
	var s := Session.new({"seed": 3, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "trade": true, "logistics": true})
	check(s.businesses != null, "the city coast has the district's businesses")
	if s.businesses == null:
		s.dispose()
		return
	var signs := BusinessSigns.new(s)
	Engine.get_main_loop().root.add_child(signs)
	check_eq(signs.signs.size(), s.businesses.catalog.size(), "one sign a business")
	var b: Dictionary = s.businesses.catalog[0]
	var label: Label3D = signs.signs[str(b.id)]
	check(label.text.begins_with(str(b.name)), "named: %s" % label.text)
	s.businesses.owner[str(b.id)] = "rival"
	signs.refresh(label.position)
	check(label.text.ends_with("Los Cuervos") and label.modulate == BusinessSigns.COLOURS.rival, "theirs now: %s" % label.text)
	check(label.visible, "seen up close")
	signs.refresh(label.position + Vector3(BusinessSigns.SHOW_M + 10.0, 0, 0))
	check(not label.visible, "not from far off")
	var ground: float = maxf(0.0, s.world.ground(float(b.site[0]), float(b.site[1])))
	check_near(label.position.y, ground + BusinessSigns.POST_H + 1.0, 0.01, "on its post at the site")
	signs.free()
	s.dispose()


func test_the_words() -> void:
	var b := {"name": "Lavanderia Sol", "kind": "laundromat", "price": 42000}
	check_eq(BusinessSigns.text_for(b, "org"), "Lavanderia Sol\nlaundromat - ours")
	check_eq(BusinessSigns.text_for(b, ""), "Lavanderia Sol\nlaundromat - for sale: $42,000")
	check_eq(BusinessSigns.text_for(b, "outside"), "Lavanderia Sol\nlaundromat - not for sale")
	check_eq(BusinessSigns.text_for(b, "moretti"), "Lavanderia Sol\nlaundromat - The Morettis")
