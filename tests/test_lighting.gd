extends TestCase
## Real light at night: the street lamps nearest the camera, and the car's headlights.


func _tree() -> SceneTree:
	return Engine.get_main_loop()


func after_each() -> void:
	World.use_map(0)


func _lamps() -> PackedVector3Array:
	return PackedVector3Array([Vector3(0, 7, 0), Vector3(40, 7, 0), Vector3(80, 7, 0), Vector3(500, 7, 0), Vector3(-30, 7, 20)])


func test_the_nearest_lamps_within_range_come_first() -> void:
	var near := StreetLights.nearest(_lamps(), Vector3(5, 1, 0), 3)
	check_eq(near.size(), 3, "three of them")
	check_eq(near[0], Vector3(0, 7, 0), "the nearest first")
	check_eq(near[1], Vector3(40, 7, 0), "then the next")
	check(not near.has(Vector3(500, 7, 0)), "the one 500 m away is out of range")
	check_eq(StreetLights.nearest(_lamps(), Vector3(5000, 0, 0), 4).size(), 0, "far from every lamp: none")


func test_the_pool_lights_the_lamps_by_night_and_nothing_by_day() -> void:
	var sl := StreetLights.new()
	sl.heads = _lamps()
	for i in 3:
		var l := OmniLight3D.new()
		sl.add_child(l)
		sl.pool.append(l)
	_tree().root.add_child(sl)
	sl.night = 0.0
	sl.place(Vector3(0, 1, 0))
	check(sl.pool.all(func(l): return not l.visible), "by day no lamp is lit")
	sl.night = 1.0
	sl.place(Vector3(0, 1, 0))
	check(sl.pool.all(func(l): return l.visible and l.light_energy > 3.0), "at night all three are")
	check_near((sl.pool[0] as OmniLight3D).global_position.x, 0.0, 0.01, "the first is on the nearest lamp")
	sl.place(Vector3(500, 1, 0))
	check_eq(sl.pool.filter(func(l): return l.visible).size(), 1, "out where only one lamp is near, one light is on")
	sl.night = 0.4
	sl.place(Vector3(0, 1, 0))
	var dim: float = (sl.pool[0] as OmniLight3D).light_energy
	sl.night = 1.0
	sl.place(Vector3(0, 1, 0))
	check(dim < (sl.pool[0] as OmniLight3D).light_energy, "dusk is dimmer than midnight")
	sl.queue_free()


func test_the_town_scene_has_a_pool_on_medium_and_high_only() -> void:
	var s := Session.new({"seed": 1, "map_seed": MapCity.SEED, "location": "HAR"})
	var counts := {}
	for q in ["low", "medium", "high"]:
		var scene := WorldScene.new()
		_tree().root.add_child(scene)
		scene.setup(s.world, Quality.get_preset(q))
		counts[q] = 0 if scene.street_lights == null else scene.street_lights.pool.size()
		if scene.street_lights != null:
			check(scene.street_lights.heads.size() > 100, "%s: it knows the lamps (%d)" % [q, scene.street_lights.heads.size()])
		scene.set_hour(23.0)
		if scene.street_lights != null:
			check(scene.street_lights.night > 0.9, "%s: told it is night" % q)
		scene.queue_free()
	check_eq(counts, {"low": 0, "medium": 5, "high": 10}, "lights per quality")
	s.dispose()


func test_the_car_has_headlights_that_come_on_in_the_dark_when_driven() -> void:
	var s := Session.new({"seed": 9, "location": "COV", "features": Session.SANDBOX_FEATURES, "ground_war": true})
	var app := PilotApp.new()
	_tree().root.add_child(app)
	app.setup(s, "low")
	app._toggle_on_foot()
	for i in 20:
		await _tree().physics_frame
	var car: Car = app.car
	check_eq(car.headlights.size(), 2, "two headlamps")
	check(car.headlights.all(func(h): return h is SpotLight3D and not h.visible), "off to begin with")
	app.walker.place(car.global_position.x + 3.0, -car.global_position.z, 0.0)
	app._enter_car()
	app.scene.set_hour(13.0)
	app._car_lights()
	check(car.headlights.all(func(h): return not h.visible), "not at noon")
	app.scene.set_hour(23.0)
	app._car_lights()
	check(car.headlights.all(func(h): return h.visible), "on at night while driving")
	car.speed = 0.0
	app._exit_car()
	app._car_lights()
	check(car.headlights.all(func(h): return not h.visible), "and off once you are out")
	app.free()
	s.dispose()
