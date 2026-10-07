extends SceneTree
## Staged service screens, not a campaign progression or travel walkthrough.
var sess: Session
var app: PilotApp
var caption: Label
var elapsed := 0.0
var stage := -1
var acted := false
const SCREENS := ["phone", "dealer", "track", "rackets", "casino"]
const LABELS := ["Contacts: hiring, buyers, lawyers and organisation services", "Vehicle dealership: prices, capability and owned fleet", "Races: entry costs, prizes and availability", "Rackets: collection policies and prisoner decisions", "Staged casino access: roulette betting and the authoritative result"]

func _initialize() -> void:
	World.use_map(MapCity.SEED)
	sess = Session.new({"seed": 5, "map_seed": MapCity.SEED, "location": "HAR", "features": Session.SANDBOX_FEATURES, "ground_war": true, "rackets": true, "casino": true, "family": true, "island": true, "races": true, "dealership": true, "court": true, "payroll": true, "trade": true, "logistics": true})
	sess.money = 60000
	sess.update(1.0 / 30)
	app = PilotApp.new()
	root.add_child(app)
	app.setup(sess, "low")
	app.scene.set_hour(16.0)
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	caption = UIStyle.label("", 18, UIStyle.WHITE)
	caption.add_theme_stylebox_override("normal", UIStyle.panel_box(Color(0, 0, 0, 0.9)))
	caption.position = Vector2(24, 680)
	layer.add_child(caption)

func _process(dt: float) -> bool:
	elapsed += dt
	var next := int(elapsed / 7)
	if next >= SCREENS.size():
		app.set_process(false)
		sess.dispose()
		return true
	if next != stage:
		for menu in app.menus.values():
			menu.close()
		stage = next
		acted = false
		caption.text = LABELS[stage]
		if SCREENS[stage] == "casino":
			sess.spawn_at(Island.CODE)  # staged arrival; casino command still validates access
			app.menus.casino.sit("roulette")
		else:
			app._toggle_menu(SCREENS[stage])
	if not acted and fmod(elapsed, 7) >= 3:
		var menu = app.menus[SCREENS[stage]]
		if stage == 4:
			menu.key("enter")
			menu.key("s")
		else:
			menu.key("down")
		acted = true
	return false
