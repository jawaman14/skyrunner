class_name CasinoBuilding
extends RefCounted
## The Hotel Cielo, walkable: the Family's casino hotel on Isla Soberana, built the way Havana built them in the 1950s (the
## Nacional's grand lobby, the Capri's compact floor, the Riviera's slab tower and rooftop sign, the Tropicana's open-air cabaret
## under its great concrete arches). Fiction: the name and everything in it are made up.
##
## It stands on the flat of the airfield, 75 m from the runway's right edge and 150 m along it, its face to the runway:
##   * the forecourt, a porte-cochere with a neon edge, a fountain and palms, a vertical blade sign (CIELO)
##   * a low pink-and-white block with a glass curtain wall; behind it a twelve-storey slab with ribbon windows and a rooftop sign
##   * the lobby (reception, a bar, sofas) and a mezzanine office over it for the manager, Lenny Vance
##   * a double-height gaming floor under a ring of neon: three roulette wheels around the pit, four blackjack tables, two craps
##     tables, a curtained baccarat salon, slot banks along both walls; the cage with its brass grille and its vault door
##   * out the back, the cabaret courtyard, the Salon Bajo las Estrellas: a stage, round tables, a dance floor, four concrete arches
##
## The interaction points (Buildings.Kit.interact) are what PilotApp opens: casino_roulette, casino_blackjack, casino_craps,
## casino_baccarat, casino_slots (a table screen: CasinoMenu), casino_cage and casino_office (the manager's dialogue). When the
## house is dark (not built, closed, uprising, seized) `set_open(false)` puts the lights out and boards the door.
##
## The island has no ground of its own for the walker (the world's height field stops at the mainland's edge), so `ground()` lays
## one over the strip and the casino: the island's own heights, one collider.
##
## Behind ENABLED; a session with no island never builds it.

static var ENABLED := true

const ALONG := 150.0  ## from the strip's centre, along the runway
const ACROSS := 75.0  ## from its centreline, to the right: the building's front
const W := 68.0  ## the block's width, along the runway
const D := 46.0  ## its depth
const H := 8.0  ## the gaming floor's ceiling
const FLOOR := 0.15  ## the terrazzo's top, above the ground
const TOWER_FLOORS := 11
const FLOOR_H := 3.3
const GROUND_CELL := 5.0
const GAMES := ["roulette", "blackjack", "craps", "baccarat", "slots"]


## Where the front-centre of the building stands, in game metres: {x, y, yaw} (yaw as Node3D.rotation.y; local -z faces the runway).
static func site() -> Dictionary:
	return SiteLayout.hotel_anchor()


static func build(world: World) -> Node3D:
	var root := Node3D.new()
	root.name = "casino"
	if not ENABLED or not Island.ENABLED:
		return root
	var k := Buildings.Kit.new("hotel-cielo")
	_people = []
	_forecourt(k)
	_shell(k)
	_tower(k)
	_lobby(k)
	_mezzanine(k)
	_gaming_floor(k)
	_cage(k)
	_salon(k)
	_patio(k)
	var node := k.finish()
	var at := site()
	node.position = Vector3(at.x, world.ground(at.x, at.y), -at.y)
	node.rotation.y = at.yaw
	node.name = "hotel-cielo"
	node.add_child(_boards())
	node.add_child(CasinoCrowd.make(_people, 1959))
	_signs(node)
	root.add_child(node)
	return root


## The walker's ground on the island: the strip, the apron and the casino, as one height field of the island's heights.
static func ground(world: World) -> StaticBody3D:
	var af := Island.airfield()
	var x0 := af.x - af.length / 2 - 150.0
	var x1 := af.x + af.length / 2 + 150.0
	var y0 := af.y - 420.0
	var y1 := af.y + 220.0
	var nx := int((x1 - x0) / GROUND_CELL) + 1
	var nz := int((y1 - y0) / GROUND_CELL) + 1
	var data := PackedFloat32Array()
	data.resize(nx * nz)
	for r in nz:
		var y := y1 - r * GROUND_CELL  # rows run along +z, south in game terms
		for c in nx:
			data[r * nx + c] = world.ground(x0 + c * GROUND_CELL, y)
	var shape := HeightMapShape3D.new()
	shape.map_width = nx
	shape.map_depth = nz
	shape.map_data = data
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(GROUND_CELL, 1.0, GROUND_CELL)
	var body := StaticBody3D.new()
	body.name = "island-ground"
	body.add_child(cs)
	body.position = Vector3((x0 + x1) / 2.0, 0.0, -(y0 + y1) / 2.0)
	return body


## A point of the hotel (x across, y up, z deep in its own frame) in world metres, for the sound and the tests.
static func world_point(world: World, lx: float, ly: float, lz: float) -> Vector3:
	var at := site()
	var xf := Transform3D(Basis(Vector3.UP, float(at.yaw)), Vector3(at.x, world.ground(at.x, at.y), -at.y))
	return xf * Vector3(lx, ly, lz)


## Lit and open, or dark and boarded.
static func set_open(node: Node3D, open: bool) -> void:
	if node == null:
		return
	for l in node.find_children("*", "OmniLight3D", true, false):
		l.visible = open
	for t in node.find_children("*", "Label3D", true, false):
		t.visible = open
	var crowd := node.find_child("crowd", true, false)
	if crowd != null:
		crowd.visible = open
		crowd.set_process(open)
	var boards := node.find_child("boards", true, false)
	if boards != null:
		boards.visible = not open
		for cs in boards.find_children("*", "CollisionShape3D", true, false):
			cs.set_deferred("disabled", open)


# ------------------------------------------------------------------ helpers
## A member of staff at a post (the dealers, the cashiers, the bartender, the band): recorded here, drawn and animated by CasinoCrowd.
static var _people: Array = []


static func _figure(_k: Buildings.Kit, x: float, y: float, z: float, coat := "black") -> void:
	_people.append([x, y, z, coat])


static func _stool(k: Buildings.Kit, x: float, z: float) -> void:
	k.cylinder(Vector3(x, FLOOR, z), 0.2, 0.6, "red", 8, false)


static func _palm(k: Buildings.Kit, x: float, z: float) -> void:
	k.cylinder(Vector3(x, 0.0, z), 0.22, 6.5, "wood", 6, false)
	k.cylinder(Vector3(x, 6.4, z), 2.4, 0.15, "green", 8, false)


## A felt table of boxes: the felt on a wooden rail, dealer side to +z, with the dealer, the stools and the interaction point.
static func _table(k: Buildings.Kit, x: float, z: float, size: Vector3, action: String, label: String, stools := 3) -> void:
	k.box(Vector3(x, FLOOR + size.y / 2, z), size, "mahogany")
	k.box(Vector3(x, FLOOR + size.y + 0.015, z), Vector3(size.x - 0.2, 0.03, size.z - 0.2), "felt", false)
	_figure(k, x, FLOOR, z + size.z / 2 + 0.55)
	for i in stools:
		_stool(k, x + (i - (stools - 1) / 2.0) * 0.95, z - size.z / 2 - 0.55)
	k.interact(Vector3(x, 1.2, z - size.z / 2 - 0.4), action, label, 2.2)


# ------------------------------------------------------------------ outside
static func _forecourt(k: Buildings.Kit) -> void:
	k.box(Vector3(0, 0.05, 20), Vector3(104, 0.1, 112), "concrete")  # the pavement, front, sides and the courtyard behind
	k.box(Vector3(0, 0.07, -24), Vector3(46, 0.04, 16), "asphalt", false)  # the drive
	# the porte-cochere: a flat plate on four slim columns, its edge a neon strip
	k.box(Vector3(0, 5.2, -8), Vector3(26, 0.35, 16), "white")
	k.box(Vector3(0, 4.95, -16.1), Vector3(26, 0.16, 0.1), "neon_cyan", false)
	for cx in [-11.0, 11.0]:
		for cz in [-3.0, -14.0]:
			k.cylinder(Vector3(cx, 0.0, cz), 0.25, 5.2, "metal", 8)
	k.lamp(Vector3(0, 4.6, -8), 1.6, 16.0)
	# a round fountain and the palms
	k.cylinder(Vector3(-24, 0.0, -14), 4.5, 0.5, "concrete", 16)
	k.cylinder(Vector3(-24, 0.4, -14), 4.0, 0.12, "water", 16, false)
	k.cylinder(Vector3(-24, 0.4, -14), 0.5, 2.2, "white", 8)
	for p in [[-36.0, -6.0], [36.0, -6.0], [-36.0, -20.0], [36.0, -20.0], [-18.0, -2.5], [18.0, -2.5], [-40.0, 30.0], [40.0, 30.0]]:
		_palm(k, p[0], p[1])
	# a doorman's rope and the guests' car at the kerb
	k.box(Vector3(14, 0.7, -22), Vector3(4.6, 1.4, 2.0), "black")
	k.box(Vector3(14, 1.6, -22), Vector3(2.6, 0.6, 1.9), "glass", false)


## The vertical blade sign, the rooftop sign and the neon along the roof line (labels go dark with the house).
static func _signs(node: Node3D) -> void:
	var blade := _label("C\nI\nE\nL\nO", 260, Color(1.0, 0.3, 0.7))
	blade.position = Vector3(-31.0, 10.0, -12.0)
	blade.rotation.y = PI
	node.add_child(blade)
	var roof := _label("HOTEL CIELO", 560, Color(1.0, 0.85, 0.4))
	roof.position = Vector3(0, H + TOWER_FLOORS * FLOOR_H + 3.8, 21.0)
	roof.rotation.y = PI
	node.add_child(roof)
	var door := _label("CASINO", 300, Color(0.3, 0.95, 1.0))
	door.position = Vector3(0, 5.7, -16.3)
	door.rotation.y = PI
	node.add_child(door)
	var cage := _label("CAJA   -   CAGE", 150, Color(1.0, 0.85, 0.5))
	cage.position = Vector3(0, 4.4, 39.1)
	cage.rotation.y = PI
	node.add_child(cage)
	var show := _label("SALON BAJO LAS ESTRELLAS", 110, Color(1.0, 0.5, 0.8))
	show.position = Vector3(26, 6.0, 74.8)
	show.rotation.y = PI
	node.add_child(show)


static func _label(text: String, size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color(0.05, 0.02, 0.05)
	l.shaded = false
	l.double_sided = true
	l.no_depth_test = false
	return l


## The planks across the door when the house is shut.
static func _boards() -> Node3D:
	var n := Node3D.new()
	n.name = "boards"
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(9.0, 4.5, 0.3)
	cs.shape = bs
	body.add_child(cs)
	n.add_child(body)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(9.0, 4.5, 0.3)
	mi.mesh = bm
	mi.material_override = Buildings.mat("wood")
	n.add_child(mi)
	n.position = Vector3(0, 2.4, -0.1)
	n.visible = false
	return n


# ------------------------------------------------------------------ the block
static func _shell(k: Buildings.Kit) -> void:
	k.box(Vector3(0, FLOOR / 2, D / 2), Vector3(W, FLOOR, D), "white")  # the terrazzo
	k.box(Vector3(0, H + 0.2, D / 2), Vector3(W + 1.6, 0.4, D + 1.6), "concrete_dark")  # the roof slab
	# the front: a sill, a glass curtain wall on slim mullions, two piers, and the doorway under a header
	k.wall(-W / 2, 0, -W / 2 + 3, 0, 0, H, 0.5, "white")
	k.wall(W / 2 - 3, 0, W / 2, 0, 0, H, 0.5, "white")
	k.box(Vector3(0, 4.5 + (H - 4.5) / 2, 0), Vector3(9.0, H - 4.5, 0.5), "white")
	for side in [-1.0, 1.0]:
		var x0 := 4.5
		var x1 := W / 2 - 3
		var cx: float = side * (x0 + x1) / 2
		var w := x1 - x0
		k.box(Vector3(cx, 0.45, 0), Vector3(w, 0.9, 0.5), "white")
		k.box(Vector3(cx, 0.9 + (H - 1.9) / 2, 0), Vector3(w, H - 1.9, 0.12), "glass")
		k.box(Vector3(cx, H - 0.5, 0), Vector3(w, 1.0, 0.5), "white")
		for i in 7:
			k.box(Vector3(side * (x0 + (i + 0.5) * w / 7), H / 2, -0.1), Vector3(0.12, H, 0.2), "metal", false)
	# the sides and the back
	for sx in [-1.0, 1.0]:
		k.wall(sx * W / 2, 0, sx * W / 2, D, 0, H, 0.4, "stucco_pink")
		k.box(Vector3(sx * (W / 2 + 0.22), 6.6, D / 2), Vector3(0.08, 0.9, D - 4), "window_lit", false)
	k.wall(-W / 2, D, -18, D, 0, H, 0.4, "stucco_pink", 5.0, 4.0)  # the door to the courtyard at x = -26
	k.wall(-18, D, W / 2, D, 0, H, 0.4, "stucco_pink")
	# the ring of neon in the ceiling over the floor, and the chandelier lamps
	k.cylinder(Vector3(0, H - 0.3, 27), 12.4, 0.45, "neon", 28, false)  # (a cylinder has a top cap and no bottom: its cap is buried in the roof slab)
	for p in [[0.0, 27.0, 2.2], [-14.0, 20.0, 2.6], [14.0, 20.0, 2.6], [-14.0, 34.0, 2.6], [14.0, 34.0, 2.6], [0.0, 14.0, 2.4], [-22.0, 28.0, 2.4], [0.0, 6.0, 2.4], [-22.0, 6.0, 2.0], [22.0, 6.0, 2.0]]:
		k.lamp(Vector3(p[0], H - 1.2, p[1]), p[2], 19.0)


## The slab behind the block: eleven floors of ribbon windows, a penthouse and a standing sign.
static func _tower(k: Buildings.Kit) -> void:
	var top := H + 0.4 + TOWER_FLOORS * FLOOR_H
	k.box(Vector3(0, H + 0.4 + TOWER_FLOORS * FLOOR_H / 2, 29), Vector3(56, TOWER_FLOORS * FLOOR_H, 14), "stucco")
	for f in TOWER_FLOORS:
		var y := H + 0.4 + 1.5 + f * FLOOR_H
		for z in [22 - 0.06, 36 + 0.06]:
			k.box(Vector3(0, y, z), Vector3(52, 1.1, 0.12), "window_lit", false)
		k.box(Vector3(0, H + 0.4 + f * FLOOR_H, 21.6), Vector3(56, 0.2, 0.8), "concrete_dark", false)  # the floor edge, a shade
	k.box(Vector3(0, top + 2.0, 29), Vector3(24, 4.0, 10), "stucco_pink")  # the penthouse
	k.box(Vector3(0, top + 3.4, 21.3), Vector3(34, 5.2, 0.3), "black", false)  # the sign's backing
	k.box(Vector3(0, top + 6.1, 21.3), Vector3(34, 0.2, 0.2), "neon", false)
	k.box(Vector3(0, top + 0.8, 21.3), Vector3(34, 0.2, 0.2), "neon", false)


# ------------------------------------------------------------------ the lobby
static func _lobby(k: Buildings.Kit) -> void:
	# the screen between the lobby and the floor, with a wide arch of an opening
	k.wall(-W / 2, 11.0, W / 2, 11.0, 0, H, 0.4, "white", 16.0, 4.5)
	for cx in [-12.0, 12.0]:
		k.cylinder(Vector3(cx, FLOOR, 10.0), 0.4, H, "white", 10)
	# reception, to the west under the mezzanine's shadow, and the bar to the east
	k.box(Vector3(-24, FLOOR + 0.55, 2.0), Vector3(8.0, 1.1, 1.2), "wood")
	k.box(Vector3(-24, FLOOR + 1.12, 2.0), Vector3(8.0, 0.05, 1.3), "black", false)
	_figure(k, -26.0, FLOOR, 0.9, "blue")
	k.box(Vector3(24, FLOOR + 0.55, 5.5), Vector3(1.2, 1.1, 9.0), "wood")
	k.box(Vector3(33.4, 2.0, 5.5), Vector3(0.5, 2.6, 9.0), "wood")  # the back bar and its bottles
	for i in 9:
		k.box(Vector3(33.1, 3.4, 1.4 + i * 0.9), Vector3(0.2, 0.5, 0.2), ["orange", "green", "red", "neon_cyan"][i % 4], false)
	_figure(k, 25.4, FLOOR, 5.5, "white")
	for i in 5:
		k.prop("stoolBar", Vector3(22.4, FLOOR, 2.0 + i * 1.7), 0.0)
	# the sofas, the palms and the lamps
	k.prop("loungeDesignSofa", Vector3(-4.0, FLOOR, 7.5), 0.0)
	k.prop("loungeDesignSofa", Vector3(5.0, FLOOR, 7.5), 0.0)
	k.prop("tableCoffeeGlass", Vector3(0.5, FLOOR, 7.5), 0.0)
	for p in [[-30.0, 9.0], [30.0, 9.0], [-9.0, 1.5], [9.0, 1.5]]:
		k.prop("pottedPlant", Vector3(p[0], FLOOR, p[1]), 0.0)


## The manager's office over the lobby: glass onto the floor, a desk, a safe, stairs up from the lobby.
static func _mezzanine(k: Buildings.Kit) -> void:
	var top := 4.2
	k.box(Vector3(-21, top - 0.15, 5.3), Vector3(26, 0.3, 10.6), "concrete_dark")
	k.box(Vector3(-21, top + 2.0, 10.7), Vector3(26, 3.8, 0.1), "glass")  # onto the gaming floor
	k.box(Vector3(-8.1, top + 0.5, 3.5), Vector3(0.1, 1.0, 7.0), "metal")  # the rail on the stair side
	for i in 14:  # the stairs, up to the west along the front of the lobby
		k.box(Vector3(-4.0 - i * 0.5, FLOOR + i * 0.3, 8.6), Vector3(0.5, 0.3, 2.4), "concrete_dark")
	var desk := k.prop("desk", Vector3(-26, top, 4.0), 180.0)
	k.prop("chairDesk", Vector3(-26, top, 5.3), 0.0)
	k.prop("computerScreen", Vector3(-26.4, desk.end.y, 4.1), 180.0, 2.4, false)
	k.prop("bookcaseClosedWide", Vector3(-21, top, 0.6), 0.0)
	k.box(Vector3(-32.4, top + 0.55, 8.5), Vector3(1.1, 1.1, 1.1), "metal")  # the safe
	k.prop("loungeDesignSofa", Vector3(-14.5, top, 6.5), 90.0)
	k.lamp(Vector3(-21, top + 3.2, 5.3), 1.4, 11.0)
	k.interact(Vector3(-26, top + 1.0, 6.0), "casino_office", "Lenny Vance, the manager: the house's books", 2.4)


# ------------------------------------------------------------------ the floor
static func _gaming_floor(k: Buildings.Kit) -> void:
	k.cylinder(Vector3(0, FLOOR, 27.0), 15.5, 0.02, "carpet", 28, false)  # the carpet
	k.cylinder(Vector3(0, FLOOR, 27.0), 1.7, 1.0, "wood", 12)  # the pit
	_figure(k, 0.0, FLOOR + 1.0, 27.0, "white")
	# three roulette wheels around the pit
	for p in [[-7.5, 21.0], [7.5, 21.0], [0.0, 33.0]]:
		_table(k, p[0], p[1], Vector3(3.2, 0.92, 1.5), "casino_roulette", "Roulette: single zero, 35 to 1")
		k.cylinder(Vector3(p[0] + 2.0, FLOOR + 0.9, p[1]), 0.6, 0.14, "wood", 12, false)
	# four blackjack tables in the east wing
	for p in [[14.0, 16.0], [24.0, 16.0], [14.0, 24.0], [24.0, 24.0]]:
		_table(k, p[0], p[1], Vector3(2.8, 0.92, 1.3), "casino_blackjack", "Blackjack: three to two", 3)
	# two craps tables in the west wing, each with a stickman and a rail
	for z in [18.0, 30.0]:
		_table(k, -22.0, z, Vector3(4.0, 0.95, 1.7), "casino_craps", "Craps: pass, don't pass, free odds", 4)
		k.box(Vector3(-22.0, FLOOR + 1.02, z - 0.85), Vector3(4.2, 0.1, 0.12), "wood", false)
		k.box(Vector3(-22.0, FLOOR + 1.02, z + 0.85), Vector3(4.2, 0.1, 0.12), "wood", false)
	# the slot banks along both walls, the machines facing the room
	for bank in [[-1.0, 13.0], [-1.0, 22.0], [-1.0, 31.0], [1.0, 13.0], [1.0, 22.0]]:
		_slot_bank(k, bank[0], bank[1])
	for lp in [[-18.0, 26.0], [18.0, 33.0]]:
		k.lamp(Vector3(lp[0], 3.5, lp[1]), 1.1, 9.0)


static func _slot_bank(k: Buildings.Kit, side: float, z0: float) -> void:
	var x := side * (W / 2 - 0.8)
	for i in 8:
		var z := z0 + i * 0.95
		k.box(Vector3(x, FLOOR + 0.85, z), Vector3(0.7, 1.7, 0.8), "red")
		k.box(Vector3(x - side * 0.36, FLOOR + 1.25, z), Vector3(0.04, 0.5, 0.5), "window_lit", false)
		k.box(Vector3(x - side * 0.36, FLOOR + 0.8, z), Vector3(0.1, 0.05, 0.6), "metal", false)
		k.box(Vector3(x, FLOOR + 1.78, z), Vector3(0.7, 0.14, 0.8), "neon", false)
	k.interact(Vector3(x - side * 1.0, 1.3, z0 + 3.4), "casino_slots", "The slot machines: three reels, 450 for sevens", 2.6)


## The cage: a counter behind a brass grille, the cashiers, the vault door in the wall behind.
static func _cage(k: Buildings.Kit) -> void:
	k.box(Vector3(0, FLOOR + 0.55, 39.4), Vector3(16, 1.1, 0.8), "wood")
	for i in 21:
		k.box(Vector3(-8 + i * 0.8, FLOOR + 2.0, 39.7), Vector3(0.04, 1.8, 0.04), "brass", false)
	k.box(Vector3(0, FLOOR + 2.95, 39.7), Vector3(16, 0.12, 0.12), "brass", false)
	k.wall(-10, 40.6, 10, 40.6, 0, H, 0.3, "stucco_pink")
	k.wall(-10, 40.6, -10, 46, 0, H, 0.3, "stucco_pink")
	k.wall(10, 40.6, 10, 46, 0, H, 0.3, "stucco_pink")
	for cx in [-4.0, 0.0, 4.0]:
		_figure(k, cx, FLOOR, 40.1, "white")
	k.box(Vector3(6.0, FLOOR + 1.45, 40.3), Vector3(2.4, 2.6, 0.3), "metal", false)  # the vault door, its wheel
	k.box(Vector3(6.0, FLOOR + 1.45, 40.1), Vector3(0.9, 0.12, 0.1), "black", false)
	k.box(Vector3(6.0, FLOOR + 1.45, 40.1), Vector3(0.12, 0.9, 0.1), "black", false)
	k.lamp(Vector3(0, 3.6, 38.0), 1.4, 9.0)
	k.interact(Vector3(0, 1.4, 38.3), "casino_cage", "The cage: cash, chips and the Family's account", 2.6)


## The baccarat salon: a low panelled enclosure in the north-east corner with a red carpet and one big table.
static func _salon(k: Buildings.Kit) -> void:
	k.box(Vector3(24.5, FLOOR + 0.01, 34.6), Vector3(18.0, 0.03, 9.6), "carpet", false)
	k.wall(15.0, 29.4, 34.0, 29.4, 0, 1.4, 0.2, "wood", 3.5, 2.4)
	k.wall(15.0, 29.4, 15.0, 39.6, 0, 1.4, 0.2, "wood")
	k.wall(15.0, 39.6, 34.0, 39.6, 0, 1.4, 0.2, "wood")
	k.cylinder(Vector3(24.5, FLOOR, 34.6), 2.2, 0.9, "mahogany", 16)
	k.cylinder(Vector3(24.5, FLOOR + 0.9, 34.6), 1.9, 0.06, "felt", 16, false)
	_figure(k, 24.5, FLOOR, 36.7)
	for i in 5:
		_stool(k, 24.5 + 2.7 * cos(PI * (0.18 + i * 0.16) + PI), 34.6 + 2.7 * sin(PI * (0.18 + i * 0.16) + PI))
	k.lamp(Vector3(24.5, 3.4, 34.6), 1.6, 8.0)
	k.interact(Vector3(24.5, 1.3, 32.2), "casino_baccarat", "Baccarat: punto banco, the high table", 2.4)


## The Salon Bajo las Estrellas: an open-air cabaret behind the casino.
static func _patio(k: Buildings.Kit) -> void:
	k.box(Vector3(0, 0.11, 61.0), Vector3(W, 0.12, 30.0), "stucco")  # the courtyard floor
	k.wall(-W / 2, 76.0, W / 2, 76.0, 0, 3.8, 0.4, "stucco_pink")
	k.wall(-W / 2, D, -W / 2, 76.0, 0, 3.8, 0.4, "stucco_pink")
	k.wall(W / 2, D, W / 2, 76.0, 0, 3.8, 0.4, "stucco_pink")
	# the stage, its proscenium and the dance floor
	k.box(Vector3(26.0, 0.55, 69.0), Vector3(16.0, 0.9, 12.0), "wood")
	k.box(Vector3(26.0, 4.2, 75.4), Vector3(16.0, 5.6, 0.3), "black", false)
	k.box(Vector3(26.0, 7.1, 75.1), Vector3(17.0, 0.25, 0.25), "neon", false)
	k.box(Vector3(18.0, 4.2, 75.1), Vector3(0.25, 5.6, 0.25), "neon", false)
	k.box(Vector3(34.0, 4.2, 75.1), Vector3(0.25, 5.6, 0.25), "neon", false)
	k.box(Vector3(-6.0, 0.2, 62.0), Vector3(16.0, 0.05, 14.0), "white", false)
	for p in [[22.0, 69.0], [26.0, 69.0], [30.0, 69.0]]:
		_figure(k, p[0], 1.0, p[1] + 1.0, "red")
	# round tables with a candle, in three rows facing the stage
	for row in 3:
		for col in 5:
			var tx := -30.0 + col * 9.0 + (4.5 if row == 1 else 0.0)
			var tz := 52.0 + row * 7.5
			if tx > 6.0 and tx < 18.0 and tz > 56.0:
				continue  # keep the dance floor's edge and the stage's steps clear
			k.cylinder(Vector3(tx, 0.0, tz), 0.55, 0.78, "white", 10)
			k.box(Vector3(tx, 0.82, tz), Vector3(0.08, 0.12, 0.08), "orange", false)
			k.cylinder(Vector3(tx - 0.95, 0.0, tz), 0.2, 0.5, "red", 8, false)
			k.cylinder(Vector3(tx + 0.95, 0.0, tz), 0.2, 0.5, "red", 8, false)
	# four concrete arches over the courtyard, the Tropicana's own idea
	for az in [50.0, 58.0, 66.0, 74.0]:
		k.arch(Vector3(0, 0.0, az), 24.0, 0.7, "white", 20)
	for lp in [[-20.0, 60.0], [0.0, 60.0], [20.0, 60.0], [26.0, 70.0]]:
		k.lamp(Vector3(lp[0], 5.0, lp[1]), 1.3, 14.0)
	_palm(k, -32.0, 48.0)
	_palm(k, 32.0, 48.0)
	_palm(k, -32.0, 72.0)
