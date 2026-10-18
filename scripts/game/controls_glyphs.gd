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


## Text bindings left beside the glyph for the active device. This avoids spelling out the same key/button twice while
## keeping bindings for the other device visible. `device` is explicit so this stays deterministic in tests.
static func other_device_bindings(control: String, device: String) -> String:
	ControlsConfig.ensure()
	var helper := ControlsConfig.helper()
	var pad_active := device == "pad"
	var labels: Array[String] = []
	for ev in InputMap.action_get_events(ControlsConfig.action(control)):
		var is_pad := ev is InputEventJoypadButton or ev is InputEventJoypadMotion
		if is_pad == pad_active:
			continue
		labels.append(helper.get_label_for_input(ev))
	return ", ".join(labels) if not labels.is_empty() else "-"
