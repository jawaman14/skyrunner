class_name DealerMenu
extends GameMenu
## The car dealership (from the phone, or E at a showroom): the lot above, what the organisation owns below.
##
##   UP / DOWN  choose in the list      LEFT / RIGHT  the lot or your vehicles
##   ENTER      buy the one on the lot; or drive the one you own (a car)
##   S          sell the one you own (it fetches 55 % of the price)
##   A          let the AI manage the fleet (it buys the trucks the organisation can afford)
## Cars are for the pilot to drive and wait by the aircraft. Trucks go to the stash drivers: the fleet's best speed is the
## trucks' speed, its best cover cuts the roadblock odds, steel can drive through the roadblock.

var lot: DataTable
var mine: DataTable
var focus := 0  ## 0 the lot, 1 your vehicles
var lot_rows: Array = []
var my_rows: Array = []
var note := ""


func _build() -> void:
	lot = GameMenu.make_table([
		{"title": "On the lot", "expand": true, "ratio": 3, "min": 200},
		{"title": "For", "min": 70},
		{"title": "Price", "align": "right", "mono": true, "min": 90},
		{"title": "What it does", "expand": true, "ratio": 4, "min": 260},
	])
	lot.row_selected.connect(func(_i): focus = 0)
	lot.focus_entered.connect(func(): focus = 0)
	lot.row_activated.connect(func(_i):
		focus = 0
		key("enter"))
	lot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lot.size_flags_stretch_ratio = 2.2
	content.add_child(lot)
	mine = GameMenu.make_table([
		{"title": "Yours", "expand": true, "ratio": 3, "min": 200},
		{"title": "For", "min": 70},
		{"title": "Resale", "align": "right", "mono": true, "min": 90},
		{"title": "Status", "expand": true, "ratio": 4, "min": 260},
	])
	mine.row_selected.connect(func(_i): focus = 1)
	mine.focus_entered.connect(func(): focus = 1)
	mine.row_activated.connect(func(_i):
		focus = 1
		key("enter"))
	mine.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(mine)


## Open on the lot (or on `which`: 0 the lot, 1 your vehicles).
func browse() -> void:
	focus = 0
	note = ""
	open()


static func stats(sp: Dictionary) -> String:
	if sp.use == "drive":
		return "%d km/h on the road, %d across country; %s" % [int(float(sp.road) * 3.6), int(float(sp.off) * 3.6), str(sp.blurb)]
	return "%d km/h, %d%% cover, %d%% steel; %s" % [int(float(sp.speed) * 3.6), int(float(sp.stealth) * 100.0), int(float(sp.armour) * 100.0), str(sp.blurb)]


func refresh() -> void:
	title.text = "THE DEALERSHIP"
	var d: Dealership = s.dealer
	if d == null:
		subtitle.text = "There is no dealership in this game."
		lot.clear_rows()
		mine.clear_rows()
		return
	var v: Dictionary = d.view()
	subtitle.text = "$%s in hand   -   %d of %d vehicles   -   insurance $%s an hour   -   the AI %s the fleet" % [Py.money(s.money), v.owned.size(), v.limit,
		Py.money(int(v.insurance)), "manages" if v.auto else "leaves"]
	var fl: Dictionary = v.fleet
	var keep_l := lot.selected_row()
	var keep_m := mine.selected_row()
	var lot_id: String = str(lot_rows[keep_l].id) if keep_l >= 0 and keep_l < lot_rows.size() else ""
	var serial: int = int(my_rows[keep_m].serial) if keep_m >= 0 and keep_m < my_rows.size() else -1
	var active := focus
	lot.clear_rows()
	mine.clear_rows()
	lot_rows = v.catalogue
	for sp in lot_rows:
		lot.add_row([str(sp.name), "drive" if sp.use == "drive" else "trucks", "$%s" % Py.money(int(sp.price)), stats(sp)])
	my_rows = v.owned
	for o in my_rows:
		var status := ""
		if o.use == "drive":
			status = "the car you drive" if o.active else "parked by the aircraft: ENTER to make it the one you drive"
		else:
			status = "on the stash runs"
		mine.add_row([str(o.name), "drive" if o.use == "drive" else "trucks", "$%s" % Py.money(int(o.resale)), status])
	if not lot_rows.is_empty():
		var ids: Array = lot_rows.map(func(sp): return str(sp.id))
		lot.select_near(ids.find(lot_id) if ids.has(lot_id) else maxi(0, keep_l))
	if not my_rows.is_empty():
		var serials: Array = my_rows.map(func(o): return int(o.serial))
		mine.select_near(serials.find(serial) if serials.has(serial) else maxi(0, keep_m))
	focus = active
	footer.text = note if note != "" else ("The trucks run at %d km/h with %d%% cover and %d%% steel (%d owned). The starter car is the one you drive until you buy another." % [
		int(float(fl.speed) * 3.6), int(float(fl.stealth) * 100.0), int(float(fl.armour) * 100.0), int(fl.count)])
	hints.set_hints([["UP/DOWN", "choose", "down"], ["LEFT/RIGHT", "lot or yours", "right"], ["ENTER", "buy / drive", "enter"], ["S", "sell", "s"], ["A", "AI fleet", "a"], ["ESC", "leave", "esc"]])


func key(k: String) -> void:
	if confirmation_key(k):
		return
	var d: Dealership = s.dealer
	if d == null:
		return
	match k:
		"up":
			(lot if focus == 0 else mine).move(-1)
		"down":
			(lot if focus == 0 else mine).move(1)
		"left":
			focus = 0
			if lot.is_inside_tree():
				lot.grab_focus()
		"right":
			focus = 1
			if mine.is_inside_tree():
				mine.grab_focus()
		"a":
			var result: Array = s.command(Roles.PILOT, "fleet_auto", {"on": not d.auto})
			show_feedback("Fleet automation updated." if result[0] else str(result[1]), bool(result[0]))
		"enter":
			if focus == 0:
				var i := lot.selected_row()
				if i >= 0 and i < lot_rows.size():
					perform_action("buy_vehicle", {"id": lot_rows[i].id})
			else:
				var i := mine.selected_row()
				if i >= 0 and i < my_rows.size():
					var r: Array = s.command(Roles.PILOT, "use_vehicle", {"serial": my_rows[i].serial})
					show_feedback("Active car updated." if r[0] else str(r[1]), bool(r[0]))
		"s":
			var i := mine.selected_row()
			if focus == 1 and i >= 0 and i < my_rows.size():
				perform_action("sell_vehicle", {"serial": my_rows[i].serial})
	refresh()
