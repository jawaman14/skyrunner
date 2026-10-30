class_name MapAudit
extends RefCounted
## The map audit (docs/MAP_REDESIGN.md section 4): each layer's own gate over the authored data in data/maps/costa_brava/.
## L1 first: the strips. A gate returns a list of findings, "" when there are none; a finding names the strip and the rule.
##
## Pure functions over dictionaries, so the gate runs in CI on the baked data without generating anything and a new map's data can
## be checked before it is wired in.

const STRIPS_FILE := "res://data/maps/costa_brava/strips.json"
const KINDS := ["hub", "regional", "bush", "shady"]
const SETTINGS := ["flat", "plateau", "pit", "beach"]
const SURFACES := ["asphalt", "gravel", "grass", "dirt", "sand"]
## The shortest and narrowest each kind of strip may be (m): the brief's floor, under the strips the game already has.
const MIN_LENGTH := {"hub": 1500.0, "regional": 500.0, "bush": 300.0, "shady": 300.0}
const MIN_WIDTH := {"hub": 30.0, "regional": 20.0, "bush": 14.0, "shady": 14.0}
const APPROACH_M := 3000.0  ## the protected volume reaches this far past each end (3 degrees out to 3 km, MAP_REDESIGN L1)
const VOLUME_HALF_WIDTH_M := 150.0  ## ... and this far either side of the centreline
const EDGE_MARGIN_M := 500.0  ## a strip and its pad stay this far inside the map's edge


static func load_strips(path := STRIPS_FILE) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var doc: Variant = JSON.parse_string(f.get_as_text())
	if not (doc is Dictionary) or not (doc as Dictionary).get("strips") is Array:
		return []
	return (doc as Dictionary)["strips"]


## The runway's rectangle, or its protected volume (the runway plus APPROACH_M past each end), as four corners.
static func footprint(s: Dictionary, volume := false) -> PackedVector2Array:
	var h := deg_to_rad(float(s.heading))
	var u := Vector2(sin(h), cos(h))
	var v := Vector2(u.y, -u.x)
	var half_l := float(s.length) / 2.0 + (APPROACH_M if volume else 0.0)
	var half_w := float(s.width) / 2.0 + (VOLUME_HALF_WIDTH_M if volume else 0.0)
	var c := Vector2(float(s.x), float(s.y))
	return PackedVector2Array([c - u * half_l - v * half_w, c + u * half_l - v * half_w, c + u * half_l + v * half_w, c - u * half_l + v * half_w])


## The strips' own gate: required fields, kinds and floors, inside the map, no strip inside another's runway or pad.
## `half`: half the map's side (World.HALF). Protected volumes may meet over open sea; only a runway inside another strip's volume is a finding.
static func strips_gate(strips: Array, half: float) -> Array:
	if strips.is_empty():
		return ["no strips: strips.json is missing, unreadable or has no strips array"]  # an unreadable file must not pass
	var out := []
	var seen := {}
	var complete := []  ## only whole records go on to the geometry checks: a missing field is a finding, never a crash
	for s in strips:
		var code := str(s.get("code", "?"))
		var whole := true
		for key in ["code", "name", "x", "y", "heading", "length", "width", "surface", "kind", "setting"]:
			if not s.has(key):
				out.append("%s: missing %s" % [code, key])
				whole = false
		if not whole:
			continue
		complete.append(s)
		if seen.has(code):
			out.append("%s: listed twice" % code)
		seen[code] = true
		var kind := str(s.kind)
		if not kind in KINDS:
			out.append("%s: unknown kind %s" % [code, kind])
		elif float(s.length) < MIN_LENGTH[kind] or float(s.width) < MIN_WIDTH[kind]:
			out.append("%s: %.0f x %.0f m is under the %s floor of %.0f x %.0f m" % [code, float(s.length), float(s.width), kind, MIN_LENGTH[kind], MIN_WIDTH[kind]])
		if not str(s.setting) in SETTINGS:
			out.append("%s: unknown setting %s" % [code, str(s.setting)])
		if not str(s.surface) in SURFACES:
			out.append("%s: unknown surface %s" % [code, str(s.surface)])
		if str(s.setting) == "pit" and s.get("haul_road") == null:
			out.append("%s: a pit strip needs its haul road end" % code)
		var reach := float(s.length) / 2.0 + EDGE_MARGIN_M
		if absf(float(s.x)) + reach > half or absf(float(s.y)) + reach > half:
			out.append("%s: within %.0f m of the map's edge" % [code, EDGE_MARGIN_M])
		for p in footprint(s, true):
			if absf(p.x) > half or absf(p.y) > half:
				out.append("%s: its protected approach volume leaves the map (the terrain pass could not keep it clear)" % code)
				break
	for i in complete.size():
		for j in range(i + 1, complete.size()):
			var a: Dictionary = complete[i]
			var b: Dictionary = complete[j]
			if _polys_overlap(footprint(a), footprint(b, true)) or _polys_overlap(footprint(b), footprint(a, true)):
				out.append("%s and %s: a runway lies in the other's protected approach volume" % [str(a.code), str(b.code)])
	return out


static func _polys_overlap(p: PackedVector2Array, q: PackedVector2Array) -> bool:
	return not Geometry2D.intersect_polygons(p, q).is_empty()


## Strips against what the generator actually places (the baseline until MapCity reads the data): every field of every strip must match.
static func drift(strips: Array, layout_fields: Array) -> Array:
	var out := []
	var by_code := {}
	for a in layout_fields:
		by_code[a.code] = a
	for s in strips:
		var code := str(s.code)
		if not by_code.has(code):
			out.append("%s: in strips.json but not on the map" % code)
			continue
		var a = by_code[code]
		for key in ["x", "y", "heading", "length", "width"]:
			if absf(float(s[key]) - float(a.get(key))) > 1e-6:
				out.append("%s: %s is %s in strips.json, %s on the map" % [code, key, str(s[key]), str(a.get(key))])
		for key in ["name", "surface", "kind", "setting"]:
			if str(s[key]) != str(a.get(key)):
				out.append("%s: %s is %s in strips.json, %s on the map" % [code, key, str(s[key]), str(a.get(key))])
		for key in ["shop", "police", "tree_lines"]:
			if bool(s[key]) != bool(a.get(key)):
				out.append("%s: %s differs" % [code, key])
		if absf(float(s.get("radar_km", 0.0)) - float(a.get("radar_km"))) > 1e-6:
			out.append("%s: radar_km differs" % code)
		var se: Variant = s.get("elev")
		var ae: Variant = a.get("elev")
		if (se == null) != (ae == null) or (se != null and absf(float(se) - float(ae)) > 1e-6):
			out.append("%s: elev is %s in strips.json, %s on the map" % [code, str(se), str(ae)])  # null (the terrain decides) is not 0
		var sh: Variant = s.get("haul_road")
		var ah: Variant = a.get("haul_road")
		if (sh == null) != (ah == null) or (sh != null and int(sh) != int(ah)):
			out.append("%s: haul_road end differs" % code)
	for code in by_code:
		if not strips.any(func(s): return str(s.code) == code):
			out.append("%s: on the map but not in strips.json" % code)
	return out
