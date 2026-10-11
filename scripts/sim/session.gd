class_name Session
extends SessionCommands
## Game session: the authoritative simulation for one match.
##
## It holds the runner crew's aircraft (FlightModel), the task force, boats, AI
## runs, jobs and economy. Every action goes through command(role, name, args)
## so local menus, network clients and AI crew obey the same rules. No
## rendering in here: the whole game loop runs headless (tests, bots,
## dedicated servers).
##
## The class is split into layers by concern, each extending the one below (state, rules, ops, tick, commands);
## this file is the top: construction, disposal and loading a save.

## opts: world, seed, money, owned, aircraft_key, location, jsbsim_root, save_path, mode, features, humans, gear
func _init(opts := {}) -> void:
	world = opts.get("world", null)
	if world == null:
		World.use_map(int(opts.get("map_seed", World.layout.map_seed)))  # 0 = the classic island
		world = World.new()
	map_seed = world.map.map_seed
	seed = opts.get("seed", 1)
	money = opts.get("money", START_MONEY)
	owned = set_of(opts.get("owned", ["c172p"]))
	aircraft_key = opts.get("aircraft_key", "c172p")
	location = opts.get("location", START_FIELD)
	save_path = opts.get("save_path", "")
	mode = opts.get("mode", Roles.SOLO)
	humans = opts.get("humans", {}).duplicate()
	gear = set_of(opts.get("gear", []))
	if opts.get("features") == null:
		features = set_of(PoliceSystem.LAW_FEATURES if mode == Roles.POLICE else SANDBOX_FEATURES)
	else:
		features = set_of(opts.features)
	rng = PyRandom.new()
	rng.seed(seed)
	jsbsim_root = opts.get("jsbsim_root", "")
	if jsbsim_root == "":
		jsbsim_root = MassData.patched_root()
	for k in Aircraft.ROSTER:
		_mass[k] = MassData.read(Aircraft.ROSTER[k].jsbsim_model)
	bus = EventBus.new()
	radio = RadioNet.new(_rng(seed + 7))
	radio.world = world
	urng = _rng(seed + 31)
	if opts.get("fog", false):
		fog_rng = _rng(seed + 137)
	econ = Economy.new(_rng(seed + 51))
	econ.attach_market(Market.new(_rng(seed + 113)))  # supply and demand on the street (own stream)
	econ.market.hook(self)  # arrests, raids, seizures, the factions' fortunes move it
	arng = _rng(seed + 71)
	if Arsenal.REALISM:
		for side in ["org", "law", "rival"]:
			arsenals[side] = Arsenal.new(side)
		var saved: Dictionary = opts.get("arsenal", {})
		if not saved.is_empty():
			arsenals["org"] = Arsenal.from_dict(saved)
			arsenals["org"].side = "org"
	if not world.map.stashes.is_empty():
		stash_net = StashNet.new(world.map.stashes, _rng(seed + 41))
	ai_law_upgrades = opts.get("ai_law_upgrades", false)
	for key in SYSTEMS:
		if opts.get(key, false):
			enable_system(key, opts.get("career", false))
	for side in ["runner", "law"]:
		for id in opts.get("upgrades", {}).get(side, []):
			upgrades[side][id] = true
	var law := {}
	for f in features:
		if PoliceSystem.LAW_FEATURES.has(f):
			law[f] = true
	police = PoliceSystem.new(world, _rng(seed + 99), radio, "human" if humans.has(Roles.CONTROLLER) else "ai", law)
	analyst = Analyst.new(self)
	police.analyst = analyst
	analyst.held = humans.has(Roles.ANALYST)
	undercover = Undercover.new(self)
	undercover.held = humans.has(Roles.UNDERCOVER)
	if island != null:
		police.territory_y = Island.TERRITORY_Y
	if opts.get("renown", false) and Renown.ENABLED:
		renown = Renown.new(self)
	if opts.get("rackets", false) and Rackets.ENABLED and ground != null:
		rackets = Rackets.new(self)
	if opts.get("races", false) and Races.ENABLED:
		races = Races.new(self)
	if opts.get("airframe", false) and Airframe.ENABLED:
		airframe = Airframe.new(self)
		airframe.held = humans.has(Roles.MECHANIC)
	radio.df_stations = []
	for a in world.airfields:
		if a.police:
			radio.df_stations.append([a.code, a.x, a.y])
	radio.df_enabled = features.has("df")
	maritime = Maritime.new(world, _rng(seed + 13))
	director = AISmuggler.Director.new(_rng(seed + 21))
	mapper = ControlMapper.new()
	autopilot = Autopilot.new()
	log = FlightLog.new()
	squawk = "N%d%s" % [rng.randint(100, 999), rng.choice(Array("ABCDEFGHJK".split("")))]
	copilot = "human" if humans.has(Roles.COPILOT) else null
	for g in gear:
		if g in Upgrades.GEAR_NODES:
			upgrades["runner"][g] = true
	for g in ["scanner", "detector"]:  # boxes on the panel (the ferry tank is a loadout item)
		if upgrades["runner"].has(g):
			gear[g] = true
	apply_upgrades()
	if features.has("hq"):
		# no human boss: the pilot runs the organisation (AI only when nobody flies);
		# no human chief: a human controller runs the budget, else the AI chief does
		var runner_ai = "adaptive" if mode == Roles.POLICE and not humans.has(Roles.BOSS) else null
		var law_ai = null if (humans.has(Roles.CHIEF) or humans.has(Roles.CONTROLLER)) else "adaptive"
		nights = NightDirector.new(self, runner_ai, law_ai)
	_switch_aircraft(aircraft_key, 0.6)
	if opts.has("weather"):
		var w = opts["weather"]
		set_weather(w if w is Dictionary else {"sky": str(w)})
	spawn_at(location if location != null else START_FIELD)
	if police.controller == "ai":
		if features.has("aerostat"):
			police.set_aerostat(true)
		if features.has("encryption"):
			police.set_encryption(true)
	var local := humans.duplicate()
	if runner_active() and not opts.get("pilot_ai", false):
		local[Roles.PILOT] = opts.get("name", "pilot")  # the host flies
	seats = Seats.new(self, local)


## Break the reference cycles (night director, campaign, bus subscribers) so a
## finished Session is freed; batch simulators build thousands of them.
func dispose() -> void:
	if analyst != null:
		analyst.sess = null
	analyst = null
	if airframe != null:
		airframe.sess = null
	airframe = null
	casino = null
	if psych != null:
		psych.sess = null
	psych = null
	if dealer != null:
		dealer.sess = null
	dealer = null
	if undercover != null:
		undercover.sess = null
	undercover = null
	police.analyst = null
	payroll = null
	court = null
	island = null
	agency = null
	family = null
	foot = null
	chronicle = null
	renown = null
	rackets = null
	races = null
	ground = null
	if nights != null:
		nights.sess = null
	nights = null
	if campaign != null:
		campaign.sess = null
	campaign = null
	if story != null:
		story.sess = null
	story = null
	logistics = null
	if tutorial != null:
		tutorial.sess = null
	tutorial = null
	bus._subs.clear()


static func load_or_new(path: String, opts := {}) -> Session:
	var data := read_save(path)
	var o := {}
	o.merge(opts)
	# the save's island wins unless the caller asked for a specific one
	if not opts.has("map_seed"):
		o["map_seed"] = int(data.get("map_seed", 0))
	World.use_map(int(o["map_seed"]))
	o["money"] = int(data.get("money", opts.get("money", START_MONEY)))  # a new game may start with a float
	var owned_list := (data.get("owned", ["c172p"]) as Array).filter(func(k): return Aircraft.ROSTER.has(k))
	var saved_story: Dictionary = data.get("story", {}) if data.get("story") is Dictionary else {}
	var saved_employment: Dictionary = saved_story.get("employment", {}) if saved_story.get("employment") is Dictionary else {}
	o["owned"] = owned_list if not owned_list.is_empty() or bool(saved_employment.get("loaner", false)) else ["c172p"]
	o["aircraft_key"] = data.aircraft if Aircraft.ROSTER.has(data.get("aircraft", "")) else "c172p"
	o["location"] = data.location if World.AIRFIELD_BY_CODE.has(data.get("location", "")) else START_FIELD
	o["gear"] = (data.get("gear", []) as Array).filter(func(k): return GEAR.has(k))
	o["upgrades"] = {"runner": (data.get("upgrades", []) as Array).filter(func(k): return Upgrades.side_of(k) == "runner")}
	if data.get("arsenal") is Dictionary:
		o["arsenal"] = data["arsenal"]
	o["save_path"] = path
	var s := Session.new(o)
	StrategicSave.restore(s, data["sim"] if data.get("sim") is Dictionary else {})
	return s
