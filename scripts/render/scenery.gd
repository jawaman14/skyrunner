class_name Scenery
extends RefCounted
## Rocks, bushes and beach palms from Kenney's Nature Kit (assets/models/kenney/nature) scattered over the
## island on top of the terrain's own trees: boulders on steep ground and rocky land and a few on the beaches,
## bushes in the scrub and jungle (and on open ground where the map has no land-use), detailed palms along the
## sand. A 120 m grid with a jittered point per cell, rolled from a hash of the cell so it is the same every
## time and costs no RNG stream; nothing on the airfields, in town, on the roads, or in the sea.
##
## Drawn in 1 km chunks, one MultiMesh per model per chunk, each with a visibility range (rocks far, bushes
## near). Behind ENABLED; off on low quality; a missing kit draws nothing.

static var ENABLED := true

const CELL_M := 120.0
const CHUNK_M := 1000.0
const KIT := "res://assets/models/kenney/nature/%s.glb"
## part -> models, the heights it is scaled to (m), the distance it is drawn to (m)
const PARTS := {
	"boulder": {"models": ["rock_largeA", "rock_largeB", "rock_largeC", "rock_largeD", "rock_largeE", "rock_largeF"], "h": [3.0, 7.0], "range": 1800.0},
	"crag": {"models": ["rock_tallA", "rock_tallB", "rock_tallC", "rock_tallD", "rock_tallE", "rock_tallF", "rock_tallG"], "h": [3.5, 8.0], "range": 1800.0},
	"rock": {"models": ["rock_smallA", "rock_smallB", "rock_smallC", "rock_smallD", "rock_smallE", "rock_smallF", "rock_smallG", "rock_smallH", "rock_smallI"],
		"h": [0.7, 1.7], "range": 600.0},
	"bush": {"models": ["plant_bush", "plant_bushLarge", "plant_bushDetailed", "plant_bushTriangle", "plant_bushLargeTriangle", "plant_bushSmall"],
		"h": [1.0, 2.2], "range": 700.0},
	"palm": {"models": ["tree_palmDetailedTall", "tree_palmDetailedShort"], "h": [8.0, 13.0], "range": 1600.0},
}

static var _meshes := {}  ## model -> {mesh, aabb} (null when the kit lacks it)
static var _stone: StandardMaterial3D


## The kit paints its rocks in the palette of its palms (peach, with a blue-green cap); stone is grey-brown.
static func stone() -> StandardMaterial3D:
	if _stone == null:
		_stone = StandardMaterial3D.new()
		_stone.albedo_color = Color(0.5, 0.47, 0.43)
		_stone.roughness = 0.95
	return _stone


static func _mesh(model: String) -> Variant:
	if _meshes.has(model):
		return _meshes[model]
	var out = null
	var path := KIT % model
	if ResourceLoader.exists(path):
		var m: Node3D = (load(path) as PackedScene).instantiate()
		var mesh := ModelLib.merged_mesh(m)
		if mesh != null:
			out = {"mesh": mesh, "aabb": ModelLib.bounds(m)}
		m.free()
	_meshes[model] = out
	return out


## A number in [0, 1) from a cell and a salt: the same every time.
static func _roll(ix: int, iy: int, salt: int) -> float:
	var h := (ix * 73856093) ^ (iy * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h ^ (h >> 16)) % 100000) / 100000.0


## Everything to place: [{part, model, xf}], deterministic. \`world\` supplies the terrain, the land use
## (when the map has one), the roads and the airfields.
static func scatter(world: World) -> Array:
	var out := []
	var lu: PackedByteArray = world.map.land_use
	var has_lu := not lu.is_empty()
	var roads: Array = world.map.roads
	var n := int(World.SIZE_M / CELL_M)
	for ix in n:
		for iy in n:
			var x := -World.HALF + (ix + _roll(ix, iy, 1)) * CELL_M
			var y := -World.HALF + (iy + _roll(ix, iy, 2)) * CELL_M
			var h := world.height(x, y)
			if h < 0.3:
				continue
			var cls := MapCity.at(lu, x, y) if has_lu else -1
			if cls in [MapCity.URBAN, MapCity.PORT, MapCity.ROAD, MapCity.SEA]:
				continue
			var d := 8.0
			var slope := maxf(absf(world.height(x + d, y) - h), absf(world.height(x, y + d) - h)) / d
			var r := _roll(ix, iy, 3)
			var part := ""
			if (slope > 0.38 and r < 0.2) or (cls == MapCity.ROCK and r < 0.3) or (cls == MapCity.BEACH and h < 3.5 and r < 0.05):
				var k := _roll(ix, iy, 4)
				part = "crag" if k < 0.3 else ("boulder" if k < 0.65 or slope > 0.5 else "rock")
			elif cls == MapCity.BEACH and h < 4.5 and r > 0.88:
				part = "palm"
			elif has_lu and cls in [MapCity.JUNGLE, MapCity.SCRUB, MapCity.SWAMP, MapCity.MANGROVE, MapCity.GRASS] and slope < 0.4 and r > (0.86 if cls == MapCity.JUNGLE else 0.92):
				part = "bush"
			elif not has_lu and h > 3.0 and h < 400.0 and slope < 0.35 and r > 0.95:
				part = "bush"
			if part == "":
				continue
			if world.airfield_at(x, y, 150.0) != null:
				continue
			if not roads.is_empty() and MapCity.road_dist(roads, x, y) < 35.0:
				continue
			var spec: Dictionary = PARTS[part]
			var models: Array = spec.models
			var model: String = models[int(_roll(ix, iy, 5) * models.size()) % models.size()]
			var hr: Array = spec.h
			out.append({"part": part, "model": model, "x": x, "y": y, "h_m": lerpf(hr[0], hr[1], _roll(ix, iy, 6)), "yaw": _roll(ix, iy, 7) * TAU,
				"tilt": _roll(ix, iy, 8), "ground": world.ground(x, y)})
	return out


## The placements as a node: per chunk, one MultiMesh per model.
static func build(world: World, q: Quality) -> Node3D:
	var root := Node3D.new()
	root.name = "scenery"
	if not ENABLED or q.name == "low":
		return root
	var chunks := {}  # chunk -> model -> [xfs]
	for p in scatter(world):
		var m = _mesh(p.model)
		if m == null:
			continue
		var aabb: AABB = m.aabb
		var s: float = float(p.h_m) / maxf(0.01, aabb.size.y)
		var tilt := Vector3(lerpf(-0.08, 0.08, fmod(float(p.tilt) * 7.0, 1.0)), 0.0, lerpf(-0.08, 0.08, float(p.tilt))) if p.part != "palm" else Vector3.ZERO
		var basis := Basis.from_euler(Vector3(tilt.x, float(p.yaw), tilt.z)) * Basis.from_scale(Vector3(s, s, s))
		# stand the model's base centre on the ground, a little sunk (a rock sits in the earth)
		var base := Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z)
		var sink: float = 0.15 * float(p.h_m) if p.part != "palm" and p.part != "bush" else 0.0
		var origin := Vector3(p.x, float(p.ground) - sink, -float(p.y)) - basis * base
		var c := Vector2i(floori(float(p.x) / CHUNK_M), floori(float(p.y) / CHUNK_M))
		if not chunks.has(c):
			chunks[c] = {}
		if not chunks[c].has(p.model):
			chunks[c][p.model] = [PARTS[p.part].range, []]
		chunks[c][p.model][1].append(Transform3D(basis, origin))
	var shadows := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if q.shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in chunks:
		var node := Node3D.new()
		node.name = "chunk-%d-%d" % [c.x, c.y]
		for model in chunks[c]:
			var g: Array = chunks[c][model]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = (_mesh(model) as Dictionary).mesh
			mm.instance_count = g[1].size()
			for k in g[1].size():
				mm.set_instance_transform(k, g[1][k])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = model
			mmi.multimesh = mm
			if model.begins_with("rock_"):
				mmi.material_override = stone()
			mmi.cast_shadow = shadows if float(g[0]) > 1000.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = float(g[0])
			mmi.visibility_range_end_margin = 80.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			node.add_child(mmi)
		root.add_child(node)
	return root
