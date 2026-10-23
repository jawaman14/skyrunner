extends Control
## BLACKFILE Seven Boxes — a deliberately self-contained clickable Godot investigation.
## All operational characters, documents and locations are fictional. No SkyRunner runtime touched.

const CaseEngine = preload("res://case_engine.gd")
const CASE_PATH := "res://data/seven_boxes.json"
const SAVE_PATH := "user://blackfile_seven_boxes_save.json"
const INK := Color("#d8e3ed")
const MUTED := Color("#9db0bf")
const CYAN := Color("#7dd8de")
const PAPER := Color("#151f2b")

var engine = CaseEngine.new()
var route := "field"
var room := "Archive Annex"
var content: VBoxContainer
var rooms_box: VBoxContainer
var actions_box: VBoxContainer
var evidence_box: VBoxContainer
var footer_label: Label
var route_button: Button
var banner: Label
var status_line: Label

func _ready() -> void:
	get_window().title = "BLACKFILE | SEVEN BOXES"
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CASE_PATH))
	if not (parsed is Dictionary) or not engine.configure(parsed):
		push_error("BLACKFILE mission data failed validation: " + engine.last_error)
		return
	_build_ui()
	_refresh("Choose a room and review evidence. The underlying case is fictional.")

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = Color("#344457")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _label(value: String, size: int = 15, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(title: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = title
	b.custom_minimum_size.y = 38
	b.pressed.connect(callback)
	return b

func _heading(name: String) -> Label:
	return _label(name, 19, CYAN)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#0c141c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	content.add_child(top)
	var masthead := VBoxContainer.new()
	masthead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(masthead)
	masthead.add_child(_label("BLACKFILE  /  CASE MK-01", 26, CYAN))
	masthead.add_child(_label("SEVEN BOXES · 04 AUG 1977 · FICTIONAL RECORDS ANNEX", 12, MUTED))
	route_button = _button("MODE: FIELD", _toggle_route)
	top.add_child(route_button)
	top.add_child(_button("SAVE", _save_case))
	top.add_child(_button("LOAD", _load_case))
	top.add_child(_button("RESTART", _restart_case))

	banner = _label("", 13, Color("#eac78a"))
	content.add_child(banner)
	status_line = _label("", 14, INK)
	content.add_child(status_line)

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 10)
	content.add_child(main)

	var left := _panel()
	left.custom_minimum_size.x = 240
	main.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 12)
	left.add_child(lv)
	lv.add_child(_heading("LOCATION"))
	lv.add_child(_label("Choose where you investigate. Field mode requires visiting a room; delegated mode uses the same rules without travel.", 13, MUTED))
	rooms_box = VBoxContainer.new()
	rooms_box.add_theme_constant_override("separation", 7)
	lv.add_child(rooms_box)
	lv.add_child(_heading("BRIEFING"))
	var brief := _label(str(engine.case_data["briefing"]), 13)
	lv.add_child(brief)

	var middle := _panel()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(middle)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 8)
	middle.add_child(mv)
	mv.add_child(_heading("CASE ORDERS"))
	mv.add_child(_label("Orders and outcomes are recorded through one deterministic case-command gateway.", 12, MUTED))
	var action_scroll := ScrollContainer.new()
	action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mv.add_child(action_scroll)
	actions_box = VBoxContainer.new()
	actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_box.add_theme_constant_override("separation", 6)
	action_scroll.add_child(actions_box)

	var right := _panel()
	right.custom_minimum_size.x = 350
	main.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 9)
	right.add_child(rv)
	rv.add_child(_heading("DOSSIER / PROVENANCE"))
	var evidence_scroll := ScrollContainer.new()
	evidence_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(evidence_scroll)
	evidence_box = VBoxContainer.new()
	evidence_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evidence_box.add_theme_constant_override("separation", 8)
	evidence_scroll.add_child(evidence_box)

	var bottom := _panel()
	content.add_child(bottom)
	footer_label = _label("", 13)
	bottom.add_child(footer_label)

func _toggle_route() -> void:
	route = "delegated" if route == "field" else "field"
	_refresh("Mode changed. Delegated and field routes use the same costs and results.")

func _set_room(name: String) -> void:
	room = name
	_refresh("Entered " + name + ".")

func _attempt(id: String) -> void:
	var result: Dictionary = engine.command("analyst", route, id, room)
	_refresh(str(result.get("message", "No result")))

func _refresh(message: String) -> void:
	route_button.text = "MODE: " + route.to_upper()
	banner.text = "FICTIONAL RECONSTRUCTION — not a CIA document or an account of a real annex investigation."
	var m: Dictionary = engine.state["metrics"]
	status_line.text = "BUDGET  $%s   |   DAY  %s   |   EVIDENCE  %s   |   OVERSIGHT  %s   |   PRIVACY  %s   |   PRESERVATION  %s" % [engine.state["balances"]["case_fund"], m["days"], m["evidence"], m["oversight"], m["privacy"], m["preservation"]]
	for child in rooms_box.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	for name in engine.case_data["rooms"]:
		var chosen: String = str(name)
		var b := _button(("● " if name == room else "   ") + name, func(): _set_room(chosen))
		rooms_box.add_child(b)
	for child in actions_box.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	for a in engine.case_data["actions"]:
		var id := str(a["id"])
		var cost := int(a["cost"])
		var label_text := "%s     $%s  ·  %s" % [a["title"], cost, a["room"]]
		var b := _button(label_text, func(): _attempt(id))
		var reason := engine.available(id, route, room)
		b.disabled = not reason.is_empty()
		b.tooltip_text = reason if not reason.is_empty() else str(a.get("report", ""))
		actions_box.add_child(b)
		if not reason.is_empty():
			actions_box.add_child(_label("   " + reason, 11, MUTED))
	for child in evidence_box.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	evidence_box.add_child(_label("DOCUMENTS (fictional artefacts)", 14, CYAN))
	if engine.state["unlocked_docs"].is_empty():
		evidence_box.add_child(_label("No artefacts catalogued. Inventory the recovered boxes.", 12, MUTED))
	for doc in engine.case_data["documents"]:
		if doc["id"] in engine.state["unlocked_docs"]:
			evidence_box.add_child(_label(str(doc["title"]) + " [FICTION]", 13))
			evidence_box.add_child(_label(str(doc["body"]), 11, MUTED))
	evidence_box.add_child(_label("HISTORICAL CLAIM REGISTER", 14, CYAN))
	for claim in engine.case_data["claims"]:
		evidence_box.add_child(_label("[%s] %s" % [claim["status"], claim["text"]], 12))
		evidence_box.add_child(_label("Source: " + ", ".join(PackedStringArray(claim["source_ids"])) + ". " + str(claim["note"]), 11, MUTED))
	evidence_box.add_child(_label("RESEARCH SOURCES (modern reader)", 14, CYAN))
	for source in engine.case_data["sources"]:
		var url := str(source["url"])
		var b := _button("OPEN " + str(source["id"]) + " · " + str(source["title"]), func(): OS.shell_open(url))
		b.tooltip_text = "Opens an external reference in your browser; may require Internet access."
		evidence_box.add_child(b)
	var recent := "No orders issued."
	if not engine.audit.is_empty():
		var e: Dictionary = engine.audit[-1]
		recent = "Latest: %s via %s, day %s. %s" % [e["action"], e["route"], e["day"], e["report"]]
	footer_label.text = ("CASE CLOSED: " + str(engine.state["ending"]) + "  |  " if engine.state["finished"] else "") + message + "\n" + recent

func _save_case() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		_refresh("SAVE ERROR: Cannot open file (" + str(FileAccess.get_open_error()) + ")")
		return
	f.store_string(JSON.stringify(engine.snapshot(), "  "))
	f.close()
	_refresh("Case saved to " + SAVE_PATH)

func _load_case() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_refresh("No saved investigation found.")
		return
	var doc = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (doc is Dictionary):
		_refresh("SAVE ERROR: malformed JSON; current session unchanged")
		return
	if not engine.restore(engine.case_data, doc):
		_refresh("SAVE ERROR: " + engine.last_error + "; current session unchanged")
		return
	_refresh("Investigation restored and audited from its event history.")

func _restart_case() -> void:
	engine.configure(engine.case_data)
	route = "field"
	room = "Archive Annex"
	_refresh("New local investigation started; previous save remains on disk until you press SAVE.")
