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
		k.gable(Vector3(0, 2.2, 0), size.x, size.z, 0.4, "green", 0.2, true)
		for at in [Vector3(7, 0.2, 3), Vector3(-6, 0.2, 4)]:
			k.gable(at, 5, 7, 2.6, "green", 0.2, true)
	else:
		room(k, center, size.x, size.y, size.z, spec.material, 3.0 if stash.kind == "warehouse" else 2.0)
		if stash.kind == "warehouse":
			k.box(Vector3(0, size.y + 0.1, 0), Vector3(size.x, 0.2, size.z), "metal_rust")
		else:
			var rise: float = {"barn": 3.5, "shack": 1.4, "shed": 1.4, "boathouse": 2.0, "villa": 2.4}.get(stash.kind, 1.4)
			k.gable(center + Vector3(0, size.y, 0), size.x, size.z, rise, "terracotta" if stash.kind == "villa" else "metal_rust", 0.6, true)
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
	if world.map.map_seed == MapCity.SEED and stash.id == "docks" and stash.kind == "warehouse":
		warehouse_frontage(k, size)
	if world.map.map_seed == MapCity.SEED:
		rural_dressing(k, stash, size)
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

## Warehouse 7's working-port identity is painted onto its existing shell.
## Thin battens sit against the wall; the central loading doorway stays clear.
static func warehouse_frontage(k: Buildings.Kit, size: Vector3) -> void:
	var front := -size.z / 2
	k.box(Vector3(0, 5.0, front - 0.035), Vector3(10, 1.2, 0.05), "pump_cream", false)
	Buildings.painted_sign(k, "warehouse-seven-name", "ALMACEN 7", Vector3(0, 5.0, front - 0.065), 0.025)
	for side in [-1, 1]:
		# Door-jamb paint and low scuffs, with no step or barrier at the threshold.
		k.box(Vector3(side * 1.7, 1.2, front - 0.025), Vector3(0.18, 2.4, 0.035), "pump_cream", false)
		for mark in 4:
			k.box(Vector3(side * 1.7, 0.3 + mark * 0.55, front - 0.05), Vector3(0.18, 0.15, 0.015), "black", false)
		for rib in 4:
			var x: float = side * (3.5 + rib * 3.0)
			k.box(Vector3(x, size.y / 2, front - 0.025), Vector3(0.045, size.y - 0.3, 0.035), "metal_rust", false)
		k.box(Vector3(side * 8, 0.3, front - 0.025), Vector3(8, 0.3, 0.025), "metal_rust", false)


## Hand-authored rural scenery, contained by each existing storage shell.
## These stacks and furnishings are scenery, not stock or new interaction points.
static func rural_dressing(k: Buildings.Kit, stash: Dictionary, size: Vector3) -> void:
	var front := -size.z / 2
	if stash.id == "barn" and stash.kind == "barn":
		k.box(Vector3(0, 3.65, front - 0.04), Vector3(7, 0.8, 0.05), "pump_cream", false)
		Buildings.painted_sign(k, "finca-morales-name", "FINCA MORALES", Vector3(0, 3.65, front - 0.075), 0.018)
		# Bound hay stacks sit along the left wall, leaving the main aisle open.
		for z in [-5.0, -2.0]:
			var at := Vector3(-size.x / 2 + 1.4, 0.65, z)
			k.box(at, Vector3(2, 1.2, 1.8), "pump_cream")
			for band in [-0.55, 0.55]:
				k.box(at + Vector3(band, 0, -0.91), Vector3(0.04, 1.2, 0.025), "wood", false)
				k.box(at + Vector3(band, 0.61, 0), Vector3(0.04, 0.025, 1.8), "wood", false)
			k.box(at + Vector3(0, 0, -0.92), Vector3(2, 0.035, 0.02), "wood", false)
		var timber := Vector3(size.x / 2 - 1.3, 0.55, 0)
		k.box(timber, Vector3(1.2, 1, 4.8), "wood")
		for row in 4:
			k.box(timber + Vector3(0, -0.36 + row * 0.24, -2.41), Vector3(1.2, 0.025, 0.025), "black", false)
	elif stash.id == "quarry" and stash.kind == "shed":
		var bench := Vector3(-size.x / 2 + 1.6, 0, size.z / 2 - 1.45)
		k.box(bench + Vector3(0, 0.65, 0), Vector3(2.4, 1.2, 1.2), "wood")
		Buildings.workshop_tools(k, bench)
		k.box(Vector3(-3, 2.05, front - 0.04), Vector3(1.6, 0.45, 0.05), "pump_cream", false)
		Buildings.painted_sign(k, "quarry-name", "CANTERA", Vector3(-3, 2.05, front - 0.075), 0.0075)
		var scrap := Vector3(size.x / 2 - 1.2, 0.35, 0)
		k.box(scrap, Vector3(1.2, 0.6, 2), "metal_rust")
		for row in 3:
			k.box(scrap + Vector3(0, -0.15 + row * 0.18, -1.015), Vector3(1.2, 0.025, 0.025), "black", false)
	elif stash.id == "camp" and stash.kind == "camp":
		var shelf := Vector3(-size.x / 2 + 0.6, 0.6, 0.3)
		k.box(shelf, Vector3(0.65, 1.1, 2), "wood")
		for row in 2:
			k.box(shelf + Vector3(0.335, -0.3 + row * 0.55, 0), Vector3(0.02, 0.09, 2), "metal_rust", false)
			for z in [-0.6, 0.3]:
				k.box(shelf + Vector3(0.34, -0.1 + row * 0.55, z), Vector3(0.02, 0.28, 0.45), "drum_sage", false)
		# One solid cot envelope, away from the doorway and rear logistics desk.
		var cot := Vector3(size.x / 2 - 0.85, 0.325, 0.4)
		k.box(cot, Vector3(0.85, 0.5, 1.8), "wood")
		k.box(cot + Vector3(0, 0.26, 0), Vector3(0.82, 0.05, 1.76), "green", false)
		k.box(cot + Vector3(0, 0.31, 0.6), Vector3(0.65, 0.05, 0.35), "pump_cream", false)
		k.box(Vector3(-1.65, 1.75, front - 0.04), Vector3(1.3, 0.45, 0.05), "wood", false)
		Buildings.painted_sign(k, "la-selva-name", "LA SELVA", Vector3(-1.65, 1.75, front - 0.075), 0.006)
		# Patches sit on the existing canvas side wall, below the pitched roof.
		for z in [-1.4, 1.2]:
			k.box(Vector3(-size.x / 2 - 0.015, 1.5, z), Vector3(0.025, 0.55, 0.7), "drum_sage", false)


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
