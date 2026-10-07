class_name TalkBalloon
extends CanvasLayer
## A conversation on screen: the speaker's name in neon script, the line, and
## wrapped, scrolling answers (Up/Down/Enter, 1-9 shortcuts, or a click). ENTER moves
## on when there's nothing to choose; ESC walks away. Drives Talk's Dialogue
## Manager scripts one line at a time, re-reading the game (State.refresh)
## before each so the numbers are current.

signal finished

var resource: DialogueResource
var state: Talk.State
var line: DialogueLine = null
var lines_shown := 0
var panel: PanelContainer
var who: Label
var text: Label
var choices: VBoxContainer
var hint: Label
var scroll: ScrollContainer
var selected := 0
var busy := false
var closed := false
var _palette := ""
var review: ActionReview
var leave: Button
var _answers: Array = []  ## the DialogueResponses offered now


func _ready() -> void:
	layer = 60
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.box(Color(0.06, 0.02, 0.09, 0.94), 10, UIStyle.PINK, 2, Vector4(22, 14, 22, 14)))
	panel.anchor_left = 0.18
	panel.anchor_right = 0.82
	panel.anchor_top = 0.35
	panel.anchor_bottom = 0.97
	panel.offset_top = 0
	panel.offset_bottom = 0
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	who = UIStyle.title("", 26, UIStyle.PINK)
	v.add_child(who)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	text = UIStyle.label("", 19, UIStyle.WHITE)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(text)
	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation", 4)
	content.add_child(choices)
	hint = UIStyle.caption("")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	leave = Button.new()
	leave.text = "Leave / Back"
	leave.pressed.connect(_close)
	v.add_child(leave)
	_apply_palette()


func _apply_palette() -> void:
	_palette = UIStyle.palette
	panel.get_parent().theme = UIStyle.theme()
	panel.add_theme_stylebox_override("panel", UIStyle.box(Color(0.06, 0.02, 0.09, 0.94), 10, UIStyle.PINK, 2, Vector4(22, 14, 22, 14)))
	who.add_theme_color_override("font_color", UIStyle.PINK)


func _process(_dt: float) -> void:
	if _palette != UIStyle.palette:
		_apply_palette()


## Start `title` of `resource` with `state`; `finished` fires when it ends.
func start(resource_: DialogueResource, title: String, state_: Talk.State) -> void:
	resource = resource_
	state = state_
	await _next(title)


func _next(id: String) -> void:
	if closed:
		return
	busy = true
	hint.text = "Waiting for result…   ESC leave"
	for button in choices.get_children():
		button.disabled = true
	if state != null:
		state.refresh()
	var next_line = await Talk.manager().get_next_dialogue_line(resource, id, [state])
	if closed:
		return
	line = next_line
	busy = false
	if line == null:
		_close()
		return
	if line.text != "" or line.responses.is_empty():
		# (a line that's only answers keeps the last speaker's words on screen)
		lines_shown += 1
		who.text = line.character
		who.visible = line.character != ""
		text.text = line.text
	for c in choices.get_children():
		choices.remove_child(c)
		c.queue_free()
	_answers = line.responses.filter(func(r): return r.is_allowed)
	for i in _answers.size():
		var b := Button.new()
		b.text = "%d   %s" % [i + 1, _answers[i].text]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.focus_entered.connect(func():
			selected = i
			scroll.ensure_control_visible(b))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(choose.bind(i))
		choices.add_child(b)
	hint.text = "Up/Down choose   ENTER answer   1–9 shortcuts   ESC leave" if not _answers.is_empty() else "ENTER go on   ESC walk away"
	Speech.line(line.character if line.text != "" else "", line.text, _answers.map(func(r): return str(r.text)))
	selected = 0
	scroll.scroll_vertical = 0
	if not _answers.is_empty():
		choices.get_child(0).grab_focus()


## Answer with the i-th allowed response.
func choose(i: int) -> void:
	if closed or busy or line == null or i < 0 or i >= _answers.size():
		return
	var snd = get_parent().get("sound") if get_parent() != null else null
	if snd != null:
		snd.click("choose")
	await _next(_answers[i].next_id)


## Move past a line with nothing to answer.
func advance() -> void:
	if closed or busy or line == null or not _answers.is_empty():
		return
	await _next(line.next_id)


func _close() -> void:
	if closed:
		return
	closed = true
	if state != null:
		state.cancelled = true
	line = null
	finished.emit()
	queue_free()


func _exit_tree() -> void:
	closed = true
	if state != null:
		state.cancelled = true


func _input(ev: InputEvent) -> void:
	if is_instance_valid(review):
		return  # The higher confirmation owns input, including Cancel.
	if closed or (ev is InputEventKey and ev.echo) or not ev.is_pressed():
		return
	if ev.is_action_pressed("ui_cancel"):
		_close()
	elif busy:
		# Pending UI controls must not fall through into gameplay controls.
		if ev.is_action_pressed("ui_accept") or ev.is_action_pressed("ui_up") or ev.is_action_pressed("ui_down") or (ev is InputEventKey and ev.keycode >= KEY_1 and ev.keycode <= KEY_9):
			get_viewport().set_input_as_handled()
		return
	elif ev.is_action_pressed("ui_up") or ev.is_action_pressed("ui_down"):
		if not _answers.is_empty():
			selected = posmod(selected + (1 if ev.is_action_pressed("ui_down") else -1), _answers.size())
			choices.get_child(selected).grab_focus()
	elif ev.is_action_pressed("ui_accept"):
		if leave.has_focus():
			_close()
		elif _answers.is_empty():
			advance()
		else:
			choose(selected)
	elif ev is InputEventKey and ev.keycode >= KEY_1 and ev.keycode <= KEY_9:
		choose(ev.keycode - KEY_1)
	else:
		return
	get_viewport().set_input_as_handled()
