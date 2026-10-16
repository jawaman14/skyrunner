class_name AirfieldDress
extends RefCounted
## Props around each airfield, from Skyrunner's own low-poly models (assets/models/airfield, original art, see its
## README): the windsock, a beacon tower, a fuel bowser, a ground power cart, wheel chocks, tie-down anchors and
## blue taxi lights and white apron-edge lights. Every model is in the game's conventions (metres, origin at the base, facing -Z), so it is placed
## as it comes.
##
## Placed from the airfield alone (no random stream), so it is the same every time. Scenery only: nothing here is
## solid, lit or simulated. Behind ENABLED and ModelLib.ENABLED; a missing model draws nothing and the field is as
## bare as it was (`Models.build_airfield` keeps its procedural windsock whenever `has_windsock()` is false).

static var ENABLED := true

const ROOT := "res://assets/models/airfield/"
const WINDSOCK_BEHIND_M := 0.7  ## along the strip from the centre, as a share of half the length (matches the old pole)
const WINDSOCK_SIDE_M := 12.0  ## beyond the strip's edge

static var _cache := {}


static func scene(name: String) -> PackedScene:
	if not ENABLED or not ModelLib.ENABLED:
		return null
	if _cache.has(name):
		return _cache[name]
	var path := ROOT + name + ".glb"
	var ps: PackedScene = load(path) if ResourceLoader.exists(path) else null
	_cache[name] = ps
	return ps


## True when the windsock model will be drawn, so the old procedural pole is not drawn as well.
static func has_windsock() -> bool:
	return scene("windsock") != null


## Where the windsock stands, in map coordinates [x, y]: beside the strip, back from the centre.
static func windsock_spot(af: Airfield) -> Array:
	var a := -af.length / 2.0 * WINDSOCK_BEHIND_M
	var c := -af.width / 2.0 - WINDSOCK_SIDE_M
	return [af.x + af.ux * a + af.uy * c, af.y + af.uy * a - af.ux * c]


## The props placed in the site frame (x along the strip, z across, -z toward the runway): [[model, x, z, yaw], ...].
static func apron_layout(af: Airfield) -> Array:
	var out := []
	match af.kind:
		"hub":
			out.append(["fuel_bowser", 21.0, -9.0, PI / 2.0])
			out.append(["ground_power_cart", -38.0, -3.0, 0.0])
			out.append(["beacon_tower", -92.0, 4.0, 0.0])
			for i in 8:
				out.append(["tie_down_anchor", -60.0 + 12.0 * i, -24.0, 0.0])
			for x in [-48.0, -24.0, 0.0]:
				out.append(["wheel_chocks", x, -20.0, 0.0])
			for i in 12:
				out.append(["runway_edge_light_blue", -70.0 + 10.0 * i, -30.0, 0.0])
			for i in 7:
				out.append(["runway_edge_light_white", -70.0 + 20.0 * i, -14.0, 0.0])
		"regional":
			out.append(["fuel_bowser", 17.0, -9.0, PI / 2.0])
			out.append(["ground_power_cart", -26.0, -3.0, 0.0])
			out.append(["beacon_tower", -50.0, 4.0, 0.0])
			for i in 5:
				out.append(["tie_down_anchor", -30.0 + 12.0 * i, -20.0, 0.0])
			for x in [-18.0, 6.0]:
				out.append(["wheel_chocks", x, -16.0, 0.0])
			for i in 8:
				out.append(["runway_edge_light_blue", -40.0 + 10.0 * i, -26.0, 0.0])
			for i in 5:
				out.append(["runway_edge_light_white", -30.0 + 15.0 * i, -10.0, 0.0])
		_:
			for x in [-6.0, 6.0]:
				out.append(["tie_down_anchor", x, -12.0, 0.0])
			out.append(["wheel_chocks", 0.0, -9.0, 0.0])
	return out


static func _model(name: String, at: Vector3, yaw: float) -> Node3D:
	var ps := scene(name)
	if ps == null:
		return null
	var m: Node3D = ps.instantiate()
	m.name = name
	m.position = at
	m.rotation.y = yaw
	return m


static func build(world: World, af: Airfield, q: Quality) -> Node3D:
	var root := Node3D.new()
	root.name = "airfield_dress-" + af.code
	if not ENABLED or not ModelLib.ENABLED:
		return root
	# the windsock streams along the strip (static: it does not follow the weather)
	var spot := windsock_spot(af)
	var ws := _model("windsock", Vector3(spot[0], world.airfield_elev(af) + 0.12, -spot[1]), atan2(-af.ux, af.uy))
	if ws == null:
		return root
	root.add_child(ws)
	if not q.shaded:
		return root
	var apron := Node3D.new()
	apron.name = "apron"
	apron.transform = SiteLayout.airfield_frame(world, af)
	for item in apron_layout(af):
		var m := _model(item[0], Vector3(item[1], 0.0, item[2]), item[3])
		if m != null:
			apron.add_child(m)
	root.add_child(apron)
	return root
