class_name HangarMenu
extends GameMenu
## Aircraft dealer, gear shop and services (spotters, crew), as one table:
## what it is, what it does, and what it costs or whether you have it. LEFT/
## RIGHT turns to the second page: the upgrade trees (electronics and counter-
## surveillance, espionage, the airframe, weaponry).

var list: DataTable
var detail: Label
var rows: Array = []
var tree: UpgradeTree
var page := 0  ## 0 the shop, 1 the upgrade trees


func _build() -> void:
	list = GameMenu.make_table([
		{"title": "", "min": 90},
		{"title": "Item", "expand": true, "ratio": 2, "min": 200},
		{"title": "Details", "expand": true, "ratio": 3, "min": 260},
		{"title": "Price", "align": "right", "mono": true, "min": 110},
	])
	list.row_activated.connect(func(_i): key("enter"))
	list.row_selected.connect(func(_i): _detail())
	content.add_child(list)
	detail = UIStyle.label("", 15, UIStyle.DIM)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(0, 44)
	content.add_child(detail)
	tree = UpgradeTree.new().setup("runner")
	tree.buy.connect(func(id):
		var result: Array = s.command(Roles.PILOT, "upgrade", {"id": id})
		show_feedback("Upgrade fitted." if result[0] else str(result[1]), bool(result[0]))
		refresh())
	tree.visible = false
	content.add_child(tree)


func _rows() -> Array:
	var out := []
	for a in Aircraft.ROSTER.values():
		out.append(["aircraft", a])
	for g in Session.GEAR:
		if s.features.has({"ferry_tank": "ferry"}.get(g, g)):
			out.append(["gear", g])
	if s.features.has("spotters"):
		out.append(["spotter", s.location])
	if s.features.has("copilot"):
		out.append(["copilot", null])
	if s.airframe != null:
		out.append(["service", null])
	return out


func refresh() -> void:
	list.visible = page == 0
	detail.visible = page == 0
	tree.visible = page == 1
	if page == 1:
		title.text = "UPGRADES"
		subtitle.text = "counter-surveillance, espionage, airframe, weaponry  -  $%s in hand" % Py.money(s.money)
		tree.update(s.upgrades["runner"], s.money)
		footer.text = "A node needs the one above it. Gear is fitted on the ground; the rest takes effect at once."
		hints.set_hints([["LEFT/RIGHT", "shop", "left"], ["UP/DOWN", "select", "down"], ["ENTER", "buy", "enter"], ["ESC", "close", "esc"]])
		return
	title.text = "HANGAR"
	subtitle.text = "aircraft, gear & crew  -  $%s in hand" % Py.money(s.money)
	var keep := list.selected_row()
	var keep_id := _row_id(rows[keep]) if keep >= 0 and keep < rows.size() else ""
	list.clear_rows()
	rows = _rows()
	for r in rows:
		match r[0]:
			"aircraft":
				var a: Aircraft.Spec = r[1]
				var owned: bool = s.owned.has(a.key)
				var cur: bool = a.key == s.aircraft_key
				list.add_row(["AIRCRAFT", a.name + ("  (flying)" if cur else ""),
					"MTOW %.0f lb  -  %d seats  -  roll ~%.0f m" % [a.mtow_lb, a.seat_count(), a.ground_roll_m],
					"OWNED" if owned else ("EMPLOYER / $" if s.story != null and s.story.employment != null and s.story.employment.loaner and a.key == EmploymentOpening.AIRCRAFT else "$") + Py.money(s.aircraft_purchase_price(a.key))],
					{"cell_colors": {3: UIStyle.GREEN if owned else UIStyle.WHITE, 1: UIStyle.AMBER if cur else Color(0.9, 0.92, 0.95)}})
			"gear":
				var g: Array = Session.GEAR[r[1]]
				var have: bool = s.gear.has(r[1]) or (r[1] == "ferry_tank" and Py.any(s.loadout.items.values(), func(i): return i.kind == "tank"))
				list.add_row(["GEAR", str(r[1]).replace("_", " ").capitalize(), g[1], "FITTED" if have else "$" + Py.money(g[0])],
					{"cell_colors": {3: UIStyle.GREEN if have else UIStyle.WHITE}})
			"spotter":
				var watching := ", ".join(s.spotters.map(func(sp): return sp.code))
				list.add_row(["CREW", "Spotter at %s" % s.location, "watching: %s" % (watching if watching else "none"),
					"$%d" % Session.SPOTTER_FEE])
			"service":
				var af: Airframe = s.airframe
				var cost := int(round((100.0 - af.engine()) * af.price("engine") + (100.0 - af.airframe()) * af.price("airframe")))
				list.add_row(["SERVICE", "Engine %s  -  airframe %s" % [Airframe.band_of(af.engine()), Airframe.band_of(af.airframe())],
					("work under way" if not af.work.is_empty() else "%d points a minute here (%s)" % [int(af.terms()[0]), af.place() if af.place() != "" else "no strip"]),
					"STOP" if not af.work.is_empty() else ("$" + Py.money(cost) if cost > 0 else "as new")],
					{"cell_colors": {3: UIStyle.CYAN if not af.work.is_empty() else UIStyle.WHITE}})
			"copilot":
				var who: String = {"human": "human (online)", "ai": "Rosa (AI)"}.get(s.copilot, "none")
				list.add_row(["CREW", "Co-pilot: " + who, "loads 2x faster, kicks bales, pumps ferry fuel",
					"ON" if s.copilot else "OFF"], {"cell_colors": {3: UIStyle.GREEN if s.copilot else UIStyle.CAPTION}})
	var ids: Array = rows.map(_row_id)
	list.select_near(ids.find(keep_id) if ids.has(keep_id) else maxi(0, keep))
	_detail()
	var shop: bool = s.airfield != null and s.airfield.shop
	footer.text = "" if shop else "No aircraft dealer at this strip: gear and crew only."
	hints.set_hints([["LEFT/RIGHT", "upgrades", "right"], ["UP/DOWN", "select", "down"], ["ENTER", "buy / hire / toggle", "enter"],
		["ESC", "close", "esc"]])


func _detail() -> void:
	var i := list.selected_row()
	detail.text = ""
	if i < 0 or i >= rows.size():
		return
	match rows[i][0]:
		"aircraft":
			var a: Aircraft.Spec = rows[i][1]
			var action := s.describe_action(Roles.PILOT, "buy_aircraft", {"key": a.key})
			detail.text = action.preview if action.enabled else action.disabled_reason
		"gear":
			var action := s.describe_action(Roles.PILOT, "buy_gear", {"name": rows[i][1]})
			detail.text = action.preview if action.enabled else action.disabled_reason
		"copilot":
			detail.text = "ENTER toggles the AI co-pilot. A human co-pilot joins from the lobby (station or --seat3d)."
		"spotter":
			var action := s.describe_action(Roles.PILOT, "hire_spotter", {"code": rows[i][1]})
			detail.text = action.preview if action.enabled else action.disabled_reason
		"service":
			detail.text = "ENTER starts the work on both (it takes time, and the aircraft cannot fly meanwhile); ENTER again stops it. A hangar is quicker than a bush strip; a mechanic is quicker and cheaper than either."


func key(k: String) -> void:
	if confirmation_key(k):
		return
	if k in ["left", "right"]:
		page = 1 - page
		refresh()
		focus_action()
		return
	if page == 1:
		if k in ["up", "down"]:
			tree.move(1 if k == "down" else -1)
		elif k == "enter":
			tree.activate()
		return
	match k:
		"up":
			list.move(-1)
			_detail()
		"down":
			list.move(1)
			_detail()
		"enter":
			var i := list.selected_row()
			if i < 0:
				return
			var r: Array = rows[i]
			var err = null
			match r[0]:
				"aircraft":
					perform_action("buy_aircraft", {"key": r[1].key})
					return
				"gear":
					perform_action("buy_gear", {"name": r[1]})
					return
				"spotter":
					perform_action("hire_spotter", {"code": r[1]})
					return
				"service":
					if s.airframe.work.is_empty():
						perform_action("service", {"part": "both"})
						return
					var res: Array = s.command(Roles.PILOT, "stop_work", {})
					err = null if res[0] else res[1]
					show_feedback("Work stopped; completed repairs and prior charges remain." if res[0] else str(res[1]), bool(res[0]))
				"copilot":
					if s.copilot == "human":
						err = "Your co-pilot is a real person - ask them."
					else:
						s.set_copilot(null if s.copilot else "ai")
						s.say("Co-pilot aboard." if s.copilot else "Co-pilot stays on the ground.")
			if err:
				show_feedback(str(err), false)
			refresh()


static func _row_id(row: Array) -> String:
	return str(row[0]) + ":" + (str(row[1].key) if row[0] == "aircraft" else str(row[1]))
