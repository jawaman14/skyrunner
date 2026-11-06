class_name StreakGuard
extends RefCounted
## Bad-luck protection (owner, 4 November 2026, D-94: the World of Warcraft study). WoW raised a quest item's drop chance after
## each miss, so nobody kills forty boars for one tusk. The same for the rolls here that can take a whole run in one go: after
## each catastrophe in a row the chance of the next one halves (down to an eighth), and a clean pass puts it back. The same draws,
## in the same order, against a lower threshold: no new stream. Off for the Python replays (`Switches.PARITY`).
##   - the customs inspection on landing a hot load at a police strip (Police.landing_check, `customs_streak`);
##   - a passing patrol pulling over a truck (GroundWar._patrol_stops, `truck_streak`; a checkpoint still stops every truck).

static var ENABLED := true
const EASE := 0.5  ## each catastrophe in a row halves the chance of the next one
const MAX_STEPS := 3  ## ... at most three times (an eighth of the base chance)


## The multiplier on a catastrophe's chance after `streak` of them in a row: 1, 0.5, 0.25, 0.125.
static func factor(streak: int) -> float:
	if not ENABLED or streak <= 0:
		return 1.0
	return pow(EASE, mini(streak, MAX_STEPS))
