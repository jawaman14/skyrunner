class_name ControlsGlyphs
extends RefCounted
## The picture of a control: the key cap while the keyboard was used last, the button of the connected pad (Xbox,
## PlayStation, Switch, Steam Deck...) after a pad button, from Controller Icons (addons/controller_icons, MIT; the glyphs
## are Xelu's CC0 set). It reads the same InputMap actions ControlsConfig registers, so a rebound control shows its new
## glyph. Only the rebindable flight controls are InputMap actions; keys the game reads by keycode have no pad glyph.

const AUTOLOAD := "ControllerIcons"


## True when the Controller Icons autoload is running (it is not in a bare SceneTree without the project's autoloads).
static func available() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	return tree != null and tree.root.get_node_or_null(AUTOLOAD) != null


## The glyph texture of the rebindable control `name` (a ControlsConfig name), or null without the add-on.
static func texture(control: String) -> Texture2D:
	if not drawable() or not ControlsConfig.names().has(control):
		return null
	ControlsConfig.ensure()
	var tex := ControllerIconTexture.new()
	tex.path = ControlsConfig.action(control)
	return tex


## True when glyphs can be drawn: the add-on runs and a real display server is up. The key-cap glyphs ask the OS for the
## keyboard layout (`DisplayServer.keyboard_get_keycode_from_physical`), which a headless run does not have.
static func drawable() -> bool:
	return available() and DisplayServer.get_name() != "headless"


## The glyph as a plain texture for `control` as it looks for `device` ("keyboard" or "pad"), whatever was used last. The
## keyboard one needs a display server (see drawable); the pad one does not.
static func resolved(control: String, device: String) -> Texture:
	if not available() or (device != "pad" and not drawable()):
		return null
	ControlsConfig.ensure()
	var icons := (Engine.get_main_loop() as SceneTree).root.get_node(AUTOLOAD)
	return icons.parse_path(ControlsConfig.action(control), icons.InputType.CONTROLLER if device == "pad" else icons.InputType.KEYBOARD_MOUSE)


## Text bindings left beside the glyph. Omit only the event the add-on selected when a glyph actually draws it;
## keep every binding readable when the slot is empty. `device` and `glyph_drawn` are explicit for headless tests.
static func other_device_bindings(control: String, device: String, glyph_drawn: bool) -> String:
	ControlsConfig.ensure()
	var helper := ControlsConfig.helper()
	var icons := (Engine.get_main_loop() as SceneTree).root.get_node_or_null(AUTOLOAD)
	var shown_event: InputEvent = icons.get_matching_event(ControlsConfig.action(control), icons.InputType.CONTROLLER if device == "pad" else icons.InputType.KEYBOARD_MOUSE) if glyph_drawn and icons != null else null
	var labels: Array[String] = []
	var drawn := false
	for ev in InputMap.action_get_events(ControlsConfig.action(control)):
		if ev == shown_event and not drawn:
			drawn = true
			continue
		labels.append(helper.get_label_for_input(ev))
	return ", ".join(labels) if not labels.is_empty() else "-"
