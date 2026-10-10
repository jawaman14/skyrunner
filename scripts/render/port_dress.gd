class_name PortDress
extends RefCounted
## The docks of San Telmo from Kenney's Pirate Kit (CC0, assets/models/kenney/pirate): wooden piers running out into
## the harbour basin from the quay, crates and barrels stacked at the foot of each, and boats moored alongside.
## Placed from the map alone (a hash of the pier's number, no random stream), so it is the same every time.
##
## Scenery only: nothing here is solid, and the sea stops the walker anyway. Behind ENABLED; a missing kit draws
## nothing and the quay is as bare as it was.

static var ENABLED := true

const KIT := "pirate/"
const TILE_M := 6.0  ## a pier tile (the kit's 2.5 m deck square, scaled)
const PIER_LEN := 6  ## tiles
const PIER_EVERY_M := 170.0
const DECK_Y := 0.0  ## where a tile's base sits against the water (m)
const CRATES := ["crate", "barrel", "crate-bottles", "barrel", "chest"]
const MOORED := ["boat-row-large", "boat-row-small", "ship-small"]


static func _roll(i: int, salt: int) -> float:
	var h := (i * 73856093) ^ (salt * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h ^ (h >> 16)) % 100000) / 100000.0


## The y of the quay's edge at `x`: the first sea cell going south from the quay road.
static func shore_y(world: World, x: float) -> float:
	var y := MapCity.COAST_Y + 120.0
	while y > MapCity.COAST_Y - 200.0:
		if world.ground(x, y) < 0.3:
			return y
		y -= 2.0
	return MapCity.COAST_Y


## The piers' positions: [[x, y_shore], ...], from the map's harbour, west to east.
static func piers(world: World) -> Array:
	return SiteLayout.dock_sites(world)


static func build(world: World, q: Quality) -> Node3D:
	var root := Node3D.new()
	root.name = "port_dress"
	if not ENABLED or not q.shaded or world.map.map_seed != MapCity.SEED:
		return root
	var s := TILE_M / 2.5
	var dressed := false
	for p in piers(world):
		var x: float = p[0]
		var y: float = p[1]
		var n: int = p[2]
		if not dressed:
			var equipment := Buildings.Kit.new("coastal-mooring")
			var equipment_x := x + TILE_M * 0.5 - 0.5
			var equipment_y := y + 8.0
			Buildings.mooring_set(equipment, Vector3(equipment_x, world.ground(equipment_x, equipment_y), -equipment_y))
			root.add_child(equipment.finish())
			dressed = true
		# the pier: tiles running south from the quay
		for t in PIER_LEN:
			var tile := ModelLib.wrapped(KIT + "structure-platform-dock", s, 0.0)
			if tile == null:
				return root
			tile.position = Vector3(x, DECK_Y, -(y + 4.0 - t * TILE_M))
			root.add_child(tile)
		# crates and barrels on the quay at the pier's foot
		var cnt := 3 + int(_roll(n, 1) * 3.0)
		for k in cnt:
			var name: String = CRATES[int(_roll(n * 11 + k, 2) * CRATES.size())]
			var m := ModelLib.wrapped(KIT + name, 1.9 + 0.7 * _roll(n * 11 + k, 3), TAU * _roll(n * 11 + k, 4))
			if m == null:
				continue
			var px := x + (_roll(n * 11 + k, 5) - 0.5) * 16.0
			var py := y + 8.0 + _roll(n * 11 + k, 6) * 9.0
			m.position = Vector3(px, world.ground(px, py), -py)
			root.add_child(m)
		# a boat alongside
		var boat: String = MOORED[int(_roll(n, 7) * MOORED.size())]
		var bs := 1.6 if boat != "ship-small" else 1.0
		var b := ModelLib.wrapped(KIT + boat, bs, PI * 0.5 * _roll(n, 8))
		if b != null:
			var side := 1.0 if _roll(n, 9) < 0.5 else -1.0
			b.position = Vector3(x + side * (TILE_M * 0.5 + 5.0), DECK_Y - 0.1, -(y - 10.0 - _roll(n, 10) * 18.0))
			root.add_child(b)
	return root
