class_name Compass
extends Control
## The heading tape: degrees scrolling past a fixed pointer, so a turn is seen at a glance instead of
## read off a number, with the wind as a small arrow over it. Hud anchors and sizes it (_build_compass);
## this widget only draws (same custom-draw pattern as CGChart: set_data() then queue_redraw()).
##
## The wind arrow points toward where the wind is blowing FROM, relative to the nose: straight up is a
## headwind, straight down a tailwind, right is wind off the right wing - a weather-vane needle, not a
## windsock (which points the other way, downwind).

const SPAN_DEG := 50.0  ## how many degrees either side of the nose the tape shows
const TICK_EVERY := 10.0
const MAJOR_EVERY := 30
const CARDINAL := {0: "N", 90: "E", 180: "S", 270: "W"}

var heading := 0.0
var wind_dir := 0.0
var wind_kt := 0.0
var has_wind := false


func _init() -> void:
	custom_minimum_size = Vector2(200, 58)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `weather`: Session.weather (Dictionary); {} off-season draws the tape with no wind arrow.
func set_data(heading_: float, weather: Dictionary) -> void:
	heading = fposmod(heading_, 360.0)
	has_wind = not weather.is_empty() and float(weather.get("wind_kt", 0.0)) > 0.1
	if has_wind:
		wind_dir = float(weather.wind_dir)
		wind_kt = float(weather.wind_kt)
	queue_redraw()


## -180..180: the wind's bearing relative to the nose (0 = headwind, +90 = off the right wing).
static func relative_wind(heading_: float, wind_dir_: float) -> float:
	return Py.wrap180(wind_dir_ - heading_)


## Where heading `hdg` (0-360) falls on the tape, in local x, or null past SPAN_DEG off the nose.
func _tape_x(hdg: float) -> Variant:
	var d := Py.wrap180(hdg - heading)
	if absf(d) > SPAN_DEG:
		return null
	return size.x / 2.0 + d / SPAN_DEG * (size.x / 2.0)


func _draw() -> void:
	var w := size.x
	var tape_y := size.y - 16.0
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 0.62))  # the HUD panels' own dark, not CGChart's (over bright sky, not a menu)
	draw_line(Vector2(0, tape_y), Vector2(w, tape_y), UIStyle.DIM, 1.0)
	var font := UIStyle.mono()
	var t: float = ceilf((heading - SPAN_DEG) / TICK_EVERY) * TICK_EVERY
	while t <= heading + SPAN_DEG + 0.01:
		var x = _tape_x(fposmod(t, 360.0))
		if x != null:
			var hk := int(round(t)) % 360
			if hk < 0:
				hk += 360
			var major: bool = hk % MAJOR_EVERY == 0
			var th := 10.0 if major else 5.0
			draw_line(Vector2(x, tape_y), Vector2(x, tape_y - th), UIStyle.DIM, 1.0)
			if major:
				var label: String = CARDINAL.get(hk, "%02d" % int(hk / 10.0))
				var col := UIStyle.CYAN if CARDINAL.has(hk) else UIStyle.DIM
				draw_string(font, Vector2(x - 8, tape_y - th - 4), label, HORIZONTAL_ALIGNMENT_CENTER, 16, 11, col)
		t += TICK_EVERY
	var cx := w / 2.0
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 5, tape_y + 2), Vector2(cx + 5, tape_y + 2), Vector2(cx, tape_y - 7)]), UIStyle.AMBER)
	draw_string(font, Vector2(cx - 20, size.y - 1), "%03d" % int(round(heading)), HORIZONTAL_ALIGNMENT_CENTER, 40, 13, UIStyle.WHITE)
	if has_wind:
		var rel := relative_wind(heading, wind_dir)
		var r := 15.0
		var cy := 13.0
		var dir := Vector2(sin(deg_to_rad(rel)), -cos(deg_to_rad(rel)))
		var perp := Vector2(-dir.y, dir.x)
		var tip := Vector2(cx, cy) + dir * r
		draw_line(Vector2(cx, cy), tip - dir * 5.0, UIStyle.CYAN, 2.0)
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 6.0 + perp * 3.0, tip - dir * 6.0 - perp * 3.0]), UIStyle.CYAN)
		draw_string(font, Vector2(cx + r + 6.0, cy + 4), "%d kt" % int(round(wind_kt)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.CYAN)
