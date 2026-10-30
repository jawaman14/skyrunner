class_name FlightDebrief
extends PanelContainer
## The card after a landing: how long, how soft, how much fuel, what it paid, the pilot's own records for the route and Benny's time
## to beat. Shown for SHOW_S, then it fades away; nothing to press.

const SHOW_S := 9.0

var _text: Label
var _left := 0.0


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.box(Color(0.03, 0.035, 0.05, 0.92), 10, Color(1, 0.82, 0.25, 0.6), 2, Vector4(16, 12, 16, 12)))
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -230.0
	offset_right = 230.0
	offset_top = 90.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text = UIStyle.label("", 15, UIStyle.WHITE, UIStyle.mono())
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_text)
	visible = false


## `d`: the "landed" event's data; `rec`: RouteBests.record's result; `benny`: Benny's seconds for the route (0: none).
func show_flight(d: Dictionary, rec: Dictionary, benny: float, from_name: String, to_name: String) -> void:
	var secs: float = float(d.get("seconds", 0.0))
	var fpm: float = float(d.get("touchdown_fpm", 0.0))
	var lines := ["%s -> %s" % [from_name, to_name],
		"Flight   %s%s" % [RouteBests.clock(secs), "   NEW BEST" if rec.get("new_time", false) else "   best %s" % RouteBests.clock(float(rec.get("best_seconds", secs)))],
		"Landing  %d fpm %s%s" % [int(fpm), "butter" if fpm < 150 else ("firm" if fpm < 400 else "hard"), "   SOFTEST YET" if rec.get("new_soft", false) else ""],
		"Fuel     %d lb" % int(float(d.get("fuel_used_lb", 0.0)))]
	var pay := int(d.get("pay", 0))
	if pay != 0:
		lines.append("Paid     %s$%s" % ["+" if pay > 0 else "-", Py.money(absi(pay))])
	if benny > 0.0:
		lines.append("Benny's time %s   %s" % [RouteBests.clock(benny), "beaten!" if secs <= benny else "%s to find" % RouteBests.clock(secs - benny)])
	_text.text = "\n".join(lines)
	visible = true
	modulate.a = 1.0
	_left = SHOW_S


func _process(dt: float) -> void:
	if not visible:
		return
	_left -= dt
	if _left < 1.0:
		modulate.a = maxf(0.0, _left)
	if _left <= 0.0:
		visible = false
