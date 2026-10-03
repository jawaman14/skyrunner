class_name Airframe
extends RefCounted
## The aircraft's condition: engine and airframe wear, and what it takes to put them right.
##
## Each aircraft you own carries two numbers, 0 to 100: the **engine** (worn by flying hours) and the **airframe** (worn by
## hard landings, rough strips and storms). Nothing breaks the instant it is low, it gets worse in steps:
##   engine < 60   it runs rough: power falls off, to POWER_FLOOR of full at zero ("rough running" on the HUD);
##   engine < 30   it may quit in the air, more likely the lower it is (up to FAIL_PER_MIN_AT_ZERO a minute), for FAIL_S
##                 seconds, then catches again (the throttle is forced to idle meanwhile);
##   airframe < 50 the gear is weaker: the touchdown that collapses it comes at a softer landing (down to 60 % of the limit).
## **Repairs** run on the ground, over time, and cost money by the point: a hangar (a field with a shop, or a hub or
## regional strip) does HANGAR_RATE points a minute; a bush strip's patch-up only FIELD_RATE at FIELD_COST times the
## price; a human **mechanic** (Roles.MECHANIC) does MECHANIC_RATE anywhere at MECHANIC_COST times the price, and sees the
## real numbers (everyone else sees "good / worn / poor"). The aircraft cannot take off while a repair is running (the
## throttle is held at idle); it stops on its own when the work is done, the money runs out, or the aircraft is moved.
##
## Opt-in with the session option `airframe: true` (a game without it has no wear at all). Behind `Airframe.ENABLED`.
## Its dice are their own stream (seed + 929).

static var ENABLED := true

const ENGINE_WEAR_PER_MIN := 0.12  ## points, in the air
const STORM_WEAR_PER_MIN := 0.10  ## airframe points, flying in a storm
const HARD_FRACTION := 0.6  ## of the gear's limit: a touchdown harder than this does damage
const HARD_POINTS := 14.0  ## airframe points for a touchdown at the limit (in proportion above HARD_FRACTION)
const ROUGH_AIRFRAME := {"gravel": 0.4, "grass": 0.5, "dirt": 0.7, "sand": 0.8}  ## points per landing on that surface
const ENGINE_ROUGH_BELOW := 60.0
const ENGINE_FAIL_BELOW := 30.0
const FAIL_PER_MIN_AT_ZERO := 0.05
const FAIL_S := 90.0
const POWER_FLOOR := 0.8
const GEAR_FLOOR := 0.6
const AIRFRAME_WEAK_BELOW := 50.0
const HANGAR_RATE := 12.0  ## points a minute
const FIELD_RATE := 5.0
const MECHANIC_RATE := 24.0
const COST := {"engine": 30.0, "airframe": 20.0}  ## $ a point at a hangar
const FIELD_COST := 1.5
const MECHANIC_COST := 0.6
const SERVICE_BELOW := 70.0  ## the AI ground crew services an aircraft this worn (at a hangar)
const EMERGENCY_BELOW := 40.0  ## ... and patches one this worn even at a bush strip

var sess
var held := false  ## a human mechanic
var cond := {}  ## aircraft key -> {"engine": float, "airframe": float}
var work := {}  ## the repair under way: {parts: [..], to: float, key, at}
var fail_until := -1.0
var failures := 0
var spent := 0
var rng: PyRandom


func _init(sess_) -> void:
	sess = sess_
	rng = PyRandom.new()
	rng.seed(int(sess.seed) + 929)


func active() -> bool:
	return ENABLED


func of(key := "") -> Dictionary:
	var k: String = key if key != "" else sess.aircraft_key
	if not cond.has(k):
		cond[k] = {"engine": 100.0, "airframe": 100.0}
	return cond[k]


func engine() -> float:
	return float(of().engine)


func airframe() -> float:
	return float(of().airframe)


## The share of full power the engine gives, 1.0 when healthy; 0 while it has quit.
func power_scale() -> float:
	if not active():
		return 1.0
	if sess.time < fail_until:
		return 0.0
	var e := engine()
	if e >= ENGINE_ROUGH_BELOW:
		return 1.0
	return POWER_FLOOR + (1.0 - POWER_FLOOR) * clampf(e / ENGINE_ROUGH_BELOW, 0.0, 1.0)


## The touchdown (in fpm) that collapses the gear, scaled for a weakened airframe.
func gear_factor() -> float:
	if not active():
		return 1.0
	var a := airframe()
	if a >= AIRFRAME_WEAK_BELOW:
		return 1.0
	return GEAR_FLOOR + (1.0 - GEAR_FLOOR) * clampf(a / AIRFRAME_WEAK_BELOW, 0.0, 1.0)


func rough() -> bool:
	return engine() < ENGINE_ROUGH_BELOW


func engine_out() -> bool:
	return sess.time < fail_until


## The controls as the engine and a repair under way allow them.
func limit(c: FlightModel.Controls) -> FlightModel.Controls:
	if not active():
		return c
	var cap := power_scale()
	if not work.is_empty() and sess.parked:
		cap = 0.0  # the mechanics have the cowling off
	if c.throttle <= cap:
		return c
	var d := c.copy()
	d.throttle = cap
	return d


## A touchdown of `fpm`, against the gear's `limit_fpm`, on `af` (may be null).
func touchdown(fpm: float, limit_fpm: float, af) -> void:
	if not active():
		return
	var a := of()
	var hard := maxf(0.0, fpm / maxf(1.0, limit_fpm) - HARD_FRACTION) / (1.0 - HARD_FRACTION)
	var loss := hard * HARD_POINTS
	if af != null:
		loss += float(ROUGH_AIRFRAME.get(af.surface, 0.0))
	if loss > 0.0:
		a.airframe = maxf(0.0, float(a.airframe) - loss)
		if hard > 0.3:
			sess.say("That landing hurt the airframe (%s)." % band_of(float(a.airframe)))


## Wear while flying; the engine's failures; a repair's progress. `s` is the flight state (may be null).
func update(dt: float, s) -> void:
	if not active():
		return
	var a := of()
	if s != null and sess.phase == "flying" and s.engine_running:
		a.engine = maxf(0.0, float(a.engine) - ENGINE_WEAR_PER_MIN * dt / 60.0)
		if not sess.weather.is_empty() and sess.weather.get("sky", "") == "storm":
			a.airframe = maxf(0.0, float(a.airframe) - STORM_WEAR_PER_MIN * dt / 60.0)
		var e := float(a.engine)
		if e < ENGINE_FAIL_BELOW and sess.time >= fail_until:
			var p := FAIL_PER_MIN_AT_ZERO * (ENGINE_FAIL_BELOW - e) / ENGINE_FAIL_BELOW * dt / 60.0
			if rng.random() < p:
				fail_until = sess.time + FAIL_S
				failures += 1
				sess.say("ENGINE FAILURE - it quit! Glide it down; it may catch again.")
				sess.bus.emit("engine_failure", sess.time, "", ["runner"], {})
		elif e < ENGINE_ROUGH_BELOW and fposmod(sess.time, 120.0) < dt:
			sess.say("The engine is running rough (%s)." % band_of(e))
	if not work.is_empty():
		_work(dt)


# ------------------------------------------------------------------ repairs
## Where we are: "hangar" (a shop, a hub or a regional strip), or "field" (a bush or shady strip).
func place() -> String:
	var af = sess.airfield
	if af == null:
		return ""
	return "hangar" if (af.shop or af.kind in ["hub", "regional"]) else "field"


## [points a minute, price multiplier] for a repair here now.
func terms() -> Array:
	if held:
		return [MECHANIC_RATE, MECHANIC_COST]
	if place() == "hangar":
		return [HANGAR_RATE, 1.0]
	return [FIELD_RATE, FIELD_COST]


func price(part: String) -> float:
	return float(COST[part]) * float(terms()[1])


## Start putting `parts` (["engine"], ["airframe"] or both) right, up to `to` (100 by default). "" or why not.
func repair(parts: Array, to := 100.0) -> String:
	if not active():
		return "No wear in this game."
	if sess.phase != "parked" or sess.airfield == null:
		return "Park at a strip to have it worked on."
	if not work.is_empty():
		return "The work is already under way."
	var needed := []
	for p in parts:
		if COST.has(p) and float(of()[p]) < to - 0.01:
			needed.append(p)
	if needed.is_empty():
		return "Nothing needs doing."
	if sess.money < price(needed[0]):
		return "Not enough money for the parts."
	work = {"parts": needed, "to": clampf(to, 1.0, 100.0), "key": sess.aircraft_key, "at": sess.location}
	var t := terms()
	sess.say("Work begins: %s, %d points a minute at %s a point." % [" and ".join(needed), int(t[0]), "$%d" % int(price(needed[0]))])
	return ""


func stop(why := "") -> void:
	if work.is_empty():
		return
	work = {}
	if why != "":
		sess.say("Work stopped: %s." % why)


func _work(dt: float) -> void:
	if sess.phase != "parked" or sess.location != work.at or sess.aircraft_key != work.key:
		stop("the aircraft moved")
		return
	var a := of()
	var rate: float = float(terms()[0]) * dt / 60.0
	for p in work.parts.duplicate():
		var gain := minf(rate, float(work.to) - float(a[p]))
		if gain <= 0.0:
			work.parts.erase(p)
			continue
		var cost := gain * price(p)
		if sess.money < cost:
			stop("the money ran out")
			return
		sess.money -= int(round(cost))
		spent += int(round(cost))
		a[p] = minf(100.0, float(a[p]) + gain)
	if work.parts.is_empty():
		work = {}
		sess.say("Work done: engine %s, airframe %s." % [band_of(engine()), band_of(airframe())])


## The AI ground crew: a bot or an absent pilot has a worn aircraft serviced at a hangar (no one is asked).
func auto_service() -> void:
	if not active() or sess.phase != "parked" or not work.is_empty():
		return
	var worst := minf(engine(), airframe())
	if place() != "hangar" and worst >= EMERGENCY_BELOW:
		return  # a bush strip is only for an emergency patch
	var parts := []
	for p in ["engine", "airframe"]:
		if float(of()[p]) < SERVICE_BELOW:
			parts.append(p)
	if not parts.is_empty():
		repair(parts, 100.0)


# ------------------------------------------------------------------ what is shown
static func band_of(v: float) -> String:
	return "good" if v >= 75.0 else ("worn" if v >= 45.0 else ("poor" if v >= 20.0 else "failing"))


func band() -> Dictionary:
	return {"engine": band_of(engine()), "airframe": band_of(airframe())}


## `exact`: the mechanic's numbers; everyone else gets the bands.
func view(exact: bool) -> Dictionary:
	var t := terms()
	var v := {"engine": band_of(engine()), "airframe": band_of(airframe()), "rough": rough(), "out": engine_out(), "working": not work.is_empty(),
		"place": place(), "rate": t[0], "engine_price": int(round(price("engine"))), "airframe_price": int(round(price("airframe"))),
		"mechanic": held, "failures": failures, "spent": spent}
	if exact:
		v["engine_pts"] = snappedf(engine(), 0.1)
		v["airframe_pts"] = snappedf(airframe(), 0.1)
		v["fail_pct_min"] = snappedf(100.0 * FAIL_PER_MIN_AT_ZERO * maxf(0.0, (ENGINE_FAIL_BELOW - engine()) / ENGINE_FAIL_BELOW), 0.1)
		v["gear_factor"] = snappedf(gear_factor(), 0.01)
		v["power"] = snappedf(power_scale(), 0.01)
	return v
