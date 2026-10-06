class_name Minimap
extends Control
## The radar and the chart. Small, it is a round radar centred on the aircraft that turns with the nose
## (track-up) or holds north up (Shift+M), at one of four ranges (+ and -), with range rings, a rim
## that carries the compass points, and a chevron on the rim for each job you have taken that is off
## the scope. M opens the whole island as a north-up chart. Both draw the same things - strips and
## their radar circles, jobs, stash houses and trucks, boats and bales, and the police you actually
## know about (eyeballs, scanner, spotters) - through one world-to-screen transform, so the two
## cannot disagree.

signal waypoint_picked(world: Vector2)  ## a click on the chart: where to go (Vector2.INF: cleared)

var s: Session
var tex: ImageTexture
var big := false
var north_up := false
var zoom_i := 1
var focus = null  ## {x, y, heading} to centre on instead of the aircraft: the car, the walker
var waypoint = null  ## a Vector2 on the ground to go to, or null

const RADAR_R := 100.0  ## the round radar's radius at 720 p; scales with the screen height
const BIG := 560.0  ## the chart's side at 720 p
const PANEL_W := 300.0  ## the places list beside it
const ROW := 22.0
const MARGIN := Vector2(12, 30)  ## clear of the build line along the bottom edge
const FOOT := 20.0  ## a caption strip under the radar
const ZOOMS_KM := [4.0, 10.0, 25.0, 60.0]  ## how far the rim is from the aircraft
const RING := Color(1, 1, 1, 0.16)
const INK := Color(0.02, 0.03, 0.05, 0.78)

var _places: Array = []  ## Places.ordered(), refreshed about once a second while the chart is open
var _places_t := 0.0
var _scroll := 0
var _hover := -1
var _mpp := 1.0  ## metres per pixel this frame
var _c := Vector2.ZERO  ## the screen point of the scope's centre
var _r := 1.0  ## the radar's radius in px (big mode: half the chart)
var _h := 0.0  ## the heading the scope is turned to, radians (0 when north-up or the chart)
var _wc := Vector2.ZERO  ## the world point at the scope's centre


func setup(sess: Session) -> Minimap:
	s = sess
	tex = ImageTexture.create_from_image(Models.minimap_image(sess.world, 256))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout()
	return self


func _scale() -> float:
	var h: float = get_parent_area_size().y if is_inside_tree() else 720.0
	return clampf(h / 720.0, 0.8, 2.0)


func _want() -> Vector2:
	if big:
		var b := BIG * _scale()
		return Vector2(b + PANEL_W * _scale(), b)
	var d := 2.0 * RADAR_R * _scale()
	return Vector2(d, d + FOOT)


func _layout() -> void:
	var sz := _want()
	custom_minimum_size = sz
	size = sz
	var area: Vector2 = get_parent_area_size() if is_inside_tree() else Vector2(1280, 720)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = (area - sz) / 2 if big else area - sz - MARGIN
	mouse_filter = Control.MOUSE_FILTER_STOP if big else Control.MOUSE_FILTER_IGNORE  # the open chart takes clicks


func toggle() -> void:
	big = not big
	_layout()


## +1 closer, -1 wider (the round radar only; the chart always shows the island).
func zoom(step: int) -> void:
	zoom_i = clampi(zoom_i + step, 0, ZOOMS_KM.size() - 1)


## The chart's own square (the places panel takes the rest of the open control).
func _chart_px() -> float:
	return BIG * _scale() if big else size.x


func range_km() -> float:
	return float(ZOOMS_KM[zoom_i])


func _process(dt: float) -> void:
	if (size - _want()).length() > 1.0 or not big and position != get_parent_area_size() - size - MARGIN:
		_layout()
	if big:
		_places_t -= clampf(dt, 0.0, 0.5)
		if _places_t <= 0.0 or _places.is_empty():
			_places_t = 1.0
			_places = Places.ordered(Places.list(s))
	queue_redraw()


## Who the scope follows: the car or the walker when there is one, else the aircraft. {} when there is nobody.
func _focus() -> Dictionary:
	if focus != null:
		return focus
	var st: FlightModel.FlightState = s.state
	return {} if st == null else {"x": st.x, "y": st.y, "heading": st.heading}


func _rows() -> int:
	return maxi(1, int((_chart_px() - 70.0 * _scale()) / (ROW * _scale())))


## Which place the point `p` (local) is over in the panel, or -1.
func _row_at(p: Vector2) -> int:
	var sc := _scale()
	var x0 := _chart_px() + 8.0
	if p.x < x0 or p.x > size.x - 4.0:
		return -1
	var i := int((p.y - 34.0 * sc) / (ROW * sc))
	if p.y < 34.0 * sc or i < 0 or i >= _rows():
		return -1
	return i + _scroll


## The PLACES panel: what is yours, what is open, what is not yet, each with how far it is; click one to go there.
func _panel(font: Font) -> void:
	var sc := _scale()
	var x0 := _chart_px() + 8.0
	var w := size.x - x0 - 4.0
	draw_rect(Rect2(Vector2(x0 - 4.0, 0), Vector2(w + 8.0, size.y)), Color(0.02, 0.03, 0.05, 0.9))
	draw_string(font, Vector2(x0 + 4.0, 20.0 * sc), "PLACES", HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * sc), UIStyle.CYAN)
	draw_string(font, Vector2(x0 + 4.0, 32.0 * sc), "yours, open, and not yet", HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * sc), UIStyle.CAPTION)
	var f := _focus()
	var me := Vector2(float(f.x), float(f.y)) if not f.is_empty() else Vector2.ZERO
	var rows := _rows()
	for k in rows:
		var i := _scroll + k
		if i >= _places.size():
			break
		var pl: Dictionary = _places[i]
		var y := (34.0 + k * ROW) * sc
		var row := Rect2(Vector2(x0, y), Vector2(w, ROW * sc - 2.0))
		if i == _hover:
			draw_rect(row, Color(1, 1, 1, 0.08))
		var col := Places.color_of(pl)
		draw_circle(row.position + Vector2(8.0, row.size.y / 2.0), 4.0 * sc, col)
		var locked: bool = pl.state == "locked"
		var no_pin: bool = bool(pl.get("no_pin", false))
		var dist := "" if locked or no_pin else _km_text(Vector2(float(pl.x), float(pl.y)).distance_to(me))
		var label := str(pl.name)
		draw_string(font, row.position + Vector2(20.0, row.size.y - 5.0 * sc), label, HORIZONTAL_ALIGNMENT_LEFT, w - 90.0 * sc, int(12 * sc), col if not locked else Color(0.6, 0.6, 0.65))
		draw_string(font, row.position + Vector2(w - 66.0 * sc, row.size.y - 5.0 * sc), "locked" if locked else dist, HORIZONTAL_ALIGNMENT_RIGHT, 64.0 * sc, int(11 * sc), UIStyle.CAPTION)
	if _hover >= 0 and _hover < _places.size():
		draw_string(font, Vector2(x0 + 4.0, size.y - 8.0), str(_places[_hover].note), HORIZONTAL_ALIGNMENT_LEFT, w - 8.0, int(10 * sc), UIStyle.AMBER)
	if _places.size() > rows:
		draw_string(font, Vector2(x0 + w - 70.0, 20.0 * sc), "wheel: more", HORIZONTAL_ALIGNMENT_RIGHT, 66.0, int(10 * sc), UIStyle.CAPTION)


static func _km_text(m: float) -> String:
	return "%.1f km" % (m / 1000.0) if m >= 950.0 else "%d m" % int(m)


## Click the open chart to set a waypoint, right-click to clear it.
func _gui_input(ev: InputEvent) -> void:
	if big and ev is InputEventMouseMotion:
		_hover = _row_at(ev.position)
		return
	if not big or not (ev is InputEventMouseButton) or not ev.pressed:
		return
	if ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll = clampi(_scroll + (-1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1), 0, maxi(0, _places.size() - _rows()))
		accept_event()
		return
	if ev.position.x > _chart_px():  # the places list: a click on a row is a waypoint to that place
		if ev.button_index == MOUSE_BUTTON_LEFT:
			var i := _row_at(ev.position)
			if i >= 0 and i < _places.size():
				var pl: Dictionary = _places[i]
				if pl.state != "locked" and not bool(pl.get("no_pin", false)):
					waypoint = Vector2(float(pl.x), float(pl.y))
					waypoint_picked.emit(waypoint)
				accept_event()
		return
	if ev.button_index == MOUSE_BUTTON_LEFT:
		_frame()
		var w := _world_of(ev.position)
		waypoint = Vector2(clampf(w.x, -World.HALF, World.HALF), clampf(w.y, -World.HALF, World.HALF))
		waypoint_picked.emit(waypoint)
		accept_event()
	elif ev.button_index == MOUSE_BUTTON_RIGHT:
		waypoint = null
		waypoint_picked.emit(Vector2.INF)
		accept_event()


func _frame() -> void:
	var f := _focus()
	if big:
		_r = _chart_px() / 2.0
		_c = Vector2(_r, _r)
		_mpp = 2.0 * World.HALF / _chart_px()
		_h = 0.0
		_wc = Vector2.ZERO
		return
	_r = RADAR_R * _scale()
	_c = Vector2(_r, _r)
	_mpp = range_km() * 1000.0 / _r
	_wc = Vector2(f.x, f.y) if not f.is_empty() else Vector2.ZERO
	_h = 0.0 if north_up or f.is_empty() else deg_to_rad(float(f.heading))


## World (x east, y north) to local px: the heading points up the screen.
func to_screen(x: float, y: float) -> Vector2:
	var d := Vector2(x, y) - _wc
	var f := Vector2(sin(_h), cos(_h))
	var r := Vector2(cos(_h), -sin(_h))
	return _c + Vector2(d.dot(r), -d.dot(f)) / _mpp


func _world_of(p: Vector2) -> Vector2:
	var o := (p - _c) * _mpp
	var f := Vector2(sin(_h), cos(_h))
	var r := Vector2(cos(_h), -sin(_h))
	return _wc + r * o.x - f * o.y


func _inside(p: Vector2, pad := 0.0) -> bool:
	if big:
		var cp := _chart_px()
		return p.x >= pad and p.y >= pad and p.x <= cp - pad and p.y <= cp - pad
	return p.distance_to(_c) <= _r - pad


func _label(font: Font, p: Vector2, text: String, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string_outline(font, p, text, align, -1, fs, 4, Color(0, 0, 0, 0.85))
	draw_string(font, p, text, align, -1, fs, col)


func _cross(p: Vector2, col: Color, r := 4.0) -> void:
	draw_line(p - Vector2(r, r), p + Vector2(r, r), col, 2.0)
	draw_line(p + Vector2(-r, r), p + Vector2(r, -r), col, 2.0)


func _diamond(p: Vector2, col: Color, r := 5.0) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), col)


## A circle of world radius `m` about a world point, drawn only where it is on the scope.
func _ring_world(wx: float, wy: float, m: float, col: Color, w: float) -> void:
	var cp := to_screen(wx, wy)
	var rp := m / _mpp
	if rp < 3.0 or (not big and cp.distance_to(_c) - rp > _r) or (not big and rp - cp.distance_to(_c) > _r):
		return
	var n := 72
	var prev := cp + Vector2(rp, 0)
	for i in range(1, n + 1):
		var a := TAU * i / n
		var q := cp + Vector2(cos(a), sin(a)) * rp
		if _inside(prev, 1.0) and _inside(q, 1.0):
			draw_line(prev, q, col, w, true)
		prev = q


## On the rim: a chevron pointing out to something that is off the scope, with how far it is.
func _pointer(p: Vector2, col: Color, text: String, font: Font) -> void:
	var dir := (p - _c).normalized()
	var tip := _c + dir * (_r - 3.0)
	var perp := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([tip, tip - dir * 11.0 + perp * 6.0, tip - dir * 11.0 - perp * 6.0]), col)
	var tp := tip - dir * 24.0
	_label(font, tp - Vector2(16, -4), text, 10, col)


func _draw() -> void:
	if s == null:
		return
	_frame()
	var font := UIStyle.mono()
	if big:
		var chart := Rect2(Vector2.ZERO, Vector2(_chart_px(), _chart_px()))
		draw_texture_rect(tex, chart, false)
		draw_rect(chart, Color(0, 0, 0, 0.6), false, 2.0)
	else:
		draw_circle(_c, _r + 2.0, INK)
		_terrain()
		_rim(font)
	_world_marks(font)
	_waypoint(font)
	_me()
	if not big:
		_caption(font)
	else:
		_label(font, Vector2(10, _chart_px() - 8), "click the map or a place: waypoint   right-click: clear   M: close", 12, UIStyle.CAPTION)
		_panel(font)


## The island under the scope: the terrain image mapped onto a disc, turned with the heading.
func _terrain() -> void:
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var n := 64
	var two_h := 2.0 * World.HALF
	for i in n:
		var a := TAU * i / n
		var p := _c + Vector2(cos(a), sin(a)) * _r
		var w := _world_of(p)
		pts.append(p)
		uvs.append(Vector2((w.x + World.HALF) / two_h, 1.0 - (w.y + World.HALF) / two_h))
		cols.append(Color(0.82, 0.88, 0.95))  # a touch dark and cool, so the marks stand off it
	draw_polygon(pts, cols, uvs, tex)


## The bezel: range rings, the rim, tick marks every 10 degrees and the compass points that turn with the scope.
func _rim(font: Font) -> void:
	draw_arc(_c, _r * 0.5, 0, TAU, 48, RING, 1.0, true)
	draw_arc(_c, _r, 0, TAU, 72, Color(UIStyle.CYAN, 0.55), 2.0, true)
	for deg in range(0, 360, 10):
		var a := deg_to_rad(deg) - _h  # the screen angle of this world bearing (0 = up)
		var d := Vector2(sin(a), -cos(a))
		var tick := 8.0 if deg % 30 == 0 else 4.0
		draw_line(_c + d * (_r - tick), _c + d * _r, Color(1, 1, 1, 0.55), 1.0)
	for pt in [["N", 0], ["E", 90], ["S", 180], ["W", 270]]:
		var a := deg_to_rad(float(pt[1])) - _h
		var p := _c + Vector2(sin(a), -cos(a)) * (_r - 17.0)
		var col: Color = UIStyle.AMBER if pt[0] == "N" else UIStyle.DIM
		_label(font, p + Vector2(-5, 5), str(pt[0]), 13, col)
	draw_string(font, _c + Vector2(4, -_r * 0.5 + 12), str(snappedf(range_km() / 2.0, 0.1)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.5))


func _caption(font: Font) -> void:
	var y := size.y - 5.0
	var txt := "%s   %s km   +/-" % ["NORTH UP" if north_up else "TRACK UP", str(snappedf(range_km(), 0.1))]
	_label(font, Vector2(size.x / 2.0 - 70.0, y), txt, 11, UIStyle.CAPTION)


func _world_marks(font: Font) -> void:
	var fs := 15 if big else 11
	for af in s.world.airfields:
		var col := Color(1, 1, 1) if af.kind in ["hub", "regional"] else Color(1, 0.8, 0.3)
		var a: Array = af.threshold(0)
		var b: Array = af.threshold(1)
		var pa := to_screen(a[0], a[1])
		var pb := to_screen(b[0], b[1])
		if _inside(pa) or _inside(pb):
			draw_line(pa, pb, col, 3.0 if big else 2.5, true)
			var lp := to_screen(af.x, af.y) + Vector2(7, -7)
			if _inside(lp, 12.0):
				_label(font, lp, af.code, fs, Color(1, 1, 1, 0.92))
				if s.dealer != null and af.kind in ["hub", "regional"]:  # the car lot beside the apron
					_label(font, lp + Vector2(0, fs + 1), "CARS", maxi(fs - 3, 8), UIStyle.PINK)
		if af.radar_km:
			_ring_world(af.x, af.y, af.radar_km * 1000.0, Color(1, 0.25, 0.25, 0.55), 1.5)
	for j in s.active_jobs:
		var xy: Array = s.job_xy(j)
		var p := to_screen(xy[0], xy[1])
		var col := Color(0.3, 0.8, 1) if j.is_airdrop() else Color(0.35, 1, 0.4)
		if _inside(p, 6.0):
			draw_arc(p, 8.0, 0, TAU, 20, col, 2.0, true)
			draw_circle(p, 2.0, col)
		elif not big:
			var km := Vector2(xy[0], xy[1]).distance_to(_wc) / 1000.0
			_pointer(p, col, "%.0f" % km, font)
	for pl in Places.markers(_places if big else Places.list(s)):
		if pl.kind in ["home", "casino"]:
			var pp := to_screen(float(pl.x), float(pl.y))
			if _inside(pp, 8.0):
				var pc := Places.color_of(pl)
				draw_colored_polygon(PackedVector2Array([pp + Vector2(0, -9), pp + Vector2(8, 0), pp + Vector2(0, 9), pp + Vector2(-8, 0)]), pc)
				draw_circle(pp, 2.5, Color(0.05, 0.05, 0.08))
				_label(font, pp + Vector2(11, 4), "BOSS" if pl.kind == "home" else "HOTEL", fs, pc)
	if s.stash_net != null:  # stash houses: a square (grey when burned), trucks as dots
		for sh in s.stash_net.stashes:
			var sp := to_screen(sh.x, sh.y)
			if _inside(sp, 5.0):
				var sc: Color = Color(0.5, 0.5, 0.5) if sh.burned else Color(1, 0.55, 0.2).lerp(Color(1, 0.15, 0.1), clampf(sh.heat / 60.0, 0, 1))
				draw_rect(Rect2(sp - Vector2(4, 4), Vector2(8, 8)), sc, false, 2.0)
				if big:
					_label(font, sp + Vector2(8, 4), str(sh.name), 11, sc)
		for t in s.stash_net.trucks:
			var tp: Array = t.pos(s.time)
			var tq := to_screen(tp[0], tp[1])
			if not _inside(tq, 3.0):
				continue
			var info: Dictionary = s.logistics.truck_info(t) if s.logistics != null else {"kind": "load"}
			var col: Color = StationMap.TRUCK_COL.get(info.kind, StationMap.TRUCK_COL.load)
			var to := to_screen(t.x1, t.y1)
			if _inside(to):
				draw_line(tq, to, Color(col, 0.35), 1.0)
			draw_circle(tq, 3.5, col)
	for b in s.maritime.boats:
		if b.kind == "gofast" and b.state != "delivered":
			var bp := to_screen(b.x, b.y)
			if _inside(bp, 4.0):
				_cross(bp, Color(0.3, 0.9, 1), 4.0)
	for bl in s.maritime.bales:
		if bl.state == "floating":
			var lp := to_screen(bl.x, bl.y)
			if _inside(lp, 3.0):
				_cross(lp, Color(1, 0.9, 0.3), 2.5)
	var known := known_contacts()
	for uid in known:
		var contact: Dictionary = known[uid]
		var kp := to_screen(contact.x, contact.y)
		if _inside(kp, 4.0):
			var col := Color(0.8, 0.3, 1) if str(uid).begins_with("Rival") else Color(0.35, 0.55, 1)
			var seen: bool = contact.source == "visual"
			_diamond(kp, col if seen else Color(col, 0.55), 5.0)
			if not seen:
				draw_arc(kp, 8.0, 0, TAU, 12, Color(col, 0.4), 1.0)
			if big and _inside(kp, 24.0):
				_label(font, kp + Vector2(10, -6), "visual" if seen else "%s • %ds ago" % [contact.source, int(contact.age)], 10, col)


## Reports keep their reported position and age; only direct sight supplies a live position.
func known_contacts() -> Dictionary:
	var st: FlightModel.FlightState = s.state
	var known := {}
	for k in s.intel:
		var v: Array = s.intel[k]
		if v[0] <= s.time:
			known[k] = {"x": v[1], "y": v[2], "source": v[3], "age": maxf(0.0, s.time - float(v[0]))}
	if st != null:
		for u in s.police.units:
			if u.state != "crashed" and PyMath.hypot3(u.x - st.x, u.y - st.y, u.z - st.alt) < PoliceSystem.SIGHT_RANGE_M:
				known[u.id] = {"x": u.x, "y": u.y, "source": "visual", "age": 0.0}
		for c in s.maritime.boats:
			if c.kind == "cutter" and PyMath.hypot(c.x - st.x, c.y - st.y) < 9000:
				known[c.id] = {"x": c.x, "y": c.y, "source": "visual", "age": 0.0}
	return known


## The waypoint: a pink pin with its distance; off the radar, a pink chevron on the rim; on the chart a line to it.
func _waypoint(font: Font) -> void:
	if waypoint == null:
		return
	var wp: Vector2 = waypoint
	var p := to_screen(wp.x, wp.y)
	var f := _focus()
	var km := (wp - Vector2(float(f.x), float(f.y))).length() / 1000.0 if not f.is_empty() else 0.0
	var text := "%.1f km" % km if km >= 0.95 else "%d m" % int(km * 1000.0)
	if _inside(p, 8.0):
		if big and not f.is_empty():
			var me := to_screen(float(f.x), float(f.y))
			draw_dashed_line(me, p, Color(UIStyle.PINK, 0.7), 2.0, 8.0)
		draw_circle(p, 6.0, UIStyle.PINK)
		draw_circle(p, 2.5, Color(1, 1, 1))
		draw_arc(p, 10.0, 0, TAU, 20, Color(UIStyle.PINK, 0.8), 1.5, true)
		_label(font, p + Vector2(10, -8), text, 12 if big else 11, UIStyle.PINK)
	elif not big:
		_pointer(p, UIStyle.PINK, text, font)


## You: a yellow arrow, with a short line ahead on the scope.
func _me() -> void:
	var f := _focus()
	if f.is_empty():
		return
	var c := to_screen(float(f.x), float(f.y))
	var a := deg_to_rad(float(f.heading)) - _h
	var fw := Vector2(sin(a), -cos(a))
	var r := Vector2(-fw.y, fw.x)
	if not big:
		draw_line(c + fw * 12.0, c + fw * (_r * 0.5), Color(1, 1, 0, 0.35), 1.0)
	draw_colored_polygon(PackedVector2Array([c + fw * 10, c - fw * 6 + r * 6, c - fw * 3, c - fw * 6 - r * 6]), Color(1, 0.95, 0.1))
