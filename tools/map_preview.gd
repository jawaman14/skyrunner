extends SceneTree
## A top-down picture of the map rebuild's authored layers (docs/MAP_REDESIGN.md, step 1): the approved layout (D-106) from
## data/maps/costa_brava/{brief,districts,roads_plan}.json drawn over today's Costa Brava terrain and land use, so the layout can
## be checked against the ground it will reshape. Nothing here changes the game; the game still loads MapCity's map.
##
##   godot --path . --script res://tools/map_preview.gd -- <out.png> [px=1600] [zoom: x0,y0,x1,y1 in metres]
## Needs a display (xvfb-run on a headless box) for the labels.

const DIR := "res://data/maps/costa_brava/"
const LAND := {0: Color(0.55, 0.72, 0.80), 1: Color(0.90, 0.85, 0.66), 2: Color(0.30, 0.46, 0.30), 3: Color(0.48, 0.52, 0.36),
	4: Color(0.74, 0.76, 0.50), 5: Color(0.66, 0.74, 0.48), 6: Color(0.27, 0.45, 0.27), 7: Color(0.72, 0.66, 0.50),
	8: Color(0.62, 0.60, 0.56), 9: Color(0.80, 0.77, 0.73), 10: Color(0.70, 0.70, 0.70), 11: Color(0.40, 0.40, 0.42)}
const DISTRICT_TINT := {"keep": Color(0.25, 0.25, 0.30, 0.55), "change": Color(0.70, 0.45, 0.05, 0.8), "new": Color(0.05, 0.35, 0.65, 0.85)}

var px := 1600
var out := "map_preview.png"
var view := Rect2(-16000, -16000, 32000, 32000)


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	if a.size() > 1:
		px = int(a[1])
	if a.size() > 2:
		var z: PackedStringArray = a[2].split(",")
		view = Rect2(float(z[0]), float(z[1]), float(z[2]) - float(z[0]), float(z[3]) - float(z[1]))
	_go.call_deferred()


func _json(name: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DIR + name))
	return d if d is Dictionary else {}


## Game metres (x east, y north) to picture pixels (north up).
func _p(x: float, y: float) -> Vector2:
	return Vector2((x - view.position.x) / view.size.x * px, (view.end.y - y) / view.size.y * px)


func _go() -> void:
	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED  # one picture pixel a screen pixel, whatever the project's stretch
	get_root().content_scale_factor = 1.0
	get_root().size = Vector2i(px, px)
	World.use_map(MapCity.SEED)
	var world := World.new()
	var lu: PackedByteArray = world.map.land_use
	# The ground: land use tinted, shaded by the slope (light from the north-west).
	var img := Image.create(px, px, false, Image.FORMAT_RGB8)
	var step := view.size.x / px
	var step_y := view.size.y / px
	for j in px:
		var y := view.end.y - (j + 0.5) * step_y
		for i in px:
			var x := view.position.x + (i + 0.5) * step
			var c: Color = LAND.get(MapCity.at(lu, x, y), LAND[5]) if not lu.is_empty() else LAND[5]
			var h := world.ground(x, y)
			if h <= 0.0 and (lu.is_empty() or MapCity.at(lu, x, y) == 0):
				c = LAND[0].darkened(clampf(-h / 120.0, 0.0, 0.35))
			else:
				var dz := world.ground(x - step, y + step) - h
				c = c.lightened(clampf(dz / step * 0.6, 0.0, 0.25)) if dz > 0.0 else c.darkened(clampf(-dz / step * 0.6, 0.0, 0.35))
			img.set_pixel(i, j, c)
	var root := Node2D.new()
	get_root().add_child(root)
	var bg := Sprite2D.new()
	bg.texture = ImageTexture.create_from_image(img)
	bg.centered = false
	root.add_child(bg)
	var font := ThemeDB.fallback_font
	var fs := maxi(11, px / 110)
	# Districts.
	for d in _json("districts.json").get("districts", []):
		var poly := PackedVector2Array()
		for q in d.polygon:
			poly.append(_p(q[0], q[1]))
		var line := Line2D.new()
		line.points = poly
		line.closed = true
		line.width = 2.0 if str(d.status) == "keep" else 3.0
		line.default_color = DISTRICT_TINT.get(str(d.status), DISTRICT_TINT.keep)
		root.add_child(line)
		if d.has("hole"):
			var hl := Line2D.new()
			for q in d.hole:
				hl.add_point(_p(q[0], q[1]))
			hl.closed = true
			hl.width = 2.0
			hl.default_color = line.default_color
			root.add_child(hl)
		var cx := 0.0
		var cy := 0.0
		for q in d.polygon:
			cx += float(q[0])
			cy += float(q[1])
		cx /= (d.polygon as Array).size()
		cy /= (d.polygon as Array).size()
		_label(root, font, str(d.name).to_upper(), _p(cx, cy), fs, line.default_color.darkened(0.3))
	# Roads.
	for r in _json("roads_plan.json").get("roads", []):
		var l := Line2D.new()
		for q in r.points:
			l.add_point(_p(q[0], q[1]))
		var track := str(r["class"]) == "track"
		l.width = 3.0 if track else 5.0
		l.default_color = Color(0.55, 0.42, 0.25) if track else Color(0.55, 0.18, 0.05)
		if str(r.status) == "new":
			l.default_color = Color(0.85, 0.10, 0.45)
		l.joint_mode = Line2D.LINE_JOINT_ROUND
		root.add_child(l)
	# Strips (from strips.json, at the brief's anchors) and their protected 3 km approaches.
	var strips := {}
	for s in _json("strips.json").get("strips", []):
		strips[str(s.code)] = s
	for b in _json("brief.json").get("strips", []):
		var s: Dictionary = strips.get(str(b.code), {})
		if s.is_empty():
			continue
		var at := Vector2(float(b.at[0]), float(b.at[1]))
		var hd := deg_to_rad(float(s.heading))
		var dir := Vector2(sin(hd), cos(hd))
		var half := float(s.length) / 2.0
		var ends := [at - dir * half, at + dir * half]
		var cones := [1] if bool(b.get("two_way", true)) == false else [0, 1]
		for e in cones:
			var sgn := -1.0 if e == 0 else 1.0
			var end: Vector2 = ends[e]
			var far := end + dir * sgn * 3000.0
			var nrm := Vector2(-dir.y, dir.x)
			var cone := Polygon2D.new()
			cone.polygon = PackedVector2Array([_p(end.x + nrm.x * 60, end.y + nrm.y * 60), _p(far.x + nrm.x * 450, far.y + nrm.y * 450),
				_p(far.x - nrm.x * 450, far.y - nrm.y * 450), _p(end.x - nrm.x * 60, end.y - nrm.y * 60)])
			cone.color = Color(0.48, 0.12, 0.36, 0.22)
			root.add_child(cone)
		var rw := Line2D.new()
		rw.points = PackedVector2Array([_p(ends[0].x, ends[0].y), _p(ends[1].x, ends[1].y)])
		rw.width = maxf(4.0, float(s.length) / view.size.x * px * 0.08)
		rw.default_color = Color(0.48, 0.12, 0.36)
		root.add_child(rw)
		var tag := str(b.code) + (" (moved)" if str(b.status) == "change" and Vector2(float(s.x), float(s.y)).distance_to(at) > 100.0 else "")
		_label(root, font, tag, _p(at.x, at.y) + Vector2(10, -10), fs + 2, Color(0.48, 0.12, 0.36))
	# Sites.
	for st in _json("brief.json").get("sites", []):
		for q in st.anchors:
			var m := Polygon2D.new()
			var c := _p(q[0], q[1])
			var r := 6.0
			m.polygon = PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r, r), c + Vector2(-r, r)])
			m.color = Color(0.08, 0.31, 0.48) if bool(st.enterable) else Color(0.95, 0.95, 0.95)
			root.add_child(m)
	_label(root, font, "Costa Brava, rebuilt: the approved layout (D-106) over today's terrain   -   %d x %d km" % [int(view.size.x / 1000), int(view.size.y / 1000)],
		Vector2(14, 14), fs + 4, Color(0.1, 0.1, 0.1), false)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()


func _label(root: Node2D, font: Font, text: String, at: Vector2, size: int, colour: Color, centred := true) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.position = at - Vector2(text.length() * size * 0.28, size * 0.6) if centred else at
	root.add_child(l)
