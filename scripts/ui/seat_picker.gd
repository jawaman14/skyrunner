class_name SeatPicker
extends Control
## Compatibility adapter for callers joining an already-running game.
## RoomScreen owns the roster, chat, claim feedback and exit in both phases.

signal seated(role: String)
signal cancelled

var screen: RoomScreen
var link: NetClient
var table: DataTable:
	get: return screen.table
var _keys: Array:
	get: return screen._keys
var chat: LineEdit:
	get: return screen.chat_in
var status: Label:
	get: return screen.status


func setup(link_: NetClient) -> SeatPicker:
	link = link_
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen = RoomScreen.new()
	add_child(screen)
	screen.setup(null, link, true)
	screen.seated.connect(func(role): seated.emit(role))
	screen.cancelled.connect(func(): cancelled.emit())
	return self


func _process(_dt: float) -> void:
	if screen != null:
		screen.refresh()


func claim_selected() -> void:
	screen.claim_selected()


func key(k: String) -> void:
	screen.key(k)
