class_name SessionOps
extends SessionRules
## Layer 3 of 6 of the Session: ground operations (loading, fuel, the crew at work), the upgrade trees and the
## in-flight crew's work.

## Returns an error string, or null on success.
func accept_job(job: Jobs.Job):
	if not parked or location != job.origin:
		return "You need to be parked at the job's origin."
	if job.hot() and not features.has("contraband"):
		return "Not that kind of pilot. Yet."
	var seats := spec.seat_count() - (1 if copilot else 0)
	var pax_now := Py.count(loadout.items.values(), func(i): return i.kind == "passenger")
	var pax_new := Py.count(job.items, func(i): return i.kind == "passenger")
	if pax_now + pax_new > seats:
		return "Not enough seats (%d free in a %s)." % [seats, spec.name]
	if job.cost > 0 and logistics != null:
		var err: String = logistics.pay_seller(job.cost)  # cash on the strip, from the bags aboard
		if err != "":
			return err
		say("Paid $%s in cash for the load." % Py.money(job.cost))
	elif job.cost > 0:
		if money < job.cost:
			return "The load costs $%s up front." % Py.money(job.cost)
		money -= job.cost
		say("Paid $%s for the load." % Py.money(job.cost))
	job.accepted_at = time
	if job.kind == "fugitive":
		police.suspicion = maxf(police.suspicion, 60.0)  # already being looked for
	active_jobs.append(job)
	boards[job.origin].erase(job)
	for item in job.items:
		loadout.add(item)
	_ramp_load(job)
	fm.apply_loadout(loadout)
	if job.is_airdrop():
		var boat := maritime.new_gofast(job.drop_point, job.id)
		job.boat_id = boat.id
		var run_km := 2.0 * PyMath.hypot(float(boat.x) - float(job.drop_point[0]), float(boat.y) - float(job.drop_point[1])) / 1000.0
		var fuel_cost := Fuel.boat(self, run_km)
		say("%s is heading out to the rendezvous%s." % [boat.id, (" (fuel $%d)" % int(round(fuel_cost))) if fuel_cost > 0.0 else ""])
	if job.hot():
		_informant_roll(job)
	bus.emit("job_accepted", time, "", ["runner"], {"job_id": job.id, "hot": job.hot()})
	return null


func _informant_roll(job: Jobs.Job) -> void:
	_spy_roll(job)
	if not features.has("informants") or nights != null:
		return  # with HQs, informants are the Task Force's to recruit
	if upgrades["runner"].has("bug_sweep") and urng.random() < 0.5:
		return  # the sweep found the wire
	var chance := 1 - (1 - INFORMANT_BASE) * (1 - SPOTTER_LEAK) ** spotters.size()
	if rng.random() < chance:
		var p := job_xy(job)
		var x: float = p[0] + rng.uniform(-1500, 1500)
		var y: float = p[1] + rng.uniform(-1500, 1500)
		var where := "a drop at sea" if job.is_airdrop() else World.airfield(job.dest).name
		police.add_tip(x, y, 3000, "informant: load moving tonight, %s, aircraft %s" % [where, squawk], squawk, "runner")


## Espionage on a hot job: the task force's undercover agent may leak the exact
## destination; the organisation's double agent feeds them a false one.
func _spy_roll(job: Jobs.Job) -> void:
	if upgrades["law"].has("undercover") and urng.random() < 0.5:
		var p := job_xy(job)
		police.add_tip(p[0], p[1], 800, "undercover: the load goes to %s" % (World.airfield(job.dest).name if not job.is_airdrop() else "a drop at sea"),
			squawk, "runner")
	if upgrades["runner"].has("double_agent"):
		var decoys: Array = world.airfields.filter(func(a): return a.code != job.dest and a.kind in ["bush", "shady"])
		if not decoys.is_empty():
			var af: Airfield = decoys[urng.randint(0, decoys.size() - 1)]
			police.add_tip(af.x, af.y, 2500, "informant: a load lands at %s tonight" % af.name, "", null, false)


## The ramp crew's idea of loading: first free spot from the front.
## Rarely what you want for the CG.
func _ramp_load(job: Jobs.Job) -> void:
	var lo := loadout
	var weights := lo.station_weights(true)
	for item in job.items:
		for s in Py.sorted_by(lo.valid_stations(item), func(i): return lo.spec.stations[i].x_in):
			if lo.can_place(item, s) and weights[s] + item.weight_lb <= lo.spec.stations[s].max_lb:
				lo.assignment[item.id] = s
				lo.queue_move(item)
				weights[s] += item.weight_lb
				break


func drop_job(job: Jobs.Job) -> void:
	if not parked or not active_jobs.has(job):
		return
	active_jobs.erase(job)
	loadout.remove_job(job.id)
	if job.boat_id:
		var b := maritime.boat(job.boat_id)
		if b:
			maritime.boats.erase(b)
	if location == job.origin:
		job.accepted_at = null
		job.boat_id = null
		if not boards.has(job.origin):
			boards[job.origin] = []
		boards[job.origin].append(job)
	else:
		say("Dumped '%s' at %s. No pay." % [job.title, location])
	fm.apply_loadout(loadout)


func hire_loadmaster() -> bool:
	if not parked:
		return false
	money -= LOADMASTER_FEE
	var before := loadout.assignment.duplicate()
	var ok := loadout.auto_balance()
	loadout.requeue_changed(before)
	fm.apply_loadout(loadout)
	say("Loadmaster re-planned the load (-$%d)" % LOADMASTER_FEE + ("" if ok else " but some items don't fit!"))
	return ok


func cycle_item(item_id: int, direction := 1) -> void:
	if not parked:
		return
	loadout.cycle(loadout.items[item_id], direction)
	fm.apply_loadout(loadout)


## Put an item at a given station (-1 = unload to the ramp). Returns an error or null.
func place_item(item_id: int, station: int):
	if not parked:
		return "Loading happens on the ground, stopped."
	if not loadout.items.has(item_id):
		return "No such item."
	var item: Loadout.Item = loadout.items[item_id]
	if station < 0:
		loadout.assignment.erase(item_id)
		loadout.pending.erase(item_id)
	else:
		if station >= loadout.spec.stations.size():
			return "No such station."
		if not loadout.can_place(item, station):
			return "%s won't go in %s." % [item.label, loadout.spec.stations[station].name]
		if loadout.assignment.get(item_id) == station:
			return null
		loadout.assignment[item_id] = station
		loadout.queue_move(item)
	fm.apply_loadout(loadout)
	return null


## [price per lb, lb available] at the current field.
func fuel_source() -> Array:
	var af := airfield
	if af == null:
		return [FUEL_PRICE_PER_LB * econ.fuel_mult(), 0.0]
	var cache: float = fuel_caches.get(af.code, 0.0)
	if af.kind in ["hub", "regional"]:
		return [FUEL_PRICE_PER_LB * econ.fuel_mult(), 1e9]
	if af.kind == "bush":
		var haggle := 0.6 if airframe != null and airframe.held else 1.0  # a mechanic who knows the farmer
		return [FUEL_PRICE_PER_LB * 2 * haggle * econ.fuel_mult(), 1e9 if cache <= 0 else cache]  # farmer's drums, or your cache
	return [0.0, cache] if cache > 0 else [0.0, 0.0]  # shady strips: only what you flew in


## Take fuel from the field's supply; returns what you got (and charges for it).
func _draw_fuel(want_lb: float) -> float:
	var src := fuel_source()
	var price: float = src[0]
	var code: String = location
	var cache: float = fuel_caches.get(code, 0.0)
	var got := minf(want_lb, src[1])
	if cache > 0:
		fuel_caches[code] = cache - minf(got, cache)
		price = 0.0
	money -= int(Py.round_int(got * price))
	return got


func set_fuel(target_lb: float) -> void:
	if not parked:
		return
	var lo := loadout
	var cur := fm.fuel_lb()
	var target := maxf(10.0, minf(lo.mass.fuel_capacity_lb(), target_lb))
	if target > cur:
		target = cur + _draw_fuel(target - cur)
		if target <= cur + 0.5:
			say("No fuel for sale here - fly drums in to build a cache.")
	lo.fuel_lb = target
	fm.apply_loadout(lo)


func fill_ferry(lb: float):
	if not parked:
		return "Refuel on the ground."
	var tanks := loadout.ferry_tanks()
	if tanks.is_empty():
		return "No ferry tank installed."
	var t: Loadout.Item = tanks[0]
	var before := t.fuel_lb
	var want := maxf(0.0, minf(t.fuel_cap_lb, lb) - before)
	var got := _draw_fuel(want) if want > 0 else 0.0
	t.set_fuel(before + got if want > 0 else lb)
	if want > 0 and got <= 0.5:
		return "No fuel for sale here."
	if t.fuel_lb > before:
		var af := airfield
		if af and af.police and features.has("informants") and rng.random() < FERRY_FUEL_TIP:
			police.add_tip(af.x, af.y, 20000, "fuel desk: %s bought ferry fuel at %s" % [squawk, af.name], squawk, "runner")
	fm.apply_loadout(loadout)
	return null


func has_upgrade(id: String) -> bool:
	return upgrades["runner"].has(id) or upgrades["law"].has(id)


## Buy a tree node for `side` (Upgrades): the runner pays from the pilot's money,
## the task force from its funds. The old hangar gear goes through buy_gear.
func buy_upgrade(side: String, id: String):
	if not upgrades.has(side):
		return "Bad side."
	var funds := money if side == "runner" else int(law_funds)
	var why := Upgrades.blocker(side, id, upgrades[side], funds)
	if why != "":
		return why
	var n := Upgrades.node(side, id)
	if side == "runner" and id in Upgrades.GEAR_NODES:
		var err = buy_gear(id)
		if err:
			return err
	elif side == "runner":
		money -= int(n.cost)
		say("Upgrade: %s (-$%s)" % [n.name, Py.money(int(n.cost))])
	else:
		law_funds -= float(n.cost)
		law_say("Upgrade: %s (-$%s)" % [n.name, Py.money(int(n.cost))])
	upgrades[side][id] = true
	if id == "counter_mole" and upgrades["runner"].has("mole"):
		upgrades["runner"].erase("mole")
		say("Your man in dispatch has been found and fired.")
		law_say("Mole hunt: the leak in dispatch is found and fired")
	apply_upgrades()
	bus.emit("upgrade", time, "", [Roles.side(Roles.PILOT) if side == "runner" else "law"], {"side": side, "id": id})
	return null


## Push every owned node's effect into the systems (idempotent: defaults when not owned).
func apply_upgrades() -> void:
	var r: Dictionary = upgrades["runner"]
	var l: Dictionary = upgrades["law"]
	scanner_channels = ["police", "police_tac"] if r.has("prog_scanner") else ["police"]
	police.sensors.mti_min = SensorNet.MTI_MIN_MS * (0.5 if l.has("doppler") else 1.0)
	if l.has("coastal_radar"):
		var cp: Array = maritime.cove
		police.sensors.add_site(SensorNet.RadarSite.new("CST", "Coastal radar", cp[0], cp[1], world.ground(cp[0], cp[1]) + 60.0, 25000.0))
	if l.has("aew"):
		var c: Array = HQ.ZONE_CENTRE["sea"]
		police.sensors.add_site(SensorNet.RadarSite.new("AEW", "Airborne early warning", c[0], c[1], 3000.0, 60000.0,
			{"floor_base": 15.0, "floor_per_m": 0.002, "kind": "aew", "period_s": 10.0}))
	for f in Upgrades.FEATURE_NODES:
		if l.has(f):
			police.features[Upgrades.FEATURE_NODES[f]] = true
			features[Upgrades.FEATURE_NODES[f]] = true
	police.heli_bust_mult = 1.3 if l.has("armed_heli") else 1.0
	police.heli_speed_mult = 1.3 if l.has("blackhawk") else 1.0
	for u in police.units:
		if u.kind == "heli":
			u.speed_mult = police.heli_speed_mult
	maritime.cutter_speed = 1.25 if l.has("fast_cutter") else 1.0
	for b in maritime.boats:
		if b.kind == "cutter":
			b.speed_mult = maritime.cutter_speed
	maritime.seize_mult = (2.0 if r.has("armed_boat") else 1.0) / (1.3 if l.has("fast_cutter") else 1.0)
	police.raid_escape = 0.4 if r.has("strip_guards") else 0.0
	if family != null:
		maritime.seize_mult *= family.seize_factor()  # the union at the docks (or a tip)
		police.raid_escape = minf(0.9, police.raid_escape + family.raid_escape())  # a sergeant on the payroll
	econ.law_kit = l.size()


## Law funds and the AI chief's shopping, plus the runner's lookouts.
func _update_upgrades(dt: float) -> void:
	law_funds += dt * 40.0 / 60.0  # the budget line: ~$2,400 an hour
	if ai_law_upgrades and police.controller == "ai" and time >= _ai_buy_t:
		_ai_buy_t = time + 90.0
		var id := Upgrades.ai_pick(upgrades["law"], int(law_funds))
		if id != "":
			buy_upgrade("law", id)
	if upgrades["runner"].has("lookouts"):
		var here = [state.x, state.y] if state != null else null
		for u in police.units:
			if _lookout_seen.has(u.id) or u.faction() != "police":
				continue
			_lookout_seen[u.id] = true
			if here != null and PyMath.hypot(u.x - here[0], u.y - here[1]) < 12000:
				var brg := UIStyle.bearing_to(here[0], here[1], u.x, u.y)
				say("Lookout: police %s up, %.0f km, bearing %03.0f" % [u.kind, PyMath.hypot(u.x - here[0], u.y - here[1]) / 1000, brg])


func buy_gear(name: String):
	if not GEAR.has(name):
		return "Unknown gear."
	var price: int = GEAR[name][0]
	var feature: String = {"ferry_tank": "ferry"}.get(name, name)
	if not features.has(feature):
		return "Nobody on the island sells that yet."
	if not parked:
		return "Buy gear on the ground."
	if name == "ferry_tank":
		if Py.any(loadout.items.values(), func(i): return i.kind == "tank"):
			return "Already have a ferry tank."
		var tank := Loadout.ferry_tank(Jobs.new_id(), loadout.ferry_capacity())
		loadout.add(tank)
		var spot = Py.first(Py.sorted_by(loadout.valid_stations(tank), func(i): return -spec.stations[i].x_in),
			func(s): return loadout.can_place(tank, s))
		if spot != null:
			loadout.assignment[tank.id] = spot
			loadout.queue_move(tank)
	elif gear.has(name):
		return "Already fitted."
	else:
		gear[name] = true
	money -= price
	if name in Upgrades.GEAR_NODES:
		upgrades["runner"][name] = true
	say("Fitted: %s (-$%s)" % [GEAR[name][1], Py.money(price)])
	fm.apply_loadout(loadout)
	return null


func hire_spotter(code):
	if not features.has("spotters"):
		return "Nobody to hire yet."
	if not World.AIRFIELD_BY_CODE.has(code):
		return "Unknown field."
	if Py.any(spotters, func(s): return s.code == code):
		return "Already watching that strip."
	money -= SPOTTER_FEE
	spotters.append(Spotter.new(code))
	say("Spotter watching %s (-$%d)" % [World.airfield(code).name, SPOTTER_FEE])
	return null


## "human", "ai" or null. Changes the weight in the right seat.
func set_copilot(who) -> void:
	copilot = who
	loadout.copilot_aboard = Py.truthy(who)
	fm.apply_loadout(loadout)


func buy_or_switch(key: String):
	if not parked or not airfield or not airfield.shop:
		return "Aircraft dealers are only at Harbor Intl and Valley Regional."
	if not active_jobs.is_empty():
		return "Deliver or drop your current jobs first."
	var sp: Aircraft.Spec = Aircraft.ROSTER[key]
	if not owned.has(key):
		if money < sp.price:
			return "Need $%s." % Py.money(sp.price)
		money -= sp.price
		owned[key] = true
		say("Bought a %s!" % sp.name)
	_switch_aircraft(key)
	spawn_at(location)
	return null


## After a crash or bust.
func respawn() -> void:
	var code = log.departed_from if log.departed_from else START_FIELD
	if phase == "busted":
		code = START_FIELD
	for j in active_jobs:
		if j.boat_id:
			var b := maritime.boat(j.boat_id)
			if b:
				b.state = "running"
	active_jobs.clear()
	loadout = Loadout.new(spec, loadout.mass, loadout.mass.fuel_capacity_lb() * 0.5, Py.truthy(copilot))
	police.reset()
	spawn_at(code)


## Get out and swing the tail round: the bush pilot's answer to a runway too
## narrow to turn on. Engine off, takes a while.
func turn_around():
	var s := state
	if s == null or not s.on_ground or s.gs_kts > 1.5 or not (phase in ["parked", "flying"]):
		return "Stop on the ground first."
	if turnaround_t > 0:
		return "Already pushing her round."
	turnaround_t = TURNAROUND_S["crew" if crew_count() > 1 else "solo"]
	say("Pushing the aircraft round (%s s)..." % Py.f(turnaround_t, 0))
	return null


func _finish_turnaround() -> void:
	var s := state
	fm.spawn(s.x, s.y, fposmod(s.heading + 180.0, 360.0), world.ground(s.x, s.y), loadout)
	fm.controls.brake = 1.0
	fm.step(0.3, world.ground)
	state = fm.state()
	mapper.reset()
	say("Turned round.")


func request_kick(role: String, count := 1):
	var s := state
	if s == null or s.on_ground:
		return "Kick them out in the air, not on the ramp."
	if s.ias_kts > KICK_MAX_KTS:
		return "Too fast to open the door (max %s kt)." % Py.f(KICK_MAX_KTS, 0)
	if _droppables().is_empty():
		return "Nothing to kick."
	if role == Roles.PILOT and not copilot:
		if not autopilot.engaged:
			return "Engage the autopilot [U] before you leave the controls."
		kicker = "pilot"
	else:
		kicker = "copilot"
	kick_queue = mini(_droppables().size(), kick_queue + maxi(1, count))
	return null


func _droppables() -> Array:
	var lo := loadout
	return lo.items.values().filter(func(i): return i.droppable and lo.assignment.has(i.id) and not lo.pending.has(i.id))


func _crew_work(dt: float, s: FlightModel.FlightState) -> void:
	var lo := loadout
	# loading on the ground
	if s.on_ground and s.gs_kts < 1.0 and not lo.pending.is_empty():
		if not lo.work(dt, crew_count()).is_empty():
			fm.apply_loadout(lo)
			if lo.pending.is_empty():
				say("Loading complete.")
	# AI co-pilot habits
	if copilot == "ai" and not s.on_ground:
		if not lo.ferry_tanks().is_empty() and lo.ferry_fuel_lb() > 0 and fm.wing_fuel_room() > 0.3 * lo.mass.fuel_capacity_lb():
			pumping = true
		if auto_kick and kick_queue == 0 and not _droppables().is_empty():
			for j in active_jobs:
				if j.is_airdrop() and Py.dist2([s.x, s.y], j.drop_point) < 450 and s.ias_kts <= KICK_MAX_KTS:
					request_kick(Roles.COPILOT, _droppables().size())
					break
	# kicking
	if kick_queue > 0:
		if s.on_ground or s.ias_kts > KICK_MAX_KTS + 5:
			kick_queue = 0
			say("Door closed: too fast / on the ground.")
		else:
			kick_t += dt
			if kick_t >= KICK_TIME[kicker if kicker else "copilot"]:
				kick_t = 0.0
				_kick_one(s)
	# ferry pump
	if pumping:
		var tanks := lo.ferry_tanks()
		if tanks.is_empty() or lo.ferry_fuel_lb() <= 0.1 or fm.wing_fuel_room() < 0.5:
			pumping = false
			say("Ferry pump OFF (tank dry or wings full).")
		else:
			var rate: float = PUMP_RATE_LB_MIN["copilot" if copilot else "pilot"] / 60.0
			var t: Loadout.Item = tanks[0]
			var move := minf(rate * dt, t.fuel_lb)
			var added := fm.add_fuel(move)
			t.set_fuel(t.fuel_lb - added)
			fm.apply_loadout(lo)


func _kick_one(s: FlightModel.FlightState) -> void:
	var items := _droppables()
	if items.is_empty():
		kick_queue = 0
		return
	var item: Loadout.Item = Py.max_by(items, func(i): return spec.stations[loadout.assignment[i.id]].x_in)  # nearest the door
	loadout.remove_item(item.id)
	fm.apply_loadout(loadout)
	var vz := s.vs_fpm * 0.00508
	maritime.drop_bale(item.job_id, s.x, s.y, s.alt - 1.5, s.vx, s.vy, vz, item.weight_lb)
	kick_queue -= 1
	var left := _droppables().size()
	bus.emit("bale_kicked", time, "", ["runner"], {"job_id": item.job_id})
	say("Bale away! (%d left)" % left)


## The task force's DF net on a runner transmission (RadioNet.REALISM): bearings
## from the police strips and any DF-equipped helicopter; a fix with its error
## ellipse becomes a track, a tip and suspicion.
func _df_on(msg: RadioNet.RadioMsg) -> void:
	if not features.has("df"):
		return
	var mobile := []
	if upgrades["law"].has("heli_df"):
		for u in police.units:
			if u.kind == "heli" and u.faction() == "police" and u.state != "crashed":
				mobile.append([u.id, u.x, u.y, u.z])
	var df := radio.direction_find(msg, mobile)
	if df.bearings.is_empty():
		return
	if upgrades["law"].has("intercept"):
		# they heard the words, not just the carrier
		law_say("[intercept] %s: %s" % [msg.sender, msg.text])
		police.case("runner").suspicion = minf(100.0, police.case("runner").suspicion + 10.0)
	if df.fix == null:
		law_say("DF: %d bearing on a runner transmission (%.0f s) - no fix" % [df.bearings.size(), msg.dur])
		return
	var e: Array = df.ellipse
	law_say("DF: %d bearings, fix within %.1f x %.1f km" % [df.bearings.size(), e[0] / 1000, e[1] / 1000])
	police.sensors.add_fix("runner", df.fix[0], df.fix[1], time, "DF")
	police.tips.append(PoliceSystem.Tip.new(time, df.fix[0], df.fix[1], maxf(500.0, e[0]), "DF fix"))
	var c := police.case("runner")
	c.last_known = [df.fix[0], df.fix[1], time]
	# a tight fix on a long call is worth more than a smear on a burst
	c.suspicion = minf(100.0, c.suspicion + (30.0 if e[0] < 2000 else 15.0))


func call_boat(brief := false):
	var s := state
	var boats := maritime.boats.filter(func(b): return b.kind == "gofast" and not (b.state in ["seized", "delivered"]))
	if boats.is_empty():
		return "No boat is out."
	var b: Maritime.Boat = boats[0]
	var pos = [s.x, s.y] if s else null
	var msg: RadioNet.RadioMsg
	if RadioNet.REALISM:
		# a brevity codeword is a one-second burst the DF barely gets; a real call lasts
		var text := "rain check" if brief else "%s, %s, come to me, over water, bales ready" % [b.id, squawk]
		var burst: bool = brief or upgrades["runner"].has("burst_radio")
		msg = radio.transmit(time, "boat", squawk, text, [s.x, s.y, s.alt] if s else null, 1.0 if burst else -1.0)
		if msg.jammed:
			say("Called %s - nothing but a carrier. Jammed." % b.id)
			_df_on(msg)
			return null
		if s != null and not radio.can_hear([s.x, s.y, s.alt], [b.x, b.y, 2.0]):
			say("Called %s - no answer (out of radio range: climb, or get round the hill)." % b.id)
			_df_on(msg)
			return null
	else:
		msg = radio.transmit(time, "runner", squawk, "%s, come to me" % b.id, pos)
	var over_water := s != null and world.is_water(s.x, s.y)
	if over_water:
		b.goal = [s.x, s.y]
		b.state = "to_rendezvous"
	say("Called %s." % b.id + ("" if over_water else " (Over land: boat holds position.)"))
	if RadioNet.REALISM:
		_df_on(msg)
		return null
	var df = radio.direction_find(msg) if features.has("df") else null
	if df and not df.bearings.is_empty():
		law_say("DF: %d bearing(s) on a runner transmission" % df.bearings.size())
		if df.fix:
			police.sensors.add_fix("runner", df.fix[0], df.fix[1], time, "DF")
			police.tips.append(PoliceSystem.Tip.new(time, df.fix[0], df.fix[1], 800, "DF fix"))
			police.case("runner").last_known = [df.fix[0], df.fix[1], time]
			police.case("runner").suspicion = minf(100.0, police.case("runner").suspicion + 30)
	return null
