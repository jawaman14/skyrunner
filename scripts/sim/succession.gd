class_name Succession
extends RefCounted
## Succession and the chain of command (owner, 22 and 24 November: D-82, D-101, D-105; docs/DESIGN.md section 101).
##
## After the takeover the player is the boss, and the organisation has a chain of command under him:
##   the number two   FRIEND, the pilot's close friend since flight school (a new character, D-105): he watches the boss's back
##   the captains     the two most loyal men on the payroll, read live (no saved rank): next in line after the number two
##
## The boss dies only when a rival gang kills him (D-101; never jailed, D-64). While Los Cuervos are against us, every game hour
## the boss spends on the ground draws once for a hit: HIT_BASE, times the infamy multiplier (D-102, section 100) and the truce
## multiplier (section 84). The number two sees it coming FRIEND_SPOTS of the time and gets the boss out; otherwise the boss is
## killed and the next in line takes the seat. The player carries on as him (D-82): the same game, the same money and crew; the
## new boss's name is smaller than the old one's (RENOWN_KEPT of the renown), so the gang's eye on him is too. A captain who takes
## the seat leaves the payroll. With nobody left in line, a man from the hall steps up: an ending is never a game over (D-83).
##
## Own stream, seed + 207: one draw an hour on the ground, one for the number two's eye. Saved under `succession`. Behind ENABLED
## (in the parity set); only a game with the takeover has one, and nothing happens before it.

static var ENABLED := true

const FRIEND := "Lalo Medina"
const CHECK_S := 3600.0
const HIT_BASE := 0.04  ## a hit an hour on the ground, for a nobody at war with Los Cuervos
const FRIEND_SPOTS := 0.5
const RENOWN_KEPT := 0.5
const CAPTAINS := 2
const PILOT := "the pilot"

var sess
var rng: PyRandom
var boss := PILOT  ## who the player is now
var friend_alive := true  ## the number two is still the number two (not dead, not in the seat)
var hits: Array = []  ## {t, boss, foiled}
var _t := 0.0


func _init(sess_, rng_: PyRandom) -> void:
	sess = sess_
	rng = rng_


## The chain is live once the takeover has happened.
func live() -> bool:
	return ENABLED and sess.takeover != null and sess.takeover.done


## The odds of a hit this hour, 0 when there can't be one.
func hit_odds() -> float:
	if not live():
		return 0.0
	var p := HIT_BASE * Renown.rival_mult_of(sess)
	var tr := Trust.of_session(sess)
	if tr != null:
		p *= tr.rival_odds()  # a truce holds them back (section 84)
	return clampf(p, 0.0, 1.0)


## Who is next in line, in order: the number two, then the captains (worker dicts).
func chain() -> Array:
	var out: Array = []
	if friend_alive:
		out.append({"name": FRIEND, "role": "number two"})
	for w in captains():
		out.append({"name": str(w.name), "role": "captain", "id": str(w.id)})
	return out


## The most loyal men on our payroll who are free or posted (ties to the more skilled): read live, never saved.
func captains() -> Array:
	var p = sess.payroll
	if p == null:
		return []
	var men: Array = p.of("org").filter(func(w): return str(w.status) in ["free", "assigned"])
	men.sort_custom(func(a, b): return float(a.loyalty) > float(b.loyalty) or (float(a.loyalty) == float(b.loyalty) and float(a.skill) > float(b.skill)))
	return men.slice(0, CAPTAINS)


func update(dt: float) -> void:
	if not live():
		return
	_t += dt
	if _t < CHECK_S:
		return
	_t = 0.0
	if not sess.parked:
		return  # in the air the boss is out of their reach
	var p := hit_odds()
	if p <= 0.0 or rng.random() >= p:
		return
	if friend_alive and rng.random() < FRIEND_SPOTS:
		hits.append({"t": sess.time, "boss": boss, "foiled": true})
		var line := "%s saw the same car go round the block twice and got you out the back. Los Cuervos sent a hitter." % FRIEND
		sess.say(line)
		sess.bus.emit("hit_foiled", sess.time, line, ["runner"], {"boss": boss, "by": FRIEND})
		return
	_killed()


## The boss is killed: the next in line takes the seat, and the player carries on as him.
func _killed() -> void:
	var was := boss
	var heir := ""
	var how := ""
	if friend_alive:
		heir = FRIEND
		how = "your number two"
		friend_alive = false
	else:
		var caps := captains()
		if not caps.is_empty():
			var w: Dictionary = caps[0]
			heir = str(w.name)
			how = "the most loyal of the captains"
			w.status = "gone"
			sess.payroll.workers.erase(w)
		else:
			heir = "Chuy Barragan"
			how = "a man from the hall who stepped up when nobody else would"
	boss = heir
	hits.append({"t": sess.time, "boss": was, "foiled": false, "heir": heir})
	if sess.renown != null:
		sess.renown.score *= RENOWN_KEPT  # a new face: a smaller name, and a smaller target
	var line := "Los Cuervos got %s outside the club. %s, %s, takes the seat: you play on as %s. The business goes on." % [
		"you" if was == PILOT else was, heir, how, heir]
	sess.say("NEWS - " + line)
	sess.bus.emit("boss_killed", sess.time, line, ["runner"], {"was": was, "heir": heir, "by": "rival"})


## For the phone: the chain, the odds, the history.
func view() -> Dictionary:
	return {"live": live(), "boss": boss, "chain": chain(), "odds": hit_odds(), "friend": FRIEND if friend_alive else "",
		"hits": hits.duplicate(true)}


## One line for the Heat page.
func line() -> String:
	if not live():
		return "Rafa's desk: no one is gunning for you yet."
	var next: Array = chain().map(func(c): return "%s (%s)" % [c.name, c.role])
	return "Boss: %s. A hit %.0f%% an hour on the ground. Next in line: %s." % [
		"you" if boss == PILOT else boss, 100.0 * hit_odds(), ", ".join(next) if not next.is_empty() else "a man from the hall"]


func capture() -> Dictionary:
	if boss == PILOT and friend_alive and hits.is_empty():
		return {}
	return {"boss": boss, "friend_alive": friend_alive, "hits": hits.duplicate(true), "t": _t}


func restore(d: Dictionary) -> void:
	boss = str(d.get("boss", PILOT))
	friend_alive = bool(d.get("friend_alive", true))
	hits = (d.get("hits", []) as Array).duplicate(true) if d.get("hits") is Array else []
	_t = float(d.get("t", 0.0))
