class_name Attitude
extends Control
## The attitude ball: sky over ground turning with the bank and sliding with the pitch, a fixed
## aircraft symbol, a bank scale on the rim. It answers "how far over am I and is the nose up" at a
## glance, which the numbers in the tiles never did. Hud puts it beside the flight tiles.
##
## Pitch is in degrees, nose up positive; roll in degrees, right wing down positive (FlightState's own).

const PX_PER_DEG := 1.6  ## ball radius is about 40 degrees of pitch
const SKY := Color(0.18, 0.42, 0.72)
const GROUND := Color(0.45, 0.3, 0.16)

var pitch := 0.0
var roll := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(88, 88)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_data(pitch_: float, roll_: float) -> void:
	pitch = clampf(pitch_, -90.0, 90.0)
	roll = roll_
	queue_redraw()


## The unit vector from the ball's centre toward the ground, in screen space: it leans toward the low wing.
static func down_vector(roll_deg: float) -> Vector2:
	var r := deg_to_rad(roll_deg)
	return Vector2(sin(r), cos(r))


func _draw() -> void:
	var rad := minf(size.x, size.y) / 2.0 - 3.0
	var c := size / 2.0
	draw_circle(c, rad + 2.0, Color(0.02, 0.03, 0.05, 0.75))
	draw_circle(c, rad, SKY)
	var n := down_vector(roll)
	var dd := pitch * PX_PER_DEG  ## the horizon's distance from the centre, toward the ground when the nose is up
	if dd <= -rad:
		draw_circle(c, rad, GROUND)
	elif dd < rad:
		var phi := acos(dd / rad)
		var tn := atan2(n.y, n.x)
		var pts := PackedVector2Array()
		var steps := 32
		for i in steps + 1:
			var a := tn - phi + 2.0 * phi * i / steps
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
		draw_colored_polygon(pts, GROUND)
	var along := Vector2(-n.y, n.x)  ## along the horizon
	var hc := c + n * dd
	var edge := sqrt(maxf(rad * rad - dd * dd, 0.0))
	if edge > 1.0:
		draw_line(hc - along * edge, hc + along * edge, Color(1, 1, 1, 0.9), 1.5, true)
	for deg in [-20, -10, 10, 20]:  # the pitch ladder
		var lc := c + n * (dd - float(deg) * PX_PER_DEG)
		var half := 9.0 if absi(deg) == 10 else 14.0
		if lc.distance_to(c) + half < rad - 4.0:
			draw_line(lc - along * half, lc + along * half, Color(1, 1, 1, 0.55), 1.0)
	draw_arc(c, rad, 0, TAU, 40, Color(1, 1, 1, 0.35), 1.5, true)
	for b in [-60, -30, 0, 30, 60]:  # the bank scale, fixed to the case
		var d := Vector2(sin(deg_to_rad(float(b))), -cos(deg_to_rad(float(b))))
		draw_line(c + d * (rad - 6.0), c + d * rad, Color(1, 1, 1, 0.8), 2.0 if b == 0 else 1.0)
	var up := -n  ## the bank pointer rides the rotating sky
	var pp := c + up * (rad - 7.0)
	var pa := Vector2(-up.y, up.x)
	draw_colored_polygon(PackedVector2Array([pp - up * 1.0, pp - up * 9.0 + pa * 4.0, pp - up * 9.0 - pa * 4.0]), UIStyle.AMBER)
	var wing := UIStyle.AMBER  # the aircraft: fixed, wings level when the ball is level
	draw_line(c - Vector2(rad * 0.62, 0), c - Vector2(rad * 0.2, 0), wing, 3.0)
	draw_line(c + Vector2(rad * 0.62, 0), c + Vector2(rad * 0.2, 0), wing, 3.0)
	draw_line(c - Vector2(rad * 0.2, 0), c - Vector2(rad * 0.2, 5.0), wing, 3.0)
	draw_line(c + Vector2(rad * 0.2, 0), c + Vector2(rad * 0.2, 5.0), wing, 3.0)
	draw_circle(c, 2.5, wing)
