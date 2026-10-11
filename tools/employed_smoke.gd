extends SceneTree
## Isolated startup smoke: --headless --script res://tools/employed_smoke.gd -- --new --smoke 1800 --graphics low
## Uses a separate save directory and real Enter input to dismiss the opening briefing.
var frames := 0
func _initialize() -> void:
	var app = load("res://scripts/main.gd").new()
	app.save_dir = "user://employment-smoke/"
	root.add_child.call_deferred(app)

func _process(_dt: float) -> bool:
	frames += 1
	if frames in [30, 31]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = frames == 30
		root.push_input(event)
	return false
