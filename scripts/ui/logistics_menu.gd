class_name LogisticsMenu
extends CanvasLayer
## SHIFT+H in the aircraft, H at the organisation's desks: where the product and
## the cash are (Logistics), the trucks on the road, and orders - a truck of
## product or cash from a stash to another stash, the club (HQ) or a buyer's
## meet; and in the aircraft, cash bags on and off where you're parked.
##
## Works from a view (Logistics.view) and a command callable, so a remote desk
## drives it through the link like any other order.

signal closed

var view_fn: Callable  ## () -> Dictionary: the logistics view
var cmd_fn: Callable  ## (name, args) -> [ok, message]
var send_fn: Callable  ## optional asynchronous transport, returns command sequence
var outcome_fn: Callable  ## (sequence) -> CommandPresentation record
var _orders := {}
var review_link
var review: ActionReview
var focused_stash := ""
var pilot := false  ## the aircraft's seat: cash bags on and off
var rows: VBoxContainer
var trucks: VBoxContainer
var from_ob: OptionButton
var to_ob: OptionButton
var what_ob: OptionButton
var amount: SpinBox
var status: Label
var fuel_label: Label
var round_label: Label
var round_stops: Array = []  ## the stops of the round being planned, in order
var _names := {}  ## site id -> name, from the last view
var _sites: Array = []
var _dests: Array = []
const WHAT := ["cash", "cocaine", "marijuana", "acid", "the armoury", "rifles", "pistols", "machine guns", "RPGs"]
const TIER := {"rifles": "rifle", "pistols": "pistol", "machine guns": "mg", "RPGs": "rpg"}
const BUYERS := [["family", "the Morettis (town)"], ["agency", "the Company (north)"], ["rival", "Los Cuervos (west)"]]


func _ready() -> void:
	layer = 70
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UIStyle.theme()
	add_child(root)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.box(Color(0.06, 0.02, 0.09, 0.95), 10, UIStyle.ACCENT, 2, Vector4(20, 14, 20, 14)))
	panel.anchor_left = 0.14
	panel.anchor_right = 0.86
	panel.anchor_top = 0.08
	panel.anchor_bottom = 0.92
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var shell := VBoxContainer.new()
	panel.add_child(shell)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(scroll)
	scroll.add_child(v)
	var leave := Button.new()
	leave.text = "Close [Esc]"
	leave.pressed.connect(close)
	shell.add_child(leave)
	v.add_child(UIStyle.title("Logistics", 28, UIStyle.ACCENT))
	v.add_child(UIStyle.caption("Product sells only where it sits; wages and loads are paid from the club's safe; the growers want cash on the strip."))
	fuel_label = UIStyle.caption("")
	v.add_child(fuel_label)
	rows = VBoxContainer.new()
	v.add_child(rows)
	var order := HBoxContainer.new()
	order.add_theme_constant_override("separation", 8)
	v.add_child(order)
	what_ob = OptionButton.new()
	for w in WHAT:
		what_ob.add_item(w)
	from_ob = OptionButton.new()
	to_ob = OptionButton.new()
	amount = SpinBox.new()
	amount.max_value = 1e9
	amount.step = 10
	amount.value = 0
	amount.tooltip_text = "0 = all of it"
	for c in [UIStyle.label("Send", 15), what_ob, UIStyle.label("from", 15), from_ob, UIStyle.label("to", 15), to_ob, amount]:
		order.add_child(c)
	var go := Button.new()
	go.text = "Truck it"
	go.focus_mode = Control.FOCUS_ALL
	go.pressed.connect(_send)
	order.add_child(go)
	var home := Button.new()
	home.text = "All cash home"
	home.focus_mode = Control.FOCUS_ALL
	home.pressed.connect(_all_home)
	order.add_child(home)
	var rnd := HBoxContainer.new()
	rnd.add_theme_constant_override("separation", 8)
	v.add_child(rnd)
	rnd.add_child(UIStyle.label("Round", 15))
	round_label = UIStyle.label("(add stops: pick a place in 'from', then Add stop)", 14, UIStyle.DIM)
	round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rnd.add_child(round_label)
	for spec in [["Add stop", _round_add], ["Clear", _round_clear], ["Collect cash round", _round_cash], ["Deliver round", _round_goods]]:
		var rb := Button.new()
		rb.text = spec[0]
		rb.focus_mode = Control.FOCUS_ALL
		rb.pressed.connect(spec[1])
		rnd.add_child(rb)
	if pilot:
		var bags := HBoxContainer.new()
		bags.add_theme_constant_override("separation", 8)
		v.add_child(bags)
		var load_b := Button.new()
		load_b.text = "Load cash bags here (C)"
		load_b.focus_mode = Control.FOCUS_ALL
		load_b.pressed.connect(func(): _act(_command("load_cash", {"amount": amount.value if amount.value > 0 else 1e12})))
		bags.add_child(load_b)
		var unload_b := Button.new()
		unload_b.text = "Unload the bags here (U)"
		unload_b.focus_mode = Control.FOCUS_ALL
		unload_b.pressed.connect(func(): _act(_command("unload_cash", {})))
		bags.add_child(unload_b)
	var works := HBoxContainer.new()
	works.add_theme_constant_override("separation", 8)
	v.add_child(works)
	works.add_child(UIStyle.label("Build at the house in from", 15))
	for w in StashWorks.WORKS:
		var wb := Button.new()
		wb.text = StashWorks.WORKS[w].name
		wb.tooltip_text = StashWorks.WORKS[w].blurb
		wb.focus_mode = Control.FOCUS_ALL
		wb.pressed.connect(_build_works.bind(w))
		works.add_child(wb)
	v.add_child(UIStyle.caption("ON THE ROAD"))
	trucks = VBoxContainer.new()
	trucks.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(trucks)
	status = UIStyle.caption("H or ESC close")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(status)
	refresh()
	what_ob.grab_focus.call_deferred()


func _build_works(what: String) -> void:
	if _sites.is_empty():
		return
	_act(_command("stash_works", {"stash": _sites[from_ob.selected], "what": what}))


func focus_source(id: String) -> void:
	focused_stash = id
	if from_ob != null and _sites.has(id):
		from_ob.select(_sites.find(id))
		focused_stash = ""

func refresh() -> void:
	var lv: Dictionary = view_fn.call()
	for c in rows.get_children():
		c.queue_free()
	for c in trucks.get_children():
		c.queue_free()
	if lv.is_empty():
		rows.add_child(UIStyle.label("No logistics in this game.", 15))
		return
	_names = {}
	for s in lv.get("sites", []):
		_names[s.id] = str(s.name)
	_names[Logistics.HQ] = str(lv.get("hq", "the club"))
	if lv.has("fuel"):
		var fu: Dictionary = lv.fuel
		fuel_label.text = "Fuel: $%.2f a gallon for the trucks and boats, $%.2f avgas (%+d%% on the usual); the fleet has burned $%s so far. A truck or a pilot whose tank will not cover the run fills up first." % [
			float(fu.ground), float(fu.avgas), int(round(float(fu.trend) * 100.0)), Py.money(int(fu.spent))]
	rows.add_child(UIStyle.label("%-26s %-6s %9s %9s %9s %10s" % ["", "market", "coke lb", "grass lb", "acid", "cash"], 14, UIStyle.DIM, UIStyle.mono()))
	var ids: Array = lv.sites.filter(func(s): return not s.burned).map(func(s): return s.id)
	var keep_from: String = str(_sites[from_ob.selected]) if from_ob.selected >= 0 and from_ob.selected < _sites.size() else ""
	var keep_to: String = str(_dests[to_ob.selected]) if to_ob.selected >= 0 and to_ob.selected < _dests.size() else Logistics.HQ
	var rebuild: bool = ids != _sites
	if rebuild:
		_sites = []
		_dests = []
		from_ob.clear()
		to_ob.clear()
	for s in lv.sites:
		var l := UIStyle.label("%-26s %-6s %9d %9d %9d %10s%s" % [str(s.name).left(26), s.market, int(s.cocaine), int(s.marijuana), int(s.get("acid", 0)),
			"$" + Py.money(int(s.cash)), "  BURNED" if s.burned else (("  vault %d guard %d" % [int(s.get("vault", 0)), int(s.get("guard", 0))]) if int(s.get("vault", 0)) + int(s.get("guard", 0)) > 0 else "")], 14, UIStyle.RED if s.burned else UIStyle.WHITE, UIStyle.mono())
		rows.add_child(l)
		if not s.burned and rebuild:
			_sites.append(s.id)
			from_ob.add_item(str(s.name))
			_dests.append(s.id)
			to_ob.add_item(str(s.name))
	rows.add_child(UIStyle.label("%-26s  the safe: wages, loads, lawyers   cash aboard: $%s" % [str(lv.hq).left(26), Py.money(int(lv.aboard))], 14, UIStyle.CYAN))
	var arm: Dictionary = lv.get("armoury", {})
	if not arm.is_empty():
		rows.add_child(UIStyle.label("The armoury at %s: %s" % [arm.at, Arsenal.describe(arm.weapons) if int(arm.count) > 0 else "empty"], 14, UIStyle.AMBER))
	if rebuild:
		_dests.append(Logistics.HQ)
		to_ob.add_item(str(lv.hq) + " (cash)")
		for b in BUYERS:
			_dests.append(b[0])
			to_ob.add_item("sell: " + b[1])
		from_ob.select(_sites.find(keep_from) if _sites.has(keep_from) else 0)
		to_ob.select(_dests.find(keep_to) if _dests.has(keep_to) else _dests.find(Logistics.HQ))
	if not focused_stash.is_empty() and _sites.has(focused_stash):
		from_ob.select(_sites.find(focused_stash))
		focused_stash = ""
	for t in lv.trucks:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := UIStyle.label("%s: %s -> %s, %d min%s%s" % [t.what, t.from, t.to, int(ceil(t.eta / 60.0)),
			"  (pulled over: police ahead)" if t.get("waiting", false) else "", "  [escorted]" if t.get("escort", false) else ""], 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		if bool(lv.get("war", false)) and not t.get("escort", false):
			var b := Button.new()
			b.text = "Escort"
			b.focus_mode = Control.FOCUS_ALL
			var id: int = int(t.id)
			b.pressed.connect(func(): _act(_command("escort_truck", {"job_id": id})))
			row.add_child(b)
		trucks.add_child(row)
	if lv.trucks.is_empty():
		trucks.add_child(UIStyle.caption("nothing on the road"))
	if str(lv.last) != "":
		trucks.add_child(UIStyle.caption(str(lv.last)))
	var lost: Dictionary = lv.get("lost", {})
	if float(lost.get("product", 0)) > 0 or int(lost.get("cash", 0)) > 0:
		trucks.add_child(UIStyle.caption("Lost so far: %d lb, $%s" % [int(lost.product), Py.money(int(lost.cash))]))


func _send() -> void:
	if _sites.is_empty():
		return
	var what: String = WHAT[what_ob.selected]
	var from: String = _sites[from_ob.selected]
	var to: String = _dests[to_ob.selected]
	var r: Array
	if what == "the armoury":
		r = _command("move_armoury", {"to": to})  # all of it (the 'from' is wherever it is)
	elif TIER.has(what):
		if not to in ["family", "agency", "rival"]:
			r = [false, "Guns move as the whole armoury - pick 'the armoury' to move it."]
		else:
			r = _command("sell_product", {"buyer": to, "good": "guns", "tier": TIER[what], "qty": amount.value if amount.value > 0 else 1e9})
	elif what == "cash":
		r = _command("move_cash", {"from": from, "to": to, "amount": amount.value if amount.value > 0 else 1e12})
	elif to in ["family", "agency", "rival"]:
		r = _command("sell_product", {"buyer": to, "good": what, "qty": amount.value if amount.value > 0 else 1e9, "from": from})
	else:
		r = _command("move_goods", {"from": from, "to": to, "good": what, "lb": amount.value if amount.value > 0 else 1e9})
	_act(r)


func _all_home() -> void:
	var lv: Dictionary = view_fn.call()
	var with_cash := []
	for s in lv.get("sites", []):
		if int(s.cash) > 0 and not s.burned:
			with_cash.append(s.id)
	if with_cash.size() >= 2:
		# one truck works its way round them and home
		var r: Array = _command("cash_round", {"stops": with_cash, "to": Logistics.HQ, "plan": true})
		_act(r if not r[0] else [true, "One truck is working its way round %d stashes and home." % with_cash.size()])
		return
	if with_cash.is_empty():
		_act([false, "No cash out in the stashes."])
	else:
		# One order: retain authoritative refusal or pending/partial feedback.
		_act(_command("move_cash", {"from": with_cash[0], "to": Logistics.HQ}))


func _round_text() -> String:
	if round_stops.is_empty():
		return "(add stops: pick a place in 'from', then Add stop)"
	return " > ".join(round_stops.map(func(s): return str(_names.get(s, s))))


func _round_add() -> void:
	if _sites.is_empty():
		return
	var id: String = _sites[from_ob.selected]
	if id in round_stops:
		_act([false, "%s is already on the round." % str(_names.get(id, id))])
		return
	round_stops.append(id)
	round_label.text = _round_text()


func _round_clear() -> void:
	round_stops = []
	round_label.text = _round_text()


## Collect: one truck through the stops (the first is where it starts) with the cash, to the 'to' place.
func _round_cash() -> void:
	if round_stops.size() < 2 or _dests.is_empty():
		_act([false, "A round needs at least two stops."])
		return
	var r: Array = _command("cash_round", {"stops": round_stops, "to": _dests[to_ob.selected]})
	if r[0]:
		_round_clear()
	_act(r)


## Deliver: one truck loaded at 'from' (the good in 'Send', the amount a stop), dropping it at each stop.
func _round_goods() -> void:
	if round_stops.is_empty() or _sites.is_empty():
		_act([false, "Add the stops to deliver to."])
		return
	var what: String = WHAT[what_ob.selected]
	if what not in ["cocaine", "marijuana"]:
		_act([false, "A delivery round carries cocaine or marijuana."])
		return
	var r: Array = _command("goods_round", {"from": _sites[from_ob.selected], "stops": round_stops, "good": what, "lb": amount.value if amount.value > 0 else 1e9})
	if r[0]:
		_round_clear()
	_act(r)


func _act(r: Array) -> void:
	status.text = str(r[1]) if not r[0] or str(r[1]) != "ok" else "Done."
	refresh()


func _process(_dt: float) -> void:
	if outcome_fn.is_valid():
		for seq in _orders.keys():
			var record: Dictionary = outcome_fn.call(seq)
			if record.is_empty():
				continue
			status.text = CommandPresentation.text(record)
			if record.state not in ["pending", "acknowledged"]:
				if record.state == "refreshed" and _orders[seq] in ["cash_round", "goods_round"]:
					_round_clear()
				_orders.erase(seq)
	if Engine.get_process_frames() % 30 == 0:
		refresh()


func _input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.physical_keycode if ev.physical_keycode else ev.keycode:
			KEY_ESCAPE, KEY_H:
				close()
			KEY_C:
				if pilot:
					_act(_command("load_cash", {"amount": amount.value if amount.value > 0 else 1e12}))
			KEY_U:
				if pilot:
					_act(_command("unload_cash", {}))
			_:
				return
		get_viewport().set_input_as_handled()


func close() -> void:
	closed.emit()
	queue_free()


func _command(name: String, args: Dictionary) -> Array:
	if review_link != null and name in ActionReview.COMMANDS:
		if is_instance_valid(review):
			return [false, "An action review is already open."]
		var reviewed_args := args.duplicate(true)
		review = ActionReview.new().setup(review_link, name, reviewed_args)
		review.finished.connect(func(approved, message):
			review = null
			if approved:
				var result := _dispatch_command(name, reviewed_args)
				if result[0] and name in ["cash_round", "goods_round"]:
					round_stops.clear()
				_act(result)
			else:
				_act([false, message]))
		add_child(review)
		return [false, "Review the consequences before confirming."]
	return _dispatch_command(name, args)

func _dispatch_command(name: String, args: Dictionary) -> Array:
	if send_fn.is_valid():
		var seq: int = send_fn.call(name, args)
		_orders[seq] = name
		return [false, "Order #%d sent; awaiting acknowledgement and refreshed state." % seq]
	return cmd_fn.call(name, args)
