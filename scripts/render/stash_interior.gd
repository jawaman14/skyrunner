class_name StashInterior
extends RefCounted
## Reusable period storage shells. Decorative furniture represents no inventory.
static func room(k: Buildings.Kit, c: Vector3, w: float, h: float, d: float, material: String, door := 2.0) -> void:
	k.box(c + Vector3(0, 0.04, 0), Vector3(w, 0.08, d), "concrete")
	k.wall(c.x - w / 2, c.z - d / 2 + 0.1, c.x + w / 2, c.z - d / 2 + 0.1, c.y, h, 0.2, material, door, minf(h, 2.8))
	k.box(c + Vector3(0, h / 2, d / 2 - 0.1), Vector3(w, h, 0.2), material)
	for side in [-1, 1]:
		k.box(c + Vector3(side * (w / 2 - 0.1), h / 2, 0), Vector3(0.2, h, d), material)

static func build(world: World, stash: Dictionary) -> Node3D:
	var k := Buildings.Kit.new("stash-" + str(stash.id))
	var spec := SiteLayout.stash_spec(stash)
	var size: Vector3 = spec.dimensions
	var floor_y: float = spec.floor
	var center := Vector3(0, floor_y, 0)
	if stash.kind == "lockup":
		for i in 4:
			room(k, Vector3(-6 + i * 4.0, 0, 0), 3.8, 2.8, 6, "concrete", 1.6)
			k.box(Vector3(-6 + i * 4.0, 2.85, 0), Vector3(3.8, 0.1, 6), "metal_rust")
	elif stash.kind == "camp":
		# Raised ridge leaves a full-height opening instead of a sealed triangle.
		room(k, center, size.x, 2.2, size.z, "green", 2.0)
		k.gable(Vector3(0, 2.2, 0), size.x, size.z, 0.4, "green", 0.2)
		for at in [Vector3(7, 0.2, 3), Vector3(-6, 0.2, 4)]:
			k.gable(at, 5, 7, 2.6, "green", 0.2)
	else:
		room(k, center, size.x, size.y, size.z, spec.material, 3.0 if stash.kind == "warehouse" else 2.0)
		if stash.kind == "warehouse":
			k.box(Vector3(0, size.y + 0.1, 0), Vector3(size.x, 0.2, size.z), "metal_rust")
		else:
			var rise: float = {"barn": 3.5, "shack": 1.4, "shed": 1.4, "boathouse": 2.0, "villa": 2.4}.get(stash.kind, 1.4)
			k.gable(center + Vector3(0, size.y, 0), size.x, size.z, rise, "terracotta" if stash.kind == "villa" else "metal_rust")
	if stash.kind == "shack":
		for side in [-1, 1]:
			for end in [-1, 1]:
				k.box(Vector3(side * 2.6, 0.9, end * 2.0), Vector3(0.25, 1.8, 0.25), "wood")
		# Shallow steps retain a clear 2m route to the raised threshold.
		for step in 7:
			var height := (step + 1) * floor_y / 7.0
			k.box(Vector3(0, height / 2, -size.z / 2 - (6 - step) * 0.6 - 0.3), Vector3(2, height, 0.6), "wood")
	if stash.kind == "boathouse":
		# Jetty joins the doorway with steps, rather than a 0.6m ledge.
		k.box(Vector3(0, 0.3, -12), Vector3(3, 0.6, 10), "wood")
		k.box(Vector3(0, 0.15, -6.6), Vector3(2, 0.3, 0.8), "wood")
		k.box(Vector3(0, 0.15, -17.4), Vector3(2, 0.3, 0.8), "wood")
	var desk_x: float = -6.0 if stash.kind == "lockup" else 0.0
	var desk_z := size.z / 2 - 1.0
	k.box(Vector3(desk_x, floor_y + 0.95, desk_z), Vector3(2.0, 0.12, 0.7), "wood")
	for side in [-1, 1]:
		k.box(Vector3(desk_x + side * 0.8, floor_y + 0.45, desk_z), Vector3(0.12, 0.9, 0.55), "metal_rust")
	k.box(Vector3(desk_x + 0.4, floor_y + 1.05, desk_z), Vector3(0.45, 0.08, 0.3), "pump_cream", false)
	k.interact(Vector3(desk_x, floor_y + 1.2, desk_z - 1.0), "stash_logistics", "Storage / logistics: " + str(stash.get("name", stash.id)), 1.0)
	var node := k.finish()
	node.transform = SiteLayout.stash_frame(world, stash)
	node.set_meta("stash", stash.id)
	var area := node.get_node("use_stash_logistics") as Area3D
	area.set_meta("stash", stash.id)
	return node

static func available(stash: Dictionary) -> bool:
	return not stash.is_empty() and not bool(stash.get("burned", false))

static func show_state(node: Node3D, stash: Dictionary) -> void:
	var area := node.get_node("use_stash_logistics") as Area3D
	var usable := available(stash)
	area.set_meta("label", ("Storage / logistics: " if usable else "Unavailable — burned stash: ") + str(stash.get("name", node.get_meta("stash"))))
	var sign := node.get_node_or_null("availability") as Label3D
	if sign == null:
		sign = Label3D.new()
		sign.name = "availability"
		sign.font_size = 32
		sign.pixel_size = 0.015
		node.add_child(sign)
		sign.position = area.position + Vector3(0, 0.7, 0)
	sign.text = "STORAGE / WORKSHOP" if usable else "BURNED — STORAGE UNAVAILABLE"
	sign.modulate = Color(0.8, 0.76, 0.65) if usable else Color(0.8, 0.3, 0.2)
