extends SceneTree
## Hangar action-preview baseline (P05): godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://tools/shots/hangar_review_shot.gd -- <out_dir>
## Writes ui-hangar-spotter-selected, -review and -hired .png (the spotter row, its Cancel-first review, the result).
var n := 0
var app
var sess: Session
var out_dir := ""
func _init():
	out_dir = OS.get_cmdline_user_args()[0]
	sess = Session.new({"seed": 1, "location": "FRM", "money": 5000, "upgrades": {"runner": ["bug_sweep", "detector", "dark_paint"]}})
	sess.update(1.0 / 30)
	app = PilotApp.new()
	root.add_child(app)
	app.setup(sess, "low")
	app._toggle_menu("h")
func _snap(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out_dir + "/" + name + ".png")
	print("saved ", name)
func _process(_d) -> bool:
	n += 1
	var m = app.menus["h"]
	if n == 5:
		for i in m.rows.size():
			if m.rows[i][0] == "spotter":
				m.list.select_near(i)
				m._detail()
		print("rows ", m.rows.map(func(r): return r[0]))
	if n == 20: _snap("ui-hangar-spotter-selected")
	if n == 21: m.key("enter")
	if n == 40: _snap("ui-hangar-spotter-review")
	if n == 41:
		m.confirmation.key("right")
		m.confirmation.key("enter")
	if n == 60:
		_snap("ui-hangar-spotter-hired")
		print("money ", sess.money, " spotters ", sess.spotters.size())
		quit()
	return false
