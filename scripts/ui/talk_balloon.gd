class_name TalkBalloon
extends CanvasLayer
## A conversation, on the phone: a handset slides up on the right with the contact's round icon and name, their lines as
## message bubbles on the left, your answers as pink bubbles on the right, and the answers you can still give as buttons
## underneath (Up/Down and ENTER, 1-9, or a click). ENTER or SPACE moves on when there is nothing to choose; ESC or the
## Leave button hangs up. Drives Talk's Dialogue Manager scripts one line at a time, re-reading the game (State.refresh)
## before each so the numbers are current; while the next line is being worked out the answers are disabled and swallow
## their keys. (It used to be a box across the bottom of the screen with the character's name in neon script.)

signal finished

const PHONE_W := 400.0
const BUBBLE_W := 270.0

var resource: DialogueResource
var state: Talk.State
var line: DialogueLine = null
var lines_shown := 0
var panel: PanelContainer
var who: Label  ## the contact's name in the header
var text: Label  ## the newest of their lines
var choices: VBoxContainer
var hint: Label
var thread: VBoxContainer
var scroll: ScrollContainer
var status: Label
var selected := 0  ## the answer Up/Down has reached
var busy := false  ## waiting for the next line: answers are disabled
var closed := false
var review: ActionReview  ## a confirmation over the call (Talk sets it); it owns input while it is up
var leave: Button
var _palette := ""
var _avatar: Label
var _avatar_panel: Panel
var _answers: Array = []  ## the DialogueResponses offered now
var _speaker := ""
var _t := 0.0


func _ready() -> void:
	layer = 60
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.box(Color(0.03, 0.035, 0.055, 0.97), 28, Color(1, 1, 1, 0.22), 2, Vector4(16, 14, 16, 14)))
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -PHONE_W - 24.0
	panel.offset_right = -24.0
	panel.offset_top = -560.0
	panel.offset_bottom = -24.0
	# pinned to the corner: when the contents need more room the handset grows left and up, never off the screen
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	# the header: who you are talking to
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	_avatar_panel = Panel.new()
	_avatar_panel.custom_minimum_size = Vector2(44, 44)
	_avatar = UIStyle.label("", 22, Color(0.05, 0.05, 0.08))
	_avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avatar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avatar_panel.add_child(_avatar)
	head.add_child(_avatar_panel)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	who = UIStyle.label("", 18, UIStyle.WHITE)
	names.add_child(who)
	status = UIStyle.caption("calling...")
	names.add_child(status)
	v.add_child(HSeparator.new())
	# the thread of messages
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(PHONE_W - 8.0, 250)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	# the thread and, under it, the answers: one scrolling column, so eleven long answers never push the handset off
	# the screen and the Leave button below stays in reach
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	thread = VBoxContainer.new()
	thread.add_theme_constant_override("separation", 6)
	thread.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(thread)
	scroll.get_v_scroll_bar().changed.connect(func(): scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value))  # stay at the newest
	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation", 5)
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(choices)
	hint = UIStyle.caption("")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	leave = Button.new()
	leave.text = "Leave / Back"
	leave.pressed.connect(_close)
	v.add_child(leave)
	_apply_palette()


## The palette can change mid-call (Settings): re-theme the handset.
func _apply_palette() -> void:
	_palette = UIStyle.palette
	panel.get_parent().theme = UIStyle.theme()
	panel.add_theme_stylebox_override("panel", UIStyle.box(Color(0.03, 0.035, 0.055, 0.97), 28, Color(1, 1, 1, 0.22), 2, Vector4(16, 14, 16, 14)))
	who.add_theme_color_override("font_color", UIStyle.PINK)


func _process(dt: float) -> void:
	if _palette != UIStyle.palette:
		_apply_palette()
	if line == null:
		return
	_t += dt
	if status != null:
		status.text = "mobile   %d:%02d" % [int(_t / 60.0), int(_t) % 60]


## Start `title` of `resource` with `state`; `finished` fires when it ends.
func start(resource_: DialogueResource, title: String, state_: Talk.State) -> void:
	resource = resource_
	state = state_
	await _next(title)


static func _avatar_color(name_: String) -> Color:
	var h := float(absi(name_.hash()) % 360) / 360.0
	return Color.from_hsv(h, 0.55, 0.95)


func _set_contact(name_: String) -> void:
	_speaker = name_
	who.text = name_
	_avatar.text = name_.substr(0, 1).to_upper()
	_avatar_panel.add_theme_stylebox_override("panel", UIStyle.box(_avatar_color(name_), 22, Color(1, 1, 1, 0.3), 1, Vector4(0, 0, 0, 0)))


## One message in the thread: theirs on the left, yours on the right, a stage direction centred.
func _bubble(msg: String, side := "them", name_ := "") -> Label:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := PanelContainer.new()
	var bg := Color(0.14, 0.15, 0.21)
	var fg := UIStyle.WHITE
	if side == "me":
		bg = Color(0.85, 0.26, 0.6, 0.95)
		fg = Color(1, 1, 1)
	elif side == "note":
		bg = Color(0.1, 0.1, 0.13, 0.8)
		fg = UIStyle.CAPTION
	box.add_theme_stylebox_override("panel", UIStyle.box(bg, 16, Color(0, 0, 0, 0), 0, Vector4(12, 8, 12, 8)))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	box.add_child(col)
	if name_ != "" and side == "them":
		col.add_child(UIStyle.label(name_, 12, _avatar_color(name_)))
	var l := UIStyle.label(msg, 16, fg)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(minf(BUBBLE_W, 40.0 + 8.0 * msg.length()), 0)
	col.add_child(l)
	if side == "me":
		row.add_child(pad)
		row.add_child(box)
	elif side == "note":
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(box)
	else:
		row.add_child(box)
		row.add_child(pad)
	thread.add_child(row)
	return l


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
		if line.character != "" and _speaker == "":
			_set_contact(line.character)
		if line.text != "":
			text = _bubble(line.text, "them" if line.character != "" else "note", line.character if line.character != _speaker else "")
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
	hint.text = "UP/DOWN, 1-%d reply   ESC hang up" % _answers.size() if not _answers.is_empty() else "ENTER next   ESC hang up"
	# keep the thread's height sensible: the answers take what they need, the thread the rest
	var room: float = panel.get_viewport().get_visible_rect().size.y - 48.0 if panel.get_viewport() != null else 700.0
	panel.offset_top = -minf(250.0 + 150.0 + 44.0 * _answers.size(), room)
	while thread.get_child_count() > 40:  # a long call forgets its oldest messages
		thread.get_child(0).queue_free()
		thread.remove_child(thread.get_child(0))
	selected = 0
	if not _answers.is_empty():
		choices.get_child(0).grab_focus()


## Answer with the i-th allowed response.
func choose(i: int) -> void:
	if closed or busy or line == null or i < 0 or i >= _answers.size():
		return
	var snd = get_parent().get("sound") if get_parent() != null else null
	if snd != null:
		snd.click("choose")
	_bubble(str(_answers[i].text), "me")
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
