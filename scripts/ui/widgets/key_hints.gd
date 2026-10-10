class_name KeyHints
extends HFlowContainer
## The one footer style: key caps with what they do ("ENTER  issue"). Each chip is
## also a button - clicking it emits `hint_pressed(action)`, so every hotkey has a
## mouse equivalent.
##
##   hints.set_hints([["ENTER", "issue", "enter"], ["ESC", "close", "esc"]])

signal hint_pressed(action: String)

var _last: Array = []


func _init() -> void:
	add_theme_constant_override("h_separation", 14)
	add_theme_constant_override("v_separation", 6)
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_hints(hints: Array) -> void:
	if hints == _last:
		return
	_last = hints.duplicate(true)
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for h in hints:
		add_child(_chip(str(h[0]), str(h[1]), str(h[2]) if h.size() > 2 else ""))


func actions() -> Array:
	return _last.map(func(h): return str(h[2]) if h.size() > 2 else "")


func press(action: String) -> void:
	hint_pressed.emit(action)


func _chip(key: String, text: String, action: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UIStyle.box(UIStyle.SURFACE_HI, 4, Color(1, 1, 1, 0.22), 1, Vector4(6, 1, 6, 2))
	sb.border_width_bottom = 2
	cap.add_theme_stylebox_override("panel", sb)
	var kl := UIStyle.label(key, 12, UIStyle.WHITE, UIStyle.mono())
	cap.add_child(kl)
	row.add_child(cap)
	row.add_child(UIStyle.label(text, 13, UIStyle.CAPTION))
	if action == "":
		return row
	var button := Button.new()
	button.tooltip_text = "click or press %s" % key
	button.accessibility_name = "%s: %s" % [key, text]
	button.custom_minimum_size = row.get_combined_minimum_size() + Vector2(12, 12)
	button.custom_minimum_size.y = maxf(UIStyle.TOUCH_MIN, button.custom_minimum_size.y)
	button.pressed.connect(func(): hint_pressed.emit(action))
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_top = 6
	row.offset_right = -6
	row.offset_bottom = -6
	return button
