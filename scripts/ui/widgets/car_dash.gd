class_name CarDash
extends Control
## The car's dashboard while you drive: a speedometer in km/h with a digital readout and the gear, a tachometer with a
## red zone, a little G-force dot (the car's weight, shown), the surface, the trip meter, the lamps, and the radio
## underneath - the station on the dial, what is playing, and the keys. It only draws; PilotApp feeds it each frame.
## Everything is laid out in a 560 x 200 box and scaled to the screen.

const BASE := Vector2(560, 200)
const SWEEP := 240.0  ## degrees of dial
const START := 150.0  ## where the scale begins: lower left, measured clockwise from 3 o'clock
const INK := Color(0.03, 0.035, 0.05, 0.82)
const RIM := Color(1, 1, 1, 0.16)
const TACH_MAX := 7000.0
const TACH_RED := 6000.0

var kmh := 0.0
var vmax := 160.0
var rpm := 900.0
var gear := 1
var throttle := 0.0
var brake := 0.0
var long_g := 0.0
var lat_g := 0.0
var on_road := true
var odo_km := 0.0
var lamps := false
var radio: Dictionary = {}
var wp_m := -1.0  ## distance to the waypoint, or -1 when there is none
var wp_rel := 0.0  ## and which way it lies from the nose, degrees (+ is to the right)


func _init() -> void:
	custom_minimum_size = BASE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The speedometer's top: a round number a little above what the surface allows, in steps of 20.
static func dial_max(cap_ms: float) -> float:
	return maxf(120.0, ceilf(cap_ms * 3.6 * 1.2 / 20.0) * 20.0)


static func gear_text(g: int) -> String:
	return "R" if g < 0 else ("N" if g == 0 else "D%d" % g)


## The point `f` (0..1) of the way round a dial of radius `r` about `c`.
static func dial_point(c: Vector2, r: float, f: float) -> Vector2:
	var a := deg_to_rad(START + SWEEP * clampf(f, 0.0, 1.0))
	return c + Vector2(cos(a), sin(a)) * r


func set_data(car: Car, radio_: CarRadio, night: bool, waypoint = null) -> void:
	kmh = absf(car.speed) * 3.6
	vmax = dial_max(car.road_ms)
	rpm = car.rpm
	gear = car.gear
	throttle = car.throttle_in
	brake = car.brake_in
	long_g = car.long_g
	lat_g = car.lat_g
	on_road = car.on_road()
	odo_km = car.odo_m / 1000.0
	lamps = night
	wp_m = -1.0
	if waypoint != null:
		var w: Vector2 = waypoint
		var g := car.game_xy()
		wp_m = g.distance_to(w)
		wp_rel = Py.wrap180(UIStyle.bearing_to(g.x, g.y, w.x, w.y) - car.heading_deg())
	radio = radio_.now_playing() if radio_ != null else {}
	var h: float = get_parent_area_size().y if is_inside_tree() else 720.0
	var u := clampf(h / 720.0, 0.8, 2.0)
	custom_minimum_size = BASE * u
	size = BASE * u
	var area: Vector2 = get_parent_area_size() if is_inside_tree() else Vector2(1280, 720)
	position = Vector2((area.x - size.x) / 2.0, area.y - size.y - 14.0)  # bottom centre
	queue_redraw()


func _dial(c: Vector2, r: float, v: float, vmax_: float, major: float, minor: float, label_div: float, red_from: float, col: Color) -> void:
	var font := UIStyle.mono()
	draw_circle(c, r + 3.0, INK)
	draw_arc(c, r + 3.0, 0, TAU, 64, RIM, 1.5, true)
	if red_from < vmax_:  # the red zone, a thick arc on the scale
		var a0 := deg_to_rad(START + SWEEP * red_from / vmax_)
		var a1 := deg_to_rad(START + SWEEP)
		draw_arc(c, r - 5.0, a0, a1, 24, Color(UIStyle.RED, 0.85), 4.0, true)
	var t := 0.0
	while t <= vmax_ + 0.001:
		var f := t / vmax_
		var is_major := fposmod(t, major) < 0.001 or absf(fposmod(t, major) - major) < 0.001
		var p1 := dial_point(c, r - (13.0 if is_major else 8.0), f)
		var p2 := dial_point(c, r - 2.0, f)
		draw_line(p1, p2, Color(1, 1, 1, 0.9 if is_major else 0.45), 2.0 if is_major else 1.0, true)
		if is_major:
			var lp := dial_point(c, r - 25.0, f)
			draw_string(font, lp + Vector2(-14, 4), "%d" % int(round(t / label_div)), HORIZONTAL_ALIGNMENT_CENTER, 28, 11, Color(1, 1, 1, 0.85))
		t += minor
	var fn := clampf(v / vmax_, 0.0, 1.0)
	var tip := dial_point(c, r - 9.0, fn)
	var tail := c - (tip - c).normalized() * 9.0
	draw_line(tail + Vector2(1, 1), tip + Vector2(1, 1), Color(0, 0, 0, 0.5), 3.0, true)
	draw_line(tail, tip, col, 2.5, true)
	draw_circle(c, 5.0, Color(0.15, 0.15, 0.18))
	draw_circle(c, 2.5, col)


func _draw() -> void:
	var u := size.y / BASE.y
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(u, u))
	var font := UIStyle.mono()
	# the dials: tach to the left, speedometer in the middle, the gauges to the right
	var sc := Vector2(280, 82)
	var tc := Vector2(112, 92)
	_dial(tc, 62.0, rpm, TACH_MAX, 1000.0, 500.0, 1000.0, TACH_RED, UIStyle.AMBER)
	draw_string(font, tc + Vector2(-28, 30), "x1000 rpm", HORIZONTAL_ALIGNMENT_CENTER, 56, 9, UIStyle.CAPTION)
	_dial(sc, 80.0, kmh, vmax, 20.0, 10.0, 1.0, vmax + 1.0, UIStyle.CYAN)
	draw_string(font, sc + Vector2(-40, 36), "%d" % int(round(kmh)), HORIZONTAL_ALIGNMENT_CENTER, 80, 30, UIStyle.WHITE)
	draw_string(font, sc + Vector2(-30, 52), "km/h", HORIZONTAL_ALIGNMENT_CENTER, 60, 11, UIStyle.CAPTION)
	# the gear, boxed, over the speedometer's hub
	var gb := Rect2(sc + Vector2(-20, -42), Vector2(40, 22))
	draw_style_box(UIStyle.box(Color(0, 0, 0, 0.55), 5, UIStyle.AMBER if gear > 0 else UIStyle.RED, 1, Vector4(0, 0, 0, 0)), gb)
	draw_string(font, gb.position + Vector2(0, 16), gear_text(gear), HORIZONTAL_ALIGNMENT_CENTER, gb.size.x, 15, UIStyle.WHITE)
	# the pedals as two thin bars, so you can see the throttle ramp and the brake bite
	var px := 380.0
	_bar(Vector2(px, 38), 12.0, 70.0, throttle, UIStyle.GREEN)
	_bar(Vector2(px + 20.0, 38), 12.0, 70.0, brake, UIStyle.RED)
	draw_string(font, Vector2(px - 6, 124), "PEDALS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UIStyle.CAPTION)
	# the G dot: a friction circle that shows the weight shifting
	var gc := Vector2(470, 74)
	draw_circle(gc, 36.0, INK)
	draw_arc(gc, 36.0, 0, TAU, 40, RIM, 1.5, true)
	draw_arc(gc, 18.0, 0, TAU, 32, Color(1, 1, 1, 0.1), 1.0, true)
	draw_line(gc - Vector2(36, 0), gc + Vector2(36, 0), Color(1, 1, 1, 0.1), 1.0)
	draw_line(gc - Vector2(0, 36), gc + Vector2(0, 36), Color(1, 1, 1, 0.1), 1.0)
	var dot := gc + Vector2(clampf(lat_g, -1.2, 1.2) * 30.0, clampf(-long_g, -1.2, 1.2) * 30.0)
	draw_circle(dot, 5.0, UIStyle.AMBER if (absf(lat_g) < 0.7 and absf(long_g) < 0.7) else UIStyle.RED)
	draw_string(font, gc + Vector2(-20, 52), "G", HORIZONTAL_ALIGNMENT_CENTER, 40, 9, UIStyle.CAPTION)
	# the small print
	draw_string(font, Vector2(372, 140), "ROAD" if on_road else "OFF-ROAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.GREEN if on_road else UIStyle.AMBER)
	draw_string(font, Vector2(372, 154), "TRIP %.1f km" % odo_km, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.CAPTION)
	draw_string(font, Vector2(470, 140), "LAMPS" if lamps else "", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.NEON_CYAN)
	draw_string(font, Vector2(470, 154), "[E] get out", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIStyle.CAPTION)
	_waypoint_arrow(font)
	_radio_panel(font)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A pink arrow that points at the waypoint relative to the nose (up is dead ahead), with the distance under it.
func _waypoint_arrow(font: Font) -> void:
	var c := Vector2(528, 36)
	if wp_m < 0.0:
		draw_string(font, c + Vector2(-26, 4), "no WPT", HORIZONTAL_ALIGNMENT_CENTER, 52, 9, UIStyle.CAPTION)
		return
	var d := Vector2(sin(deg_to_rad(wp_rel)), -cos(deg_to_rad(wp_rel)))
	var perp := Vector2(-d.y, d.x)
	draw_circle(c, 20.0, INK)
	draw_arc(c, 20.0, 0, TAU, 28, RIM, 1.5, true)
	draw_colored_polygon(PackedVector2Array([c + d * 15.0, c - d * 9.0 + perp * 9.0, c - d * 4.0, c - d * 9.0 - perp * 9.0]), UIStyle.PINK)
	var txt := "%.1f km" % (wp_m / 1000.0) if wp_m >= 950.0 else "%d m" % int(wp_m)
	draw_string(font, c + Vector2(-28, 36), txt, HORIZONTAL_ALIGNMENT_CENTER, 56, 11, UIStyle.PINK)


func _bar(p: Vector2, w: float, h: float, v: float, col: Color) -> void:
	draw_rect(Rect2(p, Vector2(w, h)), Color(0, 0, 0, 0.55))
	var fh := h * clampf(v, 0.0, 1.0)
	draw_rect(Rect2(p + Vector2(0, h - fh), Vector2(w, fh)), col)
	draw_rect(Rect2(p, Vector2(w, h)), RIM, false, 1.0)


## The radio under the dials: the dial reading and station, what is playing with how far through it is, the keys.
func _radio_panel(font: Font) -> void:
	var r := Rect2(Vector2(8, 166), Vector2(BASE.x - 16, 30))
	draw_style_box(UIStyle.box(INK, 7, RIM, 1, Vector4(0, 0, 0, 0)), r)
	if radio.is_empty() or not bool(radio.get("stations", false)):
		draw_string(font, r.position + Vector2(12, 20), "RADIO  no stations", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.CAPTION)
		return
	var is_on: bool = bool(radio.get("on", false))
	var fading: bool = bool(radio.get("static", false))
	var lamp := r.position + Vector2(16, 15)
	draw_circle(lamp, 4.0, (UIStyle.AMBER if fading else UIStyle.GREEN) if is_on else Color(0.3, 0.3, 0.3))
	if not is_on:
		draw_string(font, r.position + Vector2(30, 20), "RADIO OFF   (R turns it on, comma and full stop tune)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.CAPTION)
		return
	draw_string(font, r.position + Vector2(30, 20), "%s  %s" % [radio.dial, radio.name], HORIZONTAL_ALIGNMENT_LEFT, 190, 12, UIStyle.WHITE)
	var title := str(radio.get("title", ""))
	draw_string(font, r.position + Vector2(226, 20), ("~ " if fading else "") + title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 300.0, 12, UIStyle.CYAN)
	draw_string(font, r.position + Vector2(r.size.x - 66, 20), ", .  tune", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIStyle.CAPTION)
	var prog := float(radio.get("progress", 0.0))
	draw_rect(Rect2(r.position + Vector2(12, 26), Vector2((r.size.x - 24) * clampf(prog, 0.0, 1.0), 2)), Color(UIStyle.CYAN, 0.7))
