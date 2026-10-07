extends TestCase
class FlatLand extends World:
	func ground(_x: float, _y: float) -> float: return 0.0
	func height(_x: float, _y: float) -> float: return 0.0

func _travel(walker: Walker, target: float) -> void:
	var direction := Vector3(0, 0, signf(target - walker.position.z))
	for i in 600:
		if absf(walker.position.z - target) < 0.12: return
		walker.velocity = Vector3(0, walker.velocity.y - Walker.GRAVITY / 60.0, direction.z * 5)
		walker.move_and_slide()
		walker._step_up(direction)
		await Engine.get_main_loop().physics_frame

func test_every_stash_has_a_walkable_entrance_and_storage_aisle() -> void:
	var world := FlatLand.new()
	for kind in SiteLayout.STASH:
		var stash := {"id": kind, "kind": kind, "x": 0.0, "y": 0.0, "name": kind, "burned": false}
		var root := Node3D.new()
		Engine.get_main_loop().root.add_child(root)
		var ground := Buildings.Kit.new("test-ground")
		ground.box(Vector3(0, -0.1, 0), Vector3(100, 0.2, 100), "concrete")
		root.add_child(ground.finish())
		var node := StashInterior.build(world, stash)
		root.add_child(node)
		var spec := SiteLayout.stash_spec(stash)
		var entry: Vector3 = spec.entry
		var walker := Walker.new().setup(world)
		root.add_child(walker)
		walker.set_physics_process(false)
		walker.look_enabled = false
		var outside: float = entry.z - (11.0 if kind == "boathouse" else 5.0)
		walker.position = Vector3(entry.x, 0.1, outside)
		for i in 3: await Engine.get_main_loop().physics_frame
		var area := node.get_node("use_stash_logistics") as Area3D
		await _travel(walker, area.position.z - 0.8)
		check(absf(walker.position.z - (area.position.z - 0.8)) < 0.2, kind + " entrance and interior aisle")
		check(walker.unobstructed(area), kind + " workbench is reachable without a wall")
		check_near(walker.position.y, float(spec.floor) + 0.08, 0.12, kind + " usable floor")
		await _travel(walker, outside)
		check(absf(walker.position.z - outside) < 0.2, kind + " exit remains usable")
		root.free()

func test_burned_state_labels_access_without_trapping_player() -> void:
	var stash := {"id": "test", "kind": "barn", "x": 0.0, "y": 0.0, "name": "Test", "burned": false}
	var node := StashInterior.build(FlatLand.new(), stash)
	StashInterior.show_state(node, stash)
	check(StashInterior.available(stash))
	stash.burned = true
	StashInterior.show_state(node, stash)
	check(not StashInterior.available(stash))
	check("burned" in str(node.get_node("use_stash_logistics").get_meta("label")))
	check("UNAVAILABLE" in node.get_node("availability").text)
	check(not StashInterior.available({}))
	node.free()

func test_logistics_focus_uses_stable_stash_id() -> void:
	var menu := LogisticsMenu.new()
	menu.view_fn = func(): return {"sites": [{"id": "a", "name": "A", "market": "town", "burned": false, "cash": 0, "cocaine": 0, "marijuana": 0}, {"id": "b", "name": "B", "market": "town", "burned": false, "cash": 0, "cocaine": 0, "marijuana": 0}], "hq": "Club", "aboard": 0, "trucks": [], "last": ""}
	menu.focused_stash = "b"
	Engine.get_main_loop().root.add_child(menu)
	check_eq(menu._sites[menu.from_ob.selected], "b")
	menu.refresh()
	check_eq(menu._sites[menu.from_ob.selected], "b")
	menu.focus_source("a")
	check_eq(menu._sites[menu.from_ob.selected], "a")
	menu.free()
