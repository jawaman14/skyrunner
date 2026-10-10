class_name PhoneNotify
extends VBoxContainer
## Phone notifications, in the manner of a smartphone's banners: a card slides in from the right with the sender's round
## icon, their name, the message, and - when there is something to decide - key caps for the answer ([Y] take it,
## [N] leave it). Instead of a character walking up to you with a pop-up, the phone buzzes. The newest card with answers
## is the one Y and N reply to; cards fade by themselves (the ones with a decision wait longer).
##
## PilotApp owns one, anchored on the right above the radar, and feeds it: new contacts, the Family's offers, calls that
## have come in. `push` returns the card; `answer(key)` returns the action id the key chose (or "").

signal answered(action: String, data: Variant)

const MAX_CARDS := 2
const INK := Color(0.04, 0.045, 0.07, 0.92)
const ICON_COLORS := {"phone": Color(0.3, 0.9, 0.5), "family": Color(1.0, 0.75, 0.2), "law": Color(0.4, 0.55, 1.0), "lab": Color(0.8, 0.4, 1.0),
	"job": Color(0.35, 1.0, 0.4), "bank": Color(0.5, 0.9, 1.0), "alert": Color(1.0, 0.3, 0.25)}

var _cards: Array = []  ## [{node, until, actions, data}]
var history: Array = []  ## every card ever pushed, oldest first ({sender, body, kind}): the phone's Messages app reads it


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	alignment = BoxContainer.ALIGNMENT_END


## `actions`: [[key_label, action_id, caption], ...], e.g. [["Y", "accept", "take it"], ["N", "decline", "leave it"]].
func push(sender: String, body: String, kind := "phone", actions: Array = [], data: Variant = null, ttl := 7.0) -> PanelContainer:
	history.append({"sender": sender, "body": body, "kind": kind})
	if history.size() > 60:
		history.pop_front()
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(300, 0)
	card.add_theme_stylebox_override("panel", UIStyle.box(INK, 14, Color(1, 1, 1, 0.1), 1, Vector4(12, 10, 12, 10)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.add_child(_icon(sender, ICON_COLORS.get(kind, ICON_COLORS.phone)))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)
	col.add_child(UIStyle.label(sender, 15, UIStyle.WHITE))
	var msg := UIStyle.label(body, 14, UIStyle.DIM)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(214, 0)
	col.add_child(msg)
	if not actions.is_empty():
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override("separation", 14)
		keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for a in actions:
			var kc := UIStyle.label("[%s] %s" % [a[0], a[2]], 13, UIStyle.CYAN if a[1] != "decline" else UIStyle.CAPTION)
			keys.add_child(kc)
		col.add_child(keys)
	add_child(card)
	card.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.18)
	_cards.append({"node": card, "until": Time.get_ticks_msec() / 1000.0 + (ttl if actions.is_empty() else ttl * 3.0), "actions": actions, "data": data})
	while _cards.size() > MAX_CARDS:
		_drop(_cards[0])
	return card


static func _icon(sender: String, col: Color) -> Control:
	var icon := Panel.new()
	icon.custom_minimum_size = Vector2(38, 38)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_theme_stylebox_override("panel", UIStyle.box(col, 19, Color(1, 1, 1, 0.25), 1, Vector4(0, 0, 0, 0)))
	var l := UIStyle.label(sender.substr(0, 1).to_upper(), 20, Color(0.05, 0.05, 0.08))
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_child(l)
	return icon


## Is there a card waiting for an answer?
func asking() -> bool:
	for c in _cards:
		if not c.actions.is_empty():
			return true
	return false


## The newest card with a decision on it takes the key. Returns the action id, or "" if no card wanted it.
func answer(key: String) -> String:
	for i in range(_cards.size() - 1, -1, -1):
		var c: Dictionary = _cards[i]
		for a in c.actions:
			if str(a[0]).to_upper() == key.to_upper():
				var id := str(a[1])
				answered.emit(id, c.data)
				_drop(c)
				return id
	return ""


func _drop(c: Dictionary) -> void:
	_cards.erase(c)
	var n: Control = c.node
	if is_instance_valid(n):
		var tw := n.create_tween()
		tw.tween_property(n, "modulate:a", 0.0, 0.2)
		tw.tween_callback(n.queue_free)


func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for c in _cards.duplicate():
		if now >= float(c.until):
			_drop(c)


## Take away every card carrying this `data` (the offer it was about has gone).
func drop_data(data: Variant) -> void:
	for c in _cards.duplicate():
		if c.data == data:
			_drop(c)


func has_data(data: Variant) -> bool:
	return _cards.any(func(c): return c.data == data)


func count() -> int:
	return _cards.size()
