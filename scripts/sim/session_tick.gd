class_name SessionTick
extends SessionOps
## Layer 4 of 6 of the Session: the tick - update(), the runner, the world, intel, stashes and the economy.

## Advance one frame. `bot_controls` (from a bot) replaces the pilot's input and autopilot.
func update(dt: float, inp: ControlMapper.InputFrame = null, bot_controls: FlightModel.Controls = null) -> void:
	time += dt
	if inp == null:
		inp = ControlMapper.InputFrame.new()
	if runner_active():
		_update_runner(dt, inp, bot_controls)
	_update_world(dt)
	if campaign != null:
		campaign.tick(self)
	if story != null:
		story.tick(self)
	if tutorial != null:
		tutorial.tick(self)
	if nights != null:
		nights.tick(dt)


func _update_runner(dt: float, inp: ControlMapper.InputFrame, bot_controls: FlightModel.Controls) -> void:
	if phase in ["crashed", "busted", "custody"]:
		if inp.pressed.has("confirm") and phase != "custody" and not (court != null and court.holding()):
			respawn()
		return
	if turnaround_t > 0:
		turnaround_t -= dt
		if turnaround_t <= 0:
			_finish_turnaround()
		fm.controls = FlightModel.Controls.make({"brake": 1.0})
		state = fm.step(dt, world.ground)
		return
	var pilot_aft: bool = kicker == "pilot" and kick_queue > 0
	if pilot_aft:
		inp = ControlMapper.InputFrame.new()  # nobody at the controls
	elif autopilot.engaged and (_any_held(inp, ["pitch_up", "pitch_down", "roll_left", "roll_right"]) or inp.stick != null):
		autopilot.disengage()
		say("Autopilot disconnected")
	var controls := mapper.update(dt, inp, state)
	if bot_controls != null and not pilot_aft:
		controls = bot_controls
	elif state != null and autopilot.engaged:
		controls = autopilot.update(dt, state, controls)
		if autopilot.arrived:
			autopilot.arrived = false
			say("Autopilot: over the field - your controls for the approach.")
	elif hand_tremor != Vector2.ZERO:
		# a frightened pilot's hands (Nerves): only on human hands, never the bot or the autopilot
		controls = controls.copy()
		controls.aileron = clampf(controls.aileron + hand_tremor.x, -1.0, 1.0)
		controls.elevator = clampf(controls.elevator + hand_tremor.y, -1.0, 1.0)
	if parked and not _any_held(inp, ["throttle_up", "brake"]) and controls.throttle < 0.05:
		controls.brake = 1.0  # parking brake while in menus
	if phase == "parked" and loadout.busy() and controls.throttle > 0.05:
		controls.throttle = 0.0
		controls.brake = 1.0
		if messages.is_empty() or time - messages.back()[0] > 4:
			var what := "Still loading" if not loadout.pending.is_empty() else "Cargo still on the ramp! Load it [L] or drop the job [J]"
			say(what + ".")
	if not weather.is_empty():
		var tie: bool = phase == "parked" and controls.throttle < 0.05
		if tie != _tied:
			_tied = tie
			_apply_wind()
	if airframe != null:
		controls = airframe.limit(controls)  # a rough or failed engine, or the cowling off for a repair
	fm.controls = controls
	var s := fm.step(dt, world.ground)
	state = s
	if s.valid:
		loadout.fuel_lb = s.fuel_lb
	_rules(dt, s)
	if airframe != null:
		airframe.update(dt, s)
	if not (phase in ["crashed", "busted"]):
		_crew_work(dt, s)
	if phase == "parked" and not unloading.is_empty():
		_unload_tick(dt)


static func _any_held(inp: ControlMapper.InputFrame, keys: Array) -> bool:
	for k in keys:
		if inp.held.has(k):
			return true
	return false


func runner_signature() -> SensorNet.Signature:
	var s := state
	if s == null or not runner_active() or phase != "flying":
		return null
	var agl := s.alt - world.ground(s.x, s.y) - fm.mass.gear_height_ft * FT
	var sig := SensorNet.Signature.new("runner", s.x, s.y, s.alt, agl, s.vx, s.vy, "air", transponder, squawk)
	sig.code = squawk_code
	sig.rcs = float(SensorNet.RCS.get(spec.key, 1.0))
	var r: Dictionary = upgrades["runner"]
	sig.visual = 0.7 if r.has("quiet_prop") else (0.8 if r.has("dark_paint") else 1.0)
	sig.spoofed = transponder and r.has("spoofer")
	return sig


func _update_world(dt: float) -> void:
	var targets := []
	var sig := runner_signature()
	if sig != null:
		targets.append(PoliceSystem.Target.new(sig, carrying_hot(), hot_value(), squawk if transponder else "runner"))
	# AI runs (police mode)
	if mode == Roles.POLICE:
		var active := smugglers.filter(func(a): return a.active())
		if director.due(time, active.size()):
			_spawn_ai_run()
			director.schedule_next(time)
	var law_air := []
	for u in police.units:
		if u.faction() == "police" and u.state != "crashed":
			law_air.append([u.x, u.y, u.z])
	for a in smugglers:
		if not a.active():
			continue
		var tr: String = a.update(dt, world, law_air,
			func(jid, x, y, z, vx, vy): maritime.drop_bale(jid, x, y, z, vx, vy, 0.0, 60))
		if tr == "escaped":
			runner_score["escapes"] += 1
			law_say("%s left the area - escaped" % police.alias(a.id))
		elif tr == "crashed":
			law_say("%s crashed" % police.alias(a.id))
		if a.active():
			targets.append(PoliceSystem.Target.new(a.signature(world), a.hot, 5000 if a.hot else 0, a.id))

	for u in police.units:
		if u.pilot:
			u.stick = pilot_input.get(u.pilot, u.stick)
	var outcomes := police.tick(dt, time, targets)
	for tid in outcomes:
		var what: String = outcomes[tid]
		if tid == "runner":
			_police_outcome(what)
		else:
			var a = Py.first(smugglers, func(s): return s.id == tid)
			if a:
				a.state = "busted"
				bus.emit("ai_busted", time, "", ["law"], {"id": tid})
	for e in police.events:
		say(e)
	police.events.clear()
	for e in police.law_events:
		law_say(e)
		if upgrades["runner"].has("mole") and not e.begins_with("Upgrade"):
			say("[mole] " + e)  # the man in dispatch hears every order, encrypted or not
	police.law_events.clear()
	_update_upgrades(dt)
	_update_stashes(dt)
	if foot != null and foot.active:
		foot.update(dt)
	_update_economy(dt)
	if races != null:
		races.update(dt)
	if chronicle != null:
		chronicle.update(dt)
	if agency != null:
		agency.update(dt)
	if family != null:
		family.update(dt)
	if island != null:
		island.update(dt)
	if court != null:
		court.update(dt)
	if payroll != null:
		payroll.update(dt)
	if trade != null:
		trade.update(dt)
	if logistics != null:
		logistics.update(dt)

	# maritime: cutters go where the task force suspects a drop
	var law_goals := []
	for t in police.tips:
		if time - t.t < 600 and t.text in ["possible airdrop", "DF fix"]:
			law_goals.append([t.x, t.y])
	var cutter_ai: bool = police.controller == "ai" and (seats == null or not seats.human(Roles.CUTTER))
	if cutter_ai and not law_goals.is_empty() and features.has("cutters") and police.stock.get("cutter", 0) > 0:
		police.stock["cutter"] -= 1
		var c := maritime.new_cutter(law_goals.back())
		radio.transmit(time, "police", c.id, "underway to suspected drop", [c.x, c.y])
	maritime.update(dt, law_goals if cutter_ai else [])
	for ev in maritime.events:
		_maritime_event(ev[0], ev[1])
	maritime.events.clear()
	if casino != null:
		casino.update(dt)
	if dealer != null:
		dealer.update(dt)
	if psych != null:
		psych.update(dt)
	if analyst != null:
		analyst.update(dt)
	if undercover != null:
		undercover.update(dt)
	_update_intel(dt)


func _spawn_ai_run() -> void:
	director.serial += 1
	var r := director.rng
	var ee := AISmuggler.entry_and_exit(r)
	var drop := Maritime.random_drop_point(world, r, maritime.cove)
	var jid := Jobs.new_id()
	var a := AISmuggler.new("Runner-%d" % director.serial, ee[0][0], ee[0][1], 150.0, ee[2], drop, ee[1], jid,
		{"bales_left": r.randint(4, 7)})
	smugglers.append(a)
	maritime.new_gofast(drop, jid)
	law_say("Intel: a run is expected tonight.")


func _police_outcome(what: String) -> void:
	if what == "busted":
		_bust("forced down by police")
	elif what == "clean":
		var fine := 500 if not transponder else 0
		money -= fine
		say("Police forced you down and searched the aircraft: clean." + (" Fined $%d for no transponder." % fine if fine else ""))
	elif what == "hijacked":
		var lost := active_jobs.filter(func(j): return j.hot())
		for j in lost:
			active_jobs.erase(j)
			loadout.remove_job(j.id)
		fm.apply_loadout(loadout)
		say("Rivals forced you to jettison the goods!")
		bus.emit("hijacked", time, "", ["runner"], {"jobs": lost.map(func(j): return j.id)})


func _maritime_event(kind: String, data: Dictionary) -> void:
	var job = Py.first(active_jobs, func(j): return j.id == data.get("job_id"))
	if kind == "bales_delivered":
		var n: int = data["count"]
		runner_score["bales_delivered"] += n
		if job:
			var pay := int(job.payout * n / float(maxi(1, job.bales_total)))
			money += pay
			job.bales_delivered = n
			_resolve_job(job, "%s made the cove with %d/%d bales: +$%s" % [data["boat"], n, job.bales_total, Py.money(pay)])
		bus.emit("bales_delivered", time, "", ["runner"], {"count": n, "job_id": data.get("job_id")})
	elif kind == "boat_seized":
		police.score["boats_seized"] += 1
		police.score["bales_seized"] += data["count"]
		law_say("%s seized %s with %d bales" % [data["cutter"], data["boat"], data["count"]])
		law_funds += 1500.0 + 100.0 * data["count"]  # asset forfeiture
		econ.record_seizure("marijuana", "sea")
		if upgrades["runner"].has("armed_boat"):
			law_funds += 1500.0
			_seize_weapons({"rifle": 2}, data["boat"])
			law_say("Firearms aboard %s: a federal charge on top" % data["boat"])
		if job:
			_resolve_job(job, "Coast Guard took %s! Job lost." % data["boat"])
		bus.emit("boat_seized", time, "", ["runner", "law"], data)
	elif kind == "bale_seized":
		police.score["bales_seized"] += 1
		law_say("%s recovered a floating bale" % data["cutter"])
	elif kind == "bale_splash" and job:
		say("Splash - bale in the water.")
	elif kind == "bale_lost" and job:
		say("Bale lost (%s)." % data["why"])
	elif kind == "boat_fleeing" and job:
		say("%s: cutter on us, running!" % data["boat"])
	elif kind == "boat_returning" and job:
		say("%s: cutter's gone, heading back to the rendezvous." % data["boat"])
	elif kind == "cutter_contact":
		radio.transmit(time, "police", data["cutter"], "surface contact, go-fast, pursuing", [data["x"], data["y"]])


func _resolve_job(job: Jobs.Job, text: String) -> void:
	job.resolved = true
	active_jobs.erase(job)
	say(text)


## Scanner intercepts and spotter reports -> runner-side knowledge of police.
func _update_intel(dt: float) -> void:
	var rx = null
	if state != null:
		rx = [state.x, state.y, state.alt]
	elif location != "":
		rx = [World.airfield(location).x, World.airfield(location).y, null]
	if gear.has("scanner") and features.has("scanner") and RadioNet.REALISM and rx != null:
		# the scanner hears what's in radio range of the aircraft, on its programmed channels
		for e in radio.scanner_at(_scanner_seen, rx, scanner_channels):
			scanner_log.append(e)
		for m in radio.log:
			if m.t > _scanner_seen and m.channel in scanner_channels and not m.encrypted and not m.jammed \
					and m.x != null and radio.can_hear([m.x, m.y, m.z], rx):
				intel[m.sender] = [m.t, m.x, m.y, "scanner"]
		Py.keep_last(scanner_log, 30)
	elif gear.has("scanner") and features.has("scanner"):
		for e in radio.scanner(_scanner_seen):
			scanner_log.append(e)
		for m in radio.channel("police", _scanner_seen):
			if not m.encrypted and m.x != null:
				intel[m.sender] = [m.t, m.x, m.y, "scanner"]
		Py.keep_last(scanner_log, 30)
	_scanner_seen = time
	for sp in spotters:
		if sp.moving_to:
			sp.move_t -= dt
			if sp.move_t <= 0:
				sp.code = sp.moving_to
				sp.moving_to = null
				say("Spotter in position at %s." % World.airfield(sp.code).name)
			continue
		if time - sp.last_report_t < 8.0:
			continue
		sp.last_report_t = time
		var af := World.airfield(sp.code)
		var seen := police.units.filter(func(u): return u.faction() == "police" and u.state != "crashed" \
			and PyMath.hypot(u.x - af.x, u.y - af.y) < SPOTTER_RANGE_M)
		for u in seen:
			intel[u.id] = [time + SPOTTER_DELAY_S, u.x, u.y, "spotter@" + sp.code]
		if not seen.is_empty():
			say("Spotter@%s: %d police unit(s) near the strip!" % [sp.code, seen.size()])
	# forget stale intel
	var fresh := {}
	for k in intel:
		if time - intel[k][0] < 90:
			fresh[k] = intel[k]
	intel = fresh
