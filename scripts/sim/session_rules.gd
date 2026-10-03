class_name SessionRules
extends SessionState
## Layer 2 of 6 of the Session: the rules (busts, raids, deliveries, grading), the ground war and the court and payroll
## command wrappers.

func _crash(reason: String) -> void:
	phase = "crashed"
	var fee := maxi(2500, int(spec.price * 0.12))
	money -= fee
	var lost := active_jobs.size()
	last_outcome = "CRASH: %s. Repairs -$%s." % [reason, Py.money(fee)] + (" %d job(s) lost." % lost if lost else "")
	say(last_outcome)
	bus.emit("crashed", time, "", ["runner", "law"], {"reason": reason})


func _bust(how: String) -> void:
	if agency != null and agency.quash(how):
		return  # friends in Washington
	if logistics != null:
		logistics.seize_aboard()
	if court != null:
		# the full process: charges, the bail hearing, a lawyer, a plea or a trial
		phase = "busted"
		court.arrest(how)
		last_outcome = "ARRESTED (%s). Charged: %s." % [how, court.charge_names()]
		law_say("BUST: %s (%s)" % [squawk, how])
		bus.emit("busted", time, "", ["runner", "law"], {"how": how})
		return
	if family != null and family.lawyer_bust(how):
		return  # a very good lawyer
	phase = "busted"
	var fine := 1500 + int(maxi(0, money) * 0.25)
	law_funds += 3000.0  # the aircraft and the cash, forfeited
	for j in active_jobs:
		if j.hot():
			econ.record_seizure(Economy.good_of(j), Economy.job_market(j))
			_seize_weapons(Arsenal.weapons_of(j), "the aircraft")
	if upgrades["runner"].has("strip_guards"):
		fine = int(fine * 1.5)  # an armed-bust case
		how += ", with the armed guards"
	money -= fine
	last_outcome = "BUSTED (%s). Fine and impound -$%s. Cargo seized." % [how, Py.money(fine)]
	say(last_outcome)
	police.score["busts"] += 1
	law_say("BUST: %s (%s)" % [squawk, how])
	bus.emit("busted", time, "", ["runner", "law"], {"how": how})


func _rules(dt: float, s: FlightModel.FlightState) -> void:
	var lg := log
	if fm.crash_reason:
		_crash(fm.crash_reason)
		return
	if not s.valid:
		_crash("Airframe failure")
		return
	var af_here := world.airfield_at(s.x, s.y, 4.0)

	# --- leaving / flying
	if not s.on_ground and s.agl > 3.0:
		if not lg.airborne:
			lg.airborne = true
			lg.departed_from = lg.departed_from if lg.departed_from else location
		if phase == "parked":
			if not unloading.is_empty():
				say("Took off with the load still aboard - no deal.")
				unloading = []
			phase = "flying"
			location = null
			police.reset(true)
		lg.max_bank = maxf(lg.max_bank, absf(s.roll))
	elif phase == "parked" and s.gs_kts > 3:
		lg.departed_from = lg.departed_from if lg.departed_from else location

	# --- collisions
	if world.tree_hit(s.x, s.y, s.alt - fm.mass.gear_height_ft * FT, 4.0):
		_crash("Hit trees")
		return
	if absf(s.x) > World.HALF + 3000 or absf(s.y) > World.HALF + 3000:
		if messages.is_empty() or time - messages.back()[0] > 6:
			say("Leaving the operating area - turn back!")

	# --- touchdowns
	if fm.touchdowns != lg.touchdowns_seen:
		lg.touchdowns_seen = fm.touchdowns
		var fpm := -fm.last_touchdown_fpm
		lg.last_touchdown_fpm = fpm
		lg.max_touchdown_fpm = maxf(lg.max_touchdown_fpm, fpm)
		var limit := spec.gear_limit_fpm * (0.75 if loadout.compute(null, false).overweight_lb > 0 else 1.0) \
			* (1.5 if upgrades["runner"].has("heavy_gear") else 1.0) * (airframe.gear_factor() if airframe != null else 1.0)
		if fpm > limit * GEAR_MARGIN:
			_crash("Gear collapsed on a %s fpm touchdown" % Py.f(fpm, 0))
			return
		if airframe != null and lg.airborne:
			airframe.touchdown(fpm, limit, af_here)
		if lg.airborne:
			say("Touchdown %s fpm" % Py.f(fpm, 0) + (" - butter!" if fpm < 150 else (" - hard landing!" if fpm > limit else "")))

	if s.on_ground:
		autopilot.disengage()
		if world.is_water(s.x, s.y) and af_here == null:
			_crash("Ditched in the sea")
			return
		if absf(s.roll) > WINGTIP_STRIKE_ROLL_DEG:
			_crash("Wingtip strike")
			return
		if s.pitch < -7:
			_crash("Prop strike - nosed over")
			return
		if af_here == null and s.gs_kts > OFF_FIELD_MAX_GS_KTS and not _on_shoulder(s.x, s.y):
			_crash("Ran off the strip into rough ground")
			return
		if s.gs_kts < 1.0 and lg.airborne:
			# stopped a few metres off the end or the edge is still at the field
			var af_stop: Airfield = af_here if af_here != null else world.airfield_at(s.x, s.y, ARRIVE_MARGIN_M)
			if af_stop != null:
				_arrive(af_stop, s)


## On the graded shoulder of a strip: flat, cleared ground beside it.
func _on_shoulder(x: float, y: float) -> bool:
	for af in world.airfields:
		if af.contains(x, y, float(SHOULDER_M.get(af.setting, 25.0))):
			return true
	return false


func _arrive(af: Airfield, s: FlightModel.FlightState) -> void:
	phase = "parked"
	location = af.code
	if af.kind == "foreign" and island != null:
		island.on_arrive()  # the General's men, not the task force
	elif police.landing_check(s, af, carrying_hot()):
		_bust("arrested on landing at %s" % af.name)
		if phase == "busted":
			return
		phase = "parked"
	var delivered := active_jobs.filter(func(j): return j.dest == af.code)
	for job in delivered.filter(func(j): return j.stash != "" and stash_net != null):
		_truck_out(job, af)
	delivered = delivered.filter(func(j): return j.stash == "")
	var hot_here := delivered.filter(func(j): return j.hot() and af.kind in ["bush", "shady"])
	if not hot_here.is_empty():
		# the buyers count it before they pay: sit tight and hope nobody followed you in
		unloading = hot_here
		unload_t = UNLOAD_HOT_S
		say("Unloading - %s s. Watch the sky." % Py.f(UNLOAD_HOT_S, 0))
		delivered = delivered.filter(func(j): return not hot_here.has(j))
	for job in delivered:
		_complete_delivery(job, af)
	fm.apply_loadout(loadout)
	police.reset(true)
	log = FlightLog.new(fm.touchdowns)
	refresh_board(af.code)
	if delivered.is_empty() and hot_here.is_empty():
		say("Parked at %s." % af.name)
	bus.emit("landed", time, "", ["runner"], {"code": af.code})
	save()


## A stash job landed: the load goes on the crew's truck, graded for the flight
## now and paid when (if) the truck reaches the stash.
func _truck_out(job: Jobs.Job, af: Airfield) -> void:
	var g := _grade(job)
	var c := police.case("runner")
	var risk := (0.15 if af.police else 0.0) + (0.1 if (c.tipped or c.wanted) else 0.0)
	var t := stash_net.dispatch(job, af, time, g[0], risk)
	if payroll != null:
		var d: Array = payroll.driver_for(str(job.id))
		t.driver = d[0]
		if d[1]:
			t.waved = true  # he knows the checkpoint sergeant's cousin
	if ground != null:
		# by road; the roadblock roll gives way to the checkpoints on the ground
		var st: Dictionary = stash_net.get_stash(job.stash)
		t.route = ground.route("org", Vector2(af.x, af.y), Vector2(st.x, st.y))
		t.dur = StashNet.TRUCK_LOAD_S + RoadGraph.length(t.route) / stash_net.haul_ms
		t.stop_at = -1.0
	if Agent.ENABLED:
		t.start_agent()  # last: the driver, the road and the time it takes are all settled by now
	active_jobs.erase(job)
	loadout.remove_job(job.id)
	say("Load's on the truck to %s: about %d min by road." % [stash_net.get_stash(job.stash).name, int(ceil(t.dur / 60.0))])
	bus.emit("truck_out", time, "", ["runner"], {"job_id": job.id, "stash": job.stash})


func _update_stashes(dt: float) -> void:
	if stash_net == null:
		return
	var results := stash_net.update(dt, time, police.units.filter(func(u): return u.faction() == "police"))
	if ground != null:
		ground.update(dt)
		if rackets != null:
			rackets.update(dt)
		for r in ground.truck_contacts():
			stash_net.trucks.erase(r[0])
			results.append(r)
		for e in ground.events:
			if e[0] in ["runner", "both"]:
				say(e[1])
			if e[0] in ["law", "both"]:
				law_say(e[1])
		ground.events.clear()
	for r in results:
		var t: StashNet.Truck = r[0]
		if logistics != null and logistics.owns(t):
			logistics.arrived(t, r[1], r[2])
			continue
		var st: Dictionary = stash_net.get_stash(t.stash)
		if r[1] == "hijacked":
			say("Los Cuervos hit the truck to %s. The load is theirs." % st.name)
			law_say("Word on the street: Los Cuervos hijacked a truck near %s" % st.name)
			bus.emit("truck_hijacked", time, "", ["runner"], {"stash": t.stash})
			continue
		if r[1] == "delivered" and not t.weapons.is_empty() and t.gun_mode == "stock" and Arsenal.REALISM:
			_stock_weapons(t.weapons, st.id)
			say("Truck in at %s: %s into the armoury here" % [st.name, Arsenal.describe(t.weapons)])
			bus.emit("job_delivered", time, "", ["runner"], {"job_id": t.job_id, "pay": 0, "dest": t.stash, "hot": true})
		elif r[1] == "delivered":
			money += t.pay
			econ.record_delivery("guns" if not t.weapons.is_empty() else "cocaine", st.zone)
			say("Truck in at %s: +$%s" % [st.name, Py.money(t.pay)])
			bus.emit("job_delivered", time, "", ["runner"], {"job_id": t.job_id, "pay": t.pay, "dest": t.stash, "hot": true})
		else:
			if payroll != null and t.driver != "":
				payroll.lose(t.driver, "arrested")
				t.driver = ""
			say("The truck to %s was stopped (%s). The load is gone." % [st.name, r[2]])
			law_say("Truck stopped on the road to %s: %d crates seized" % [st.name, t.items])
			law_funds += 2000.0 + 300.0 * t.items
			econ.record_seizure("guns" if not t.weapons.is_empty() else "cocaine", st.zone)
			_seize_weapons(t.weapons, "the truck")
			police.case("runner").suspicion = minf(100.0, police.case("runner").suspicion + 15.0)
			bus.emit("truck_seized", time, "", ["runner", "law"], {"stash": t.stash})
	# the AI task force raids a stash it knows is busy
	if police.controller == "ai" and time >= _stash_ai_t and ground == null:
		_stash_ai_t = time + 60.0
		for st in stash_net.known():
			if not st.burned and st.heat >= 55.0 and urng.random() < 0.3:
				_raid(st.id)
				break


## The markets move: police and rival traffic near each market, the rivals'
## turf (the HQ season's, when there is one), and the news.
func _update_economy(dt: float) -> void:
	var cops := []
	var rivals := []
	for u in police.units:
		if u.state != "crashed":
			(cops if u.faction() == "police" else rivals).append([u.x, u.y])
	for c in maritime.boats:
		if c.kind == "cutter":
			cops.append([c.x, c.y])
	for a in smugglers:
		if a.active() and a.kind == "rival":
			rivals.append([a.x, a.y])
	var turf := {}
	if nights != null and nights.season != null and nights.season.rival != null:
		turf = nights.season.rival.turf
	if ground != null:
		cops += ground.positions("police")
		rivals += ground.positions("rival")
		turf = ground.turf(turf)
	econ.update(dt, time, cops, rivals, turf, ground)
	while _news_seen < econ.news.size():
		say("Market news: " + econ.news[_news_seen][1])
		_news_seen += 1
	if _news_seen > 12:
		_news_seen = econ.news.size()


func _raid(id: String):
	if payroll != null and stash_net.get_stash(id) != null and not stash_net.get_stash(id).burned and payroll.lookout_warns(id):
		# the lookout saw them coming: the product was gone before the door came in
		var ls: Dictionary = stash_net.get_stash(id)
		ls.heat = 0.0
		ls.intel *= 0.5
		law_funds += 500.0
		law_say("Raid on %s: empty. Somebody warned them." % ls.name)
		say("The lookout at %s saw the raid coming: the product was moved. The house is cold for now." % ls.name)
		bus.emit("raid_foiled", time, "", ["runner", "law"], {"stash": id})
		return null
	var why := stash_net.raid(id)
	if why != "":
		return why
	var st: Dictionary = stash_net.get_stash(id)
	var taken := stash_net.trucks_to(id)
	for t in taken:
		stash_net.trucks.erase(t)
	law_funds += 2000.0 + 1500.0 * taken.size()
	econ.record_seizure("cocaine", st.zone)
	for t in taken:
		_seize_weapons(t.weapons, "the truck at the door")
	if Arsenal.REALISM and arsenals.has("org") and arsenals["org"].cache == id and not arsenals["org"].is_empty():
		var moved: Dictionary = arsenals["org"].seize_into(arsenals["law"])
		arsenals["org"].cache = ""
		econ.record_seizure("guns", st.zone)
		law_say("The armoury at %s: %s seized - issued to the patrols" % [st.name, Arsenal.describe(moved)])
		say("They found the armoury at %s: %s gone to the police." % [st.name, Arsenal.describe(moved)])
	law_say("Raid on %s: burned%s" % [st.name, (", %d truck(s) taken at the door" % taken.size()) if taken else ""])
	say("The police raided %s. It's burned%s." % [st.name, " - and the truck with it" if taken else ""])
	bus.emit("stash_raided", time, "", ["runner", "law"], {"stash": id})
	return null


func _faction_of(role: String) -> String:
	return "police" if Roles.side(role) == "law" else "org"


func _court(fn: Callable):
	if court == null:
		return "No court in this game."
	var err: String = fn.call()
	return err if err != "" else null


func _pay(fn: Callable):
	if payroll == null:
		return "No payroll in this game."
	var err: String = fn.call()
	return err if err != "" else null


func _complete_delivery(job: Jobs.Job, af: Airfield) -> void:
	var drums := job.items.filter(func(i): return i.label == "Fuel drum")
	if not drums.is_empty() and af.kind in ["bush", "shady"]:
		var fuel := Py.sum_by(drums, func(i): return i.weight_lb) * 0.9
		fuel_caches[af.code] = fuel_caches.get(af.code, 0.0) + fuel
		say("%s lb of fuel cached at %s." % [Py.f(fuel, 0), af.name])
	if job.agency and agency != null:
		if agency.flight_done(job):
			# the Company let the DEA have this one: the strip was a sting
			active_jobs.erase(job)
			loadout.remove_job(job.id)
			_bust("a DEA sting at %s - the Agency's contact never came" % af.name)
			return
	if Arsenal.REALISM and not job.weapons.is_empty() and job.gun_mode == "stock" and not job.agency:
		_stock_weapons(job.weapons, "")
		active_jobs.erase(job)
		loadout.remove_job(job.id)
		say("Delivered '%s': %s into the organisation's armoury" % [job.title, Arsenal.describe(job.weapons)])
		bus.emit("job_delivered", time, "", ["runner"], _delivered(job, 0, af, true))
		return
	if job.own_good != "" and trade != null:
		trade.delivered(job)
		active_jobs.erase(job)
		loadout.remove_job(job.id)
		bus.emit("job_delivered", time, "", ["runner"], _delivered(job, 0, af, true))
		return
	if job.defector and island != null:
		island.defected(job)
	var g := _grade(job)
	money += g[0]
	if job.hot():
		econ.record_delivery(Economy.good_of(job), Economy.job_market(job))
	active_jobs.erase(job)
	loadout.remove_job(job.id)
	say(("Delivered '%s': +$%s %s" % [job.title, Py.money(g[0]), g[1]]).strip_edges(false, true))
	bus.emit("job_delivered", time, "", ["runner"], _delivered(job, g[0], af, job.hot()))


## What a delivery event says: the old keys, plus what the story counts (the
## good, its pounds, whose job it was, where it came from).
func _delivered(job: Jobs.Job, pay: int, af: Airfield, hot: bool) -> Dictionary:
	var good: String = job.own_good if job.own_good != "" else (Economy.good_of(job) if hot else "")
	var lb := 0.0
	for it in job.items:
		if it.label != "Fuel drum":
			lb += it.weight_lb
	return {"job_id": job.id, "pay": pay, "dest": af.code, "hot": hot, "good": good, "lb": lb,
		"agency": job.agency, "origin": job.origin, "weapons": not job.weapons.is_empty()}


## A hot load being counted out on a bush/shady strip. Police arriving = raid.
func _unload_tick(dt: float) -> void:
	if unloading.is_empty():
		return
	var s := state
	for u in police.units:
		if (u.faction() == "police" and u.state != "crashed"
				and PyMath.hypot(u.x - s.x, u.y - s.y) < RAID_RANGE_M and u.z - s.alt < 600):
			var held := unloading
			unloading = []
			_bust("raided on the ground at %s" % (airfield.name if airfield else "the strip"))
			if phase != "busted":
				unloading = held  # quashed: the count goes on
			return
	unload_t -= dt
	if unload_t <= 0:
		var af := airfield
		for job in unloading:
			if active_jobs.has(job):
				_complete_delivery(job, af)
		unloading = []
		fm.apply_loadout(loadout)
		save()


## [pay, notes]
func _grade(job: Jobs.Job) -> Array:
	var pay := float(job.payout)
	var notes := []
	if Economy.REALISM and job.hot():
		# contraband sells at the street price on the day it arrives
		var move := econ.job_mult(job) / maxf(0.05, job.price_mult)
		pay *= move
		if absf(move - 1.0) >= 0.03:
			notes.append("(street price %+d%%)" % int(round((move - 1.0) * 100.0)))
	var lg := log
	var left = job.time_left(time)
	if left != null and left < 0:
		pay *= 0.4
		notes.append("(late)")
	if Py.any(job.items, func(i): return i.fragile) and lg.max_touchdown_fpm > 400:
		pay *= 0.5
		notes.append("(breakage)")
	if job.comfort and (lg.max_bank > 45 or lg.max_touchdown_fpm > 300):
		pay *= 0.7
		notes.append("(VIP unhappy)")
	if lg.last_touchdown_fpm < 150:
		pay *= 1.1
		notes.append("(smooth landing bonus)")
	return [int(pay), " ".join(notes)]
