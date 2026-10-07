class_name ActionDescriptions
extends RefCounted
## Read-only command consequences. Permission checks precede every state read.
## Execution always recomputes this gate and retains its own handler validation.
const SUPPORTED := ["buy_aircraft", "buy_gear", "buy_vehicle", "sell_vehicle", "sell_product", "move_cash", "move_goods", "service", "rackets", "disband_squad", "cash_round", "goods_round", "move_armoury"]

static func unavailable(name: String, args: Dictionary, reason: String) -> Dictionary:
	return {"label": name.replace("_", " ").capitalize(), "enabled": false, "disabled_reason": reason,
		"confirmation_required": true, "command": name, "args": args.duplicate(true), "preview": ""}

static func build(s, role: String, name: String, args: Dictionary) -> Dictionary:
	var a := unavailable(name, args, "")
	if not Roles.valid(role) or not Roles.allowed(role, name):
		a.disabled_reason = "This role cannot perform that action."
		return a
	if name not in SUPPORTED:
		a.disabled_reason = "Preview unavailable for this action."
		return a
	args = args.duplicate(true)
	var numeric: Array = {"sell_vehicle": ["serial"], "sell_product": ["qty"], "move_cash": ["amount"], "move_goods": ["lb"], "service": ["to"], "goods_round": ["lb"]}.get(name, [])
	for key in numeric:
		if not args.has(key):
			continue
		var value = args[key]
		if not (value is int or value is float or (value is String and value.is_valid_float())) or not is_finite(float(value)):
			a.disabled_reason = "Invalid numeric argument: " + str(key)
			return a
		args[key] = float(value)
	match name:
		"buy_aircraft":
			var key := str(args.get("key", ""))
			if not Aircraft.ROSTER.has(key):
				a.disabled_reason = "Unknown aircraft."
			else:
				var spec: Aircraft.Spec = Aircraft.ROSTER[key]
				var cost: int = 0 if s.owned.has(key) else spec.price
				a.label = "Switch to " + spec.name if cost == 0 else "Buy " + spec.name
				a.preview = "Charge $%s. Switches the aircraft at this strip; check the new load and fuel before departure." % Py.money(cost)
				if not s.parked or s.airfield == null or not s.airfield.shop:
					a.disabled_reason = "Park at an aircraft dealer."
				elif not s.active_jobs.is_empty():
					a.disabled_reason = "Deliver or drop your current jobs first."
				elif s.money < cost:
					a.disabled_reason = "Need $%s." % Py.money(cost)
		"buy_gear":
			var key := str(args.get("name", ""))
			if not Session.GEAR.has(key):
				a.disabled_reason = "Unknown gear."
			else:
				var price: int = Session.GEAR[key][0]
				a.preview = "Charge $%s. Fits %s to this aircraft." % [Py.money(price), Session.GEAR[key][1]]
				if not s.features.has({"ferry_tank": "ferry"}.get(key, key)):
					a.disabled_reason = "Nobody sells that yet."
				elif not s.parked:
					a.disabled_reason = "Buy gear on the ground."
				elif s.gear.has(key) or (key == "ferry_tank" and Py.any(s.loadout.items.values(), func(i): return i.kind == "tank")):
					a.disabled_reason = "Already fitted."
				elif s.money < price:
					a.disabled_reason = "Need $%s." % Py.money(price)
		"buy_vehicle", "sell_vehicle":
			if s.dealer == null or not Dealership.ENABLED:
				a.disabled_reason = "There is no dealership in this game."
			elif name == "buy_vehicle":
				var spec: Dictionary = Dealership.spec(str(args.get("id", "")))
				a.disabled_reason = s.dealer.why_not(str(args.get("id", "")))
				if not spec.is_empty():
					a.label = "Buy " + str(spec.name)
					a.preview = "Charge $%s. Adds one %s. Insurance continues at $%d per hour." % [Py.money(int(spec.price)), spec.name, int(Dealership.INSURANCE_DRIVE if spec.use == "drive" else Dealership.INSURANCE_HAUL)]
			else:
				var serial := int(args.get("serial", -1))
				var index: int = s.dealer._find(serial)
				if index < 0:
					a.disabled_reason = "You do not own that."
				else:
					var spec: Dictionary = Dealership.spec(str(s.dealer.owned[index].id))
					a.label = "Sell " + str(spec.name)
					a.preview = "Removes vehicle #%d, %s. Receive $%s; its insurance stops. Active car/fleet capability may change." % [serial, spec.name, Py.money(int(float(spec.price) * Dealership.RESALE))]
		"service":
			if s.airframe == null or not s.airframe.active():
				a.disabled_reason = "No wear in this game."
			else:
				var part := str(args.get("part", "both"))
				var target := clampf(float(args.get("to", 100.0)), 1.0, 100.0)
				var condition: Dictionary = s.airframe.cond.get(s.aircraft_key, {"engine": 100.0, "airframe": 100.0})
				var cost := 0.0
				var points := 0.0
				var first_price := 0.0
				for p in ["engine", "airframe"]:
					if part in [p, "both"]:
						var gain := maxf(0.0, target - float(condition[p]))
						cost += gain * s.airframe.price(p)
						points = maxf(points, gain)
						if gain > 0.01 and first_price == 0.0:
							first_price = s.airframe.price(p)
				var terms: Array = s.airframe.terms()
				a.preview = "Repair %s to %.0f%%. Estimated total $%s over %.1f minutes. Charges accrue during work; work stops if funds run out or the aircraft moves." % [part, target, Py.money(int(round(cost))), points / maxf(1.0, float(terms[0]))]
				if not is_finite(target) or part not in ["engine", "airframe", "both"]:
					a.disabled_reason = "Invalid repair target or part."
				elif s.phase != "parked" or s.airfield == null:
					a.disabled_reason = "Park at a strip to have it worked on."
				elif not s.airframe.work.is_empty():
					a.disabled_reason = "The work is already under way."
				elif points < 0.01:
					a.disabled_reason = "Nothing needs doing."
				elif s.money < first_price:
					a.disabled_reason = "Not enough money for the parts."
		"rackets":
			if s.rackets == null:
				a.disabled_reason = "Nobody collects for us here."
			else:
				var kind := str(args.get("what", ""))
				var count: int = s.rackets.held
				if kind == "policy":
					var market := str(args.get("market", ""))
					var mode := str(args.get("mode", ""))
					a.preview = "Set %s collection policy to %s. Changes future tribute and pressure." % [market, mode]
					if not s.rackets.policy.has(market) or mode not in Rackets.POLICIES:
						a.disabled_reason = "Unknown market or policy."
				elif kind in ["ransom", "turn", "release"]:
					a.label = "%s all %d prisoners" % [kind.capitalize(), count]
					if count <= 0:
						a.disabled_reason = "No prisoners."
					if kind == "ransom":
						var multiplier: float = s.renown.price_mult() if s.renown != null else 1.0
						a.preview = "Returns all %d prisoners. Requested ransom $%s; actual payment may be lower if the rival cannot pay. No prisoners remain held." % [count, Py.money(int(Rackets.RANSOM_EACH * multiplier * count))]
					elif kind == "turn":
						var wage := int(float(Payroll.ROLES.soldier[0]) * (0.7 + 0.6 * 0.3) * 1.5)
						a.preview = "All %d prisoners join the payroll as soldiers with low loyalty. Continuing wages: $%s per payday. None remain held." % [count, Py.money(count * wage)]
						if s.payroll == null:
							a.disabled_reason = "No payroll to put them on."
					else:
						a.preview = "Releases all %d prisoners without payment. They cannot be ransomed or recruited afterward. Renown may increase." % count
				else:
					a.disabled_reason = "Unknown prisoner action."
		"disband_squad":
			var q = s.ground.get_squad(str(args.get("id", ""))) if s.ground != null else null
			if q == null or q.faction != s._faction_of(role):
				a.disabled_reason = "Not one of ours."
			else:
				a.label = "Disband " + str(q.id)
				a.preview = "Removes squad %s (%d men). Weapons and %.0f ammunition return to its arsenal; payroll soldiers remain employed. No cash refund." % [q.id, q.men, q.ammo]
				if q.fight != null:
					a.disabled_reason = "They're in a firefight."
		"move_cash", "move_goods":
			_transfer(s, a, name, args)
		"cash_round", "goods_round":
			_round(s, a, name, args)
		"move_armoury":
			_armoury(s, a, args)
		"sell_product":
			_sale(s, a, args)
	a.enabled = a.disabled_reason == ""
	return a

static func _transfer(s, a: Dictionary, name: String, args: Dictionary) -> void:
	if s.logistics == null:
		a.disabled_reason = "No logistics in this game: money is money." if name == "move_cash" else "No logistics in this game: the product is just there."
		return
	var from := str(args.get("from", ""))
	var to := str(args.get("to", Logistics.HQ if name == "move_cash" else ""))
	var good := "cash" if name == "move_cash" else str(args.get("good", ""))
	var quantity := float(args.get("amount", 1e12)) if good == "cash" else float(args.get("lb", 0.0))
	a.disabled_reason = s.logistics.transfer_reason(from, to, good, quantity)
	if a.disabled_reason != "":
		return
	var have: float = (float(s.money) if from == Logistics.HQ else float(s.logistics.cash.get(from, 0.0))) if good == "cash" else float(s.logistics.stock[from][good])
	quantity = minf(quantity, have)
	a.preview = "Dispatch %.1f %s from %s to %s; %.1f remains at source. Stock/cash leaves now and arrives by truck, with fuel costs and travel risks. It is not delivered immediately." % [quantity, "dollars" if good == "cash" else good, s.logistics.name_of(from), s.logistics.name_of(to), have - quantity]

static func _sale(s, a: Dictionary, args: Dictionary) -> void:
	if s.trade == null:
		a.disabled_reason = "No trade in this game."
		return
	var good := str(args.get("good", ""))
	var tier := str(args.get("tier", "rifle"))
	if good not in ["cocaine", "marijuana", "guns"] or not Arsenal.TIERS.has(tier):
		a.disabled_reason = "Unknown product or weapon."
		return
	if good == "guns" and not s.unlocked("guns"):
		a.disabled_reason = "Nobody's buying guns from us yet."
		return
	var buyer := str(args.get("buyer", ""))
	var quote: Dictionary = s.trade.quote(buyer, good, tier)
	a.disabled_reason = quote.why
	if a.disabled_reason != "":
		return
	var have: float = float(s.arsenals.org.stock.get(tier, 0)) if good == "guns" else float(s.trade.stock[good])
	var quantity := minf(float(args.get("qty", 0.0)), minf(have, float(quote.room)))
	if good == "guns":
		quantity = floorf(quantity)
	if not is_finite(quantity) or quantity <= 0.0:
		a.disabled_reason = "No stock or buyer capacity for this sale."
		return
	var from := str(args.get("from", ""))
	if s.logistics != null and good != "guns":
		if from == "" and not s.logistics.stock.is_empty():
			from = Py.max_by(s.logistics.stock.keys(), func(k): return s.logistics.stock[k][good])
		a.disabled_reason = s.logistics.transfer_reason(from, buyer, good, quantity)
		quantity = minf(quantity, float(s.logistics.stock.get(from, {}).get(good, 0.0)))
	a.preview = "Sell up to %.1f %s to %s at $%.2f each (estimated $%s). %s" % [quantity, tier if good == "guns" else good, buyer, float(quote.price), Py.money(int(quantity * quote.price)), "Delivery and payment occur by truck; stock leaves the source now and prices may change before settlement." if s.logistics != null else "Removes stock and credits cash now."]

static func _round(s, a: Dictionary, name: String, args: Dictionary) -> void:
	if s.logistics == null:
		a.disabled_reason = "No logistics in this game."
		return
	var lg: Logistics = s.logistics
	var raw = args.get("stops", [])
	if not raw is Array:
		a.disabled_reason = "Stops must be a list of stash IDs."
		return
	var stops: Array = raw.duplicate()
	var seen := {}
	if stops.size() < (2 if name == "cash_round" else 1):
		a.disabled_reason = "A round needs at least two stops." if name == "cash_round" else "A delivery round needs stops."
		return
	for stop in stops:
		if not stop is String or not lg.stock.has(stop):
			a.disabled_reason = "No such stash."
			return
		if seen.has(stop):
			a.disabled_reason = "A stop is on the round twice."
			return
		seen[stop] = true
		if s.stash_net.get_stash(stop).burned:
			a.disabled_reason = "%s is burned." % lg.name_of(stop)
			return
	var lines: Array[String] = []
	if name == "cash_round":
		var to := str(args.get("to", Logistics.HQ))
		if (to != Logistics.HQ and not lg.stock.has(to)) or stops.has(to):
			a.disabled_reason = "It has to end somewhere else."
			return
		var target = s.stash_net.get_stash(to)
		if target != null and target.burned:
			a.disabled_reason = "%s is burned." % lg.name_of(to)
			return
		if args.get("plan", false):
			stops = lg.plan_order(stops, lg.pos(to))
		var total := 0.0
		for stop in stops:
			var cash: float = lg.cash.get(stop, 0.0)
			total += cash
			lines.append("%s: $%s currently available" % [lg.name_of(stop), Py.money(int(cash))])
		if total < 1.0:
			a.disabled_reason = "No cash out on the round."
			return
		lines.append("Estimated collection $%s to %s. %s" % [Py.money(int(total)), lg.name_of(to), "Only the first stop's cash leaves now; later cash remains until pickup and may change." if Agent.ENABLED else "Cash leaves each source now in separate trucks."])
	else:
		var source := str(args.get("from", ""))
		var good := str(args.get("good", ""))
		var each := float(args.get("lb", 1e9))
		if not lg.stock.has(source) or stops.has(source) or s.stash_net.get_stash(source).burned:
			a.disabled_reason = "Load from a live stash outside the delivery stops."
			return
		if good not in lg.goods() or each <= 0.0:
			a.disabled_reason = "Choose a product and a positive delivery quantity."
			return
		var have: float = lg.stock[source].get(good, 0.0)
		var amount := minf(each * stops.size(), have)
		if amount < 0.5:
			a.disabled_reason = "Nothing to deliver."
			return
		var remaining := amount
		for stop in stops:
			var delivery := minf(each, remaining)
			lines.append("%s: %.1f %s" % [lg.name_of(stop), delivery, good])
			remaining -= delivery
		lines.append("%.1f %s leaves %s now; %.1f remains at source." % [amount, good, lg.name_of(source), have - amount])
	lines.append("Delivery takes time, incurs fuel costs and remains exposed to travel risks.")
	a.preview = "\n".join(lines)

static func _armoury(s, a: Dictionary, args: Dictionary) -> void:
	if s.logistics == null or not Arsenal.REALISM or not s.arsenals.has("org"):
		a.disabled_reason = "No armoury in this game."
		return
	if not s.unlocked("guns"):
		a.disabled_reason = "No gun dealer will talk to us yet."
		return
	var lg: Logistics = s.logistics
	var source := lg.armoury_site()
	var to := str(args.get("to", ""))
	if to == source:
		a.disabled_reason = "The armoury is already there."
		return
	if to != Logistics.HQ and not lg.stock.has(to):
		a.disabled_reason = "Choose an armoury destination; use a weapon sale for a buyer."
		return
	var target = s.stash_net.get_stash(to)
	if target != null and target.burned:
		a.disabled_reason = "%s is burned." % lg.name_of(to)
		return
	var weapons := {}
	for tier in Arsenal.ORDER:
		var count: int = s.arsenals.org.stock.get(tier, 0)
		if count > 0: weapons[tier] = count
	if weapons.is_empty():
		a.disabled_reason = "The armoury is empty."
		return
	a.preview = "Dispatch %s from %s to %s. Weapons leave stock now; the armoury location changes on arrival. Ammunition is not transferred by this order. Fuel costs and travel risks continue until delivery." % [Arsenal.describe(weapons), lg.name_of(source), lg.name_of(to)]
