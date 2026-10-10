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
var confirmation: ConfirmBox
var _pending_action := {}
var feedback: Label
var _return_focus: WeakRef
var _palette := ""
var _feedback_success := true


func setup(sess: Session) -> GameMenu:
	s = sess
	_palette = UIStyle.palette
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
	if is_inside_tree():
		var owner := get_viewport().gui_get_focus_owner()
		_return_focus = weakref(owner) if owner != null and not is_ancestor_of(owner) else null
	feedback.visible = false
	visible = true
	refresh()
	focus_action()


func close() -> void:
	if confirmation != null and confirmation.visible:
		confirmation.key("esc")
	_pending_action = {}
	visible = false
	if _return_focus != null:
		var owner: Control = _return_focus.get_ref() as Control
		if owner != null and owner.is_inside_tree() and owner.is_visible_in_tree():
			owner.grab_focus()
	closed.emit()


## Focus the first task control, retaining an explicit Close when content is empty.
func focus_action() -> void:
	var target := _first_focus(content)
	if target == null:
		target = _first_focus(hints)
	if target == null:
		target = close_button
	if target != null and target.is_inside_tree():
		target.grab_focus()


static func _first_focus(node: Node) -> Control:
	for child in node.get_children():
		if child is Control and child.visible:
			if child.focus_mode == Control.FOCUS_ALL and not (child is BaseButton and child.disabled):
				return child
			var nested := _first_focus(child)
			if nested != null:
				return nested
	return null


func _input(event: InputEvent) -> void:
	if not visible or not is_inside_tree() or (confirmation != null and confirmation.visible):
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and not is_ancestor_of(owner):
		return # A higher modal owns input.
	if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
		close()
		get_viewport().set_input_as_handled()
		return
	if owner == null or not content.is_ancestor_of(owner) or not (owner is DataTable or owner is ItemList):
		return
	for pair in [["ui_up", "up"], ["ui_down", "down"], ["ui_left", "left"], ["ui_right", "right"], ["ui_accept", "enter"]]:
		if event.is_action_pressed(pair[0], true):
			if not (event is InputEventKey and event.echo and pair[1] == "enter"):
				key(pair[1])
			get_viewport().set_input_as_handled()
			return


func _process(_dt: float) -> void:
	if visible and _palette != UIStyle.palette:
		_palette = UIStyle.palette
		theme = UIStyle.theme()
		title.add_theme_color_override("font_color", UIStyle.ACCENT)
		feedback.add_theme_color_override("font_color", UIStyle.GREEN if _feedback_success else UIStyle.RED)
		refresh()


func refresh() -> void:
	pass


func key(_k: String) -> void:
	pass


## A command result stays beside the action until the panel is reopened.
func show_feedback(message: String, success: bool) -> void:
	_feedback_success = success
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


## Shared read-only review + revalidated execution for committing decisions.
func perform_action(name: String, args := {}, role := Roles.PILOT) -> void:
	var action := s.describe_action(role, name, args)
	if not action.enabled:
		show_feedback(action.disabled_reason, false)
		return
	if confirmation == null:
		confirmation = ConfirmBox.new().setup("", "Confirm", "Cancel")
		add_child(confirmation)
		confirmation.answered.connect(_action_answered)
	_pending_action = action.duplicate(true)
	_pending_action.review_role = role
	confirmation.msg.text = str(action.label) + "\n\n" + str(action.preview)
	confirmation.yes_btn.text = str(action.label)
	confirmation.ask()

func _action_answered(yes: bool) -> void:
	var action := _pending_action
	_pending_action = {}
	if not yes or action.is_empty():
		return
	var role: String = action.get("review_role", Roles.PILOT)
	var fresh := s.describe_action(role, action.command, action.args)
	if not fresh.enabled:
		show_feedback(fresh.disabled_reason, false)
	elif fresh.preview != action.preview or fresh.label != action.label:
		show_feedback("State changed. Review the updated action before confirming.", false)
	else:
		var result: Array = s.command(role, action.command, action.args)
		var detail: String = str(result[1])
		if detail in ["", "ok"]:
			detail = str(fresh.preview)
		show_feedback(str(fresh.label) + ". " + detail if result[0] else str(result[1]), bool(result[0]))
	refresh()

func confirmation_key(k: String) -> bool:
	return confirmation.key(k) if confirmation != null and confirmation.visible else false
