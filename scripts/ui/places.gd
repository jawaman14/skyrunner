class_name Places
extends RefCounted
## Where things are: the list behind the chart's PLACES panel and the markers on it. Each is a place you have, or one the
## game has opened, or (greyed, with how to open it) one it has not - so "where is the boss's desk", "which are my stash
## houses" and "what is unlocked" are answered on the map instead of by wandering. Picking one sets the waypoint.
##
## A place is {id, name, kind, x, y, state, note}: kind is one of home, stash, lot, casino, island, lab, field; state is
## "mine" (yours), "open" (there to use), "burned" (a stash the law has taken) or "locked" (note says what opens it).

const KIND_ORDER := ["home", "stash", "lot", "casino", "island", "lab", "field"]


static func list(s: Session) -> Array:
	var out := []
	var hq: Dictionary = s.world.map.hqs.get("org", {})
	if not hq.is_empty():
		out.append({"id": "home", "name": "%s - the boss's desk" % str(hq.get("name", "Your villa")), "kind": "home",
			"x": float(hq.x), "y": float(hq.y), "state": "mine", "note": "walk in and sit at the desk: orders, hiring, the books"})
	if s.stash_net != null:
		for sh in s.stash_net.stashes:
			var burned: bool = bool(sh.burned)
			out.append({"id": "stash:%s" % str(sh.id), "name": "Stash: %s" % str(sh.name), "kind": "stash", "x": float(sh.x), "y": float(sh.y),
				"state": "burned" if burned else "mine", "note": "burned: the law has it" if burned else "product and cash are kept here"})
	for af in s.world.airfields:
		if af.kind in ["hub", "regional"]:
			if s.dealer != null:
				out.append({"id": "lot:%s" % af.code, "name": "Car lot at %s" % af.name, "kind": "lot", "x": af.x + 40.0, "y": af.y + 30.0,
					"state": "open", "note": "cars to drive, trucks for the stash runs (Shift+V in the cockpit)"})
	if s.dealer == null:
		out.append(_locked("lot", "Car lot", _opens("The Connection"), s))
	if s.casino != null:
		var site := CasinoBuilding.site()
		out.append({"id": "casino", "name": "Hotel Cielo (the Family's casino)", "kind": "casino", "x": float(site.x), "y": float(site.y), "state": "open",
			"note": "the tables, the cage, the manager upstairs"})
	else:
		out.append(_locked("casino", "Hotel Cielo", _opens("The House"), s))
	if s.island != null:
		var ia := Island.airfield()
		out.append({"id": "island", "name": "Isla Soberana", "kind": "island", "x": ia.x, "y": ia.y, "state": "open", "note": "the General's island: its own strip and board"})
	else:
		out.append(_locked("island", "Isla Soberana", _opens("Isla Soberana"), s))
	if s.psych != null:
		out.append({"id": "lab", "name": "The Sunrise Collective (call from the phone)", "kind": "lab", "x": float(hq.get("x", 0.0)) if not hq.is_empty() else 0.0,
			"y": float(hq.get("y", 0.0)) if not hq.is_empty() else 0.0, "state": "open", "note": "ring Nico from the phone: acid for grass", "no_pin": true})
	else:
		out.append(_locked("lab", "The Sunrise Collective", _opens("Blotter"), s))
	for af in s.world.airfields:
		out.append({"id": "field:%s" % af.code, "name": "%s - %s" % [af.code, af.name], "kind": "field", "x": af.x, "y": af.y, "state": "open",
			"note": "%s strip, %d m" % [af.kind, int(af.length)]})
	return out


## "opens in The House (1985)": the story chapter that switches the place on.
static func _opens(chapter: String) -> String:
	var i := Story.index_of(chapter)
	return "opens in %s (%d)" % [chapter, int(Story.CHAPTERS[i][0])] if i < Story.CHAPTERS.size() else "not open in this game"


static func _locked(kind: String, name: String, note: String, s: Session) -> Dictionary:
	return {"id": "locked:%s" % kind, "name": name, "kind": kind, "x": 0.0, "y": 0.0, "state": "locked", "note": note, "no_pin": true}


## What to draw a marker for on the chart: not the locked ones, and not the ones that have no place of their own.
static func markers(places: Array) -> Array:
	return places.filter(func(p): return p.state != "locked" and not bool(p.get("no_pin", false)) and p.kind != "field")


static func color_of(p: Dictionary) -> Color:
	if p.state == "locked":
		return Color(0.5, 0.5, 0.55)
	if p.state == "burned":
		return Color(0.55, 0.55, 0.55)
	match str(p.kind):
		"home":
			return UIStyle.AMBER
		"stash":
			return Color(1, 0.55, 0.2)
		"lot":
			return UIStyle.PINK
		"casino":
			return Color(1, 0.85, 0.3)
		"island":
			return UIStyle.NEON_CYAN
		_:
			return UIStyle.DIM


## The same list sorted for the panel: yours first, then what is open, then what is not, kinds in a fixed order.
static func ordered(places: Array) -> Array:
	var rank := {"mine": 0, "open": 1, "burned": 2, "locked": 3}
	var out := places.duplicate()
	out.sort_custom(func(a, b):
		var ra: int = rank.get(a.state, 9)
		var rb: int = rank.get(b.state, 9)
		if ra != rb:
			return ra < rb
		var ka := KIND_ORDER.find(a.kind)
		var kb := KIND_ORDER.find(b.kind)
		if ka != kb:
			return ka < kb
		return str(a.name) < str(b.name))
	return out
