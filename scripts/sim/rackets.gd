class_name Rackets
extends RefCounted
## What holding the street is worth, and what winning a fight on it leaves in your hands: two Mount & Blade ideas
## (a village's tribute, the prisoners you take) on the ground war's turf.
##
## Tribute. Every TRIBUTE_EVERY_S the collectors go round the markets (town, west, north, sea). Where the
## organisation holds more than half the street (GroundWar.org_share) it pays: up to TRIBUTE_BASE at full control,
## scaled by the name you have (Renown). Each market has a policy: "fair", "squeeze" (more than double, but the
## street resents it: our hold there drops by 15% and the case against us warms) or "off".
##
## Prisoners. When our squad routs one of Los Cuervos', a third of the survivors are taken. They can be ransomed
## (Los Cuervos pay what they have, up to RANSOM_EACH a man), turned (they join the payroll as soldiers, not to be
## trusted) or let go (a little name for mercy); left alone a few get away every ESCAPE_EVERY_S.
##
## Off for the replays (Rackets.ENABLED = false); a session with a ground war asks for it with `rackets: true`.

static var ENABLED := true

const TRIBUTE_EVERY_S := 600.0
const TRIBUTE_BASE := 160.0  ## $ a market a round at full control
const MIN_SHARE := 0.5  ## below this the street pays nothing
const SQUEEZE_MULT := 2.2
const SQUEEZE_RESENT := 0.85  ## what is left of our hold after a squeeze
const SQUEEZE_HEAT := 2.0  ## suspicion on the case, per squeezed market
const POLICIES := ["fair", "squeeze", "off"]

const CAPTURE_SHARE := 0.3  ## of the beaten squad's survivors
const RANSOM_EACH := 350
const ESCAPE_EVERY_S := 600.0
const ESCAPE_DIV := 8.0  ## one in this many gets away each time

var sess
var policy := {}  ## market -> "fair" | "squeeze" | "off"
var held := 0  ## prisoners
var collected := 0  ## $ of tribute, all told
var rounds := 0
var taken := 0
var escaped := 0
var ransomed := 0
var ransom_cash := 0
var turned := 0
var released := 0
var last_round: Dictionary = {}  ## market -> $ the last time round
var _tt := 0.0
var _te := 0.0


func _init(sess_) -> void:
	sess = sess_
	for m in Economy.MARKETS:
		policy[m] = "fair"


func update(dt: float) -> void:
	_tt += dt
	if _tt >= TRIBUTE_EVERY_S:
		_tt = 0.0
		collect()
	_te += dt
	if _te >= ESCAPE_EVERY_S:
		_te = 0.0
		var gone := int(floor(float(held) / ESCAPE_DIV))
		if gone > 0:
			held -= gone
			escaped += gone
			sess.say("PRISONERS - %d got away in the night (%d still held)." % [gone, held])


# ------------------------------------------------------------------ tribute
## What market m would pay now under its policy (0 when it holds nothing for us).
func expected(m: String) -> int:
	var g = sess.ground
	var pol: String = policy.get(m, "fair")
	if g == null or pol == "off":
		return 0
	var share: float = g.org_share(m)
	if share < MIN_SHARE:
		return 0
	var amt := TRIBUTE_BASE * (share - MIN_SHARE) * 2.0 * (SQUEEZE_MULT if pol == "squeeze" else 1.0)
	if sess.renown != null:
		amt *= sess.renown.price_mult()
	return int(roundf(amt))


## The collectors' round. Returns the total taken.
func collect() -> int:
	var g = sess.ground
	if g == null:
		return 0
	var total := 0
	var heat := 0.0
	var parts := []
	last_round = {}
	for m in Economy.MARKETS:
		var k := expected(m)
		if k <= 0:
			continue
		last_round[m] = k
		total += k
		parts.append("%s $%s" % [m, Py.money(k)])
		if policy[m] == "squeeze":
			g.control[m]["org"] *= SQUEEZE_RESENT
			heat += SQUEEZE_HEAT
	rounds += 1
	if total > 0:
		sess.money += total
		collected += total
		if heat > 0.0:
			var c = sess.police.case("runner")
			c.suspicion = minf(100.0, c.suspicion + heat)
		sess.say("TRIBUTE - the collectors brought $%s (%s)." % [Py.money(total), ", ".join(parts)])
		sess.bus.emit("tribute", sess.time, "", ["runner"], {"amount": total})
	return total


func set_policy(m: String, p: String) -> String:
	if not policy.has(m):
		return "No such market."
	if p not in POLICIES:
		return "Fair, squeeze or off."
	policy[m] = p
	return ""


# ------------------------------------------------------------------ prisoners
## Our squad has routed `loser` (one of Los Cuervos'): a share of what is left of it is taken. Returns how many.
func capture(loser) -> int:
	var n := int(float(loser.men) * CAPTURE_SHARE)
	if n <= 0:
		return 0
	loser.men -= n
	held += n
	taken += n
	sess.say("PRISONERS - our men took %d of Los Cuervos' (%d held)." % [n, held])
	return n


## Los Cuervos pay for their men: RANSOM_EACH a head (more with a name), as much as they have.
func ransom() -> String:
	if held <= 0:
		return "No prisoners."
	var g = sess.ground
	var each: float = float(RANSOM_EACH) * (sess.renown.price_mult() if sess.renown != null else 1.0)
	var want := int(each * float(held))
	var have: float = 0.0 if g == null else float(g.commanders.rival.cash)
	var pay := mini(want, int(have))
	if g != null:
		g.commanders.rival.cash -= pay
	sess.money += pay
	ransom_cash += pay
	ransomed += held
	var n := held
	held = 0
	sess.say("PRISONERS - Los Cuervos paid $%s for %d men." % [Py.money(pay), n])
	return ""


## They take our wage: soldiers on the payroll, with the loyalty of men who were shot at a day ago.
func turn() -> String:
	if held <= 0:
		return "No prisoners."
	var p = sess.payroll
	if p == null:
		return "No payroll to put them on."
	var n := held
	for i in n:
		p.workers.append(_recruit(p))
	turned += n
	held = 0
	sess.say("PRISONERS - %d of them joined us as soldiers. Watch them." % n)
	return ""


func _recruit(p) -> Dictionary:
	p._serial += 1
	var skill := 0.3
	return {"id": "W%d" % p._serial, "name": "%s %s" % [Payroll.FIRST[p._serial % Payroll.FIRST.size()], Payroll.LAST[(p._serial * 7) % Payroll.LAST.size()]],
		"outfit": "org", "role": "soldier", "skill": skill, "loyalty": 0.25,
		"wage": int(float(Payroll.ROLES.soldier[0]) * (0.7 + 0.6 * skill) * 1.5), "hint": "a prisoner who changed sides",
		"status": "free", "assigned": "", "heat": 0.0, "hired_at": sess.time, "street": true}


## Let them go: the street hears of it.
func release() -> String:
	if held <= 0:
		return "No prisoners."
	var n := held
	held = 0
	released += n
	if sess.renown != null:
		sess.renown.add(0.5 * float(n), "prisoners let go")
	sess.say("PRISONERS - %d men sent home." % n)
	return ""


func view() -> Dictionary:
	var markets := []
	for m in Economy.MARKETS:
		var share: float = -1.0 if sess.ground == null else sess.ground.org_share(m)
		markets.append({"market": m, "share": share, "policy": policy[m], "expected": expected(m)})
	return {"markets": markets, "held": held, "collected": collected, "ransom_cash": ransom_cash,
		"next_round": maxf(0.0, TRIBUTE_EVERY_S - _tt), "each": RANSOM_EACH}
