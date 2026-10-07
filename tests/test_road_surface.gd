extends TestCase

class FlatWater extends World:
	func ground(_x: float, _y: float) -> float: return 0.0
	func height(_x: float, _y: float) -> float: return -3.0
	func is_water(_x: float, _y: float) -> bool: return true

func _world() -> World:
	var world := FlatWater.new()
	world.map = MapLayout.classic()
	world.map.roads = [[[-100.0, 0.0], [100.0, 0.0]]]
	return world

func test_render_collision_and_queries_share_the_same_deck() -> void:
	var world := _world()
	var surface := world.road_surface()
	check(surface.vertices.size() > 0)
	check_near(surface.sample(Vector2.ZERO).height, 2.65, 0.0001)
	check(not surface.sample(Vector2(0, 8)).on_surface, "outside the drawn ribbon is not a deck")
	var node := CityRender._roads(world, world.map.roads)
	var collider: CollisionShape3D = node.get_node("road-deck-collision/deck-shape")
	check_eq(collider.shape.get_faces(), surface.vertices, "collider vertices are the rendered vertices")
	check_near(world.travel_surface(0, 0), 2.65, 0.0001)
	check_eq(world.ground(0, 0), 0.0, "aircraft terrain unchanged")
	node.free()

func test_walker_and_car_stand_on_the_deck_over_deep_water() -> void:
	var world := _world()
	var root := Node3D.new()
	Engine.get_main_loop().root.add_child(root)
	root.add_child(CityRender._roads(world, world.map.roads))
	var walker := Walker.new().setup(world)
	root.add_child(walker)
	walker.position = Vector3(-5, 3, 0)
	walker.look_enabled = false
	var car := Car.new().setup(world)
	root.add_child(car)
	car.place(5, 0, 0)
	for i in 90:
		await Engine.get_main_loop().physics_frame
	check(walker.is_on_floor() and walker.global_position.y > 2.5, "walker stands above water on the deck")
	check(car.is_on_floor() and car.global_position.y > 2.4, "car stands above water on the same deck: %s floor %s" % [car.global_position, car.is_on_floor()])
	root.free()

class BridgeBanks extends World:
	func ground(_x: float, _y: float) -> float: return 0.0
	func height(x: float, _y: float) -> float: return -3.0 if absf(x) < 15.0 else 0.0
	func is_water(x: float, _y: float) -> bool: return absf(x) < 15.0

func _banks() -> World:
	var world := BridgeBanks.new()
	world.map = MapLayout.classic()
	world.map.roads = [[[-100.0, 0.0], [100.0, 0.0]]]
	return world

func test_dry_roads_and_bridge_approaches_share_a_graded_surface() -> void:
	var world := _banks()
	var cross := RoadSurface.samples(world, world.map.roads[0])
	check_near(float(cross[0][2]), 0.45, 0.0001, "dry lowland road is a reachable step")
	check_near(world.travel_surface(0, 0), 2.65, 0.0001, "water retains bridge clearance")
	for i in range(1, cross.size()):
		var distance: float = cross[i][0].distance_to(cross[i - 1][0])
		check(absf(float(cross[i][2]) - float(cross[i - 1][2])) <= distance * RoadSurface.APPROACH_GRADE + 0.0001, "approach has no abrupt deck step")
	check_near(CityRender.deck_z(world, Vector2(30, 0), Vector2(0, 4.5)), world.travel_surface(30, 0), 0.0001, "railings follow graded collision")

func test_bridge_can_be_walked_and_driven_in_both_directions() -> void:
	var world := _banks()
	var root := Node3D.new()
	Engine.get_main_loop().root.add_child(root)
	root.add_child(CityRender._roads(world, world.map.roads))
	var ground := Buildings.Kit.new("banks")
	for side in [-1, 1]:
		ground.box(Vector3(side * 60, -0.2, 0), Vector3(90, 0.4, 50), "concrete")
	root.add_child(ground.finish())
	for direction in [-1, 1]:
		var walker := Walker.new().setup(world)
		root.add_child(walker)
		walker.set_physics_process(false)
		walker.look_enabled = false
		walker.position = Vector3(-direction * 45, 0.6, 1)
		for i in 3: await Engine.get_main_loop().physics_frame
		for i in 1200:
			walker.velocity = Vector3(direction * 5, walker.velocity.y - Walker.GRAVITY / 60.0, 0)
			walker.move_and_slide()
			walker._step_up(Vector3(direction, 0, 0))
			await Engine.get_main_loop().physics_frame
			if walker.position.x * direction >= 45: break
		check(walker.position.x * direction >= 45 and walker.position.y > 0.3, "walker crosses both approaches: " + str(direction))
		walker.free()
		var car := Car.new().setup(world)
		root.add_child(car)
		car.set_physics_process(false)
		car.place(-direction * 45, 0, 90 if direction > 0 else -90)
		for i in 900:
			car._drive(0.4, 0, false, 1.0 / 60.0)
			await Engine.get_main_loop().physics_frame
			if car.position.x * direction >= 45: break
		check(car.position.x * direction >= 45 and car.position.y > 0.2, "car crosses both approaches: " + str(direction))
		car.free()
	root.free()
