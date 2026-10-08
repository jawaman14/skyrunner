class_name CostaBravaPlan
extends RefCounted
## Settlement authoring independent of the simulation's airfield/stash identities.
## Real street geometry, reserved working plots and stable parcels replace the
## old painted grid. Ordinary houses remain scenery; no inventory is invented.
const VERSION := 2
const DISTRICTS := [
	{"id": "west_workshops", "name": "Camino del Aeropuerto", "rect": Rect2(-4400, -10800, 1600, 1500), "block": 240.0, "height": 7.0, "style": "warehouse"},
	{"id": "old_town", "name": "San Telmo Viejo", "rect": Rect2(-2800, -10700, 1800, 1700), "block": 180.0, "height": 10.0, "style": "res"},
	{"id": "civic", "name": "Plaza del Mercado", "rect": Rect2(-1000, -10700, 1400, 1700), "block": 220.0, "height": 12.0, "style": "shop"},
	{"id": "barrio", "name": "Barrio Chino", "rect": Rect2(400, -10700, 1700, 1700), "block": 200.0, "height": 7.0, "style": "res"},
	{"id": "port", "name": "Puerto de San Telmo", "rect": Rect2(-2800, -11260, 3500, 560), "block": 280.0, "height": 11.0, "style": "warehouse"},
	{"id": "farm_village", "name": "Pueblo Morales", "rect": Rect2(-1100, -4200, 440, 440), "block": 220.0, "height": 5.0, "style": "res"},
	{"id": "quarry_yard", "name": "Talleres de la Cantera", "rect": Rect2(9350, 150, 440, 440), "block": 220.0, "height": 5.0, "style": "warehouse"},
]

static func reserved(p: Vector2, radius: float, layout: MapLayout) -> bool:
	if p.distance_to(SiteLayout.FAMILY_AT) < 24.0 + radius: return true
	for at in [MapCity.ORG_AT, MapCity.LAW_AT]:
		if p.distance_to(at) < 100.0 + radius: return true
	for st in layout.stashes:
		if p.distance_to(Vector2(st.x, st.y)) < 65.0 + radius: return true
	for af in layout.airfields:
		if af.contains(p.x, p.y, 120.0 + radius): return true
	return false

## New local roads are physical polylines. Rejected wet/steep/runway legs never
## become graph edges. Existing trunk-road bridge indices remain valid.
static func streets(terrain: Terrain, layout: MapLayout) -> Array:
	var out := []
	for district in DISTRICTS:
		var rect: Rect2 = district.rect
		var step: float = district.block
		for axis in 2:
			var line: float = rect.position[axis]
			while line <= rect.end[axis] + 0.01:
				var other := 1 - axis
				var at: float = rect.position[other]
				var run := []
				var previous := Vector2.ZERO
				var previous_h := 0.0
				while at <= rect.end[other] + 0.01:
					var p := Vector2.ZERO
					p[axis] = line
					p[other] = at
					var h := terrain.height64(p.x, p.y)
					var clear := h > 0.5
					for at_site in [MapCity.ORG_AT, MapCity.LAW_AT]:
						if p.distance_to(at_site) < 40.0: clear = false
					for stash in layout.stashes:
						if p.distance_to(Vector2(stash.x, stash.y)) < 35.0: clear = false
					for af in layout.airfields:
						if af.contains(p.x, p.y, 65.0): clear = false
					if not run.is_empty() and absf(h - previous_h) / maxf(1.0, p.distance_to(previous)) > 0.1: clear = false
					if clear:
						run.append([p.x, p.y])
					else:
						if run.size() > 1: out.append(_compact(run, rect.position[other], step, other))
						run = []
					previous = p
					previous_h = h
					at += 20.0
				if run.size() > 1: out.append(_compact(run, rect.position[other], step, other))
				line += step
	return out

static func _compact(run: Array, origin: float, spacing: float, axis: int) -> Array:
	var out := [run[0]]
	for i in range(1, run.size() - 1):
		var value: float = (run[i][axis] - origin) / spacing
		if absf(value - roundf(value)) < 0.001: out.append(run[i])
	out.append(run[-1])
	return out

static func buildings(terrain: Terrain, layout: MapLayout) -> Array:
	var out := []
	var roads := MapCity.RoadIndex.new(layout.roads, 70.0)
	for district in DISTRICTS:
		var rect: Rect2 = district.rect
		var step: float = district.block
		var ix := 0
		var x := rect.position.x
		while x + step <= rect.end.x + 0.01:
			var iy := 0
			var y := rect.position.y
			while y + step <= rect.end.y + 0.01:
				# Four street fronts enclosing a genuinely open courtyard/yard.
				for side in 4:
					for lot in 4:
						var id := "%s/%d/%d/%d/%d" % [district.id, ix, iy, side, lot]
						var rng := RandomNumberGenerator.new()
						rng.seed = id.hash()  # parcel identity, independent of rejection elsewhere
						if rng.randf() < (0.3 if district.id == "port" else 0.14): continue
						var wide := rng.randf_range(20, 24)
						var deep := rng.randf_range(14, 20)
						var offset := 14.0 + deep / 2
						var along := 50.0 + lot * (step - 100.0) / 3.0
						var p := Vector2(x + along, y + offset)
						if side == 1: p = Vector2(x + step - offset, y + along)
						if side == 2: p = Vector2(x + along, y + step - offset)
						if side == 3: p = Vector2(x + offset, y + along)
						var w := wide if side % 2 == 0 else deep
						var d := deep if side % 2 == 0 else wide
						var radius := Vector2(w, d).length() / 2
						if reserved(p, radius, layout) or roads.dist(p) < radius + 7.0: continue
						var lo := INF
						var hi := -INF
						for corner in [Vector2(-w, -d), Vector2(w, -d), Vector2(w, d), Vector2(-w, d)]:
							var at: Vector2 = p + corner / 2
							var h := terrain.height64(at.x, at.y)
							lo = minf(lo, h)
							hi = maxf(hi, h)
						if lo < 1.0 or hi - lo > 1.5: continue
						var height: float = rng.randf_range(0.7, 1.0) * district.height
						var keep := true
						for af in layout.airfields:
							var lc: Array = af.to_local(p.x, p.y)
							var beyond: float = absf(lc[0]) - af.length / 2
							if beyond < 1800 and absf(lc[1]) < af.width / 2 + radius + 90 + maxf(0, beyond) * 0.2:
								if hi + height > float(af.elev if af.elev != null else terrain.height64(af.x, af.y)) + maxf(0, beyond) * 0.05 - 8: keep = false
						if not keep: continue
						out.append({"id": id, "district": district.id, "x": p.x, "y": p.y, "z": hi, "w": w, "d": d,
							"h": height, "style": district.style, "period": true, "yaw": side * PI / 2})
				y += step
				iy += 1
			x += step
			ix += 1
	# Harbour cranes remain navigation landmarks, outside the working road.
	for i in 5:
		var p := Vector2(lerpf(MapCity.HARBOUR_X.x + 200, MapCity.HARBOUR_X.y - 200, i / 4.0), MapCity.COAST_Y + 22)
		if terrain.height64(p.x, p.y) > 0.5 and roads.dist(p) > 14:
			out.append({"id": "port/crane/%d" % i, "district": "port", "x": p.x, "y": p.y, "z": terrain.height64(p.x, p.y), "w": 12.0, "d": 12.0, "h": 32.0, "style": "crane"})
	return out

## Small shaded public courtyards, rather than palms on every inland street.
static func planting(terrain: Terrain, layout: MapLayout) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var index := MapCity.RoadIndex.new(layout.roads, 30)
	for district in DISTRICTS:
		if district.style == "warehouse": continue
		var rect: Rect2 = district.rect
		var step: float = district.block
		var x := rect.position.x + step / 2
		while x < rect.end.x:
			var y := rect.position.y + step / 2
			while y < rect.end.y:
				var p := Vector2(x, y)
				if not reserved(p, 12, layout) and index.dist(p) > 20 and terrain.height64(x, y) > 1:
					out.append_array([x, y, terrain.height64(x, y), 6.0])
				y += step
			x += step
	return out
