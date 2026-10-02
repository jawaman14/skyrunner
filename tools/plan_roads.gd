extends SceneTree
## Plan the city map's road network and write it to res://data/maps/city_roads.json (RoadPlanner).
## Run after any change to the terrain, the strips or the stash houses, then re-bake nothing (roads are
## not part of the terrain) but re-run the tests and the balance:
##
##   godot --headless --path . --script res://tools/plan_roads.gd [-- --dry] [--out=PATH] [--rings=A:B,C:D]
##   (--dry: report only; --out: write somewhere else; --rings: try other ring links than RINGS)
##
## Prints, per road, its length, its steepest 40 m, the length over 8%, and each water crossing (a
## bridge), then whether every place is connected.

const WATER_M := 0.3  ## the ground is water below this
const RIVER_BRIDGE_M := 120.0  ## only the river's own channel may be bridged (not the lagoons round its mouth)
const STRIP_KEEP_OUT_M := 50.0  ## roads don't cross runways: wider than a grid step, so a route can't slip between nodes
const LOOPS := [["COV", "downtown"], ["VAL", "docks"], ["FRM", "MGR"]]  ## extra links beyond the tree

## Second ways between places that are already joined (RoadPlanner.detour_route): a roadblock on the
## first road leaves a road round it. Place names as printed below.
const RINGS := [["downtown", "HAR"], ["downtown", "QRY"], ["customs", "farms"]]

var base: Terrain
var layout: MapLayout


func _initialize() -> void:
	var dry := "--dry" in OS.get_cmdline_user_args()
	var out_path := ProjectSettings.globalize_path(MapCity.ROADS_FILE)
	var ring_pairs: Array = RINGS.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
		elif a.begins_with("--rings="):
			ring_pairs = []
			for pr in a.trim_prefix("--rings=").split(",", false):
				ring_pairs.append(Array(pr.split(":")))
	World.use_map(MapCity.SEED)
	layout = MapCity.generate()
	base = MapCity.base_terrain()
	var names := []
	var pos := []
	names.append("downtown")
	pos.append(MapCity.ORG_AT)
	names.append("customs")
	pos.append(MapCity.LAW_AT)
	names.append("farms")
	pos.append(MapCity.FARM_C)
	for af in layout.airfields:
		if af.code == "ISL":
			continue  # a cay: reached by boat
		var off: float = af.width / 2.0 + 48.0
		names.append(af.code)
		pos.append(Vector2(af.x + af.uy * off, af.y - af.ux * off))
	for st in layout.stashes:
		if st.id == "boathouse":
			continue  # on a cay
		names.append(st.id)
		pos.append(Vector2(st.x, st.y))
	print("places: ", ", ".join(names))
	var planner := RoadPlanner.new(_height, _passable)
	var extra := []
	var rings := []
	for pair in ring_pairs:
		var ra := names.find(pair[0])
		var rb := names.find(pair[1])
		if ra >= 0 and rb >= 0:
			rings.append([ra, rb])
		else:
			print("ring link skipped, no such place: ", pair)
	for pair in LOOPS:
		var a := names.find(pair[0])
		var b := names.find(pair[1])
		if a >= 0 and b >= 0:
			extra.append([a, b])
	var t0 := Time.get_ticks_msec()
	var res := planner.plan(pos, extra, rings)
	print("planned %d roads in %.1f s" % [res.roads.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	for ri in res.roads.size():
		res.roads[ri] = RoadPlanner.straighten_bridges(res.roads[ri], _is_water)
	var bridges := []
	var total := 0.0
	var steep := 0.0
	var worst := 0.0
	var wet_total := 0.0
	for ri in res.roads.size():
		var m := RoadPlanner.measure(res.roads[ri], _h, _is_water)
		total += m.length
		steep += m.steep_m
		worst = maxf(worst, m.max_grade)
		var spans := []
		for w in m.water:
			bridges.append({"road": ri, "from": snappedf(w[0] - 15.0, 1.0), "to": snappedf(w[1] + 15.0, 1.0)})
			spans.append("%.0f m" % (w[1] - w[0]))
			wet_total += w[1] - w[0]
		print("  road %2d: %5.1f km, steepest 40 m %4.1f%%, >8%% for %4.0f m%s" % [ri, m.length / 1000.0, m.max_grade * 100.0, m.steep_m,
			("  bridge " + ", ".join(spans)) if not spans.is_empty() else ""])
	print("network: %.1f km, %.1f%% over 8%%, steepest %.1f%%, %d bridges (%.0f m of water)" % [total / 1000.0, steep / maxf(total, 1.0) * 100.0, worst * 100.0, bridges.size(), wet_total])
	for t in res.tracks:
		print("reached by a mountain track (up to %.0f%%): %s" % [RoadPlanner.TRACK_GRADE * 100.0, names[t]])
	for u in res.unreached:
		print("NOT CONNECTED: ", names[u])
	if not dry:
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"roads": res.roads, "bridges": bridges}))
		print("wrote ", out_path)
	quit()


func _h(x: float, y: float) -> float:
	return base.height64(x, y)


func _height(x: float, y: float) -> float:
	return maxf(base.height64(x, y), 0.0)  # a bridge deck runs level over the water


func _is_water(x: float, y: float) -> bool:
	return base.height64(x, y) < WATER_M


func _passable(x: float, y: float) -> float:
	for af in layout.airfields:
		if af.contains(x, y, STRIP_KEEP_OUT_M):
			return 0.0
	var h := base.height64(x, y)
	if h >= WATER_M:
		return 1.0
	if h > -8.0 and MapCity._river(Vector2(x, y))[0] < RIVER_BRIDGE_M:
		return 60.0  # a river: a bridge, at a price that finds the narrow place
	return 0.0
