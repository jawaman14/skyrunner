class_name PauseMenu
extends CanvasLayer
## ESC: the pause menu - resume, save, load the last save, settings (graphics,
## volume, colours, the controls panel), and quit to the lobby or the desktop.
## The owner decides what's offered (`setup`) and acts on `chosen(action)`:
## "resume", "save", "load", "lobby", "desktop", "controls". Settings are
## applied and saved here (user://settings.cfg). Keyboard: UP/DOWN move, ENTER
## presses, LEFT/RIGHT change a setting, ESC resumes.

signal chosen(action: String)

const GRAPHICS := ["high", "medium", "low"]
const VOLUMES := [1.0, 0.75, 0.5, 0.25, 0.0]

var panel: PanelContainer
var status: Label
var buttons: Array[Button] = []
var confirm: ConfirmBox
var _pending := ""  ## an action waiting for the confirm box
var _graphics_btn: Button = null
var _volume_btn: Button = null
var _palette_btn: Button = null
var _offer := {}


## `offer`: which rows to show - {save, load, graphics, controls, lobby} (bools);
## `note`: a line under the title ("Paused", "The game runs on: friends are flying").
func setup(offer: Dictionary, note := "Paused") -> PauseMenu:
	_offer = offer
	layer = 60  # over the HUD and ground menus, under the controls panel (70)
	name = "PauseMenu"
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIStyle.theme()
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.box(Color(0.06, 0.02, 0.09, 0.96), 10, UIStyle.ACCENT, 2, Vector4(28, 20, 28, 20)))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(380, 0)
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UIStyle.title("Skyrunner", 40, UIStyle.ACCENT))
	status = UIStyle.caption(note)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(status)
	_add(v, "Resume", func(): chosen.emit("resume"))
	if offer.get("save", false):
		_add(v, "Save game", func(): chosen.emit("save"))
	if offer.get("load", false):
		_add(v, "Load last save", func(): _ask("load", "Load the last save? Anything since then is lost.", "Load"))
	v.add_child(UIStyle.caption("Settings"))
	if offer.get("graphics", false):
		_graphics_btn = _add(v, "", func(): _step_graphics(1))
	_volume_btn = _add(v, "", func(): _step_volume(1))
	_palette_btn = _add(v, "", _toggle_palette)
	if offer.get("controls", false):
		_add(v, "Controls (F8)", func(): chosen.emit("controls"))
	v.add_child(HSeparator.new())
	if offer.get("lobby", false):
		_add(v, "Quit to lobby", func(): _ask("lobby", "Quit to the lobby?%s" % (" The game is saved first." if offer.get("save", false) else ""), "Quit"))
	_add(v, "Quit to desktop", func(): _ask("desktop", "Quit to the desktop?%s" % (" The game is saved first." if offer.get("save", false) else ""), "Quit"))
	confirm = ConfirmBox.new().setup("", "Yes", "No")
	confirm.answered.connect(func(yes: bool):
		var a := _pending
		_pending = ""
		if yes:
			chosen.emit(a)
		elif not buttons.is_empty():
			buttons[0].grab_focus())
	root.add_child(confirm)
	_refresh()
	buttons[0].grab_focus.call_deferred()
	return self


func _add(v: VBoxContainer, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 36)
	b.pressed.connect(cb)
	v.add_child(b)
	buttons.append(b)
	return b


func _ask(action: String, text: String, yes: String) -> void:
	_pending = action
	confirm.msg.text = text
	confirm.yes_btn.text = "%s  (ENTER)" % yes
	confirm.ask()


func say(text: String) -> void:
	status.text = text


func _refresh() -> void:
	var st := ControlsConfig.settings()
	if _graphics_btn != null:
		_graphics_btn.text = "Graphics: %s  (next load)" % st.graphics
	_volume_btn.text = "Volume: %d%%" % int(round(float(st.volume) * 100.0))
	_palette_btn.text = "Colours: %s" % ("colour-safe" if UIStyle.palette == "safe" else "neon")


## Graphics apply when a game loads (the world is built for one preset); the lobby starts on it too.
func _step_graphics(dir: int) -> void:
	var i := GRAPHICS.find(str(ControlsConfig.settings().graphics))
	ControlsConfig.save_setting("graphics", GRAPHICS[wrapi(i + dir, 0, GRAPHICS.size())])
	say("Graphics change when a game loads: Load last save to see it now.")
	_refresh()


func _step_volume(dir: int) -> void:
	var cur := float(ControlsConfig.settings().volume)
	var i := 0
	for k in VOLUMES.size():  # the nearest step
		if absf(VOLUMES[k] - cur) < absf(VOLUMES[i] - cur):
			i = k
	var vol: float = VOLUMES[wrapi(i + dir, 0, VOLUMES.size())]
	ControlsConfig.save_setting("volume", vol)
	apply_volume(vol)
	_refresh()


func _toggle_palette() -> void:
	UIStyle.set_palette("neon" if UIStyle.palette == "safe" else "safe")
	ControlsConfig.save_setting("palette", UIStyle.palette)
	say("Colours: new screens use them now; everything after a load.")
	_refresh()


## The master bus: every sound in the game, the desks' clicks included.
static func apply_volume(vol: float) -> void:
	AudioServer.set_bus_mute(0, vol <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(vol, 0.001)))


func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	var k: int = ev.physical_keycode if ev.physical_keycode else ev.keycode
	if confirm.visible:
		if k in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
			confirm.key("esc" if k == KEY_ESCAPE else "enter")
		get_viewport().set_input_as_handled()
		return
	var focus := get_viewport().gui_get_focus_owner()
	if k == KEY_ESCAPE:
		chosen.emit("resume")
	elif k in [KEY_LEFT, KEY_RIGHT] and focus != null and focus in [_graphics_btn, _volume_btn]:
		var dir := 1 if k == KEY_RIGHT else -1
		if focus == _graphics_btn:
			_step_graphics(dir)
		else:
			_step_volume(dir)
	elif k in [KEY_UP, KEY_DOWN, KEY_TAB, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		return  # the focused button handles these (ui_up, ui_down, ui_accept)
	get_viewport().set_input_as_handled()  # modal: no flying while it's open


func close() -> void:
	queue_free()
