class_name ConfirmBox
extends Control
## A bounded modal. Cancel is selected first; keyboard approval requires an
## explicit selection and a fresh activation after the opening frame.
signal answered(yes: bool)
var msg: Label
var yes_btn: Button
var no_btn: Button
var panel: PanelContainer
var scroller: ScrollContainer
var selected_yes := false
var _armed_frame := 0
var _fresh_mouse := false
var _opener: WeakRef
var _fitted_text := ""

func setup(text: String, yes_text := "Leave", no_text := "Stay") -> ConfirmBox:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.theme()
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.box(Color(0.07, 0.08, 0.11, 0.98), 8, UIStyle.ACCENT, 1, Vector4(22, 18, 22, 18)))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	scroller = ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroller)
	msg = UIStyle.label(text, 20, UIStyle.WHITE)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(msg)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	no_btn = Button.new()
	no_btn.text = "%s  (ESC)" % no_text
	no_btn.pressed.connect(func(): _answer(false))
	no_btn.focus_entered.connect(func(): selected_yes = false)
	row.add_child(no_btn)
	yes_btn = Button.new()
	yes_btn.text = yes_text
	yes_btn.pressed.connect(func():
		if _fresh_mouse:
			_answer(true))
	yes_btn.focus_entered.connect(func(): selected_yes = true)
	row.add_child(yes_btn)
	return self

func ask() -> void:
	var viewport := get_viewport()
	var opener: Control = viewport.gui_get_focus_owner() if viewport != null else null
	_opener = weakref(opener) if opener != null else null
	selected_yes = false
	_fresh_mouse = false
	_armed_frame = Engine.get_process_frames() + 1
	var bounds := get_viewport_rect().size if viewport != null else Vector2(1024, 768)
	panel.custom_minimum_size.x = minf(620.0, bounds.x * 0.84)
	_fit()
	visible = true
	_select(false)

## Size the scroll area to the wrapped message so short texts are never clipped; only text taller than
## 60% of the screen scrolls. The message can change while the box is open (a preview arriving).
func _fit() -> void:
	_fitted_text = msg.text
	var viewport := get_viewport()
	var bounds := get_viewport_rect().size if viewport != null else Vector2(1024, 768)
	var width := maxf(120.0, panel.custom_minimum_size.x - 44.0 - 16.0)
	var font := msg.get_theme_font("font")
	var size: int = msg.get_theme_font_size("font_size")
	var wrapped := font.get_multiline_string_size(msg.text, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, TextServer.BREAK_WORD_BOUND | TextServer.BREAK_MANDATORY | TextServer.BREAK_ADAPTIVE).y
	scroller.custom_minimum_size.y = clampf(wrapped + 14.0, 40.0, maxf(40.0, bounds.y * 0.6))

func _process(_dt: float) -> void:
	if not visible:
		return
	if msg.text != _fitted_text:
		_fit()
	# Refine the estimate with the label's own wrapped height once it has a real width.
	var bounds := get_viewport_rect().size
	var want := clampf(msg.get_minimum_size().y + 6.0, 40.0, maxf(40.0, bounds.y * 0.6))
	if absf(want - scroller.custom_minimum_size.y) > 1.0:
		scroller.custom_minimum_size.y = want

func _select(yes: bool) -> void:
	selected_yes = yes
	if is_inside_tree():
		(yes_btn if yes else no_btn).grab_focus()

func _answer(yes: bool) -> void:
	if not visible or (yes and (yes_btn.disabled or Engine.get_process_frames() <= _armed_frame)):
		return
	visible = false
	var opener = _opener.get_ref() if _opener != null else null
	if is_instance_valid(opener) and opener.is_inside_tree() and opener.is_visible_in_tree():
		opener.grab_focus()
	answered.emit(yes)

## Owners may forward abstract navigation; Enter activates the selected choice.
func key(k: String) -> bool:
	if not visible:
		return false
	match k:
		"esc": _answer(false)
		"left", "up": _select(false)
		"right", "down": _select(true)
		"enter":
			if Engine.get_process_frames() > _armed_frame:
				_answer(selected_yes)
	return true

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventJoypadButton and event.pressed:
		var keys := {JOY_BUTTON_B: "esc", JOY_BUTTON_A: "enter", JOY_BUTTON_DPAD_LEFT: "left", JOY_BUTTON_DPAD_UP: "left", JOY_BUTTON_DPAD_RIGHT: "right", JOY_BUTTON_DPAD_DOWN: "right"}
		if keys.has(event.button_index):
			key(keys[event.button_index])
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_fresh_mouse = Engine.get_process_frames() > _armed_frame and yes_btn.get_global_rect().has_point(event.position)
		return  # GUI consumes the click on the full-screen shade or buttons.
	if event is InputEventKey and event.echo:
		get_viewport().set_input_as_handled()
		return
	if event.is_pressed():
		if event.is_action_pressed("ui_cancel"):
			key("esc")
		elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
			key("left")
		elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_focus_next"):
			if selected_yes:
				no_btn.grab_focus()
			else:
				yes_btn.grab_focus()
		elif event.is_action_pressed("ui_accept"):
			key("enter")
	get_viewport().set_input_as_handled()
