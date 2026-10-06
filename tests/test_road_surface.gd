extends TestCase

class FlatWater extends World:
	func ground(_x: float, _y: float) -> float: return 0.0
	func height(_x: float, _y: float) -> float: return -3.0

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
