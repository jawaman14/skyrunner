class_name Investigation
extends RefCounted
## The task force's case files on the stash houses (DESIGN §48, step 1 of the heat-and-law rework, owner 18 Oct).
##
## Instead of a hidden roll ("a stash at heat 55 is raided on a 30% chance a minute"), each stash the task force learns
## about gets a case that moves through stages on timers, and the player can answer each one:
##
##   lead          the stash is known (StashNet.KNOWN_HEAT)
##   surveillance  after SURVEIL_AFTER_S with its suspicion still at SURVEIL_LINE or more: a stakeout
##   warrant       after WARRANT_AFTER_S of surveillance: a judge signs, and the raid comes WARRANT_S later
##   raid          the warrant runs out
##
## A case is dropped when the stash cools (below KNOWN_HEAT as a lead, below DROP_LINE under surveillance): lying low
## works. A lawyer can challenge a warrant (`challenge`), which sends the case back to surveillance. Draws are on the
## case files' own stream (seed + 163). With ENABLED off the session keeps the old roll.

static var ENABLED := true

const SURVEIL_LINE := 45.0
const DROP_LINE := 38.0
const SURVEIL_AFTER_S := 180.0
const WARRANT_AFTER_S := 360.0
const WARRANT_S := 240.0
const CHALLENGE_FEE := 1500
const STAGES := ["lead", "surveillance", "warrant"]
## Aircraft heat (per tail number, 0..100): points a minute.
const TAIL_WANTED_MIN := 4.0  ## flown while wanted
const TAIL_DARK_MIN := 1.0  ## tracked flying dark (no transponder)
const TAIL_COOL_MIN := 0.3  ## anywhere else
const TAIL_PARKED_MIN := 1.0  ## parked
const TAIL_HANGAR_MIN := 3.0  ## parked at a field with a hangar
const TAIL_MULT := 0.5  ## a fully known aircraft's sightings count 1.5 times
const TAIL_KNOWN := 50.0
## District heat (per map zone, 0..100): seizures and raids there; it cools DISTRICT_COOL_MIN a minute.
const DISTRICT_SEIZED := 15.0
const DISTRICT_RAIDED := 25.0
const DISTRICT_COOL_MIN := 0.5
const DISTRICT_RISK := 1.0 / 400.0  ## roadblock odds per point: a district at 100 adds 0.25

var cases := {}  ## stash id -> {"stage": String, "since": float, "until": float}
var events: Array = []  ## [stage or "dropped", stash id], for the session's messages; ["tail_known", aircraft key] too
var tail_heat := {}  ## aircraft key -> heat 0..100
var district_heat := {}  ## map zone -> heat 0..100
var rng: PyRandom


func _init(rng_: PyRandom = null) -> void:
	rng = rng_ if rng_ != null else PyRandom.new()


## One step of the files at `now`. Returns the stash ids whose warrant has run out: the session raids them.
func update(now: float, stash_net) -> Array:
	var raids := []
	for st in stash_net.stashes:
		var id := str(st.id)
		if st.burned:
			cases.erase(id)
			continue
		var heat := StashNet.suspicion(st)
		var c = cases.get(id)
		if c == null:
			if heat >= StashNet.KNOWN_HEAT:
				_stage(id, "lead", now)
			continue
		match str(c.stage):
			"lead":
				if heat < StashNet.KNOWN_HEAT:
					_drop(id)
				elif heat >= SURVEIL_LINE and now - float(c.since) >= SURVEIL_AFTER_S:
					_stage(id, "surveillance", now)
			"surveillance":
				if heat < DROP_LINE:
					_drop(id)
				elif now - float(c.since) >= WARRANT_AFTER_S:
					_stage(id, "warrant", now, now + WARRANT_S)
			"warrant":
				if now >= float(c.until):
					cases.erase(id)
					raids.append(id)
	return raids


## The aircraft's heat over `dt` seconds: up while flying wanted or tracked dark; parked aircraft cool, fastest in a
## hangar. Returns the multiplier the police give its sightings.
func update_tail(dt: float, key: String, wanted: bool, tracked_dark: bool, parked: bool, hangar: bool) -> float:
	var h := float(tail_heat.get(key, 0.0))
	var before := h
	var per_min := 0.0
	if parked:
		per_min = -(TAIL_HANGAR_MIN if hangar else TAIL_PARKED_MIN)
	elif wanted:
		per_min = TAIL_WANTED_MIN
	elif tracked_dark:
		per_min = TAIL_DARK_MIN
	else:
		per_min = -TAIL_COOL_MIN
	h = clampf(h + per_min * dt / 60.0, 0.0, 100.0)
	tail_heat[key] = h
	if before < TAIL_KNOWN and h >= TAIL_KNOWN:
		events.append(["tail_known", key])
	return tail_mult(key)


## Something happened in `zone` (a truck seized, a stash raided): the streets there get hotter.
func heat_district(zone: String, pts: float) -> void:
	district_heat[zone] = clampf(float(district_heat.get(zone, 0.0)) + pts, 0.0, 100.0)


func cool_districts(dt: float) -> void:
	for z in district_heat.keys():
		district_heat[z] = maxf(0.0, float(district_heat[z]) - DISTRICT_COOL_MIN * dt / 60.0)


## What a hot district adds to a truck's roadblock odds there.
func district_risk(zone: String) -> float:
	return float(district_heat.get(zone, 0.0)) * DISTRICT_RISK


func tail_mult(key: String) -> float:
	return 1.0 + TAIL_MULT * float(tail_heat.get(key, 0.0)) / 100.0


## A lawyer's challenge to the warrant on `id`: a chance (better with a better lawyer, tier 0..3) to have it thrown out,
## which sends the case back to surveillance. Returns true when it is thrown out.
func challenge(id: String, tier: int, now: float) -> bool:
	var c = cases.get(id)
	if c == null or str(c.stage) != "warrant":
		return false
	if rng.random() < 0.25 + 0.15 * clampi(tier, 0, 3):
		_stage(id, "surveillance", now)
		return true
	return false


func stage_of(id: String) -> String:
	return str(cases[id].stage) if cases.has(id) else ""


## The files as the runner's side sees them: every case and its stage; the countdown only where `warned` (a lookout
## posted there) says someone is watching for them.
func view(stash_net, now: float, warned := {}) -> Array:
	var out := []
	for id in cases:
		var c: Dictionary = cases[id]
		var st = stash_net.get_stash(id)
		var row := {"stash": id, "name": str(st.name) if st != null else id, "stage": str(c.stage)}
		if warned.has(id) and str(c.stage) == "warrant":
			row["raid_in_s"] = maxf(0.0, float(c.until) - now)
		out.append(row)
	return out


func to_dict() -> Dictionary:
	return {"cases": cases.duplicate(true), "tail_heat": tail_heat.duplicate(), "district_heat": district_heat.duplicate()}


func load_dict(d) -> void:
	cases = {}
	tail_heat = {}
	district_heat = {}
	if d is Dictionary and d.get("district_heat") is Dictionary:
		for z in d.district_heat:
			district_heat[str(z)] = clampf(float(d.district_heat[z]), 0.0, 100.0)
	if d is Dictionary and d.get("tail_heat") is Dictionary:
		for k in d.tail_heat:
			tail_heat[str(k)] = clampf(float(d.tail_heat[k]), 0.0, 100.0)
	if d is Dictionary and d.get("cases") is Dictionary:
		for id in d.cases:
			var c = d.cases[id]
			if c is Dictionary and str(c.get("stage", "")) in STAGES:
				cases[str(id)] = {"stage": str(c.stage), "since": float(c.get("since", 0.0)), "until": float(c.get("until", -1.0))}


func _stage(id: String, stage: String, now: float, until := -1.0) -> void:
	cases[id] = {"stage": stage, "since": now, "until": until}
	events.append([stage, id])


func _drop(id: String) -> void:
	cases.erase(id)
	events.append(["dropped", id])
