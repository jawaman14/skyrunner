class_name SessionState
extends RefCounted
## Layer 1 of 6 of the Session (scripts/sim/session*.gd): the state - every constant, member and inner class - and the
## helpers, aircraft handling, the arsenals and persistence that everything above is built from.

const FT := 0.3048
const FUEL_PRICE_PER_LB := 1.1
const LOADMASTER_FEE := 150
const START_MONEY := 3000
const OPEN_FLOAT := 10000  ## open mode's start: every system live from the first minute (BALANCE entry 34)
const START_FIELD := "HAR"
const OFF_FIELD_MAX_GS_KTS := 15.0
const GEAR_MARGIN := 1.25  ## the gear holds to this multiple of its rated sink rate; between 1x and 1.25x is a hard landing
const WINGTIP_STRIKE_ROLL_DEG := 18.0  ## on the ground: a Cessna's wingtip is about 1.8 m up, half a span out
## The graded ground beside a strip (Terrain._shape_fields levels it out to 50 m) is part of the field for the
## "ran off" check, so a rollout that drifts onto the shoulder is a scare, not a crash. Pits and cliffs get none.
const SHOULDER_M := {"flat": 25.0, "beach": 25.0, "plateau": 20.0, "pit": 5.0}
const KICK_MAX_KTS := 130.0
const KICK_TIME := {"copilot": 2.0, "pilot": 4.0}
const PUMP_RATE_LB_MIN := {"copilot": 60.0, "pilot": 25.0}
const TURNAROUND_S := {"solo": 20.0, "crew": 10.0}  ## push the aircraft round by hand
const UNLOAD_HOT_S := 60.0  ## the buyers count the goods on the strip
const RAID_RANGE_M := 2000.0
const SPOTTER_FEE := 400
const SPOTTER_RANGE_M := 5000.0
const SPOTTER_DELAY_S := 5.0
const SPOTTER_MOVE_S := 60.0
const INFORMANT_BASE := 0.30
const SPOTTER_LEAK := 0.15
const FERRY_FUEL_TIP := 0.25
const GEAR := {
	"scanner": [1800, "Radio scanner: hear police dispatch (unless encrypted)"],
	"detector": [2500, "Radar detector: warns when a radar paints you"],
	"ferry_tank": [3000, "Ferry bladder tank: extra fuel in the cabin"],
}
const RUNNER_FEATURES := ["contraband", "airdrop", "ferry", "scanner", "detector", "spotters", "copilot"]
const SANDBOX_FEATURES := ["contraband", "airdrop", "ferry", "scanner", "detector", "spotters", "copilot",
	"interceptors", "rivals", "informants", "cutters", "df"]


class FlightLog:
	var departed_from = null
	var airborne := false
	var max_bank := 0.0
	var max_touchdown_fpm := 0.0
	var last_touchdown_fpm := 0.0
	var touchdowns_seen := 0

	func _init(touchdowns_seen_ := 0) -> void:
		touchdowns_seen = touchdowns_seen_


class Spotter:
	var code: String
	var moving_to = null
	var move_t := 0.0
	var last_report_t := -1e9

	func _init(code_: String) -> void:
		code = code_


var world: World
var seed := 1
var money := START_MONEY
var fuel_spent := {"org": 0.0, "rival": 0.0}  ## what the hired fleet has burned in fuel (Fuel)
var owned := {"c172p": true}
var aircraft_key := "c172p"
const ARRIVE_MARGIN_M := 30.0  ## how far off a strip a stopped aircraft still counts as arrived
var phase := "parked"  ## parked | flying | crashed | busted
var location = START_FIELD
var messages: Array = []  ## [[t, text]]
var active_jobs: Array = []
var boards := {}
var jsbsim_root := ""
var save_path := ""
var mode := Roles.SOLO
var features := {}
var humans := {}  ## role -> name
var gear := {}

var rng: PyRandom
var _mass := {}
var bus: EventBus
var radio: RadioNet
var police: PoliceSystem
var maritime: Maritime
var smugglers: Array = []
var director: AISmuggler.Director
var mapper: ControlMapper
var keyboard_assist := false:  ## wings level / pitch hold on the keyboard (the player's setting; never the bots')
	set(v):
		keyboard_assist = v
		mapper.assist = v
var autopilot: Autopilot
var log: FlightLog
var time := 0.0
var fm: FlightModel
var loadout: Loadout
var state: FlightModel.FlightState
var last_outcome := ""
var law_log: Array = []
var scanner_log: Array = []
var scanner_channels := ["police"]  ## what the runner's scanner is programmed for (RadioNet.REALISM)
var upgrades := {"runner": {}, "law": {}}  ## bought tree nodes (Upgrades)
var airframe: Airframe = null  ## engine and airframe wear, repairs (Airframe; `airframe: true` asks for it)
var undercover: Undercover = null  ## the agent who plants a tracking beacon (Undercover)
var analyst: Analyst = null  ## the tip desk (Analyst; a human seat holds tips back from dispatch)
var law_funds := 8000.0  ## the task force's upgrade money: a budget plus forfeiture from busts and seizures
var econ: Economy  ## the markets: what each good is worth where (Economy)
var _news_seen := 0
var stash_net: StashNet = null  ## the organisation's stash houses (maps that have them)
var _stash_ai_t := 0.0
var arsenals := {}  ## "org" | "law" | "rival" -> Arsenal (Arsenal.REALISM)
var seats: Seats  ## who holds each role: the AI, or a human (Seats)
var _ai_defaults := {}  ## what each seat's AI was set to before a human took it
var remote_stick := {}  ## a remote pilot's controls {roll, pitch, throttle, rudder, brake} (the pilot seat over the wire)
var agency: Agency = null  ## the Company: arms flights south, protection, exposure (live play asks for it)
var family: Family = null  ## the Morettis: help that might be a trap (live play asks for it)
var trade: Trade = null  ## the product business: stock, street dealers, bulk buyers, own loads, the career (live play asks for it)
var payroll: Payroll = null  ## the outfits' hired workers: soldiers, drivers, mules, lookouts, accountants, pilots (live play asks for it)
var court: Court = null  ## the pilot's case after an arrest: bail, lawyers, plea, trial, sentence (live play asks for it)
var island: Island = null  ## Isla Soberana, over the horizon: cheap product, sovereign airspace (live play asks for it)
var foot: FootCombat = null  ## the pilot on foot with a gun (sessions with a ground war)
var chronicle: Chronicle = null  ## the news and the breaks between runs (Chronicle; live play asks for it)
var renown: Renown = null  ## how big the name is (Renown; `renown: true` asks for it)
var rackets: Rackets = null  ## street tribute and prisoners (Rackets; `rackets: true` with a ground war)
var races: Races = null  ## the arena: a street race and an air circuit for prize money (Races; `races: true`)
var ground: GroundWar = null  ## squads, firefights and turf on the roads (GroundWar; live play asks for it)
var arng: PyRandom  ## gun runs and arsenal draws, off the board and parity streams
var ai_law_upgrades := false  ## the AI chief buys law upgrades as money comes in (live play; off in sims and tests)
var urng: PyRandom  ## upgrade draws (spoiled tips, leaks), off the parity streams
var _ai_buy_t := 0.0
var _lookout_seen := {}
var intel := {}  ## unit -> [t, x, y, source]
var spotters: Array = []
var transponder := true
var squawk := ""
var squawk_code := "1200"  ## Mode A: 1200 VFR; 7500 hijack, 7600 radio failure, 7700 emergency
var kick_queue := 0
var kick_t := 0.0
var kicker = null
var auto_kick := true
var pumping := false
var copilot = null  ## "human" | "ai" | null
var campaign = null  ## set by Campaign.attach
var tutorial = null  ## Tutorial: the optional lessons and tips (the seat shows them)
var logistics = null  ## Logistics: product and cash sit somewhere, and trucks (or the aircraft) move them
var story = null  ## set by Story.attach: Costa Brava 1979-1989, systems unlocking chapter by chapter
## The chapter on screen (HUD, briefing, desks): the flying campaign's or the story's.
var narrative:
	get:
		return campaign if campaign != null else story
var runner_score := {"bales_delivered": 0, "escapes": 0}
var fuel_caches := {}  ## shady strips: fuel you flew in yourself
var turnaround_t := 0.0
var unloading: Array = []
var unload_t := 0.0
var pilot_input := {}  ## police pilots' sticks
var _scanner_seen := 0.0
var map_seed := 0  ## the island this session is on (0 = classic)
var nights = null  ## NightDirector when the Organisation layer is on
var weather := {}  ## {sky, wind_kt, wind_dir, moon, fog}; empty = calm and clear (the tactical sims fly that)
var fog_rng: PyRandom = null  ## sea fog on calm nights (live play asks: fog: true); its own stream
var weather_rev := 0
var _tied := false  ## parked at idle in weather: tied down, the wind can't flip it
var hand_tremor := Vector2.ZERO  ## set each frame by the pilot's Nerves (the 3D client)  ## bumped on every change, so the renderer knows to follow


# ================================================================ helpers


var spec: Aircraft.Spec:
	get:
		return Aircraft.ROSTER[aircraft_key]


var airfield: Airfield:
	get:
		return World.AIRFIELD_BY_CODE.get(location) if location else null


var parked: bool:
	get:
		var s := state
		return (runner_active() and phase == "parked" and s != null and s.on_ground and s.gs_kts < 1.5
			and location != null)


# ================================================================ aircraft


## The optional systems, in the order they're built (it's also the order they
## hear the event bus). Live play asks for all of them; the story mode switches
## them on chapter by chapter (Story), each on its own stream, so a system that
## arrives in 1983 behaves as it would have from the start.
const SYSTEMS := ["ground_war", "agency", "island", "trade", "logistics", "payroll", "court", "family", "chronicle"]


# ================================================================ commands


const AUTOPILOT_MIN_ROUTE_M := 3000.0  ## closer than this isn't worth engaging the navigate leg for
const AUTOPILOT_HOT_DARK_SUSPICION := 50.0  ## a hot leg goes dark once suspicion's at least this, even without a tip or a wanted level yet


# ================================================================ ground ops


# ================================================================ upgrade trees


# ================================================================ in-flight crew work


# ================================================================ tick


# ================================================================ rules


# ================================================================ arsenals and gun running


# ================================================================ the ground war


# ------------------------------------------------------------------ the court


# ------------------------------------------------------------------ the payroll


# ================================================================ persistence


static func set_of(items) -> Dictionary:
	if items is Dictionary:
		return items.duplicate()
	var d := {}
	for i in items:
		d[i] = true
	return d


static func _rng(s: int) -> PyRandom:
	var r := PyRandom.new()
	r.seed(s)
	return r


func runner_active() -> bool:
	return mode != Roles.POLICE


func say(text: String) -> void:
	messages.append([time, text])
	Py.keep_last(messages, 8)


func law_say(text: String) -> void:
	law_log.append([time, text])
	Py.keep_last(law_log, 40)


func carrying_hot() -> bool:
	for i in loadout.items.values():
		if i.hot:
			return true
	return false


func hot_value() -> int:
	var s := 0
	for j in active_jobs:
		if j.hot():
			s += j.payout
	return s


func job_xy(job: Jobs.Job) -> Array:
	return job.target_xy()


func find_job(job_id: int) -> Jobs.Job:
	for j in active_jobs:
		if j.id == job_id:
			return j
	for board in boards.values():
		for j in board:
			if j.id == job_id:
				return j
	return null


func crew_count() -> int:
	var n := 1 + (1 if copilot else 0)
	var af := airfield
	if af and af.kind in ["hub", "regional"]:
		n += 2  # ramp crew
	return n


## [endurance hours, still-air range km] from live fuel flow incl. ferry fuel.
func range_estimate() -> Array:
	var s := state
	if s == null or s.fuel_flow_pph < 1.0:
		return [0.0, 0.0]
	var fuel: float = s.fuel_lb + loadout.ferry_fuel_lb()
	var hours := fuel / s.fuel_flow_pph
	return [hours, hours * maxf(s.gs_kts, 1.0) * 1.852]


func _switch_aircraft(key: String, fuel_frac = null) -> void:
	var sp: Aircraft.Spec = Aircraft.ROSTER[key]
	var mass: MassData = _mass[key]
	var fuel: float = mass.fuel_capacity_lb() * (fuel_frac if fuel_frac != null else 0.5)
	aircraft_key = key
	loadout = Loadout.new(sp, mass, fuel, Py.truthy(copilot))
	fm = FlightModel.new(sp, jsbsim_root, mass)


func spawn_at(code: String) -> void:
	var af := World.airfield(code)
	var back := af.length / 2 - 25  # line up 25 m in from the threshold of end 0
	var x := af.x - af.ux * back
	var y := af.y - af.uy * back
	fm.spawn(x, y, af.heading, world.airfield_elev(af), loadout)
	fm.controls.brake = 1.0
	fm.step(0.5, world.ground)  # settle onto the gear
	_after_spawn()
	location = code
	phase = "parked"
	if not boards.has(code):
		refresh_board(code)


## Start in the air (offshore entry for long runs).
func spawn_airborne(x: float, y: float, heading: float, alt_agl: float, speed_kts: float) -> void:
	fm.spawn(x, y, heading, 0.0, loadout, world.ground(x, y) + alt_agl, speed_kts)
	_after_spawn()
	mapper.controls.throttle = 0.75
	fm.controls.brake = 0.0
	location = null
	phase = "flying"
	log.airborne = true


func _after_spawn() -> void:
	_apply_wind()
	mapper.reset()
	autopilot.disengage()
	kick_queue = 0
	pumping = false
	log = FlightLog.new(fm.touchdowns)
	state = fm.state()
	fm.controls.brake = 1.0


## Tonight's weather (the HQ season's, or --weather in the sandbox): cloud, rain
## and a dark moon shorten how far a police crew can see you; wind and
## turbulence go to the flight model.
func set_weather(w: Dictionary) -> void:
	var sky: String = w.get("sky", "clear")
	if not HQ.SKIES.has(sky):
		sky = "clear"
	var wr: Array = HQ.SKIES[sky][1]
	weather = {"sky": sky, "wind_kt": int(w.get("wind_kt", (wr[0] + wr[1]) / 2)), "wind_dir": int(w.get("wind_dir", 250)),
		"moon": float(w.get("moon", 0.5))}
	police.visibility = HQ.SKIES[sky][2] * (0.8 + 0.4 * weather["moon"])
	# sea fog: on calm, dry nights, now and then. Eyes can't see past it; radar can.
	var fog := float(w.get("fog", -1.0))
	if fog < 0.0:
		fog = 0.0
		if fog_rng != null and sky != "storm" and int(weather["wind_kt"]) <= 10 and fog_rng.random() < 0.3:
			fog = snappedf(fog_rng.uniform(0.4, 0.95), 0.01)
	weather["fog"] = fog
	police.visibility *= 1.0 - 0.65 * fog
	police.heli_grounded = fog > 0.75
	if fog > 0.0:
		say("Sea fog tonight (%d%%): the crews can't see far%s - but the radar still can." % [int(fog * 100), "; the helicopters are grounded" if fog > 0.75 else ""])
		law_say("Sea fog (%d%%): visual contacts at %d%% of range%s" % [int(fog * 100), int((1.0 - 0.65 * fog) * 100), "; helicopters grounded" if fog > 0.75 else ""])
	police.sensors.weather = {"sky": sky, "wind_kt": float(weather["wind_kt"])}  # sea and rain clutter
	econ.storm = sky == "storm"
	weather_rev += 1
	_apply_wind()


func _apply_wind() -> void:
	if weather.is_empty() or fm == null:
		return
	var fps: float = 0.0 if _tied else weather["wind_kt"] * 1.68781
	var toward := deg_to_rad(weather["wind_dir"] + 180.0)  # wind is named for where it blows from
	fm.fdm.set_property("atmosphere/wind-north-fps", cos(toward) * fps)
	fm.fdm.set_property("atmosphere/wind-east-fps", sin(toward) * fps)
	fm.fdm.set_property("atmosphere/turb-type", 0 if _tied else 4)  # MIL-F-8785C (Dryden)
	fm.fdm.set_property("atmosphere/turbulence/milspec/severity", {"clear": 1, "cloud": 2, "storm": 3}[weather["sky"]])
	if fm.has("atmosphere/turbulence/milspec/windspeed_at_20ft_fps"):
		fm.fdm.set_property("atmosphere/turbulence/milspec/windspeed_at_20ft_fps", fps)


## Build one optional system now. Returns true if it's new (false: already on,
## switched off by its ENABLED flag, or the map has no place for it).
func enable_system(key: String, career := false) -> bool:
	match key:
		"ground_war":
			if ground != null or not GroundWar.ENABLED:
				return false
			ground = GroundWar.new(self, _rng(seed + 61), _rng(seed + 67))
			foot = FootCombat.new(self, _rng(seed + 73))
		"agency":
			if agency != null or not Agency.ENABLED:
				return false
			agency = Agency.new(self, _rng(seed + 89), _rng(seed + 101))
			agency.prng = _rng(seed + 127)  # the pipeline: cocaine north, guns south
		"island":
			if island != null or not Island.ENABLED or world.map.foreign.is_empty():
				return false
			island = Island.new(self, _rng(seed + 103))
			if police != null:
				police.territory_y = Island.TERRITORY_Y
		"trade":
			if trade != null or not Trade.ENABLED:
				return false
			trade = Trade.new(self, _rng(seed + 131), career)
		"logistics":
			if logistics != null or trade == null or stash_net == null:
				return false
			logistics = Logistics.new(self)
		"payroll":
			if payroll != null or not Payroll.ENABLED:
				return false
			payroll = Payroll.new(self, _rng(seed + 109))
			payroll.ai["org"] = not (humans.has(Roles.BOSS) or humans.has(Roles.LIEUTENANT))
		"court":
			if court != null or not Court.ENABLED:
				return false
			court = Court.new(self, _rng(seed + 107))
			court.prosecutor_ai = not (humans.has(Roles.CONTROLLER) or humans.has(Roles.CHIEF))
		"family":
			if family != null or not Family.ENABLED:
				return false
			family = Family.new(self, _rng(seed + 97))
			family.ai = not (humans.has(Roles.BOSS) or humans.has(Roles.LIEUTENANT))
		"chronicle":
			if chronicle != null or not Chronicle.ENABLED:
				return false
			chronicle = Chronicle.new(self, _rng(seed + 83))
		_:
			return false
	return true


## Is this part of the game open yet? Only the story mode locks anything: the
## systems it hasn't built and Story.LOCKS ("guns": gun runs and gun sales;
## "role_soldier"/"role_mule": who the hiring hall offers). Cocaine waits on the
## trade's connection.
func unlocked(key: String) -> bool:
	return story == null or not (key in Story.LOCKS or key in SYSTEMS) or story.is_unlocked(key)


func refresh_board(code: String) -> void:
	var af := World.airfield(code)
	if af.kind == "foreign":
		boards[code] = island.board(af) if island != null else []
		return
	boards[code] = Jobs.generate(af, world.airfields, rng, 6, features,
		func(): return Maritime.random_drop_point(world, rng, maritime.cove))
	if stash_net != null and features.has("contraband") and af.kind in ["shady", "bush"]:
		var sj = stash_net.job_from(af, rng)
		if sj != null:
			boards[code].append(sj)
	if agency != null and agency.active() and features.has("contraband") and af.kind in ["shady", "bush"] and agency.rng.random() < agency.offer_chance:
		var aj = agency.job_from(af, world.airfields)
		if aj != null:
			boards[code].append(aj)
	if Arsenal.REALISM and stash_net != null and features.has("contraband") and af.kind in ["shady", "bush"] and unlocked("guns") and arng.random() < 0.5:
		var gj = Arsenal.gun_run(af, world.airfields, stash_net, arng)
		if gj != null:
			boards[code].append(gj)
	if trade != null and features.has("contraband") and af.kind in ["shady", "bush"]:
		var oj = trade.board_offer(af, rng)
		if oj != null:
			boards[code].append(oj)
		if not trade.connected:
			# the career: grass until the Colombians call - no cocaine work yet
			boards[code] = boards[code].filter(func(j): return j.own_good == "marijuana" or Economy.good_of(j) != "cocaine")
	if Economy.REALISM:
		for j in boards[code]:  # today's prices
			j.price_mult = econ.job_mult(j)
			j.payout = int(j.payout * j.price_mult)


## Weapons taken by the police go into their arsenal and arm their patrols.
func _seize_weapons(weapons: Dictionary, where: String) -> void:
	if not Arsenal.REALISM or weapons.is_empty() or not arsenals.has("law"):
		return
	var n: int = arsenals["law"].take_seized(weapons)
	if n > 0:
		law_say("Weapons recovered from %s: %s - into the arsenal" % [where, Arsenal.describe(weapons)])
		bus.emit("weapons_seized", time, "", ["law"], {"weapons": weapons, "where": where})


func _stock_weapons(weapons: Dictionary, stash_id: String) -> void:
	var org: Arsenal = arsenals["org"]
	org.add_all(weapons)
	if stash_id != "":
		org.cache = stash_id  # the guns sit where the truck left them
	bus.emit("weapons_stocked", time, "", ["runner"], {"weapons": weapons, "cache": org.cache})


## The fence's price for one weapon (a cut under the street) and the dealer's (a mark-up).
func weapon_price(tier: String, buying: bool) -> int:
	var m := econ.mult("guns", "town")
	return int(Arsenal.TIERS[tier].price * m * (1.4 if buying else 0.8))


func save() -> void:
	if save_path == "":
		return
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var o := owned.keys()
	o.sort()
	var g := gear.keys()
	g.sort()
	var data := {
		"money": money,
		"owned": o,
		"aircraft": aircraft_key,
		"location": save_location(),
		"gear": g,
		"upgrades": Py.sorted_by(upgrades["runner"].keys(), func(k): return k),
		"map_seed": map_seed,
	}
	if arsenals.has("org"):
		data["arsenal"] = arsenals["org"].to_dict()
	if campaign != null:
		data["campaign"] = campaign.to_dict()
	if story != null:
		data["story"] = story.to_dict()
	if tutorial != null:
		data["tutorial"] = tutorial.to_dict()
	data["sim"] = StrategicSave.capture(self)  # stashes, stock, crew, case, court, squads (docs/ROADMAP.md, Saves)
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


## Where a load puts you: here if parked, else the field you took off from.
func save_location() -> String:
	return location if parked else (log.departed_from if log.departed_from else START_FIELD)


static func read_save(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}
