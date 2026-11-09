class_name Trust
extends RefCounted
## Trust with each crew (D-11; docs/DESIGN.md section 76): the five crews' standing with the organisation, 0 to 100, and the owner's
## table of who resents whom. When the organisation does well by one crew, its enemies think less of it:
##
## | Up | Down |
## |---|---|
## | the Morettis | Los Cuervos |
## | Los Cuervos | the Morettis, and the dealers |
## | the Company | the Collective, a little |
## | the Collective | the Company, a little |
## | the dealers | Los Cuervos, a little |
##
## "Down" is half the rise, "a little" a quarter (drafts for the owner's G1). Only a rise spreads: a crew falling out with us is no
## favour to its enemies.
##
## Three crews already had a standing and keep it where it lives: the Family's respect, the Company's trust (`Agency.trust`) and the
## Collective's (`Psychedelics.trust`); a crew whose system is off this game has none. Los Cuervos and the dealers get theirs here
## (they start wary: 20 and 50). The organisation's own dealings move them through `nudge`: a buyer's order filled or left short
## (Orders), a pickup missed (Pickups), a bulk sale (Trade), a barter with the Collective. The world's own events (story beats, the
## Family's offers, the casino) still move the three old standings directly and spread nothing.
##
## No random draws. Saved (Los Cuervos' and the dealers'; the other three are saved by their systems). Behind ENABLED (in the parity
## set): off, `nudge` moves only the crew named, as before.

static var ENABLED := true

const CREWS := ["family", "rival", "agency", "collective", "dealers"]
const NAMES := {"family": "The Morettis", "rival": "Los Cuervos", "agency": "The Company", "collective": "The Sunrise Collective",
	"dealers": "Manny's dealers"}
const DOWN := 0.5
const A_LITTLE := 0.25
const TABLE := {
	"family": {"rival": DOWN},
	"rival": {"family": DOWN, "dealers": DOWN},
	"agency": {"collective": A_LITTLE},
	"collective": {"agency": A_LITTLE},
	"dealers": {"rival": A_LITTLE},
}
const START := {"rival": 20.0, "dealers": 50.0}

var sess
var own := {"rival": 20.0, "dealers": 50.0}  ## the standings kept here


func _init(sess_) -> void:
	sess = sess_


## A crew's standing now, or -1 when it has none this game (its system is off).
func of(crew: String) -> float:
	match crew:
		"family":
			return float(sess.family.respect) if sess.family != null else -1.0
		"agency":
			return float(sess.agency.trust) if sess.agency != null else -1.0
		"collective":
			return float(sess.psych.trust) if sess.psych != null else -1.0
	return float(own.get(crew, -1.0))


func _put(crew: String, v: float) -> void:
	v = clampf(v, 0.0, 100.0)
	match crew:
		"family":
			if sess.family != null:
				sess.family.respect = v
		"agency":
			if sess.agency != null:
				sess.agency.trust = v
		"collective":
			if sess.psych != null:
				sess.psych.trust = v
		_:
			if own.has(crew):
				own[crew] = v


## The organisation's dealing moves `crew` by `delta`; a rise lowers its enemies' (TABLE). Returns {crew: change} for each that moved.
func nudge(crew: String, delta: float) -> Dictionary:
	var out := {}
	if of(crew) < 0.0:
		return out
	var was := of(crew)
	_put(crew, was + delta)
	out[crew] = of(crew) - was
	if ENABLED and delta > 0.0:
		for enemy in TABLE.get(crew, {}):
			if of(enemy) < 0.0:
				continue
			var e := of(enemy)
			_put(enemy, e - delta * float(TABLE[crew][enemy]))
			out[enemy] = of(enemy) - e
	return out


## For the phone: each crew this game has, with its standing.
func view() -> Array:
	var out := []
	for c in CREWS:
		if of(c) >= 0.0:
			out.append({"crew": c, "name": NAMES[c], "trust": snappedf(of(c), 0.1)})
	return out


func capture() -> Dictionary:
	return own.duplicate()


func restore(d: Dictionary) -> void:
	for k in START:
		own[k] = clampf(float(d.get(k, START[k])), 0.0, 100.0)
