extends SceneTree
## Staged new-career presentation, isolated from player saves.
## Record with --write-movie opening.avi --fixed-fps 15 --resolution 1280x720.
var sess: Session
var app: PilotApp
var elapsed := 0.0
var step := 0
var caption: Label

func _initialize() -> void:
	World.use_map(MapCity.SEED)
	sess = Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "career": true})
	Story.new_employed().attach(sess)
	app = PilotApp.new()
	root.add_child(app)
	app.setup(sess, "low")
	app.scene.set_hour(16.0)
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	caption = UIStyle.label("New career: fly the employer's Cessna; ownership is earned", 18, UIStyle.WHITE)
	caption.add_theme_stylebox_override("normal", UIStyle.panel_box(Color(0, 0, 0, 0.9)))
	caption.position = Vector2(24, 680)
	layer.add_child(caption)

func _enter() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event)

func _process(dt: float) -> bool:
	elapsed += dt
	if step == 0 and elapsed >= 7:
		_enter()
		app._toggle_menu("j")
		caption.text = "Employer contracts: ordinary supplies before suspicious requests and smuggling"
		step = 1
	elif step == 1 and elapsed >= 14:
		app._toggle_menu("j")
		app._toggle_menu("h")
		caption.text = "Company use is not ownership: the dealer shows the first purchase cost"
		step = 2
	elif step == 2 and elapsed >= 21:
		app._toggle_menu("h")
		# Demonstrate the presentation, not a measured earnings/pacing result.
		sess.money = EmploymentOpening.PURCHASE_PRICE
		var result := sess.command(Roles.PILOT, "buy_aircraft", {"key": "c172p"})
		assert(result[0], str(result[1]))
		app.briefing.text = sess.story.journal_text()
		app.briefing_panel.visible = true
		app.set_process(false)
		caption.text = "Staged funds: first purchase is saved in the journal; price remains provisional"
		step = 3
	if elapsed >= 29:
		sess.dispose()
		return true
	return false
