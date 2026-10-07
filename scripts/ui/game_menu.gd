class_name GameMenu
extends PanelContainer
## Base for the ground menus: a titled panel that the pilot app opens with a
## hotkey, driven by mouse or keyboard (`key(name)` receives up/down/left/right/
## enter/a/+/-/f). Subclasses build their content in `_build` and refresh it
## from the session in `refresh`. The footer is a row of key caps (`hints`);
## clicking one does what the key does. `footer` is a one-line note above it.

signal closed

var s: Session
var title: Label
var content: VBoxContainer
var subtitle: Label
var footer: Label
var hints: KeyHints
var close_button: Button
var feedback: Label


func setup(sess: Session) -> GameMenu:
	s = sess
	theme = UIStyle.theme()
	add_theme_stylebox_override("panel", UIStyle.surface_box(Color(0.03, 0.04, 0.06, 0.97), true))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor_left = 0.07
	anchor_right = 0.93
	anchor_top = 0.07
	anchor_bottom = 0.93
	custom_minimum_size = Vector2(720, 480)
	offset_left = 0
	offset_right = 0
	offset_top = 0
	offset_bottom = 0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UIStyle.SPACE_MD)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIStyle.SPACE_MD)
	v.add_child(head)
	title = UIStyle.title("", 30)
	head.add_child(title)
	subtitle = UIStyle.label("", 15, UIStyle.CAPTION)
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(subtitle)
	close_button = Button.new()
	close_button.text = "Close  [Esc]"
	close_button.tooltip_text = "Close this panel and return to the game"
	close_button.custom_minimum_size = Vector2(112, UIStyle.TOUCH_MIN)
	close_button.pressed.connect(close)
	head.add_child(close_button)
	var rule := ColorRect.new()
	rule.color = Color(UIStyle.ACCENT.r, UIStyle.ACCENT.g, UIStyle.ACCENT.b, 0.35)
	rule.custom_minimum_size = Vector2(0, 1)
	v.add_child(rule)
	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", UIStyle.SPACE_SM)
	v.add_child(content)
	feedback = UIStyle.label("", 15, UIStyle.GREEN)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.visible = false
	v.add_child(feedback)
	footer = UIStyle.label("", 14, UIStyle.CAPTION)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(footer)
	hints = KeyHints.new()
	hints.hint_pressed.connect(func(a):
		if a == "esc":
			close()
		else:
			key(a))
	v.add_child(hints)
	_build()
	visible = false
	return self


func _build() -> void:
	pass


func open() -> void:
	feedback.visible = false
	visible = true
	refresh()
	# A predictable initial focus makes keyboard/controller navigation visible
	# immediately instead of leaving focus wherever the previous screen had it.
	if close_button != null and close_button.is_inside_tree():
		close_button.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	pass


func key(_k: String) -> void:
	pass


## A command result stays beside the action until the panel is reopened.
func show_feedback(message: String, success: bool) -> void:
	feedback.text = ("Done: " if success else "Not completed: ") + message
	feedback.add_theme_color_override("font_color", UIStyle.GREEN if success else UIStyle.RED)
	feedback.visible = true


## A table for a menu (see DataTable).
static func make_table(columns: Array) -> DataTable:
	return DataTable.new().setup(columns)


## Keyboard step through a DataTable or an ItemList.
static func list_move(l, d: int) -> void:
	if l is DataTable:
		l.move(d)
		return
	var n: int = l.item_count
	if n == 0:
		return
	var cur: int = l.get_selected_items()[0] if l.is_anything_selected() else 0
	var nxt := posmod(cur + d, n)
	for k in n:  # skip non-selectable separators
		if l.is_item_selectable(nxt):
			break
		nxt = posmod(nxt + d, n)
	l.select(nxt)
	l.ensure_current_is_visible()


static func selected(l) -> int:
	if l is DataTable:
		return l.selected_row()
	return l.get_selected_items()[0] if l.is_anything_selected() else -1
