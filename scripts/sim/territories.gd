class_name Territories
extends RefCounted
## Map-owned local turf areas, rolled up into the economy's existing markets.

static var ENABLED := true


static func records(layout: MapLayout) -> Array:
	if not layout.territories.is_empty():
		return layout.territories
	var out := []
	for market in Economy.MARKETS:
		var centre := Vector2.ZERO
		if market == "town":
			var hub = layout.airfield("HAR")
			if hub != null:
				centre = Vector2(hub.x, hub.y)
		else:
			var raw: Array = layout.zone_centre.get(market, [0.0, 0.0])
			centre = Vector2(float(raw[0]), float(raw[1]))
		out.append({"id": market, "name": market.capitalize(), "market": market, "center": centre,
			"neighbors": [], "tags": []})
	return out


static func at(layout: MapLayout, position: Vector2) -> Dictionary:
	var areas := records(layout)
	if areas.is_empty():
		return {}
	if layout.territories.is_empty():
		var land_area: Dictionary = areas[0]
		var land_distance := INF
		var sea_area: Dictionary = {}
		for area: Dictionary in areas:
			var distance := center_of(area).distance_to(position)
			if str(area.get("market", "")) == "sea":
				sea_area = area
			elif distance < land_distance:
				land_distance = distance
				land_area = area
		if not sea_area.is_empty() and center_of(sea_area).distance_to(position) < land_distance * 0.8:
			return sea_area
		return land_area
	var nearest: Dictionary = areas[0]
	var nearest_distance := INF
	for area: Dictionary in areas:
		var center := center_of(area)
		var bounds_value: Variant = area.get("bounds")
		if bounds_value is Rect2:
			var bounds: Rect2 = bounds_value
			if bounds.has_point(position):
				return area
		var distance := center.distance_squared_to(position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = area
	return nearest


static func get_area(layout: MapLayout, id: String) -> Dictionary:
	if id.contains("/") and id.get_slice("/", 0) != layout.region_id:
		return {}
	var local := local_id(id)
	for area: Dictionary in records(layout):
		if str(area.get("id", "")) == local:
			return area
	return {}


static func key(layout: MapLayout, id: String) -> String:
	if id.contains("/"):
		return id
	return "%s/%s" % [layout.region_id, id]


static func local_id(id: String) -> String:
	var slash := id.rfind("/")
	return id.substr(slash + 1) if slash >= 0 else id


static func center_of(area: Dictionary) -> Vector2:
	var value: Variant = area.get("center", Vector2.ZERO)
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


static func territory_ids(layout: MapLayout) -> Array:
	var out := []
	for area: Dictionary in records(layout):
		out.append(key(layout, str(area.get("id", ""))))
	return out


static func validate(layout: MapLayout) -> String:
	var areas := records(layout)
	var ids := {}
	for area: Dictionary in areas:
		var id := str(area.get("id", ""))
		if id.is_empty() or ids.has(id):
			return "Territory IDs must be non-empty and unique."
		if str(area.get("market", "")) not in Economy.MARKETS:
			return "Territory %s has an unknown parent market." % id
		var center: Variant = area.get("center", Vector2.ZERO)
		var center_valid: bool = center is Vector2 or center is Array and center.size() >= 2
		if not center_valid:
			return "Territory %s has no valid centre." % id
		ids[id] = true
	for area: Dictionary in areas:
		for neighbor in area.get("neighbors", []):
			if not ids.has(str(neighbor)):
				return "Territory %s names an unknown neighbor." % str(area.get("id", ""))
	return ""
